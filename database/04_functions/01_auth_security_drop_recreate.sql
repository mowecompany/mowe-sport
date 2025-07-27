-- =====================================================
-- MOWE SPORT PLATFORM - DROP AND RECREATE SECURITY FUNCTIONS
-- =====================================================
-- Description: Drop and recreate security functions with correct signatures
-- =====================================================

-- Drop existing functions that need signature changes
DROP FUNCTION IF EXISTS public.get_user_security_events(UUID, INTEGER);
DROP FUNCTION IF EXISTS public.detect_suspicious_activity(INTERVAL);

-- Recreate with correct return types
CREATE OR REPLACE FUNCTION public.get_user_security_events(
    p_user_id UUID,
    p_limit INTEGER DEFAULT 50
) RETURNS TABLE (
    event_time TIMESTAMP WITH TIME ZONE,
    action TEXT,
    ip_address INET,
    user_agent TEXT,
    details JSONB
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        al.created_at,
        al.action,
        al.ip_address,
        al.user_agent,
        al.new_values
    FROM public.audit_logs al
    WHERE al.user_id = p_user_id
    AND al.action IN (
        'SUCCESSFUL_LOGIN',
        'FAILED_LOGIN',
        'PASSWORD_RESET_COMPLETED',
        'PASSWORD_RECOVERY_REQUESTED',
        '2FA_ENABLED',
        '2FA_DISABLED',
        '2FA_VERIFICATION_ATTEMPT',
        'ACCOUNT_LOCKED',
        'ACCOUNT_UNLOCKED'
    )
    ORDER BY al.created_at DESC
    LIMIT p_limit;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION public.detect_suspicious_activity(
    p_time_window INTERVAL DEFAULT INTERVAL '1 hour'
) RETURNS TABLE (
    user_id UUID,
    email TEXT,
    suspicious_events INTEGER,
    unique_ips INTEGER,
    failed_attempts INTEGER,
    last_event TIMESTAMP WITH TIME ZONE
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        up.user_id,
        up.email,
        COUNT(al.*)::INTEGER as suspicious_events,
        COUNT(DISTINCT al.ip_address)::INTEGER as unique_ips,
        COUNT(CASE WHEN al.action LIKE 'FAILED_%' THEN 1 END)::INTEGER as failed_attempts,
        MAX(al.created_at) as last_event
    FROM public.user_profiles up
    JOIN public.audit_logs al ON up.user_id = al.user_id
    WHERE al.created_at >= NOW() - p_time_window
    AND al.action IN (
        'FAILED_LOGIN',
        'FAILED_LOGIN_UNKNOWN_EMAIL',
        '2FA_VERIFICATION_ATTEMPT'
    )
    GROUP BY up.user_id, up.email
    HAVING COUNT(al.*) >= 5 OR COUNT(DISTINCT al.ip_address) >= 3
    ORDER BY suspicious_events DESC, last_event DESC;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Update other functions that had record_id issues
CREATE OR REPLACE FUNCTION public.record_failed_login_attempt_enhanced(
    p_user_id UUID,
    p_ip_address INET DEFAULT NULL,
    p_user_agent TEXT DEFAULT NULL
) RETURNS JSONB AS $$
DECLARE
    current_attempts INTEGER;
    lock_duration INTERVAL;
    lock_until TIMESTAMP;
    result JSONB;
BEGIN
    -- Get current failed attempts
    SELECT failed_login_attempts INTO current_attempts
    FROM public.user_profiles
    WHERE user_id = p_user_id;
    
    IF NOT FOUND THEN
        RETURN jsonb_build_object(
            'success', false,
            'message', 'User not found'
        );
    END IF;
    
    -- Increment failed attempts
    current_attempts := current_attempts + 1;
    
    -- Determine lock duration based on attempts
    IF current_attempts >= 10 THEN
        lock_duration := INTERVAL '24 hours'; -- 24 hour lock after 10 attempts
    ELSIF current_attempts >= 5 THEN
        lock_duration := INTERVAL '15 minutes'; -- 15 minute lock after 5 attempts
    ELSE
        lock_duration := NULL; -- No lock yet
    END IF;
    
    -- Calculate lock until time
    IF lock_duration IS NOT NULL THEN
        lock_until := NOW() + lock_duration;
    ELSE
        lock_until := NULL;
    END IF;
    
    -- Update user record
    UPDATE public.user_profiles
    SET 
        failed_login_attempts = current_attempts,
        locked_until = lock_until,
        updated_at = NOW()
    WHERE user_id = p_user_id;
    
    -- Log the failed attempt
    INSERT INTO public.audit_logs (
        user_id,
        action,
        table_name,
        record_id,
        new_values,
        ip_address,
        user_agent
    ) VALUES (
        p_user_id,
        'FAILED_LOGIN',
        'user_profiles',
        p_user_id,
        jsonb_build_object(
            'failed_attempts', current_attempts,
            'locked_until', lock_until,
            'lock_duration_seconds', EXTRACT(EPOCH FROM lock_duration)
        ),
        p_ip_address,
        p_user_agent
    );
    
    -- Return result
    result := jsonb_build_object(
        'success', true,
        'failed_attempts', current_attempts,
        'locked', lock_until IS NOT NULL,
        'locked_until', lock_until
    );
    
    IF lock_duration IS NOT NULL THEN
        result := result || jsonb_build_object(
            'lock_duration_minutes', EXTRACT(EPOCH FROM lock_duration) / 60
        );
    END IF;
    
    RETURN result;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION public.reset_failed_login_attempts_enhanced(
    p_user_id UUID,
    p_ip_address INET DEFAULT NULL,
    p_user_agent TEXT DEFAULT NULL
) RETURNS JSONB AS $$
DECLARE
    previous_attempts INTEGER;
BEGIN
    -- Get previous attempts count
    SELECT failed_login_attempts INTO previous_attempts
    FROM public.user_profiles
    WHERE user_id = p_user_id;
    
    IF NOT FOUND THEN
        RETURN jsonb_build_object(
            'success', false,
            'message', 'User not found'
        );
    END IF;
    
    -- Reset failed attempts and unlock account
    UPDATE public.user_profiles
    SET 
        failed_login_attempts = 0,
        locked_until = NULL,
        last_login_at = NOW(),
        updated_at = NOW()
    WHERE user_id = p_user_id;
    
    -- Log successful login if there were previous failed attempts
    IF previous_attempts > 0 THEN
        INSERT INTO public.audit_logs (
            user_id,
            action,
            table_name,
            record_id,
            new_values,
            ip_address,
            user_agent
        ) VALUES (
            p_user_id,
            'SUCCESSFUL_LOGIN_AFTER_FAILURES',
            'user_profiles',
            p_user_id,
            jsonb_build_object(
                'previous_failed_attempts', previous_attempts,
                'account_unlocked', true
            ),
            p_ip_address,
            p_user_agent
        );
    END IF;
    
    RETURN jsonb_build_object(
        'success', true,
        'previous_failed_attempts', previous_attempts,
        'account_unlocked', true
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;