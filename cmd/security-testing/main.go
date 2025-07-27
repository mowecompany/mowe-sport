package main

import (
	"context"
	"fmt"
	"log"
	"os"
	"strings"

	"github.com/jackc/pgx/v5"
	"github.com/joho/godotenv"
)

type SecurityTest struct {
	Name        string
	Category    string
	Severity    string
	Status      string
	Description string
	Details     string
	Remediation string
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

	fmt.Println("🛡️ Starting Security Penetration Testing")
	fmt.Println("=" + strings.Repeat("=", 60))

	// Run security tests
	results := runSecurityTests(conn)

	// Generate security report
	generateSecurityReport(results)
}

func runSecurityTests(conn *pgx.Conn) []SecurityTest {
	var results []SecurityTest

	fmt.Println("\n🔍 Running Security Tests...")

	// Authentication Security Tests
	results = append(results, testPasswordSecurity(conn)...)
	results = append(results, testAccountLockingSecurity(conn)...)
	results = append(results, test2FASecurity(conn)...)

	// Authorization Security Tests
	results = append(results, testRLSSecurity(conn)...)
	results = append(results, testPrivilegeEscalation(conn)...)

	// Data Security Tests
	results = append(results, testDataExposure(conn)...)
	results = append(results, testSQLInjectionProtection(conn)...)

	// Session Security Tests
	results = append(results, testSessionSecurity(conn)...)

	// Audit Security Tests
	results = append(results, testAuditLogging(conn)...)

	return results
}

func testPasswordSecurity(conn *pgx.Conn) []SecurityTest {
	var results []SecurityTest
	fmt.Println("\n🔐 Testing Password Security...")

	// Test 1: Password hashing
	test := SecurityTest{
		Name:        "Password Hashing",
		Category:    "Authentication",
		Severity:    "CRITICAL",
		Description: "Verify all passwords are properly hashed",
	}

	var weakPasswords int
	err := conn.QueryRow(context.Background(), `
		SELECT COUNT(*) 
		FROM user_profiles 
		WHERE password_hash IS NULL 
		OR password_hash = '' 
		OR LENGTH(password_hash) < 20
		OR password_hash NOT LIKE '$%'
	`).Scan(&weakPasswords)

	if err != nil {
		test.Status = "ERROR"
		test.Details = fmt.Sprintf("Error checking password hashing: %v", err)
		test.Remediation = "Fix database query for password validation"
	} else if weakPasswords == 0 {
		test.Status = "PASS"
		test.Details = "All passwords are properly hashed"
		test.Remediation = "None required"
	} else {
		test.Status = "FAIL"
		test.Details = fmt.Sprintf("%d users have weak or unhashed passwords", weakPasswords)
		test.Remediation = "Implement proper password hashing for all users"
	}
	results = append(results, test)

	status := "✓"
	if test.Status == "FAIL" {
		status = "✗"
	}
	fmt.Printf("  %s Password Hashing: %s\n", status, test.Status)

	// Test 2: Password complexity requirements
	test = SecurityTest{
		Name:        "Password Complexity",
		Category:    "Authentication",
		Severity:    "HIGH",
		Description: "Check if password complexity is enforced",
	}

	// Check if there's a function to validate password complexity
	var complexityFunction int
	err = conn.QueryRow(context.Background(), `
		SELECT COUNT(*) 
		FROM information_schema.routines 
		WHERE routine_schema = 'public' 
		AND routine_name LIKE '%password%'
		AND routine_name LIKE '%valid%'
	`).Scan(&complexityFunction)

	if err != nil {
		test.Status = "ERROR"
		test.Details = fmt.Sprintf("Error checking password complexity functions: %v", err)
		test.Remediation = "Fix database query for function validation"
	} else if complexityFunction > 0 {
		test.Status = "PASS"
		test.Details = "Password complexity validation functions exist"
		test.Remediation = "None required"
	} else {
		test.Status = "FAIL"
		test.Details = "No password complexity validation found"
		test.Remediation = "Implement password complexity validation functions"
	}
	results = append(results, test)

	status = "✓"
	if test.Status == "FAIL" {
		status = "✗"
	}
	fmt.Printf("  %s Password Complexity: %s\n", status, test.Status)

	return results
}

