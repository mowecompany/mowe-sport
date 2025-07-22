package database

import (
	"context"
	"fmt"
	"os"
	"time"

	"github.com/jackc/pgx/v5"
)

type Database struct {
	conn *pgx.Conn
}

func NewDatabase() (*Database, error) {
	dbURL := os.Getenv("DATABASE_URL")
	if dbURL == "" {
		return nil, fmt.Errorf("DATABASE_URL environment variable is not set")
	}

	fmt.Printf("Connecting to database with URL: %s\n", dbURL)

	ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer cancel()

	config, err := pgx.ParseConfig(dbURL)
	if err != nil {
		return nil, fmt.Errorf("database configuration error: %w", err)
	}

	config.RuntimeParams = map[string]string{
		"application_name":  "mowesport-api",
		"statement_timeout": "60000",
	}

	conn, err := pgx.ConnectConfig(ctx, config)
	if err != nil {
		return nil, fmt.Errorf("database connection error: %w", err)
	}

	if err := conn.Ping(ctx); err != nil {
		conn.Close(context.Background())
		return nil, fmt.Errorf("database ping error: %w", err)
	}

	fmt.Println("Database connection successful!")
	return &Database{conn: conn}, nil
}

func (db *Database) Close() {
	if db.conn != nil {
		db.conn.Close(context.Background())
	}
}

func (db *Database) GetConnection() *pgx.Conn {
	return db.conn
}

// TestConnection verifies the database connection is working
func (db *Database) TestConnection() error {
	var version string
	err := db.conn.QueryRow(context.Background(), "SELECT version()").Scan(&version)
	if err != nil {
		return fmt.Errorf("failed to query database version: %w", err)
	}
	return nil
}
