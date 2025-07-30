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

type AdminHandler struct {
	adminService *services.AdminService
	validator    *validator.Validate
}

func NewAdminHandler(db *database.Database) *AdminHandler {
	return &AdminHandler{
		adminService: services.NewAdminService(db),
		validator:    validator.New(),
	}
}

// RegisterAdmin handles POST /api/admin/register
func (h *AdminHandler) RegisterAdmin(c echo.Context) error {
	// Extract user from JWT token
	user := c.Get("user").(*jwt.Token)
	claims := user.Claims.(jwt.MapClaims)

	// Get user ID from token
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

	registeredByUserID, err := uuid.Parse(userIDStr)
	if err != nil {
		return c.JSON(http.StatusUnauthorized, map[string]interface{}{
			"success": false,
			"error": map[string]interface{}{
				"code":    "INVALID_USER_ID",
				"message": "Invalid user ID format",
			},
		})
	}

	// Validate user has super_admin role
	userRole, ok := claims["primary_role"].(string)
	if !ok || userRole != models.RoleSuperAdmin {
		return c.JSON(http.StatusForbidden, map[string]interface{}{
			"success": false,
			"error": map[string]interface{}{
				"code":    "INSUFFICIENT_PERMISSIONS",
				"message": "Only super administrators can register new admins",
			},
		})
	}

	// Parse request body
	var req models.AdminRegistrationRequest
	if err := c.Bind(&req); err != nil {
		return c.JSON(http.StatusBadRequest, map[string]interface{}{
			"success": false,
			"error": map[string]interface{}{
				"code":    "INVALID_REQUEST_BODY",
				"message": "Invalid request body format",
				"details": err.Error(),
			},
		})
	}

	// Validate request
	if err := h.validator.Struct(&req); err != nil {
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
			case "uuid":
				validationErrors[field] = "Invalid UUID format"
			case "url":
				validationErrors[field] = "Invalid URL format"
			case "oneof":
				validationErrors[field] = "Invalid value for " + field
			default:
				validationErrors[field] = "Invalid " + field
			}
		}

		return c.JSON(http.StatusBadRequest, map[string]interface{}{
			"success": false,
			"error": map[string]interface{}{
				"code":    "VALIDATION_ERROR",
				"message": "Request validation failed",
				"details": validationErrors,
			},
		})
	}

	// Note: Input sanitization is now handled in the service layer for better security

	// Create context with timeout
	ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer cancel()

	// Register admin
	response, err := h.adminService.RegisterAdmin(ctx, &req, registeredByUserID)
	if err != nil {
		// Handle specific errors
		switch {
		case contains(err.Error(), "email already exists"):
			return c.JSON(http.StatusConflict, map[string]interface{}{
				"success": false,
				"error": map[string]interface{}{
					"code":    "EMAIL_ALREADY_EXISTS",
					"message": "An admin with this email already exists",
					"details": err.Error(),
				},
			})
		case contains(err.Error(), "city not found"):
			return c.JSON(http.StatusBadRequest, map[string]interface{}{
				"success": false,
				"error": map[string]interface{}{
					"code":    "CITY_NOT_FOUND",
					"message": "The specified city does not exist",
					"details": err.Error(),
				},
			})
		case contains(err.Error(), "sport not found"):
			return c.JSON(http.StatusBadRequest, map[string]interface{}{
				"success": false,
				"error": map[string]interface{}{
					"code":    "SPORT_NOT_FOUND",
					"message": "The specified sport does not exist",
					"details": err.Error(),
				},
			})
		case contains(err.Error(), "admin already exists"):
			return c.JSON(http.StatusConflict, map[string]interface{}{
				"success": false,
				"error": map[string]interface{}{
					"code":    "ADMIN_ALREADY_EXISTS",
					"message": "An admin already exists for this city and sport combination",
					"details": err.Error(),
				},
			})
		default:
			return c.JSON(http.StatusInternalServerError, map[string]interface{}{
				"success": false,
				"error": map[string]interface{}{
					"code":    "INTERNAL_SERVER_ERROR",
					"message": "Failed to register admin",
					"details": err.Error(),
				},
			})
		}
	}

	// Return success response
	return c.JSON(http.StatusCreated, map[string]interface{}{
		"success": true,
		"data":    response,
	})
}

// ValidateEmail handles GET /api/admin/validate-email
func (h *AdminHandler) ValidateEmail(c echo.Context) error {
	email := c.QueryParam("email")
	if email == "" {
		return c.JSON(http.StatusBadRequest, map[string]interface{}{
			"success": false,
			"error": map[string]interface{}{
				"code":    "MISSING_EMAIL",
				"message": "Email parameter is required",
			},
		})
	}

	// Create context with timeout
	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()

	// Validate email with enhanced security
	response, err := h.adminService.ValidateEmailUniquenessWithSecurity(ctx, email)
	if err != nil {
		return c.JSON(http.StatusInternalServerError, map[string]interface{}{
			"success": false,
			"error": map[string]interface{}{
				"code":    "VALIDATION_ERROR",
				"message": "Failed to validate email",
				"details": err.Error(),
			},
		})
	}

	return c.JSON(http.StatusOK, map[string]interface{}{
		"success": true,
		"data":    response,
	})
}


// GetAdminList handles GET /api/admin/list
func (h *AdminHandler) GetAdminList(c echo.Context) error {
	// Parse query parameters
	var req models.AdminListRequest
	if err := c.Bind(&req); err != nil {
		return c.JSON(http.StatusBadRequest, map[string]interface{}{
			"success": false,
			"error": map[string]interface{}{
				"code":    "INVALID_QUERY_PARAMS",
				"message": "Invalid query parameters",
				"details": err.Error(),
			},
		})
	}

	// Validate request
	if err := h.validator.Struct(&req); err != nil {
		validationErrors := make(map[string]string)
		for _, err := range err.(validator.ValidationErrors) {
			field := err.Field()
			switch err.Tag() {
			case "min":
				validationErrors[field] = field + " must be at least " + err.Param()
			case "max":
				validationErrors[field] = field + " must be at most " + err.Param()
			case "uuid":
				validationErrors[field] = "Invalid UUID format for " + field
			case "oneof":
				validationErrors[field] = "Invalid value for " + field
			default:
				validationErrors[field] = "Invalid " + field
			}
		}

		return c.JSON(http.StatusBadRequest, map[string]interface{}{
			"success": false,
			"error": map[string]interface{}{
				"code":    "VALIDATION_ERROR",
				"message": "Query parameter validation failed",
				"details": validationErrors,
			},
		})
	}

	// Create context with timeout
	ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer cancel()

	// Get admin list
	response, err := h.adminService.GetAdminList(ctx, &req)
	if err != nil {
		return c.JSON(http.StatusInternalServerError, map[string]interface{}{
			"success": false,
			"error": map[string]interface{}{
				"code":    "INTERNAL_SERVER_ERROR",
				"message": "Failed to retrieve admin list",
				"details": err.Error(),
			},
		})
	}

	return c.JSON(http.StatusOK, map[string]interface{}{
		"success": true,
		"data":    response,
	})
}

// contains checks if a string contains a substring (case-insensitive)
func contains(s, substr string) bool {
	return strings.Contains(strings.ToLower(s), strings.ToLower(substr))
}
