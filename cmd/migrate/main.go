package main

import (
	"database/sql"
	"flag"
	"fmt"
	"log"
	"os"

	"github.com/golang-migrate/migrate/v4"
	"github.com/golang-migrate/migrate/v4/database/postgres"
	_ "github.com/golang-migrate/migrate/v4/source/file"
	_ "github.com/lib/pq"
)

func main() {
	var (
		databaseURL    = flag.String("database-url", "", "Database URL")
		migrationsPath = flag.String("migrations-path", "file://migrations", "Path to migrations directory")
		command        = flag.String("command", "", "Migration command: up, down, version, force")
		steps          = flag.Int("steps", 0, "Number of steps for up/down commands")
		version        = flag.Uint("version", 0, "Version for force command")
	)
	flag.Parse()

	// Get database URL from environment if not provided
	if *databaseURL == "" {
		*databaseURL = os.Getenv("DATABASE_URL")
	}

	if *databaseURL == "" {
		log.Fatal("Database URL is required. Use -database-url flag or DATABASE_URL environment variable")
	}

	if *command == "" {
		log.Fatal("Command is required. Use -command flag with: up, down, version, force")
	}

	// Convert Supabase JDBC URL to PostgreSQL URL if needed
	if len(*databaseURL) > 5 && (*databaseURL)[:5] == "jdbc:" {
		*databaseURL = (*databaseURL)[5:] // Remove "jdbc:" prefix
	}

	// Open database connection
	db, err := sql.Open("postgres", *databaseURL)
	if err != nil {
		log.Fatalf("Failed to connect to database: %v", err)
	}
	defer db.Close()

	// Test connection
	if err := db.Ping(); err != nil {
		log.Fatalf("Failed to ping database: %v", err)
	}

	fmt.Println("✅ Database connection successful")

	// Create postgres driver instance
	driver, err := postgres.WithInstance(db, &postgres.Config{})
	if err != nil {
		log.Fatalf("Failed to create postgres driver: %v", err)
	}

	// Create migrate instance
	m, err := migrate.NewWithDatabaseInstance(*migrationsPath, "postgres", driver)
	if err != nil {
		log.Fatalf("Failed to create migrate instance: %v", err)
	}

	// Execute command
	switch *command {
	case "up":
		if *steps > 0 {
			err = m.Steps(*steps)
		} else {
			err = m.Up()
		}
		if err != nil && err != migrate.ErrNoChange {
			log.Fatalf("Failed to run up migrations: %v", err)
		}
		if err == migrate.ErrNoChange {
			fmt.Println("✅ No migrations to apply")
		} else {
			fmt.Println("✅ Migrations applied successfully")
		}

	case "down":
		if *steps > 0 {
			err = m.Steps(-*steps)
		} else {
			err = m.Down()
		}
		if err != nil && err != migrate.ErrNoChange {
			log.Fatalf("Failed to run down migrations: %v", err)
		}
		if err == migrate.ErrNoChange {
			fmt.Println("✅ No migrations to rollback")
		} else {
			fmt.Println("✅ Migrations rolled back successfully")
		}

	case "version":
		version, dirty, err := m.Version()
		if err != nil {
			log.Fatalf("Failed to get migration version: %v", err)
		}
		fmt.Printf("Current migration version: %d (dirty: %t)\n", version, dirty)

	case "force":
		if *version == 0 {
			log.Fatal("Version is required for force command. Use -version flag")
		}
		err = m.Force(int(*version))
		if err != nil {
			log.Fatalf("Failed to force migration version: %v", err)
		}
		fmt.Printf("✅ Forced migration to version %d\n", *version)

	default:
		log.Fatalf("Unknown command: %s. Available commands: up, down, version, force", *command)
	}
}
