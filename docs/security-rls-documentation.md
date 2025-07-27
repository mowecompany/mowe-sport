# Mowe Sport - Row Level Security (RLS) and Security Functions Documentation

## Overview

This document provides comprehensive information about the Row Level Security (RLS) implementation and security functions in the Mowe Sport platform. The security model is designed to ensure multi-tenant data isolation and robust authentication mechanisms.

## Row Level Security (RLS) Architecture

### Security Model Overview

The Mowe Sport platform implements a multi-layered security model:

1. **Multi-Tenancy Isolation**: Data is isolated by city and sport combination
2. **Role-Based Access Control**: Different access levels based on user roles
3. **Row-Level Filtering**: Automatic data filtering at the database level
4. **View-Level Permissions**: Granular control over what users can see

### Core Security Functions

#### Current User Context Functions

```sql
-- Get current authenticated user ID
CREATE OR REPLACE FUNCTION current_user_id()
RETURNS UUID AS $$
BEGIN
    RETURN COALESCE(
        (current_setting('app.current_user_id', true))::UUID,
        '00000000-0000-0000-0000-000000000000'::UUID
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Get current user's primary role
CREATE OR REPLACE FUNCTION current_user_role()
RETURNS TEXT AS $$
DECLARE
    user_role TEXT;
BEGIN
    SELECT primary_role INTO user_role
    FROM user_profiles
    WHERE user_id = current_user_id();
    
    RETURN COALESCE(user_role, 'anonymous');
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Get current user's city context
CREATE OR REPLACE FUNCTION current_user_city()
RETURNS UUID AS $$
DECLARE
    city_id UUID;
BEGIN
    SELECT ur.city_id INTO city_id
    FROM user_roles_by_city_sport ur
    WHERE ur.user_id = current_user_id()
    AND ur.is_active = TRUE
    LIMIT 1;
    
    RETURN city_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Get current user's sport context
CREATE OR REPLACE FUNCTION current_user_sport()
RETURNS UUID AS $$
DECLARE
    sport_id UUID;
BEGIN
    SELECT ur.sport_id INTO sport_id
    FROM user_roles_by_city_sport ur
    WHERE ur.user_id = current_user_id()
    AND ur.is_active = TRUE
    LIMIT 1;
    
    RETURN sport_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
```

### RLS Policies by Table

#### 1. User Profiles Table

```sql
-- Enable RLS on user_profiles
ALTER TABLE user_profiles ENABLE ROW LEVEL SECURITY;

-- Super admins can see all users
CREATE POLICY "super_admin_all_users" ON user_profiles
FOR ALL TO authenticated
USING (
    EXISTS (
        SELECT 1 FROM user_profiles up
        WHERE up.user_id = current_user_id()
        AND up.primary_role = 'super_admin'
        AND up.is_active = TRUE
    )
);

-- Users can see their own profile
CREATE POLICY "users_own_profile" ON user_profiles
FOR ALL TO authenticated
USING (user_id = current_user_id());

-- City admins can see users in their city/sport
CREATE POLICY "city_admin_users" ON user_profiles
FOR SELECT TO authenticated
USING (
    EXISTS (
        SELECT 1 FROM user_roles_by_city_sport ur1
        JOIN user_roles_by_city_sport ur2 ON ur1.city_id = ur2.city_id AND ur1.sport_id = ur2.sport_id
        WHERE ur1.user_id = current_user_id()
        AND ur1.role_name = 'city_admin'
        AND ur1.is_active = TRUE
        AND ur2.user_id = user_profiles.user_id
        AND ur2.is_active = TRUE
    )
);
```

#### 2. Tournaments Table

