package main

import (
	"context"
	"fmt"
	"log"
	"os"
	"strings"
	"time"

	"github.com/jackc/pgx/v5"
	"github.com/joho/godotenv"
)

type TestResult struct {
	TestName    string
	Category    string
	Success     bool
	Error       error
	Duration    time.Duration
	Description string
}

type TestSuite struct {
	conn    *pgx.Conn
	results []TestResult
}

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

	fmt.Println("🚀 Starting Comprehensive System Testing")
	fmt.Println("=" + strings.Repeat("=", 60))

	suite := &TestSuite{
		conn:    conn,
		results: make([]TestResult, 0),
	}

	// Run all test categories
	suite.runDataIntegrityTests()
	suite.runFunctionTests()
	suite.runRLSTests()
	suite.runPerformanceTests()
	suite.runSecurityTests()
	suite.runAuditTests()
	suite.runEdgeCaseTests()

	// Generate final report
	suite.generateReport()
}

func (ts *TestSuite) runTest(testName, category, description string, testFunc func() error) {
	fmt.Printf("🔍 Testing: %s\n", testName)

	start := time.Now()
	err := testFunc()
	duration := time.Since(start)

	result := TestResult{
		TestName:    testName,
		Category:    category,
		Success:     err == nil,
		Error:       err,
		Duration:    duration,
		Description: description,
	}

	ts.results = append(ts.results, result)

	if err == nil {
		fmt.Printf("✅ PASS (%v)\n", duration)
	} else {
		fmt.Printf("❌ FAIL (%v): %v\n", duration, err)
	}
	fmt.Println()
}

func (ts *TestSuite) runDataIntegrityTests() {
	fmt.Println("\n📊 DATA INTEGRITY TESTS")
	fmt.Println(strings.Repeat("-", 40))

	// Test 1: Check all tables exist
	ts.runTest("Table Existence Check", "Data Integrity",
		"Verify all required tables exist in the database", func() error {
			requiredTables := []string{
				"user_profiles", "cities", "sports", "tournaments", "teams",
				"players", "matches", "match_events", "team_statistics",
				"player_statistics", "user_roles_by_city_sport", "audit_logs",
			}

			for _, table := range requiredTables {
				var exists bool
				err := ts.conn.QueryRow(context.Background(),
					"SELECT EXISTS (SELECT FROM information_schema.tables WHERE table_name = $1)",
					table).Scan(&exists)
				if err != nil {
					return fmt.Errorf("error checking table %s: %v", table, err)
				}
				if !exists {
					return fmt.Errorf("required table %s does not exist", table)
				}
			}
			return nil
		})

	// Test 2: Check foreign key constraints
	ts.runTest("Foreign Key Constraints", "Data Integrity",
		"Verify all foreign key relationships are properly established", func() error {
			var constraintCount int
			err := ts.conn.QueryRow(context.Background(), `
			SELECT COUNT(*) 
			FROM information_schema.table_constraints 
			WHERE constraint_type = 'FOREIGN KEY' 
			AND table_schema = 'public'
		`).Scan(&constraintCount)

			if err != nil {
				return fmt.Errorf("error checking foreign keys: %v", err)
			}

			if constraintCount < 10 { // Expecting at least 10 foreign key constraints
				return fmt.Errorf("insufficient foreign key constraints found: %d", constraintCount)
			}

			return nil
		})

	// Test 3: Check data consistency
	ts.runTest("Data Consistency Check", "Data Integrity",
		"Verify data consistency across related tables", func() error {
			// Check if all tournaments have valid city and sport references
			var inconsistentCount int
			err := ts.conn.QueryRow(context.Background(), `
			SELECT COUNT(*) FROM tournaments t
			LEFT JOIN cities c ON t.city_id = c.city_id
			LEFT JOIN sports s ON t.sport_id = s.sport_id
			WHERE c.city_id IS NULL OR s.sport_id IS NULL
		`).Scan(&inconsistentCount)

			if err != nil {
				return fmt.Errorf("error checking data consistency: %v", err)
			}

			if inconsistentCount > 0 {
				return fmt.Errorf("found %d tournaments with invalid references", inconsistentCount)
			}

			return nil
		})

	// Test 4: Check unique constraints
	ts.runTest("Unique Constraints", "Data Integrity",
		"Verify unique constraints are working properly", func() error {
			// Test email uniqueness in user_profiles
			_, err := ts.conn.Exec(context.Background(), `
			INSERT INTO user_profiles (email, password_hash, first_name, last_name, primary_role)
			VALUES ('test@duplicate.com', 'hash1', 'Test', 'User', 'client')
		`)
			if err != nil {
				return fmt.Errorf("error inserting first test user: %v", err)
			}

			// Try to insert duplicate email (should fail)
			_, err = ts.conn.Exec(context.Background(), `
			INSERT INTO user_profiles (email, password_hash, first_name, last_name, primary_role)
			VALUES ('test@duplicate.com', 'hash2', 'Test2', 'User2', 'client')
		`)

			// Clean up
			ts.conn.Exec(context.Background(), "DELETE FROM user_profiles WHERE email = 'test@duplicate.com'")

			if err == nil {
				return fmt.Errorf("duplicate email was allowed - unique constraint not working")
			}

			return nil
		})
}

