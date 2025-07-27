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

type IntegrityTest struct {
	Name        string
	Category    string
	Description string
	Query       string
	Expected    interface{}
	Comparison  string // "equals", "greater_than", "less_than", "not_zero"
}

type IntegrityResult struct {
	Test     IntegrityTest
	Actual   interface{}
	Success  bool
	Error    error
	Duration time.Duration
}

type IntegrityTestSuite struct {
	conn    *pgx.Conn
	results []IntegrityResult
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

	fmt.Println("🔍 Starting Data Integrity and Validation Testing")
	fmt.Println("=" + strings.Repeat("=", 60))

	suite := &IntegrityTestSuite{
		conn:    conn,
		results: make([]IntegrityResult, 0),
	}

	// Run all integrity tests
	suite.runSchemaIntegrityTests()
	suite.runConstraintTests()
	suite.runDataConsistencyTests()
	suite.runReferentialIntegrityTests()
	suite.runBusinessRuleTests()
	suite.runStatisticsIntegrityTests()

	// Generate report
	suite.generateReport()
}

func (its *IntegrityTestSuite) runTest(test IntegrityTest) {
	fmt.Printf("🔍 Testing: %s\n", test.Name)

	start := time.Now()

	var actual interface{}
	var err error

	// Execute the test query
	err = its.conn.QueryRow(context.Background(), test.Query).Scan(&actual)
	duration := time.Since(start)

	result := IntegrityResult{
		Test:     test,
		Actual:   actual,
		Duration: duration,
		Error:    err,
	}

	// Evaluate success based on comparison type
	if err == nil {
		result.Success = its.evaluateResult(test, actual)
	}

	its.results = append(its.results, result)

	if result.Success {
		fmt.Printf("✅ PASS (%v) - Expected: %v, Got: %v\n", duration, test.Expected, actual)
	} else {
		fmt.Printf("❌ FAIL (%v) - Expected: %v, Got: %v", duration, test.Expected, actual)
		if err != nil {
			fmt.Printf(" (Error: %v)", err)
		}
		fmt.Println()
	}
	fmt.Println()
}

func (its *IntegrityTestSuite) evaluateResult(test IntegrityTest, actual interface{}) bool {
	switch test.Comparison {
	case "equals":
		return fmt.Sprintf("%v", actual) == fmt.Sprintf("%v", test.Expected)
	case "greater_than":
		if actualInt, ok := actual.(int64); ok {
			if expectedInt, ok := test.Expected.(int64); ok {
				return actualInt > expectedInt
			}
		}
		return false
	case "less_than":
		if actualInt, ok := actual.(int64); ok {
			if expectedInt, ok := test.Expected.(int64); ok {
				return actualInt < expectedInt
			}
		}
		return false
	case "not_zero":
		if actualInt, ok := actual.(int64); ok {
			return actualInt != 0
		}
		return false
	case "zero":
		if actualInt, ok := actual.(int64); ok {
			return actualInt == 0
		}
		return false
	default:
		return false
	}
}

func (its *IntegrityTestSuite) runSchemaIntegrityTests() {
	fmt.Println("\n📋 SCHEMA INTEGRITY TESTS")
	fmt.Println(strings.Repeat("-", 40))

	tests := []IntegrityTest{
		{
			Name:        "Required Tables Exist",
			Category:    "Schema",
			Description: "Verify all required tables exist",
			Query: `
				SELECT COUNT(*) FROM information_schema.tables 
				WHERE table_schema = 'public' 
				AND table_name IN ('user_profiles', 'cities', 'sports', 'tournaments', 'teams', 'players', 'matches', 'match_events', 'team_statistics', 'player_statistics')
			`,
			Expected:   int64(10),
			Comparison: "equals",
		},
		{
			Name:        "Primary Keys Exist",
			Category:    "Schema",
			Description: "Verify all tables have primary keys",
			Query: `
				SELECT COUNT(*) FROM information_schema.table_constraints 
				WHERE constraint_type = 'PRIMARY KEY' 
				AND table_schema = 'public'
			`,
			Expected:   int64(10),
			Comparison: "greater_than",
		},
		{
			Name:        "Foreign Keys Exist",
			Category:    "Schema",
			Description: "Verify foreign key relationships are established",
			Query: `
				SELECT COUNT(*) FROM information_schema.table_constraints 
				WHERE constraint_type = 'FOREIGN KEY' 
				AND table_schema = 'public'
			`,
			Expected:   int64(15),
			Comparison: "greater_than",
		},
		{
			Name:        "Check Constraints Exist",
			Category:    "Schema",
			Description: "Verify check constraints are in place",
			Query: `
				SELECT COUNT(*) FROM information_schema.table_constraints 
				WHERE constraint_type = 'CHECK' 
				AND table_schema = 'public'
			`,
			Expected:   int64(5),
			Comparison: "greater_than",
		},
		{
			Name:        "Unique Constraints Exist",
			Category:    "Schema",
			Description: "Verify unique constraints are properly set",
			Query: `
				SELECT COUNT(*) FROM information_schema.table_constraints 
				WHERE constraint_type = 'UNIQUE' 
				AND table_schema = 'public'
			`,
			Expected:   int64(3),
			Comparison: "greater_than",
		},
	}

	for _, test := range tests {
		its.runTest(test)
	}
}

