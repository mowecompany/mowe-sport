-- =====================================================
-- MOWE SPORT PLATFORM - CORE PERFORMANCE INDEXES
-- =====================================================
-- Description: Essential indexes for optimal query performance
-- Dependencies: Complete schema from 01_schema/
-- Execution Order: After schema creation
-- =====================================================

-- =====================================================
-- CORE TABLES INDEXES
-- =====================================================

-- Cities indexes
CREATE INDEX IF NOT EXISTS idx_cities_country ON public.cities(country);
CREATE INDEX IF NOT EXISTS idx_cities_active ON public.cities(is_active) WHERE is_active = TRUE;
CREATE INDEX IF NOT EXISTS idx_cities_name_search ON public.cities USING gin(to_tsvector('spanish', name));

-- Sports indexes
CREATE INDEX IF NOT EXISTS idx_sports_active ON public.sports(is_active) WHERE is_active = TRUE;
CREATE INDEX IF NOT EXISTS idx_sports_name_search ON public.sports USING gin(to_tsvector('spanish', name));

-- User profiles indexes (additional to those in schema files)
CREATE INDEX IF NOT EXISTS idx_user_profiles_role ON public.user_profiles(primary_role);
CREATE INDEX IF NOT EXISTS idx_user_profiles_status ON public.user_profiles(account_status);
CREATE INDEX IF NOT EXISTS idx_user_profiles_active ON public.user_profiles(is_active) WHERE is_active = TRUE;
CREATE INDEX IF NOT EXISTS idx_user_profiles_email_lower ON public.user_profiles(LOWER(email));
CREATE INDEX IF NOT EXISTS idx_user_profiles_name ON public.user_profiles(first_name, last_name);
CREATE INDEX IF NOT EXISTS idx_user_profiles_identification ON public.user_profiles(identification) WHERE identification IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_user_profiles_login_attempts ON public.user_profiles(failed_login_attempts) WHERE failed_login_attempts > 0;
CREATE INDEX IF NOT EXISTS idx_user_profiles_locked ON public.user_profiles(locked_until) WHERE locked_until IS NOT NULL;

-- User roles by city sport indexes (additional)
CREATE INDEX IF NOT EXISTS idx_user_roles_city ON public.user_roles_by_city_sport(city_id) WHERE city_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_user_roles_sport ON public.user_roles_by_city_sport(sport_id) WHERE sport_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_user_roles_active ON public.user_roles_by_city_sport(user_id, is_active) WHERE is_active = TRUE;
CREATE INDEX IF NOT EXISTS idx_user_roles_assigned_by ON public.user_roles_by_city_sport(assigned_by_user_id) WHERE assigned_by_user_id IS NOT NULL;

-- User view permissions indexes
CREATE INDEX IF NOT EXISTS idx_user_view_permissions_user ON public.user_view_permissions(user_id) WHERE user_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_user_view_permissions_role ON public.user_view_permissions(role_name) WHERE role_name IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_user_view_permissions_view ON public.user_view_permissions(view_name);
CREATE INDEX IF NOT EXISTS idx_user_view_permissions_allowed ON public.user_view_permissions(view_name, is_allowed) WHERE is_allowed = TRUE;

-- Audit logs indexes
CREATE INDEX IF NOT EXISTS idx_audit_logs_user ON public.audit_logs(user_id) WHERE user_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_audit_logs_action ON public.audit_logs(action);
CREATE INDEX IF NOT EXISTS idx_audit_logs_table ON public.audit_logs(table_name) WHERE table_name IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_audit_logs_record ON public.audit_logs(table_name, record_id) WHERE table_name IS NOT NULL AND record_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_audit_logs_created_at ON public.audit_logs(created_at);
CREATE INDEX IF NOT EXISTS idx_audit_logs_ip ON public.audit_logs(ip_address) WHERE ip_address IS NOT NULL;

-- =====================================================
-- TOURNAMENT TABLES INDEXES
-- =====================================================

-- Tournament categories indexes (additional)
CREATE INDEX IF NOT EXISTS idx_tournament_categories_tournament ON public.tournament_categories(tournament_id);
CREATE INDEX IF NOT EXISTS idx_tournament_categories_age ON public.tournament_categories(min_age, max_age) WHERE min_age IS NOT NULL OR max_age IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_tournament_categories_gender ON public.tournament_categories(gender) WHERE gender IS NOT NULL;

