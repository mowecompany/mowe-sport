-- =====================================================
-- MOWE SPORT PLATFORM - ADVANCED PERFORMANCE INDEXES
-- =====================================================
-- Description: Advanced indexes for complex queries and analytics
-- Dependencies: 01_core_indexes.sql
-- Execution Order: After core indexes
-- =====================================================

-- =====================================================
-- ADVANCED COMPOSITE INDEXES FOR COMPLEX QUERIES
-- =====================================================

-- Multi-column indexes for tournament management queries
CREATE INDEX IF NOT EXISTS idx_tournaments_admin_management ON public.tournaments(
    admin_user_id, city_id, sport_id, status, start_date
) WHERE admin_user_id IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_tournaments_city_sport_dates ON public.tournaments(
    city_id, sport_id, start_date, end_date, status
) WHERE status IN ('approved', 'active', 'completed');

-- Team management and performance queries
CREATE INDEX IF NOT EXISTS idx_teams_owner_city_sport ON public.teams(
    owner_user_id, city_id, sport_id, is_active
) WHERE owner_user_id IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_teams_performance ON public.teams(
    city_id, sport_id, founded_date, is_verified
) WHERE is_active = TRUE;

-- Player management and statistics queries
CREATE INDEX IF NOT EXISTS idx_players_demographics ON public.players(
    nationality, gender, date_of_birth, is_active
) WHERE is_active = TRUE;

CREATE INDEX IF NOT EXISTS idx_players_availability ON public.players(
    preferred_position, is_available, is_active
) WHERE is_active = TRUE AND is_available = TRUE;

-- Team composition and player relationships
CREATE INDEX IF NOT EXISTS idx_team_players_active_composition ON public.team_players(
    team_id, position, is_captain, join_date
) WHERE is_active = TRUE AND leave_date IS NULL;

CREATE INDEX IF NOT EXISTS idx_team_players_history ON public.team_players(
    player_id, join_date, leave_date, is_active
);

-- Tournament participation and registration
CREATE INDEX IF NOT EXISTS idx_tournament_teams_participation ON public.tournament_teams(
    tournament_id, status, registration_date, category_id
);

CREATE INDEX IF NOT EXISTS idx_tournament_teams_approval ON public.tournament_teams(
    tournament_id, team_id, status, registration_fee_paid
) WHERE status = 'pending';

-- =====================================================
-- MATCH AND EVENT PERFORMANCE INDEXES
-- =====================================================

-- Live match tracking and real-time updates
CREATE INDEX IF NOT EXISTS idx_matches_live_tracking ON public.matches(
    tournament_id, status, actual_start_time, match_date
) WHERE status IN ('live', 'half_time');

CREATE INDEX IF NOT EXISTS idx_matches_upcoming_schedule ON public.matches(
    tournament_id, match_date, match_time, status
) WHERE status = 'scheduled';

-- Match events for real-time statistics
CREATE INDEX IF NOT EXISTS idx_match_events_realtime ON public.match_events(
    match_id, event_type, event_minute, created_at
) WHERE is_deleted = FALSE;

CREATE INDEX IF NOT EXISTS idx_match_events_player_performance ON public.match_events(
    player_id, team_id, event_type, match_id
) WHERE is_deleted = FALSE AND event_type IN ('goal', 'assist', 'yellow_card', 'red_card');

-- Match lineups and formations
CREATE INDEX IF NOT EXISTS idx_match_lineups_tactical ON public.match_lineups(
    match_id, team_id, formation_position, is_starter
) WHERE formation_position IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_match_lineups_substitutions ON public.match_lineups(
    match_id, team_id, substituted_at_minute
) WHERE substituted_at_minute IS NOT NULL;

-- =====================================================
-- STATISTICS AND ANALYTICS INDEXES
-- =====================================================

-- Player performance analytics
CREATE INDEX IF NOT EXISTS idx_player_stats_performance ON public.player_statistics(
    tournament_id, goals_scored, assists, matches_played
) WHERE matches_played > 0;