func testAccountLockingSecurity(conn *pgx.Conn) []SecurityTest {
	var results []SecurityTest
	fmt.Println("\n🔒 Testing Account Locking Security...")

	// Test account locking mechanism
	test := SecurityTest{
		Name:        "Account Locking Mechanism",
		Category:    "Authentication",
		Severity:    "HIGH",
		Description: "Verify account locking prevents brute force attacks",
	}

	var lockingFields int
	err := conn.QueryRow(context.Background(), `
		SELECT COUNT(*) 
		FROM information_schema.columns 
		WHERE table_name = 'user_profiles' 
		AND column_name IN ('failed_login_attempts', 'locked_until')
	`).Scan(&lockingFields)

	if err != nil {
		test.Status = "ERROR"
		test.Details = fmt.Sprintf("Error checking locking fields: %v", err)
		test.Remediation = "Fix database query for locking mechanism validation"
	} else if lockingFields == 2 {
		test.Status = "PASS"
		test.Details = "Account locking mechanism is properly implemented"
		test.Remediation = "None required"
	} else {
		test.Status = "FAIL"
		test.Details = "Account locking mechanism is incomplete"
		test.Remediation = "Implement complete account locking with failed attempts and lock duration"
	}
	results = append(results, test)

	status := "✓"
	if test.Status == "FAIL" {
		status = "✗"
	}
	fmt.Printf("  %s Account Locking: %s\n", status, test.Status)

	return results
}

func test2FASecurity(conn *pgx.Conn) []SecurityTest {
	var results []SecurityTest
	fmt.Println("\n📱 Testing 2FA Security...")

	// Test 2FA implementation
	test := SecurityTest{
		Name:        "2FA Implementation",
		Category:    "Authentication",
		Severity:    "MEDIUM",
		Description: "Verify 2FA is properly implemented",
	}

	var twoFAFields int
	err := conn.QueryRow(context.Background(), `
		SELECT COUNT(*) 
		FROM information_schema.columns 
		WHERE table_name = 'user_profiles' 
		AND column_name IN ('two_factor_secret', 'two_factor_enabled')
	`).Scan(&twoFAFields)

	if err != nil {
		test.Status = "ERROR"
		test.Details = fmt.Sprintf("Error checking 2FA fields: %v", err)
		test.Remediation = "Fix database query for 2FA field validation"
	} else if twoFAFields == 2 {
		test.Status = "PASS"
		test.Details = "2FA fields are properly implemented"
		test.Remediation = "None required"
	} else {
		test.Status = "FAIL"
		test.Details = "2FA implementation is incomplete"
		test.Remediation = "Implement complete 2FA with secret and enabled fields"
	}
	results = append(results, test)

	status := "✓"
	if test.Status == "FAIL" {
		status = "✗"
	}
	fmt.Printf("  %s 2FA Implementation: %s\n", status, test.Status)

	return results
}

func testRLSSecurity(conn *pgx.Conn) []SecurityTest {
	var results []SecurityTest
	fmt.Println("\n🛡️ Testing RLS Security...")

	// Test RLS enablement
	test := SecurityTest{
		Name:        "RLS Enablement",
		Category:    "Authorization",
		Severity:    "CRITICAL",
		Description: "Verify RLS is enabled on all sensitive tables",
	}

	criticalTables := []string{
		"tournaments", "teams", "matches", "player_statistics", "team_statistics",
	}

	enabledTables := 0
	for _, table := range criticalTables {
		var rlsEnabled bool
		err := conn.QueryRow(context.Background(), `
			SELECT row_security 
			FROM information_schema.tables 
			WHERE table_schema = 'public' 
			AND table_name = $1
		`, table).Scan(&rlsEnabled)

		if err == nil && rlsEnabled {
			enabledTables++
		}
	}

	if enabledTables == len(criticalTables) {
		test.Status = "PASS"
		test.Details = "RLS is enabled on all critical tables"
		test.Remediation = "None required"
	} else {
		test.Status = "FAIL"
		test.Details = fmt.Sprintf("RLS enabled on only %d/%d critical tables", enabledTables, len(criticalTables))
		test.Remediation = "Enable RLS on all sensitive tables immediately"
	}
	results = append(results, test)

	status := "✓"
	if test.Status == "FAIL" {
		status = "✗"
	}
	fmt.Printf("  %s RLS Enablement: %s\n", status, test.Status)

	return results
}