-- Tournament phases indexes
CREATE INDEX IF NOT EXISTS idx_tournament_phases_tournament ON public.tournament_phases(tournament_id);
CREATE INDEX IF NOT EXISTS idx_tournament_phases_category ON public.tournament_phases(category_id) WHERE category_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_tournament_phases_order ON public.tournament_phases(tournament_id, phase_order);
CREATE INDEX IF NOT EXISTS idx_tournament_phases_dates ON public.tournament_phases(start_date, end_date) WHERE start_date IS NOT NULL;

-- Tournament groups indexes
CREATE INDEX IF NOT EXISTS idx_tournament_groups_phase ON public.tournament_groups(phase_id);
CREATE INDEX IF NOT EXISTS idx_tournament_groups_name ON public.tournament_groups(phase_id, name);

-- Tournament settings indexes
CREATE INDEX IF NOT EXISTS idx_tournament_settings_tournament ON public.tournament_settings(tournament_id);
CREATE INDEX IF NOT EXISTS idx_tournament_settings_key ON public.tournament_settings(setting_key);

-- =====================================================
-- TEAM AND PLAYER INDEXES
-- =====================================================

-- Teams indexes (additional)
CREATE INDEX IF NOT EXISTS idx_teams_name_search ON public.teams USING gin(to_tsvector('spanish', name));
CREATE INDEX IF NOT EXISTS idx_teams_short_name ON public.teams(short_name) WHERE short_name IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_teams_verified ON public.teams(city_id, sport_id, is_verified) WHERE is_verified = TRUE;
CREATE INDEX IF NOT EXISTS idx_teams_founded ON public.teams(founded_date) WHERE founded_date IS NOT NULL;

-- Players indexes (additional)
CREATE INDEX IF NOT EXISTS idx_players_user_profile ON public.players(user_profile_id) WHERE user_profile_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_players_gender ON public.players(gender) WHERE gender IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_players_nationality ON public.players(nationality);
CREATE INDEX IF NOT EXISTS idx_players_age ON public.players(date_of_birth);
CREATE INDEX IF NOT EXISTS idx_players_position ON public.players(preferred_position) WHERE preferred_position IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_players_available ON public.players(is_active, is_available) WHERE is_active = TRUE AND is_available = TRUE;
CREATE INDEX IF NOT EXISTS idx_players_name_search ON public.players USING gin(to_tsvector('spanish', first_name || ' ' || last_name));

-- Team players indexes (additional)
CREATE INDEX IF NOT EXISTS idx_team_players_dates ON public.team_players(join_date, leave_date);
CREATE INDEX IF NOT EXISTS idx_team_players_captain ON public.team_players(team_id, is_captain) WHERE is_captain = TRUE;
CREATE INDEX IF NOT EXISTS idx_team_players_position ON public.team_players(team_id, position) WHERE position IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_team_players_contract ON public.team_players(contract_type) WHERE contract_type IS NOT NULL;

-- Tournament teams indexes (additional)
CREATE INDEX IF NOT EXISTS idx_tournament_teams_category ON public.tournament_teams(category_id) WHERE category_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_tournament_teams_group ON public.tournament_teams(group_id) WHERE group_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_tournament_teams_registration_date ON public.tournament_teams(registration_date);
CREATE INDEX IF NOT EXISTS idx_tournament_teams_payment ON public.tournament_teams(registration_fee_paid, payment_date);
CREATE INDEX IF NOT EXISTS idx_tournament_teams_seed ON public.tournament_teams(tournament_id, seed_number) WHERE seed_number IS NOT NULL;

-- Tournament team players indexes (additional)
CREATE INDEX IF NOT EXISTS idx_tournament_team_players_position ON public.tournament_team_players(tournament_team_id, position) WHERE position IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_tournament_team_players_captain ON public.tournament_team_players(tournament_team_id, is_captain) WHERE is_captain = TRUE;
CREATE INDEX IF NOT EXISTS idx_tournament_team_players_eligible ON public.tournament_team_players(tournament_team_id, is_eligible) WHERE is_eligible = TRUE;

-- Player transfers indexes (additional)
CREATE INDEX IF NOT EXISTS idx_player_transfers_date ON public.player_transfers(transfer_date);
CREATE INDEX IF NOT EXISTS idx_player_transfers_type ON public.player_transfers(transfer_type);
CREATE INDEX IF NOT EXISTS idx_player_transfers_status ON public.player_transfers(status);
CREATE INDEX IF NOT EXISTS idx_player_transfers_approved_by ON public.player_transfers(approved_by_user_id) WHERE approved_by_user_id IS NOT NULL;