func (its *IntegrityTestSuite) runConstraintTests() {
	fmt.Println("\n🔒 CONSTRAINT VALIDATION TESTS")
	fmt.Println(strings.Repeat("-", 40))

	tests := []IntegrityTest{
		{
			Name:        "Email Uniqueness",
			Category:    "Constraints",
			Description: "Verify email addresses are unique in user_profiles",
			Query: `
				SELECT COUNT(*) FROM (
					SELECT email, COUNT(*) as cnt 
					FROM user_profiles 
					GROUP BY email 
					HAVING COUNT(*) > 1
				) duplicates
			`,
			Expected:   int64(0),
			Comparison: "equals",
		},
		{
			Name:        "Valid User Roles",
			Category:    "Constraints",
			Description: "Verify all user roles are valid",
			Query: `
				SELECT COUNT(*) FROM user_profiles 
				WHERE primary_role NOT IN ('super_admin', 'city_admin', 'tournament_admin', 'owner', 'coach', 'referee', 'player', 'client')
			`,
			Expected:   int64(0),
			Comparison: "equals",
		},
		{
			Name:        "Valid Account Status",
			Category:    "Constraints",
			Description: "Verify all account statuses are valid",
			Query: `
				SELECT COUNT(*) FROM user_profiles 
				WHERE account_status NOT IN ('active', 'suspended', 'payment_pending', 'disabled')
			`,
			Expected:   int64(0),
			Comparison: "equals",
		},
		{
			Name:        "Valid Tournament Status",
			Category:    "Constraints",
			Description: "Verify all tournament statuses are valid",
			Query: `
				SELECT COUNT(*) FROM tournaments 
				WHERE status NOT IN ('pending', 'approved', 'active', 'completed', 'cancelled')
			`,
			Expected:   int64(0),
			Comparison: "equals",
		},
		{
			Name:        "Valid Match Status",
			Category:    "Constraints",
			Description: "Verify all match statuses are valid",
			Query: `
				SELECT COUNT(*) FROM matches 
				WHERE status NOT IN ('scheduled', 'live', 'completed', 'cancelled', 'postponed')
			`,
			Expected:   int64(0),
			Comparison: "equals",
		},
	}

	for _, test := range tests {
		its.runTest(test)
	}
}

