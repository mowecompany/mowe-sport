package handlers

import (
	"context"
	"encoding/json"
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
	"golang.org/x/crypto/bcrypt"
)

type UserManagementHandler struct {
	userService *services.UserManagementService
	validator   *validator.Validate
}

func NewUserManagementHandler(db *database.Database) *UserManagementHandler {
	return &UserManagementHandler{
		userService: services.NewUserManagementService(db),
		validator:   validator.New(),
	}
}

// GetUserProfile handles GET /api/users/:id
func (h *UserManagementHandler) GetUserProfile(c echo.Context) error {
	// Extract user from JWT token
	user := c.Get("user").(*jwt.Token)
	claims := user.Claims.(jwt.MapClaims)

	// Get requester user ID from token
	requesterIDStr, ok := claims["user_id"].(string)
	if !ok {
		return c.JSON(http.StatusUnauthorized, map[string]interface{}{
			"success": false,
			"error": map[string]interface{}{
				"code":    "INVALID_TOKEN",
				"message": "Invalid user ID in token",
			},
		})
	}

	requesterID, err := uuid.Parse(requesterIDStr)
	if err != nil {
		return c.JSON(http.StatusUnauthorized, map[string]interface{}{
			"success": false,
			"error": map[string]interface{}{
				"code":    "INVALID_USER_ID",
				"message": "Invalid user ID format",
			},
		})
	}

	// Get target user ID from URL parameter
	userIDStr := c.Param("id")
	userID, err := uuid.Parse(userIDStr)
	if err != nil {
		return c.JSON(http.StatusBadRequest, map[string]interface{}{
			"success": false,
			"error": map[string]interface{}{
				"code":    "INVALID_USER_ID",
				"message": "Invalid user ID format",
			},
		})
	}

	// Create context with timeout
	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()

	// Get user profile
	userProfile, err := h.userService.GetUserProfile(ctx, userID, requesterID)
	if err != nil {
		if strings.Contains(err.Error(), "insufficient permissions") {
			return c.JSON(http.StatusForbidden, map[string]interface{}{
				"success": false,
				"error": map[string]interface{}{
					"code":    "INSUFFICIENT_PERMISSIONS",
					"message": "Admin permissions required",
				},
			})
		}

		if strings.Contains(err.Error(), "not found") {
			return c.JSON(http.StatusNotFound, map[string]interface{}{
				"success": false,
				"error": map[string]interface{}{
					"code":    "USER_NOT_FOUND",
					"message": "User not found",
				},
			})
		}

		return c.JSON(http.StatusInternalServerError, map[string]interface{}{
			"success": false,
			"error": map[string]interface{}{
				"code":    "INTERNAL_SERVER_ERROR",
				"message": "Failed to retrieve user profile",
				"details": err.Error(),
			},
		})
	}

	return c.JSON(http.StatusOK, map[string]interface{}{
		"success": true,
		"data":    userProfile,
	})
}

// UpdateUserProfile handles PUT /api/users/:id
func (h *UserManagementHandler) UpdateUserProfile(c echo.Context) error {
	// Extract user from JWT token
	user := c.Get("user").(*jwt.Token)
	claims := user.Claims.(jwt.MapClaims)

	// Get requester user ID from token
	requesterIDStr, ok := claims["user_id"].(string)
	if !ok {
		return c.JSON(http.StatusUnauthorized, map[string]interface{}{
			"success": false,
			"error": map[string]interface{}{
				"code":    "INVALID_TOKEN",
				"message": "Invalid user ID in token",
			},
		})
	}

	requesterID, err := uuid.Parse(requesterIDStr)
	if err != nil {
		return c.JSON(http.StatusUnauthorized, map[string]interface{}{
			"success": false,
			"error": map[string]interface{}{
				"code":    "INVALID_USER_ID",
				"message": "Invalid user ID format",
			},
		})
	}

	// Get target user ID from URL parameter
	userIDStr := c.Param("id")
	userID, err := uuid.Parse(userIDStr)
	if err != nil {
		return c.JSON(http.StatusBadRequest, map[string]interface{}{
			"success": false,
			"error": map[string]interface{}{
				"code":    "INVALID_USER_ID",
				"message": "Invalid user ID format",
			},
		})
	}

	// Parse request body
	var req models.UserUpdateRequest
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
		validationErrors := h.formatValidationErrors(err)
		return c.JSON(http.StatusBadRequest, map[string]interface{}{
			"success": false,
			"error": map[string]interface{}{
				"code":    "VALIDATION_ERROR",
				"message": "Request validation failed",
				"details": validationErrors,
			},
		})
	}

	// Create context with timeout
	ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer cancel()

	// Update user profile
	updatedUser, err := h.userService.UpdateUserProfile(ctx, userID, &req, requesterID)
	if err != nil {
		if strings.Contains(err.Error(), "insufficient permissions") {
			return c.JSON(http.StatusForbidden, map[string]interface{}{
				"success": false,
				"error": map[string]interface{}{
					"code":    "INSUFFICIENT_PERMISSIONS",
					"message": "Admin permissions required",
				},
			})
		}

		if strings.Contains(err.Error(), "not found") {
			return c.JSON(http.StatusNotFound, map[string]interface{}{
				"success": false,
				"error": map[string]interface{}{
					"code":    "USER_NOT_FOUND",
					"message": "User not found",
				},
			})
		}

		return c.JSON(http.StatusInternalServerError, map[string]interface{}{
			"success": false,
			"error": map[string]interface{}{
				"code":    "INTERNAL_SERVER_ERROR",
				"message": "Failed to update user profile",
				"details": err.Error(),
			},
		})
	}

	return c.JSON(http.StatusOK, map[string]interface{}{
		"success": true,
		"data":    updatedUser,
	})
}

