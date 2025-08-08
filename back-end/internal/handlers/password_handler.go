package handlers

import (
	"context"
	"fmt"
	"mowesport/internal/database"
	"mowesport/internal/services"
	"net/http"
	"time"

	"github.com/go-playground/validator/v10"
	"github.com/golang-jwt/jwt/v5"
	"github.com/google/uuid"
	"github.com/labstack/echo/v4"
	"golang.org/x/crypto/bcrypt"
)

type PasswordHandler struct {
	db                       *database.Database
	temporaryPasswordService *services.TemporaryPasswordService
	validator                *validator.Validate
}

type ChangePasswordRequest struct {
	CurrentPassword string `json:"current_password" validate:"required"`
	NewPassword     string `json:"new_password" validate:"required,min=8"`
	ConfirmPassword string `json:"confirm_password" validate:"required"`
}

type ChangePasswordResponse struct {
	Message string `json:"message"`
	Success bool   `json:"success"`
}

func NewPasswordHandler(db *database.Database) *PasswordHandler {
	return &PasswordHandler{
		db:                       db,
		temporaryPasswordService: services.NewTemporaryPasswordService(db),
		validator:                validator.New(),
	}
}

// ChangePassword handles POST /api/auth/change-password
func (h *PasswordHandler) ChangePassword(c echo.Context) error {
	// Get user from JWT token
	user := c.Get("user").(*jwt.Token)
	claims := user.Claims.(jwt.MapClaims)
	userIDStr := claims["user_id"].(string)

	userID, err := uuid.Parse(userIDStr)
	if err != nil {
		return c.JSON(http.StatusBadRequest, map[string]interface{}{
			"success": false,
			"error": map[string]interface{}{
				"code":    "INVALID_USER_ID",
				"message": "Invalid user ID",
			},
		})
	}

	// Parse request
	var req ChangePasswordRequest
	if err := c.Bind(&req); err != nil {
		return c.JSON(http.StatusBadRequest, map[string]interface{}{
			"success": false,
			"error": map[string]interface{}{
				"code":    "INVALID_REQUEST_BODY",
				"message": "Invalid request body",
			},
		})
	}

	// Validate request
	if err := h.validator.Struct(req); err != nil {
		return c.JSON(http.StatusBadRequest, map[string]interface{}{
			"success": false,
			"error": map[string]interface{}{
				"code":    "VALIDATION_ERROR",
				"message": "Validation failed",
				"details": h.formatValidationErrors(err),
			},
		})
	}

	// Check if new password matches confirmation
	if req.NewPassword != req.ConfirmPassword {
		return c.JSON(http.StatusBadRequest, map[string]interface{}{
			"success": false,
			"error": map[string]interface{}{
				"code":    "PASSWORD_MISMATCH",
				"message": "New password and confirmation do not match",
			},
		})
	}

	// Get current user data
	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()

	var currentPasswordHash string
	err = h.db.GetConnection().QueryRow(ctx, `
		SELECT password_hash FROM user_profiles WHERE user_id = $1
	`, userID).Scan(&currentPasswordHash)

	if err != nil {
		return c.JSON(http.StatusInternalServerError, map[string]interface{}{
			"success": false,
			"error": map[string]interface{}{
				"code":    "DATABASE_ERROR",
				"message": "Failed to retrieve user data",
			},
		})
	}

	// Verify current password
	if err := bcrypt.CompareHashAndPassword([]byte(currentPasswordHash), []byte(req.CurrentPassword)); err != nil {
		return c.JSON(http.StatusUnauthorized, map[string]interface{}{
			"success": false,
			"error": map[string]interface{}{
				"code":    "INVALID_CURRENT_PASSWORD",
				"message": "Current password is incorrect",
			},
		})
	}

	// Hash new password
	hashedNewPassword, err := bcrypt.GenerateFromPassword([]byte(req.NewPassword), bcrypt.DefaultCost)
	if err != nil {
		return c.JSON(http.StatusInternalServerError, map[string]interface{}{
			"success": false,
			"error": map[string]interface{}{
				"code":    "PASSWORD_HASH_ERROR",
				"message": "Failed to process new password",
			},
		})
	}

	// Update password and clear temporary password expiration
	_, err = h.db.GetConnection().Exec(ctx, `
		UPDATE user_profiles 
		SET password_hash = $1, 
		    token_expiration_date = NULL,
		    updated_at = NOW()
		WHERE user_id = $2
	`, string(hashedNewPassword), userID)

	if err != nil {
		return c.JSON(http.StatusInternalServerError, map[string]interface{}{
			"success": false,
			"error": map[string]interface{}{
				"code":    "PASSWORD_UPDATE_ERROR",
				"message": "Failed to update password",
			},
		})
	}

	// Mark temporary password as used if it was temporary
	err = h.temporaryPasswordService.MarkTemporaryPasswordAsUsed(ctx, userID)
	if err != nil {
		// Log error but don't fail the request
		// The password was already updated successfully
		c.Logger().Errorf("Failed to mark temporary password as used: %v", err)
	}

	return c.JSON(http.StatusOK, map[string]interface{}{
		"success": true,
		"data": ChangePasswordResponse{
			Message: "Password changed successfully",
			Success: true,
		},
	})
}