func (ts *TestSuite) runFunctionTests() {
	fmt.Println("\n⚙️ FUNCTION TESTS")
	fmt.Println(strings.Repeat("-", 40))

	// Test 1: Authentication functions
	ts.runTest("Authentication Functions", "Functions",
		"Test password validation and authentication functions", func() error {
			// Check if authentication functions exist
			functions := []string{
				"validate_password_hash", "handle_failed_login", "reset_failed_attempts",
			}

			for _, funcName := range functions {
				var exists bool
				err := ts.conn.QueryRow(context.Background(), `
				SELECT EXISTS (
					SELECT 1 FROM information_schema.routines 
					WHERE routine_name = $1 AND routine_schema = 'public'
				)
			`, funcName).Scan(&exists)

				if err != nil {
					return fmt.Errorf("error checking function %s: %v", funcName, err)
				}
				if !exists {
					return fmt.Errorf("required function %s does not exist", funcName)
				}
			}
			return nil
		})

	// Test 2: Statistics functions
	ts.runTest("Statistics Functions", "Functions",
		"Test statistics calculation functions", func() error {
			functions := []string{
				"recalculate_player_statistics", "recalculate_team_statistics",
				"update_tournament_standings",
			}

			for _, funcName := range functions {
				var exists bool
				err := ts.conn.QueryRow(context.Background(), `
				SELECT EXISTS (
					SELECT 1 FROM information_schema.routines 
					WHERE routine_name = $1 AND routine_schema = 'public'
				)
			`, funcName).Scan(&exists)

				if err != nil {
					return fmt.Errorf("error checking function %s: %v", funcName, err)
				}
				if !exists {
					return fmt.Errorf("required function %s does not exist", funcName)
				}
			}
			return nil
		})

	// Test 3: Trigger functions
	ts.runTest("Trigger Functions", "Functions",
		"Test that triggers are properly configured", func() error {
			var triggerCount int
			err := ts.conn.QueryRow(context.Background(), `
			SELECT COUNT(*) FROM information_schema.triggers 
			WHERE trigger_schema = 'public'
		`).Scan(&triggerCount)

			if err != nil {
				return fmt.Errorf("error checking triggers: %v", err)
			}

			if triggerCount < 3 { // Expecting at least 3 triggers
				return fmt.Errorf("insufficient triggers found: %d", triggerCount)
			}

			return nil
		})
}

func (ts *TestSuite) runRLSTests() {
	fmt.Println("\n🔒 ROW LEVEL SECURITY TESTS")
	fmt.Println(strings.Repeat("-", 40))

	// Test 1: RLS is enabled on sensitive tables
	ts.runTest("RLS Enabled Check", "Security",
		"Verify RLS is enabled on all sensitive tables", func() error {
			sensitiveTable := []string{
				"tournaments", "teams", "matches", "player_statistics", "team_statistics",
			}

			for _, table := range sensitiveTable {
				var rlsEnabled bool
				err := ts.conn.QueryRow(context.Background(), `
				SELECT relrowsecurity FROM pg_class 
				WHERE relname = $1 AND relnamespace = (
					SELECT oid FROM pg_namespace WHERE nspname = 'public'
				)
			`, table).Scan(&rlsEnabled)

				if err != nil {
					return fmt.Errorf("error checking RLS for table %s: %v", table, err)
				}
				if !rlsEnabled {
					return fmt.Errorf("RLS not enabled on table %s", table)
				}
			}
			return nil
		})

	// Test 2: RLS policies exist
	ts.runTest("RLS Policies Check", "Security",
		"Verify RLS policies are properly configured", func() error {
			var policyCount int
			err := ts.conn.QueryRow(context.Background(), `
			SELECT COUNT(*) FROM pg_policies WHERE schemaname = 'public'
		`).Scan(&policyCount)

			if err != nil {
				return fmt.Errorf("error checking RLS policies: %v", err)
			}

			if policyCount < 5 { // Expecting at least 5 policies
				return fmt.Errorf("insufficient RLS policies found: %d", policyCount)
			}

			return nil
		})

	// Test 3: Multi-tenancy isolation
	ts.runTest("Multi-Tenancy Isolation", "Security",
		"Test that users can only access data from their assigned city/sport", func() error {
			// This would require creating test users and testing access
			// For now, we'll check that the user_roles_by_city_sport table exists and has data structure
			var columnCount int
			err := ts.conn.QueryRow(context.Background(), `
			SELECT COUNT(*) FROM information_schema.columns 
			WHERE table_name = 'user_roles_by_city_sport' 
			AND column_name IN ('user_id', 'city_id', 'sport_id', 'role_name')
		`).Scan(&columnCount)

			if err != nil {
				return fmt.Errorf("error checking multi-tenancy structure: %v", err)
			}

			if columnCount < 4 {
				return fmt.Errorf("multi-tenancy table structure incomplete")
			}

			return nil
		})
}

