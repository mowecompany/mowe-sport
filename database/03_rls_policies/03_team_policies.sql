-- =====================================================
-- MOWE SPORT PLATFORM - TEAM AND PLAYER RLS POLICIES
-- =====================================================
-- Description: Row Level Security policies for teams and players
-- Dependencies: 01_user_policies.sql, 02_tournament_policies.sql
-- Execution Order: After tournament policies
-- =====================================================

-- =====================================================
-- TEAMS POLICIES
-- =====================================================

-- Policy: Public can view active teams
CREATE POLICY "Public can view active teams" ON public.teams
    FOR SELECT TO anon, authenticated
    USING (is_active = TRUE);

-- Policy: Super admins can manage all teams
CREATE POLICY "Super admins can manage all teams" ON public.teams
    FOR ALL TO authenticated
    USING (public.is_super_admin(auth.uid()));

-- Policy: Team owners can manage their teams
CREATE POLICY "Team owners can manage their teams" ON public.teams
    FOR ALL TO authenticated
    USING (owner_user_id = auth.uid());

-- Policy: City admins can view teams in their jurisdiction
CREATE POLICY "City admins can view jurisdiction teams" ON public.teams
    FOR SELECT TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM public.user_roles_by_city_sport ur
            WHERE ur.user_id = auth.uid()
            AND ur.role_name = 'city_admin'
            AND ur.is_active = TRUE
            AND ur.city_id = public.teams.city_id
            AND ur.sport_id = public.teams.sport_id
        )
    );

-- Policy: City admins can manage teams in their jurisdiction
CREATE POLICY "City admins can manage jurisdiction teams" ON public.teams
    FOR UPDATE TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM public.user_roles_by_city_sport ur
            WHERE ur.user_id = auth.uid()
            AND ur.role_name = 'city_admin'
            AND ur.is_active = TRUE
            AND ur.city_id = public.teams.city_id
            AND ur.sport_id = public.teams.sport_id
        )
    );

-- Policy: Coaches can view teams they are associated with
CREATE POLICY "Coaches can view associated teams" ON public.teams
    FOR SELECT TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM public.user_roles_by_city_sport ur
            WHERE ur.user_id = auth.uid()
            AND ur.role_name = 'coach'
            AND ur.is_active = TRUE
            AND ur.city_id = public.teams.city_id
            AND ur.sport_id = public.teams.sport_id
        )
    );

-- =====================================================
-- PLAYERS POLICIES
-- =====================================================

-- Policy: Public can view active players
CREATE POLICY "Public can view active players" ON public.players
    FOR SELECT TO anon, authenticated
    USING (is_active = TRUE);

-- Policy: Super admins can manage all players
CREATE POLICY "Super admins can manage all players" ON public.players
    FOR ALL TO authenticated
    USING (public.is_super_admin(auth.uid()));

-- Policy: Players can view and update their own profile
CREATE POLICY "Players can manage own profile" ON public.players
    FOR ALL TO authenticated
    USING (user_profile_id = auth.uid());

-- Policy: Team owners can manage players in their teams
CREATE POLICY "Team owners can manage team players" ON public.players
    FOR ALL TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM public.team_players tp
            JOIN public.teams t ON tp.team_id = t.team_id
            WHERE tp.player_id = public.players.player_id
            AND t.owner_user_id = auth.uid()
            AND tp.is_active = TRUE
        )
    );

-- Policy: City admins can view players in their jurisdiction
CREATE POLICY "City admins can view jurisdiction players" ON public.players
    FOR SELECT TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM public.team_players tp
            JOIN public.teams t ON tp.team_id = t.team_id
            JOIN public.user_roles_by_city_sport ur ON ur.user_id = auth.uid()
            WHERE tp.player_id = public.players.player_id
            AND ur.role_name = 'city_admin'
            AND ur.is_active = TRUE
            AND ur.city_id = t.city_id
            AND ur.sport_id = t.sport_id
        )
    );

-- Policy: Coaches can view players in their teams
CREATE POLICY "Coaches can view team players" ON public.players
    FOR SELECT TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM public.team_players tp
            JOIN public.teams t ON tp.team_id = t.team_id
            JOIN public.user_roles_by_city_sport ur ON ur.user_id = auth.uid()
            WHERE tp.player_id = public.players.player_id
            AND ur.role_name = 'coach'
            AND ur.is_active = TRUE
            AND ur.city_id = t.city_id
            AND ur.sport_id = t.sport_id
            AND tp.is_active = TRUE
        )
    );