-- =====================================================
-- MATCH TABLES INDEXES
-- =====================================================

-- Matches indexes (additional)
CREATE INDEX IF NOT EXISTS idx_matches_phase ON public.matches(phase_id) WHERE phase_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_matches_group ON public.matches(group_id) WHERE group_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_matches_venue ON public.matches(venue) WHERE venue IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_matches_officials ON public.matches(referee_user_id, assistant_referee_1_id) WHERE referee_user_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_matches_scores ON public.matches(home_team_score, away_team_score);
CREATE INDEX IF NOT EXISTS idx_matches_attendance ON public.matches(attendance) WHERE attendance IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_matches_actual_times ON public.matches(actual_start_time, actual_end_time) WHERE actual_start_time IS NOT NULL;

-- Match events indexes (additional)
CREATE INDEX IF NOT EXISTS idx_match_events_related_player ON public.match_events(related_player_id) WHERE related_player_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_match_events_created_by ON public.match_events(created_by_user_id) WHERE created_by_user_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_match_events_deleted ON public.match_events(is_deleted, deleted_at) WHERE is_deleted = TRUE;
CREATE INDEX IF NOT EXISTS idx_match_events_goals ON public.match_events(match_id, event_type) WHERE event_type IN ('goal', 'penalty_goal', 'own_goal');
CREATE INDEX IF NOT EXISTS idx_match_events_cards ON public.match_events(match_id, event_type) WHERE event_type IN ('yellow_card', 'red_card');

-- Match lineups indexes (additional)
CREATE INDEX IF NOT EXISTS idx_match_lineups_formation ON public.match_lineups(match_id, team_id, formation_position) WHERE formation_position IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_match_lineups_substitutions ON public.match_lineups(substituted_at_minute, substituted_by_player_id) WHERE substituted_at_minute IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_match_lineups_captains ON public.match_lineups(match_id, is_captain) WHERE is_captain = TRUE;

-- Match officials indexes (additional)
CREATE INDEX IF NOT EXISTS idx_match_officials_role ON public.match_officials(official_role);
CREATE INDEX IF NOT EXISTS idx_match_officials_fee ON public.match_officials(fee) WHERE fee IS NOT NULL;

-- Match comments indexes (additional)
CREATE INDEX IF NOT EXISTS idx_match_comments_type ON public.match_comments(comment_type);
CREATE INDEX IF NOT EXISTS idx_match_comments_created_at ON public.match_comments(created_at);

-- Match media indexes (additional)
CREATE INDEX IF NOT EXISTS idx_match_media_created_at ON public.match_media(created_at);
CREATE INDEX IF NOT EXISTS idx_match_media_file_size ON public.match_media(file_size_bytes) WHERE file_size_bytes IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_match_media_duration ON public.match_media(duration_seconds) WHERE duration_seconds IS NOT NULL;

-- =====================================================
-- COMPOSITE INDEXES FOR COMPLEX QUERIES
-- =====================================================

-- Multi-tenant queries
CREATE INDEX IF NOT EXISTS idx_tournaments_city_sport_status_dates ON public.tournaments(city_id, sport_id, status, start_date, end_date);
CREATE INDEX IF NOT EXISTS idx_teams_city_sport_active ON public.teams(city_id, sport_id, is_active);
CREATE INDEX IF NOT EXISTS idx_matches_tournament_teams_date ON public.matches(tournament_id, home_team_id, away_team_id, match_date);

-- Statistics calculation queries
CREATE INDEX IF NOT EXISTS idx_match_events_stats ON public.match_events(player_id, team_id, event_type, match_id) WHERE is_deleted = FALSE;
CREATE INDEX IF NOT EXISTS idx_matches_completed_tournament ON public.matches(tournament_id, status, match_date) WHERE status = 'completed';

-- User role and permission queries
CREATE INDEX IF NOT EXISTS idx_user_roles_permissions ON public.user_roles_by_city_sport(user_id, city_id, sport_id, role_name, is_active);

-- Tournament registration queries
CREATE INDEX IF NOT EXISTS idx_tournament_teams_registration ON public.tournament_teams(tournament_id, status, registration_date);

-- Player eligibility queries
CREATE INDEX IF NOT EXISTS idx_players_eligibility ON public.players(date_of_birth, gender, nationality, is_active, is_available);

-- =====================================================
-- FULL-TEXT SEARCH INDEXES
-- =====================================================