CREATE INDEX IF NOT EXISTS idx_player_stats_efficiency ON public.player_statistics(
    tournament_id, goals_per_match, minutes_per_goal
) WHERE goals_scored > 0;

-- Team performance and standings
CREATE INDEX IF NOT EXISTS idx_team_stats_standings ON public.team_statistics(
    tournament_id, points, goal_difference, goals_for
);

CREATE INDEX IF NOT EXISTS idx_team_stats_form ON public.team_statistics(
    tournament_id, recent_form, current_position
) WHERE current_position IS NOT NULL;

-- Tournament standings optimization
CREATE INDEX IF NOT EXISTS idx_tournament_standings_ranking ON public.tournament_standings(
    tournament_id, category_id, position, points, goal_difference
);

-- Player rankings for leaderboards
CREATE INDEX IF NOT EXISTS idx_player_rankings_leaderboard ON public.player_rankings(
    tournament_id, ranking_type, position, value
);

-- =====================================================
-- USER MANAGEMENT AND SECURITY INDEXES
-- =====================================================

-- User role management for multi-tenancy
CREATE INDEX IF NOT EXISTS idx_user_roles_management ON public.user_roles_by_city_sport(
    user_id, city_id, sport_id, is_active
) WHERE is_active = TRUE;

CREATE INDEX IF NOT EXISTS idx_user_roles_assignment ON public.user_roles_by_city_sport(
    assigned_by_user_id, role_name, created_at
) WHERE assigned_by_user_id IS NOT NULL;

-- User authentication and security
CREATE INDEX IF NOT EXISTS idx_user_profiles_security ON public.user_profiles(
    email, account_status, is_active, failed_login_attempts
) WHERE is_active = TRUE;

CREATE INDEX IF NOT EXISTS idx_user_profiles_locked_accounts ON public.user_profiles(
    locked_until, failed_login_attempts
) WHERE locked_until IS NOT NULL OR failed_login_attempts > 0;

-- Audit trail for security monitoring
CREATE INDEX IF NOT EXISTS idx_audit_logs_security ON public.audit_logs(
    action, created_at, ip_address
) WHERE action IN ('FAILED_LOGIN', 'SUCCESSFUL_LOGIN', 'ACCOUNT_LOCKED');

CREATE INDEX IF NOT EXISTS idx_audit_logs_user_activity ON public.audit_logs(
    user_id, action, created_at
) WHERE user_id IS NOT NULL;

-- =====================================================
-- REPORTING AND ANALYTICS INDEXES
-- =====================================================

-- Time-based reporting indexes
CREATE INDEX IF NOT EXISTS idx_matches_monthly_reports ON public.matches(
    match_date,
    sport_id,
    tournament_id,
    status
) WHERE status = 'completed';

CREATE INDEX IF NOT EXISTS idx_tournaments_seasonal ON public.tournaments(
    city_id,
    sport_id,
    start_date,
    status
) WHERE status IN ('completed', 'active');

-- User engagement analytics
CREATE INDEX IF NOT EXISTS idx_user_activity_analytics ON public.audit_logs(
    user_id,
    created_at,
    action
) WHERE user_id IS NOT NULL;

-- Financial reporting (if applicable)
CREATE INDEX IF NOT EXISTS idx_tournament_teams_financial ON public.tournament_teams(
    tournament_id,
    registration_fee_paid,
    payment_date
) WHERE registration_fee_paid = TRUE;

-- =====================================================
-- SEARCH AND DISCOVERY INDEXES
-- =====================================================

-- Advanced full-text search indexes
-- Note: Using simple concatenation to ensure immutability
CREATE INDEX IF NOT EXISTS idx_tournaments_search_advanced ON public.tournaments USING gin(
    to_tsvector('spanish', name || ' ' || COALESCE(description, ''))
) WHERE is_public = TRUE;

CREATE INDEX IF NOT EXISTS idx_teams_search_location ON public.teams USING gin(
    to_tsvector('spanish', name || ' ' || COALESCE(short_name, '') || ' ' || COALESCE(description, ''))
) WHERE is_active = TRUE;

