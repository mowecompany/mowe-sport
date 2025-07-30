package main

import (
	"log"
	"mowesport/internal/config"
	"mowesport/internal/database"
	"mowesport/internal/server"

	"github.com/joho/godotenv"
)

func main() {
	// Load environment variables
	if err := godotenv.Load(); err != nil {
		log.Println("Warning: .env file not found, using environment variables")
	}

	// Load configuration
	cfg := config.LoadConfig()

	if cfg.DatabaseURL == "" {
		log.Fatal("DATABASE_URL is required")
	}

	// Initialize database
	db, err := database.NewDatabase()
	if err != nil {
		log.Fatal("Database initialization failed:", err)
	}
	defer db.Close()

	if err := db.TestConnection(); err != nil {
		log.Fatal("Database connection test failed:", err)
	}

	// Initialize server with configuration
	srv := server.NewServer(db, cfg)

	log.Printf("Starting server on port %s", cfg.ServerPort)
	if err := srv.Start(":" + cfg.ServerPort); err != nil {
		log.Fatal("Server failed to start:", err)
	}
}
