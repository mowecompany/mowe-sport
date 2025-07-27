-- =====================================================
-- MOWE SPORT PLATFORM - COMPLETE DATABASE ROLLBACK
-- =====================================================
-- Migration: 003_complete_database_setup (DOWN)
-- Description: Rollback complete database setup
-- =====================================================

-- Drop indexes
DROP INDEX IF EXISTS idx_team_statistics_points;
DROP INDEX IF EXISTS idx_team_statistics_team;
DROP INDEX IF EXISTS idx_team_statistics_tournament;
DROP INDEX IF EXISTS idx_player_statistics_goals;
DROP INDEX IF EXISTS idx_player_statistics_tournament;
DROP INDEX IF EXISTS idx_player_statistics_player;
DROP INDEX IF EXISTS idx_match_events_active;
DROP INDEX IF EXISTS idx_match_events_type;
DROP INDEX IF EXISTS idx_match_events_team;
DROP INDEX IF EXISTS idx_match_events_player;
DROP INDEX IF EXISTS idx_match_events_match;
DROP INDEX IF EXISTS idx_matches_status;
DROP INDEX IF EXISTS idx_matches_date_time;
DROP INDEX IF EXISTS idx_matches_teams;
DROP INDEX IF EXISTS idx_matches_tournament;
DROP INDEX IF EXISTS idx_tournament_teams_status;
DROP INDEX IF EXISTS idx_tournament_teams_team;
DROP INDEX IF EXISTS idx_tournament_teams_tournament;
DROP INDEX IF EXISTS idx_team_players_active;
DROP INDEX IF EXISTS idx_team_players_player;
DROP INDEX IF EXISTS idx_team_players_team;
DROP INDEX IF EXISTS idx_players_active;
DROP INDEX IF EXISTS idx_players_birth_date;
DROP INDEX IF EXISTS idx_players_identification;
DROP INDEX IF EXISTS idx_players_name;
DROP INDEX IF EXISTS idx_teams_active;
DROP INDEX IF EXISTS idx_teams_owner;
DROP INDEX IF EXISTS idx_teams_city_sport;

-- Drop triggers
DROP TRIGGER IF EXISTS update_team_statistics_updated_at ON public.team_statistics;
DROP TRIGGER IF EXISTS update_player_statistics_updated_at ON public.player_statistics;
DROP TRIGGER IF EXISTS update_matches_updated_at ON public.matches;
DROP TRIGGER IF EXISTS update_tournament_teams_updated_at ON public.tournament_teams;
DROP TRIGGER IF EXISTS update_team_players_updated_at ON public.team_players;
DROP TRIGGER IF EXISTS update_players_updated_at ON public.players;
DROP TRIGGER IF EXISTS update_teams_updated_at ON public.teams;

-- Drop tables in reverse dependency order
DROP TABLE IF EXISTS public.team_statistics;
DROP TABLE IF EXISTS public.player_statistics;
DROP TABLE IF EXISTS public.match_events;
DROP TABLE IF EXISTS public.matches;
DROP TABLE IF EXISTS public.tournament_teams;
DROP TABLE IF EXISTS public.team_players;
DROP TABLE IF EXISTS public.players;
DROP TABLE IF EXISTS public.teams;