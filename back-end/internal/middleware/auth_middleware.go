package middleware

import (
	"mowesport/internal/models"
	"net/http"

	"github.com/golang-jwt/jwt/v5"
	"github.com/labstack/echo/v4"
)

// RequireSuperAdmin middleware ensures only super admins can access the endpoint
func RequireSuperAdmin(next echo.HandlerFunc) echo.HandlerFunc {
	return func(c echo.Context) error {
		// Get user from JWT token (assumes JWT middleware has already run)
		user := c.Get("user").(*jwt.Token)
		claims := user.Claims.(jwt.MapClaims)

		// Check if user has super_admin role
		userRole, ok := claims["primary_role"].(string)
		if !ok || userRole != models.RoleSuperAdmin {
			return c.JSON(http.StatusForbidden, map[string]interface{}{
				"success": false,
				"error": map[string]interface{}{
					"code":    "INSUFFICIENT_PERMISSIONS",
					"message": "Super administrator access required",
				},
			})
		}

		return next(c)
	}
}

// RequireAdmin middleware ensures only admins (city_admin or super_admin) can access the endpoint
func RequireAdmin(next echo.HandlerFunc) echo.HandlerFunc {
	return func(c echo.Context) error {
		// Get user from JWT token (assumes JWT middleware has already run)
		user := c.Get("user").(*jwt.Token)
		claims := user.Claims.(jwt.MapClaims)

		// Check if user has admin role
		userRole, ok := claims["primary_role"].(string)
		if !ok || (userRole != models.RoleSuperAdmin && userRole != models.RoleCityAdmin) {
			return c.JSON(http.StatusForbidden, map[string]interface{}{
				"success": false,
				"error": map[string]interface{}{
					"code":    "INSUFFICIENT_PERMISSIONS",
					"message": "Administrator access required",
				},
			})
		}

		return next(c)
	}
}

// RequireAuthentication middleware ensures user is authenticated
func RequireAuthentication(next echo.HandlerFunc) echo.HandlerFunc {
	return func(c echo.Context) error {
		// Get user from JWT token (assumes JWT middleware has already run)
		user := c.Get("user")
		if user == nil {
			return c.JSON(http.StatusUnauthorized, map[string]interface{}{
				"success": false,
				"error": map[string]interface{}{
					"code":    "AUTHENTICATION_REQUIRED",
					"message": "Authentication required",
				},
			})
		}

		return next(c)
	}
}
