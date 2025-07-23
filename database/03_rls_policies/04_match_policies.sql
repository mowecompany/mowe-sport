-- =====================================================
-- MOWE SPORT PLATFORM - MATCH AND STATISTICS RLS POLICIES
-- =====================================================
-- Description: Row Level Security policies for matches and statistics
-- Dependencies: All previous RLS policy files
-- Execution Order: Final RLS policies file
-- =====================================================

-- =====================================================
-- MATCHES POLICIES
-- =====================================================

-- Policy: Public can view completed and live matches
CREATE POLICY "Public can view completed and live matches" ON public.matches
    FOR SELECT TO anon, authenticated
    USING (
        status IN ('completed', 'live', 'half_time') OR
        (status = 'scheduled' AND match_date >= CURRENT_DATE - INTERVAL '1 day')
    );

-- Policy: Super admins can manage all matches
CREATE POLICY "Super admins can manage all matches" ON public.matches
    FOR ALL TO authenticated
    USING (public.is_super_admin(auth.uid()));

-- Policy: City admins can manage matches in their jurisdiction
CREATE POLICY "City admins can manage jurisdiction matches" ON public.matches
    FOR ALL TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM public.tournaments t
            JOIN public.user_roles_by_city_sport ur ON ur.user_id = auth.uid()
            WHERE t.tournament_id = public.matches.tournament_id
            AND ur.role_name = 'city_admin'
            AND ur.is_active = TRUE
            AND ur.city_id = t.city_id
            AND ur.sport_id = t.sport_id
        )
    );

-- Policy: Tournament admins can manage matches in their tournaments
CREATE POLICY "Tournament admins can manage their matches" ON public.matches
    FOR ALL TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM public.tournaments t
            WHERE t.tournament_id = public.matches.tournament_id
            AND t.admin_user_id = auth.uid()
        )
    );

-- Policy: Referees can manage matches they are assigned to
CREATE POLICY "Referees can manage assigned matches" ON public.matches
    FOR ALL TO authenticated
    USING (
        referee_user_id = auth.uid() OR
        assistant_referee_1_id = auth.uid() OR
        assistant_referee_2_id = auth.uid() OR
        fourth_official_id = auth.uid()
    );

-- Policy: Team owners can view matches involving their teams
CREATE POLICY "Team owners can view their team matches" ON public.matches
    FOR SELECT TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM public.teams t
            WHERE (t.team_id = public.matches.home_team_id OR 
                   t.team_id = public.matches.away_team_id)
            AND t.owner_user_id = auth.uid()
        )
    );

-- Policy: Players can view matches they participate in
CREATE POLICY "Players can view their matches" ON public.matches
    FOR SELECT TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM public.team_players tp
            JOIN public.players p ON tp.player_id = p.player_id
            WHERE (tp.team_id = public.matches.home_team_id OR 
                   tp.team_id = public.matches.away_team_id)
            AND p.user_profile_id = auth.uid()
            AND tp.is_active = TRUE
        )
    );

-- =====================================================
-- MATCH EVENTS POLICIES
-- =====================================================

-- Policy: Public can view non-deleted match events
CREATE POLICY "Public can view match events" ON public.match_events
    FOR SELECT TO anon, authenticated
    USING (
        is_deleted = FALSE AND
        EXISTS (
            SELECT 1 FROM public.matches m
            WHERE m.match_id = public.match_events.match_id
            AND m.status IN ('completed', 'live', 'half_time')
        )
    );

-- Policy: Super admins can manage all match events
CREATE POLICY "Super admins can manage all match events" ON public.match_events
    FOR ALL TO authenticated
    USING (public.is_super_admin(auth.uid()));

-- Policy: Referees can manage events in their matches
CREATE POLICY "Referees can manage their match events" ON public.match_events
    FOR ALL TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM public.matches m
            WHERE m.match_id = public.match_events.match_id
            AND (m.referee_user_id = auth.uid() OR
                 m.assistant_referee_1_id = auth.uid() OR
                 m.assistant_referee_2_id = auth.uid() OR
                 m.fourth_official_id = auth.uid())
        )
    );

-- Policy: City admins can manage events in their jurisdiction
CREATE POLICY "City admins can manage jurisdiction match events" ON public.match_events
    FOR ALL TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM public.matches m
            JOIN public.tournaments t ON m.tournament_id = t.tournament_id
            JOIN public.user_roles_by_city_sport ur ON ur.user_id = auth.uid()
            WHERE m.match_id = public.match_events.match_id
            AND ur.role_name = 'city_admin'
            AND ur.is_active = TRUE
            AND ur.city_id = t.city_id
            AND ur.sport_id = t.sport_id
        )
    );

