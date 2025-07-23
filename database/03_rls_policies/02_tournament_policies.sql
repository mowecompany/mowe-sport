-- =====================================================
-- MOWE SPORT PLATFORM - TOURNAMENT RLS POLICIES
-- =====================================================
-- Description: Row Level Security policies for tournament-related tables
-- Dependencies: 01_user_policies.sql
-- Execution Order: After user policies
-- =====================================================

-- =====================================================
-- TOURNAMENTS POLICIES
-- =====================================================

-- Policy: Public can view public tournaments
CREATE POLICY "Public can view public tournaments" ON public.tournaments
    FOR SELECT TO anon, authenticated
    USING (is_public = TRUE AND status IN ('approved', 'active', 'completed'));

-- Policy: Super admins can manage all tournaments
CREATE POLICY "Super admins can manage all tournaments" ON public.tournaments
    FOR ALL TO authenticated
    USING (public.is_super_admin(auth.uid()));

-- Policy: City admins can view tournaments in their jurisdiction
CREATE POLICY "City admins can view jurisdiction tournaments" ON public.tournaments
    FOR SELECT TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM public.user_roles_by_city_sport ur
            WHERE ur.user_id = auth.uid()
            AND ur.role_name = 'city_admin'
            AND ur.is_active = TRUE
            AND ur.city_id = public.tournaments.city_id
        )
    );

-- Policy: City admins can manage tournaments in their jurisdiction
CREATE POLICY "City admins can manage jurisdiction tournaments" ON public.tournaments
    FOR ALL TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM public.user_roles_by_city_sport ur
            WHERE ur.user_id = auth.uid()
            AND ur.role_name = 'city_admin'
            AND ur.is_active = TRUE
            AND ur.city_id = public.tournaments.city_id
            AND ur.sport_id = public.tournaments.sport_id
        )
    );

-- Policy: Tournament admins can manage their assigned tournaments
CREATE POLICY "Tournament admins can manage assigned tournaments" ON public.tournaments
    FOR ALL TO authenticated
    USING (admin_user_id = auth.uid());

-- Policy: Team owners can view tournaments they participate in
CREATE POLICY "Team owners can view participating tournaments" ON public.tournaments
    FOR SELECT TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM public.tournament_teams tt
            JOIN public.teams t ON tt.team_id = t.team_id
            WHERE tt.tournament_id = public.tournaments.tournament_id
            AND t.owner_user_id = auth.uid()
            AND tt.status = 'approved'
        )
    );

-- =====================================================
-- TOURNAMENT CATEGORIES POLICIES
-- =====================================================

-- Policy: Public can view categories of public tournaments
CREATE POLICY "Public can view public tournament categories" ON public.tournament_categories
    FOR SELECT TO anon, authenticated
    USING (
        EXISTS (
            SELECT 1 FROM public.tournaments t
            WHERE t.tournament_id = public.tournament_categories.tournament_id
            AND t.is_public = TRUE
            AND t.status IN ('approved', 'active', 'completed')
        )
    );

-- Policy: Super admins can manage all categories
CREATE POLICY "Super admins can manage all categories" ON public.tournament_categories
    FOR ALL TO authenticated
    USING (public.is_super_admin(auth.uid()));

-- Policy: City admins can manage categories in their jurisdiction
CREATE POLICY "City admins can manage jurisdiction categories" ON public.tournament_categories
    FOR ALL TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM public.tournaments t
            JOIN public.user_roles_by_city_sport ur ON ur.user_id = auth.uid()
            WHERE t.tournament_id = public.tournament_categories.tournament_id
            AND ur.role_name = 'city_admin'
            AND ur.is_active = TRUE
            AND ur.city_id = t.city_id
            AND ur.sport_id = t.sport_id
        )
    );

-- Policy: Tournament admins can manage categories of their tournaments
CREATE POLICY "Tournament admins can manage their categories" ON public.tournament_categories
    FOR ALL TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM public.tournaments t
            WHERE t.tournament_id = public.tournament_categories.tournament_id
            AND t.admin_user_id = auth.uid()
        )
    );

-- =====================================================
-- TOURNAMENT TEAMS POLICIES
-- =====================================================

-- Policy: Public can view approved tournament teams
CREATE POLICY "Public can view approved tournament teams" ON public.tournament_teams
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
CREATE POLICY "Super admins can manage all tournament teams" ON public.tournament_teams
    FOR ALL TO authenticated
    USING (public.is_super_admin(auth.uid()));