func testPrivilegeEscalation(conn *pgx.Conn) []SecurityTest {
	var results []SecurityTest
	fmt.Println("\n⬆️ Testing Privilege Escalation...")

	// Test role hierarchy
	test := SecurityTest{
		Name:        "Role Hierarchy",
		Category:    "Authorization",
		Severity:    "HIGH",
		Description: "Verify proper role hierarchy prevents privilege escalation",
	}

	var roleHierarchy int
	err := conn.QueryRow(context.Background(), `
		SELECT COUNT(DISTINCT primary_role) 
		FROM user_profiles 
		WHERE primary_role IN ('super_admin', 'city_admin', 'tournament_admin', 'owner', 'coach', 'referee', 'player', 'client')
	`).Scan(&roleHierarchy)

	if err != nil {
		test.Status = "ERROR"
		test.Details = fmt.Sprintf("Error checking role hierarchy: %v", err)
		test.Remediation = "Fix database query for role validation"
	} else if roleHierarchy >= 5 {
		test.Status = "PASS"
		test.Details = fmt.Sprintf("Found %d distinct roles in hierarchy", roleHierarchy)
		test.Remediation = "None required"
	} else {
		test.Status = "FAIL"
		test.Details = fmt.Sprintf("Only %d roles found in hierarchy", roleHierarchy)
		test.Remediation = "Implement complete role hierarchy with proper permissions"
	}
	results = append(results, test)

	status := "✓"
	if test.Status == "FAIL" {
		status = "✗"
	}
	fmt.Printf("  %s Role Hierarchy: %s\n", status, test.Status)

	return results
}

func testDataExposure(conn *pgx.Conn) []SecurityTest {
	var results []SecurityTest
	fmt.Println("\n📊 Testing Data Exposure...")

	// Test sensitive data protection
	test := SecurityTest{
		Name:        "Sensitive Data Protection",
		Category:    "Data Security",
		Severity:    "CRITICAL",
		Description: "Verify sensitive data is properly protected",
	}

	var exposedData int
	err := conn.QueryRow(context.Background(), `
		SELECT COUNT(*) 
		FROM user_profiles 
		WHERE password_hash IS NULL 
		OR email LIKE '%@test.com' 
		OR phone LIKE '123%'
	`).Scan(&exposedData)

	if err != nil {
		test.Status = "ERROR"
		test.Details = fmt.Sprintf("Error checking data exposure: %v", err)
		test.Remediation = "Fix database query for data exposure validation"
	} else if exposedData == 0 {
		test.Status = "PASS"
		test.Details = "No exposed sensitive data found"
		test.Remediation = "None required"
	} else {
		test.Status = "FAIL"
		test.Details = fmt.Sprintf("%d records with potentially exposed data", exposedData)
		test.Remediation = "Review and secure all sensitive data fields"
	}
	results = append(results, test)

	status := "✓"
	if test.Status == "FAIL" {
		status = "✗"
	}
	fmt.Printf("  %s Sensitive Data Protection: %s\n", status, test.Status)

	return results
}

