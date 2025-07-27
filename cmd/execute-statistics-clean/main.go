package main

import (
	"database/sql"
	"fmt"
	"io/ioutil"
	"log"
	"os"

	_ "github.com/lib/pq"
)

func main() {
	// Get database URL from environment
	databaseURL := os.Getenv("DATABASE_URL")
	if databaseURL == "" {
		log.Fatal("DATABASE_URL environment variable is required")
	}

	// Connect to database
	db, err := sql.Open("postgres", databaseURL)
	if err != nil {
		log.Fatalf("Failed to connect to database: %v", err)
	}
	defer db.Close()

	// Test connection
	if err := db.Ping(); err != nil {
		log.Fatalf("Failed to ping database: %v", err)
	}

	fmt.Println("✅ Database connection successful")

	// Execute drop and recreate statistics functions
	fmt.Println("🧹 Cleaning and recreating statistics functions...")
	sqlContent, err := ioutil.ReadFile("database/04_functions/02_statistics_functions_drop_recreate.sql")
	if err != nil {
		log.Fatalf("Failed to read statistics functions SQL file: %v", err)
	}

	_, err = db.Exec(string(sqlContent))
	if err != nil {
		log.Fatalf("Failed to execute statistics functions SQL: %v", err)
	}

	fmt.Println("✅ Statistics functions recreated successfully!")
	fmt.Println("🎉 Basic statistics functions are now ready!")
}
