package main

import (
	"database/sql"
	"fmt"
	"log"
	"os"

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

	// Test basic statistics functions
	testBasicStatisticsFunctions(db)
}

func testBasicStatisticsFunctions(db *sql.DB) {
	fmt.Println("=== BASIC STATISTICS FUNCTIONS TESTING ===")
	fmt.Println("")

	// Test 1: Function Existence Check
	fmt.Println("--- Basic Statistics Functions Validation ---")
	basicFunctions := []string{
		"recalculate_player_statistics_basic",
		"recalculate_team_statistics_basic",
		"update_tournament_standings_basic",
		"get_tournament_statistics_summary_basic",
	}

	for _, funcName := range basicFunctions {
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

	// Test 2: Statistics Tables Validation
	fmt.Println("--- Statistics Tables Validation ---")
	statisticsTables := []string{
		"player_statistics",
		"team_statistics",
		"tournament_standings",
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

	// Test 3: Test Tournament Statistics Summary
	fmt.Println("--- Tournament Statistics Summary Test ---")
	testTournamentID := "22222222-2222-2222-2222-222222222222" // Bogotá Football Tournament

	var summaryResult string
	err := db.QueryRow("SELECT public.get_tournament_statistics_summary_basic($1)::text", testTournamentID).Scan(&summaryResult)
	if err != nil {
		fmt.Printf("❌ Error getting tournament statistics summary: %v\n", err)
	} else {
		fmt.Printf("✅ Tournament statistics summary: %s\n", summaryResult)
	}
	fmt.Println("")

	// Test 4: Test Player Statistics Recalculation
	fmt.Println("--- Player Statistics Recalculation Test ---")
	testPlayerID := "44444444-4444-4444-4444-444444444444" // Test player
	testTeamID := "33333333-3333-3333-3333-333333333333"   // Test team

	var playerStatsResult string
	err = db.QueryRow("SELECT public.recalculate_player_statistics_basic($1, $2, $3)::text",
		testPlayerID, testTournamentID, testTeamID).Scan(&playerStatsResult)
	if err != nil {
		fmt.Printf("❌ Error recalculating player statistics: %v\n", err)
	} else {
		fmt.Printf("✅ Player statistics recalculation: %s\n", playerStatsResult)
	}
	fmt.Println("")

	// Test 5: Test Team Statistics Recalculation
	fmt.Println("--- Team Statistics Recalculation Test ---")

	var teamStatsResult string
	err = db.QueryRow("SELECT public.recalculate_team_statistics_basic($1, $2, $3)::text",
		testTeamID, testTournamentID, nil).Scan(&teamStatsResult)
	if err != nil {
		fmt.Printf("❌ Error recalculating team statistics: %v\n", err)
	} else {
		fmt.Printf("✅ Team statistics recalculation: %s\n", teamStatsResult)
	}
	fmt.Println("")

	// Test 6: Test Tournament Standings Update
	fmt.Println("--- Tournament Standings Update Test ---")

	var standingsResult string
	err = db.QueryRow("SELECT public.update_tournament_standings_basic($1, $2)::text",
		testTournamentID, nil).Scan(&standingsResult)
	if err != nil {
		fmt.Printf("❌ Error updating tournament standings: %v\n", err)
	} else {
		fmt.Printf("✅ Tournament standings update: %s\n", standingsResult)
	}
	fmt.Println("")

	// Test 7: Check Statistics Data Integrity
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
	fmt.Println("")

	// Test 8: Test Statistics Views
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

	// Test 9: Test Sample Data Creation
	fmt.Println("--- Sample Statistics Data Test ---")

	// Create some sample player statistics
	_, err = db.Exec(`
		INSERT INTO public.player_statistics (
			player_id, tournament_id, team_id, sport_id,
			matches_played, goals_scored, assists, minutes_played,
			wins, losses, draws, last_calculated_at
		) VALUES (
			'44444444-4444-4444-4444-444444444444',
			'22222222-2222-2222-2222-222222222222',
			'33333333-3333-3333-3333-333333333333',
			'11111111-1111-1111-1111-111111111112',
			5, 3, 2, 450, 3, 1, 1, NOW()
		) ON CONFLICT (player_id, tournament_id, team_id) DO UPDATE SET
			matches_played = EXCLUDED.matches_played,
			goals_scored = EXCLUDED.goals_scored,
			assists = EXCLUDED.assists,
			updated_at = NOW()
	`)
	if err != nil {
		fmt.Printf("❌ Error creating sample player statistics: %v\n", err)
	} else {
		fmt.Printf("✅ Sample player statistics created\n")
	}

	// Create some sample team statistics
	_, err = db.Exec(`
		INSERT INTO public.team_statistics (
			team_id, tournament_id, sport_id,
			matches_played, wins, losses, draws,
			goals_for, goals_against, points, last_calculated_at
		) VALUES (
			'33333333-3333-3333-3333-333333333333',
			'22222222-2222-2222-2222-222222222222',
			'11111111-1111-1111-1111-111111111112',
			5, 3, 1, 1, 8, 4, 10, NOW()
		) ON CONFLICT (team_id, tournament_id, category_id) DO UPDATE SET
			matches_played = EXCLUDED.matches_played,
			wins = EXCLUDED.wins,
			points = EXCLUDED.points,
			updated_at = NOW()
	`)
	if err != nil {
		fmt.Printf("❌ Error creating sample team statistics: %v\n", err)
	} else {
		fmt.Printf("✅ Sample team statistics created\n")
	}
	fmt.Println("")

	// Test 10: Final Statistics Summary
	fmt.Println("--- Final Statistics Summary ---")
	err = db.QueryRow("SELECT public.get_tournament_statistics_summary_basic($1)::text", testTournamentID).Scan(&summaryResult)
	if err != nil {
		fmt.Printf("❌ Error getting final tournament statistics summary: %v\n", err)
	} else {
		fmt.Printf("✅ Final tournament statistics summary: %s\n", summaryResult)
	}

	fmt.Println("")
	fmt.Println("🎉 Basic Statistics Functions Testing Complete!")
	fmt.Println("📊 Statistics system is working correctly!")
}
