-- =====================================================
-- MOWE SPORT PLATFORM - CRITICAL QUERY INDEXES
-- =====================================================
-- Description: Specialized indexes for the most critical and frequent queries
-- Dependencies: All previous index files
-- Execution Order: After all other indexes
-- =====================================================

-- =====================================================
-- REAL-TIME MATCH TRACKING INDEXES
-- =====================================================

-- Critical index for live match updates (highest priority)
CREATE INDEX IF NOT EXISTS idx_matches_live_critical ON public.matches(
    status, actual_start_time, tournament_id
) WHERE status IN ('live', 'half_time');

-- Index for match events during live matches (real-time updates)
CREATE INDEX IF NOT EXISTS idx_match_events_live_critical ON public.match_events(
    match_id, created_at, event_type
) WHERE is_deleted = FALSE 
AND created_at >= NOW() - INTERVAL '3 hours';

-- Index for recent match events (for live feeds)
CREATE INDEX IF NOT EXISTS idx_match_events_recent_feed ON public.match_events(
    created_at DESC, match_id, event_type
) WHERE is_deleted = FALSE 
AND created_at >= NOW() - INTERVAL '24 hours';

-- =====================================================
-- TOURNAMENT STANDINGS CRITICAL INDEXES
-- =====================================================

-- Ultra-fast tournament standings lookup
CREATE INDEX IF NOT EXISTS idx_team_stats_standings_critical ON public.team_statistics(
    tournament_id, points DESC, goal_difference DESC, goals_for DESC
) WHERE matches_played > 0;

-- Index for position changes tracking
CREATE INDEX IF NOT EXISTS idx_team_stats_position_tracking ON public.team_statistics(
    tournament_id, current_position, previous_position, updated_at
) WHERE current_position IS NOT NULL;

-- Index for team form calculation
CREATE INDEX IF NOT EXISTS idx_team_stats_form ON public.team_statistics(
    tournament_id, recent_form, updated_at
) WHERE recent_form IS NOT NULL;

-- =====================================================
-- PLAYER STATISTICS LEADERBOARDS
-- =====================================================

-- Top scorers index (most frequently accessed)
CREATE INDEX IF NOT EXISTS idx_player_stats_top_scorers ON public.player_statistics(
    tournament_id, goals_scored DESC, assists DESC, matches_played DESC
) WHERE goals_scored > 0;

-- Top assists index
CREATE INDEX IF NOT EXISTS idx_player_stats_top_assists ON public.player_statistics(
    tournament_id, assists DESC, goals_scored DESC, matches_played DESC
) WHERE assists > 0;

-- Most disciplined players (least cards)
CREATE INDEX IF NOT EXISTS idx_player_stats_discipline ON public.player_statistics(
    tournament_id, (yellow_cards + red_cards * 2), matches_played DESC
) WHERE matches_played > 0;

-- Player efficiency metrics
CREATE INDEX IF NOT EXISTS idx_player_stats_efficiency ON public.player_statistics(
    tournament_id, 
    CASE WHEN minutes_played > 0 THEN goals_scored::decimal / (minutes_played / 90.0) ELSE 0 END DESC
) WHERE minutes_played > 0 AND goals_scored > 0;

-- =====================================================
-- USER AUTHENTICATION AND AUTHORIZATION
-- =====================================================

-- Critical login performance index
CREATE INDEX IF NOT EXISTS idx_user_profiles_login_critical ON public.user_profiles(
    LOWER(email), password_hash, is_active, account_status
) WHERE is_active = TRUE AND account_status = 'active';

-- Account security monitoring
CREATE INDEX IF NOT EXISTS idx_user_profiles_security_critical ON public.user_profiles(
    failed_login_attempts, locked_until, last_login_at
) WHERE failed_login_attempts > 0 OR locked_until IS NOT NULL;

-- Role-based access control (most critical for multi-tenancy)
CREATE INDEX IF NOT EXISTS idx_user_roles_rbac_critical ON public.user_roles_by_city_sport(
    user_id, city_id, sport_id, role_name, is_active
) WHERE is_active = TRUE;