-- Policy: Tournament admins can manage events in their tournaments
CREATE POLICY "Tournament admins can manage their match events" ON public.match_events
    FOR ALL TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM public.matches m
            JOIN public.tournaments t ON m.tournament_id = t.tournament_id
            WHERE m.match_id = public.match_events.match_id
            AND t.admin_user_id = auth.uid()
        )
    );

-- =====================================================
-- MATCH LINEUPS POLICIES
-- =====================================================

-- Enable RLS on match lineups
ALTER TABLE public.match_lineups ENABLE ROW LEVEL SECURITY;

-- Policy: Public can view match lineups
CREATE POLICY "Public can view match lineups" ON public.match_lineups
    FOR SELECT TO anon, authenticated
    USING (
        EXISTS (
            SELECT 1 FROM public.matches m
            WHERE m.match_id = public.match_lineups.match_id
            AND m.status IN ('completed', 'live', 'half_time', 'scheduled')
        )
    );

-- Policy: Super admins can manage all lineups
CREATE POLICY "Super admins can manage all lineups" ON public.match_lineups
    FOR ALL TO authenticated
    USING (public.is_super_admin(auth.uid()));

-- Policy: Team owners can manage lineups for their teams
CREATE POLICY "Team owners can manage their lineups" ON public.match_lineups
    FOR ALL TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM public.teams t
            WHERE t.team_id = public.match_lineups.team_id
            AND t.owner_user_id = auth.uid()
        )
    );

-- Policy: Coaches can manage lineups for their teams
CREATE POLICY "Coaches can manage team lineups" ON public.match_lineups
    FOR ALL TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM public.teams t
            JOIN public.user_roles_by_city_sport ur ON ur.user_id = auth.uid()
            WHERE t.team_id = public.match_lineups.team_id
            AND ur.role_name = 'coach'
            AND ur.is_active = TRUE
            AND ur.city_id = t.city_id
            AND ur.sport_id = t.sport_id
        )
    );

-- Policy: Referees can manage lineups for their matches
CREATE POLICY "Referees can manage match lineups" ON public.match_lineups
    FOR ALL TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM public.matches m
            WHERE m.match_id = public.match_lineups.match_id
            AND (m.referee_user_id = auth.uid() OR
                 m.assistant_referee_1_id = auth.uid() OR
                 m.assistant_referee_2_id = auth.uid() OR
                 m.fourth_official_id = auth.uid())
        )
    );

-- =====================================================
-- MATCH OFFICIALS POLICIES
-- =====================================================

-- Enable RLS on match officials
ALTER TABLE public.match_officials ENABLE ROW LEVEL SECURITY;

-- Policy: Public can view match officials
CREATE POLICY "Public can view match officials" ON public.match_officials
    FOR SELECT TO anon, authenticated
    USING (
        EXISTS (
            SELECT 1 FROM public.matches m
            WHERE m.match_id = public.match_officials.match_id
            AND m.status IN ('completed', 'live', 'half_time', 'scheduled')
        )
    );

-- Policy: Super admins can manage all match officials
CREATE POLICY "Super admins can manage all match officials" ON public.match_officials
    FOR ALL TO authenticated
    USING (public.is_super_admin(auth.uid()));

-- Policy: City admins can manage officials in their jurisdiction
CREATE POLICY "City admins can manage jurisdiction officials" ON public.match_officials
    FOR ALL TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM public.matches m
            JOIN public.tournaments t ON m.tournament_id = t.tournament_id
            JOIN public.user_roles_by_city_sport ur ON ur.user_id = auth.uid()
            WHERE m.match_id = public.match_officials.match_id
            AND ur.role_name = 'city_admin'
            AND ur.is_active = TRUE
            AND ur.city_id = t.city_id
            AND ur.sport_id = t.sport_id
        )
    );

-- Policy: Tournament admins can manage officials in their tournaments
CREATE POLICY "Tournament admins can manage their officials" ON public.match_officials
    FOR ALL TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM public.matches m
            JOIN public.tournaments t ON m.tournament_id = t.tournament_id
            WHERE m.match_id = public.match_officials.match_id
            AND t.admin_user_id = auth.uid()
        )
    );

-- Policy: Officials can view their assignments
CREATE POLICY "Officials can view their assignments" ON public.match_officials
    FOR SELECT TO authenticated
    USING (user_id = auth.uid());

-- =====================================================
-- MATCH COMMENTS POLICIES
-- =====================================================

-- Enable RLS on match comments
ALTER TABLE public.match_comments ENABLE ROW LEVEL SECURITY;

-- Policy: Public can view public match comments
CREATE POLICY "Public can view public match comments" ON public.match_comments
    FOR SELECT TO anon, authenticated
    USING (is_public = TRUE);