func (its *IntegrityTestSuite) runDataConsistencyTests() {
	fmt.Println("\n📊 DATA CONSISTENCY TESTS")
	fmt.Println(strings.Repeat("-", 40))

	tests := []IntegrityTest{
		{
			Name:        "Tournament Date Consistency",
			Category:    "Consistency",
			Description: "Verify tournament end dates are after start dates",
			Query: `
				SELECT COUNT(*) FROM tournaments 
				WHERE end_date <= start_date
			`,
			Expected:   int64(0),
			Comparison: "equals",
		},
		{
			Name:        "Match Date Consistency",
			Category:    "Consistency",
			Description: "Verify match dates are within tournament date ranges",
			Query: `
				SELECT COUNT(*) FROM matches m
				JOIN tournaments t ON m.tournament_id = t.tournament_id
				WHERE m.match_date < t.start_date OR m.match_date > t.end_date
			`,
			Expected:   int64(0),
			Comparison: "equals",
		},
		{
			Name:        "Player Age Consistency",
			Category:    "Consistency",
			Description: "Verify player birth dates are reasonable",
			Query: `
				SELECT COUNT(*) FROM players 
				WHERE date_of_birth > CURRENT_DATE 
				OR date_of_birth < CURRENT_DATE - INTERVAL '100 years'
			`,
			Expected:   int64(0),
			Comparison: "equals",
		},
		{
			Name:        "Team Player Consistency",
			Category:    "Consistency",
			Description: "Verify team players have valid join/leave dates",
			Query: `
				SELECT COUNT(*) FROM team_players 
				WHERE leave_date IS NOT NULL AND leave_date <= join_date
			`,
			Expected:   int64(0),
			Comparison: "equals",
		},
		{
			Name:        "Statistics Consistency",
			Category:    "Consistency",
			Description: "Verify statistics values are non-negative",
			Query: `
				SELECT COUNT(*) FROM player_statistics 
				WHERE matches_played < 0 OR goals_scored < 0 OR assists < 0 
				OR yellow_cards < 0 OR red_cards < 0 OR minutes_played < 0
			`,
			Expected:   int64(0),
			Comparison: "equals",
		},
	}

	for _, test := range tests {
		its.runTest(test)
	}
}

func (its *IntegrityTestSuite) runReferentialIntegrityTests() {
	fmt.Println("\n🔗 REFERENTIAL INTEGRITY TESTS")
	fmt.Println(strings.Repeat("-", 40))

	tests := []IntegrityTest{
		{
			Name:        "Tournament City References",
			Category:    "Referential",
			Description: "Verify all tournaments reference valid cities",
			Query: `
				SELECT COUNT(*) FROM tournaments t
				LEFT JOIN cities c ON t.city_id = c.city_id
				WHERE c.city_id IS NULL
			`,
			Expected:   int64(0),
			Comparison: "equals",
		},
		{
			Name:        "Tournament Sport References",
			Category:    "Referential",
			Description: "Verify all tournaments reference valid sports",
			Query: `
				SELECT COUNT(*) FROM tournaments t
				LEFT JOIN sports s ON t.sport_id = s.sport_id
				WHERE s.sport_id IS NULL
			`,
			Expected:   int64(0),
			Comparison: "equals",
		},
		{
			Name:        "Tournament Admin References",
			Category:    "Referential",
			Description: "Verify all tournaments reference valid admin users",
			Query: `
				SELECT COUNT(*) FROM tournaments t
				LEFT JOIN user_profiles u ON t.admin_user_id = u.user_id
				WHERE u.user_id IS NULL
			`,
			Expected:   int64(0),
			Comparison: "equals",
		},
		{
			Name:        "Team Owner References",
			Category:    "Referential",
			Description: "Verify all teams reference valid owner users",
			Query: `
				SELECT COUNT(*) FROM teams t
				LEFT JOIN user_profiles u ON t.owner_user_id = u.user_id
				WHERE u.user_id IS NULL
			`,
			Expected:   int64(0),
			Comparison: "equals",
		},
		{
			Name:        "Match Tournament References",
			Category:    "Referential",
			Description: "Verify all matches reference valid tournaments",
			Query: `
				SELECT COUNT(*) FROM matches m
				LEFT JOIN tournaments t ON m.tournament_id = t.tournament_id
				WHERE t.tournament_id IS NULL
			`,
			Expected:   int64(0),
			Comparison: "equals",
		},
		{
			Name:        "Match Team References",
			Category:    "Referential",
			Description: "Verify all matches reference valid teams",
			Query: `
				SELECT COUNT(*) FROM matches m
				LEFT JOIN teams t1 ON m.home_team_id = t1.team_id
				LEFT JOIN teams t2 ON m.away_team_id = t2.team_id
				WHERE t1.team_id IS NULL OR t2.team_id IS NULL
			`,
			Expected:   int64(0),
			Comparison: "equals",
		},
	}

	for _, test := range tests {
		its.runTest(test)
	}
}

