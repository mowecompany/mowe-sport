-- =====================================================
-- MOWE SPORT PLATFORM - RLS POLICIES ROLLBACK
-- =====================================================
-- Migration: 006_implement_rls_policies (DOWN)
-- Description: Rollback RLS policies implementation
-- =====================================================

-- =====================================================
-- DROP ALL RLS POLICIES
-- =====================================================

-- User profiles policies
DROP POLICY IF EXISTS "users_can_view_own_profile" ON public.user_profiles;
DROP POLICY IF EXISTS "users_can_update_own_profile" ON public.user_profiles;
DROP POLICY IF EXISTS "super_admins_manage_all_profiles" ON public.user_profiles;
DROP POLICY IF EXISTS "city_admins_view_jurisdiction_profiles" ON public.user_profiles;
DROP POLICY IF EXISTS "city_admins_manage_registered_users" ON public.user_profiles;

-- User roles policies
DROP POLICY IF EXISTS "users_view_own_roles" ON public.user_roles_by_city_sport;
DROP POLICY IF EXISTS "super_admins_manage_all_roles" ON public.user_roles_by_city_sport;
DROP POLICY IF EXISTS "city_admins_view_jurisdiction_roles" ON public.user_roles_by_city_sport;
DROP POLICY IF EXISTS "city_admins_manage_jurisdiction_roles" ON public.user_roles_by_city_sport;

-- Cities and sports policies
DROP POLICY IF EXISTS "everyone_view_active_cities" ON public.cities;
DROP POLICY IF EXISTS "super_admins_manage_cities" ON public.cities;
DROP POLICY IF EXISTS "everyone_view_active_sports" ON public.sports;
DROP POLICY IF EXISTS "super_admins_manage_sports" ON public.sports;

-- Tournament policies
DROP POLICY IF EXISTS "public_view_public_tournaments" ON public.tournaments;
DROP POLICY IF EXISTS "super_admins_manage_all_tournaments" ON public.tournaments;
DROP POLICY IF EXISTS "city_admins_manage_jurisdiction_tournaments" ON public.tournaments;
DROP POLICY IF EXISTS "team_owners_view_participating_tournaments" ON public.tournaments;

-- Tournament teams policies
DROP POLICY IF EXISTS "public_view_approved_tournament_teams" ON public.tournament_teams;
DROP POLICY IF EXISTS "super_admins_manage_all_tournament_teams" ON public.tournament_teams;
DROP POLICY IF EXISTS "city_admins_manage_jurisdiction_tournament_teams" ON public.tournament_teams;
DROP POLICY IF EXISTS "team_owners_manage_registrations" ON public.tournament_teams;

-- Teams policies
DROP POLICY IF EXISTS "public_view_active_teams" ON public.teams;
DROP POLICY IF EXISTS "super_admins_manage_all_teams" ON public.teams;
DROP POLICY IF EXISTS "team_owners_manage_teams" ON public.teams;
DROP POLICY IF EXISTS "city_admins_view_jurisdiction_teams" ON public.teams;

-- Players policies
DROP POLICY IF EXISTS "public_view_active_players" ON public.players;
DROP POLICY IF EXISTS "super_admins_manage_all_players" ON public.players;
DROP POLICY IF EXISTS "players_manage_own_profile" ON public.players;
DROP POLICY IF EXISTS "team_owners_view_team_players" ON public.players;

-- Team players policies
DROP POLICY IF EXISTS "public_view_active_team_players" ON public.team_players;
DROP POLICY IF EXISTS "super_admins_manage_all_team_players" ON public.team_players;
DROP POLICY IF EXISTS "team_owners_manage_team_players" ON public.team_players;
DROP POLICY IF EXISTS "players_view_own_team_associations" ON public.team_players;

-- Matches policies
DROP POLICY IF EXISTS "public_view_completed_live_matches" ON public.matches;
DROP POLICY IF EXISTS "super_admins_manage_all_matches" ON public.matches;
DROP POLICY IF EXISTS "city_admins_manage_jurisdiction_matches" ON public.matches;
DROP POLICY IF EXISTS "team_owners_view_team_matches" ON public.matches;