-- Policy: Super admins can manage all match comments
CREATE POLICY "Super admins can manage all match comments" ON public.match_comments
    FOR ALL TO authenticated
    USING (public.is_super_admin(auth.uid()));

-- Policy: Users can manage their own comments
CREATE POLICY "Users can manage own match comments" ON public.match_comments
    FOR ALL TO authenticated
    USING (user_id = auth.uid());

-- Policy: City admins can view all comments in their jurisdiction
CREATE POLICY "City admins can view jurisdiction comments" ON public.match_comments
    FOR SELECT TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM public.matches m
            JOIN public.tournaments t ON m.tournament_id = t.tournament_id
            JOIN public.user_roles_by_city_sport ur ON ur.user_id = auth.uid()
            WHERE m.match_id = public.match_comments.match_id
            AND ur.role_name = 'city_admin'
            AND ur.is_active = TRUE
            AND ur.city_id = t.city_id
            AND ur.sport_id = t.sport_id
        )
    );

-- =====================================================
-- MATCH MEDIA POLICIES
-- =====================================================

-- Enable RLS on match media
ALTER TABLE public.match_media ENABLE ROW LEVEL SECURITY;

-- Policy: Public can view public match media
CREATE POLICY "Public can view public match media" ON public.match_media
    FOR SELECT TO anon, authenticated
    USING (is_public = TRUE);

-- Policy: Super admins can manage all match media
CREATE POLICY "Super admins can manage all match media" ON public.match_media
    FOR ALL TO authenticated
    USING (public.is_super_admin(auth.uid()));

-- Policy: Users can manage media they uploaded
CREATE POLICY "Users can manage own match media" ON public.match_media
    FOR ALL TO authenticated
    USING (uploaded_by_user_id = auth.uid());

-- Policy: City admins can manage media in their jurisdiction
CREATE POLICY "City admins can manage jurisdiction media" ON public.match_media
    FOR ALL TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM public.matches m
            JOIN public.tournaments t ON m.tournament_id = t.tournament_id
            JOIN public.user_roles_by_city_sport ur ON ur.user_id = auth.uid()
            WHERE m.match_id = public.match_media.match_id
            AND ur.role_name = 'city_admin'
            AND ur.is_active = TRUE
            AND ur.city_id = t.city_id
            AND ur.sport_id = t.sport_id
        )
    );

-- =====================================================
-- STATISTICS POLICIES
-- =====================================================

-- Policy: Public can view all player statistics
CREATE POLICY "Public can view player statistics" ON public.player_statistics
    FOR SELECT TO anon, authenticated
    USING (TRUE);

-- Policy: Super admins can manage all player statistics
CREATE POLICY "Super admins can manage player statistics" ON public.player_statistics
    FOR ALL TO authenticated
    USING (public.is_super_admin(auth.uid()));

-- Policy: System can update player statistics (for automated calculations)
CREATE POLICY "System can update player statistics" ON public.player_statistics
    FOR INSERT TO authenticated
    WITH CHECK (TRUE);

CREATE POLICY "System can update existing player statistics" ON public.player_statistics
    FOR UPDATE TO authenticated
    USING (TRUE);

-- Policy: Players can view their own statistics
CREATE POLICY "Players can view own statistics" ON public.player_statistics
    FOR SELECT TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM public.players p
            WHERE p.player_id = public.player_statistics.player_id
            AND p.user_profile_id = auth.uid()
        )
    );

-- Policy: Team owners can view statistics of their players
CREATE POLICY "Team owners can view team player statistics" ON public.player_statistics
    FOR SELECT TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM public.teams t
            WHERE t.team_id = public.player_statistics.team_id
            AND t.owner_user_id = auth.uid()
        )
    );

-- Policy: Public can view all team statistics
CREATE POLICY "Public can view team statistics" ON public.team_statistics
    FOR SELECT TO anon, authenticated
    USING (TRUE);

-- Policy: Super admins can manage all team statistics
CREATE POLICY "Super admins can manage team statistics" ON public.team_statistics
    FOR ALL TO authenticated
    USING (public.is_super_admin(auth.uid()));

-- Policy: System can update team statistics (for automated calculations)
CREATE POLICY "System can update team statistics" ON public.team_statistics
    FOR INSERT TO authenticated
    WITH CHECK (TRUE);

CREATE POLICY "System can update existing team statistics" ON public.team_statistics
    FOR UPDATE TO authenticated
    USING (TRUE);

