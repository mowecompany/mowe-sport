package server

import (
	"context"
	"mowesport/internal/handlers"
	"mowesport/internal/middleware"
	"mowesport/internal/models"
	"net/http"
	"strings"
	"time"

	"github.com/golang-jwt/jwt/v5"
	"github.com/labstack/echo/v4"
	"golang.org/x/crypto/bcrypt"
)

func (s *Server) setupRoutes() {
	// Health check endpoint
	s.router.GET("/api/health", s.handleHealthCheck)

	// Test database endpoint
	s.router.GET("/api/test-db", s.handleTestDB)

	// API routes group
	api := s.router.Group("/api")

	// Public routes
	api.GET("/cities", s.handleGetCities)
	api.GET("/sports", s.handleGetSports)

	// JWT configuration
	jwtConfig := middleware.NewJWTConfig(s.config.JWTSecret)

	// Auth routes
	auth := api.Group("/auth")
	authHandler := handlers.NewAuthHandler(s.db, s.config.JWTSecret)

	// Public auth endpoints
	auth.POST("/login", authHandler.Login)
	auth.POST("/signup", s.handleSignup) // Keep existing signup for now
	auth.POST("/forgot-password", authHandler.RequestPasswordRecovery)
	auth.POST("/reset-password", authHandler.ResetPassword)
	auth.POST("/refresh", authHandler.RefreshToken)

	// Protected auth endpoints (require authentication)
	authProtected := auth.Group("")
	authProtected.Use(jwtConfig.JWTMiddleware())
	authProtected.POST("/logout", authHandler.Logout)
	authProtected.GET("/profile", authHandler.GetProfile)
	authProtected.POST("/2fa/setup", authHandler.Setup2FA)
	authProtected.POST("/2fa/verify", authHandler.Verify2FA)
	authProtected.POST("/2fa/disable", authHandler.Disable2FA)

	// Protected routes
	protected := api.Group("/protected")
	protected.Use(jwtConfig.JWTMiddleware())
	protected.GET("/profile", s.handleProfile) // Example protected route

	// Admin routes (require authentication)
	admin := api.Group("/admin")
	admin.Use(jwtConfig.JWTMiddleware())

	// Import handlers
	adminHandler := handlers.NewAdminHandler(s.db)

	// Admin registration endpoint (requires super admin)
	admin.POST("/register", middleware.RequireSuperAdminRole()(adminHandler.RegisterAdmin))

	// Email validation endpoint (requires authentication)
	admin.GET("/validate-email", adminHandler.ValidateEmail)

	// Admin list endpoint (requires super admin)
	admin.GET("/list", middleware.RequireSuperAdminRole()(adminHandler.GetAdminList))

	// User management routes (require authentication)
	users := api.Group("/users")
	users.Use(jwtConfig.JWTMiddleware())

	// Import user management handler
	userHandler := handlers.NewUserManagementHandler(s.db)

	// User CRUD endpoints (require admin permissions)
	users.GET("", middleware.RequireAdminRole()(userHandler.GetUserList))
	users.GET("/:id", middleware.RequireAdminRole()(userHandler.GetUserProfile))
	users.PUT("/:id", middleware.RequireAdminRole()(userHandler.UpdateUserProfile))
	users.PATCH("/:id/status", middleware.RequireAdminRole()(userHandler.UpdateAccountStatus))

	// Role management endpoints (require admin permissions)
	users.POST("/roles", middleware.RequireAdminRole()(userHandler.AssignUserRole))
	users.DELETE("/roles/:roleId", middleware.RequireAdminRole()(userHandler.RevokeUserRole))
	users.GET("/:id/roles", middleware.RequireAdminRole()(userHandler.GetUserRoles))

	// View permission endpoints (require super admin permissions)
	users.POST("/permissions", middleware.RequireSuperAdminRole()(userHandler.SetViewPermission))
}

func (s *Server) handleHealthCheck(c echo.Context) error {
	return c.JSON(http.StatusOK, map[string]string{
		"status":  "OK",
		"message": "Server is running",
	})
}

func (s *Server) handleTestDB(c echo.Context) error {
	var version string
	err := s.db.GetConnection().QueryRow(context.Background(), "SELECT version()").Scan(&version)
	if err != nil {
		return c.JSON(http.StatusInternalServerError, map[string]string{
			"error": "Database connection failed",
		})
	}

	return c.JSON(http.StatusOK, map[string]string{
		"status":   "OK",
		"database": "Connected",
		"version":  version,
	})
}