-- =====================================================
-- TOURNAMENT MANAGEMENT CRITICAL QUERIES
-- =====================================================

-- Active tournaments by city/sport (admin dashboard)
CREATE INDEX IF NOT EXISTS idx_tournaments_admin_critical ON public.tournaments(
    city_id, sport_id, status, start_date DESC
) WHERE status IN ('active', 'approved', 'pending');

-- Tournament registration deadlines (time-sensitive)
CREATE INDEX IF NOT EXISTS idx_tournaments_registration_critical ON public.tournaments(
    registration_deadline, status, is_public
) WHERE registration_deadline >= CURRENT_DATE 
AND status IN ('approved', 'active');

-- Public tournament listings (most accessed by users)
CREATE INDEX IF NOT EXISTS idx_tournaments_public_critical ON public.tournaments(
    is_public, status, start_date DESC, city_id, sport_id
) WHERE is_public = TRUE AND status IN ('approved', 'active');

-- =====================================================
-- TEAM AND PLAYER MANAGEMENT
-- =====================================================

-- Team roster queries (frequently accessed)
CREATE INDEX IF NOT EXISTS idx_team_players_roster_critical ON public.team_players(
    team_id, is_active, position, is_captain
) WHERE is_active = TRUE AND leave_date IS NULL;

-- Player availability for transfers
CREATE INDEX IF NOT EXISTS idx_players_availability_critical ON public.players(
    is_active, is_available, preferred_position, date_of_birth
) WHERE is_active = TRUE AND is_available = TRUE;

-- Team ownership and management
CREATE INDEX IF NOT EXISTS idx_teams_ownership_critical ON public.teams(
    owner_user_id, city_id, sport_id, is_active
) WHERE is_active = TRUE;

-- =====================================================
-- MATCH SCHEDULING AND RESULTS
-- =====================================================

-- Upcoming matches (scheduler and notifications)
CREATE INDEX IF NOT EXISTS idx_matches_upcoming_critical ON public.matches(
    match_date, match_time, status, tournament_id
) WHERE status = 'scheduled' AND match_date >= CURRENT_DATE;

-- Recent completed matches (results display)
CREATE INDEX IF NOT EXISTS idx_matches_recent_results ON public.matches(
    status, match_date DESC, tournament_id
) WHERE status = 'completed' AND match_date >= CURRENT_DATE - INTERVAL '30 days';

-- Match officials assignment
CREATE INDEX IF NOT EXISTS idx_matches_officials_critical ON public.matches(
    referee_user_id, match_date, status
) WHERE referee_user_id IS NOT NULL AND status IN ('scheduled', 'live');

-- =====================================================
-- SEARCH AND DISCOVERY OPTIMIZATION
-- =====================================================

-- Team search with location context
CREATE INDEX IF NOT EXISTS idx_teams_search_critical ON public.teams USING gin(
    to_tsvector('spanish', name || ' ' || COALESCE(short_name, ''))
) WHERE is_active = TRUE;

-- Player search with team context
CREATE INDEX IF NOT EXISTS idx_players_search_critical ON public.players USING gin(
    to_tsvector('spanish', first_name || ' ' || last_name)
) WHERE is_active = TRUE;

-- Tournament search with date relevance
CREATE INDEX IF NOT EXISTS idx_tournaments_search_critical ON public.tournaments USING gin(
    to_tsvector('spanish', name)
) WHERE is_public = TRUE AND status IN ('approved', 'active');

-- =====================================================
-- REPORTING AND ANALYTICS OPTIMIZATION
-- =====================================================

-- Monthly match statistics (reports)
CREATE INDEX IF NOT EXISTS idx_matches_monthly_reports_critical ON public.matches(
    EXTRACT(YEAR FROM match_date),
    EXTRACT(MONTH FROM match_date),
    tournament_id,
    status
) WHERE status = 'completed';