-- Policy: Team owners can view their team statistics
CREATE POLICY "Team owners can view own team statistics" ON public.team_statistics
    FOR SELECT TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM public.teams t
            WHERE t.team_id = public.team_statistics.team_id
            AND t.owner_user_id = auth.uid()
        )
    );

-- =====================================================
-- HELPER FUNCTIONS FOR MATCH ACCESS
-- =====================================================

-- Function to check if user can access match
CREATE OR REPLACE FUNCTION public.can_access_match(
    p_user_id UUID,
    p_match_id UUID
) RETURNS BOOLEAN AS $$
BEGIN
    -- Super admin can access all matches
    IF public.is_super_admin(p_user_id) THEN
        RETURN TRUE;
    END IF;
    
    -- Referees can access matches they are assigned to
    IF EXISTS (
        SELECT 1 FROM public.matches
        WHERE match_id = p_match_id
        AND (referee_user_id = p_user_id OR
             assistant_referee_1_id = p_user_id OR
             assistant_referee_2_id = p_user_id OR
             fourth_official_id = p_user_id)
    ) THEN
        RETURN TRUE;
    END IF;
    
    -- Tournament admin can access matches in their tournaments
    IF EXISTS (
        SELECT 1 FROM public.matches m
        JOIN public.tournaments t ON m.tournament_id = t.tournament_id
        WHERE m.match_id = p_match_id
        AND t.admin_user_id = p_user_id
    ) THEN
        RETURN TRUE;
    END IF;
    
    -- City admin can access matches in their jurisdiction
    IF EXISTS (
        SELECT 1 FROM public.matches m
        JOIN public.tournaments t ON m.tournament_id = t.tournament_id
        JOIN public.user_roles_by_city_sport ur ON ur.user_id = p_user_id
        WHERE m.match_id = p_match_id
        AND ur.role_name = 'city_admin'
        AND ur.is_active = TRUE
        AND ur.city_id = t.city_id
        AND ur.sport_id = t.sport_id
    ) THEN
        RETURN TRUE;
    END IF;
    
    -- Team owners can access matches involving their teams
    IF EXISTS (
        SELECT 1 FROM public.matches m
        JOIN public.teams t ON (t.team_id = m.home_team_id OR t.team_id = m.away_team_id)
        WHERE m.match_id = p_match_id
        AND t.owner_user_id = p_user_id
    ) THEN
        RETURN TRUE;
    END IF;
    
    -- Players can access matches they participate in
    IF EXISTS (
        SELECT 1 FROM public.matches m
        JOIN public.team_players tp ON (tp.team_id = m.home_team_id OR tp.team_id = m.away_team_id)
        JOIN public.players p ON tp.player_id = p.player_id
        WHERE m.match_id = p_match_id
        AND p.user_profile_id = p_user_id
        AND tp.is_active = TRUE
    ) THEN
        RETURN TRUE;
    END IF;
    
    -- Completed and live matches are accessible to everyone
    IF EXISTS (
        SELECT 1 FROM public.matches
        WHERE match_id = p_match_id
        AND status IN ('completed', 'live', 'half_time')
    ) THEN
        RETURN TRUE;
    END IF;
    
    RETURN FALSE;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to check if user can manage match
CREATE OR REPLACE FUNCTION public.can_manage_match(
    p_user_id UUID,
    p_match_id UUID
) RETURNS BOOLEAN AS $$
BEGIN
    -- Super admin can manage all matches
    IF public.is_super_admin(p_user_id) THEN
        RETURN TRUE;
    END IF;
    
    -- Referees can manage matches they are assigned to
    IF EXISTS (
        SELECT 1 FROM public.matches
        WHERE match_id = p_match_id
        AND (referee_user_id = p_user_id OR
             assistant_referee_1_id = p_user_id OR
             assistant_referee_2_id = p_user_id OR
             fourth_official_id = p_user_id)
    ) THEN
        RETURN TRUE;
    END IF;
    
    -- Tournament admin can manage matches in their tournaments
    IF EXISTS (
        SELECT 1 FROM public.matches m
        JOIN public.tournaments t ON m.tournament_id = t.tournament_id
        WHERE m.match_id = p_match_id
        AND t.admin_user_id = p_user_id
    ) THEN
        RETURN TRUE;
    END IF;
    
    -- City admin can manage matches in their jurisdiction
    IF EXISTS (
        SELECT 1 FROM public.matches m
        JOIN public.tournaments t ON m.tournament_id = t.tournament_id
        JOIN public.user_roles_by_city_sport ur ON ur.user_id = p_user_id
        WHERE m.match_id = p_match_id
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
COMMENT ON FUNCTION public.can_access_match IS 'Check if user can access a specific match';
COMMENT ON FUNCTION public.can_manage_match IS 'Check if user can manage a specific match';