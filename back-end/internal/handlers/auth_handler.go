package handlers

import (
	"context"
	"mowesport/internal/database"
	"mowesport/internal/models"
	"mowesport/internal/services"
	"net/http"
	"strings"
	"time"

	"github.com/go-playground/validator/v10"
	"github.com/golang-jwt/jwt/v5"
	"github.com/google/uuid"
	"github.com/labstack/echo/v4"
)

type AuthHandler struct {
	authService *services.AuthService
	validator   *validator.Validate
}

func NewAuthHandler(db *database.Database, jwtSecret string) *AuthHandler {
	return &AuthHandler{
		authService: services.NewAuthService(db, jwtSecret),
		validator:   validator.New(),
	}
}

// Login handles POST /api/auth/login
func (h *AuthHandler) Login(c echo.Context) error {
	var req models.LoginRequest
	if err := c.Bind(&req); err != nil {
		return c.JSON(http.StatusBadRequest, map[string]interface{}{
			"success": false,
			"error": map[string]interface{}{
				"code":    "INVALID_REQUEST_BODY",
				"message": "Invalid request body format",
			},
		})
	}

	// Validate request
	if err := h.validator.Struct(&req); err != nil {
		return c.JSON(http.StatusBadRequest, map[string]interface{}{
			"success": false,
			"error": map[string]interface{}{
				"code":    "VALIDATION_ERROR",
				"message": "Request validation failed",
				"details": h.formatValidationErrors(err),
			},
		})
	}

	// Create context with timeout
	ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer cancel()

	// Attempt login
	response, err := h.authService.Login(ctx, &req)
	if err != nil {
		return h.handleAuthError(c, err)
	}

	return c.JSON(http.StatusOK, map[string]interface{}{
		"success": true,
		"data":    response,
	})
}

// RefreshToken handles POST /api/auth/refresh
func (h *AuthHandler) RefreshToken(c echo.Context) error {
	var req struct {
		RefreshToken string `json:"refresh_token" validate:"required"`
	}

	if err := c.Bind(&req); err != nil {
		return c.JSON(http.StatusBadRequest, map[string]interface{}{
			"success": false,
			"error": map[string]interface{}{
				"code":    "INVALID_REQUEST_BODY",
				"message": "Invalid request body format",
			},
		})
	}

	if err := h.validator.Struct(&req); err != nil {
		return c.JSON(http.StatusBadRequest, map[string]interface{}{
			"success": false,
			"error": map[string]interface{}{
				"code":    "VALIDATION_ERROR",
				"message": "Refresh token is required",
			},
		})
	}

	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()

	response, err := h.authService.RefreshToken(ctx, req.RefreshToken)
	if err != nil {
		return c.JSON(http.StatusUnauthorized, map[string]interface{}{
			"success": false,
			"error": map[string]interface{}{
				"code":    "INVALID_REFRESH_TOKEN",
				"message": "Invalid or expired refresh token",
			},
		})
	}

	return c.JSON(http.StatusOK, map[string]interface{}{
		"success": true,
		"data":    response,
	})
}

// Logout handles POST /api/auth/logout
func (h *AuthHandler) Logout(c echo.Context) error {
	// For JWT-based auth, logout is typically handled client-side by removing the token
	// However, we can implement token blacklisting if needed in the future

	return c.JSON(http.StatusOK, map[string]interface{}{
		"success": true,
		"message": "Logged out successfully",
	})
}

// RequestPasswordRecovery handles POST /api/auth/forgot-password
func (h *AuthHandler) RequestPasswordRecovery(c echo.Context) error {
	var req models.PasswordRecoveryRequest
	if err := c.Bind(&req); err != nil {
		return c.JSON(http.StatusBadRequest, map[string]interface{}{
			"success": false,
			"error": map[string]interface{}{
				"code":    "INVALID_REQUEST_BODY",
				"message": "Invalid request body format",
			},
		})
	}

	if err := h.validator.Struct(&req); err != nil {
		return c.JSON(http.StatusBadRequest, map[string]interface{}{
			"success": false,
			"error": map[string]interface{}{
				"code":    "VALIDATION_ERROR",
				"message": "Valid email is required",
			},
		})
	}

	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()

	err := h.authService.RequestPasswordRecovery(ctx, &req)
	if err != nil {
		return c.JSON(http.StatusInternalServerError, map[string]interface{}{
			"success": false,
			"error": map[string]interface{}{
				"code":    "RECOVERY_REQUEST_FAILED",
				"message": "Failed to process password recovery request",
			},
		})
	}

	// Always return success for security (don't reveal if email exists)
	return c.JSON(http.StatusOK, map[string]interface{}{
		"success": true,
		"message": "If the email exists, a recovery link has been sent",
	})
}

