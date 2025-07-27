package main

import (
	"database/sql"
	"fmt"
	"log"
	"os"
	"time"

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
	fmt.Println("")

	// Test authentication and security functions
	testAuthenticationFunctions(db)
}

func testAuthenticationFunctions(db *sql.DB) {
	fmt.Println("=== COMPREHENSIVE AUTHENTICATION & SECURITY FUNCTIONS TESTING ===")
	fmt.Println("")

	// Test 1: Password Strength Validation
	fmt.Println("--- Password Strength Validation ---")
	testPasswords := []string{
		"weak",                  // Too short, no uppercase, no digits, no special chars
		"password123",           // Common password
		"Password123",           // Missing special character
		"Password123!",          // Strong password
		"MySecureP@ssw0rd2024!", // Very strong password
	}

	for _, password := range testPasswords {
		var result string
		err := db.QueryRow("SELECT public.validate_password_strength($1)::text", password).Scan(&result)
		if err != nil {
			fmt.Printf("❌ Error testing password '%s': %v\n", password, err)
			continue
		}
		fmt.Printf("🔍 Password: %-25s - %s\n", password, result)
	}
	fmt.Println("")

	// Test 2: Password Hashing and Verification
	fmt.Println("--- Password Hashing and Verification ---")
	testPassword := "MySecureP@ssw0rd2024!"

	// Test hashing
	var hashedPassword string
	err := db.QueryRow("SELECT public.hash_password($1)", testPassword).Scan(&hashedPassword)
	if err != nil {
		fmt.Printf("❌ Error hashing password: %v\n", err)
	} else {
		fmt.Printf("✅ Password hashed successfully: %s...\n", hashedPassword[:20])

		// Test verification with correct password
		var isValid bool
		err = db.QueryRow("SELECT public.verify_password($1, $2)", testPassword, hashedPassword).Scan(&isValid)
		if err != nil {
			fmt.Printf("❌ Error verifying correct password: %v\n", err)
		} else {
			fmt.Printf("✅ Correct password verification: %t\n", isValid)
		}

		// Test verification with wrong password
		err = db.QueryRow("SELECT public.verify_password($1, $2)", "wrongpassword", hashedPassword).Scan(&isValid)
		if err != nil {
			fmt.Printf("❌ Error verifying wrong password: %v\n", err)
		} else {
			fmt.Printf("✅ Wrong password verification: %t\n", isValid)
		}
	}
	fmt.Println("")

	// Test 3: Account Lock Management
	fmt.Println("--- Account Lock Management ---")
	testUserID := "11111111-1111-1111-1111-111111111111" // Bogotá admin

	// Check initial lock status
	var lockStatus string
	err = db.QueryRow("SELECT public.is_account_locked_detailed($1)::text", testUserID).Scan(&lockStatus)
	if err != nil {
		fmt.Printf("❌ Error checking lock status: %v\n", err)
	} else {
		fmt.Printf("✅ Initial lock status: %s\n", lockStatus)
	}

	// Record some failed attempts
	for i := 1; i <= 3; i++ {
		var attemptResult string
		err = db.QueryRow("SELECT public.record_failed_login_attempt_enhanced($1, $2, $3)::text",
			testUserID, "192.168.1.100", "Test User Agent").Scan(&attemptResult)
		if err != nil {
			fmt.Printf("❌ Error recording failed attempt %d: %v\n", i, err)
		} else {
			fmt.Printf("✅ Failed attempt %d recorded: %s\n", i, attemptResult)
		}
	}

	// Check lock status after failed attempts
	err = db.QueryRow("SELECT public.is_account_locked_detailed($1)::text", testUserID).Scan(&lockStatus)
	if err != nil {
		fmt.Printf("❌ Error checking lock status after attempts: %v\n", err)
	} else {
		fmt.Printf("✅ Lock status after 3 attempts: %s\n", lockStatus)
	}

	// Reset failed attempts
	var resetResult string
	err = db.QueryRow("SELECT public.reset_failed_login_attempts_enhanced($1, $2, $3)::text",
		testUserID, "192.168.1.100", "Test User Agent").Scan(&resetResult)
	if err != nil {
		fmt.Printf("❌ Error resetting failed attempts: %v\n", err)
	} else {
		fmt.Printf("✅ Failed attempts reset: %s\n", resetResult)
	}
	fmt.Println("")

	// Test 4: Password Recovery
	fmt.Println("--- Password Recovery ---")
	testEmail := "admin.bogota@mowesport.com"

	// Generate recovery token
	var recoveryResult string
	err = db.QueryRow("SELECT public.generate_password_recovery_token($1, $2, $3)::text",
		testEmail, "192.168.1.100", "Test User Agent").Scan(&recoveryResult)
	if err != nil {
		fmt.Printf("❌ Error generating recovery token: %v\n", err)
	} else {
		fmt.Printf("✅ Recovery token generated: %s\n", recoveryResult)

		// Test token validation with dummy token
		var validationResult string
		err = db.QueryRow("SELECT public.validate_password_recovery_token($1)::text",
			"dummy_token_for_testing").Scan(&validationResult)
		if err != nil {
			fmt.Printf("❌ Error validating recovery token: %v\n", err)
		} else {
			fmt.Printf("✅ Token validation test: %s\n", validationResult)
		}
	}
	fmt.Println("")

	// Test 5: 2FA Functions
	fmt.Println("--- Two-Factor Authentication ---")
	testUser2FA := "00000000-0000-0000-0000-000000000001" // Super admin

	// Generate 2FA secret
	var secretResult string
	err = db.QueryRow("SELECT public.generate_2fa_secret($1)::text", testUser2FA).Scan(&secretResult)
	if err != nil {
		fmt.Printf("❌ Error generating 2FA secret: %v\n", err)
	} else {
		fmt.Printf("✅ 2FA secret generated: %s\n", secretResult)

		// Test enabling 2FA
		var enableResult string
		err = db.QueryRow("SELECT public.enable_2fa($1, $2, $3, $4)::text",
			testUser2FA, "123456", "192.168.1.100", "Test User Agent").Scan(&enableResult)
		if err != nil {
			fmt.Printf("❌ Error enabling 2FA: %v\n", err)
		} else {
			fmt.Printf("✅ 2FA enable attempt: %s\n", enableResult)
		}

		// Test 2FA code verification
		var verifyResult string
		err = db.QueryRow("SELECT public.verify_2fa_code($1, $2)::text",
			testUser2FA, "123456").Scan(&verifyResult)
		if err != nil {
			fmt.Printf("❌ Error verifying 2FA code: %v\n", err)
		} else {
			fmt.Printf("✅ 2FA code verification: %s\n", verifyResult)
		}
	}
	fmt.Println("")

	// Test 6: Comprehensive Authentication
	fmt.Println("--- Comprehensive Authentication ---")

	// Test with correct credentials
	var authResult string
	err = db.QueryRow("SELECT public.authenticate_user($1, $2, $3, $4, $5)::text",
		"admin@mowesport.com", "MoweSport2024!", nil, "192.168.1.100", "Test User Agent").Scan(&authResult)
	if err != nil {
		fmt.Printf("❌ Error testing authentication: %v\n", err)
	} else {
		fmt.Printf("✅ Authentication test: %s\n", authResult)
	}

	// Test with wrong credentials
	err = db.QueryRow("SELECT public.authenticate_user($1, $2, $3, $4, $5)::text",
		"admin@mowesport.com", "wrongpassword", nil, "192.168.1.100", "Test User Agent").Scan(&authResult)
	if err != nil {
		fmt.Printf("❌ Error testing wrong authentication: %v\n", err)
	} else {
		fmt.Printf("✅ Wrong credentials test: %s\n", authResult)
	}
	fmt.Println("")

	// Test 7: Security Monitoring
	fmt.Println("--- Security Monitoring ---")

	// Get security events for super admin
	rows, err := db.Query("SELECT event_time, action, ip_address, user_agent, details FROM public.get_user_security_events($1, $2)",
		"00000000-0000-0000-0000-000000000001", 10)
	if err != nil {
		fmt.Printf("❌ Error getting security events: %v\n", err)
	} else {
		defer rows.Close()
		eventCount := 0
		fmt.Println("📋 Recent Security Events:")
		for rows.Next() {
			var eventTime time.Time
			var action, userAgent, details string
			var ipAddress sql.NullString

			err := rows.Scan(&eventTime, &action, &ipAddress, &userAgent, &details)
			if err != nil {
				fmt.Printf("❌ Error scanning security event: %v\n", err)
				continue
			}

			ip := "N/A"
			if ipAddress.Valid {
				ip = ipAddress.String
			}

			fmt.Printf("  📅 %s - %s from %s\n",
				eventTime.Format("2006-01-02 15:04:05"), action, ip)
			eventCount++
		}
		fmt.Printf("✅ Found %d security events\n", eventCount)
	}

	// Detect suspicious activity
	rows, err = db.Query("SELECT user_id, email, suspicious_events, unique_ips, failed_attempts, last_event FROM public.detect_suspicious_activity($1)", "1 hour")
	if err != nil {
		fmt.Printf("❌ Error detecting suspicious activity: %v\n", err)
	} else {
		defer rows.Close()
		suspiciousCount := 0
		fmt.Println("🚨 Suspicious Activity Detection:")
		for rows.Next() {
			var userID, email string
			var suspiciousEvents, uniqueIPs, failedAttempts int
			var lastEvent time.Time

			err := rows.Scan(&userID, &email, &suspiciousEvents, &uniqueIPs, &failedAttempts, &lastEvent)
			if err != nil {
				fmt.Printf("❌ Error scanning suspicious activity: %v\n", err)
				continue
			}

			fmt.Printf("  🚨 %s - Events: %d, IPs: %d, Failed: %d, Last: %s\n",
				email, suspiciousEvents, uniqueIPs, failedAttempts,
				lastEvent.Format("2006-01-02 15:04:05"))
			suspiciousCount++
		}
		if suspiciousCount == 0 {
			fmt.Println("  ✅ No suspicious activity detected")
		} else {
			fmt.Printf("⚠️  Found %d accounts with suspicious activity\n", suspiciousCount)
		}
	}
	fmt.Println("")

	// Test 8: Function Existence Check
	fmt.Println("--- Security Functions Validation ---")
	securityFunctions := []string{
		"validate_password_strength",
		"hash_password",
		"verify_password",
		"is_account_locked_detailed",
		"record_failed_login_attempt_enhanced",
		"reset_failed_login_attempts_enhanced",
		"generate_password_recovery_token",
		"validate_password_recovery_token",
		"reset_password_with_token",
		"generate_2fa_secret",
		"enable_2fa",
		"disable_2fa",
		"verify_2fa_code",
		"authenticate_user",
		"get_user_security_events",
		"detect_suspicious_activity",
	}

	for _, funcName := range securityFunctions {
		var exists bool
		err := db.QueryRow(`
			SELECT EXISTS(
				SELECT 1 FROM pg_proc p
				JOIN pg_namespace n ON p.pronamespace = n.oid
				WHERE n.nspname = 'public'
				AND p.proname = $1
			)
		`, funcName).Scan(&exists)

		if err != nil {
			fmt.Printf("❌ Error checking function %s: %v\n", funcName, err)
		} else if exists {
			fmt.Printf("✅ Function %s exists\n", funcName)
		} else {
			fmt.Printf("❌ Function %s missing\n", funcName)
		}
	}
	fmt.Println("")

	// Test 9: Integration Test - Complete Login Flow
	fmt.Println("--- Complete Login Flow Integration Test ---")

	// Test complete flow with existing user
	testCompleteLoginFlow(db, "admin@mowesport.com", "MoweSport2024!")

	fmt.Println("")
	fmt.Println("🎉 Authentication and Security Functions Testing Complete!")
}