```sql
-- Enable RLS on tournaments
ALTER TABLE tournaments ENABLE ROW LEVEL SECURITY;

-- Public tournaments are visible to everyone
CREATE POLICY "public_tournaments" ON tournaments
FOR SELECT TO anon, authenticated
USING (is_public = TRUE AND status IN ('approved', 'active', 'completed'));

-- Super admins can manage all tournaments
CREATE POLICY "super_admin_tournaments" ON tournaments
FOR ALL TO authenticated
USING (
    EXISTS (
        SELECT 1 FROM user_profiles up
        WHERE up.user_id = current_user_id()
        AND up.primary_role = 'super_admin'
        AND up.is_active = TRUE
    )
);

-- City admins can manage tournaments in their city/sport
CREATE POLICY "city_admin_tournaments" ON tournaments
FOR ALL TO authenticated
USING (
    EXISTS (
        SELECT 1 FROM user_roles_by_city_sport ur
        WHERE ur.user_id = current_user_id()
        AND ur.role_name = 'city_admin'
        AND ur.city_id = tournaments.city_id
        AND ur.sport_id = tournaments.sport_id
        AND ur.is_active = TRUE
    )
);

-- Tournament admins can manage their own tournaments
CREATE POLICY "tournament_admin_own" ON tournaments
FOR ALL TO authenticated
USING (admin_user_id = current_user_id());

-- Team owners can view tournaments they participate in
CREATE POLICY "team_owners_tournaments" ON tournaments
FOR SELECT TO authenticated
USING (
    EXISTS (
        SELECT 1 FROM tournament_teams tt
        JOIN teams t ON tt.team_id = t.team_id
        WHERE tt.tournament_id = tournaments.tournament_id
        AND t.owner_user_id = current_user_id()
        AND tt.status = 'approved'
    )
);
```

#### 3. Teams Table

```sql
-- Enable RLS on teams
ALTER TABLE teams ENABLE ROW LEVEL SECURITY;

-- Super admins can manage all teams
CREATE POLICY "super_admin_teams" ON teams
FOR ALL TO authenticated
USING (
    EXISTS (
        SELECT 1 FROM user_profiles up
        WHERE up.user_id = current_user_id()
        AND up.primary_role = 'super_admin'
        AND up.is_active = TRUE
    )
);

-- Team owners can manage their own teams
CREATE POLICY "team_owners_own_teams" ON teams
FOR ALL TO authenticated
USING (owner_user_id = current_user_id());

-- City admins can view teams in their city/sport
CREATE POLICY "city_admin_teams" ON teams
FOR SELECT TO authenticated
USING (
    EXISTS (
        SELECT 1 FROM user_roles_by_city_sport ur
        WHERE ur.user_id = current_user_id()
        AND ur.role_name = 'city_admin'
        AND ur.city_id = teams.city_id
        AND ur.sport_id = teams.sport_id
        AND ur.is_active = TRUE
    )
);

-- Tournament admins can view teams in their tournaments
CREATE POLICY "tournament_admin_teams" ON teams
FOR SELECT TO authenticated
USING (
    EXISTS (
        SELECT 1 FROM tournaments t
        JOIN tournament_teams tt ON t.tournament_id = tt.tournament_id
        WHERE t.admin_user_id = current_user_id()
        AND tt.team_id = teams.team_id
    )
);

-- Public visibility for active teams
CREATE POLICY "public_active_teams" ON teams
FOR SELECT TO anon, authenticated
USING (is_active = TRUE);
```

#### 4. Matches Table

```sql
-- Enable RLS on matches
ALTER TABLE matches ENABLE ROW LEVEL SECURITY;

-- Super admins can manage all matches
CREATE POLICY "super_admin_matches" ON matches
FOR ALL TO authenticated
USING (
    EXISTS (
        SELECT 1 FROM user_profiles up
        WHERE up.user_id = current_user_id()
        AND up.primary_role = 'super_admin'
        AND up.is_active = TRUE
    )
);

-- Tournament admins can manage matches in their tournaments
CREATE POLICY "tournament_admin_matches" ON matches
FOR ALL TO authenticated
USING (
    EXISTS (
        SELECT 1 FROM tournaments t
        WHERE t.tournament_id = matches.tournament_id
        AND t.admin_user_id = current_user_id()
    )
);

-- Referees can manage matches they're assigned to
CREATE POLICY "referee_assigned_matches" ON matches
FOR ALL TO authenticated
USING (referee_user_id = current_user_id());

-- Team owners can view matches their teams participate in
CREATE POLICY "team_owners_matches" ON matches
FOR SELECT TO authenticated
USING (
    EXISTS (
        SELECT 1 FROM teams t
        WHERE (t.team_id = matches.team1_id OR t.team_id = matches.team2_id)
        AND t.owner_user_id = current_user_id()
    )
);

-- Public matches are visible to everyone
CREATE POLICY "public_matches" ON matches
FOR SELECT TO anon, authenticated
USING (
    EXISTS (
        SELECT 1 FROM tournaments t
        WHERE t.tournament_id = matches.tournament_id
        AND t.is_public = TRUE
    )
);
```

#### 5. Statistics Tables

