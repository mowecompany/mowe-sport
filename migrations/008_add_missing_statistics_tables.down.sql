-- =====================================================
-- MOWE SPORT PLATFORM - ROLLBACK MISSING STATISTICS TABLES
-- =====================================================
-- Migration: 008_add_missing_statistics_tables (DOWN)
-- Description: Rollback missing tables for statistics system
-- =====================================================

-- =====================================================
-- DROP VIEWS
-- =====================================================

DROP VIEW IF EXISTS public.match_results;
DROP VIEW IF EXISTS public.current_tournament_standings;
DROP VIEW IF EXISTS public.current_top_scorers;

-- =====================================================
-- DROP INDEXES
-- =====================================================

DROP INDEX IF EXISTS idx_matches_status_date;
DROP INDEX IF EXISTS idx_matches_tournament_date;
DROP INDEX IF EXISTS idx_team_stats_points_desc;
DROP INDEX IF EXISTS idx_player_stats_assists_desc;
DROP INDEX IF EXISTS idx_player_stats_goals_desc;
DROP INDEX IF EXISTS idx_tournament_groups_phase;
DROP INDEX IF EXISTS idx_tournament_phases_tournament_order;
DROP INDEX IF EXISTS idx_tournament_categories_tournament;
DROP INDEX IF EXISTS idx_match_lineups_starters;
DROP INDEX IF EXISTS idx_match_lineups_player;
DROP INDEX IF EXISTS idx_match_lineups_match_team;
DROP INDEX IF EXISTS idx_historical_stats_date;
DROP INDEX IF EXISTS idx_historical_stats_entity;
DROP INDEX IF EXISTS idx_player_rankings_value;
DROP INDEX IF EXISTS idx_player_rankings_player;
DROP INDEX IF EXISTS idx_player_rankings_tournament_type;
DROP INDEX IF EXISTS idx_tournament_standings_points;
DROP INDEX IF EXISTS idx_tournament_standings_category_position;
DROP INDEX IF EXISTS idx_tournament_standings_tournament_position;

-- =====================================================
-- REMOVE ADDED COLUMNS FROM EXISTING TABLES
-- =====================================================

-- Remove columns from match_events
ALTER TABLE public.match_events 
DROP COLUMN IF EXISTS deleted_by_user_id,
DROP COLUMN IF EXISTS deleted_at,
DROP COLUMN IF EXISTS is_deleted;

-- Remove columns from matches
ALTER TABLE public.matches 
DROP COLUMN IF EXISTS away_score,
DROP COLUMN IF EXISTS home_score,
DROP COLUMN IF EXISTS away_team_id,
DROP COLUMN IF EXISTS home_team_id,
DROP COLUMN IF EXISTS group_id,
DROP COLUMN IF EXISTS phase_id,
DROP COLUMN IF EXISTS category_id;

-- Remove columns from team_statistics
ALTER TABLE public.team_statistics 
DROP COLUMN IF EXISTS last_calculated_at,
DROP COLUMN IF EXISTS points_per_match,
DROP COLUMN IF EXISTS position_change,
DROP COLUMN IF EXISTS previous_position,
DROP COLUMN IF EXISTS current_position,
DROP COLUMN IF EXISTS recent_form,
DROP COLUMN IF EXISTS red_cards,
DROP COLUMN IF EXISTS yellow_cards,
DROP COLUMN IF EXISTS failed_to_score,
DROP COLUMN IF EXISTS clean_sheets;

-- Remove columns from player_statistics
ALTER TABLE public.player_statistics 
DROP COLUMN IF EXISTS last_calculated_at,
DROP COLUMN IF EXISTS goals_per_match,
DROP COLUMN IF EXISTS clean_sheets,
DROP COLUMN IF EXISTS penalties_scored,
DROP COLUMN IF EXISTS penalties_taken,
DROP COLUMN IF EXISTS free_kicks_taken,
DROP COLUMN IF EXISTS corners_taken,
DROP COLUMN IF EXISTS shots_off_target,
DROP COLUMN IF EXISTS shots_on_target,
DROP COLUMN IF EXISTS own_goals,
DROP COLUMN IF EXISTS penalty_goals,
DROP COLUMN IF EXISTS matches_as_substitute,
DROP COLUMN IF EXISTS matches_started;

-- =====================================================
-- DROP NEW TABLES (in reverse dependency order)
-- =====================================================

DROP TABLE IF EXISTS public.tournament_standings;
DROP TABLE IF EXISTS public.player_rankings;
DROP TABLE IF EXISTS public.historical_statistics;
DROP TABLE IF EXISTS public.match_lineups;
DROP TABLE IF EXISTS public.tournament_groups;
DROP TABLE IF EXISTS public.tournament_phases;
DROP TABLE IF EXISTS public.tournament_categories;

-- =====================================================
-- LOG ROLLBACK COMPLETION
-- =====================================================

INSERT INTO public.audit_logs (
    user_id,
    action,
    table_name,
    record_id,
    new_values,
    ip_address,
    user_agent
) VALUES (
    '00000000-0000-0000-0000-000000000001',
    'SYSTEM_MIGRATION_ROLLBACK',
    'database_schema',
    NULL,
    '{\"migration\": \"008_add_missing_statistics_tables_rollback\", \"tables_dropped\": [\"tournament_standings\", \"player_rankings\", \"historical_statistics\", \"match_lineups\", \"tournament_categories\", \"tournament_phases\", \"tournament_groups\"], \"columns_removed\": [\"player_statistics_enhancements\", \"team_statistics_enhancements\", \"matches_enhancements\"], \"views_dropped\": [\"current_top_scorers\", \"current_tournament_standings\", \"match_results\"]}'::jsonb,
    '127.0.0.1'::inet,
    'Mowe Sport Database Migration System'
);"