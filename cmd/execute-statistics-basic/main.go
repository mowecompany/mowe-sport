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

	// Execute basic statistics functions
	fmt.Println("📊 Executing basic statistics functions...")
	sqlContent, err := ioutil.ReadFile("database/04_functions/02_statistics_basic_functions.sql")
	if err != nil {
		log.Fatalf("Failed to read basic statistics functions SQL file: %v", err)
	}

	_, err = db.Exec(string(sqlContent))
	if err != nil {
		log.Fatalf("Failed to execute basic statistics functions SQL: %v", err)
	}

	fmt.Println("✅ Basic statistics functions implemented successfully!")
	fmt.Println("🎉 Statistics functions are now ready for testing!")
}