func (its *IntegrityTestSuite) runBusinessRuleTests() {
	fmt.Println("\n💼 BUSINESS RULE VALIDATION TESTS")
	fmt.Println(strings.Repeat("-", 40))

	tests := []IntegrityTest{
		{
			Name:        "Team Self-Match Prevention",
			Category:    "Business Rules",
			Description: "Verify teams cannot play against themselves",
			Query: `
				SELECT COUNT(*) FROM matches 
				WHERE home_team_id = away_team_id
			`,
			Expected:   int64(0),
			Comparison: "equals",
		},
		{
			Name:        "Tournament Team Sport Consistency",
			Category:    "Business Rules",
			Description: "Verify tournament teams match tournament sport",
			Query: `
				SELECT COUNT(*) FROM tournament_teams tt
				JOIN tournaments t ON tt.tournament_id = t.tournament_id
				JOIN teams tm ON tt.team_id = tm.team_id
				WHERE t.sport_id != tm.sport_id
			`,
			Expected:   int64(0),
			Comparison: "equals",
		},
		{
			Name:        "Tournament Team City Consistency",
			Category:    "Business Rules",
			Description: "Verify tournament teams match tournament city",
			Query: `
				SELECT COUNT(*) FROM tournament_teams tt
				JOIN tournaments t ON tt.tournament_id = t.tournament_id
				JOIN teams tm ON tt.team_id = tm.team_id
				WHERE t.city_id != tm.city_id
			`,
			Expected:   int64(0),
			Comparison: "equals",
		},
		{
			Name:        "Active User Profiles",
			Category:    "Business Rules",
			Description: "Verify active users have proper account status",
			Query: `
				SELECT COUNT(*) FROM user_profiles 
				WHERE is_active = TRUE AND account_status NOT IN ('active', 'payment_pending')
			`,
			Expected:   int64(0),
			Comparison: "equals",
		},
		{
			Name:        "Statistics Match Consistency",
			Category:    "Business Rules",
			Description: "Verify player statistics don't exceed reasonable limits",
			Query: `
				SELECT COUNT(*) FROM player_statistics 
				WHERE goals_scored > matches_played * 10 
				OR assists > matches_played * 10
				OR minutes_played > matches_played * 120
			`,
			Expected:   int64(0),
			Comparison: "equals",
		},
	}

	for _, test := range tests {
		its.runTest(test)
	}
}

func (its *IntegrityTestSuite) runStatisticsIntegrityTests() {
	fmt.Println("\n📈 STATISTICS INTEGRITY TESTS")
	fmt.Println(strings.Repeat("-", 40))

	tests := []IntegrityTest{
		{
			Name:        "Team Statistics Consistency",
			Category:    "Statistics",
			Description: "Verify team wins + losses + draws = matches played",
			Query: `
				SELECT COUNT(*) FROM team_statistics 
				WHERE matches_played != (wins + losses + draws)
				AND matches_played > 0
			`,
			Expected:   int64(0),
			Comparison: "equals",
		},
		{
			Name:        "Player Statistics Consistency",
			Category:    "Statistics",
			Description: "Verify player wins + losses + draws = matches played",
			Query: `
				SELECT COUNT(*) FROM player_statistics 
				WHERE matches_played != (wins + losses + draws)
				AND matches_played > 0
			`,
			Expected:   int64(0),
			Comparison: "equals",
		},
		{
			Name:        "Team Points Calculation",
			Category:    "Statistics",
			Description: "Verify team points calculation (3 points per win, 1 per draw)",
			Query: `
				SELECT COUNT(*) FROM team_statistics 
				WHERE points != (wins * 3 + draws * 1)
				AND matches_played > 0
			`,
			Expected:   int64(0),
			Comparison: "equals",
		},
		{
			Name:        "Goal Difference Calculation",
			Category:    "Statistics",
			Description: "Verify goal difference = goals for - goals against",
			Query: `
				SELECT COUNT(*) FROM team_statistics 
				WHERE goal_difference != (goals_for - goals_against)
				AND matches_played > 0
			`,
			Expected:   int64(0),
			Comparison: "equals",
		},
		{
			Name:        "Statistics Update Timestamps",
			Category:    "Statistics",
			Description: "Verify statistics have recent update timestamps",
			Query: `
				SELECT COUNT(*) FROM team_statistics 
				WHERE updated_at < CURRENT_DATE - INTERVAL '30 days'
				AND matches_played > 0
			`,
			Expected:   int64(0),
			Comparison: "equals",
		},
	}

	for _, test := range tests {
		its.runTest(test)
	}
}

