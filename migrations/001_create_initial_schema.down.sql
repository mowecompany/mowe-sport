-- =====================================================
-- MIGRATION 001 ROLLBACK: DROP INITIAL SCHEMA
-- =====================================================
-- Description: Rollback complete Mowe Sport schema
-- Author: Migration System
-- Date: 2025-01-23
-- WARNING: This will drop all tables and data!
-- =====================================================

-- Drop triggers first
DROP TRIGGER IF EXISTS update_cities_updated_at ON public.cities;
DROP TRIGGER IF EXISTS update_sports_updated_at ON public.sports;
DROP TRIGGER IF EXISTS update_user_profiles_updated_at ON public.user_profiles;
DROP TRIGGER IF EXISTS update_tournaments_updated_at ON public.tournaments;
DROP TRIGGER IF EXISTS update_teams_updated_at ON public.teams;
DROP TRIGGER IF EXISTS update_players_updated_at ON public.players;
DROP TRIGGER IF EXISTS update_matches_updated_at ON public.matches;

-- Drop trigger function
DROP FUNCTION IF EXISTS public.update_updated_at_column();

-- Drop tables in reverse dependency order
DROP TABLE IF EXISTS public.player_transfers CASCADE;
DROP TABLE IF EXISTS public.historical_statistics CASCADE;
DROP TABLE IF EXISTS public.player_rankings CASCADE;
DROP TABLE IF EXISTS public.tournament_standings CASCADE;
DROP TABLE IF EXISTS public.team_statistics CASCADE;
DROP TABLE IF EXISTS public.player_statistics CASCADE;
DROP TABLE IF EXISTS public.match_comments CASCADE;
DROP TABLE IF EXISTS public.match_lineups CASCADE;
DROP TABLE IF EXISTS public.match_events CASCADE;
DROP TABLE IF EXISTS public.matches CASCADE;
DROP TABLE IF EXISTS public.tournament_teams CASCADE;
DROP TABLE IF EXISTS public.team_players CASCADE;
DROP TABLE IF EXISTS public.players CASCADE;
DROP TABLE IF EXISTS public.teams CASCADE;
DROP TABLE IF EXISTS public.tournament_settings CASCADE;
DROP TABLE IF EXISTS public.tournament_categories CASCADE;
DROP TABLE IF EXISTS public.tournaments CASCADE;
DROP TABLE IF EXISTS public.audit_logs CASCADE;
DROP TABLE IF EXISTS public.user_view_permissions CASCADE;
DROP TABLE IF EXISTS public.user_roles_by_city_sport CASCADE;
DROP TABLE IF EXISTS public.user_profiles CASCADE;
DROP TABLE IF EXISTS public.sports CASCADE;
DROP TABLE IF EXISTS public.cities CASCADE;

-- Note: We don't drop the UUID extension as it might be used by other applications