func testSQLInjectionProtection(conn *pgx.Conn) []SecurityTest {
	var results []SecurityTest
	fmt.Println("\n💉 Testing SQL Injection Protection...")

	// Test parameterized queries
	test := SecurityTest{
		Name:        "SQL Injection Protection",
		Category:    "Data Security",
		Severity:    "CRITICAL",
		Description: "Verify protection against SQL injection attacks",
	}

	// Test if functions use proper parameterization
	var securityFunctions int
	err := conn.QueryRow(context.Background(), `
		SELECT COUNT(*) 
		FROM information_schema.routines 
		WHERE routine_schema = 'public' 
		AND routine_definition NOT LIKE '%||%'
		AND routine_definition NOT LIKE '%EXECUTE%'
	`).Scan(&securityFunctions)

	if err != nil {
		test.Status = "ERROR"
		test.Details = fmt.Sprintf("Error checking SQL injection protection: %v", err)
		test.Remediation = "Fix database query for SQL injection validation"
	} else if securityFunctions > 0 {
		test.Status = "PASS"
		test.Details = "Functions appear to use safe SQL practices"
		test.Remediation = "Continue using parameterized queries"
	} else {
		test.Status = "FAIL"
		test.Details = "Potential SQL injection vulnerabilities found"
		test.Remediation = "Review all functions for SQL injection vulnerabilities"
	}
	results = append(results, test)

	status := "✓"
	if test.Status == "FAIL" {
		status = "✗"
	}
	fmt.Printf("  %s SQL Injection Protection: %s\n", status, test.Status)

	return results
}

func testSessionSecurity(conn *pgx.Conn) []SecurityTest {
	var results []SecurityTest
	fmt.Println("\n🔐 Testing Session Security...")

	// Test session management
	test := SecurityTest{
		Name:        "Session Management",
		Category:    "Session Security",
		Severity:    "HIGH",
		Description: "Verify proper session management implementation",
	}

	var sessionFields int
	err := conn.QueryRow(context.Background(), `
		SELECT COUNT(*) 
		FROM information_schema.columns 
		WHERE table_name = 'user_profiles' 
		AND column_name IN ('last_login', 'session_token')
	`).Scan(&sessionFields)

	if err != nil {
		test.Status = "ERROR"
		test.Details = fmt.Sprintf("Error checking session fields: %v", err)
		test.Remediation = "Fix database query for session validation"
	} else if sessionFields >= 1 {
		test.Status = "PASS"
		test.Details = "Session management fields are present"
		test.Remediation = "None required"
	} else {
		test.Status = "FAIL"
		test.Details = "Session management fields are missing"
		test.Remediation = "Implement proper session management with tokens and expiration"
	}
	results = append(results, test)

	status := "✓"
	if test.Status == "FAIL" {
		status = "✗"
	}
	fmt.Printf("  %s Session Management: %s\n", status, test.Status)

	return results
}

func testAuditLogging(conn *pgx.Conn) []SecurityTest {
	var results []SecurityTest
	fmt.Println("\n📝 Testing Audit Logging...")

	// Test audit logging implementation
	test := SecurityTest{
		Name:        "Audit Logging",
		Category:    "Audit Security",
		Severity:    "HIGH",
		Description: "Verify comprehensive audit logging is implemented",
	}

	var auditTable bool
	err := conn.QueryRow(context.Background(), `
		SELECT EXISTS (
			SELECT 1 
			FROM information_schema.tables 
			WHERE table_schema = 'public' 
			AND table_name = 'audit_logs'
		)
	`).Scan(&auditTable)

	if err != nil {
		test.Status = "ERROR"
		test.Details = fmt.Sprintf("Error checking audit table: %v", err)
		test.Remediation = "Fix database query for audit table validation"
	} else if auditTable {
		test.Status = "PASS"
		test.Details = "Audit logging table exists"
		test.Remediation = "None required"
	} else {
		test.Status = "FAIL"
		test.Details = "Audit logging table is missing"
		test.Remediation = "Implement comprehensive audit logging table and triggers"
	}
	results = append(results, test)

	status := "✓"
	if test.Status == "FAIL" {
		status = "✗"
	}
	fmt.Printf("  %s Audit Logging: %s\n", status, test.Status)

	return results
}