-- =====================================================
-- TEAM PLAYERS POLICIES
-- =====================================================

-- Policy: Public can view active team players
CREATE POLICY "Public can view active team players" ON public.team_players
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
CREATE POLICY "Super admins can manage all team players" ON public.team_players
    FOR ALL TO authenticated
    USING (public.is_super_admin(auth.uid()));

-- Policy: Team owners can manage their team players
CREATE POLICY "Team owners can manage their team players" ON public.team_players
    FOR ALL TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM public.teams t
            WHERE t.team_id = public.team_players.team_id
            AND t.owner_user_id = auth.uid()
        )
    );

-- Policy: Players can view their own team associations
CREATE POLICY "Players can view own team associations" ON public.team_players
    FOR SELECT TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM public.players p
            WHERE p.player_id = public.team_players.player_id
            AND p.user_profile_id = auth.uid()
        )
    );

-- Policy: City admins can manage team players in their jurisdiction
CREATE POLICY "City admins can manage jurisdiction team players" ON public.team_players
    FOR ALL TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM public.teams t
            JOIN public.user_roles_by_city_sport ur ON ur.user_id = auth.uid()
            WHERE t.team_id = public.team_players.team_id
            AND ur.role_name = 'city_admin'
            AND ur.is_active = TRUE
            AND ur.city_id = t.city_id
            AND ur.sport_id = t.sport_id
        )
    );

-- Policy: Coaches can view team players in their teams
CREATE POLICY "Coaches can view their team players" ON public.team_players
    FOR SELECT TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM public.teams t
            JOIN public.user_roles_by_city_sport ur ON ur.user_id = auth.uid()
            WHERE t.team_id = public.team_players.team_id
            AND ur.role_name = 'coach'
            AND ur.is_active = TRUE
            AND ur.city_id = t.city_id
            AND ur.sport_id = t.sport_id
        )
    );

-- =====================================================
-- PLAYER TRANSFERS POLICIES
-- =====================================================

-- Enable RLS on player transfers
ALTER TABLE public.player_transfers ENABLE ROW LEVEL SECURITY;

-- Policy: Public can view completed transfers
CREATE POLICY "Public can view completed transfers" ON public.player_transfers
    FOR SELECT TO anon, authenticated
    USING (status = 'completed');

-- Policy: Super admins can manage all transfers
CREATE POLICY "Super admins can manage all transfers" ON public.player_transfers
    FOR ALL TO authenticated
    USING (public.is_super_admin(auth.uid()));

-- Policy: Team owners can manage transfers involving their teams
CREATE POLICY "Team owners can manage their transfers" ON public.player_transfers
    FOR ALL TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM public.teams t
            WHERE (t.team_id = public.player_transfers.from_team_id OR 
                   t.team_id = public.player_transfers.to_team_id)
            AND t.owner_user_id = auth.uid()
        )
    );

-- Policy: Players can view their own transfers
CREATE POLICY "Players can view own transfers" ON public.player_transfers
    FOR SELECT TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM public.players p
            WHERE p.player_id = public.player_transfers.player_id
            AND p.user_profile_id = auth.uid()
        )
    );

-- Policy: City admins can manage transfers in their jurisdiction
CREATE POLICY "City admins can manage jurisdiction transfers" ON public.player_transfers
    FOR ALL TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM public.teams t
            JOIN public.user_roles_by_city_sport ur ON ur.user_id = auth.uid()
            WHERE (t.team_id = public.player_transfers.from_team_id OR 
                   t.team_id = public.player_transfers.to_team_id)
            AND ur.role_name = 'city_admin'
            AND ur.is_active = TRUE
            AND ur.city_id = t.city_id
            AND ur.sport_id = t.sport_id
        )
    );

-- =====================================================
-- HELPER FUNCTIONS FOR TEAM ACCESS
-- =====================================================

