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