func (s *Server) handleLogin(c echo.Context) error {
	var req models.LoginRequest
	if err := c.Bind(&req); err != nil {
		return c.JSON(http.StatusBadRequest, map[string]interface{}{
			"success": false,
			"error": map[string]interface{}{
				"code":    "INVALID_REQUEST_BODY",
				"message": "Invalid request body",
			},
		})
	}

	// Search user by email in user_profiles table
	var userProfile models.UserProfile
	err := s.db.GetConnection().QueryRow(
		context.Background(),
		`SELECT user_id, email, password_hash, first_name, last_name, primary_role, 
		 is_active, account_status, failed_login_attempts, locked_until 
		 FROM user_profiles WHERE email = $1`,
		req.Email,
	).Scan(&userProfile.UserID, &userProfile.Email, &userProfile.PasswordHash,
		&userProfile.FirstName, &userProfile.LastName, &userProfile.PrimaryRole,
		&userProfile.IsActive, &userProfile.AccountStatus,
		&userProfile.FailedLoginAttempts, &userProfile.LockedUntil)

	if err != nil {
		return c.JSON(http.StatusNotFound, map[string]interface{}{
			"success": false,
			"error": map[string]interface{}{
				"code":    "USER_NOT_FOUND",
				"message": "User not found",
			},
		})
	}

	// Check if account is active
	if !userProfile.IsActive {
		return c.JSON(http.StatusForbidden, map[string]interface{}{
			"success": false,
			"error": map[string]interface{}{
				"code":    "ACCOUNT_INACTIVE",
				"message": "Account is inactive",
			},
		})
	}

	// Check account status
	if userProfile.AccountStatus != models.AccountStatusActive {
		return c.JSON(http.StatusForbidden, map[string]interface{}{
			"success": false,
			"error": map[string]interface{}{
				"code":    "ACCOUNT_" + strings.ToUpper(userProfile.AccountStatus),
				"message": "Account is " + userProfile.AccountStatus,
			},
		})
	}

	// Check if account is locked
	if userProfile.LockedUntil != nil && time.Now().Before(*userProfile.LockedUntil) {
		return c.JSON(http.StatusForbidden, map[string]interface{}{
			"success": false,
			"error": map[string]interface{}{
				"code":    "ACCOUNT_LOCKED",
				"message": "Account is temporarily locked due to failed login attempts",
			},
		})
	}

	// Verify password
	if err := bcrypt.CompareHashAndPassword([]byte(userProfile.PasswordHash), []byte(req.Password)); err != nil {
		// Increment failed login attempts
		s.db.GetConnection().Exec(
			context.Background(),
			"UPDATE user_profiles SET failed_login_attempts = failed_login_attempts + 1 WHERE user_id = $1",
			userProfile.UserID,
		)

		return c.JSON(http.StatusUnauthorized, map[string]interface{}{
			"success": false,
			"error": map[string]interface{}{
				"code":    "INVALID_CREDENTIALS",
				"message": "Invalid credentials",
			},
		})
	}

	// Reset failed login attempts and update last login
	s.db.GetConnection().Exec(
		context.Background(),
		"UPDATE user_profiles SET failed_login_attempts = 0, locked_until = NULL, last_login_at = NOW() WHERE user_id = $1",
		userProfile.UserID,
	)

	// Generate JWT with proper claims
	token := jwt.NewWithClaims(jwt.SigningMethodHS256, jwt.MapClaims{
		"user_id":      userProfile.UserID.String(),
		"email":        userProfile.Email,
		"first_name":   userProfile.FirstName,
		"last_name":    userProfile.LastName,
		"primary_role": userProfile.PrimaryRole,
		"type":         "access",
		"exp":          time.Now().Add(time.Hour * 72).Unix(),
		"iat":          time.Now().Unix(),
	})

	tokenString, err := token.SignedString([]byte(s.config.JWTSecret))
	if err != nil {
		return c.JSON(http.StatusInternalServerError, map[string]interface{}{
			"success": false,
			"error": map[string]interface{}{
				"code":    "TOKEN_GENERATION_ERROR",
				"message": "Error generating token",
			},
		})
	}

	// Generate refresh token
	refreshToken := jwt.NewWithClaims(jwt.SigningMethodHS256, jwt.MapClaims{
		"user_id": userProfile.UserID.String(),
		"type":    "refresh",
		"exp":     time.Now().Add(7 * 24 * time.Hour).Unix(), // 7 days
		"iat":     time.Now().Unix(),
	})

	refreshTokenString, err := refreshToken.SignedString([]byte(s.config.JWTSecret))
	if err != nil {
		return c.JSON(http.StatusInternalServerError, map[string]interface{}{
			"success": false,
			"error": map[string]interface{}{
				"code":    "REFRESH_TOKEN_GENERATION_ERROR",
				"message": "Error generating refresh token",
			},
		})
	}

	return c.JSON(http.StatusOK, map[string]interface{}{
		"success": true,
		"data": models.LoginResponse{
			UserID:       userProfile.UserID,
			Email:        userProfile.Email,
			FirstName:    userProfile.FirstName,
			LastName:     userProfile.LastName,
			PrimaryRole:  userProfile.PrimaryRole,
			Token:        tokenString,
			RefreshToken: refreshTokenString,
			ExpiresIn:    72 * 3600, // 72 hours in seconds
		},
	})
}

