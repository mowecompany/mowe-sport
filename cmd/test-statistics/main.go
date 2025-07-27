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

	// Test statistics functions
	testStatisticsFunctions(db)
}

func testStatisticsFunctions(db *sql.DB) {
	fmt.Println("=== COMPREHENSIVE STATISTICS FUNCTIONS TESTING ===")
	fmt.Println("")

	// Test 1: Function Existence Check
	fmt.Println("--- Statistics Functions Validation ---")
	statisticsFunctions := []string{
		"recalculate_player_statistics",
		"recalculate_all_player_statistics",
		"recalculate_team_statistics",
		"recalculate_all_team_statistics",
		"update_tournament_standings",
		"update_player_rankings",
		"update_all_player_rankings",
		"recalculate_tournament_statistics",
		"daily_statistics_maintenance",
		"get_tournament_statistics_summary",
	}

	for _, funcName := range statisticsFunctions {
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

	// Test 2: Trigger Functions Validation
	fmt.Println("--- Statistics Trigger Functions Validation ---")
	triggerFunctions := []string{
		"handle_match_completion",
		"handle_match_event_change",
		"handle_match_lineup_change",
		"handle_tournament_status_change",
	}

	for _, funcName := range triggerFunctions {
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
			fmt.Printf("❌ Error checking trigger function %s: %v\n", funcName, err)
		} else if exists {
			fmt.Printf("✅ Trigger function %s exists\n", funcName)
		} else {
			fmt.Printf("❌ Trigger function %s missing\n", funcName)
		}
	}
	fmt.Println("")

	// Test 3: Statistics Tables Validation
	fmt.Println("--- Statistics Tables Validation ---")
	statisticsTables := []string{
		"player_statistics",
		"team_statistics",
		"tournament_standings",
		"player_rankings",
		"historical_statistics",
	}

	for _, tableName := range statisticsTables {
		var exists bool
		err := db.QueryRow(`
			SELECT EXISTS(
				SELECT 1 FROM information_schema.tables
				WHERE table_schema = 'public'
				AND table_name = $1
			)
		`, tableName).Scan(&exists)

		if err != nil {
			fmt.Printf("❌ Error checking table %s: %v\n", tableName, err)
		} else if exists {
			fmt.Printf("✅ Table %s exists\n", tableName)
		} else {
			fmt.Printf("❌ Table %s missing\n", tableName)
		}
	}
	fmt.Println("")

	// Test 4: Test Tournament Statistics Summary
	fmt.Println("--- Tournament Statistics Summary Test ---")
	testTournamentID := "22222222-2222-2222-2222-222222222222" // Bogotá Football Tournament

	var summaryResult string
	err := db.QueryRow("SELECT public.get_tournament_statistics_summary($1)::text", testTournamentID).Scan(&summaryResult)
	if err != nil {
		fmt.Printf("❌ Error getting tournament statistics summary: %v\n", err)
	} else {
		fmt.Printf("✅ Tournament statistics summary: %s\n", summaryResult)
	}
	fmt.Println("")

	// Test 5: Test Player Statistics Recalculation
	fmt.Println("--- Player Statistics Recalculation Test ---")
	testPlayerID := "44444444-4444-4444-4444-444444444444" // Test player
	testTeamID := "33333333-3333-3333-3333-333333333333"   // Test team

	var playerStatsResult string
	err = db.QueryRow("SELECT public.recalculate_player_statistics($1, $2, $3)::text",
		testPlayerID, testTournamentID, testTeamID).Scan(&playerStatsResult)
	if err != nil {
		fmt.Printf("❌ Error recalculating player statistics: %v\n", err)
	} else {
		fmt.Printf("✅ Player statistics recalculation: %s\n", playerStatsResult)
	}
	fmt.Println("")

	// Test 6: Test Team Statistics Recalculation
	fmt.Println("--- Team Statistics Recalculation Test ---")

	var teamStatsResult string
	err = db.QueryRow("SELECT public.recalculate_team_statistics($1, $2, $3)::text",
		testTeamID, testTournamentID, nil).Scan(&teamStatsResult)
	if err != nil {
		fmt.Printf("❌ Error recalculating team statistics: %v\n", err)
	} else {
		fmt.Printf("✅ Team statistics recalculation: %s\n", teamStatsResult)
	}
	fmt.Println("")

	// Test 7: Test Tournament Standings Update
	fmt.Println("--- Tournament Standings Update Test ---")

	var standingsResult string
	err = db.QueryRow("SELECT public.update_tournament_standings($1, $2, $3, $4)::text",
		testTournamentID, nil, nil, nil).Scan(&standingsResult)
	if err != nil {
		fmt.Printf("❌ Error updating tournament standings: %v\n", err)
	} else {
		fmt.Printf("✅ Tournament standings update: %s\n", standingsResult)
	}
	fmt.Println("")

	// Test 8: Test Player Rankings Update
	fmt.Println("--- Player Rankings Update Test ---")

	var rankingsResult string
	err = db.QueryRow("SELECT public.update_player_rankings($1, $2, $3)::text",
		testTournamentID, "top_scorer", nil).Scan(&rankingsResult)
	if err != nil {
		fmt.Printf("❌ Error updating player rankings: %v\n", err)
	} else {
		fmt.Printf("✅ Player rankings update (top_scorer): %s\n", rankingsResult)
	}
	fmt.Println("")

	// Test 9: Test All Player Rankings Update
	fmt.Println("--- All Player Rankings Update Test ---")

	var allRankingsResult string
	err = db.QueryRow("SELECT public.update_all_player_rankings($1, $2)::text",
		testTournamentID, nil).Scan(&allRankingsResult)
	if err != nil {
		fmt.Printf("❌ Error updating all player rankings: %v\n", err)
	} else {
		fmt.Printf("✅ All player rankings update: %s\n", allRankingsResult)
	}
	fmt.Println("")

	// Test 10: Test Comprehensive Tournament Statistics Recalculation
	fmt.Println("--- Comprehensive Tournament Statistics Recalculation Test ---")

	var comprehensiveResult string
	err = db.QueryRow("SELECT public.recalculate_tournament_statistics($1, $2)::text",
		testTournamentID, nil).Scan(&comprehensiveResult)
	if err != nil {
		fmt.Printf("❌ Error in comprehensive tournament statistics recalculation: %v\n", err)
	} else {
		fmt.Printf("✅ Comprehensive tournament statistics recalculation: %s\n", comprehensiveResult)
	}
	fmt.Println("")

	// Test 11: Test Daily Statistics Maintenance
	fmt.Println("--- Daily Statistics Maintenance Test ---")

	var maintenanceResult string
	err = db.QueryRow("SELECT public.daily_statistics_maintenance()::text").Scan(&maintenanceResult)
	if err != nil {
		fmt.Printf("❌ Error in daily statistics maintenance: %v\n", err)
	} else {
		fmt.Printf("✅ Daily statistics maintenance: %s\n", maintenanceResult)
	}
	fmt.Println("")

	// Test 12: Check Statistics Data Integrity
	fmt.Println("--- Statistics Data Integrity Check ---")

	// Check player statistics
	var playerStatsCount int
	err = db.QueryRow("SELECT COUNT(*) FROM public.player_statistics").Scan(&playerStatsCount)
	if err != nil {
		fmt.Printf("❌ Error checking player statistics count: %v\n", err)
	} else {
		fmt.Printf("✅ Player statistics records: %d\n", playerStatsCount)
	}

	// Check team statistics
	var teamStatsCount int
	err = db.QueryRow("SELECT COUNT(*) FROM public.team_statistics").Scan(&teamStatsCount)
	if err != nil {
		fmt.Printf("❌ Error checking team statistics count: %v\n", err)
	} else {
		fmt.Printf("✅ Team statistics records: %d\n", teamStatsCount)
	}

	// Check tournament standings
	var standingsCount int
	err = db.QueryRow("SELECT COUNT(*) FROM public.tournament_standings").Scan(&standingsCount)
	if err != nil {
		fmt.Printf("❌ Error checking tournament standings count: %v\n", err)
	} else {
		fmt.Printf("✅ Tournament standings records: %d\n", standingsCount)
	}

	// Check player rankings
	var rankingsCount int
	err = db.QueryRow("SELECT COUNT(*) FROM public.player_rankings").Scan(&rankingsCount)
	if err != nil {
		fmt.Printf("❌ Error checking player rankings count: %v\n", err)
	} else {
		fmt.Printf("✅ Player rankings records: %d\n", rankingsCount)
	}
	fmt.Println("")

	// Test 13: Test Statistics Views
	fmt.Println("--- Statistics Views Test ---")

	// Test current_top_scorers view
	rows, err := db.Query("SELECT tournament_id, first_name, last_name, team_name, goals_scored, position FROM public.current_top_scorers LIMIT 5")
	if err != nil {
		fmt.Printf("❌ Error querying current_top_scorers view: %v\n", err)
	} else {
		defer rows.Close()
		scorerCount := 0
		fmt.Println("📊 Top Scorers:")
		for rows.Next() {
			var tournamentID, firstName, lastName, teamName string
			var goalsScored, position int

			err := rows.Scan(&tournamentID, &firstName, &lastName, &teamName, &goalsScored, &position)
			if err != nil {
				fmt.Printf("❌ Error scanning top scorer: %v\n", err)
				continue
			}

			fmt.Printf("  %d. %s %s (%s) - %d goals\n", position, firstName, lastName, teamName, goalsScored)
			scorerCount++
		}
		if scorerCount == 0 {
			fmt.Println("  ℹ️  No top scorers data available")
		} else {
			fmt.Printf("✅ Found %d top scorers\n", scorerCount)
		}
	}
	fmt.Println("")

	// Test 14: Test Triggers Existence
	fmt.Println("--- Statistics Triggers Validation ---")
	triggers := []string{
		"trigger_match_completion",
		"trigger_match_event_change",
		"trigger_match_lineup_change",
		"trigger_tournament_status_change",
	}

	for _, triggerName := range triggers {
		var exists bool
		err := db.QueryRow(`
			SELECT EXISTS(
				SELECT 1 FROM information_schema.triggers
				WHERE trigger_schema = 'public'
				AND trigger_name = $1
			)
		`, triggerName).Scan(&exists)

		if err != nil {
			fmt.Printf("❌ Error checking trigger %s: %v\n", triggerName, err)
		} else if exists {
			fmt.Printf("✅ Trigger %s exists\n", triggerName)
		} else {
			fmt.Printf("❌ Trigger %s missing\n", triggerName)
		}
	}
	fmt.Println("")

	// Test 15: Performance Test
	fmt.Println("--- Statistics Performance Test ---")

	start := time.Now()
	err = db.QueryRow("SELECT public.recalculate_tournament_statistics($1, $2)::text",
		testTournamentID, nil).Scan(&comprehensiveResult)
	duration := time.Since(start)

	if err != nil {
		fmt.Printf("❌ Performance test failed: %v\n", err)
	} else {
		fmt.Printf("✅ Comprehensive recalculation completed in %v\n", duration)
		if duration < 5*time.Second {
			fmt.Printf("✅ Performance: GOOD (< 5 seconds)\n")
		} else if duration < 10*time.Second {
			fmt.Printf("⚠️  Performance: ACCEPTABLE (5-10 seconds)\n")
		} else {
			fmt.Printf("❌ Performance: SLOW (> 10 seconds)\n")
		}
	}

	fmt.Println("")
	fmt.Println("🎉 Statistics Functions Testing Complete!")
}
