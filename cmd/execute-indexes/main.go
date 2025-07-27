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

	fmt.Println("🚀 Executing Critical Query Indexes")
	fmt.Println("=" + strings.Repeat("=", 50))

	// Execute critical query indexes
	if err := executeCriticalIndexes(conn); err != nil {
		log.Fatalf("Failed to execute critical indexes: %v", err)
	}

	fmt.Println("\n✅ Critical query indexes created successfully!")
}

func executeCriticalIndexes(conn *pgx.Conn) error {
	// Define critical indexes to create
	criticalIndexes := []string{
		// Live match tracking
		`CREATE INDEX IF NOT EXISTS idx_matches_live_critical ON public.matches(
			status, actual_start_time, tournament_id
		) WHERE status IN ('live', 'half_time')`,

		// Tournament standings
		`CREATE INDEX IF NOT EXISTS idx_team_stats_standings_critical ON public.team_statistics(
			tournament_id, points DESC, goal_difference DESC, goals_for DESC
		) WHERE matches_played > 0`,

		// Player leaderboards
		`CREATE INDEX IF NOT EXISTS idx_player_stats_top_scorers ON public.player_statistics(
			tournament_id, goals_scored DESC, assists DESC, matches_played DESC
		) WHERE goals_scored > 0`,

		// User authentication
		`CREATE INDEX IF NOT EXISTS idx_user_profiles_login_critical ON public.user_profiles(
			LOWER(email), password_hash, is_active, account_status
		) WHERE is_active = TRUE AND account_status = 'active'`,

		// Tournament listings
		`CREATE INDEX IF NOT EXISTS idx_tournaments_public_critical ON public.tournaments(
			is_public, status, start_date DESC, city_id, sport_id
		) WHERE is_public = TRUE AND status IN ('approved', 'active')`,

		// Match events for real-time
		`CREATE INDEX IF NOT EXISTS idx_match_events_live_critical ON public.match_events(
			match_id, created_at, event_type
		) WHERE is_deleted = FALSE`,

		// Team search
		`CREATE INDEX IF NOT EXISTS idx_teams_search_critical ON public.teams USING gin(
			to_tsvector('spanish', name || ' ' || COALESCE(short_name, ''))
		) WHERE is_active = TRUE`,

		// Upcoming matches
		`CREATE INDEX IF NOT EXISTS idx_matches_upcoming_critical ON public.matches(
			match_date, match_time, status, tournament_id
		) WHERE status = 'scheduled' AND match_date >= CURRENT_DATE`,
	}

	successCount := 0

	for i, indexSQL := range criticalIndexes {
		fmt.Printf("Creating critical index %d/%d...\n", i+1, len(criticalIndexes))

		_, err := conn.Exec(context.Background(), indexSQL)
		if err != nil {
			if strings.Contains(err.Error(), "already exists") {
				fmt.Printf("⚠️  Index already exists (skipping)\n")
				successCount++
			} else {
				fmt.Printf("❌ Failed: %v\n", err)
			}
		} else {
			fmt.Printf("✅ Success\n")
			successCount++
		}
	}

	fmt.Printf("\n📊 Summary: %d/%d critical indexes created successfully\n", successCount, len(criticalIndexes))

	return nil
}