```sql
-- Enable RLS on player_statistics
ALTER TABLE player_statistics ENABLE ROW LEVEL SECURITY;

-- Super admins can see all statistics
CREATE POLICY "super_admin_player_stats" ON player_statistics
FOR ALL TO authenticated
USING (
    EXISTS (
        SELECT 1 FROM user_profiles up
        WHERE up.user_id = current_user_id()
        AND up.primary_role = 'super_admin'
        AND up.is_active = TRUE
    )
);

-- Team owners can see statistics for their team players
CREATE POLICY "team_owners_player_stats" ON player_statistics
FOR SELECT TO authenticated
USING (
    EXISTS (
        SELECT 1 FROM teams t
        WHERE t.team_id = player_statistics.team_id
        AND t.owner_user_id = current_user_id()
    )
);

-- Tournament admins can see statistics in their tournaments
CREATE POLICY "tournament_admin_player_stats" ON player_statistics
FOR SELECT TO authenticated
USING (
    EXISTS (
        SELECT 1 FROM tournaments t
        WHERE t.tournament_id = player_statistics.tournament_id
        AND t.admin_user_id = current_user_id()
    )
);

-- Public statistics for public tournaments
CREATE POLICY "public_player_stats" ON player_statistics
FOR SELECT TO anon, authenticated
USING (
    EXISTS (
        SELECT 1 FROM tournaments t
        WHERE t.tournament_id = player_statistics.tournament_id
        AND t.is_public = TRUE
    )
);

-- Similar policies for team_statistics
ALTER TABLE team_statistics ENABLE ROW LEVEL SECURITY;

CREATE POLICY "super_admin_team_stats" ON team_statistics
FOR ALL TO authenticated
USING (
    EXISTS (
        SELECT 1 FROM user_profiles up
        WHERE up.user_id = current_user_id()
        AND up.primary_role = 'super_admin'
        AND up.is_active = TRUE
    )
);

CREATE POLICY "team_owners_team_stats" ON team_statistics
FOR SELECT TO authenticated
USING (
    EXISTS (
        SELECT 1 FROM teams t
        WHERE t.team_id = team_statistics.team_id
        AND t.owner_user_id = current_user_id()
    )
);

CREATE POLICY "public_team_stats" ON team_statistics
FOR SELECT TO anon, authenticated
USING (
    EXISTS (
        SELECT 1 FROM tournaments t
        WHERE t.tournament_id = team_statistics.tournament_id
        AND t.is_public = TRUE
    )
);
```

## Authentication Security Functions

### Password Management

#### Password Strength Validation

```sql
CREATE OR REPLACE FUNCTION validate_password_strength(password TEXT)
RETURNS JSONB AS $$
DECLARE
    result JSONB := '{"valid": true, "errors": []}'::JSONB;
    errors TEXT[] := ARRAY[]::TEXT[];
BEGIN
    -- Length check (minimum 8 characters)
    IF LENGTH(password) < 8 THEN
        errors := array_append(errors, 'Password must be at least 8 characters long');
    END IF;
    
    -- Maximum length check (prevent DoS)
    IF LENGTH(password) > 128 THEN
        errors := array_append(errors, 'Password must be less than 128 characters');
    END IF;
    
    -- Uppercase letter check
    IF password !~ '[A-Z]' THEN
        errors := array_append(errors, 'Password must contain at least one uppercase letter');
    END IF;
    
    -- Lowercase letter check
    IF password !~ '[a-z]' THEN
        errors := array_append(errors, 'Password must contain at least one lowercase letter');
    END IF;
    
    -- Digit check
    IF password !~ '[0-9]' THEN
        errors := array_append(errors, 'Password must contain at least one digit');
    END IF;
    
    -- Special character check
    IF password !~ '[!@#$%^&*(),.?":{}|<>]' THEN
        errors := array_append(errors, 'Password must contain at least one special character');
    END IF;
    
    -- Common password check
    IF password IN ('password', '123456', 'password123', 'admin', 'qwerty', '12345678', 'abc123', 'Password1') THEN
        errors := array_append(errors, 'Password is too common and easily guessable');
    END IF;
    
    -- Sequential characters check
    IF password ~ '(012|123|234|345|456|567|678|789|890|abc|bcd|cde|def)' THEN
        errors := array_append(errors, 'Password should not contain sequential characters');
    END IF;
    
    IF array_length(errors, 1) > 0 THEN
        result := jsonb_build_object('valid', false, 'errors', errors);
    END IF;
    
    RETURN result;
END;
$$ LANGUAGE plpgsql;
```

#### Password Hashing