// GetUserList handles GET /api/users
func (h *UserManagementHandler) GetUserList(c echo.Context) error {
	// Extract user from JWT token
	user := c.Get("user").(*jwt.Token)
	claims := user.Claims.(jwt.MapClaims)

	// Get requester user ID from token
	requesterIDStr, ok := claims["user_id"].(string)
	if !ok {
		return c.JSON(http.StatusUnauthorized, map[string]interface{}{
			"success": false,
			"error": map[string]interface{}{
				"code":    "INVALID_TOKEN",
				"message": "Invalid user ID in token",
			},
		})
	}

	requesterID, err := uuid.Parse(requesterIDStr)
	if err != nil {
		return c.JSON(http.StatusUnauthorized, map[string]interface{}{
			"success": false,
			"error": map[string]interface{}{
				"code":    "INVALID_USER_ID",
				"message": "Invalid user ID format",
			},
		})
	}

	// Parse query parameters
	var req models.UserListRequest
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
		validationErrors := h.formatValidationErrors(err)
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

	// Get user list
	response, err := h.userService.GetUserList(ctx, &req, requesterID)
	if err != nil {
		if strings.Contains(err.Error(), "insufficient permissions") {
			return c.JSON(http.StatusForbidden, map[string]interface{}{
				"success": false,
				"error": map[string]interface{}{
					"code":    "INSUFFICIENT_PERMISSIONS",
					"message": "Admin permissions required",
				},
			})
		}

		return c.JSON(http.StatusInternalServerError, map[string]interface{}{
			"success": false,
			"error": map[string]interface{}{
				"code":    "INTERNAL_SERVER_ERROR",
				"message": "Failed to retrieve user list",
				"details": err.Error(),
			},
		})
	}

	return c.JSON(http.StatusOK, map[string]interface{}{
		"success": true,
		"data":    response,
	})
}

