package main

import (
	"context"
	"fmt"
	"log"
	"os"

	"github.com/jackc/pgx/v5"
	"github.com/joho/godotenv"
	"golang.org/x/crypto/bcrypt"
)

func main() {
	// Load environment variables
	if err := godotenv.Load(); err != nil {
		log.Println("Warning: .env file not found")
	}

	databaseURL := os.Getenv("DATABASE_URL")
	if databaseURL == "" {
		log.Fatal("DATABASE_URL is required")
	}

	// Connect to database
	conn, err := pgx.Connect(context.Background(), databaseURL)
	if err != nil {
		log.Fatal("Failed to connect to database:", err)
	}
	defer conn.Close(context.Background())

	// Generate password hash
	password := "admin123"
	hash, err := bcrypt.GenerateFromPassword([]byte(password), bcrypt.DefaultCost)
	if err != nil {
		log.Fatal("Failed to generate password hash:", err)
	}

	// Insert super admin user
	_, err = conn.Exec(context.Background(), `
		INSERT INTO public.user_profiles (
			user_id,
			email,
			password_hash,
			first_name,
			last_name,
			primary_role,
			is_active,
			account_status,
			failed_login_attempts,
			two_factor_enabled,
			created_at,
			updated_at
		) VALUES (
			'd5c37951-c387-49f7-a115-903ea94a41e6',
			'admin@mowesport.com',
			$1,
			'Super',
			'Admin',
			'super_admin',
			TRUE,
			'active',
			0,
			FALSE,
			NOW(),
			NOW()
		) ON CONFLICT (user_id) DO UPDATE SET
			email = EXCLUDED.email,
			password_hash = EXCLUDED.password_hash,
			first_name = EXCLUDED.first_name,
			last_name = EXCLUDED.last_name,
			primary_role = EXCLUDED.primary_role,
			updated_at = NOW()
	`, string(hash))

	if err != nil {
		log.Fatal("Failed to insert user:", err)
	}

	fmt.Println("Super admin user created successfully!")
	fmt.Println("Email: admin@mowesport.com")
	fmt.Println("Password: admin123")

	// Verify user was created
	var userID, email, firstName, lastName, role string
	err = conn.QueryRow(context.Background(), `
		SELECT user_id, email, first_name, last_name, primary_role 
		FROM public.user_profiles 
		WHERE email = 'admin@mowesport.com'
	`).Scan(&userID, &email, &firstName, &lastName, &role)

	if err != nil {
		log.Fatal("Failed to verify user creation:", err)
	}

	fmt.Printf("Verified user: %s %s (%s) - %s - %s\n", firstName, lastName, email, role, userID)
}
