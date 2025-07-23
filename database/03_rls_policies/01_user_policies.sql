-- =====================================================
-- MOWE SPORT PLATFORM - USER RLS POLICIES
-- =====================================================
-- Description: Row Level Security policies for user-related tables
-- Dependencies: Complete schema and indexes
-- Execution Order: After schema and indexes
-- =====================================================

-- =====================================================
-- ENABLE RLS ON USER TABLES
-- =====================================================

ALTER TABLE public.user_profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_roles_by_city_sport ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_view_permissions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.audit_logs ENABLE ROW LEVEL SECURITY;

-- =====================================================
-- USER PROFILES POLICIES
-- =====================================================

-- Policy: Users can view their own profile
CREATE POLICY "Users can view own profile" ON public.user_profiles
    FOR SELECT TO authenticated
    USING (auth.uid() = user_id);

-- Policy: Users can update their own profile (limited fields)
CREATE POLICY "Users can update own profile" ON public.user_profiles
    FOR UPDATE TO authenticated
    USING (auth.uid() = user_id)
    WITH CHECK (
        auth.uid() = user_id AND
        -- Prevent users from changing critical fields
        primary_role = (SELECT primary_role FROM public.user_profiles WHERE user_id = auth.uid()) AND
        account_status = (SELECT account_status FROM public.user_profiles WHERE user_id = auth.uid()) AND
        is_active = (SELECT is_active FROM public.user_profiles WHERE user_id = auth.uid())
    );

-- Policy: Super admins can view all profiles
CREATE POLICY "Super admins can view all profiles" ON public.user_profiles
    FOR SELECT TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM public.user_profiles 
            WHERE user_id = auth.uid() 
            AND primary_role = 'super_admin'
            AND is_active = TRUE
        )
    );

-- Policy: Super admins can manage all profiles
CREATE POLICY "Super admins can manage all profiles" ON public.user_profiles
    FOR ALL TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM public.user_profiles 
            WHERE user_id = auth.uid() 
            AND primary_role = 'super_admin'
            AND is_active = TRUE
        )
    );

-- Policy: City admins can view profiles in their jurisdiction
CREATE POLICY "City admins can view profiles in jurisdiction" ON public.user_profiles
    FOR SELECT TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM public.user_profiles up
            JOIN public.user_roles_by_city_sport ur ON up.user_id = ur.user_id
            WHERE up.user_id = auth.uid()
            AND up.primary_role = 'city_admin'
            AND up.is_active = TRUE
            AND ur.role_name = 'city_admin'
            AND ur.is_active = TRUE
            AND (
                -- Can see users in same city
                EXISTS (
                    SELECT 1 FROM public.user_roles_by_city_sport target_ur
                    WHERE target_ur.user_id = public.user_profiles.user_id
                    AND target_ur.city_id = ur.city_id
                    AND target_ur.is_active = TRUE
                )
                OR
                -- Can see their own profile
                public.user_profiles.user_id = auth.uid()
            )
        )
    );

-- Policy: City admins can manage users they can register
CREATE POLICY "City admins can manage registered users" ON public.user_profiles
    FOR ALL TO authenticated
    USING (
        -- City admins can manage owners, coaches, referees, players, clients in their city
        EXISTS (
            SELECT 1 FROM public.user_profiles admin_profile
            JOIN public.user_roles_by_city_sport admin_role ON admin_profile.user_id = admin_role.user_id
            WHERE admin_profile.user_id = auth.uid()
            AND admin_profile.primary_role = 'city_admin'
            AND admin_profile.is_active = TRUE
            AND admin_role.role_name = 'city_admin'
            AND admin_role.is_active = TRUE
            AND public.user_profiles.primary_role IN ('owner', 'coach', 'referee', 'player', 'client')
            AND EXISTS (
                SELECT 1 FROM public.user_roles_by_city_sport target_role
                WHERE target_role.user_id = public.user_profiles.user_id
                AND target_role.city_id = admin_role.city_id
                AND target_role.is_active = TRUE
            )
        )
    );

