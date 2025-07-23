-- =====================================================
-- MOWE SPORT PLATFORM - AUTHENTICATION FUNCTIONS
-- =====================================================
-- Description: Helper functions for authentication and user management
-- Dependencies: Core schema tables
-- Execution Order: After RLS policies
-- =====================================================

-- =====================================================
-- USER AUTHENTICATION FUNCTIONS
-- =====================================================

-- Function to handle user registration
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
    -- Insert user profile when new user is created in auth.users
    INSERT INTO public.user_profiles (
        user_id,
        email,
        first_name,
        last_name,
        primary_role,
        is_active,
        account_status
    ) VALUES (
        NEW.id,
        NEW.email,
        COALESCE(NEW.raw_user_meta_data->>'first_name', 'User'),
        COALESCE(NEW.raw_user_meta_data->>'last_name', 'Name'),
        COALESCE(NEW.raw_user_meta_data->>'role', 'client'),
        TRUE,
        'active'
    );
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Trigger for new user registration
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- =====================================================
-- LOGIN ATTEMPT TRACKING FUNCTIONS
-- =====================================================

-- Function to record failed login attempt
CREATE OR REPLACE FUNCTION public.record_failed_login_attempt(
    p_user_id UUID,
    p_ip_address INET DEFAULT NULL,
    p_user_agent TEXT DEFAULT NULL
) RETURNS VOID AS $$
DECLARE
    v_attempts INTEGER;
    v_lock_duration INTERVAL;
