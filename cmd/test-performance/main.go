package main

import (
	"context"
	"fmt"
	"log"
	"os"
	"time"

	"github.com/jackc/pgx/v5"
	"github.com/joho/godotenv"
)

type PerformanceTest struct {
	Name        string
	Query       string
	ExpectedMs  int64
	Description string
}

type TestResult struct {
	Name          string
	ExecutionTime time.Duration
	RowCount      int64
	Success       bool
	Error         error
	ExpectedMs    int64
	PerformanceOK bool
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

	fmt.Println("🚀 Starting Mowe Sport Performance Tests")
	fmt.Println("=" + fmt.Sprintf("%50s", "="))

	// Define performance tests
	tests := []PerformanceTest{
		{
			Name:        "Tournament Listings",
			ExpectedMs:  500,
			Description: "Test tournament listing query performance",
			Query: `
				SELECT t.tournament_id, t.name, c.name as city_name, s.name as sport_name,
					   t.start_date, t.end_date, t.status, t.is_public
				FROM tournaments t
				JOIN cities c ON t.city_id = c.city_id
				JOIN sports s ON t.sport_id = s.sport_id
				WHERE t.status IN ('active', 'approved', 'pending')
				AND t.is_public = TRUE
				ORDER BY t.start_date DESC
				LIMIT 100;
			`,
		},
		{
			Name:        "Team Statistics Query",
			ExpectedMs:  300,
			Description: "Test team statistics aggregation performance",
			Query: `
				SELECT ts.team_id, t.name, ts.matches_played, ts.wins, ts.draws, ts.losses,
					   ts.goals_for, ts.goals_against, ts.goal_difference, ts.points,
					   ts.current_position
				FROM team_statistics ts
				JOIN teams t ON ts.team_id = t.team_id
				WHERE ts.matches_played > 0
				ORDER BY ts.points DESC, ts.goal_difference DESC
				LIMIT 50;
			`,
		},
		{
			Name:        "Player Statistics Query",
			ExpectedMs:  400,
			Description: "Test player statistics query performance",
			Query: `
				SELECT ps.player_id, p.first_name, p.last_name, t.name as team_name,
					   ps.goals_scored, ps.assists, ps.matches_played, ps.minutes_played,
					   ps.yellow_cards, ps.red_cards
				FROM player_statistics ps
				JOIN players p ON ps.player_id = p.player_id
				JOIN teams t ON ps.team_id = t.team_id
				WHERE ps.matches_played > 0
				ORDER BY ps.goals_scored DESC, ps.assists DESC
				LIMIT 100;
			`,
		},
		{
			Name:        "Live Matches Query",
			ExpectedMs:  200,
			Description: "Test live matches query performance",
			Query: `
				SELECT m.match_id, m.tournament_id, 
					   ht.name as home_team, at.name as away_team,
					   m.home_team_score, m.away_team_score, m.status,
					   m.match_date, m.match_time, m.actual_start_time
				FROM matches m
				JOIN teams ht ON m.home_team_id = ht.team_id
				JOIN teams at ON m.away_team_id = at.team_id
				WHERE m.status IN ('live', 'half_time', 'scheduled')
				ORDER BY m.match_date, m.match_time
				LIMIT 50;
			`,
		},
		{
			Name:        "Match Events Query",
			ExpectedMs:  600,
			Description: "Test match events query performance",
			Query: `
				SELECT me.event_id, me.match_id, me.event_type, me.event_minute,
					   p.first_name, p.last_name, t.name as team_name,
					   me.description, me.created_at
				FROM match_events me
				LEFT JOIN players p ON me.player_id = p.player_id
				JOIN teams t ON me.team_id = t.team_id
				JOIN matches m ON me.match_id = m.match_id
				WHERE me.is_deleted = FALSE
				AND m.match_date >= CURRENT_DATE - INTERVAL '7 days'
				ORDER BY me.created_at DESC
				LIMIT 200;
			`,
		},
		{
			Name:        "User Roles Query",
			ExpectedMs:  150,
			Description: "Test user roles and permissions query performance",
			Query: `
				SELECT up.user_id, up.email, up.first_name, up.last_name,
					   ur.role_name, c.name as city_name, s.name as sport_name,
					   ur.is_active
				FROM user_profiles up
				JOIN user_roles_by_city_sport ur ON up.user_id = ur.user_id
				LEFT JOIN cities c ON ur.city_id = c.city_id
				LEFT JOIN sports s ON ur.sport_id = s.sport_id
				WHERE up.is_active = TRUE
				AND ur.is_active = TRUE
				ORDER BY up.created_at DESC
				LIMIT 100;
			`,
		},
		{
			Name:        "Full-Text Search Teams",
			ExpectedMs:  800,
			Description: "Test full-text search performance for teams",
			Query: `
				SELECT t.team_id, t.name, t.short_name, t.description,
					   c.name as city_name, s.name as sport_name
				FROM teams t
				JOIN cities c ON t.city_id = c.city_id
				JOIN sports s ON t.sport_id = s.sport_id
				WHERE to_tsvector('spanish', t.name || ' ' || COALESCE(t.short_name, '') || ' ' || COALESCE(t.description, ''))
					  @@ plainto_tsquery('spanish', 'futbol')
				AND t.is_active = TRUE
				ORDER BY ts_rank(to_tsvector('spanish', t.name), plainto_tsquery('spanish', 'futbol')) DESC
				LIMIT 20;
			`,
		},
		{
			Name:        "Complex Tournament Stats",
			ExpectedMs:  1000,
			Description: "Test complex tournament statistics aggregation",
			Query: `
				SELECT t.tournament_id, t.name,
					   COUNT(DISTINCT tt.team_id) as total_teams,
					   COUNT(DISTINCT m.match_id) as total_matches,
					   COUNT(DISTINCT CASE WHEN m.status = 'completed' THEN m.match_id END) as completed_matches,
					   SUM(m.home_team_score + m.away_team_score) as total_goals,
					   AVG(m.home_team_score + m.away_team_score) as avg_goals_per_match
				FROM tournaments t
				LEFT JOIN tournament_teams tt ON t.tournament_id = tt.tournament_id
				LEFT JOIN matches m ON t.tournament_id = m.tournament_id
				WHERE t.status IN ('active', 'completed')
				GROUP BY t.tournament_id, t.name
				HAVING COUNT(DISTINCT tt.team_id) > 0
				ORDER BY total_goals DESC NULLS LAST
				LIMIT 20;
			`,
		},
	}

	// Run performance tests
	results := make([]TestResult, 0, len(tests))
	totalTests := len(tests)
	passedTests := 0

	for i, test := range tests {
		fmt.Printf("\n[%d/%d] Testing: %s\n", i+1, totalTests, test.Name)
		fmt.Printf("Description: %s\n", test.Description)
		fmt.Printf("Expected: < %dms\n", test.ExpectedMs)

		result := runPerformanceTest(conn, test)
		results = append(results, result)

		if result.Success {
			fmt.Printf("✅ Execution Time: %v (%dms)\n", result.ExecutionTime, result.ExecutionTime.Milliseconds())
			fmt.Printf("📊 Rows Returned: %d\n", result.RowCount)

			if result.PerformanceOK {
				fmt.Printf("🚀 Performance: GOOD\n")
				passedTests++
			} else {
				fmt.Printf("⚠️  Performance: SLOW (expected <%dms)\n", result.ExpectedMs)
			}
		} else {
			fmt.Printf("❌ Error: %v\n", result.Error)
		}
	}

	// Print summary
	fmt.Println("\n" + "=" + fmt.Sprintf("%50s", "="))
	fmt.Println("📋 PERFORMANCE TEST SUMMARY")
	fmt.Println("=" + fmt.Sprintf("%50s", "="))
	fmt.Printf("Total Tests: %d\n", totalTests)
	fmt.Printf("Passed: %d\n", passedTests)
	fmt.Printf("Failed: %d\n", totalTests-passedTests)
	fmt.Printf("Success Rate: %.1f%%\n", float64(passedTests)/float64(totalTests)*100)

	// Detailed results
	fmt.Println("\n📊 DETAILED RESULTS:")
	fmt.Println("-" + fmt.Sprintf("%50s", "-"))
	for _, result := range results {
		status := "❌ FAIL"
		if result.Success && result.PerformanceOK {
			status = "✅ PASS"
		} else if result.Success {
			status = "⚠️  SLOW"
		}

		fmt.Printf("%-25s %s %6dms (%d rows)\n",
			result.Name, status, result.ExecutionTime.Milliseconds(), result.RowCount)
	}

	// Run additional analysis
	fmt.Println("\n🔍 RUNNING ADDITIONAL ANALYSIS...")
	runIndexAnalysis(conn)
	runTableAnalysis(conn)

	fmt.Println("\n✅ Performance testing completed!")
}