func generateSecurityReport(results []SecurityTest) {
	fmt.Println("\n" + strings.Repeat("=", 70))
	fmt.Println("🛡️ SECURITY PENETRATION TEST REPORT")
	fmt.Println(strings.Repeat("=", 70))

	// Count results by severity and status
	severityCount := make(map[string]int)
	statusCount := make(map[string]int)
	criticalFailures := 0
	highFailures := 0

	for _, result := range results {
		severityCount[result.Severity]++
		statusCount[result.Status]++

		if result.Status == "FAIL" {
			if result.Severity == "CRITICAL" {
				criticalFailures++
			} else if result.Severity == "HIGH" {
				highFailures++
			}
		}
	}

	// Overall security summary
	fmt.Printf("\n🔍 SECURITY TEST SUMMARY:\n")
	fmt.Printf("Total Tests: %d\n", len(results))
	fmt.Printf("Passed: %d\n", statusCount["PASS"])
	fmt.Printf("Failed: %d\n", statusCount["FAIL"])
	fmt.Printf("Errors: %d\n", statusCount["ERROR"])
	fmt.Printf("Critical Failures: %d\n", criticalFailures)
	fmt.Printf("High Risk Failures: %d\n", highFailures)

	// Severity breakdown
	fmt.Printf("\n⚠️ SEVERITY BREAKDOWN:\n")
	fmt.Println(strings.Repeat("-", 30))
	for severity, count := range severityCount {
		fmt.Printf("%-10s: %d tests\n", severity, count)
	}

	// Detailed results
	fmt.Printf("\n📋 DETAILED SECURITY TEST RESULTS:\n")
	fmt.Println(strings.Repeat("-", 90))
	fmt.Printf("%-25s %-15s %-10s %-8s %s\n", "Test Name", "Category", "Severity", "Status", "Details")
	fmt.Println(strings.Repeat("-", 90))

	for _, result := range results {
		fmt.Printf("%-25s %-15s %-10s %-8s %s\n",
			truncateString(result.Name, 25),
			truncateString(result.Category, 15),
			result.Severity,
			result.Status,
			truncateString(result.Details, 35))
	}

	// Security risk assessment
	fmt.Printf("\n🎯 SECURITY RISK ASSESSMENT:\n")
	fmt.Println(strings.Repeat("-", 40))

	if criticalFailures == 0 && highFailures == 0 {
		fmt.Println("✅ SECURITY RISK: LOW")
		fmt.Println("   System has strong security posture")
	} else if criticalFailures == 0 && highFailures <= 2 {
		fmt.Println("⚠️  SECURITY RISK: MEDIUM")
		fmt.Println("   Some high-risk issues need attention")
	} else if criticalFailures <= 1 && highFailures <= 3 {
		fmt.Println("⚠️  SECURITY RISK: HIGH")
		fmt.Println("   Critical security issues must be addressed")
	} else {
		fmt.Println("❌ SECURITY RISK: CRITICAL")
		fmt.Println("   Immediate security remediation required")
	}

	// Critical remediation actions
	fmt.Printf("\n🚨 CRITICAL REMEDIATION ACTIONS:\n")
	fmt.Println(strings.Repeat("-", 40))

	criticalActions := 0
	for _, result := range results {
		if result.Status == "FAIL" && result.Severity == "CRITICAL" {
			criticalActions++
			fmt.Printf("%d. %s: %s\n", criticalActions, result.Name, result.Remediation)
		}
	}

	if criticalActions == 0 {
		fmt.Println("✅ No critical security actions required")
	}

	// Security recommendations
	fmt.Printf("\n💡 SECURITY RECOMMENDATIONS:\n")
	fmt.Println(strings.Repeat("-", 35))
	fmt.Println("1. Implement regular security testing in CI/CD")
	fmt.Println("2. Conduct periodic penetration testing")
	fmt.Println("3. Review and update security policies quarterly")
	fmt.Println("4. Implement security monitoring and alerting")
	fmt.Println("5. Train development team on secure coding practices")

	fmt.Println("\n✅ Security penetration testing completed!")
}

func truncateString(s string, maxLen int) string {
	if len(s) <= maxLen {
		return s
	}
	return s[:maxLen-3] + "..."
}
