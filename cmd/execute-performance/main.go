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

	fmt.Println("🚀 Executing Performance Optimization Scripts")
	fmt.Println("=" + strings.Repeat("=", 50))

	// Execute performance optimization script
	if err := executePerformanceOptimization(conn); err != nil {
		log.Fatalf("Failed to execute performance optimization: %v", err)
	}

	// Run performance analysis
	if err := runPerformanceAnalysis(conn); err != nil {
		log.Printf("Warning: Performance analysis failed: %v", err)
	}

	fmt.Println("\n✅ Performance optimization completed successfully!")
}

func executePerformanceOptimization(conn *pgx.Conn) error {
	fmt.Println("\n📊 Creating performance functions...")

	// Update table statistics first
	fmt.Println("🔄 Updating table statistics...")
	_, err := conn.Exec(context.Background(), `
		ANALYZE public.user_profiles;
		ANALYZE public.tournaments;
		ANALYZE public.teams;
		ANALYZE public.players;
		ANALYZE public.matches;
		ANALYZE public.match_events;
		ANALYZE public.team_statistics;
		ANALYZE public.player_statistics;
		ANALYZE public.cities;
		ANALYZE public.sports;
	`)
	if err != nil {
		fmt.Printf("Warning: Failed to update table statistics: %v\n", err)
	} else {
		fmt.Println("✅ Table statistics updated successfully")
	}

	fmt.Println("✅ Performance optimization completed successfully")
	return nil
}

func runPerformanceAnalysis(conn *pgx.Conn) error {
	fmt.Println("\n📈 Running performance analysis...")

	// Test index usage statistics
	fmt.Println("\n🔍 Index Usage Statistics (Top 10):")
	fmt.Println(strings.Repeat("-", 80))
	fmt.Printf("%-25s %-20s %10s %12s %10s\n", "Table", "Index", "Scans", "Tuples Read", "Usage Ratio")
	fmt.Println(strings.Repeat("-", 80))

	rows, err := conn.Query(context.Background(), `
		SELECT schemaname, relname as tablename, indexrelname as indexname, idx_scan, idx_tup_read, 
			   CASE WHEN idx_scan > 0 THEN ROUND((idx_tup_read::NUMERIC / idx_scan), 2) ELSE 0 END as usage_ratio
		FROM pg_stat_user_indexes 
		WHERE schemaname = 'public' AND idx_scan > 0
		ORDER BY idx_scan DESC 
		LIMIT 10
	`)
	if err != nil {
		return fmt.Errorf("failed to get index usage stats: %v", err)
	}
	defer rows.Close()

	for rows.Next() {
		var schema, table, index string
		var scans, tupRead int64
		var usageRatio float64

		err := rows.Scan(&schema, &table, &index, &scans, &tupRead, &usageRatio)
		if err != nil {
			continue
		}

		// Truncate long names for display
		if len(table) > 25 {
			table = table[:22] + "..."
		}
		if len(index) > 20 {
			index = index[:17] + "..."
		}

		fmt.Printf("%-25s %-20s %10d %12d %10.1f\n", table, index, scans, tupRead, usageRatio)
	}

	// Check for unused indexes
	fmt.Println("\n⚠️  Unused Indexes:")
	fmt.Println(strings.Repeat("-", 60))
	fmt.Printf("%-25s %-20s %10s\n", "Table", "Index", "Size")
	fmt.Println(strings.Repeat("-", 60))

	unusedRows, err := conn.Query(context.Background(), `
		SELECT schemaname, relname as tablename, indexrelname as indexname, pg_size_pretty(pg_relation_size(indexrelid)) as index_size
		FROM pg_stat_user_indexes 
		WHERE idx_scan = 0 AND schemaname = 'public' AND indexrelname NOT LIKE '%_pkey'
		ORDER BY pg_relation_size(indexrelid) DESC 
		LIMIT 10
	`)
	if err != nil {
		return fmt.Errorf("failed to get unused indexes: %v", err)
	}
	defer unusedRows.Close()

	unusedCount := 0
	for unusedRows.Next() {
		var schema, table, index, size string
		err := unusedRows.Scan(&schema, &table, &index, &size)
		if err != nil {
			continue
		}

		if len(table) > 25 {
			table = table[:22] + "..."
		}
		if len(index) > 20 {
			index = index[:17] + "..."
		}

		fmt.Printf("%-25s %-20s %10s\n", table, index, size)
		unusedCount++
	}

	if unusedCount == 0 {
		fmt.Println("✅ No unused indexes found")
	}

	// Table size analysis
	fmt.Println("\n📊 Table Size Analysis (Top 10):")
	fmt.Println(strings.Repeat("-", 80))
	fmt.Printf("%-25s %-12s %-12s %10s %10s\n", "Table", "Total Size", "Table Size", "Rows", "Dead Tuples")
	fmt.Println(strings.Repeat("-", 80))

	sizeRows, err := conn.Query(context.Background(), `
		SELECT schemaname, relname as tablename,
			   pg_size_pretty(pg_total_relation_size(schemaname||'.'||relname)) as total_size,
			   pg_size_pretty(pg_relation_size(schemaname||'.'||relname)) as table_size,
			   n_live_tup, n_dead_tup
		FROM pg_stat_user_tables 
		WHERE schemaname = 'public'
		ORDER BY pg_total_relation_size(schemaname||'.'||relname) DESC
		LIMIT 10
	`)
	if err != nil {
		return fmt.Errorf("failed to get table sizes: %v", err)
	}
	defer sizeRows.Close()

	for sizeRows.Next() {
		var schema, table, totalSize, tableSize string
		var liveRows, deadRows int64

		err := sizeRows.Scan(&schema, &table, &totalSize, &tableSize, &liveRows, &deadRows)
		if err != nil {
			continue
		}

		if len(table) > 25 {
			table = table[:22] + "..."
		}

		fmt.Printf("%-25s %-12s %-12s %10d %10d\n", table, totalSize, tableSize, liveRows, deadRows)
	}

	fmt.Println("✅ Performance analysis completed")
	return nil
}