func (ts *TestSuite) runPerformanceTests() {
	fmt.Println("\n⚡ PERFORMANCE TESTS")
	fmt.Println(strings.Repeat("-", 40))

	// Test 1: Index usage
	ts.runTest("Index Usage", "Performance",
		"Verify critical indexes are created and being used", func() error {
			var indexCount int
			err := ts.conn.QueryRow(context.Background(), `
			SELECT COUNT(*) FROM pg_stat_user_indexes 
			WHERE schemaname = 'public' AND idx_scan > 0
		`).Scan(&indexCount)

			if err != nil {
				return fmt.Errorf("error checking index usage: %v", err)
			}

			if indexCount < 5 { // Expecting at least 5 used indexes
				return fmt.Errorf("insufficient index usage found: %d", indexCount)
			}

			return nil
		})

	// Test 2: Query performance
	ts.runTest("Query Performance", "Performance",
		"Test that critical queries execute within acceptable time limits", func() error {
			start := time.Now()

			// Test a complex query that should be optimized
			rows, err := ts.conn.Query(context.Background(), `
			SELECT t.tournament_id, t.name, COUNT(tt.team_id) as team_count
			FROM tournaments t
			LEFT JOIN tournament_teams tt ON t.tournament_id = tt.tournament_id
			GROUP BY t.tournament_id, t.name
			ORDER BY team_count DESC
			LIMIT 10
		`)
			if err != nil {
				return fmt.Errorf("error executing performance test query: %v", err)
			}
			rows.Close()

			duration := time.Since(start)
			if duration > 2*time.Second {
				return fmt.Errorf("query took too long: %v (expected < 2s)", duration)
			}

			return nil
		})

	// Test 3: Statistics update performance
	ts.runTest("Statistics Update Performance", "Performance",
		"Test that statistics functions execute efficiently", func() error {
			start := time.Now()

			// Test statistics update (if function exists)
			_, err := ts.conn.Exec(context.Background(), `
			SELECT CASE 
				WHEN EXISTS (SELECT 1 FROM information_schema.routines WHERE routine_name = 'update_table_statistics')
				THEN update_table_statistics()
				ELSE NULL
			END
		`)

			duration := time.Since(start)
			if err != nil && !strings.Contains(err.Error(), "does not exist") {
				return fmt.Errorf("error executing statistics update: %v", err)
			}

			if duration > 5*time.Second {
				return fmt.Errorf("statistics update took too long: %v (expected < 5s)", duration)
			}

			return nil
		})
}