-- Policy: Owners can view players and coaches in their teams
CREATE POLICY "Owners can view team members" ON public.user_profiles
    FOR SELECT TO authenticated
    USING (
        public.user_profiles.primary_role IN ('player', 'coach') AND
        EXISTS (
            SELECT 1 FROM public.user_profiles owner_profile
            JOIN public.teams t ON owner_profile.user_id = t.owner_user_id
            JOIN public.team_players tp ON t.team_id = tp.team_id
            JOIN public.players p ON tp.player_id = p.player_id
            WHERE owner_profile.user_id = auth.uid()
            AND owner_profile.primary_role = 'owner'
            AND owner_profile.is_active = TRUE
            AND t.is_active = TRUE
            AND tp.is_active = TRUE
            AND (
                p.user_profile_id = public.user_profiles.user_id
                OR
                -- For coaches assigned to the team
                EXISTS (
                    SELECT 1 FROM public.user_roles_by_city_sport ur
                    WHERE ur.user_id = public.user_profiles.user_id
                    AND ur.role_name = 'coach'
                    AND ur.city_id = t.city_id
                    AND ur.sport_id = t.sport_id
                    AND ur.is_active = TRUE
                )
            )
        )
    );

-- =====================================================
-- USER ROLES BY CITY SPORT POLICIES
-- =====================================================

-- Policy: Users can view their own roles
CREATE POLICY "Users can view own roles" ON public.user_roles_by_city_sport
    FOR SELECT TO authenticated
    USING (user_id = auth.uid());

-- Policy: Super admins can manage all roles
CREATE POLICY "Super admins can manage all roles" ON public.user_roles_by_city_sport
    FOR ALL TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM public.user_profiles 
            WHERE user_id = auth.uid() 
            AND primary_role = 'super_admin'
            AND is_active = TRUE
        )
    );

-- Policy: City admins can view roles in their jurisdiction
CREATE POLICY "City admins can view roles in jurisdiction" ON public.user_roles_by_city_sport
    FOR SELECT TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM public.user_profiles up
            JOIN public.user_roles_by_city_sport admin_role ON up.user_id = admin_role.user_id
            WHERE up.user_id = auth.uid()
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
CREATE POLICY "City admins can manage jurisdiction roles" ON public.user_roles_by_city_sport
    FOR INSERT TO authenticated
    WITH CHECK (
        role_name IN ('owner', 'coach', 'referee', 'player', 'client') AND
        EXISTS (
            SELECT 1 FROM public.user_profiles up
            JOIN public.user_roles_by_city_sport admin_role ON up.user_id = admin_role.user_id
            WHERE up.user_id = auth.uid()
            AND up.primary_role = 'city_admin'
            AND up.is_active = TRUE
            AND admin_role.role_name = 'city_admin'
            AND admin_role.is_active = TRUE
            AND public.user_roles_by_city_sport.city_id = admin_role.city_id
        )
    );

-- Policy: City admins can update/delete roles they manage
CREATE POLICY "City admins can update managed roles" ON public.user_roles_by_city_sport
    FOR UPDATE TO authenticated
    USING (
        role_name IN ('owner', 'coach', 'referee', 'player', 'client') AND
        EXISTS (
            SELECT 1 FROM public.user_profiles up
            JOIN public.user_roles_by_city_sport admin_role ON up.user_id = admin_role.user_id
            WHERE up.user_id = auth.uid()
            AND up.primary_role = 'city_admin'
            AND up.is_active = TRUE
            AND admin_role.role_name = 'city_admin'
            AND admin_role.is_active = TRUE
            AND public.user_roles_by_city_sport.city_id = admin_role.city_id
        )
    );

-- Policy: Owners can manage roles for their team members
CREATE POLICY "Owners can manage team member roles" ON public.user_roles_by_city_sport
    FOR ALL TO authenticated
    USING (
        role_name IN ('player', 'coach') AND
        EXISTS (
            SELECT 1 FROM public.user_profiles owner_profile
            JOIN public.teams t ON owner_profile.user_id = t.owner_user_id
            WHERE owner_profile.user_id = auth.uid()
            AND owner_profile.primary_role = 'owner'
            AND owner_profile.is_active = TRUE
            AND t.is_active = TRUE
            AND public.user_roles_by_city_sport.city_id = t.city_id
            AND public.user_roles_by_city_sport.sport_id = t.sport_id
        )
    );

-- =====================================================
-- USER VIEW PERMISSIONS POLICIES
-- =====================================================

-- Policy: Super admins can manage all view permissions
CREATE POLICY "Super admins can manage all view permissions" ON public.user_view_permissions
    FOR ALL TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM public.user_profiles 
            WHERE user_id = auth.uid() 
            AND primary_role = 'super_admin'
            AND is_active = TRUE
        )
    );