// AssignUserRole handles POST /api/users/roles
func (h *UserManagementHandler) AssignUserRole(c echo.Context) error {
	// Extract user from JWT token
	user := c.Get("user").(*jwt.Token)
	claims := user.Claims.(jwt.MapClaims)

	// Get requester user ID from token
	requesterIDStr, ok := claims["user_id"].(string)
	if !ok {
		return c.JSON(http.StatusUnauthorized, map[string]interface{}{
			"success": false,
			"error": map[string]interface{}{
				"code":    "INVALID_TOKEN",
				"message": "Invalid user ID in token",
			},
		})
	}

	requesterID, err := uuid.Parse(requesterIDStr)
	if err != nil {
		return c.JSON(http.StatusUnauthorized, map[string]interface{}{
			"success": false,
			"error": map[string]interface{}{
				"code":    "INVALID_USER_ID",
				"message": "Invalid user ID format",
			},
		})
	}

	// Parse request body
	var req models.RoleAssignmentRequest
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
		validationErrors := h.formatValidationErrors(err)
		return c.JSON(http.StatusBadRequest, map[string]interface{}{
			"success": false,
			"error": map[string]interface{}{
				"code":    "VALIDATION_ERROR",
				"message": "Request validation failed",
				"details": validationErrors,
			},
		})
	}

	// Create context with timeout
	ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer cancel()

	// Assign role
	roleAssignment, err := h.userService.AssignUserRole(ctx, &req, requesterID)
	if err != nil {
		if strings.Contains(err.Error(), "insufficient permissions") {
			return c.JSON(http.StatusForbidden, map[string]interface{}{
				"success": false,
				"error": map[string]interface{}{
					"code":    "INSUFFICIENT_PERMISSIONS",
					"message": "Admin permissions required",
				},
			})
		}

		if strings.Contains(err.Error(), "user not found") {
			return c.JSON(http.StatusNotFound, map[string]interface{}{
				"success": false,
				"error": map[string]interface{}{
					"code":    "USER_NOT_FOUND",
					"message": "User not found",
				},
			})
		}

		if strings.Contains(err.Error(), "city not found") {
			return c.JSON(http.StatusBadRequest, map[string]interface{}{
				"success": false,
				"error": map[string]interface{}{
					"code":    "CITY_NOT_FOUND",
					"message": "City not found",
				},
			})
		}

		if strings.Contains(err.Error(), "sport not found") {
			return c.JSON(http.StatusBadRequest, map[string]interface{}{
				"success": false,
				"error": map[string]interface{}{
					"code":    "SPORT_NOT_FOUND",
					"message": "Sport not found",
				},
			})
		}

		if strings.Contains(err.Error(), "already has this role") {
			return c.JSON(http.StatusConflict, map[string]interface{}{
				"success": false,
				"error": map[string]interface{}{
					"code":    "ROLE_ALREADY_ASSIGNED",
					"message": "User already has this role for the specified city/sport",
				},
			})
		}

		return c.JSON(http.StatusInternalServerError, map[string]interface{}{
			"success": false,
			"error": map[string]interface{}{
				"code":    "INTERNAL_SERVER_ERROR",
				"message": "Failed to assign role",
				"details": err.Error(),
			},
		})
	}

	response := &models.RoleAssignmentResponse{
		RoleAssignmentID: roleAssignment.RoleAssignmentID,
		UserID:           roleAssignment.UserID,
		CityID:           roleAssignment.CityID,
		SportID:          roleAssignment.SportID,
		RoleName:         roleAssignment.RoleName,
		AssignedByUserID: roleAssignment.AssignedByUserID,
		IsActive:         roleAssignment.IsActive,
		CreatedAt:        roleAssignment.CreatedAt,
		Message:          "Role assigned successfully",
	}

	return c.JSON(http.StatusCreated, map[string]interface{}{
		"success": true,
		"data":    response,
	})
}

// RevokeUserRole handles DELETE /api/users/roles/:roleId
func (h *UserManagementHandler) RevokeUserRole(c echo.Context) error {
	// Extract user from JWT token
	user := c.Get("user").(*jwt.Token)
	claims := user.Claims.(jwt.MapClaims)

	// Get requester user ID from token
	requesterIDStr, ok := claims["user_id"].(string)
	if !ok {
		return c.JSON(http.StatusUnauthorized, map[string]interface{}{
			"success": false,
			"error": map[string]interface{}{
				"code":    "INVALID_TOKEN",
				"message": "Invalid user ID in token",
			},
		})
	}

	requesterID, err := uuid.Parse(requesterIDStr)
	if err != nil {
		return c.JSON(http.StatusUnauthorized, map[string]interface{}{
			"success": false,
			"error": map[string]interface{}{
				"code":    "INVALID_USER_ID",
				"message": "Invalid user ID format",
			},
		})
	}

	// Get role assignment ID from URL parameter
	roleIDStr := c.Param("roleId")
	roleID, err := uuid.Parse(roleIDStr)
	if err != nil {
		return c.JSON(http.StatusBadRequest, map[string]interface{}{
			"success": false,
			"error": map[string]interface{}{
				"code":    "INVALID_ROLE_ID",
				"message": "Invalid role assignment ID format",
			},
		})
	}

	// Create context with timeout
	ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer cancel()

	// Revoke role
	err = h.userService.RevokeUserRole(ctx, roleID, requesterID)
	if err != nil {
		if strings.Contains(err.Error(), "insufficient permissions") {
			return c.JSON(http.StatusForbidden, map[string]interface{}{
				"success": false,
				"error": map[string]interface{}{
					"code":    "INSUFFICIENT_PERMISSIONS",
					"message": "Admin permissions required",
				},
			})
		}

		if strings.Contains(err.Error(), "not found") {
			return c.JSON(http.StatusNotFound, map[string]interface{}{
				"success": false,
				"error": map[string]interface{}{
					"code":    "ROLE_NOT_FOUND",
					"message": "Role assignment not found",
				},
			})
		}

		if strings.Contains(err.Error(), "already inactive") {
			return c.JSON(http.StatusConflict, map[string]interface{}{
				"success": false,
				"error": map[string]interface{}{
					"code":    "ROLE_ALREADY_INACTIVE",
					"message": "Role assignment is already inactive",
				},
			})
		}

		return c.JSON(http.StatusInternalServerError, map[string]interface{}{
			"success": false,
			"error": map[string]interface{}{
				"code":    "INTERNAL_SERVER_ERROR",
				"message": "Failed to revoke role",
				"details": err.Error(),
			},
		})
	}

	return c.JSON(http.StatusOK, map[string]interface{}{
		"success": true,
		"data": map[string]interface{}{
			"message": "Role revoked successfully",
		},
	})
}

