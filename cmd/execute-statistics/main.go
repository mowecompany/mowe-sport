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

	// Execute statistics functions
	fmt.Println("📊 Executing statistics functions...")
	sqlContent, err := ioutil.ReadFile("database/04_functions/02_statistics_functions_complete.sql")
	if err != nil {
		log.Fatalf("Failed to read statistics functions SQL file: %v", err)
	}

	_, err = db.Exec(string(sqlContent))
	if err != nil {
		log.Fatalf("Failed to execute statistics functions SQL: %v", err)
	}

	fmt.Println("✅ Statistics functions implemented successfully!")

	// Execute statistics triggers
	fmt.Println("🔄 Executing statistics triggers...")
	sqlContent, err = ioutil.ReadFile("database/04_functions/03_statistics_triggers.sql")
	if err != nil {
		log.Fatalf("Failed to read statistics triggers SQL file: %v", err)
	}

	_, err = db.Exec(string(sqlContent))
	if err != nil {
		log.Fatalf("Failed to execute statistics triggers SQL: %v", err)
	}

	fmt.Println("✅ Statistics triggers implemented successfully!")
	fmt.Println("🎉 All statistics and calculation functions are now ready!")
}
