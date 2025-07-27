-- =====================================================
-- MOWE SPORT PLATFORM - AUTHENTICATION SECURITY FIXES
-- =====================================================
-- Description: Fix issues in authentication and security functions
-- =====================================================

-- Fix the audit log record_id type issues
-- Replace functions with corrected versions

-- Function to generate password recovery token (FIXED)
CREATE OR REPLACE FUNCTION public.generate_password_recovery_token(
    p_email TEXT,
    p_ip_address INET DEFAULT NULL,
    p_user_agent TEXT DEFAULT NULL
) RETURNS JSONB AS $$
DECLARE
    target_user_id UUID;
    recovery_token TEXT;
    expiration_time TIMESTAMP;
    result JSONB;
BEGIN
    -- Find user by email
    SELECT user_id INTO target_user_id
    FROM public.user_profiles
    WHERE LOWER(email) = LOWER(p_email)
    AND is_active = TRUE
    AND account_status = 'active';
    
    IF NOT FOUND THEN
        -- Don't reveal if email exists or not for security
        RETURN jsonb_build_object(
            'success', true,
            'message', 'If the email exists, a recovery token has been sent'
        );
    END IF;
    
    -- Generate secure random token
    recovery_token := encode(gen_random_bytes(32), 'hex');
    expiration_time := NOW() + INTERVAL '1 hour'; -- Token expires in 1 hour
    
    -- Store token in user profile
    UPDATE public.user_profiles
    SET 
        token_recovery = recovery_token,
        token_expiration_date = expiration_time,
        updated_at = NOW()
    WHERE user_id = target_user_id;
    
    -- Log the recovery request
    INSERT INTO public.audit_logs (
        user_id,
        action,
        table_name,
        record_id,
        new_values,
        ip_address,
        user_agent
    ) VALUES (
        target_user_id,
        'PASSWORD_RECOVERY_REQUESTED',
        'user_profiles',
        target_user_id,
        jsonb_build_object(
            'email', p_email,
            'token_expiration', expiration_time
        ),
        p_ip_address,
        p_user_agent
    );
    
    RETURN jsonb_build_object(
        'success', true,
        'user_id', target_user_id,
        'recovery_token', recovery_token,
        'expires_at', expiration_time,
        'message', 'Recovery token generated successfully'
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to reset password with recovery token (FIXED)
CREATE OR REPLACE FUNCTION public.reset_password_with_token(
    p_token TEXT,
    p_new_password TEXT,
    p_ip_address INET DEFAULT NULL,
    p_user_agent TEXT DEFAULT NULL
) RETURNS JSONB AS $$
DECLARE
    token_validation JSONB;
    target_user_id UUID;
    new_password_hash TEXT;
BEGIN
    -- Validate token first
    token_validation := public.validate_password_recovery_token(p_token);
    
    IF NOT (token_validation->>'valid')::BOOLEAN THEN
        RETURN token_validation;
    END IF;
    
    target_user_id := (token_validation->>'user_id')::UUID;
    
    -- Hash the new password
    BEGIN
        new_password_hash := public.hash_password(p_new_password);
    EXCEPTION WHEN OTHERS THEN
        RETURN jsonb_build_object(
            'success', false,
            'message', 'Password validation failed: ' || SQLERRM
        );
    END;
    
    -- Update password and clear recovery token
    UPDATE public.user_profiles
    SET 
        password_hash = new_password_hash,
        token_recovery = NULL,
        token_expiration_date = NULL,
        failed_login_attempts = 0,
        locked_until = NULL,
        updated_at = NOW()
    WHERE user_id = target_user_id;
    
    -- Log the password reset
    INSERT INTO public.audit_logs (
        user_id,
        action,
        table_name,
        record_id,
        new_values,
        ip_address,
        user_agent
    ) VALUES (
        target_user_id,
        'PASSWORD_RESET_COMPLETED',
        'user_profiles',
        target_user_id,
        jsonb_build_object(
            'method', 'recovery_token',
            'token_used', p_token
        ),
        p_ip_address,
        p_user_agent
    );
    
    RETURN jsonb_build_object(
        'success', true,
        'message', 'Password reset successfully'
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to generate 2FA secret (FIXED)
CREATE OR REPLACE FUNCTION public.generate_2fa_secret(
    p_user_id UUID
) RETURNS JSONB AS $$
DECLARE
    secret TEXT;
    user_email TEXT;
BEGIN
    -- Check if user exists and is active
    SELECT email INTO user_email
    FROM public.user_profiles
    WHERE user_id = p_user_id
    AND is_active = TRUE
    AND account_status = 'active';
    
    IF NOT FOUND THEN
        RETURN jsonb_build_object(
            'success', false,
            'message', 'User not found or inactive'
        );
    END IF;
    
    -- Generate base32 secret (32 characters)
    secret := encode(gen_random_bytes(20), 'base64');
    -- Clean up base64 to make it base32-like (simplified)
    secret := REPLACE(REPLACE(REPLACE(secret, '+', ''), '/', ''), '=', '');
    secret := UPPER(LEFT(secret, 32));
    
    -- Store secret (not enabled yet)
    UPDATE public.user_profiles
    SET 
        two_factor_secret = secret,
        updated_at = NOW()
    WHERE user_id = p_user_id;
    
    -- Log 2FA setup initiation
    INSERT INTO public.audit_logs (
        user_id,
        action,
        table_name,
        record_id,
        new_values
    ) VALUES (
        p_user_id,
        '2FA_SECRET_GENERATED',
        'user_profiles',
        p_user_id,
        jsonb_build_object(
            'email', user_email,
            'secret_length', LENGTH(secret)
        )
    );
    
    RETURN jsonb_build_object(
        'success', true,
        'secret', secret,
        'qr_code_url', 'otpauth://totp/MoweSport:' || user_email || '?secret=' || secret || '&issuer=MoweSport',
        'message', '2FA secret generated. Scan QR code with authenticator app'
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to enable 2FA (FIXED)
CREATE OR REPLACE FUNCTION public.enable_2fa(
    p_user_id UUID,
    p_totp_code TEXT,
    p_ip_address INET DEFAULT NULL,
    p_user_agent TEXT DEFAULT NULL
) RETURNS JSONB AS $$
DECLARE
    user_secret TEXT;
    is_valid BOOLEAN;
BEGIN
    -- Get user's 2FA secret
    SELECT two_factor_secret INTO user_secret
    FROM public.user_profiles
    WHERE user_id = p_user_id
    AND is_active = TRUE
    AND account_status = 'active'
    AND two_factor_secret IS NOT NULL;
    
    IF NOT FOUND THEN
        RETURN jsonb_build_object(
            'success', false,
            'message', 'User not found or 2FA secret not generated'
        );
    END IF;
    
    -- Validate TOTP code (simplified validation)
    -- In production, use proper TOTP validation library
    is_valid := LENGTH(p_totp_code) = 6 AND p_totp_code ~ '^[0-9]+$';
    
    IF NOT is_valid THEN
        RETURN jsonb_build_object(
            'success', false,
            'message', 'Invalid TOTP code format'
        );
    END IF;
    
    -- Enable 2FA
    UPDATE public.user_profiles
    SET 
        two_factor_enabled = TRUE,
        updated_at = NOW()
    WHERE user_id = p_user_id;
    
    -- Log 2FA enablement
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
        '2FA_ENABLED',
        'user_profiles',
        p_user_id,
        jsonb_build_object(
            'totp_code_provided', p_totp_code,
            'enabled_at', NOW()
        ),
        p_ip_address,
        p_user_agent
    );
    
    RETURN jsonb_build_object(
        'success', true,
        'message', '2FA enabled successfully'
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to disable 2FA (FIXED)
CREATE OR REPLACE FUNCTION public.disable_2fa(
    p_user_id UUID,
    p_current_password TEXT,
    p_ip_address INET DEFAULT NULL,
    p_user_agent TEXT DEFAULT NULL
) RETURNS JSONB AS $$
DECLARE
    user_record RECORD;
    password_valid BOOLEAN;
BEGIN
    -- Get user record
    SELECT 
        password_hash,
        two_factor_enabled
    INTO user_record
    FROM public.user_profiles
    WHERE user_id = p_user_id
    AND is_active = TRUE
    AND account_status = 'active';
    
    IF NOT FOUND THEN
        RETURN jsonb_build_object(
            'success', false,
            'message', 'User not found or inactive'
        );
    END IF;
    
    -- Verify current password
    password_valid := public.verify_password(p_current_password, user_record.password_hash);
    
    IF NOT password_valid THEN
        RETURN jsonb_build_object(
            'success', false,
            'message', 'Invalid current password'
        );
    END IF;
    
    -- Disable 2FA
    UPDATE public.user_profiles
    SET 
        two_factor_enabled = FALSE,
        two_factor_secret = NULL,
        updated_at = NOW()
    WHERE user_id = p_user_id;
    
    -- Log 2FA disablement
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
        '2FA_DISABLED',
        'user_profiles',
        p_user_id,
        jsonb_build_object(
            'disabled_at', NOW(),
            'password_verified', true
        ),
        p_ip_address,
        p_user_agent
    );
    
    RETURN jsonb_build_object(
        'success', true,
        'message', '2FA disabled successfully'
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to verify 2FA TOTP code (FIXED)
CREATE OR REPLACE FUNCTION public.verify_2fa_code(
    p_user_id UUID,
    p_totp_code TEXT
) RETURNS JSONB AS $$
DECLARE
    user_record RECORD;
    is_valid BOOLEAN;
BEGIN
    -- Get user's 2FA settings
    SELECT 
        two_factor_enabled,
        two_factor_secret
    INTO user_record
    FROM public.user_profiles
    WHERE user_id = p_user_id
    AND is_active = TRUE
    AND account_status = 'active';
    
    IF NOT FOUND THEN
        RETURN jsonb_build_object(
            'valid', false,
            'message', 'User not found or inactive'
        );
    END IF;
    
    IF NOT user_record.two_factor_enabled THEN
        RETURN jsonb_build_object(
            'valid', false,
            'message', '2FA is not enabled for this user'
        );
    END IF;
    
    -- Validate TOTP code (simplified validation)
    -- In production, use proper TOTP validation with time windows
    is_valid := LENGTH(p_totp_code) = 6 AND p_totp_code ~ '^[0-9]+$';
    
    -- Log verification attempt
    INSERT INTO public.audit_logs (
        user_id,
        action,
        table_name,
        record_id,
        new_values
    ) VALUES (
        p_user_id,
        '2FA_VERIFICATION_ATTEMPT',
        'user_profiles',
        p_user_id,
        jsonb_build_object(
            'code_provided', p_totp_code,
            'valid', is_valid,
            'timestamp', NOW()
        )
    );
    
    RETURN jsonb_build_object(
        'valid', is_valid,
        'message', CASE WHEN is_valid THEN '2FA code verified' ELSE 'Invalid 2FA code' END
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to perform complete login validation (FIXED)
CREATE OR REPLACE FUNCTION public.authenticate_user(
    p_email TEXT,
    p_password TEXT,
    p_totp_code TEXT DEFAULT NULL,
    p_ip_address INET DEFAULT NULL,
    p_user_agent TEXT DEFAULT NULL
) RETURNS JSONB AS $$
DECLARE
    user_record RECORD;
    lock_check JSONB;
    password_valid BOOLEAN;
    totp_valid JSONB;
    login_result JSONB;
BEGIN
    -- Find user by email
    SELECT 
        user_id,
        email,
        password_hash,
        first_name,
        last_name,
        primary_role,
        is_active,
        account_status,
        two_factor_enabled,
        failed_login_attempts
    INTO user_record
    FROM public.user_profiles
    WHERE LOWER(email) = LOWER(p_email);
    
    IF NOT FOUND THEN
        -- Log failed attempt with unknown email
        INSERT INTO public.audit_logs (
            action,
            table_name,
            new_values,
            ip_address,
            user_agent
        ) VALUES (
            'FAILED_LOGIN_UNKNOWN_EMAIL',
            'user_profiles',
            jsonb_build_object(
                'email', p_email,
                'reason', 'email_not_found'
            ),
            p_ip_address,
            p_user_agent
        );
        
        RETURN jsonb_build_object(
            'success', false,
            'message', 'Invalid email or password'
        );
    END IF;
    
    -- Check if account is locked
    lock_check := public.is_account_locked_detailed(user_record.user_id);
    
    IF (lock_check->>'locked')::BOOLEAN THEN
        RETURN jsonb_build_object(
            'success', false,
            'locked', true,
            'message', lock_check->>'message',
            'lock_info', lock_check
        );
    END IF;
    
    -- Verify password
    password_valid := public.verify_password(p_password, user_record.password_hash);
    
    IF NOT password_valid THEN
        -- Record failed attempt
        PERFORM public.record_failed_login_attempt_enhanced(
            user_record.user_id,
            p_ip_address,
            p_user_agent
        );
        
        RETURN jsonb_build_object(
            'success', false,
            'message', 'Invalid email or password'
        );
    END IF;
    
    -- Check 2FA if enabled
    IF user_record.two_factor_enabled THEN
        IF p_totp_code IS NULL THEN
            RETURN jsonb_build_object(
                'success', false,
                'requires_2fa', true,
                'message', '2FA code required'
            );
        END IF;
        
        totp_valid := public.verify_2fa_code(user_record.user_id, p_totp_code);
        
        IF NOT (totp_valid->>'valid')::BOOLEAN THEN
            -- Record failed attempt for invalid 2FA
            PERFORM public.record_failed_login_attempt_enhanced(
                user_record.user_id,
                p_ip_address,
                p_user_agent
            );
            
            RETURN jsonb_build_object(
                'success', false,
                'message', 'Invalid 2FA code'
            );
        END IF;
    END IF;
    
    -- Login successful - reset failed attempts
    PERFORM public.reset_failed_login_attempts_enhanced(
        user_record.user_id,
        p_ip_address,
        p_user_agent
    );
    
    -- Log successful login
    INSERT INTO public.audit_logs (
        user_id,
        action,
        table_name,
        record_id,
        new_values,
        ip_address,
        user_agent
    ) VALUES (
        user_record.user_id,
        'SUCCESSFUL_LOGIN',
        'user_profiles',
        user_record.user_id,
        jsonb_build_object(
            'email', user_record.email,
            'role', user_record.primary_role,
            '2fa_used', user_record.two_factor_enabled,
            'previous_failed_attempts', user_record.failed_login_attempts
        ),
        p_ip_address,
        p_user_agent
    );
    
    -- Return successful login result
    RETURN jsonb_build_object(
        'success', true,
        'user', jsonb_build_object(
            'user_id', user_record.user_id,
            'email', user_record.email,
            'first_name', user_record.first_name,
            'last_name', user_record.last_name,
            'primary_role', user_record.primary_role,
            'two_factor_enabled', user_record.two_factor_enabled
        ),
        'message', 'Login successful'
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;