// GetUserRoles handles GET /api/users/:id/roles
func (h *UserManagementHandler) GetUserRoles(c echo.Context) error {
	// Extract user from JWT token
	user := c.Get("user").(*jwt.Token)
	claims := user.Claims.(jwt.MapClaims)

	// Get requester user ID from token
	requesterIDStr, ok := claims["user_id"].(string)
	if !ok {
		return c.JSON(http.StatusUnauthorized, map[string]interface{}{
			"success": false,
			"error": map[string]interface{}{
				"code":    "INVALID_TOKEN",
				"message": "Invalid user ID in token",
			},
		})
	}

	requesterID, err := uuid.Parse(requesterIDStr)
	if err != nil {
		return c.JSON(http.StatusUnauthorized, map[string]interface{}{
			"success": false,
			"error": map[string]interface{}{
				"code":    "INVALID_USER_ID",
				"message": "Invalid user ID format",
			},
		})
	}

	// Get target user ID from URL parameter
	userIDStr := c.Param("id")
	userID, err := uuid.Parse(userIDStr)
	if err != nil {
		return c.JSON(http.StatusBadRequest, map[string]interface{}{
			"success": false,
			"error": map[string]interface{}{
				"code":    "INVALID_USER_ID",
				"message": "Invalid user ID format",
			},
		})
	}

	// Create context with timeout
	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()

	// Get user roles
	roles, err := h.userService.GetUserRoles(ctx, userID, requesterID)
	if err != nil {
		if strings.Contains(err.Error(), "insufficient permissions") {
			return c.JSON(http.StatusForbidden, map[string]interface{}{
				"success": false,
				"error": map[string]interface{}{
					"code":    "INSUFFICIENT_PERMISSIONS",
					"message": "Admin permissions required",
				},
			})
		}

		return c.JSON(http.StatusInternalServerError, map[string]interface{}{
			"success": false,
			"error": map[string]interface{}{
				"code":    "INTERNAL_SERVER_ERROR",
				"message": "Failed to retrieve user roles",
				"details": err.Error(),
			},
		})
	}

	return c.JSON(http.StatusOK, map[string]interface{}{
		"success": true,
		"data":    roles,
	})
}

// SetViewPermission handles POST /api/users/permissions
func (h *UserManagementHandler) SetViewPermission(c echo.Context) error {
	// Extract user from JWT token
	user := c.Get("user").(*jwt.Token)
	claims := user.Claims.(jwt.MapClaims)

	// Get requester user ID from token
	requesterIDStr, ok := claims["user_id"].(string)
	if !ok {
		return c.JSON(http.StatusUnauthorized, map[string]interface{}{
			"success": false,
			"error": map[string]interface{}{
				"code":    "INVALID_TOKEN",
				"message": "Invalid user ID in token",
			},
		})
	}

	requesterID, err := uuid.Parse(requesterIDStr)
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
				"message": "Only super administrators can set view permissions",
			},
		})
	}

	// Parse request body
	var req models.ViewPermissionRequest
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
		validationErrors := h.formatValidationErrors(err)
		return c.JSON(http.StatusBadRequest, map[string]interface{}{
			"success": false,
			"error": map[string]interface{}{
				"code":    "VALIDATION_ERROR",
				"message": "Request validation failed",
				"details": validationErrors,
			},
		})
	}

	// Create context with timeout
	ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer cancel()

	// Set view permission
	permission, err := h.userService.SetViewPermission(ctx, &req, requesterID)
	if err != nil {
		if strings.Contains(err.Error(), "insufficient permissions") {
			return c.JSON(http.StatusForbidden, map[string]interface{}{
				"success": false,
				"error": map[string]interface{}{
					"code":    "INSUFFICIENT_PERMISSIONS",
					"message": "Super admin permissions required",
				},
			})
		}

		return c.JSON(http.StatusInternalServerError, map[string]interface{}{
			"success": false,
			"error": map[string]interface{}{
				"code":    "INTERNAL_SERVER_ERROR",
				"message": "Failed to set view permission",
				"details": err.Error(),
			},
		})
	}

	response := &models.ViewPermissionResponse{
		PermissionID:       permission.PermissionID,
		UserID:             permission.UserID,
		RoleName:           permission.RoleName,
		ViewName:           permission.ViewName,
		IsAllowed:          permission.IsAllowed,
		ConfiguredByUserID: permission.ConfiguredByUserID,
		CreatedAt:          permission.CreatedAt,
		UpdatedAt:          permission.UpdatedAt,
		Message:            "View permission set successfully",
	}

	return c.JSON(http.StatusOK, map[string]interface{}{
		"success": true,
		"data":    response,
	})
}