-- Match events policies
DROP POLICY IF EXISTS "public_view_match_events" ON public.match_events;
DROP POLICY IF EXISTS "super_admins_manage_all_match_events" ON public.match_events;
DROP POLICY IF EXISTS "referees_manage_match_events" ON public.match_events;

-- Statistics policies
DROP POLICY IF EXISTS "public_view_player_statistics" ON public.player_statistics;
DROP POLICY IF EXISTS "super_admins_manage_player_statistics" ON public.player_statistics;
DROP POLICY IF EXISTS "system_update_player_statistics" ON public.player_statistics;
DROP POLICY IF EXISTS "system_update_existing_player_statistics" ON public.player_statistics;

DROP POLICY IF EXISTS "public_view_team_statistics" ON public.team_statistics;
DROP POLICY IF EXISTS "super_admins_manage_team_statistics" ON public.team_statistics;
DROP POLICY IF EXISTS "system_update_team_statistics" ON public.team_statistics;
DROP POLICY IF EXISTS "system_update_existing_team_statistics" ON public.team_statistics;

-- Audit logs policies
DROP POLICY IF EXISTS "super_admins_view_all_audit_logs" ON public.audit_logs;
DROP POLICY IF EXISTS "city_admins_view_jurisdiction_audit_logs" ON public.audit_logs;
DROP POLICY IF EXISTS "users_view_own_audit_logs" ON public.audit_logs;
DROP POLICY IF EXISTS "system_insert_audit_logs" ON public.audit_logs;

-- User view permissions policies
DROP POLICY IF EXISTS "super_admins_manage_view_permissions" ON public.user_view_permissions;
DROP POLICY IF EXISTS "users_view_relevant_permissions" ON public.user_view_permissions;

-- =====================================================
-- DISABLE RLS ON ALL TABLES
-- =====================================================

-- Core tables
ALTER TABLE public.user_profiles DISABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_roles_by_city_sport DISABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_view_permissions DISABLE ROW LEVEL SECURITY;
ALTER TABLE public.cities DISABLE ROW LEVEL SECURITY;
ALTER TABLE public.sports DISABLE ROW LEVEL SECURITY;

-- Tournament tables
ALTER TABLE public.tournaments DISABLE ROW LEVEL SECURITY;
ALTER TABLE public.tournament_teams DISABLE ROW LEVEL SECURITY;

-- Team and player tables
ALTER TABLE public.teams DISABLE ROW LEVEL SECURITY;
ALTER TABLE public.players DISABLE ROW LEVEL SECURITY;
ALTER TABLE public.team_players DISABLE ROW LEVEL SECURITY;

-- Match tables
ALTER TABLE public.matches DISABLE ROW LEVEL SECURITY;
ALTER TABLE public.match_events DISABLE ROW LEVEL SECURITY;

-- Statistics tables
ALTER TABLE public.player_statistics DISABLE ROW LEVEL SECURITY;
ALTER TABLE public.team_statistics DISABLE ROW LEVEL SECURITY;

-- Audit table
ALTER TABLE public.audit_logs DISABLE ROW LEVEL SECURITY;

-- =====================================================
-- DROP HELPER FUNCTIONS
-- =====================================================

DROP FUNCTION IF EXISTS public.current_user_id();
DROP FUNCTION IF EXISTS public.set_current_user_id(UUID);
DROP FUNCTION IF EXISTS public.user_has_role_in_city_sport(UUID, TEXT, UUID, UUID);
DROP FUNCTION IF EXISTS public.is_super_admin(UUID);
DROP FUNCTION IF EXISTS public.get_user_cities(UUID);
DROP FUNCTION IF EXISTS public.get_user_sports(UUID);

-- Remove audit log entry
DELETE FROM public.audit_logs 
WHERE action = 'SYSTEM_INIT' 
AND new_values->>'message' = 'Row Level Security policies implemented';