func runPerformanceTest(conn *pgx.Conn, test PerformanceTest) TestResult {
	result := TestResult{
		Name:       test.Name,
		ExpectedMs: test.ExpectedMs,
	}

	start := time.Now()

	rows, err := conn.Query(context.Background(), test.Query)
	if err != nil {
		result.Error = err
		result.Success = false
		return result
	}
	defer rows.Close()

	// Count rows
	rowCount := int64(0)
	for rows.Next() {
		rowCount++
	}

	result.ExecutionTime = time.Since(start)
	result.RowCount = rowCount
	result.Success = true
	result.PerformanceOK = result.ExecutionTime.Milliseconds() <= test.ExpectedMs

	return result
}

func runIndexAnalysis(conn *pgx.Conn) {
	fmt.Println("\n📈 INDEX USAGE ANALYSIS:")
	fmt.Println("-" + fmt.Sprintf("%30s", "-"))

	query := `
		SELECT 
			schemaname,
			tablename,
			indexname,
			idx_scan,
			idx_tup_read,
			CASE 
				WHEN idx_scan > 0 
				THEN ROUND((idx_tup_read::NUMERIC / idx_scan), 2)
				ELSE 0 
			END as avg_tuples_per_scan
		FROM pg_stat_user_indexes 
		WHERE schemaname = 'public'
		AND idx_scan > 0
		ORDER BY idx_scan DESC
		LIMIT 10;
	`

	rows, err := conn.Query(context.Background(), query)
	if err != nil {
		fmt.Printf("Error running index analysis: %v\n", err)
		return
	}
	defer rows.Close()

	fmt.Printf("%-20s %-15s %10s %12s\n", "Table", "Index", "Scans", "Avg Tuples")
	fmt.Println("-" + fmt.Sprintf("%60s", "-"))

	for rows.Next() {
		var schema, table, index string
		var scans, tupRead int64
		var avgTuples float64

		err := rows.Scan(&schema, &table, &index, &scans, &tupRead, &avgTuples)
		if err != nil {
			continue
		}

		// Truncate long names
		if len(table) > 20 {
			table = table[:17] + "..."
		}
		if len(index) > 15 {
			index = index[:12] + "..."
		}

		fmt.Printf("%-20s %-15s %10d %12.1f\n", table, index, scans, avgTuples)
	}
}