func (its *IntegrityTestSuite) generateReport() {
	fmt.Println("\n" + strings.Repeat("=", 60))
	fmt.Println("🔍 DATA INTEGRITY TEST REPORT")
	fmt.Println(strings.Repeat("=", 60))

	// Count results by category
	categoryStats := make(map[string]struct {
		Total  int
		Passed int
		Failed int
	})

	totalTests := len(its.results)
	totalPassed := 0
	totalFailed := 0
	totalDuration := time.Duration(0)

	for _, result := range its.results {
		stats := categoryStats[result.Test.Category]
		stats.Total++
		if result.Success {
			stats.Passed++
			totalPassed++
		} else {
			stats.Failed++
			totalFailed++
		}
		categoryStats[result.Test.Category] = stats
		totalDuration += result.Duration
	}

	// Overall summary
	fmt.Printf("📋 OVERALL INTEGRITY TEST SUMMARY\n")
	fmt.Printf("Total Tests: %d\n", totalTests)
	fmt.Printf("Passed: %d (%.1f%%)\n", totalPassed, float64(totalPassed)/float64(totalTests)*100)
	fmt.Printf("Failed: %d (%.1f%%)\n", totalFailed, float64(totalFailed)/float64(totalTests)*100)
	fmt.Printf("Total Duration: %v\n", totalDuration)
	fmt.Printf("Average Duration: %v\n", totalDuration/time.Duration(totalTests))
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
		fmt.Printf("❌ FAILED INTEGRITY TESTS\n")
		fmt.Println(strings.Repeat("-", 50))
		for _, result := range its.results {
			if !result.Success {
				fmt.Printf("• %s (%s)\n", result.Test.Name, result.Test.Category)
				fmt.Printf("  Expected: %v, Got: %v\n", result.Test.Expected, result.Actual)
				if result.Error != nil {
					fmt.Printf("  Error: %v\n", result.Error)
				}
				fmt.Printf("  Description: %s\n", result.Test.Description)
				fmt.Println()
			}
		}
	}

	// Critical issues summary
	criticalIssues := 0
	for _, result := range its.results {
		if !result.Success && (result.Test.Category == "Referential" || result.Test.Category == "Constraints") {
			criticalIssues++
		}
	}

	fmt.Printf("🚨 CRITICAL ISSUES SUMMARY\n")
	fmt.Println(strings.Repeat("-", 50))
	if criticalIssues == 0 {
		fmt.Println("✅ No critical data integrity issues found")
	} else {
		fmt.Printf("⚠️  %d critical data integrity issues found\n", criticalIssues)
		fmt.Println("   These issues must be resolved before production deployment")
	}
	fmt.Println()

	// Recommendations
	fmt.Printf("💡 RECOMMENDATIONS\n")
	fmt.Println(strings.Repeat("-", 50))
	if totalFailed == 0 {
		fmt.Println("✅ All data integrity tests passed")
		fmt.Println("• Continue with regular integrity monitoring")
		fmt.Println("• Set up automated integrity checks")
		fmt.Println("• Monitor data quality metrics")
	} else {
		fmt.Println("⚠️  Data integrity issues detected")
		fmt.Println("• Fix all constraint violations immediately")
		fmt.Println("• Review and correct referential integrity issues")
		fmt.Println("• Implement additional data validation")
		fmt.Println("• Set up monitoring for data quality")
	}
	fmt.Println()

	// Final status
	if totalFailed == 0 {
		fmt.Println("🎉 ALL DATA INTEGRITY TESTS PASSED! Database is consistent and reliable.")
	} else {
		fmt.Printf("⚠️  %d DATA INTEGRITY TESTS FAILED. Review and fix issues before production.\n", totalFailed)
	}

	fmt.Println(strings.Repeat("=", 60))
}