-- Full-text search for teams
CREATE INDEX IF NOT EXISTS idx_teams_fulltext ON public.teams USING gin(
    to_tsvector('spanish', COALESCE(name, '') || ' ' || COALESCE(short_name, '') || ' ' || COALESCE(description, ''))
);

-- Full-text search for players
CREATE INDEX IF NOT EXISTS idx_players_fulltext ON public.players USING gin(
    to_tsvector('spanish', first_name || ' ' || last_name || ' ' || COALESCE(identification, ''))
);

-- Full-text search for tournaments
CREATE INDEX IF NOT EXISTS idx_tournaments_fulltext ON public.tournaments USING gin(
    to_tsvector('spanish', name || ' ' || COALESCE(description, ''))
);

-- =====================================================
-- PARTIAL INDEXES FOR SPECIFIC CONDITIONS
-- =====================================================

-- Active tournaments only
CREATE INDEX IF NOT EXISTS idx_tournaments_active_public ON public.tournaments(city_id, sport_id, start_date)
    WHERE status IN ('approved', 'active') AND is_public = TRUE;

-- Upcoming matches
CREATE INDEX IF NOT EXISTS idx_matches_upcoming ON public.matches(tournament_id, match_date, match_time)
    WHERE status = 'scheduled' AND match_date >= CURRENT_DATE;

-- Live matches
CREATE INDEX IF NOT EXISTS idx_matches_live_realtime ON public.matches(tournament_id, actual_start_time)
    WHERE status IN ('live', 'half_time');

-- Recent match events (for real-time updates)
CREATE INDEX IF NOT EXISTS idx_match_events_recent ON public.match_events(match_id, created_at)
    WHERE created_at >= NOW() - INTERVAL '2 hours' AND is_deleted = FALSE;

-- Active team players
CREATE INDEX IF NOT EXISTS idx_team_players_current ON public.team_players(team_id, player_id, position)
    WHERE is_active = TRUE AND leave_date IS NULL;

-- Pending approvals
CREATE INDEX IF NOT EXISTS idx_tournament_teams_pending ON public.tournament_teams(tournament_id, registration_date)
    WHERE status = 'pending';

-- =====================================================
-- EXPRESSION INDEXES FOR CALCULATED FIELDS
-- =====================================================

-- Age calculation for players
CREATE INDEX IF NOT EXISTS idx_players_current_age ON public.players(
    EXTRACT(YEAR FROM AGE(date_of_birth))
) WHERE is_active = TRUE;

-- Match duration calculation (removed - will be handled in schema files)
-- Note: Generated columns should be defined in schema files, not index files

-- Tournament duration
CREATE INDEX IF NOT EXISTS idx_tournaments_duration ON public.tournaments(
    (end_date - start_date)
) WHERE status IN ('approved', 'active', 'completed');

-- =====================================================
-- INDEXES FOR REPORTING AND ANALYTICS
-- =====================================================

-- Monthly statistics
CREATE INDEX IF NOT EXISTS idx_matches_monthly ON public.matches(
    EXTRACT(YEAR FROM match_date),
    EXTRACT(MONTH FROM match_date),
    tournament_id
) WHERE status = 'completed';

-- User activity tracking
CREATE INDEX IF NOT EXISTS idx_audit_logs_monthly ON public.audit_logs(
    EXTRACT(YEAR FROM created_at),
    EXTRACT(MONTH FROM created_at),
    action
);

-- Team performance over time
CREATE INDEX IF NOT EXISTS idx_team_statistics_performance ON public.team_statistics(
    team_id,
    tournament_id,
    points DESC,
    goal_difference DESC
);

-- Player performance rankings
CREATE INDEX IF NOT EXISTS idx_player_statistics_rankings ON public.player_statistics(
    tournament_id,
    goals_scored DESC,
    assists DESC,
    matches_played DESC
);

-- =====================================================
-- MAINTENANCE NOTES
-- =====================================================

-- Add comments for maintenance
COMMENT ON INDEX idx_teams_fulltext IS 'Full-text search index for teams - rebuild monthly';
COMMENT ON INDEX idx_players_fulltext IS 'Full-text search index for players - rebuild monthly';
COMMENT ON INDEX idx_tournaments_fulltext IS 'Full-text search index for tournaments - rebuild monthly';

-- Note: Consider running REINDEX periodically on full-text search indexes
-- Note: Monitor index usage with pg_stat_user_indexes
-- Note: Consider dropping unused indexes based on pg_stat_user_indexes data