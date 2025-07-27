package main

import (
	"context"
	"fmt"
	"io/ioutil"
	"log"
	"os"
	"strings"

	"github.com/jackc/pgx/v5"
	"github.com/joho/godotenv"
)

func main() {
	// Load environment variables
	if err := godotenv.Load(); err != nil {
		log.Printf("Warning: .env file not found: %v", err)
	}

	// Database connection
	databaseURL := os.Getenv("DATABASE_URL")
	if databaseURL == "" {
		log.Fatal("DATABASE_URL environment variable is required")
	}

	conn, err := pgx.Connect(context.Background(), databaseURL)
	if err != nil {
		log.Fatalf("Failed to connect to database: %v", err)
	}
	defer conn.Close(context.Background())

	fmt.Println("🔧 Applying Testing Fixes")
	fmt.Println("=" + strings.Repeat("=", 50))

	// Apply audit log fixes
	if err := applyFixes(conn); err != nil {
		log.Fatalf("Failed to apply fixes: %v", err)
	}

	fmt.Println("\n✅ All fixes applied successfully!")
}

func applyFixes(conn *pgx.Conn) error {
	// Read and execute the audit log fixes
	content, err := ioutil.ReadFile("database/06_testing_fixes/01_audit_log_fixes.sql")
	if err != nil {
		return fmt.Errorf("failed to read fixes file: %v", err)
	}

	fmt.Println("📋 Applying audit log and authentication function fixes...")

	_, err = conn.Exec(context.Background(), string(content))
	if err != nil {
		return fmt.Errorf("failed to execute fixes: %v", err)
	}

	fmt.Println("✅ Audit log fixes applied successfully")
	return nil
}
