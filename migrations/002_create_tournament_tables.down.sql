-- =====================================================
-- MOWE SPORT PLATFORM - TOURNAMENT TABLES ROLLBACK
-- =====================================================
-- Migration: 002_create_tournament_tables (DOWN)
-- Description: Rollback tournament tables creation
-- =====================================================

-- Drop indexes
DROP INDEX IF EXISTS idx_tournament_categories_active;
DROP INDEX IF EXISTS idx_tournaments_active;
DROP INDEX IF EXISTS idx_tournaments_admin;
DROP INDEX IF EXISTS idx_tournaments_dates;
DROP INDEX IF EXISTS idx_tournaments_status;
DROP INDEX IF EXISTS idx_tournaments_city_sport;

-- Drop triggers
DROP TRIGGER IF EXISTS update_tournament_settings_updated_at ON public.tournament_settings;
DROP TRIGGER IF EXISTS update_tournament_groups_updated_at ON public.tournament_groups;
DROP TRIGGER IF EXISTS update_tournament_phases_updated_at ON public.tournament_phases;
DROP TRIGGER IF EXISTS update_tournament_categories_updated_at ON public.tournament_categories;
DROP TRIGGER IF EXISTS update_tournaments_updated_at ON public.tournaments;

-- Drop tables in reverse dependency order
DROP TABLE IF EXISTS public.tournament_settings;
DROP TABLE IF EXISTS public.tournament_groups;
DROP TABLE IF EXISTS public.tournament_phases;
DROP TABLE IF EXISTS public.tournament_categories;
DROP TABLE IF EXISTS public.tournaments;