// ResetPassword handles POST /api/auth/reset-password
func (h *AuthHandler) ResetPassword(c echo.Context) error {
	var req models.PasswordResetRequest
	if err := c.Bind(&req); err != nil {
		return c.JSON(http.StatusBadRequest, map[string]interface{}{
			"success": false,
			"error": map[string]interface{}{
				"code":    "INVALID_REQUEST_BODY",
				"message": "Invalid request body format",
			},
		})
	}

	if err := h.validator.Struct(&req); err != nil {
		return c.JSON(http.StatusBadRequest, map[string]interface{}{
			"success": false,
			"error": map[string]interface{}{
				"code":    "VALIDATION_ERROR",
				"message": "Token and new password are required",
				"details": h.formatValidationErrors(err),
			},
		})
	}

	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()

	err := h.authService.ResetPassword(ctx, &req)
	if err != nil {
		if strings.Contains(err.Error(), "invalid") || strings.Contains(err.Error(), "expired") {
			return c.JSON(http.StatusBadRequest, map[string]interface{}{
				"success": false,
				"error": map[string]interface{}{
					"code":    "INVALID_TOKEN",
					"message": "Invalid or expired recovery token",
				},
			})
		}

		return c.JSON(http.StatusInternalServerError, map[string]interface{}{
			"success": false,
			"error": map[string]interface{}{
				"code":    "PASSWORD_RESET_FAILED",
				"message": "Failed to reset password",
			},
		})
	}

	return c.JSON(http.StatusOK, map[string]interface{}{
		"success": true,
		"message": "Password reset successfully",
	})
}

// Setup2FA handles POST /api/auth/2fa/setup
func (h *AuthHandler) Setup2FA(c echo.Context) error {
	// Get user from JWT token
	user := c.Get("user").(*jwt.Token)
	claims := user.Claims.(jwt.MapClaims)

	userIDStr, ok := claims["user_id"].(string)
	if !ok {
		return c.JSON(http.StatusUnauthorized, map[string]interface{}{
			"success": false,
			"error": map[string]interface{}{
				"code":    "INVALID_TOKEN",
				"message": "Invalid user ID in token",
			},
		})
	}

	userID, err := uuid.Parse(userIDStr)
	if err != nil {
		return c.JSON(http.StatusUnauthorized, map[string]interface{}{
			"success": false,
			"error": map[string]interface{}{
				"code":    "INVALID_USER_ID",
				"message": "Invalid user ID format",
			},
		})
	}

	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()

	response, err := h.authService.Setup2FA(ctx, userID)
	if err != nil {
		return c.JSON(http.StatusInternalServerError, map[string]interface{}{
			"success": false,
			"error": map[string]interface{}{
				"code":    "2FA_SETUP_FAILED",
				"message": "Failed to setup 2FA",
			},
		})
	}

	return c.JSON(http.StatusOK, map[string]interface{}{
		"success": true,
		"data":    response,
	})
}

