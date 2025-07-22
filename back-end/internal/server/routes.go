package server

import (
	"context"
	"mowesport/internal/models"
	"net/http"
	"strings"

	"time"

	"github.com/golang-jwt/jwt/v5"
	echojwt "github.com/labstack/echo-jwt/v4"
	"github.com/labstack/echo/v4"
	"github.com/labstack/echo/v4/middleware"
	"golang.org/x/crypto/bcrypt"
)

func (s *Server) setupRoutes() {
	// Health check endpoint
	s.router.GET("/api/health", s.handleHealthCheck)

	// Test database endpoint
	s.router.GET("/api/test-db", s.handleTestDB)

	// CORS configuration
	s.router.Use(middleware.CORSWithConfig(middleware.CORSConfig{
		AllowOrigins: []string{"http://localhost:5173"},
		AllowMethods: []string{http.MethodGet, http.MethodPost, http.MethodPut, http.MethodDelete},
	}))

	// API routes group
	api := s.router.Group("/api")

	// Auth routes
	auth := api.Group("/auth")
	auth.POST("/login", s.handleLogin)
	auth.POST("/signup", s.handleSignup)

	// Protected routes
	protected := api.Group("/protected")
	protected.Use(echojwt.JWT([]byte("your-secret-key")))
	protected.GET("/profile", s.handleProfile) // Example protected route
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
		return c.JSON(http.StatusBadRequest, map[string]string{
			"error": "Invalid request body",
		})
	}

	// Buscar usuario por email
	var user models.User
	var hashedPassword string
	err := s.db.GetConnection().QueryRow(
		context.Background(),
		"SELECT id, email, password_hash FROM users WHERE email = $1",
		req.Email,
	).Scan(&user.ID, &user.Email, &hashedPassword)

	if err != nil {
		return c.JSON(http.StatusNotFound, map[string]string{
			"error":   "User not found",
			"message": "El usuario no se encuentra registrado",
		})
	}

	// Verificar contraseña
	if err := bcrypt.CompareHashAndPassword([]byte(hashedPassword), []byte(req.Password)); err != nil {
		return c.JSON(http.StatusUnauthorized, map[string]string{
			"error":   "Invalid credentials",
			"message": "Las credenciales son incorrectas",
		})
	}

	// Generar JWT
	token := jwt.NewWithClaims(jwt.SigningMethodHS256, jwt.MapClaims{
		"id":    user.ID,
		"email": user.Email,
		"exp":   time.Now().Add(time.Hour * 72).Unix(),
	})

	tokenString, err := token.SignedString([]byte("your-secret-key"))
	if err != nil {
		return c.JSON(http.StatusInternalServerError, map[string]string{
			"error": "Error generating token",
		})
	}

	return c.JSON(http.StatusOK, models.LoginResponse{
		ID:    user.ID,
		Email: user.Email,
		Token: tokenString,
	})
}

func (s *Server) handleSignup(c echo.Context) error {
	var req models.SignupRequest
	if err := c.Bind(&req); err != nil {
		return c.JSON(http.StatusBadRequest, map[string]string{
			"error": "Invalid request body",
		})
	}

	// Validar campos requeridos
	if req.Name == "" || req.Email == "" || req.Password == "" {
		return c.JSON(http.StatusBadRequest, map[string]string{
			"error": "Name, email and password are required",
		})
	}

	// Hash the password
	hashedPassword, err := bcrypt.GenerateFromPassword([]byte(req.Password), bcrypt.DefaultCost)
	if err != nil {
		return c.JSON(http.StatusInternalServerError, map[string]string{
			"error": "Error processing password",
		})
	}

	// Insert user into database
	var user models.User
	err = s.db.GetConnection().QueryRow(
		context.Background(),
		"INSERT INTO users (name, email, password_hash, status, created_at, updated_at) VALUES ($1, $2, $3, $4, NOW(), NOW()) RETURNING id, name, email, created_at, updated_at",
		req.Name,
		req.Email,
		string(hashedPassword),
		true, // status activo por defecto
	).Scan(&user.ID, &user.Name, &user.Email, &user.CreatedAt, &user.UpdatedAt)

	if err != nil {
		if strings.Contains(err.Error(), "unique constraint") || strings.Contains(err.Error(), "duplicate key") {
			return c.JSON(http.StatusConflict, map[string]string{
				"error": "Email already exists",
			})
		}
		return c.JSON(http.StatusInternalServerError, map[string]string{
			"error": "Error creating user",
		})
	}

	return c.JSON(http.StatusCreated, models.SignupResponse{
		ID:    user.ID,
		Name:  user.Name,
		Email: user.Email,
	})
}

func (s *Server) handleProfile(c echo.Context) error {
	return c.JSON(http.StatusOK, map[string]string{
		"message": "Profile endpoint",
	})
}