-- Function to check if user can access team
CREATE OR REPLACE FUNCTION public.can_access_team(
    p_user_id UUID,
    p_team_id UUID
) RETURNS BOOLEAN AS $$
BEGIN
    -- Super admin can access all teams
    IF public.is_super_admin(p_user_id) THEN
        RETURN TRUE;
    END IF;
    
    -- Team owner can access their team
    IF EXISTS (
        SELECT 1 FROM public.teams
        WHERE team_id = p_team_id
        AND owner_user_id = p_user_id
    ) THEN
        RETURN TRUE;
    END IF;
    
    -- City admin can access teams in their jurisdiction
    IF EXISTS (
        SELECT 1 FROM public.teams t
        JOIN public.user_roles_by_city_sport ur ON ur.user_id = p_user_id
        WHERE t.team_id = p_team_id
        AND ur.role_name = 'city_admin'
        AND ur.is_active = TRUE
        AND ur.city_id = t.city_id
        AND ur.sport_id = t.sport_id
    ) THEN
        RETURN TRUE;
    END IF;
    
    -- Coach can access teams they are associated with
    IF EXISTS (
        SELECT 1 FROM public.teams t
        JOIN public.user_roles_by_city_sport ur ON ur.user_id = p_user_id
        WHERE t.team_id = p_team_id
        AND ur.role_name = 'coach'
        AND ur.is_active = TRUE
        AND ur.city_id = t.city_id
        AND ur.sport_id = t.sport_id
    ) THEN
        RETURN TRUE;
    END IF;
    
    -- Player can access teams they belong to
    IF EXISTS (
        SELECT 1 FROM public.team_players tp
        JOIN public.players p ON tp.player_id = p.player_id
        WHERE tp.team_id = p_team_id
        AND p.user_profile_id = p_user_id
        AND tp.is_active = TRUE
    ) THEN
        RETURN TRUE;
    END IF;
    
    -- Active teams are accessible to everyone for viewing
    IF EXISTS (
        SELECT 1 FROM public.teams
        WHERE team_id = p_team_id
        AND is_active = TRUE
    ) THEN
        RETURN TRUE;
    END IF;
    
    RETURN FALSE;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to check if user can manage team
CREATE OR REPLACE FUNCTION public.can_manage_team(
    p_user_id UUID,
    p_team_id UUID
) RETURNS BOOLEAN AS $$
BEGIN
    -- Super admin can manage all teams
    IF public.is_super_admin(p_user_id) THEN
        RETURN TRUE;
    END IF;
    
    -- Team owner can manage their team
    IF EXISTS (
        SELECT 1 FROM public.teams
        WHERE team_id = p_team_id
        AND owner_user_id = p_user_id
    ) THEN
        RETURN TRUE;
    END IF;
    
    -- City admin can manage teams in their jurisdiction
    IF EXISTS (
        SELECT 1 FROM public.teams t
        JOIN public.user_roles_by_city_sport ur ON ur.user_id = p_user_id
        WHERE t.team_id = p_team_id
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

-- Function to check if user can manage player
CREATE OR REPLACE FUNCTION public.can_manage_player(
    p_user_id UUID,
    p_player_id UUID
) RETURNS BOOLEAN AS $$
BEGIN
    -- Super admin can manage all players
    IF public.is_super_admin(p_user_id) THEN
        RETURN TRUE;
    END IF;
    
    -- Player can manage their own profile
    IF EXISTS (
        SELECT 1 FROM public.players
        WHERE player_id = p_player_id
        AND user_profile_id = p_user_id
    ) THEN
        RETURN TRUE;
    END IF;
    
    -- Team owner can manage players in their teams
    IF EXISTS (
        SELECT 1 FROM public.team_players tp
        JOIN public.teams t ON tp.team_id = t.team_id
        WHERE tp.player_id = p_player_id
        AND t.owner_user_id = p_user_id
        AND tp.is_active = TRUE
    ) THEN
        RETURN TRUE;
    END IF;
    
    -- City admin can manage players in their jurisdiction
    IF EXISTS (
        SELECT 1 FROM public.team_players tp
        JOIN public.teams t ON tp.team_id = t.team_id
        JOIN public.user_roles_by_city_sport ur ON ur.user_id = p_user_id
        WHERE tp.player_id = p_player_id
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
COMMENT ON FUNCTION public.can_access_team IS 'Check if user can access a specific team';
COMMENT ON FUNCTION public.can_manage_team IS 'Check if user can manage a specific team';
COMMENT ON FUNCTION public.can_manage_player IS 'Check if user can manage a specific player';