-- =====================================================
-- MOWE SPORT PLATFORM - CORE TABLES ROLLBACK
-- =====================================================
-- Migration: 001_create_core_tables (DOWN)
-- Description: Rollback core tables creation
-- =====================================================

-- Drop triggers first
DROP TRIGGER IF EXISTS update_user_view_permissions_updated_at ON public.user_view_permissions;
DROP TRIGGER IF EXISTS update_user_profiles_updated_at ON public.user_profiles;
DROP TRIGGER IF EXISTS update_sports_updated_at ON public.sports;
DROP TRIGGER IF EXISTS update_cities_updated_at ON public.cities;

-- Drop function
DROP FUNCTION IF EXISTS public.update_updated_at_column();

-- Drop tables in reverse dependency order
DROP TABLE IF EXISTS public.audit_logs;
DROP TABLE IF EXISTS public.user_view_permissions;
DROP TABLE IF EXISTS public.user_roles_by_city_sport;
DROP TABLE IF EXISTS public.user_profiles;
DROP TABLE IF EXISTS public.sports;
DROP TABLE IF EXISTS public.cities;