// UpdateAccountStatus handles PATCH /api/users/:id/status
func (h *UserManagementHandler) UpdateAccountStatus(c echo.Context) error {
	// Extract user from JWT token
	user := c.Get("user").(*jwt.Token)
	claims := user.Claims.(jwt.MapClaims)

	// Get requester user ID from token
	requesterIDStr, ok := claims["user_id"].(string)
	if !ok {
		return c.JSON(http.StatusUnauthorized, map[string]interface{}{
			"success": false,
			"error": map[string]interface{}{
				"code":    "INVALID_TOKEN",
				"message": "Invalid user ID in token",
			},
		})
	}

	requesterID, err := uuid.Parse(requesterIDStr)
	if err != nil {
		return c.JSON(http.StatusUnauthorized, map[string]interface{}{
			"success": false,
			"error": map[string]interface{}{
				"code":    "INVALID_USER_ID",
				"message": "Invalid user ID format",
			},
		})
	}

	// Get target user ID from URL parameter
	userIDStr := c.Param("id")
	userID, err := uuid.Parse(userIDStr)
	if err != nil {
		return c.JSON(http.StatusBadRequest, map[string]interface{}{
			"success": false,
			"error": map[string]interface{}{
				"code":    "INVALID_USER_ID",
				"message": "Invalid user ID format",
			},
		})
	}

	// Parse request body
	var req models.AccountStatusUpdateRequest
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
		validationErrors := h.formatValidationErrors(err)
		return c.JSON(http.StatusBadRequest, map[string]interface{}{
			"success": false,
			"error": map[string]interface{}{
				"code":    "VALIDATION_ERROR",
				"message": "Request validation failed",
				"details": validationErrors,
			},
		})
	}

	// Create context with timeout
	ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer cancel()

	// Update account status
	err = h.userService.UpdateAccountStatus(ctx, userID, req.Status, req.Reason, requesterID)
	if err != nil {
		if strings.Contains(err.Error(), "insufficient permissions") {
			return c.JSON(http.StatusForbidden, map[string]interface{}{
				"success": false,
				"error": map[string]interface{}{
					"code":    "INSUFFICIENT_PERMISSIONS",
					"message": "Admin permissions required",
				},
			})
		}

		if strings.Contains(err.Error(), "user not found") {
			return c.JSON(http.StatusNotFound, map[string]interface{}{
				"success": false,
				"error": map[string]interface{}{
					"code":    "USER_NOT_FOUND",
					"message": "User not found",
				},
			})
		}

		if strings.Contains(err.Error(), "invalid account status") {
			return c.JSON(http.StatusBadRequest, map[string]interface{}{
				"success": false,
				"error": map[string]interface{}{
					"code":    "INVALID_STATUS",
					"message": "Invalid account status",
				},
			})
		}

		return c.JSON(http.StatusInternalServerError, map[string]interface{}{
			"success": false,
			"error": map[string]interface{}{
				"code":    "INTERNAL_SERVER_ERROR",
				"message": "Failed to update account status",
				"details": err.Error(),
			},
		})
	}

	return c.JSON(http.StatusOK, map[string]interface{}{
		"success": true,
		"data": map[string]interface{}{
			"message": "Account status updated successfully",
		},
	})
}

// Helper method to format validation errors
func (h *UserManagementHandler) formatValidationErrors(err error) map[string]string {
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
	return validationErrors
}

// Hierarchical User Registration Methods