func testCompleteLoginFlow(db *sql.DB, email, password string) {
	fmt.Printf("Testing complete login flow for: %s\n", email)

	// Step 1: Check if account is locked
	var userID string
	err := db.QueryRow("SELECT user_id FROM public.user_profiles WHERE email = $1", email).Scan(&userID)
	if err != nil {
		fmt.Printf("❌ User not found: %v\n", err)
		return
	}

	var lockStatus string
	err = db.QueryRow("SELECT public.is_account_locked_detailed($1)::text", userID).Scan(&lockStatus)
	if err != nil {
		fmt.Printf("❌ Error checking lock status: %v\n", err)
		return
	}
	fmt.Printf("  🔒 Lock Status: %s\n", lockStatus)

	// Step 2: Attempt authentication
	var authResult string
	err = db.QueryRow("SELECT public.authenticate_user($1, $2, $3, $4, $5)::text",
		email, password, nil, "192.168.1.100", "Integration Test").Scan(&authResult)
	if err != nil {
		fmt.Printf("❌ Authentication error: %v\n", err)
		return
	}
	fmt.Printf("  🔐 Authentication Result: %s\n", authResult)

	// Step 3: Check security events
	rows, err := db.Query("SELECT event_time, action, ip_address, user_agent, details FROM public.get_user_security_events($1, 3)", userID)
	if err != nil {
		fmt.Printf("❌ Error getting security events: %v\n", err)
		return
	}
	defer rows.Close()

	fmt.Println("  📋 Recent Security Events:")
	for rows.Next() {
		var eventTime time.Time
		var action, userAgent, details string
		var ipAddress sql.NullString

		err := rows.Scan(&eventTime, &action, &ipAddress, &userAgent, &details)
		if err != nil {
			fmt.Printf("❌ Error scanning event: %v\n", err)
			continue
		}

		fmt.Printf("    📅 %s - %s\n", eventTime.Format("15:04:05"), action)
	}
}
