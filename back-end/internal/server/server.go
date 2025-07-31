package server

import (
	"mowesport/internal/config"
	"mowesport/internal/database"
	"net/http"

	"github.com/labstack/echo/v4"
	"github.com/labstack/echo/v4/middleware"
)

type Server struct {
	db     *database.Database
	config *config.Config
	router *echo.Echo
}

func NewServer(db *database.Database, cfg *config.Config) *Server {
	e := echo.New()

	// Configure minimal logging middleware
	e.Use(middleware.LoggerWithConfig(middleware.LoggerConfig{
		Format: "${status} ${method} ${uri}\n",
	}))
	e.Use(middleware.Recover())
	e.Use(middleware.CORSWithConfig(middleware.CORSConfig{
		AllowOrigins:     []string{"http://localhost:5173"},
		AllowMethods:     []string{http.MethodGet, http.MethodPost, http.MethodPut, http.MethodDelete, http.MethodOptions},
		AllowHeaders:     []string{"Origin", "Content-Type", "Accept", "Authorization", "X-Requested-With"},
		AllowCredentials: true,
	}))

	server := &Server{
		db:     db,
		config: cfg,
		router: e,
	}

	server.setupRoutes()
	return server
}

func (s *Server) Start(address string) error {
	return s.router.Start(address)
}