-- Goal statistics for analytics
CREATE INDEX IF NOT EXISTS idx_match_events_goals_analytics ON public.match_events(
    event_type, match_id, player_id, team_id, event_minute
) WHERE event_type IN ('goal', 'penalty_goal', 'own_goal') AND is_deleted = FALSE;

-- Card statistics for discipline reports
CREATE INDEX IF NOT EXISTS idx_match_events_cards_analytics ON public.match_events(
    event_type, match_id, player_id, team_id, event_minute
) WHERE event_type IN ('yellow_card', 'red_card') AND is_deleted = FALSE;

-- =====================================================
-- AUDIT AND SECURITY MONITORING
-- =====================================================

-- Security event monitoring (critical for security)
CREATE INDEX IF NOT EXISTS idx_audit_logs_security_critical ON public.audit_logs(
    action, created_at DESC, user_id, ip_address
) WHERE action IN ('FAILED_LOGIN', 'ACCOUNT_LOCKED', 'SUSPICIOUS_ACTIVITY');

-- Recent user activity (session management)
CREATE INDEX IF NOT EXISTS idx_audit_logs_activity_critical ON public.audit_logs(
    user_id, created_at DESC, action
) WHERE user_id IS NOT NULL 
AND created_at >= NOW() - INTERVAL '24 hours';

-- =====================================================
-- NOTIFICATION SYSTEM OPTIMIZATION
-- =====================================================

-- Match notifications (goals, cards, etc.)
CREATE INDEX IF NOT EXISTS idx_match_events_notifications ON public.match_events(
    match_id, event_type, created_at DESC
) WHERE event_type IN ('goal', 'red_card', 'match_start', 'match_end') 
AND is_deleted = FALSE
AND created_at >= NOW() - INTERVAL '2 hours';

-- Tournament notifications (registrations, approvals)
CREATE INDEX IF NOT EXISTS idx_tournament_teams_notifications ON public.tournament_teams(
    tournament_id, status, registration_date DESC
) WHERE status IN ('pending', 'approved', 'rejected');

-- =====================================================
-- MOBILE APP OPTIMIZATION
-- =====================================================

-- Mobile app live scores
CREATE INDEX IF NOT EXISTS idx_matches_mobile_scores ON public.matches(
    status, match_date DESC, home_team_score, away_team_score
) WHERE status IN ('live', 'completed') 
AND match_date >= CURRENT_DATE - INTERVAL '7 days';

-- Mobile app player profiles
CREATE INDEX IF NOT EXISTS idx_players_mobile_profiles ON public.players(
    player_id, first_name, last_name, photo_url, is_active
) WHERE is_active = TRUE;

-- =====================================================
-- PERFORMANCE MONITORING INDEXES
-- =====================================================

-- Query performance monitoring
CREATE INDEX IF NOT EXISTS idx_audit_logs_performance ON public.audit_logs(
    table_name, action, created_at DESC
) WHERE table_name IS NOT NULL 
AND created_at >= NOW() - INTERVAL '1 hour';

-- System health monitoring
CREATE INDEX IF NOT EXISTS idx_matches_system_health ON public.matches(
    status, created_at, updated_at
) WHERE status IN ('live', 'half_time');

-- =====================================================
-- PARTIAL INDEXES FOR SPECIFIC CONDITIONS
-- =====================================================

-- Today's matches (highest traffic)
CREATE INDEX IF NOT EXISTS idx_matches_today ON public.matches(
    tournament_id, match_time, status
) WHERE match_date = CURRENT_DATE;

-- This week's matches
CREATE INDEX IF NOT EXISTS idx_matches_this_week ON public.matches(
    tournament_id, match_date, match_time, status
) WHERE match_date BETWEEN CURRENT_DATE AND CURRENT_DATE + INTERVAL '7 days';

-- Active user sessions
CREATE INDEX IF NOT EXISTS idx_user_profiles_active_sessions ON public.user_profiles(
    user_id, last_login_at DESC
) WHERE last_login_at >= NOW() - INTERVAL '30 minutes'
AND is_active = TRUE;

-- =====================================================
-- EXPRESSION INDEXES FOR CALCULATED FIELDS
-- =====================================================