-- Policy: Users can view permissions that affect them
CREATE POLICY "Users can view relevant permissions" ON public.user_view_permissions
    FOR SELECT TO authenticated
    USING (
        user_id = auth.uid() OR
        (
            role_name IS NOT NULL AND
            EXISTS (
                SELECT 1 FROM public.user_profiles
                WHERE user_id = auth.uid()
                AND primary_role = public.user_view_permissions.role_name
            )
        )
    );

-- Policy: City admins can view permissions in their jurisdiction
CREATE POLICY "City admins can view jurisdiction permissions" ON public.user_view_permissions
    FOR SELECT TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM public.user_profiles up
            WHERE up.user_id = auth.uid()
            AND up.primary_role = 'city_admin'
            AND up.is_active = TRUE
            AND (
                public.user_view_permissions.user_id IN (
                    SELECT ur.user_id FROM public.user_roles_by_city_sport ur
                    JOIN public.user_roles_by_city_sport admin_ur ON admin_ur.user_id = auth.uid()
                    WHERE ur.city_id = admin_ur.city_id
                    AND admin_ur.role_name = 'city_admin'
                    AND admin_ur.is_active = TRUE
                )
                OR
                public.user_view_permissions.role_name IN ('owner', 'coach', 'referee', 'player', 'client')
            )
        )
    );

-- =====================================================
-- AUDIT LOGS POLICIES
-- =====================================================

-- Policy: Super admins can view all audit logs
CREATE POLICY "Super admins can view all audit logs" ON public.audit_logs
    FOR SELECT TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM public.user_profiles 
            WHERE user_id = auth.uid() 
            AND primary_role = 'super_admin'
            AND is_active = TRUE
        )
    );

-- Policy: City admins can view audit logs for their jurisdiction
CREATE POLICY "City admins can view jurisdiction audit logs" ON public.audit_logs
    FOR SELECT TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM public.user_profiles up
            JOIN public.user_roles_by_city_sport ur ON up.user_id = ur.user_id
            WHERE up.user_id = auth.uid()
            AND up.primary_role = 'city_admin'
            AND up.is_active = TRUE
            AND ur.role_name = 'city_admin'
            AND ur.is_active = TRUE
            AND (
                public.audit_logs.user_id IN (
                    SELECT target_ur.user_id 
                    FROM public.user_roles_by_city_sport target_ur
                    WHERE target_ur.city_id = ur.city_id
                    AND target_ur.is_active = TRUE
                )
                OR public.audit_logs.user_id = auth.uid()
            )
        )
    );

-- Policy: Users can view their own audit logs
CREATE POLICY "Users can view own audit logs" ON public.audit_logs
    FOR SELECT TO authenticated
    USING (user_id = auth.uid());

-- Policy: System can insert audit logs
CREATE POLICY "System can insert audit logs" ON public.audit_logs
    FOR INSERT TO authenticated
    WITH CHECK (true); -- Allow all authenticated users to create audit logs

-- =====================================================
-- CITIES AND SPORTS POLICIES (Public Read)
-- =====================================================

-- Enable RLS on cities and sports
ALTER TABLE public.cities ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.sports ENABLE ROW LEVEL SECURITY;

-- Policy: Everyone can view active cities
CREATE POLICY "Everyone can view active cities" ON public.cities
    FOR SELECT TO anon, authenticated
    USING (is_active = TRUE);

-- Policy: Super admins can manage cities
CREATE POLICY "Super admins can manage cities" ON public.cities
    FOR ALL TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM public.user_profiles 
            WHERE user_id = auth.uid() 
            AND primary_role = 'super_admin'
            AND is_active = TRUE
        )
    );

-- Policy: Everyone can view active sports
CREATE POLICY "Everyone can view active sports" ON public.sports
    FOR SELECT TO anon, authenticated
    USING (is_active = TRUE);

-- Policy: Super admins can manage sports
CREATE POLICY "Super admins can manage sports" ON public.sports
    FOR ALL TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM public.user_profiles 
            WHERE user_id = auth.uid() 
            AND primary_role = 'super_admin'
            AND is_active = TRUE
        )
    );

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

-- Add comments for functions
COMMENT ON FUNCTION public.user_has_role_in_city_sport IS 'Check if user has specific role in city/sport';
COMMENT ON FUNCTION public.is_super_admin IS 'Check if user is an active super admin';
COMMENT ON FUNCTION public.get_user_cities IS 'Get array of city IDs user has access to';
COMMENT ON FUNCTION public.get_user_sports IS 'Get array of sport IDs user has access to';