func runTableAnalysis(conn *pgx.Conn) {
	fmt.Println("\n📊 TABLE SIZE ANALYSIS:")
	fmt.Println("-" + fmt.Sprintf("%30s", "-"))

	query := `
		SELECT 
			schemaname,
			tablename,
			pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename)) as total_size,
			pg_size_pretty(pg_relation_size(schemaname||'.'||tablename)) as table_size,
			n_live_tup as estimated_rows,
			n_tup_ins,
			n_tup_upd,
			n_tup_del
		FROM pg_stat_user_tables 
		WHERE schemaname = 'public'
		ORDER BY pg_total_relation_size(schemaname||'.'||tablename) DESC
		LIMIT 10;
	`

	rows, err := conn.Query(context.Background(), query)
	if err != nil {
		fmt.Printf("Error running table analysis: %v\n", err)
		return
	}
	defer rows.Close()

	fmt.Printf("%-20s %-10s %-10s %10s %8s %8s %8s\n",
		"Table", "Total Size", "Table Size", "Rows", "Inserts", "Updates", "Deletes")
	fmt.Println("-" + fmt.Sprintf("%80s", "-"))

	for rows.Next() {
		var schema, table, totalSize, tableSize string
		var rowCount, inserts, updates, deletes int64

		err := rows.Scan(&schema, &table, &totalSize, &tableSize, &rowCount, &inserts, &updates, &deletes)
		if err != nil {
			continue
		}

		// Truncate long names
		if len(table) > 20 {
			table = table[:17] + "..."
		}

		fmt.Printf("%-20s %-10s %-10s %10d %8d %8d %8d\n",
			table, totalSize, tableSize, rowCount, inserts, updates, deletes)
	}
}