-- Geographic and location-based indexes
CREATE INDEX IF NOT EXISTS idx_matches_venue_location ON public.matches(
    venue, venue_address
) WHERE venue IS NOT NULL;

-- =====================================================
-- PERFORMANCE MONITORING INDEXES
-- =====================================================

-- Database performance monitoring
CREATE INDEX IF NOT EXISTS idx_slow_queries_monitoring ON public.audit_logs(
    table_name,
    action,
    created_at
) WHERE table_name IS NOT NULL;

-- Real-time system health
CREATE INDEX IF NOT EXISTS idx_system_health ON public.matches(
    status,
    actual_start_time,
    created_at
) WHERE status IN ('live', 'half_time');

-- =====================================================
-- SPECIALIZED SPORT-SPECIFIC INDEXES
-- =====================================================

-- Football/Soccer specific indexes
CREATE INDEX IF NOT EXISTS idx_match_events_football ON public.match_events(
    match_id,
    event_type,
    event_minute,
    additional_time
) WHERE event_type IN ('goal', 'penalty_goal', 'own_goal', 'yellow_card', 'red_card', 'substitution_in', 'substitution_out');

-- Basketball specific indexes (if needed)
CREATE INDEX IF NOT EXISTS idx_match_events_basketball ON public.match_events(
    match_id,
    event_type,
    player_id,
    team_id
) WHERE event_type IN ('field_goal', 'three_pointer', 'free_throw', 'rebound', 'assist', 'steal', 'block');

-- =====================================================
-- MAINTENANCE AND OPTIMIZATION INDEXES
-- =====================================================

-- Cleanup and maintenance operations
-- Note: Removed date-based WHERE clauses to avoid immutability issues
-- These can be recreated with specific dates when needed for maintenance
CREATE INDEX IF NOT EXISTS idx_historical_data_cleanup ON public.historical_statistics(
    snapshot_date,
    entity_type
);

CREATE INDEX IF NOT EXISTS idx_audit_logs_cleanup ON public.audit_logs(
    created_at
);

-- Data archival indexes
CREATE INDEX IF NOT EXISTS idx_completed_tournaments_archive ON public.tournaments(
    status,
    end_date
) WHERE status = 'completed';

-- =====================================================
-- CONDITIONAL INDEXES FOR SPECIFIC SCENARIOS
-- =====================================================

-- High-traffic tournament indexes
CREATE INDEX IF NOT EXISTS idx_popular_tournaments ON public.tournaments(
    city_id,
    sport_id,
    start_date,
    status
) WHERE is_public = TRUE AND status IN ('active', 'approved');

-- Emergency and incident management
CREATE INDEX IF NOT EXISTS idx_match_incidents ON public.match_comments(
    match_id,
    comment_type,
    created_at
) WHERE comment_type IN ('incident_report', 'referee_report');

-- Player transfer tracking
CREATE INDEX IF NOT EXISTS idx_player_transfers_tracking ON public.player_transfers(
    player_id,
    transfer_date,
    status
) WHERE status IN ('pending', 'approved');

-- =====================================================
-- INDEX MAINTENANCE NOTES
-- =====================================================

-- Add comments for maintenance guidance
COMMENT ON INDEX idx_tournaments_search_advanced IS 'Advanced search index - rebuild weekly during low traffic';
COMMENT ON INDEX idx_teams_search_location IS 'Location-based search index - monitor for performance';
COMMENT ON INDEX idx_matches_live_tracking IS 'Critical for real-time features - high priority maintenance';
COMMENT ON INDEX idx_player_stats_performance IS 'Analytics index - rebuild after major tournaments';

-- Performance monitoring queries for DBAs:
-- SELECT schemaname, tablename, indexname, idx_tup_read, idx_tup_fetch 
-- FROM pg_stat_user_indexes 
-- WHERE schemaname = 'public' 
-- ORDER BY idx_tup_read DESC;

-- Index usage analysis:
-- SELECT schemaname, tablename, indexname, idx_scan, idx_tup_read, idx_tup_fetch
-- FROM pg_stat_user_indexes 
-- WHERE idx_scan = 0 AND schemaname = 'public';