-- Policy: City admins can manage tournament teams in their jurisdiction
CREATE POLICY "City admins can manage jurisdiction tournament teams" ON public.tournament_teams
    FOR ALL TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM public.tournaments t
            JOIN public.user_roles_by_city_sport ur ON ur.user_id = auth.uid()
            WHERE t.tournament_id = public.tournament_teams.tournament_id
            AND ur.role_name = 'city_admin'
            AND ur.is_active = TRUE
            AND ur.city_id = t.city_id
            AND ur.sport_id = t.sport_id
        )
    );

-- Policy: Tournament admins can manage teams in their tournaments
CREATE POLICY "Tournament admins can manage their tournament teams" ON public.tournament_teams
    FOR ALL TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM public.tournaments t
            WHERE t.tournament_id = public.tournament_teams.tournament_id
            AND t.admin_user_id = auth.uid()
        )
    );

-- Policy: Team owners can manage their team registrations
CREATE POLICY "Team owners can manage their registrations" ON public.tournament_teams
    FOR ALL TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM public.teams t
            WHERE t.team_id = public.tournament_teams.team_id
            AND t.owner_user_id = auth.uid()
        )
    );

-- Policy: Team owners can view their team registrations
CREATE POLICY "Team owners can view their registrations" ON public.tournament_teams
    FOR SELECT TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM public.teams t
            WHERE t.team_id = public.tournament_teams.team_id
            AND t.owner_user_id = auth.uid()
        )
    );

-- =====================================================
-- HELPER FUNCTIONS FOR TOURNAMENT ACCESS
-- =====================================================

-- Function to check if user can access tournament
CREATE OR REPLACE FUNCTION public.can_access_tournament(
    p_user_id UUID,
    p_tournament_id UUID
) RETURNS BOOLEAN AS $$
BEGIN
    -- Super admin can access all tournaments
    IF public.is_super_admin(p_user_id) THEN
        RETURN TRUE;
    END IF;
    
    -- Tournament admin can access their tournaments
    IF EXISTS (
        SELECT 1 FROM public.tournaments
        WHERE tournament_id = p_tournament_id
        AND admin_user_id = p_user_id
    ) THEN
        RETURN TRUE;
    END IF;
    
    -- City admin can access tournaments in their jurisdiction
    IF EXISTS (
        SELECT 1 FROM public.tournaments t
        JOIN public.user_roles_by_city_sport ur ON ur.user_id = p_user_id
        WHERE t.tournament_id = p_tournament_id
        AND ur.role_name = 'city_admin'
        AND ur.is_active = TRUE
        AND ur.city_id = t.city_id
        AND ur.sport_id = t.sport_id
    ) THEN
        RETURN TRUE;
    END IF;
    
    -- Team owner can access tournaments they participate in
    IF EXISTS (
        SELECT 1 FROM public.tournament_teams tt
        JOIN public.teams tm ON tt.team_id = tm.team_id
        WHERE tt.tournament_id = p_tournament_id
        AND tm.owner_user_id = p_user_id
        AND tt.status = 'approved'
    ) THEN
        RETURN TRUE;
    END IF;
    
    -- Public tournaments are accessible to everyone
    IF EXISTS (
        SELECT 1 FROM public.tournaments
        WHERE tournament_id = p_tournament_id
        AND is_public = TRUE
        AND status IN ('approved', 'active', 'completed')
    ) THEN
        RETURN TRUE;
    END IF;
    
    RETURN FALSE;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to check if user can manage tournament
CREATE OR REPLACE FUNCTION public.can_manage_tournament(
    p_user_id UUID,
    p_tournament_id UUID
) RETURNS BOOLEAN AS $$
BEGIN
    -- Super admin can manage all tournaments
    IF public.is_super_admin(p_user_id) THEN
        RETURN TRUE;
    END IF;
    
    -- Tournament admin can manage their tournaments
    IF EXISTS (
        SELECT 1 FROM public.tournaments
        WHERE tournament_id = p_tournament_id
        AND admin_user_id = p_user_id
    ) THEN
        RETURN TRUE;
    END IF;
    
    -- City admin can manage tournaments in their jurisdiction
    IF EXISTS (
        SELECT 1 FROM public.tournaments t
        JOIN public.user_roles_by_city_sport ur ON ur.user_id = p_user_id
        WHERE t.tournament_id = p_tournament_id
        AND ur.role_name = 'city_admin'
        AND ur.is_active = TRUE
        AND ur.city_id = t.city_id
        AND ur.sport_id = t.sport_id
    ) THEN
        RETURN TRUE;
    END IF;
    
    RETURN FALSE;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Add comments for functions
COMMENT ON FUNCTION public.can_access_tournament IS 'Check if user can access a specific tournament';
COMMENT ON FUNCTION public.can_manage_tournament IS 'Check if user can manage a specific tournament';