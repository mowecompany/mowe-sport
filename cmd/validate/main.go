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

	// Validate initial data
	validateInitialData(db)
}

func validateInitialData(db *sql.DB) {
	fmt.Println("=== MOWE SPORT INITIAL DATA VALIDATION ===")
	fmt.Println("")

	// Check basic counts
	fmt.Println("--- Basic Data Counts ---")
	counts := map[string]string{
		"Cities":           "SELECT COUNT(*) FROM public.cities",
		"Sports":           "SELECT COUNT(*) FROM public.sports",
		"Users":            "SELECT COUNT(*) FROM public.user_profiles",
		"Teams":            "SELECT COUNT(*) FROM public.teams",
		"Players":          "SELECT COUNT(*) FROM public.players",
		"Tournaments":      "SELECT COUNT(*) FROM public.tournaments",
		"User Roles":       "SELECT COUNT(*) FROM public.user_roles_by_city_sport",
		"Team Players":     "SELECT COUNT(*) FROM public.team_players",
		"Tournament Teams": "SELECT COUNT(*) FROM public.tournament_teams",
		"Player Stats":     "SELECT COUNT(*) FROM public.player_statistics",
		"Team Stats":       "SELECT COUNT(*) FROM public.team_statistics",
	}

	for entity, query := range counts {
		var count int
		err := db.QueryRow(query).Scan(&count)
		if err != nil {
			fmt.Printf("❌ Error counting %s: %v\n", entity, err)
			continue
		}
		fmt.Printf("✅ %-15s: %d\n", entity, count)
	}
	fmt.Println("")

	// Check super admin user
	fmt.Println("--- Super Admin Validation ---")
	var email, firstName, lastName, role string
	var isActive bool
	err := db.QueryRow(`
		SELECT email, first_name, last_name, primary_role, is_active 
		FROM public.user_profiles 
		WHERE user_id = '00000000-0000-0000-0000-000000000001'
	`).Scan(&email, &firstName, &lastName, &role, &isActive)

	if err != nil {
		fmt.Printf("❌ Super admin user not found: %v\n", err)
	} else {
		fmt.Printf("✅ Super Admin: %s %s (%s) - %s - Active: %t\n", firstName, lastName, email, role, isActive)
	}
	fmt.Println("")

	// Check city admin users
	fmt.Println("--- City Admin Users ---")
	rows, err := db.Query(`
		SELECT email, first_name, last_name, primary_role, is_active 
		FROM public.user_profiles 
		WHERE primary_role = 'city_admin'
		ORDER BY email
	`)
	if err != nil {
		fmt.Printf("❌ Error querying city admin users: %v\n", err)
	} else {
		defer rows.Close()
		for rows.Next() {
			err := rows.Scan(&email, &firstName, &lastName, &role, &isActive)
			if err != nil {
				fmt.Printf("❌ Error scanning city admin: %v\n", err)
				continue
			}
			fmt.Printf("✅ City Admin: %s %s (%s) - Active: %t\n", firstName, lastName, email, isActive)
		}
	}
	fmt.Println("")

	// Check role assignments
	fmt.Println("--- Role Assignments ---")
	rows, err = db.Query(`
		SELECT 
			up.email,
			up.first_name || ' ' || up.last_name as full_name,
			COALESCE(c.name, 'All Cities') as city,
			COALESCE(s.name, 'All Sports') as sport,
			ur.role_name,
			ur.is_active
		FROM public.user_roles_by_city_sport ur
		JOIN public.user_profiles up ON ur.user_id = up.user_id
		LEFT JOIN public.cities c ON ur.city_id = c.city_id
		LEFT JOIN public.sports s ON ur.sport_id = s.sport_id
		ORDER BY up.email, ur.role_name
	`)
	if err != nil {
		fmt.Printf("❌ Error querying role assignments: %v\n", err)
	} else {
		defer rows.Close()
		for rows.Next() {
			var userEmail, fullName, city, sport, roleName string
			var roleActive bool
			err := rows.Scan(&userEmail, &fullName, &city, &sport, &roleName, &roleActive)
			if err != nil {
				fmt.Printf("❌ Error scanning role assignment: %v\n", err)
				continue
			}
			fmt.Printf("✅ %s (%s) - %s in %s/%s - Active: %t\n", fullName, userEmail, roleName, city, sport, roleActive)
		}
	}
	fmt.Println("")

	// Check teams
	fmt.Println("--- Teams Validation ---")
	rows, err = db.Query(`
		SELECT 
			t.name as team_name,
			c.name as city,
			s.name as sport,
			up.first_name || ' ' || up.last_name as owner,
			t.is_active
		FROM public.teams t
		JOIN public.cities c ON t.city_id = c.city_id
		JOIN public.sports s ON t.sport_id = s.sport_id
		JOIN public.user_profiles up ON t.owner_user_id = up.user_id
		ORDER BY t.name
	`)
	if err != nil {
		fmt.Printf("❌ Error querying teams: %v\n", err)
	} else {
		defer rows.Close()
		for rows.Next() {
			var teamName, city, sport, owner string
			var teamActive bool
			err := rows.Scan(&teamName, &city, &sport, &owner, &teamActive)
			if err != nil {
				fmt.Printf("❌ Error scanning team: %v\n", err)
				continue
			}
			fmt.Printf("✅ Team: %s (%s/%s) - Owner: %s - Active: %t\n", teamName, city, sport, owner, teamActive)
		}
	}
	fmt.Println("")

	// Check tournaments
	fmt.Println("--- Tournaments Validation ---")
	rows, err = db.Query(`
		SELECT 
			t.name as tournament_name,
			c.name as city,
			s.name as sport,
			up.first_name || ' ' || up.last_name as admin,
			t.status,
			t.max_teams
		FROM public.tournaments t
		JOIN public.cities c ON t.city_id = c.city_id
		JOIN public.sports s ON t.sport_id = s.sport_id
		JOIN public.user_profiles up ON t.admin_user_id = up.user_id
		ORDER BY t.name
	`)
	if err != nil {
		fmt.Printf("❌ Error querying tournaments: %v\n", err)
	} else {
		defer rows.Close()
		for rows.Next() {
			var tournamentName, city, sport, admin, status string
			var maxTeams int
			err := rows.Scan(&tournamentName, &city, &sport, &admin, &status, &maxTeams)
			if err != nil {
				fmt.Printf("❌ Error scanning tournament: %v\n", err)
				continue
			}
			fmt.Printf("✅ Tournament: %s (%s/%s) - Admin: %s - Status: %s - Max Teams: %d\n", tournamentName, city, sport, admin, status, maxTeams)
		}
	}
	fmt.Println("")

	// Check referential integrity
	fmt.Println("--- Referential Integrity Checks ---")
	integrityChecks := map[string]string{
		"Orphaned user roles": `
			SELECT COUNT(*) 
			FROM public.user_roles_by_city_sport ur
			LEFT JOIN public.user_profiles up ON ur.user_id = up.user_id
			WHERE up.user_id IS NULL
		`,
		"Orphaned teams (user)": `
			SELECT COUNT(*) 
			FROM public.teams t
			LEFT JOIN public.user_profiles up ON t.owner_user_id = up.user_id
			WHERE up.user_id IS NULL
		`,
		"Orphaned teams (city)": `
			SELECT COUNT(*) 
			FROM public.teams t
			LEFT JOIN public.cities c ON t.city_id = c.city_id
			WHERE c.city_id IS NULL
		`,
		"Orphaned tournaments": `
			SELECT COUNT(*) 
			FROM public.tournaments t
			LEFT JOIN public.user_profiles up ON t.admin_user_id = up.user_id
			LEFT JOIN public.cities c ON t.city_id = c.city_id
			LEFT JOIN public.sports s ON t.sport_id = s.sport_id
			WHERE up.user_id IS NULL OR c.city_id IS NULL OR s.sport_id IS NULL
		`,
	}

	for checkName, query := range integrityChecks {
		var count int
		err := db.QueryRow(query).Scan(&count)
		if err != nil {
			fmt.Printf("❌ Error checking %s: %v\n", checkName, err)
			continue
		}
		if count == 0 {
			fmt.Printf("✅ %-25s: %d (OK)\n", checkName, count)
		} else {
			fmt.Printf("❌ %-25s: %d (ISSUES FOUND)\n", checkName, count)
		}
	}
	fmt.Println("")

	// Check audit logs
	fmt.Println("--- Recent Audit Log Entries ---")
	rows, err = db.Query(`
		SELECT 
			al.action,
			al.table_name,
			up.email as user_email,
			al.new_values->>'message' as message,
			al.created_at
		FROM public.audit_logs al
		LEFT JOIN public.user_profiles up ON al.user_id = up.user_id
		WHERE al.action = 'SYSTEM_INIT'
		ORDER BY al.created_at DESC
		LIMIT 10
	`)
	if err != nil {
		fmt.Printf("❌ Error querying audit logs: %v\n", err)
	} else {
		defer rows.Close()
		for rows.Next() {
			var action, tableName, userEmail, message string
			var createdAt string
			err := rows.Scan(&action, &tableName, &userEmail, &message, &createdAt)
			if err != nil {
				fmt.Printf("❌ Error scanning audit log: %v\n", err)
				continue
			}
			fmt.Printf("✅ %s on %s by %s: %s (%s)\n", action, tableName, userEmail, message, createdAt)
		}
	}
	fmt.Println("")

	fmt.Println("=== VALIDATION COMPLETE ===")
}