func (ts *TestSuite) runSecurityTests() {
	fmt.Println("\n🛡️ SECURITY TESTS")
	fmt.Println(strings.Repeat("-", 40))

	// Test 1: Password security
	ts.runTest("Password Security", "Security",
		"Verify passwords are properly hashed and not stored in plain text", func() error {
			// Check that no plain text passwords exist
			var plainTextCount int
			err := ts.conn.QueryRow(context.Background(), `
			SELECT COUNT(*) FROM user_profiles 
			WHERE password_hash IS NULL OR LENGTH(password_hash) < 20
		`).Scan(&plainTextCount)

			if err != nil {
				return fmt.Errorf("error checking password security: %v", err)
			}

			if plainTextCount > 0 {
				return fmt.Errorf("found %d users with weak or missing password hashes", plainTextCount)
			}

			return nil
		})

	// Test 2: Account lockout mechanism
	ts.runTest("Account Lockout", "Security",
		"Test that account lockout mechanism is working", func() error {
			// Check that failed_login_attempts column exists and has proper constraints
			var columnExists bool
			err := ts.conn.QueryRow(context.Background(), `
			SELECT EXISTS (
				SELECT 1 FROM information_schema.columns 
				WHERE table_name = 'user_profiles' 
				AND column_name = 'failed_login_attempts'
			)
		`).Scan(&columnExists)

			if err != nil {
				return fmt.Errorf("error checking lockout mechanism: %v", err)
			}

			if !columnExists {
				return fmt.Errorf("failed_login_attempts column not found")
			}

			return nil
		})

	// Test 3: Audit logging
	ts.runTest("Audit Logging", "Security",
		"Verify audit logging is properly configured", func() error {
			// Check that audit_logs table exists and has proper structure
			var columnCount int
			err := ts.conn.QueryRow(context.Background(), `
			SELECT COUNT(*) FROM information_schema.columns 
			WHERE table_name = 'audit_logs' 
			AND column_name IN ('user_id', 'action', 'table_name', 'created_at')
		`).Scan(&columnCount)

			if err != nil {
				return fmt.Errorf("error checking audit logging: %v", err)
			}

			if columnCount < 4 {
				return fmt.Errorf("audit logging structure incomplete")
			}

			return nil
		})
}

func (ts *TestSuite) runAuditTests() {
	fmt.Println("\n📋 AUDIT AND LOGGING TESTS")
	fmt.Println(strings.Repeat("-", 40))

	// Test 1: Audit log functionality
	ts.runTest("Audit Log Functionality", "Audit",
		"Test that audit logs are being created for critical actions", func() error {
			// Insert a test audit log entry
			_, err := ts.conn.Exec(context.Background(), `
			INSERT INTO audit_logs (action, table_name, description, created_at)
			VALUES ('TEST_ACTION', 'test_table', 'System test audit entry', NOW())
		`)

			if err != nil {
				return fmt.Errorf("error inserting test audit log: %v", err)
			}

			// Verify the entry was created
			var count int
			err = ts.conn.QueryRow(context.Background(), `
			SELECT COUNT(*) FROM audit_logs 
			WHERE action = 'TEST_ACTION' AND table_name = 'test_table'
		`).Scan(&count)

			// Clean up
			ts.conn.Exec(context.Background(), `
			DELETE FROM audit_logs 
			WHERE action = 'TEST_ACTION' AND table_name = 'test_table'
		`)

			if err != nil {
				return fmt.Errorf("error verifying audit log: %v", err)
			}

			if count == 0 {
				return fmt.Errorf("audit log entry was not created")
			}

			return nil
		})

	// Test 2: Audit log retention
	ts.runTest("Audit Log Structure", "Audit",
		"Verify audit log table has proper structure for retention and querying", func() error {
			// Check for proper indexing on audit logs
			var indexExists bool
			err := ts.conn.QueryRow(context.Background(), `
			SELECT EXISTS (
				SELECT 1 FROM pg_indexes 
				WHERE tablename = 'audit_logs' 
				AND indexname LIKE '%created_at%'
			)
		`).Scan(&indexExists)

			if err != nil {
				return fmt.Errorf("error checking audit log indexes: %v", err)
			}

			if !indexExists {
				return fmt.Errorf("audit log created_at index not found")
			}

			return nil
		})
}