```sql
CREATE OR REPLACE FUNCTION hash_password(password TEXT)
RETURNS TEXT AS $$
DECLARE
    salt TEXT;
    hashed TEXT;
BEGIN
    -- Generate a random salt
    salt := encode(gen_random_bytes(16), 'hex');
    
    -- Create hash using SHA-256 with salt and pepper
    hashed := encode(
        digest(
            password || salt || 'mowe_sport_pepper_2024', 
            'sha256'
        ), 
        'hex'
    );
    
    -- Return in format: $mowe$salt$hash
    RETURN '$mowe$' || salt || '$' || hashed;
END;
$$ LANGUAGE plpgsql;
```

#### Password Verification

```sql
CREATE OR REPLACE FUNCTION verify_password(password TEXT, stored_hash TEXT)
RETURNS BOOLEAN AS $$
DECLARE
    salt TEXT;
    hash TEXT;
    computed_hash TEXT;
BEGIN
    -- Extract salt and hash from stored format
    IF stored_hash !~ '^\$mowe\$[a-f0-9]{32}\$[a-f0-9]{64}$' THEN
        RETURN FALSE;
    END IF;
    
    salt := substring(stored_hash from 7 for 32);
    hash := substring(stored_hash from 40);
    
    -- Compute hash with provided password
    computed_hash := encode(
        digest(
            password || salt || 'mowe_sport_pepper_2024', 
            'sha256'
        ), 
        'hex'
    );
    
    -- Compare hashes
    RETURN computed_hash = hash;
END;
$$ LANGUAGE plpgsql;
```

### Account Security Functions

#### Account Locking Management

```sql
CREATE OR REPLACE FUNCTION is_account_locked_detailed(user_email TEXT)
RETURNS JSONB AS $$
DECLARE
    user_record RECORD;
    result JSONB;
BEGIN
    SELECT user_id, failed_login_attempts, locked_until, account_status, is_active
    INTO user_record
    FROM user_profiles
    WHERE email = user_email;
    
    IF NOT FOUND THEN
        RETURN jsonb_build_object(
            'locked', true,
            'reason', 'user_not_found',
            'message', 'User account not found'
        );
    END IF;
    
    -- Check if account is active
    IF NOT user_record.is_active THEN
        RETURN jsonb_build_object(
            'locked', true,
            'reason', 'account_inactive',
            'message', 'Account is inactive'
        );
    END IF;
    
    -- Check account status
    IF user_record.account_status != 'active' THEN
        RETURN jsonb_build_object(
            'locked', true,
            'reason', 'account_disabled',
            'message', 'Account is disabled or suspended',
            'status', user_record.account_status
        );
    END IF;
    
    -- Check temporary lock
    IF user_record.locked_until IS NOT NULL AND user_record.locked_until > NOW() THEN
        RETURN jsonb_build_object(
            'locked', true,
            'reason', 'temporary_lock',
            'message', 'Account is temporarily locked due to failed login attempts',
            'locked_until', user_record.locked_until,
            'failed_attempts', user_record.failed_login_attempts
        );
    END IF;
    
    -- Check if approaching lock threshold
    IF user_record.failed_login_attempts >= 3 THEN
        RETURN jsonb_build_object(
            'locked', false,
            'warning', true,
            'message', 'Account will be locked after ' || (5 - user_record.failed_login_attempts) || ' more failed attempts',
            'failed_attempts', user_record.failed_login_attempts
        );
    END IF;
    
    RETURN jsonb_build_object(
        'locked', false,
        'failed_attempts', user_record.failed_login_attempts
    );
END;
$$ LANGUAGE plpgsql;
```

#### Failed Login Attempt Management