func (s *Server) handleSignup(c echo.Context) error {
	var req models.SignupRequest
	if err := c.Bind(&req); err != nil {
		return c.JSON(http.StatusBadRequest, map[string]interface{}{
			"success": false,
			"error": map[string]interface{}{
				"code":    "INVALID_REQUEST_BODY",
				"message": "Invalid request body",
			},
		})
	}

	// Validate required fields
	if req.FirstName == "" || req.LastName == "" || req.Email == "" || req.Password == "" {
		return c.JSON(http.StatusBadRequest, map[string]interface{}{
			"success": false,
			"error": map[string]interface{}{
				"code":    "MISSING_REQUIRED_FIELDS",
				"message": "First name, last name, email and password are required",
			},
		})
	}

	// Hash the password
	hashedPassword, err := bcrypt.GenerateFromPassword([]byte(req.Password), bcrypt.DefaultCost)
	if err != nil {
		return c.JSON(http.StatusInternalServerError, map[string]interface{}{
			"success": false,
			"error": map[string]interface{}{
				"code":    "PASSWORD_HASH_ERROR",
				"message": "Error processing password",
			},
		})
	}

	// Insert user into user_profiles table
	var userProfile models.UserProfile
	var phone *string
	if req.Phone != "" {
		phone = &req.Phone
	}

	err = s.db.GetConnection().QueryRow(
		context.Background(),
		`INSERT INTO user_profiles (user_id, email, password_hash, first_name, last_name, phone, 
		 primary_role, is_active, account_status, failed_login_attempts, two_factor_enabled, 
		 created_at, updated_at) 
		 VALUES (gen_random_uuid(), $1, $2, $3, $4, $5, $6, $7, $8, $9, $10, NOW(), NOW()) 
		 RETURNING user_id, first_name, last_name, email, created_at`,
		req.Email,
		string(hashedPassword),
		req.FirstName,
		req.LastName,
		phone,
		models.RoleClient, // Default role for signup
		true,              // is_active
		models.AccountStatusActive,
		0,     // failed_login_attempts
		false, // two_factor_enabled
	).Scan(&userProfile.UserID, &userProfile.FirstName, &userProfile.LastName,
		&userProfile.Email, &userProfile.CreatedAt)

	if err != nil {
		if strings.Contains(err.Error(), "unique constraint") || strings.Contains(err.Error(), "duplicate key") {
			return c.JSON(http.StatusConflict, map[string]interface{}{
				"success": false,
				"error": map[string]interface{}{
					"code":    "EMAIL_ALREADY_EXISTS",
					"message": "Email already exists",
				},
			})
		}
		return c.JSON(http.StatusInternalServerError, map[string]interface{}{
			"success": false,
			"error": map[string]interface{}{
				"code":    "USER_CREATION_ERROR",
				"message": "Error creating user",
			},
		})
	}

	return c.JSON(http.StatusCreated, map[string]interface{}{
		"success": true,
		"data": models.SignupResponse{
			UserID:    userProfile.UserID,
			FirstName: userProfile.FirstName,
			LastName:  userProfile.LastName,
			Email:     userProfile.Email,
			Message:   "User registered successfully",
		},
	})
}

func (s *Server) handleProfile(c echo.Context) error {
	return c.JSON(http.StatusOK, map[string]string{
		"message": "Profile endpoint",
	})
}

// Admin registration handlers

// Location handlers
func (s *Server) handleGetCities(c echo.Context) error {
	locationHandler := handlers.NewLocationHandler(s.db)
	return locationHandler.GetCities(c)
}

func (s *Server) handleGetSports(c echo.Context) error {
	locationHandler := handlers.NewLocationHandler(s.db)
	return locationHandler.GetSports(c)
}