// RegisterCityAdmin handles POST /api/users/register/city-admin (Super Admin only)
func (h *UserManagementHandler) RegisterCityAdmin(c echo.Context) error {
	// Extract user from JWT token
	user := c.Get("user").(*jwt.Token)
	claims := user.Claims.(jwt.MapClaims)

	// Get requester user ID from token
	requesterIDStr, ok := claims["user_id"].(string)
	if !ok {
		return c.JSON(http.StatusUnauthorized, map[string]interface{}{
			"success": false,
			"error": map[string]interface{}{
				"code":    "INVALID_TOKEN",
				"message": "Invalid user ID in token",
			},
		})
	}

	requesterID, err := uuid.Parse(requesterIDStr)
	if err != nil {
		return c.JSON(http.StatusUnauthorized, map[string]interface{}{
			"success": false,
			"error": map[string]interface{}{
				"code":    "INVALID_TOKEN",
				"message": "Invalid user ID format in token",
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
				"message": "Invalid request body",
			},
		})
	}

	// Validate request
	if err := h.validator.Struct(&req); err != nil {
		return c.JSON(http.StatusBadRequest, map[string]interface{}{
			"success": false,
			"error": map[string]interface{}{
				"code":    "VALIDATION_ERROR",
				"message": "Validation failed",
				"details": h.formatValidationErrors(err),
			},
		})
	}

	// Use the existing admin service for registration
	adminService := services.NewAdminService(h.userService.GetDB(), nil) // Pass nil for config if not needed
	response, err := adminService.RegisterAdmin(context.Background(), &req, requesterID)
	if err != nil {
		return c.JSON(http.StatusInternalServerError, map[string]interface{}{
			"success": false,
			"error": map[string]interface{}{
				"code":    "REGISTRATION_ERROR",
				"message": err.Error(),
			},
		})
	}

	return c.JSON(http.StatusCreated, map[string]interface{}{
		"success": true,
		"data":    response,
	})
}

// RegisterOwner handles POST /api/users/register/owner (City Admin only)
func (h *UserManagementHandler) RegisterOwner(c echo.Context) error {
	return h.registerUserWithRole(c, models.RoleOwner)
}

// RegisterReferee handles POST /api/users/register/referee (City Admin only)
func (h *UserManagementHandler) RegisterReferee(c echo.Context) error {
	return h.registerUserWithRole(c, models.RoleReferee)
}

// RegisterPlayer handles POST /api/users/register/player (Owner only)
func (h *UserManagementHandler) RegisterPlayer(c echo.Context) error {
	return h.registerUserWithRole(c, models.RolePlayer)
}

// RegisterCoach handles POST /api/users/register/coach (Owner only)
func (h *UserManagementHandler) RegisterCoach(c echo.Context) error {
	return h.registerUserWithRole(c, models.RoleCoach)
}

// ValidateEmailUniqueness handles GET /api/users/validate-email
func (h *UserManagementHandler) ValidateEmailUniqueness(c echo.Context) error {
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

	// Check if email exists in user_profiles table
	var exists bool
	err := h.userService.GetDB().GetConnection().QueryRow(
		context.Background(),
		"SELECT EXISTS(SELECT 1 FROM user_profiles WHERE email = $1)",
		email,
	).Scan(&exists)

	if err != nil {
		return c.JSON(http.StatusInternalServerError, map[string]interface{}{
			"success": false,
			"error": map[string]interface{}{
				"code":    "DATABASE_ERROR",
				"message": "Error checking email uniqueness",
			},
		})
	}

	return c.JSON(http.StatusOK, map[string]interface{}{
		"success": true,
		"data": map[string]interface{}{
			"is_valid":  true,
			"is_unique": !exists,
			"message": func() string {
				if exists {
					return "Email is already registered"
				}
				return "Email is available"
			}(),
		},
	})
}