```sql
CREATE OR REPLACE FUNCTION record_failed_login_attempt_enhanced(user_email TEXT)
RETURNS JSONB AS $$
DECLARE
    user_id UUID;
    current_attempts INTEGER;
    lock_duration INTERVAL;
    lock_until TIMESTAMP;
BEGIN
    -- Get current user info
    SELECT up.user_id, up.failed_login_attempts
    INTO user_id, current_attempts
    FROM user_profiles up
    WHERE up.email = user_email;
    
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
        lock_duration := INTERVAL '24 hours';  -- 24 hour lock for 10+ attempts
    ELSIF current_attempts >= 5 THEN
        lock_duration := INTERVAL '15 minutes'; -- 15 minute lock for 5+ attempts
    ELSE
        lock_duration := NULL; -- No lock yet
    END IF;
    
    -- Calculate lock until time
    IF lock_duration IS NOT NULL THEN
        lock_until := NOW() + lock_duration;
    END IF;
    
    -- Update user record
    UPDATE user_profiles
    SET 
        failed_login_attempts = current_attempts,
        locked_until = lock_until,
        updated_at = NOW()
    WHERE user_profiles.user_id = record_failed_login_attempt_enhanced.user_id;
    
    -- Log the failed attempt
    INSERT INTO audit_logs (
        user_id,
        action,
        table_name,
        record_id,
        old_values,
        new_values,
        ip_address,
        user_agent
    ) VALUES (
        user_id,
        'failed_login_attempt',
        'user_profiles',
        user_id,
        jsonb_build_object('failed_attempts', current_attempts - 1),
        jsonb_build_object('failed_attempts', current_attempts, 'locked_until', lock_until),
        inet_client_addr(),
        current_setting('app.user_agent', true)
    );
    
    RETURN jsonb_build_object(
        'success', true,
        'failed_attempts', current_attempts,
        'locked_until', lock_until,
        'message', CASE 
            WHEN lock_until IS NOT NULL THEN 'Account locked due to failed attempts'
            ELSE 'Failed attempt recorded'
        END
    );
END;
$$ LANGUAGE plpgsql;
```

### Two-Factor Authentication (2FA)

#### Generate 2FA Secret

```sql
CREATE OR REPLACE FUNCTION generate_2fa_secret(user_email TEXT)
RETURNS JSONB AS $$
DECLARE
    user_id UUID;
    secret TEXT;
    qr_url TEXT;
BEGIN
    -- Get user ID
    SELECT up.user_id INTO user_id
    FROM user_profiles up
    WHERE up.email = user_email AND up.is_active = TRUE;
    
    IF NOT FOUND THEN
        RETURN jsonb_build_object(
            'success', false,
            'message', 'User not found or inactive'
        );
    END IF;
    
    -- Generate base32 secret (32 characters)
    secret := upper(encode(gen_random_bytes(20), 'base32'));
    
    -- Update user profile with secret
    UPDATE user_profiles
    SET 
        two_factor_secret = secret,
        updated_at = NOW()
    WHERE user_profiles.user_id = generate_2fa_secret.user_id;
    
    -- Generate QR code URL for authenticator apps
    qr_url := 'otpauth://totp/MoweSport:' || user_email || 
              '?secret=' || secret || 
              '&issuer=MoweSport';
    
    RETURN jsonb_build_object(
        'success', true,
        'secret', secret,
        'qr_code_url', qr_url,
        'message', '2FA secret generated. Scan QR code with authenticator app'
    );
END;
$$ LANGUAGE plpgsql;
```

#### Enable/Disable 2FA

```sql
CREATE OR REPLACE FUNCTION enable_2fa(user_email TEXT, verification_code TEXT)
RETURNS JSONB AS $$
DECLARE
    user_record RECORD;
    is_valid BOOLEAN;
BEGIN
    -- Get user info
    SELECT user_id, two_factor_secret, two_factor_enabled
    INTO user_record
    FROM user_profiles
    WHERE email = user_email AND is_active = TRUE;
    
    IF NOT FOUND THEN
        RETURN jsonb_build_object(
            'success', false,
            'message', 'User not found or inactive'
        );
    END IF;
    
    IF user_record.two_factor_secret IS NULL THEN
        RETURN jsonb_build_object(
            'success', false,
            'message', '2FA secret not generated. Generate secret first.'
        );
    END IF;
    
    -- Verify the code (simplified - in production use proper TOTP library)
    is_valid := verify_2fa_code(user_email, verification_code);
    
    IF NOT is_valid THEN
        RETURN jsonb_build_object(
            'success', false,
            'message', 'Invalid verification code'
        );
    END IF;
    
    -- Enable 2FA
    UPDATE user_profiles
    SET 
        two_factor_enabled = TRUE,
        updated_at = NOW()
    WHERE user_id = user_record.user_id;
    
    -- Log the 2FA enablement
    INSERT INTO audit_logs (
        user_id,
        action,
        table_name,
        record_id,
        new_values
    ) VALUES (
        user_record.user_id,
        '2fa_enabled',
        'user_profiles',
        user_record.user_id,
        jsonb_build_object('two_factor_enabled', true)
    );
    
    RETURN jsonb_build_object(
        'success', true,
        'message', '2FA enabled successfully'
    );
END;
$$ LANGUAGE plpgsql;
```

