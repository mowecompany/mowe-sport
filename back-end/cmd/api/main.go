package main

import (
	"log"
	"mowesport/internal/database"
	"mowesport/internal/server"
	"os"

	"github.com/joho/godotenv"
)

func main() {
	if err := godotenv.Load(); err != nil {
		log.Fatal("Error loading .env file")
	}

	if os.Getenv("DATABASE_URL") == "" {
		log.Fatal("DATABASE_URL is required")
	}

	db, err := database.NewDatabase()
	if err != nil {
		log.Fatal("Database initialization failed")
	}
	defer db.Close()

	if err := db.TestConnection(); err != nil {
		log.Fatal("Database connection test failed")
	}

	srv := server.NewServer(db)
	if err := srv.Start(":8080"); err != nil {
		log.Fatal("Server failed to start")
	}
}