BEGIN
    -- Get current failed attempts
    SELECT failed_login_attempts INTO v_attempts
    FROM public.user_profiles
    WHERE user_id = p_user_id;
    
    -- Increment failed attempts
    v_attempts := COALESCE(v_attempts, 0) + 1;
    
    -- Determine lock duration based on attempts
    IF v_attempts >= 10 THEN
        v_lock_duration := INTERVAL '24 hours';
    ELSIF v_attempts >= 5 THEN
        v_lock_duration := INTERVAL '15 minutes';
    ELSE
        v_lock_duration := NULL;
    END IF;
    
    -- Update user profile
    UPDATE public.user_profiles
    SET 
        failed_login_attempts = v_attempts,
        locked_until = CASE 
            WHEN v_lock_duration IS NOT NULL 
            THEN NOW() + v_lock_duration 
            ELSE locked_until 
        END,
        updated_at = NOW()
    WHERE user_id = p_user_id;
    
    -- Log the failed attempt
    INSERT INTO public.audit_logs (
        user_id,
        action,
        table_name,
        new_values,
        ip_address,
        user_agent
    ) VALUES (
        p_user_id,
        'FAILED_LOGIN',
        'user_profiles',
        json_build_object(
            'failed_attempts', v_attempts,
            'locked_until', CASE WHEN v_lock_duration IS NOT NULL THEN NOW() + v_lock_duration ELSE NULL END
        ),
        p_ip_address,
        p_user_agent
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to record successful login
CREATE OR REPLACE FUNCTION public.record_successful_login(
    p_user_id UUID,
    p_ip_address INET DEFAULT NULL,
    p_user_agent TEXT DEFAULT NULL
) RETURNS VOID AS $$
BEGIN
    -- Reset failed attempts and update last login
    UPDATE public.user_profiles
    SET 
        failed_login_attempts = 0,
        locked_until = NULL,
        last_login_at = NOW(),
        updated_at = NOW()
    WHERE user_id = p_user_id;
    
    -- Log the successful login
    INSERT INTO public.audit_logs (
        user_id,
        action,
        table_name,
        new_values,
        ip_address,
        user_agent
    ) VALUES (
        p_user_id,
        'SUCCESSFUL_LOGIN',
        'user_profiles',
        json_build_object(
            'last_login_at', NOW(),
            'failed_attempts_reset', true
        ),
        p_ip_address,
        p_user_agent
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to check if user account is locked
CREATE OR REPLACE FUNCTION public.is_account_locked(p_user_id UUID)
RETURNS BOOLEAN AS $$
DECLARE
    v_locked_until TIMESTAMP WITH TIME ZONE;
    v_account_status VARCHAR(20);
    v_is_active BOOLEAN;
BEGIN
    SELECT locked_until, account_status, is_active
    INTO v_locked_until, v_account_status, v_is_active
    FROM public.user_profiles
    WHERE user_id = p_user_id;
    
    -- Check if account is inactive
    IF NOT v_is_active THEN
        RETURN TRUE;
    END IF;
    
    -- Check account status
    IF v_account_status IN ('suspended', 'disabled') THEN
        RETURN TRUE;
    END IF;
    
    -- Check if temporarily locked
    IF v_locked_until IS NOT NULL AND v_locked_until > NOW() THEN
        RETURN TRUE;
    END IF;
    
    RETURN FALSE;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- =====================================================
-- USER ROLE MANAGEMENT FUNCTIONS
-- =====================================================

-- Function to assign role to user
CREATE OR REPLACE FUNCTION public.assign_user_role(
    p_user_id UUID,
    p_city_id UUID,
    p_sport_id UUID,
    p_role_name VARCHAR(20),
    p_assigned_by_user_id UUID
) RETURNS BOOLEAN AS $$
BEGIN
    -- Check if assigner has permission
    IF NOT (
        public.is_super_admin(p_assigned_by_user_id) OR
        (p_role_name IN ('owner', 'coach', 'referee', 'player', 'client') AND
         public.user_has_role_in_city_sport(p_assigned_by_user_id, 'city_admin', p_city_id, p_sport_id))
    ) THEN
        RAISE EXCEPTION 'Insufficient permissions to assign role';
    END IF;
    
    -- Insert role assignment
    INSERT INTO public.user_roles_by_city_sport (
        user_id,
        city_id,
        sport_id,
        role_name,
        assigned_by_user_id,
        is_active
    ) VALUES (
        p_user_id,
        p_city_id,
        p_sport_id,
        p_role_name,
        p_assigned_by_user_id,
        TRUE
    ) ON CONFLICT (user_id, city_id, sport_id, role_name) 
    DO UPDATE SET
        is_active = TRUE,
        assigned_by_user_id = p_assigned_by_user_id;
    
    -- Log the role assignment
    INSERT INTO public.audit_logs (
        user_id,
        action,
        table_name,
        record_id,
        new_values
    ) VALUES (
        p_assigned_by_user_id,
        'ROLE_ASSIGNED',
        'user_roles_by_city_sport',
        p_user_id,
        json_build_object(
            'target_user_id', p_user_id,
            'city_id', p_city_id,
            'sport_id', p_sport_id,
            'role_name', p_role_name
        )
    );
    
    RETURN TRUE;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to revoke role from user
CREATE OR REPLACE FUNCTION public.revoke_user_role(
    p_user_id UUID,
    p_city_id UUID,
    p_sport_id UUID,
    p_role_name VARCHAR(20),
    p_revoked_by_user_id UUID
) RETURNS BOOLEAN AS $$
BEGIN
    -- Check if revoker has permission
    IF NOT (
        public.is_super_admin(p_revoked_by_user_id) OR
        (p_role_name IN ('owner', 'coach', 'referee', 'player', 'client') AND
         public.user_has_role_in_city_sport(p_revoked_by_user_id, 'city_admin', p_city_id, p_sport_id))
    ) THEN
        RAISE EXCEPTION 'Insufficient permissions to revoke role';
    END IF;
    
    -- Deactivate role assignment
    UPDATE public.user_roles_by_city_sport
    SET is_active = FALSE
    WHERE user_id = p_user_id
    AND city_id = p_city_id
    AND sport_id = p_sport_id
    AND role_name = p_role_name;
    
    -- Log the role revocation
    INSERT INTO public.audit_logs (
        user_id,
        action,
        table_name,
        record_id,
        new_values
    ) VALUES (
        p_revoked_by_user_id,
        'ROLE_REVOKED',
        'user_roles_by_city_sport',
        p_user_id,
        json_build_object(
            'target_user_id', p_user_id,
            'city_id', p_city_id,
            'sport_id', p_sport_id,
            'role_name', p_role_name
        )
    );
    
    RETURN TRUE;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- =====================================================
-- ACCOUNT MANAGEMENT FUNCTIONS
-- =====================================================

-- Function to update account status
CREATE OR REPLACE FUNCTION public.update_account_status(
    p_user_id UUID,
    p_new_status VARCHAR(20),
    p_updated_by_user_id UUID,
    p_reason TEXT DEFAULT NULL
) RETURNS BOOLEAN AS $$
DECLARE
    v_old_status VARCHAR(20);
BEGIN
    -- Check if updater has permission (only super admin can change account status)
    IF NOT public.is_super_admin(p_updated_by_user_id) THEN
        RAISE EXCEPTION 'Insufficient permissions to update account status';
    END IF;
    
    -- Get current status
    SELECT account_status INTO v_old_status
    FROM public.user_profiles
    WHERE user_id = p_user_id;
    
    -- Update account status
    UPDATE public.user_profiles
    SET 
        account_status = p_new_status,
        updated_at = NOW()
    WHERE user_id = p_user_id;
    
    -- Log the status change
    INSERT INTO public.audit_logs (
        user_id,
        action,
        table_name,
        record_id,
        old_values,
        new_values
    ) VALUES (
        p_updated_by_user_id,
        'ACCOUNT_STATUS_CHANGED',
        'user_profiles',
        p_user_id,
        json_build_object('account_status', v_old_status),
        json_build_object(
            'account_status', p_new_status,
            'reason', p_reason
        )
    );
    
    RETURN TRUE;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to activate/deactivate user account
CREATE OR REPLACE FUNCTION public.set_account_active(
    p_user_id UUID,
    p_is_active BOOLEAN,
    p_updated_by_user_id UUID,
    p_reason TEXT DEFAULT NULL
) RETURNS BOOLEAN AS $$
DECLARE
    v_old_active BOOLEAN;
BEGIN
    -- Check if updater has permission
    IF NOT public.is_super_admin(p_updated_by_user_id) THEN
        RAISE EXCEPTION 'Insufficient permissions to activate/deactivate account';
    END IF;
    
    -- Get current status
    SELECT is_active INTO v_old_active
    FROM public.user_profiles
    WHERE user_id = p_user_id;
    
    -- Update active status
    UPDATE public.user_profiles
    SET 
        is_active = p_is_active,
        updated_at = NOW()
    WHERE user_id = p_user_id;
    
    -- Log the change
    INSERT INTO public.audit_logs (
        user_id,
        action,
        table_name,
        record_id,
        old_values,
        new_values
    ) VALUES (
        p_updated_by_user_id,
        CASE WHEN p_is_active THEN 'ACCOUNT_ACTIVATED' ELSE 'ACCOUNT_DEACTIVATED' END,
        'user_profiles',
        p_user_id,
        json_build_object('is_active', v_old_active),
        json_build_object(
            'is_active', p_is_active,
            'reason', p_reason
        )
    );
    
    RETURN TRUE;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- =====================================================
-- VIEW PERMISSION FUNCTIONS
-- =====================================================

-- Function to check if user has view permission
CREATE OR REPLACE FUNCTION public.has_view_permission(
    p_user_id UUID,
    p_view_name VARCHAR(100)
) RETURNS BOOLEAN AS $$
DECLARE
    v_user_role VARCHAR(20);
    v_permission_exists BOOLEAN;
    v_is_allowed BOOLEAN;
BEGIN
    -- Get user's primary role
    SELECT primary_role INTO v_user_role
    FROM public.user_profiles
    WHERE user_id = p_user_id;
    
    -- Super admin has access to all views
    IF v_user_role = 'super_admin' THEN
        RETURN TRUE;
    END IF;
    
    -- Check for user-specific permission
    SELECT EXISTS(
        SELECT 1 FROM public.user_view_permissions
        WHERE user_id = p_user_id
        AND view_name = p_view_name
    ), COALESCE(
        (SELECT is_allowed FROM public.user_view_permissions
         WHERE user_id = p_user_id AND view_name = p_view_name
         LIMIT 1), TRUE
    ) INTO v_permission_exists, v_is_allowed;
    
    -- If user-specific permission exists, use it
    IF v_permission_exists THEN
        RETURN v_is_allowed;
    END IF;
    
    -- Check for role-based permission
    SELECT EXISTS(
        SELECT 1 FROM public.user_view_permissions
        WHERE role_name = v_user_role
        AND view_name = p_view_name
    ), COALESCE(
        (SELECT is_allowed FROM public.user_view_permissions
         WHERE role_name = v_user_role AND view_name = p_view_name
         LIMIT 1), TRUE
    ) INTO v_permission_exists, v_is_allowed;
    
    -- If role-based permission exists, use it
    IF v_permission_exists THEN
        RETURN v_is_allowed;
    END IF;
    
    -- Default: allow access if no specific restriction
    RETURN TRUE;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to set view permission
CREATE OR REPLACE FUNCTION public.set_view_permission(
    p_view_name VARCHAR(100),
    p_is_allowed BOOLEAN,
    p_configured_by_user_id UUID,
    p_target_user_id UUID DEFAULT NULL,
    p_target_role VARCHAR(20) DEFAULT NULL
) RETURNS BOOLEAN AS $$
BEGIN
    -- Check if configurator has permission (only super admin)
    IF NOT public.is_super_admin(p_configured_by_user_id) THEN
        RAISE EXCEPTION 'Insufficient permissions to configure view permissions';
    END IF;
    
    -- Validate parameters
    IF (p_target_user_id IS NULL AND p_target_role IS NULL) OR 
       (p_target_user_id IS NOT NULL AND p_target_role IS NOT NULL) THEN
        RAISE EXCEPTION 'Must specify either target_user_id or target_role, but not both';
    END IF;
    
    -- Insert or update permission
    INSERT INTO public.user_view_permissions (
        user_id,
        role_name,
        view_name,
        is_allowed,
        configured_by_user_id
    ) VALUES (
        p_target_user_id,
        p_target_role,
        p_view_name,
        p_is_allowed,
        p_configured_by_user_id
    ) ON CONFLICT (COALESCE(user_id, '00000000-0000-0000-0000-000000000000'::UUID), 
                   COALESCE(role_name, ''), view_name)
    DO UPDATE SET
        is_allowed = p_is_allowed,
        configured_by_user_id = p_configured_by_user_id,
        updated_at = NOW();
    
    -- Log the permission change
    INSERT INTO public.audit_logs (
        user_id,
        action,
        table_name,
        new_values
    ) VALUES (
        p_configured_by_user_id,
        'VIEW_PERMISSION_SET',
        'user_view_permissions',
        json_build_object(
            'target_user_id', p_target_user_id,
            'target_role', p_target_role,
            'view_name', p_view_name,
            'is_allowed', p_is_allowed
        )
    );
    
    RETURN TRUE;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- =====================================================
-- FUNCTION COMMENTS
-- =====================================================

COMMENT ON FUNCTION public.handle_new_user() IS 'Automatically creates user profile when new user registers';
COMMENT ON FUNCTION public.record_failed_login_attempt(UUID, INET, TEXT) IS 'Records failed login attempt and applies account locking if needed';
COMMENT ON FUNCTION public.record_successful_login(UUID, INET, TEXT) IS 'Records successful login and resets failed attempt counter';
COMMENT ON FUNCTION public.is_account_locked(UUID) IS 'Checks if user account is locked or suspended';
COMMENT ON FUNCTION public.assign_user_role(UUID, UUID, UUID, VARCHAR, UUID) IS 'Assigns role to user with permission checking';
COMMENT ON FUNCTION public.revoke_user_role(UUID, UUID, UUID, VARCHAR, UUID) IS 'Revokes role from user with permission checking';
COMMENT ON FUNCTION public.update_account_status(UUID, VARCHAR, UUID, TEXT) IS 'Updates user account status (super admin only)';
COMMENT ON FUNCTION public.set_account_active(UUID, BOOLEAN, UUID, TEXT) IS 'Activates or deactivates user account (super admin only)';
COMMENT ON FUNCTION public.has_view_permission(UUID, VARCHAR) IS 'Checks if user has permission to access specific view';
COMMENT ON FUNCTION public.set_view_permission(UUID, VARCHAR, VARCHAR, BOOLEAN, UUID) IS 'Sets view permission for user or role (super admin only)';