// Helper method to register users with specific roles
func (h *UserManagementHandler) registerUserWithRole(c echo.Context, role string) error {
	// Extract user from JWT token
	user := c.Get("user").(*jwt.Token)
	claims := user.Claims.(jwt.MapClaims)

	// Get requester user ID from token
	requesterIDStr, ok := claims["user_id"].(string)
	if !ok {
		return c.JSON(http.StatusUnauthorized, map[string]interface{}{
			"success": false,
			"error": map[string]interface{}{
				"code":    "INVALID_TOKEN",
				"message": "Invalid user ID in token",
			},
		})
	}

	requesterID, err := uuid.Parse(requesterIDStr)
	if err != nil {
		return c.JSON(http.StatusUnauthorized, map[string]interface{}{
			"success": false,
			"error": map[string]interface{}{
				"code":    "INVALID_TOKEN",
				"message": "Invalid user ID format in token",
			},
		})
	}

	// Parse request body - using a generic registration request
	var req struct {
		FirstName      string `json:"first_name" validate:"required,min=2,max=100"`
		LastName       string `json:"last_name" validate:"required,min=2,max=100"`
		Email          string `json:"email" validate:"required,email"`
		Phone          string `json:"phone,omitempty" validate:"omitempty,min=10,max=20"`
		Identification string `json:"identification,omitempty" validate:"omitempty,min=5,max=50"`
		PhotoURL       string `json:"photo_url,omitempty" validate:"omitempty,url"`
		CityID         string `json:"city_id,omitempty" validate:"omitempty,uuid"`
		SportID        string `json:"sport_id,omitempty" validate:"omitempty,uuid"`
		AccountStatus  string `json:"account_status,omitempty" validate:"omitempty,oneof=active suspended payment_pending disabled"`

		// Player-specific fields
		DateOfBirth      string `json:"date_of_birth,omitempty"`
		BloodType        string `json:"blood_type,omitempty"`
		Position         string `json:"position,omitempty"`
		JerseyNumber     *int   `json:"jersey_number,omitempty"`
		EmergencyContact struct {
			Name         string `json:"name,omitempty"`
			Phone        string `json:"phone,omitempty"`
			Relationship string `json:"relationship,omitempty"`
		} `json:"emergency_contact,omitempty"`
		MedicalInfo struct {
			Allergies         string `json:"allergies,omitempty"`
			Medications       string `json:"medications,omitempty"`
			MedicalConditions string `json:"medical_conditions,omitempty"`
		} `json:"medical_info,omitempty"`

		// Coach/Referee-specific fields
		CertificationLevel string `json:"certification_level,omitempty"`
		ExperienceYears    *int   `json:"experience_years,omitempty"`
		Specialization     string `json:"specialization,omitempty"`
	}

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
	if err := h.validator.Struct(&req); err != nil {
		return c.JSON(http.StatusBadRequest, map[string]interface{}{
			"success": false,
			"error": map[string]interface{}{
				"code":    "VALIDATION_ERROR",
				"message": "Validation failed",
				"details": h.formatValidationErrors(err),
			},
		})
	}

	// Generate temporary password
	tempPassword := h.generateTemporaryPassword()
	hashedPassword, err := bcrypt.GenerateFromPassword([]byte(tempPassword), bcrypt.DefaultCost)
	if err != nil {
		return c.JSON(http.StatusInternalServerError, map[string]interface{}{
			"success": false,
			"error": map[string]interface{}{
				"code":    "PASSWORD_HASH_ERROR",
				"message": "Error processing password",
			},
		})
	}

	// Set default account status
	accountStatus := req.AccountStatus
	if accountStatus == "" {
		accountStatus = models.AccountStatusActive
	}

	// Create user in user_profiles table
	var userID uuid.UUID
	var phone, identification, photoURL *string
	if req.Phone != "" {
		phone = &req.Phone
	}
	if req.Identification != "" {
		identification = &req.Identification
	}
	if req.PhotoURL != "" {
		photoURL = &req.PhotoURL
	}

	err = h.userService.GetDB().GetConnection().QueryRow(
		context.Background(),
		`INSERT INTO user_profiles (user_id, email, password_hash, first_name, last_name, phone, 
		 identification, photo_url, primary_role, is_active, account_status, failed_login_attempts, 
		 two_factor_enabled, created_at, updated_at) 
		 VALUES (gen_random_uuid(), $1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, NOW(), NOW()) 
		 RETURNING user_id`,
		req.Email,
		string(hashedPassword),
		req.FirstName,
		req.LastName,
		phone,
		identification,
		photoURL,
		role,
		true, // is_active
		accountStatus,
		0,     // failed_login_attempts
		false, // two_factor_enabled
	).Scan(&userID)

	if err != nil {
		if strings.Contains(err.Error(), "unique constraint") || strings.Contains(err.Error(), "duplicate key") {
			return c.JSON(http.StatusConflict, map[string]interface{}{
				"success": false,
				"error": map[string]interface{}{
					"code":    "EMAIL_EXISTS",
					"message": "Email address is already registered",
				},
			})
		}
		return c.JSON(http.StatusInternalServerError, map[string]interface{}{
			"success": false,
			"error": map[string]interface{}{
				"code":    "USER_CREATION_ERROR",
				"message": "Error creating user: " + err.Error(),
			},
		})
	}

	// Create role assignment if city_id and sport_id are provided
	var roleAssignmentID *uuid.UUID
	if req.CityID != "" && req.SportID != "" {
		cityUUID, err := uuid.Parse(req.CityID)
		if err != nil {
			return c.JSON(http.StatusBadRequest, map[string]interface{}{
				"success": false,
				"error": map[string]interface{}{
					"code":    "INVALID_CITY_ID",
					"message": "Invalid city ID format",
				},
			})
		}

		sportUUID, err := uuid.Parse(req.SportID)
		if err != nil {
			return c.JSON(http.StatusBadRequest, map[string]interface{}{
				"success": false,
				"error": map[string]interface{}{
					"code":    "INVALID_SPORT_ID",
					"message": "Invalid sport ID format",
				},
			})
		}

		var assignmentID uuid.UUID
		err = h.userService.GetDB().GetConnection().QueryRow(
			context.Background(),
			`INSERT INTO user_roles_by_city_sport (role_assignment_id, user_id, city_id, sport_id, 
			 role_name, assigned_by_user_id, is_active, created_at) 
			 VALUES (gen_random_uuid(), $1, $2, $3, $4, $5, $6, NOW()) 
			 RETURNING role_assignment_id`,
			userID, cityUUID, sportUUID, role, requesterID, true,
		).Scan(&assignmentID)

		if err != nil {
			// If role assignment fails, we should probably delete the user too
			h.userService.GetDB().GetConnection().Exec(
				context.Background(),
				"DELETE FROM user_profiles WHERE user_id = $1",
				userID,
			)
			return c.JSON(http.StatusInternalServerError, map[string]interface{}{
				"success": false,
				"error": map[string]interface{}{
					"code":    "ROLE_ASSIGNMENT_ERROR",
					"message": "Error assigning role: " + err.Error(),
				},
			})
		}
		roleAssignmentID = &assignmentID
	}

	// Handle player-specific data
	if role == models.RolePlayer && req.DateOfBirth != "" {
		// Parse date of birth
		dateOfBirth, err := time.Parse("2006-01-02", req.DateOfBirth)
		if err != nil {
			return c.JSON(http.StatusBadRequest, map[string]interface{}{
				"success": false,
				"error": map[string]interface{}{
					"code":    "INVALID_DATE_FORMAT",
					"message": "Invalid date of birth format. Use YYYY-MM-DD",
				},
			})
		}

		// Create player record
		var emergencyContactJSON, medicalInfoJSON *string
		if req.EmergencyContact.Name != "" {
			emergencyContact := map[string]string{
				"name":         req.EmergencyContact.Name,
				"phone":        req.EmergencyContact.Phone,
				"relationship": req.EmergencyContact.Relationship,
			}
			emergencyContactBytes, _ := json.Marshal(emergencyContact)
			emergencyContactStr := string(emergencyContactBytes)
			emergencyContactJSON = &emergencyContactStr
		}

		if req.MedicalInfo.Allergies != "" || req.MedicalInfo.Medications != "" || req.MedicalInfo.MedicalConditions != "" {
			medicalInfo := map[string]string{
				"allergies":          req.MedicalInfo.Allergies,
				"medications":        req.MedicalInfo.Medications,
				"medical_conditions": req.MedicalInfo.MedicalConditions,
			}
			medicalInfoBytes, _ := json.Marshal(medicalInfo)
			medicalInfoStr := string(medicalInfoBytes)
			medicalInfoJSON = &medicalInfoStr
		}

		var bloodType, position *string
		if req.BloodType != "" {
			bloodType = &req.BloodType
		}
		if req.Position != "" {
			position = &req.Position
		}

		_, err = h.userService.GetDB().GetConnection().Exec(
			context.Background(),
			`INSERT INTO players (player_id, user_profile_id, first_name, last_name, date_of_birth, 
			 identification, blood_type, email, phone, photo_url, emergency_contact, medical_info, 
			 preferred_position, is_active, created_at, updated_at) 
			 VALUES (gen_random_uuid(), $1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, NOW(), NOW())`,
			userID,
			req.FirstName,
			req.LastName,
			dateOfBirth,
			identification,
			bloodType,
			req.Email,
			phone,
			photoURL,
			emergencyContactJSON,
			medicalInfoJSON,
			position,
			true, // is_active
		)

		if err != nil {
			return c.JSON(http.StatusInternalServerError, map[string]interface{}{
				"success": false,
				"error": map[string]interface{}{
					"code":    "PLAYER_CREATION_ERROR",
					"message": "Error creating player record: " + err.Error(),
				},
			})
		}
	}

	// Prepare response
	response := map[string]interface{}{
		"user_id":            userID,
		"email":              req.Email,
		"first_name":         req.FirstName,
		"last_name":          req.LastName,
		"primary_role":       role,
		"temporary_password": tempPassword,
		"message":            "User registered successfully",
	}

	if roleAssignmentID != nil {
		response["role_assignment_id"] = *roleAssignmentID
	}

	return c.JSON(http.StatusCreated, map[string]interface{}{
		"success": true,
		"data":    response,
	})
}

// Helper method to generate temporary password
func (h *UserManagementHandler) generateTemporaryPassword() string {
	const charset = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789!@#$%^&*"
	const length = 12

	password := make([]byte, length)
	for i := range password {
		password[i] = charset[time.Now().UnixNano()%int64(len(charset))]
	}
	return string(password)
}
