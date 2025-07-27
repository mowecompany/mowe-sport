package main

import (
	"database/sql"
	"fmt"
	"log"
	"os"

	_ "github.com/lib/pq"
	"golang.org/x/crypto/bcrypt"
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
	fmt.Println("")

	testSuperAdminCredentials(db)
}

func testSuperAdminCredentials(db *sql.DB) {
	fmt.Println("=== SUPER ADMIN CREDENTIALS TEST ===")
	fmt.Println("")

	// Get super admin user details
	var userID, email, firstName, lastName, primaryRole, accountStatus string
	var passwordHash string
	var isActive, twoFactorEnabled bool
	var failedAttempts int

	err := db.QueryRow(`
		SELECT 
			user_id, email, password_hash, first_name, last_name, 
			primary_role, is_active, account_status, 
			failed_login_attempts, two_factor_enabled
		FROM public.user_profiles 
		WHERE user_id = '00000000-0000-0000-0000-000000000001'
	`).Scan(&userID, &email, &passwordHash, &firstName, &lastName,
		&primaryRole, &isActive, &accountStatus, &failedAttempts, &twoFactorEnabled)

	if err != nil {
		fmt.Printf("❌ Super admin user not found: %v\n", err)
		return
	}

	fmt.Println("--- Super Admin User Details ---")
	fmt.Printf("✅ User ID: %s\n", userID)
	fmt.Printf("✅ Email: %s\n", email)
	fmt.Printf("✅ Name: %s %s\n", firstName, lastName)
	fmt.Printf("✅ Role: %s\n", primaryRole)
	fmt.Printf("✅ Active: %t\n", isActive)
	fmt.Printf("✅ Account Status: %s\n", accountStatus)
	fmt.Printf("✅ Failed Login Attempts: %d\n", failedAttempts)
	fmt.Printf("✅ Two Factor Enabled: %t\n", twoFactorEnabled)
	fmt.Println("")

	// Test password verification
	fmt.Println("--- Password Verification Test ---")
	testPassword := "MoweSport2024!"

	err = bcrypt.CompareHashAndPassword([]byte(passwordHash), []byte(testPassword))
	if err != nil {
		fmt.Printf("❌ Password verification failed: %v\n", err)
		fmt.Printf("❌ Expected password: %s\n", testPassword)
		fmt.Printf("❌ Hash in database: %s\n", passwordHash[:50]+"...")
	} else {
		fmt.Printf("✅ Password verification successful!\n")
		fmt.Printf("✅ Default password: %s\n", testPassword)
		fmt.Printf("⚠️  IMPORTANT: Change this password immediately after first login!\n")
	}
	fmt.Println("")

	// Check city admin users
	fmt.Println("--- City Admin Users ---")
	rows, err := db.Query(`
		SELECT email, first_name, last_name, is_active, account_status
		FROM public.user_profiles 
		WHERE primary_role = 'city_admin'
		ORDER BY email
	`)
	if err != nil {
		fmt.Printf("❌ Error querying city admin users: %v\n", err)
	} else {
		defer rows.Close()
		for rows.Next() {
			var adminEmail, adminFirstName, adminLastName, adminAccountStatus string
			var adminIsActive bool
			err := rows.Scan(&adminEmail, &adminFirstName, &adminLastName, &adminIsActive, &adminAccountStatus)
			if err != nil {
				fmt.Printf("❌ Error scanning city admin: %v\n", err)
				continue
			}
			fmt.Printf("✅ City Admin: %s %s (%s) - Active: %t - Status: %s\n",
				adminFirstName, adminLastName, adminEmail, adminIsActive, adminAccountStatus)
		}
	}
	fmt.Println("")

	// Test city admin password (they should have the same default password)
	fmt.Println("--- City Admin Password Test ---")
	var cityAdminHash string
	err = db.QueryRow(`
		SELECT password_hash 
		FROM public.user_profiles 
		WHERE primary_role = 'city_admin' 
		LIMIT 1
	`).Scan(&cityAdminHash)

	if err != nil {
		fmt.Printf("❌ No city admin found for password test: %v\n", err)
	} else {
		err = bcrypt.CompareHashAndPassword([]byte(cityAdminHash), []byte(testPassword))
		if err != nil {
			fmt.Printf("❌ City admin password verification failed: %v\n", err)
		} else {
			fmt.Printf("✅ City admin password verification successful!\n")
			fmt.Printf("✅ All admin accounts use the same default password: %s\n", testPassword)
		}
	}
	fmt.Println("")

	// Check role assignments
	fmt.Println("--- Role Assignments Summary ---")
	rows, err = db.Query(`
		SELECT 
			up.email,
			up.first_name || ' ' || up.last_name as full_name,
			COALESCE(c.name, 'Global') as city,
			COALESCE(s.name, 'All Sports') as sport,
			ur.role_name
		FROM public.user_roles_by_city_sport ur
		JOIN public.user_profiles up ON ur.user_id = up.user_id
		LEFT JOIN public.cities c ON ur.city_id = c.city_id
		LEFT JOIN public.sports s ON ur.sport_id = s.sport_id
		WHERE ur.is_active = TRUE
		ORDER BY ur.role_name, up.email
	`)
	if err != nil {
		fmt.Printf("❌ Error querying role assignments: %v\n", err)
	} else {
		defer rows.Close()
		for rows.Next() {
			var userEmail, fullName, city, sport, roleName string
			err := rows.Scan(&userEmail, &fullName, &city, &sport, &roleName)
			if err != nil {
				fmt.Printf("❌ Error scanning role assignment: %v\n", err)
				continue
			}
			fmt.Printf("✅ %s (%s) - %s in %s/%s\n", fullName, userEmail, roleName, city, sport)
		}
	}
	fmt.Println("")

	fmt.Println("=== SECURITY RECOMMENDATIONS ===")
	fmt.Println("1. 🔐 Change super admin password immediately: admin@mowesport.com")
	fmt.Println("2. 🔐 Change all city admin passwords:")
	fmt.Println("   - admin.bogota@mowesport.com")
	fmt.Println("   - admin.medellin@mowesport.com")
	fmt.Println("   - admin.cali@mowesport.com")
	fmt.Println("3. 🔒 Enable 2FA for all admin accounts")
	fmt.Println("4. 📝 Review and update user permissions as needed")
	fmt.Println("5. 🔍 Monitor audit logs for security events")
	fmt.Println("")
	fmt.Println("=== TEST COMPLETE ===")
}