// Verify2FA handles POST /api/auth/2fa/verify
func (h *AuthHandler) Verify2FA(c echo.Context) error {
	// Get user from JWT token
	user := c.Get("user").(*jwt.Token)
	claims := user.Claims.(jwt.MapClaims)

	userIDStr, ok := claims["user_id"].(string)
	if !ok {
		return c.JSON(http.StatusUnauthorized, map[string]interface{}{
			"success": false,
			"error": map[string]interface{}{
				"code":    "INVALID_TOKEN",
				"message": "Invalid user ID in token",
			},
		})
	}

	userID, err := uuid.Parse(userIDStr)
	if err != nil {
		return c.JSON(http.StatusUnauthorized, map[string]interface{}{
			"success": false,
			"error": map[string]interface{}{
				"code":    "INVALID_USER_ID",
				"message": "Invalid user ID format",
			},
		})
	}

	var req models.Verify2FARequest
	if err := c.Bind(&req); err != nil {
		return c.JSON(http.StatusBadRequest, map[string]interface{}{
			"success": false,
			"error": map[string]interface{}{
				"code":    "INVALID_REQUEST_BODY",
				"message": "Invalid request body format",
			},
		})
	}

	if err := h.validator.Struct(&req); err != nil {
		return c.JSON(http.StatusBadRequest, map[string]interface{}{
			"success": false,
			"error": map[string]interface{}{
				"code":    "VALIDATION_ERROR",
				"message": "6-digit code is required",
			},
		})
	}

	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()

	err = h.authService.Verify2FA(ctx, userID, &req)
	if err != nil {
		if strings.Contains(err.Error(), "invalid") {
			return c.JSON(http.StatusBadRequest, map[string]interface{}{
				"success": false,
				"error": map[string]interface{}{
					"code":    "INVALID_2FA_CODE",
					"message": "Invalid 2FA code",
				},
			})
		}

		return c.JSON(http.StatusInternalServerError, map[string]interface{}{
			"success": false,
			"error": map[string]interface{}{
				"code":    "2FA_VERIFICATION_FAILED",
				"message": "Failed to verify 2FA",
			},
		})
	}

	return c.JSON(http.StatusOK, map[string]interface{}{
		"success": true,
		"message": "2FA enabled successfully",
	})
}

// Disable2FA handles POST /api/auth/2fa/disable
func (h *AuthHandler) Disable2FA(c echo.Context) error {
	// Get user from JWT token
	user := c.Get("user").(*jwt.Token)
	claims := user.Claims.(jwt.MapClaims)

	userIDStr, ok := claims["user_id"].(string)
	if !ok {
		return c.JSON(http.StatusUnauthorized, map[string]interface{}{
			"success": false,
			"error": map[string]interface{}{
				"code":    "INVALID_TOKEN",
				"message": "Invalid user ID in token",
			},
		})
	}

	userID, err := uuid.Parse(userIDStr)
	if err != nil {
		return c.JSON(http.StatusUnauthorized, map[string]interface{}{
			"success": false,
			"error": map[string]interface{}{
				"code":    "INVALID_USER_ID",
				"message": "Invalid user ID format",
			},
		})
	}

	var req models.Verify2FARequest
	if err := c.Bind(&req); err != nil {
		return c.JSON(http.StatusBadRequest, map[string]interface{}{
			"success": false,
			"error": map[string]interface{}{
				"code":    "INVALID_REQUEST_BODY",
				"message": "Invalid request body format",
			},
		})
	}

	if err := h.validator.Struct(&req); err != nil {
		return c.JSON(http.StatusBadRequest, map[string]interface{}{
			"success": false,
			"error": map[string]interface{}{
				"code":    "VALIDATION_ERROR",
				"message": "6-digit code is required",
			},
		})
	}

	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()

	err = h.authService.Disable2FA(ctx, userID, &req)
	if err != nil {
		if strings.Contains(err.Error(), "invalid") {
			return c.JSON(http.StatusBadRequest, map[string]interface{}{
				"success": false,
				"error": map[string]interface{}{
					"code":    "INVALID_2FA_CODE",
					"message": "Invalid 2FA code",
				},
			})
		}

		if strings.Contains(err.Error(), "not enabled") {
			return c.JSON(http.StatusBadRequest, map[string]interface{}{
				"success": false,
				"error": map[string]interface{}{
					"code":    "2FA_NOT_ENABLED",
					"message": "2FA is not enabled for this account",
				},
			})
		}

		return c.JSON(http.StatusInternalServerError, map[string]interface{}{
			"success": false,
			"error": map[string]interface{}{
				"code":    "2FA_DISABLE_FAILED",
				"message": "Failed to disable 2FA",
			},
		})
	}

	return c.JSON(http.StatusOK, map[string]interface{}{
		"success": true,
		"message": "2FA disabled successfully",
	})
}

