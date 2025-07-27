-- =====================================================
-- MOWE SPORT PLATFORM - ROW LEVEL SECURITY IMPLEMENTATION
-- =====================================================
-- Migration: 006_implement_rls_policies
-- Description: Implement comprehensive RLS policies for multi-tenant security
-- =====================================================

-- =====================================================
-- CURRENT USER FUNCTION FOR RLS
-- =====================================================
-- This function will be used by RLS policies to get the current authenticated user
-- It should be set by the application layer when processing requests

CREATE OR REPLACE FUNCTION public.current_user_id() RETURNS UUID AS $$
BEGIN
    -- Get the user ID from the current session variable
    -- This will be set by the application layer during JWT validation
    RETURN COALESCE(
        current_setting('app.current_user_id', true)::UUID,
        '00000000-0000-0000-0000-000000000000'::UUID
    );
EXCEPTION
    WHEN OTHERS THEN
        RETURN '00000000-0000-0000-0000-000000000000'::UUID;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to set current user (called by application)
CREATE OR REPLACE FUNCTION public.set_current_user_id(user_id UUID) RETURNS VOID AS $$
BEGIN
    PERFORM set_config('app.current_user_id', user_id::TEXT, true);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- =====================================================
-- HELPER FUNCTIONS FOR RLS
-- =====================================================

