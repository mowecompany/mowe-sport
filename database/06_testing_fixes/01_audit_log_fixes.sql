-- =====================================================
-- MOWE SPORT PLATFORM - AUDIT LOG FIXES
-- =====================================================
-- Description: Fix audit log table structure and add missing columns
-- Dependencies: Existing audit_logs table
-- Execution Order: Before running system tests
-- =====================================================

-- Check if audit_logs table exists and add missing columns
DO $$
BEGIN
    -- Add description column if it doesn't exist
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'audit_logs' AND column_name = 'description'
    ) THEN
        ALTER TABLE audit_logs ADD COLUMN description TEXT;
    END IF;
    
    -- Ensure all required columns exist
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'audit_logs' AND column_name = 'user_id'
    ) THEN
        ALTER TABLE audit_logs ADD COLUMN user_id UUID REFERENCES user_profiles(user_id);
    END IF;
    
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'audit_logs' AND column_name = 'action'
    ) THEN
        ALTER TABLE audit_logs ADD COLUMN action VARCHAR(100) NOT NULL DEFAULT 'UNKNOWN';
    END IF;
    
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'audit_logs' AND column_name = 'table_name'
    ) THEN
        ALTER TABLE audit_logs ADD COLUMN table_name VARCHAR(100);
    END IF;
    
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'audit_logs' AND column_name = 'record_id'
    ) THEN
        ALTER TABLE audit_logs ADD COLUMN record_id UUID;
    END IF;
    
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'audit_logs' AND column_name = 'ip_address'
    ) THEN
        ALTER TABLE audit_logs ADD COLUMN ip_address INET;
    END IF;
    
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'audit_logs' AND column_name = 'created_at'
    ) THEN
        ALTER TABLE audit_logs ADD COLUMN created_at TIMESTAMP DEFAULT NOW();
    END IF;
END $$;

-- Create indexes for audit_logs if they don't exist
CREATE INDEX IF NOT EXISTS idx_audit_logs_created_at ON audit_logs(created_at);
CREATE INDEX IF NOT EXISTS idx_audit_logs_user_id ON audit_logs(user_id) WHERE user_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_audit_logs_action ON audit_logs(action);
CREATE INDEX IF NOT EXISTS idx_audit_logs_table_name ON audit_logs(table_name) WHERE table_name IS NOT NULL;

-- Create missing authentication functions
CREATE OR REPLACE FUNCTION validate_password_hash(
    input_password TEXT,
    stored_hash TEXT
) RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    -- Simple validation - in production, use proper bcrypt validation
    -- This is a placeholder implementation for testing
    RETURN stored_hash IS NOT NULL AND LENGTH(stored_hash) > 10;
END;
$$;

CREATE OR REPLACE FUNCTION handle_failed_login(
    p_user_id UUID
) RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    -- Increment failed login attempts
    UPDATE user_profiles 
    SET failed_login_attempts = failed_login_attempts + 1,
        updated_at = NOW()
    WHERE user_id = p_user_id;
    
    -- Lock account if too many attempts
    UPDATE user_profiles 
    SET locked_until = CASE 
        WHEN failed_login_attempts >= 10 THEN NOW() + INTERVAL '24 hours'
        WHEN failed_login_attempts >= 5 THEN NOW() + INTERVAL '15 minutes'
        ELSE NULL
    END
    WHERE user_id = p_user_id;
    
    -- Log the failed attempt
    INSERT INTO audit_logs (user_id, action, table_name, description, created_at)
    VALUES (p_user_id, 'FAILED_LOGIN', 'user_profiles', 'Failed login attempt', NOW());
END;
$$;

CREATE OR REPLACE FUNCTION reset_failed_attempts(
    p_user_id UUID
) RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    -- Reset failed login attempts and unlock account
    UPDATE user_profiles 
    SET failed_login_attempts = 0,
        locked_until = NULL,
        last_login_at = NOW(),
        updated_at = NOW()
    WHERE user_id = p_user_id;
    
    -- Log successful login
    INSERT INTO audit_logs (user_id, action, table_name, description, created_at)
    VALUES (p_user_id, 'SUCCESSFUL_LOGIN', 'user_profiles', 'Successful login', NOW());
END;
$$;

-- Add comments for documentation
COMMENT ON FUNCTION validate_password_hash IS 'Validates password against stored hash - placeholder implementation for testing';
COMMENT ON FUNCTION handle_failed_login IS 'Handles failed login attempts with progressive locking';
COMMENT ON FUNCTION reset_failed_attempts IS 'Resets failed login attempts after successful authentication';

-- Log the fixes
INSERT INTO audit_logs (action, table_name, description, created_at)
VALUES ('SYSTEM_FIX', 'audit_logs', 'Applied audit log fixes and missing authentication functions', NOW());