// GetProfile handles GET /api/auth/profile
func (h *AuthHandler) GetProfile(c echo.Context) error {
	// Get user from JWT token
	user := c.Get("user").(*jwt.Token)
	claims := user.Claims.(jwt.MapClaims)

	userIDStr, ok := claims["user_id"].(string)
	if !ok {
		return c.JSON(http.StatusUnauthorized, map[string]interface{}{
			"success": false,
			"error": map[string]interface{}{
				"code":    "INVALID_TOKEN",
				"message": "Invalid user ID in token",
			},
		})
	}

	userID, err := uuid.Parse(userIDStr)
	if err != nil {
		return c.JSON(http.StatusUnauthorized, map[string]interface{}{
			"success": false,
			"error": map[string]interface{}{
				"code":    "INVALID_USER_ID",
				"message": "Invalid user ID format",
			},
		})
	}

	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()

	profile, err := h.authService.GetUserProfile(ctx, userID)
	if err != nil {
		if strings.Contains(err.Error(), "not found") {
			return c.JSON(http.StatusNotFound, map[string]interface{}{
				"success": false,
				"error": map[string]interface{}{
					"code":    "USER_NOT_FOUND",
					"message": "User profile not found",
				},
			})
		}

		return c.JSON(http.StatusInternalServerError, map[string]interface{}{
			"success": false,
			"error": map[string]interface{}{
				"code":    "PROFILE_FETCH_FAILED",
				"message": "Failed to fetch user profile",
			},
		})
	}

	return c.JSON(http.StatusOK, map[string]interface{}{
		"success": true,
		"data":    profile,
	})
}

// Helper methods

func (h *AuthHandler) handleAuthError(c echo.Context, err error) error {
	errMsg := err.Error()

	switch {
	case strings.Contains(errMsg, "user not found"):
		return c.JSON(http.StatusNotFound, map[string]interface{}{
			"success": false,
			"error": map[string]interface{}{
				"code":    "USER_NOT_FOUND",
				"message": "User not found",
			},
		})

	case strings.Contains(errMsg, "invalid credentials"):
		return c.JSON(http.StatusUnauthorized, map[string]interface{}{
			"success": false,
			"error": map[string]interface{}{
				"code":    "INVALID_CREDENTIALS",
				"message": "Invalid email or password",
			},
		})

	case strings.Contains(errMsg, "account_inactive"):
		return c.JSON(http.StatusForbidden, map[string]interface{}{
			"success": false,
			"error": map[string]interface{}{
				"code":    "ACCOUNT_INACTIVE",
				"message": "Account is inactive",
			},
		})

	case strings.Contains(errMsg, "account_locked"):
		return c.JSON(http.StatusForbidden, map[string]interface{}{
			"success": false,
			"error": map[string]interface{}{
				"code":    "ACCOUNT_LOCKED",
				"message": "Account is temporarily locked due to failed login attempts",
			},
		})

	case strings.Contains(errMsg, "account_suspended"):
		return c.JSON(http.StatusForbidden, map[string]interface{}{
			"success": false,
			"error": map[string]interface{}{
				"code":    "ACCOUNT_SUSPENDED",
				"message": "Account is suspended",
			},
		})

	case strings.Contains(errMsg, "account_payment_pending"):
		return c.JSON(http.StatusForbidden, map[string]interface{}{
			"success": false,
			"error": map[string]interface{}{
				"code":    "ACCOUNT_PAYMENT_PENDING",
				"message": "Account has payment pending",
			},
		})

	case strings.Contains(errMsg, "two_factor_required"):
		return c.JSON(http.StatusUnauthorized, map[string]interface{}{
			"success": false,
			"error": map[string]interface{}{
				"code":    "TWO_FACTOR_REQUIRED",
				"message": "Two-factor authentication code required",
			},
		})

	case strings.Contains(errMsg, "invalid_two_factor_code"):
		return c.JSON(http.StatusUnauthorized, map[string]interface{}{
			"success": false,
			"error": map[string]interface{}{
				"code":    "INVALID_TWO_FACTOR_CODE",
				"message": "Invalid two-factor authentication code",
			},
		})

	default:
		return c.JSON(http.StatusInternalServerError, map[string]interface{}{
			"success": false,
			"error": map[string]interface{}{
				"code":    "AUTHENTICATION_ERROR",
				"message": "Authentication failed",
			},
		})
	}
}

func (h *AuthHandler) formatValidationErrors(err error) map[string]string {
	validationErrors := make(map[string]string)
	for _, err := range err.(validator.ValidationErrors) {
		field := err.Field()
		switch err.Tag() {
		case "required":
			validationErrors[field] = field + " is required"
		case "email":
			validationErrors[field] = "Invalid email format"
		case "min":
			validationErrors[field] = field + " is too short"
		case "max":
			validationErrors[field] = field + " is too long"
		case "len":
			validationErrors[field] = field + " must be exactly " + err.Param() + " characters"
		default:
			validationErrors[field] = "Invalid " + field
		}
	}
	return validationErrors
}