-- Function to check if user has role in city/sport
CREATE OR REPLACE FUNCTION public.user_has_role_in_city_sport(
    p_user_id UUID,
    p_role_name TEXT,
    p_city_id UUID DEFAULT NULL,
    p_sport_id UUID DEFAULT NULL
) RETURNS BOOLEAN AS $$
BEGIN
    RETURN EXISTS (
        SELECT 1 FROM public.user_roles_by_city_sport ur
        WHERE ur.user_id = p_user_id
        AND ur.role_name = p_role_name
        AND ur.is_active = TRUE
        AND (p_city_id IS NULL OR ur.city_id = p_city_id OR ur.city_id IS NULL)
        AND (p_sport_id IS NULL OR ur.sport_id = p_sport_id OR ur.sport_id IS NULL)
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to check if user is super admin
CREATE OR REPLACE FUNCTION public.is_super_admin(p_user_id UUID) RETURNS BOOLEAN AS $$
BEGIN
    RETURN EXISTS (
        SELECT 1 FROM public.user_profiles
        WHERE user_id = p_user_id
        AND primary_role = 'super_admin'
        AND is_active = TRUE
        AND account_status = 'active'
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to get user's cities
CREATE OR REPLACE FUNCTION public.get_user_cities(p_user_id UUID) RETURNS UUID[] AS $$
DECLARE
    city_ids UUID[];
BEGIN
    -- Super admins have access to all cities
    IF public.is_super_admin(p_user_id) THEN
        SELECT ARRAY_AGG(city_id) INTO city_ids FROM public.cities WHERE is_active = TRUE;
        RETURN city_ids;
    END IF;
    
    -- Get cities where user has roles
    SELECT ARRAY_AGG(DISTINCT ur.city_id) INTO city_ids
    FROM public.user_roles_by_city_sport ur
    WHERE ur.user_id = p_user_id
    AND ur.is_active = TRUE
    AND ur.city_id IS NOT NULL;
    
    RETURN COALESCE(city_ids, ARRAY[]::UUID[]);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to get user's sports
CREATE OR REPLACE FUNCTION public.get_user_sports(p_user_id UUID) RETURNS UUID[] AS $$
DECLARE
    sport_ids UUID[];
BEGIN
    -- Super admins have access to all sports
    IF public.is_super_admin(p_user_id) THEN
        SELECT ARRAY_AGG(sport_id) INTO sport_ids FROM public.sports WHERE is_active = TRUE;
        RETURN sport_ids;
    END IF;
    
    -- Get sports where user has roles
    SELECT ARRAY_AGG(DISTINCT ur.sport_id) INTO sport_ids
    FROM public.user_roles_by_city_sport ur
    WHERE ur.user_id = p_user_id
    AND ur.is_active = TRUE
    AND ur.sport_id IS NOT NULL;
    
    RETURN COALESCE(sport_ids, ARRAY[]::UUID[]);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- =====================================================
-- ENABLE RLS ON ALL TABLES
-- =====================================================

-- Core tables
ALTER TABLE public.user_profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_roles_by_city_sport ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_view_permissions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.cities ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.sports ENABLE ROW LEVEL SECURITY;

-- Tournament tables
ALTER TABLE public.tournaments ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.tournament_teams ENABLE ROW LEVEL SECURITY;

-- Team and player tables
ALTER TABLE public.teams ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.players ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.team_players ENABLE ROW LEVEL SECURITY;

-- Match tables
ALTER TABLE public.matches ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.match_events ENABLE ROW LEVEL SECURITY;

-- Statistics tables
ALTER TABLE public.player_statistics ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.team_statistics ENABLE ROW LEVEL SECURITY;

-- Audit table
ALTER TABLE public.audit_logs ENABLE ROW LEVEL SECURITY;

-- =====================================================
-- USER PROFILES POLICIES
-- =====================================================

-- Policy: Users can view their own profile
CREATE POLICY "users_can_view_own_profile" ON public.user_profiles
    FOR SELECT TO authenticated
    USING (user_id = public.current_user_id());

-- Policy: Users can update their own profile (limited fields)
CREATE POLICY "users_can_update_own_profile" ON public.user_profiles
    FOR UPDATE TO authenticated
    USING (user_id = public.current_user_id())
    WITH CHECK (
        user_id = public.current_user_id() AND
        -- Prevent users from changing critical fields
        primary_role = (SELECT primary_role FROM public.user_profiles WHERE user_id = public.current_user_id()) AND
        account_status = (SELECT account_status FROM public.user_profiles WHERE user_id = public.current_user_id()) AND
        is_active = (SELECT is_active FROM public.user_profiles WHERE user_id = public.current_user_id())
    );

-- Policy: Super admins can manage all profiles
CREATE POLICY "super_admins_manage_all_profiles" ON public.user_profiles
    FOR ALL TO authenticated
    USING (public.is_super_admin(public.current_user_id()));

-- Policy: City admins can view profiles in their jurisdiction
CREATE POLICY "city_admins_view_jurisdiction_profiles" ON public.user_profiles
    FOR SELECT TO authenticated
    USING (
        public.is_super_admin(public.current_user_id()) OR
        user_id = public.current_user_id() OR
        EXISTS (
            SELECT 1 FROM public.user_profiles up
            JOIN public.user_roles_by_city_sport ur ON up.user_id = ur.user_id
            WHERE up.user_id = public.current_user_id()
            AND up.primary_role = 'city_admin'
            AND up.is_active = TRUE
            AND ur.role_name = 'city_admin'
            AND ur.is_active = TRUE
            AND EXISTS (
                SELECT 1 FROM public.user_roles_by_city_sport target_ur
                WHERE target_ur.user_id = public.user_profiles.user_id
                AND target_ur.city_id = ur.city_id
                AND target_ur.is_active = TRUE
            )
        )
    );

-- Policy: City admins can manage users they can register
CREATE POLICY "city_admins_manage_registered_users" ON public.user_profiles
    FOR INSERT TO authenticated
    WITH CHECK (
        public.is_super_admin(public.current_user_id()) OR
        (
            primary_role IN ('owner', 'coach', 'referee', 'player', 'client') AND
            EXISTS (
                SELECT 1 FROM public.user_profiles admin_profile
                JOIN public.user_roles_by_city_sport admin_role ON admin_profile.user_id = admin_role.user_id
                WHERE admin_profile.user_id = public.current_user_id()
                AND admin_profile.primary_role = 'city_admin'
                AND admin_profile.is_active = TRUE
                AND admin_role.role_name = 'city_admin'
                AND admin_role.is_active = TRUE
            )
        )
    );

-- =====================================================
-- USER ROLES BY CITY SPORT POLICIES
-- =====================================================

-- Policy: Users can view their own roles
CREATE POLICY "users_view_own_roles" ON public.user_roles_by_city_sport
    FOR SELECT TO authenticated
    USING (
        user_id = public.current_user_id() OR
        public.is_super_admin(public.current_user_id())
    );

-- Policy: Super admins can manage all roles
CREATE POLICY "super_admins_manage_all_roles" ON public.user_roles_by_city_sport
    FOR ALL TO authenticated
    USING (public.is_super_admin(public.current_user_id()));

-- Policy: City admins can view roles in their jurisdiction
CREATE POLICY "city_admins_view_jurisdiction_roles" ON public.user_roles_by_city_sport
    FOR SELECT TO authenticated
    USING (
        user_id = public.current_user_id() OR
        public.is_super_admin(public.current_user_id()) OR
        EXISTS (
            SELECT 1 FROM public.user_profiles up
            JOIN public.user_roles_by_city_sport admin_role ON up.user_id = admin_role.user_id
            WHERE up.user_id = public.current_user_id()
            AND up.primary_role = 'city_admin'
            AND up.is_active = TRUE
            AND admin_role.role_name = 'city_admin'
            AND admin_role.is_active = TRUE
            AND (
                public.user_roles_by_city_sport.city_id = admin_role.city_id
                OR public.user_roles_by_city_sport.city_id IS NULL
            )
        )
    );

-- Policy: City admins can manage specific roles in their jurisdiction
CREATE POLICY "city_admins_manage_jurisdiction_roles" ON public.user_roles_by_city_sport
    FOR INSERT TO authenticated
    WITH CHECK (
        public.is_super_admin(public.current_user_id()) OR
        (
            role_name IN ('owner', 'coach', 'referee', 'player', 'client') AND
            EXISTS (
                SELECT 1 FROM public.user_profiles up
                JOIN public.user_roles_by_city_sport admin_role ON up.user_id = admin_role.user_id
                WHERE up.user_id = public.current_user_id()
                AND up.primary_role = 'city_admin'
                AND up.is_active = TRUE
                AND admin_role.role_name = 'city_admin'
                AND admin_role.is_active = TRUE
                AND public.user_roles_by_city_sport.city_id = admin_role.city_id
            )
        )
    );

-- =====================================================
-- CITIES AND SPORTS POLICIES
-- =====================================================

-- Policy: Everyone can view active cities
CREATE POLICY "everyone_view_active_cities" ON public.cities
    FOR SELECT TO anon, authenticated
    USING (is_active = TRUE);

-- Policy: Super admins can manage cities
CREATE POLICY "super_admins_manage_cities" ON public.cities
    FOR ALL TO authenticated
    USING (public.is_super_admin(public.current_user_id()));

-- Policy: Everyone can view active sports
CREATE POLICY "everyone_view_active_sports" ON public.sports
    FOR SELECT TO anon, authenticated
    USING (is_active = TRUE);

-- Policy: Super admins can manage sports
CREATE POLICY "super_admins_manage_sports" ON public.sports
    FOR ALL TO authenticated
    USING (public.is_super_admin(public.current_user_id()));

-- =====================================================
-- TOURNAMENTS POLICIES
-- =====================================================

-- Policy: Public can view public tournaments
CREATE POLICY "public_view_public_tournaments" ON public.tournaments
    FOR SELECT TO anon, authenticated
    USING (is_public = TRUE AND status IN ('approved', 'active', 'completed'));

-- Policy: Super admins can manage all tournaments
CREATE POLICY "super_admins_manage_all_tournaments" ON public.tournaments
    FOR ALL TO authenticated
    USING (public.is_super_admin(public.current_user_id()));

-- Policy: City admins can manage tournaments in their jurisdiction
CREATE POLICY "city_admins_manage_jurisdiction_tournaments" ON public.tournaments
    FOR ALL TO authenticated
    USING (
        public.is_super_admin(public.current_user_id()) OR
        admin_user_id = public.current_user_id() OR
        EXISTS (
            SELECT 1 FROM public.user_roles_by_city_sport ur
            WHERE ur.user_id = public.current_user_id()
            AND ur.role_name = 'city_admin'
            AND ur.is_active = TRUE
            AND ur.city_id = public.tournaments.city_id
            AND (ur.sport_id = public.tournaments.sport_id OR ur.sport_id IS NULL)
        )
    );

-- Policy: Team owners can view tournaments they participate in
CREATE POLICY "team_owners_view_participating_tournaments" ON public.tournaments
    FOR SELECT TO authenticated
    USING (
        is_public = TRUE OR
        public.is_super_admin(public.current_user_id()) OR
        admin_user_id = public.current_user_id() OR
        EXISTS (
            SELECT 1 FROM public.tournament_teams tt
            JOIN public.teams t ON tt.team_id = t.team_id
            WHERE tt.tournament_id = public.tournaments.tournament_id
            AND t.owner_user_id = public.current_user_id()
            AND tt.status = 'approved'
        )
    );

-- =====================================================
-- TOURNAMENT TEAMS POLICIES
-- =====================================================

-- Policy: Public can view approved tournament teams
CREATE POLICY "public_view_approved_tournament_teams" ON public.tournament_teams
    FOR SELECT TO anon, authenticated
    USING (
        status = 'approved' AND
        EXISTS (
            SELECT 1 FROM public.tournaments t
            WHERE t.tournament_id = public.tournament_teams.tournament_id
            AND t.is_public = TRUE
            AND t.status IN ('approved', 'active', 'completed')
        )
    );

-- Policy: Super admins can manage all tournament teams
CREATE POLICY "super_admins_manage_all_tournament_teams" ON public.tournament_teams
    FOR ALL TO authenticated
    USING (public.is_super_admin(public.current_user_id()));

-- Policy: City admins can manage tournament teams in their jurisdiction
CREATE POLICY "city_admins_manage_jurisdiction_tournament_teams" ON public.tournament_teams
    FOR ALL TO authenticated
    USING (
        public.is_super_admin(public.current_user_id()) OR
        EXISTS (
            SELECT 1 FROM public.tournaments t
            JOIN public.user_roles_by_city_sport ur ON ur.user_id = public.current_user_id()
            WHERE t.tournament_id = public.tournament_teams.tournament_id
            AND ur.role_name = 'city_admin'
            AND ur.is_active = TRUE
            AND ur.city_id = t.city_id
            AND (ur.sport_id = t.sport_id OR ur.sport_id IS NULL)
        ) OR
        EXISTS (
            SELECT 1 FROM public.tournaments t
            WHERE t.tournament_id = public.tournament_teams.tournament_id
            AND t.admin_user_id = public.current_user_id()
        )
    );

-- Policy: Team owners can manage their team registrations
CREATE POLICY "team_owners_manage_registrations" ON public.tournament_teams
    FOR ALL TO authenticated
    USING (
        public.is_super_admin(public.current_user_id()) OR
        EXISTS (
            SELECT 1 FROM public.teams t
            WHERE t.team_id = public.tournament_teams.team_id
            AND t.owner_user_id = public.current_user_id()
        )
    );

-- =====================================================
-- TEAMS POLICIES
-- =====================================================

-- Policy: Public can view active teams
CREATE POLICY "public_view_active_teams" ON public.teams
    FOR SELECT TO anon, authenticated
    USING (is_active = TRUE);

-- Policy: Super admins can manage all teams
CREATE POLICY "super_admins_manage_all_teams" ON public.teams
    FOR ALL TO authenticated
    USING (public.is_super_admin(public.current_user_id()));

-- Policy: Team owners can manage their teams
CREATE POLICY "team_owners_manage_teams" ON public.teams
    FOR ALL TO authenticated
    USING (
        public.is_super_admin(public.current_user_id()) OR
        owner_user_id = public.current_user_id()
    );

-- Policy: City admins can view teams in their jurisdiction
CREATE POLICY "city_admins_view_jurisdiction_teams" ON public.teams
    FOR SELECT TO authenticated
    USING (
        is_active = TRUE OR
        public.is_super_admin(public.current_user_id()) OR
        owner_user_id = public.current_user_id() OR
        EXISTS (
            SELECT 1 FROM public.user_roles_by_city_sport ur
            WHERE ur.user_id = public.current_user_id()
            AND ur.role_name = 'city_admin'
            AND ur.is_active = TRUE
            AND ur.city_id = public.teams.city_id
            AND (ur.sport_id = public.teams.sport_id OR ur.sport_id IS NULL)
        )
    );

-- =====================================================
-- PLAYERS POLICIES
-- =====================================================

-- Policy: Public can view active players
CREATE POLICY "public_view_active_players" ON public.players
    FOR SELECT TO anon, authenticated
    USING (is_active = TRUE);

-- Policy: Super admins can manage all players
CREATE POLICY "super_admins_manage_all_players" ON public.players
    FOR ALL TO authenticated
    USING (public.is_super_admin(public.current_user_id()));

-- Policy: Players can manage their own profile
CREATE POLICY "players_manage_own_profile" ON public.players
    FOR ALL TO authenticated
    USING (
        public.is_super_admin(public.current_user_id()) OR
        user_profile_id = public.current_user_id()
    );

-- Policy: Team owners can view players in their teams
CREATE POLICY "team_owners_view_team_players" ON public.players
    FOR SELECT TO authenticated
    USING (
        is_active = TRUE OR
        public.is_super_admin(public.current_user_id()) OR
        user_profile_id = public.current_user_id() OR
        EXISTS (
            SELECT 1 FROM public.team_players tp
            JOIN public.teams t ON tp.team_id = t.team_id
            WHERE tp.player_id = public.players.player_id
            AND t.owner_user_id = public.current_user_id()
            AND tp.is_active = TRUE
        )
    );

-- =====================================================
-- TEAM PLAYERS POLICIES
-- =====================================================

-- Policy: Public can view active team players
CREATE POLICY "public_view_active_team_players" ON public.team_players
    FOR SELECT TO anon, authenticated
    USING (
        is_active = TRUE AND
        EXISTS (
            SELECT 1 FROM public.teams t
            WHERE t.team_id = public.team_players.team_id
            AND t.is_active = TRUE
        )
    );

-- Policy: Super admins can manage all team players
CREATE POLICY "super_admins_manage_all_team_players" ON public.team_players
    FOR ALL TO authenticated
    USING (public.is_super_admin(public.current_user_id()));

-- Policy: Team owners can manage their team players
CREATE POLICY "team_owners_manage_team_players" ON public.team_players
    FOR ALL TO authenticated
    USING (
        public.is_super_admin(public.current_user_id()) OR
        EXISTS (
            SELECT 1 FROM public.teams t
            WHERE t.team_id = public.team_players.team_id
            AND t.owner_user_id = public.current_user_id()
        )
    );

-- Policy: Players can view their own team associations
CREATE POLICY "players_view_own_team_associations" ON public.team_players
    FOR SELECT TO authenticated
    USING (
        is_active = TRUE OR
        public.is_super_admin(public.current_user_id()) OR
        EXISTS (
            SELECT 1 FROM public.players p
            WHERE p.player_id = public.team_players.player_id
            AND p.user_profile_id = public.current_user_id()
        )
    );

-- =====================================================
-- MATCHES POLICIES
-- =====================================================

-- Policy: Public can view completed and live matches
CREATE POLICY "public_view_completed_live_matches" ON public.matches
    FOR SELECT TO anon, authenticated
    USING (
        status IN ('completed', 'live') OR
        (status = 'scheduled' AND match_date >= CURRENT_DATE - INTERVAL '1 day')
    );

-- Policy: Super admins can manage all matches
CREATE POLICY "super_admins_manage_all_matches" ON public.matches
    FOR ALL TO authenticated
    USING (public.is_super_admin(public.current_user_id()));

-- Policy: City admins can manage matches in their jurisdiction
CREATE POLICY "city_admins_manage_jurisdiction_matches" ON public.matches
    FOR ALL TO authenticated
    USING (
        public.is_super_admin(public.current_user_id()) OR
        referee_user_id = public.current_user_id() OR
        EXISTS (
            SELECT 1 FROM public.tournaments t
            WHERE t.tournament_id = public.matches.tournament_id
            AND t.admin_user_id = public.current_user_id()
        ) OR
        EXISTS (
            SELECT 1 FROM public.tournaments t
            JOIN public.user_roles_by_city_sport ur ON ur.user_id = public.current_user_id()
            WHERE t.tournament_id = public.matches.tournament_id
            AND ur.role_name = 'city_admin'
            AND ur.is_active = TRUE
            AND ur.city_id = t.city_id
            AND (ur.sport_id = t.sport_id OR ur.sport_id IS NULL)
        )
    );

-- Policy: Team owners can view matches involving their teams
CREATE POLICY "team_owners_view_team_matches" ON public.matches
    FOR SELECT TO authenticated
    USING (
        status IN ('completed', 'live', 'scheduled') OR
        public.is_super_admin(public.current_user_id()) OR
        EXISTS (
            SELECT 1 FROM public.teams t
            WHERE (t.team_id = public.matches.home_team_id OR t.team_id = public.matches.away_team_id)
            AND t.owner_user_id = public.current_user_id()
        )
    );

-- =====================================================
-- MATCH EVENTS POLICIES
-- =====================================================

-- Policy: Public can view match events
CREATE POLICY "public_view_match_events" ON public.match_events
    FOR SELECT TO anon, authenticated
    USING (
        EXISTS (
            SELECT 1 FROM public.matches m
            WHERE m.match_id = public.match_events.match_id
            AND m.status IN ('completed', 'live')
        )
    );

-- Policy: Super admins can manage all match events
CREATE POLICY "super_admins_manage_all_match_events" ON public.match_events
    FOR ALL TO authenticated
    USING (public.is_super_admin(public.current_user_id()));

-- Policy: Referees can manage events in their matches
CREATE POLICY "referees_manage_match_events" ON public.match_events
    FOR ALL TO authenticated
    USING (
        public.is_super_admin(public.current_user_id()) OR
        EXISTS (
            SELECT 1 FROM public.matches m
            WHERE m.match_id = public.match_events.match_id
            AND m.referee_user_id = public.current_user_id()
        )
    );

-- =====================================================
-- STATISTICS POLICIES
-- =====================================================

-- Policy: Public can view all player statistics
CREATE POLICY "public_view_player_statistics" ON public.player_statistics
    FOR SELECT TO anon, authenticated
    USING (TRUE);

-- Policy: Super admins can manage all player statistics
CREATE POLICY "super_admins_manage_player_statistics" ON public.player_statistics
    FOR ALL TO authenticated
    USING (public.is_super_admin(public.current_user_id()));

-- Policy: System can update player statistics (for automated calculations)
CREATE POLICY "system_update_player_statistics" ON public.player_statistics
    FOR INSERT TO authenticated
    WITH CHECK (TRUE);

CREATE POLICY "system_update_existing_player_statistics" ON public.player_statistics
    FOR UPDATE TO authenticated
    USING (TRUE);

-- Policy: Public can view all team statistics
CREATE POLICY "public_view_team_statistics" ON public.team_statistics
    FOR SELECT TO anon, authenticated
    USING (TRUE);

-- Policy: Super admins can manage all team statistics
CREATE POLICY "super_admins_manage_team_statistics" ON public.team_statistics
    FOR ALL TO authenticated
    USING (public.is_super_admin(public.current_user_id()));

-- Policy: System can update team statistics (for automated calculations)
CREATE POLICY "system_update_team_statistics" ON public.team_statistics
    FOR INSERT TO authenticated
    WITH CHECK (TRUE);

CREATE POLICY "system_update_existing_team_statistics" ON public.team_statistics
    FOR UPDATE TO authenticated
    USING (TRUE);

-- =====================================================
-- AUDIT LOGS POLICIES
-- =====================================================

-- Policy: Super admins can view all audit logs
CREATE POLICY "super_admins_view_all_audit_logs" ON public.audit_logs
    FOR SELECT TO authenticated
    USING (public.is_super_admin(public.current_user_id()));

-- Policy: City admins can view audit logs for their jurisdiction
CREATE POLICY "city_admins_view_jurisdiction_audit_logs" ON public.audit_logs
    FOR SELECT TO authenticated
    USING (
        public.is_super_admin(public.current_user_id()) OR
        user_id = public.current_user_id() OR
        EXISTS (
            SELECT 1 FROM public.user_profiles up
            JOIN public.user_roles_by_city_sport ur ON up.user_id = ur.user_id
            WHERE up.user_id = public.current_user_id()
            AND up.primary_role = 'city_admin'
            AND up.is_active = TRUE
            AND ur.role_name = 'city_admin'
            AND ur.is_active = TRUE
            AND public.audit_logs.user_id IN (
                SELECT target_ur.user_id 
                FROM public.user_roles_by_city_sport target_ur
                WHERE target_ur.city_id = ur.city_id
                AND target_ur.is_active = TRUE
            )
        )
    );

-- Policy: Users can view their own audit logs
CREATE POLICY "users_view_own_audit_logs" ON public.audit_logs
    FOR SELECT TO authenticated
    USING (
        user_id = public.current_user_id() OR
        public.is_super_admin(public.current_user_id())
    );

-- Policy: System can insert audit logs
CREATE POLICY "system_insert_audit_logs" ON public.audit_logs
    FOR INSERT TO authenticated
    WITH CHECK (TRUE);

-- =====================================================
-- USER VIEW PERMISSIONS POLICIES
-- =====================================================

-- Policy: Super admins can manage all view permissions
CREATE POLICY "super_admins_manage_view_permissions" ON public.user_view_permissions
    FOR ALL TO authenticated
    USING (public.is_super_admin(public.current_user_id()));

-- Policy: Users can view permissions that affect them
CREATE POLICY "users_view_relevant_permissions" ON public.user_view_permissions
    FOR SELECT TO authenticated
    USING (
        public.is_super_admin(public.current_user_id()) OR
        user_id = public.current_user_id() OR
        (
            role_name IS NOT NULL AND
            EXISTS (
                SELECT 1 FROM public.user_profiles
                WHERE user_id = public.current_user_id()
                AND primary_role = public.user_view_permissions.role_name
            )
        )
    );

-- =====================================================
-- LOG RLS POLICY CREATION
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
    'SYSTEM_INIT',
    'rls_policies',
    NULL,
    '{"message": "Row Level Security policies implemented", "tables_secured": "all", "policies_created": "comprehensive multi-tenant security"}'::jsonb,
    '127.0.0.1'::inet,
    'Mowe Sport Database Migration'
);

-- =====================================================
-- VALIDATE RLS IMPLEMENTATION
-- =====================================================

DO $$
DECLARE
    policy_count INTEGER;
    table_count INTEGER;
BEGIN
    -- Count RLS policies created
    SELECT COUNT(*) INTO policy_count
    FROM pg_policies
    WHERE schemaname = 'public';
    
    -- Count tables with RLS enabled
    SELECT COUNT(*) INTO table_count
    FROM pg_class c
    JOIN pg_namespace n ON c.relnamespace = n.oid
    WHERE n.nspname = 'public'
    AND c.relkind = 'r'
    AND c.relrowsecurity = true;
    
    RAISE NOTICE 'RLS Implementation Summary:';
    RAISE NOTICE '- Tables with RLS enabled: %', table_count;
    RAISE NOTICE '- RLS policies created: %', policy_count;
    
    IF policy_count < 30 THEN
        RAISE EXCEPTION 'Expected at least 30 RLS policies, found %', policy_count;
    END IF;
    
    IF table_count < 10 THEN
        RAISE EXCEPTION 'Expected at least 10 tables with RLS enabled, found %', table_count;
    END IF;
    
    RAISE NOTICE 'RLS implementation completed successfully!';
END $$;