-- Goals per match calculation
CREATE INDEX IF NOT EXISTS idx_player_stats_goals_per_match ON public.player_statistics(
    tournament_id,
    CASE WHEN matches_played > 0 THEN goals_scored::decimal / matches_played ELSE 0 END DESC
) WHERE matches_played > 0;

-- Points percentage for teams
CREATE INDEX IF NOT EXISTS idx_team_stats_points_percentage ON public.team_statistics(
    tournament_id,
    CASE WHEN matches_played > 0 THEN (points::decimal / (matches_played * 3)) * 100 ELSE 0 END DESC
) WHERE matches_played > 0;

-- Player age calculation
CREATE INDEX IF NOT EXISTS idx_players_age_calculation ON public.players(
    EXTRACT(YEAR FROM AGE(date_of_birth)),
    is_active
) WHERE is_active = TRUE;

-- =====================================================
-- COVERING INDEXES FOR READ-HEAVY QUERIES
-- =====================================================

-- Tournament standings covering index
CREATE INDEX IF NOT EXISTS idx_team_stats_standings_covering ON public.team_statistics(
    tournament_id, points DESC, goal_difference DESC
) INCLUDE (team_id, matches_played, wins, draws, losses, goals_for, goals_against);

-- Player leaderboard covering index
CREATE INDEX IF NOT EXISTS idx_player_stats_leaderboard_covering ON public.player_statistics(
    tournament_id, goals_scored DESC
) INCLUDE (player_id, team_id, assists, matches_played, minutes_played);

-- Match results covering index
CREATE INDEX IF NOT EXISTS idx_matches_results_covering ON public.matches(
    tournament_id, match_date DESC, status
) INCLUDE (match_id, home_team_id, away_team_id, home_team_score, away_team_score);

-- =====================================================
-- MAINTENANCE AND MONITORING
-- =====================================================

-- Add comments for critical indexes
COMMENT ON INDEX idx_matches_live_critical IS 'CRITICAL: Real-time match tracking - monitor closely';
COMMENT ON INDEX idx_team_stats_standings_critical IS 'CRITICAL: Tournament standings - highest priority';
COMMENT ON INDEX idx_user_profiles_login_critical IS 'CRITICAL: User authentication - security critical';
COMMENT ON INDEX idx_tournaments_public_critical IS 'CRITICAL: Public tournament listings - high traffic';
COMMENT ON INDEX idx_match_events_live_critical IS 'CRITICAL: Live match events - real-time updates';

-- Performance monitoring notes
COMMENT ON INDEX idx_player_stats_top_scorers IS 'HIGH TRAFFIC: Monitor for performance degradation';
COMMENT ON INDEX idx_matches_upcoming_critical IS 'TIME SENSITIVE: Used for scheduling and notifications';
COMMENT ON INDEX idx_audit_logs_security_critical IS 'SECURITY: Monitor for unusual patterns';

-- =====================================================
-- INDEX MAINTENANCE RECOMMENDATIONS
-- =====================================================

/*
MAINTENANCE SCHEDULE RECOMMENDATIONS:

DAILY:
- Monitor idx_matches_live_critical usage during peak hours
- Check idx_user_profiles_login_critical for performance
- Verify idx_match_events_live_critical during live matches

WEEKLY:
- REINDEX idx_team_stats_standings_critical after major tournaments
- Analyze idx_tournaments_public_critical usage patterns
- Review idx_player_stats_top_scorers performance

MONTHLY:
- Full analysis of all critical indexes
- Remove unused indexes identified by get_unused_indexes()
- Update statistics on all critical tables

PERFORMANCE ALERTS:
- Set up monitoring for queries taking >500ms on critical indexes
- Alert on index scan ratios below expected thresholds
- Monitor index bloat on high-traffic indexes

QUERY OPTIMIZATION:
- Use EXPLAIN ANALYZE on critical queries monthly
- Monitor pg_stat_statements for slow queries
- Review and optimize based on actual usage patterns
*/