### Password Recovery Functions

#### Generate Recovery Token

```sql
CREATE OR REPLACE FUNCTION generate_password_recovery_token(user_email TEXT)
RETURNS JSONB AS $$
DECLARE
    user_id UUID;
    recovery_token TEXT;
    expiration_time TIMESTAMP;
BEGIN
    -- Check if user exists and is active
    SELECT up.user_id INTO user_id
    FROM user_profiles up
    WHERE up.email = user_email AND up.is_active = TRUE;
    
    IF NOT FOUND THEN
        -- Don't reveal if email exists or not for security
        RETURN jsonb_build_object(
            'success', true,
            'message', 'If the email exists, a recovery token has been sent'
        );
    END IF;
    
    -- Generate secure random token
    recovery_token := encode(gen_random_bytes(32), 'hex');
    expiration_time := NOW() + INTERVAL '1 hour';
    
    -- Update user with recovery token
    UPDATE user_profiles
    SET 
        token_recovery = recovery_token,
        token_expiration_date = expiration_time,
        updated_at = NOW()
    WHERE user_profiles.user_id = generate_password_recovery_token.user_id;
    
    -- Log the recovery token generation
    INSERT INTO audit_logs (
        user_id,
        action,
        table_name,
        record_id,
        new_values
    ) VALUES (
        user_id,
        'password_recovery_requested',
        'user_profiles',
        user_id,
        jsonb_build_object('token_generated', true, 'expires_at', expiration_time)
    );
    
    RETURN jsonb_build_object(
        'success', true,
        'user_id', user_id,
        'recovery_token', recovery_token,
        'expires_at', expiration_time,
        'message', 'Recovery token generated successfully'
    );
END;
$$ LANGUAGE plpgsql;
```

## Security Best Practices

### Implementation Guidelines

1. **Always Use RLS**: Enable RLS on all tables containing sensitive data
2. **Principle of Least Privilege**: Grant minimum necessary permissions
3. **Context Functions**: Use security definer functions for user context
4. **Audit Everything**: Log all security-related actions
5. **Token Expiration**: Implement proper token expiration and rotation
6. **Rate Limiting**: Implement rate limiting for authentication endpoints
7. **Input Validation**: Validate all inputs at the database level
8. **Secure Defaults**: Default to most restrictive permissions

### Security Monitoring

```sql
-- Function to detect suspicious activity
CREATE OR REPLACE FUNCTION detect_suspicious_activity(user_id UUID, time_window INTERVAL DEFAULT '1 hour')
RETURNS JSONB AS $$
DECLARE
    failed_attempts INTEGER;
    login_locations INTEGER;
    rapid_requests INTEGER;
    result JSONB;
BEGIN
    -- Count failed login attempts in time window
    SELECT COUNT(*) INTO failed_attempts
    FROM audit_logs
    WHERE audit_logs.user_id = detect_suspicious_activity.user_id
    AND action = 'failed_login_attempt'
    AND created_at > NOW() - time_window;
    
    -- Count distinct IP addresses for logins
    SELECT COUNT(DISTINCT ip_address) INTO login_locations
    FROM audit_logs
    WHERE audit_logs.user_id = detect_suspicious_activity.user_id
    AND action IN ('login_success', 'failed_login_attempt')
    AND created_at > NOW() - time_window;
    
    -- Count rapid API requests
    SELECT COUNT(*) INTO rapid_requests
    FROM audit_logs
    WHERE audit_logs.user_id = detect_suspicious_activity.user_id
    AND created_at > NOW() - INTERVAL '5 minutes';
    
    result := jsonb_build_object(
        'user_id', user_id,
        'time_window', time_window,
        'failed_attempts', failed_attempts,
        'login_locations', login_locations,
        'rapid_requests', rapid_requests,
        'suspicious', (
            failed_attempts > 5 OR 
            login_locations > 3 OR 
            rapid_requests > 100
        )
    );
    
    -- Log if suspicious
    IF (result->>'suspicious')::BOOLEAN THEN
        INSERT INTO audit_logs (
            user_id,
            action,
            table_name,
            new_values
        ) VALUES (
            user_id,
            'suspicious_activity_detected',
            'security_monitoring',
            result
        );
    END IF;
    
    RETURN result;
END;
$$ LANGUAGE plpgsql;
```

This comprehensive RLS and security documentation provides the foundation for secure multi-tenant operations in the Mowe Sport platform. All policies and functions should be regularly reviewed and updated as the system evolves.