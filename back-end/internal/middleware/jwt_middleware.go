package middleware

import (
	"mowesport/internal/models"
	"net/http"
	"strings"

	"github.com/golang-jwt/jwt/v5"
	"github.com/labstack/echo/v4"
)

// JWTConfig holds JWT configuration
type JWTConfig struct {
	Secret []byte
}

// NewJWTConfig creates a new JWT configuration
func NewJWTConfig(secret string) *JWTConfig {
	return &JWTConfig{
		Secret: []byte(secret),
	}
}

// JWTMiddleware creates a JWT middleware with custom validation
func (config *JWTConfig) JWTMiddleware() echo.MiddlewareFunc {
	return func(next echo.HandlerFunc) echo.HandlerFunc {
		return func(c echo.Context) error {
			// Get token from Authorization header
			authHeader := c.Request().Header.Get("Authorization")
			if authHeader == "" {
				return c.JSON(http.StatusUnauthorized, map[string]interface{}{
					"success": false,
					"error": map[string]interface{}{
						"code":    "MISSING_TOKEN",
						"message": "Authorization token is required",
					},
				})
			}

			// Check if it starts with "Bearer "
			if !strings.HasPrefix(authHeader, "Bearer ") {
				return c.JSON(http.StatusUnauthorized, map[string]interface{}{
					"success": false,
					"error": map[string]interface{}{
						"code":    "INVALID_TOKEN_FORMAT",
						"message": "Token must be in Bearer format",
					},
				})
			}

			// Extract token
			tokenString := strings.TrimPrefix(authHeader, "Bearer ")

			// Parse and validate token
			token, err := jwt.Parse(tokenString, func(token *jwt.Token) (interface{}, error) {
				// Validate signing method
				if _, ok := token.Method.(*jwt.SigningMethodHMAC); !ok {
					return nil, jwt.ErrSignatureInvalid
				}
				return config.Secret, nil
			})

			if err != nil {
				return c.JSON(http.StatusUnauthorized, map[string]interface{}{
					"success": false,
					"error": map[string]interface{}{
						"code":    "INVALID_TOKEN",
						"message": "Invalid or expired token",
					},
				})
			}

			if !token.Valid {
				return c.JSON(http.StatusUnauthorized, map[string]interface{}{
					"success": false,
					"error": map[string]interface{}{
						"code":    "INVALID_TOKEN",
						"message": "Token is not valid",
					},
				})
			}

			// Check token type (should be access token)
			claims, ok := token.Claims.(jwt.MapClaims)
			if !ok {
				return c.JSON(http.StatusUnauthorized, map[string]interface{}{
					"success": false,
					"error": map[string]interface{}{
						"code":    "INVALID_TOKEN_CLAIMS",
						"message": "Invalid token claims",
					},
				})
			}

			tokenType, ok := claims["type"].(string)
			if !ok || tokenType != "access" {
				return c.JSON(http.StatusUnauthorized, map[string]interface{}{
					"success": false,
					"error": map[string]interface{}{
						"code":    "INVALID_TOKEN_TYPE",
						"message": "Invalid token type",
					},
				})
			}

			// Store token in context for use in handlers
			c.Set("user", token)

			return next(c)
		}
	}
}

// RequireRole creates middleware that requires specific roles
func RequireRole(allowedRoles ...string) echo.MiddlewareFunc {
	return func(next echo.HandlerFunc) echo.HandlerFunc {
		return func(c echo.Context) error {
			// Get user from JWT token (assumes JWT middleware has already run)
			user := c.Get("user").(*jwt.Token)
			claims := user.Claims.(jwt.MapClaims)

			// Check if user has required role
			userRole, ok := claims["primary_role"].(string)
			if !ok {
				return c.JSON(http.StatusForbidden, map[string]interface{}{
					"success": false,
					"error": map[string]interface{}{
						"code":    "MISSING_ROLE",
						"message": "User role not found in token",
					},
				})
			}

			// Check if user role is in allowed roles
			roleAllowed := false
			for _, allowedRole := range allowedRoles {
				if userRole == allowedRole {
					roleAllowed = true
					break
				}
			}

			if !roleAllowed {
				return c.JSON(http.StatusForbidden, map[string]interface{}{
					"success": false,
					"error": map[string]interface{}{
						"code":    "INSUFFICIENT_PERMISSIONS",
						"message": "Insufficient permissions for this resource",
					},
				})
			}

			return next(c)
		}
	}
}

// RequireSuperAdminRole middleware for super admin only endpoints
func RequireSuperAdminRole() echo.MiddlewareFunc {
	return RequireRole(models.RoleSuperAdmin)
}

// RequireAdminRole middleware for admin endpoints (super admin or city admin)
func RequireAdminRole() echo.MiddlewareFunc {
	return RequireRole(models.RoleSuperAdmin, models.RoleCityAdmin)
}

// RequireOwnerRole middleware for owner endpoints
func RequireOwnerRole() echo.MiddlewareFunc {
	return RequireRole(models.RoleSuperAdmin, models.RoleCityAdmin, models.RoleOwner)
}