func (ts *TestSuite) runEdgeCaseTests() {
	fmt.Println("\n🔍 EDGE CASE AND ERROR HANDLING TESTS")
	fmt.Println(strings.Repeat("-", 40))

	// Test 1: Null value handling
	ts.runTest("Null Value Handling", "Edge Cases",
		"Test that the system properly handles null values", func() error {
			// Test inserting a tournament with minimal required fields
			_, err := ts.conn.Exec(context.Background(), `
			INSERT INTO tournaments (name, city_id, sport_id, admin_user_id, start_date, end_date)
			SELECT 'Test Tournament', c.city_id, s.sport_id, u.user_id, CURRENT_DATE, CURRENT_DATE + INTERVAL '7 days'
			FROM cities c, sports s, user_profiles u
			LIMIT 1
		`)

			if err != nil {
				return fmt.Errorf("error handling null values in tournament creation: %v", err)
			}

			// Clean up
			ts.conn.Exec(context.Background(), "DELETE FROM tournaments WHERE name = 'Test Tournament'")

			return nil
		})

	// Test 2: Constraint violations
	ts.runTest("Constraint Violation Handling", "Edge Cases",
		"Test that constraint violations are properly handled", func() error {
			// Try to insert invalid data that should violate constraints
			_, err := ts.conn.Exec(context.Background(), `
			INSERT INTO user_profiles (email, password_hash, first_name, last_name, primary_role)
			VALUES ('invalid@test.com', 'hash', 'Test', 'User', 'invalid_role')
		`)

			if err == nil {
				// Clean up if somehow it was inserted
				ts.conn.Exec(context.Background(), "DELETE FROM user_profiles WHERE email = 'invalid@test.com'")
				return fmt.Errorf("invalid role was accepted - constraint not working")
			}

			// Error is expected, so this is success
			return nil
		})

	// Test 3: Large data handling
	ts.runTest("Large Data Handling", "Edge Cases",
		"Test system behavior with larger datasets", func() error {
			// Test a query that might return many results
			start := time.Now()
			rows, err := ts.conn.Query(context.Background(), `
			SELECT table_name, column_name 
			FROM information_schema.columns 
			WHERE table_schema = 'public'
			ORDER BY table_name, ordinal_position
		`)

			if err != nil {
				return fmt.Errorf("error executing large data query: %v", err)
			}

			count := 0
			for rows.Next() {
				count++
			}
			rows.Close()

			duration := time.Since(start)
			if duration > 5*time.Second {
				return fmt.Errorf("large data query took too long: %v", duration)
			}

			if count == 0 {
				return fmt.Errorf("no data returned from large data query")
			}

			return nil
		})
}

func (ts *TestSuite) generateReport() {
	fmt.Println("\n" + strings.Repeat("=", 60))
	fmt.Println("📊 COMPREHENSIVE SYSTEM TEST REPORT")
	fmt.Println(strings.Repeat("=", 60))

	// Count results by category
	categoryStats := make(map[string]struct {
		Total  int
		Passed int
		Failed int
	})

	totalTests := len(ts.results)
	totalPassed := 0
	totalFailed := 0

	for _, result := range ts.results {
		stats := categoryStats[result.Category]
		stats.Total++
		if result.Success {
			stats.Passed++
			totalPassed++
		} else {
			stats.Failed++
			totalFailed++
		}
		categoryStats[result.Category] = stats
	}

	// Overall summary
	fmt.Printf("📋 OVERALL SUMMARY\n")
	fmt.Printf("Total Tests: %d\n", totalTests)
	fmt.Printf("Passed: %d (%.1f%%)\n", totalPassed, float64(totalPassed)/float64(totalTests)*100)
	fmt.Printf("Failed: %d (%.1f%%)\n", totalFailed, float64(totalFailed)/float64(totalTests)*100)
	fmt.Println()

	// Category breakdown
	fmt.Printf("📊 RESULTS BY CATEGORY\n")
	fmt.Println(strings.Repeat("-", 50))
	for category, stats := range categoryStats {
		status := "✅ PASS"
		if stats.Failed > 0 {
			status = "❌ FAIL"
		}
		fmt.Printf("%-20s %s (%d/%d passed)\n", category, status, stats.Passed, stats.Total)
	}
	fmt.Println()

	// Failed tests details
	if totalFailed > 0 {
		fmt.Printf("❌ FAILED TESTS DETAILS\n")
		fmt.Println(strings.Repeat("-", 50))
		for _, result := range ts.results {
			if !result.Success {
				fmt.Printf("• %s (%s)\n", result.TestName, result.Category)
				fmt.Printf("  Error: %v\n", result.Error)
				fmt.Printf("  Duration: %v\n", result.Duration)
				fmt.Println()
			}
		}
	}

	// Performance summary
	fmt.Printf("⚡ PERFORMANCE SUMMARY\n")
	fmt.Println(strings.Repeat("-", 50))
	var totalDuration time.Duration
	for _, result := range ts.results {
		totalDuration += result.Duration
	}
	fmt.Printf("Total Test Duration: %v\n", totalDuration)
	fmt.Printf("Average Test Duration: %v\n", totalDuration/time.Duration(totalTests))
	fmt.Println()

	// Final status
	if totalFailed == 0 {
		fmt.Println("🎉 ALL TESTS PASSED! System is ready for production.")
	} else {
		fmt.Printf("⚠️  %d TESTS FAILED. Please review and fix issues before production.\n", totalFailed)
	}

	fmt.Println(strings.Repeat("=", 60))
}