// CheckPasswordStatus handles GET /api/auth/password-status
func (h *PasswordHandler) CheckPasswordStatus(c echo.Context) error {
	// Get user from JWT token
	user := c.Get("user").(*jwt.Token)
	claims := user.Claims.(jwt.MapClaims)
	userIDStr := claims["user_id"].(string)

	userID, err := uuid.Parse(userIDStr)
	if err != nil {
		return c.JSON(http.StatusBadRequest, map[string]interface{}{
			"success": false,
			"error": map[string]interface{}{
				"code":    "INVALID_USER_ID",
				"message": "Invalid user ID",
			},
		})
	}

	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()

	// Check if password is temporary
	isTemporary, expirationDate, err := h.temporaryPasswordService.IsPasswordTemporary(ctx, userID)
	if err != nil {
		return c.JSON(http.StatusInternalServerError, map[string]interface{}{
			"success": false,
			"error": map[string]interface{}{
				"code":    "DATABASE_ERROR",
				"message": "Failed to check password status",
			},
		})
	}

	response := map[string]interface{}{
		"is_temporary":    isTemporary,
		"requires_change": isTemporary,
	}

	if expirationDate != nil {
		response["expires_at"] = expirationDate
		response["is_expired"] = time.Now().After(*expirationDate)

		if !time.Now().After(*expirationDate) {
			response["time_remaining"] = expirationDate.Sub(time.Now()).String()
		}
	}

	return c.JSON(http.StatusOK, map[string]interface{}{
		"success": true,
		"data":    response,
	})
}

// RegenerateTemporaryPassword handles POST /api/admin/{id}/regenerate-password (Super Admin only)
func (h *PasswordHandler) RegenerateTemporaryPassword(c echo.Context) error {
	// Get admin ID from URL parameter
	adminIDStr := c.Param("id")
	adminID, err := uuid.Parse(adminIDStr)
	if err != nil {
		return c.JSON(http.StatusBadRequest, map[string]interface{}{
			"success": false,
			"error": map[string]interface{}{
				"code":    "INVALID_ADMIN_ID",
				"message": "Invalid administrator ID",
			},
		})
	}

	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()

	// Verify the admin exists
	var adminEmail, firstName, lastName string
	err = h.db.GetConnection().QueryRow(ctx, `
		SELECT email, first_name, last_name 
		FROM user_profiles 
		WHERE user_id = $1 AND primary_role = 'city_admin'
	`, adminID).Scan(&adminEmail, &firstName, &lastName)

	if err != nil {
		return c.JSON(http.StatusNotFound, map[string]interface{}{
			"success": false,
			"error": map[string]interface{}{
				"code":    "ADMIN_NOT_FOUND",
				"message": "Administrator not found",
			},
		})
	}

	// Generate new temporary password
	tempPassword, err := h.temporaryPasswordService.RegenerateTemporaryPassword(ctx, adminID, 24)
	if err != nil {
		return c.JSON(http.StatusInternalServerError, map[string]interface{}{
			"success": false,
			"error": map[string]interface{}{
				"code":    "PASSWORD_GENERATION_ERROR",
				"message": "Failed to generate new temporary password",
			},
		})
	}

	// TODO: Send email with new temporary password
	// For now, return the password in the response (development only)

	return c.JSON(http.StatusOK, map[string]interface{}{
		"success": true,
		"data": map[string]interface{}{
			"message":            "Temporary password regenerated successfully",
			"temporary_password": tempPassword, // Remove in production
			"admin_email":        adminEmail,
			"expires_in_hours":   24,
		},
	})
}

// formatValidationErrors formats validation errors for API response
func (h *PasswordHandler) formatValidationErrors(err error) map[string]string {
	errors := make(map[string]string)

	if validationErrors, ok := err.(validator.ValidationErrors); ok {
		for _, e := range validationErrors {
			field := e.Field()
			switch e.Tag() {
			case "required":
				errors[field] = "This field is required"
			case "min":
				errors[field] = fmt.Sprintf("This field must be at least %s characters", e.Param())
			case "email":
				errors[field] = "Invalid email format"
			default:
				errors[field] = "Invalid value"
			}
		}
	}

	return errors
}
