-- =====================================================
-- MOWE SPORT PLATFORM - FIX PASSWORD HASHES
-- =====================================================
-- Migration: 005_fix_password_hashes
-- Description: Update password hashes with correct bcrypt hashes
-- =====================================================

-- Update super admin password hash
-- Password: MoweSport2024! (properly hashed with bcrypt cost 12)
UPDATE public.user_profiles 
SET password_hash = '$2a$12$IafTzL7jg7UGML0rCF0ZWOlATANGkuljqy3iLGP0Qs7IfvXblxkAW',
    updated_at = NOW()
WHERE user_id = '00000000-0000-0000-0000-000000000001';

-- Update city admin password hashes (same password for all)
UPDATE public.user_profiles 
SET password_hash = '$2a$12$IafTzL7jg7UGML0rCF0ZWOlATANGkuljqy3iLGP0Qs7IfvXblxkAW',
    updated_at = NOW()
WHERE primary_role = 'city_admin';

-- Update team owner password hashes (same password for testing)
UPDATE public.user_profiles 
SET password_hash = '$2a$12$IafTzL7jg7UGML0rCF0ZWOlATANGkuljqy3iLGP0Qs7IfvXblxkAW',
    updated_at = NOW()
WHERE primary_role = 'owner';

-- Log the password hash fix
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
    'user_profiles',
    NULL,
    '{"message": "Password hashes corrected for all users", "password": "MoweSport2024!", "note": "Change all passwords immediately in production"}'::jsonb,
    '127.0.0.1'::inet,
    'Mowe Sport Database Migration'
);

-- Verify the password hash update
DO $$
DECLARE
    user_count INTEGER;
BEGIN
    SELECT COUNT(*) INTO user_count
    FROM public.user_profiles
    WHERE password_hash = '$2a$12$IafTzL7jg7UGML0rCF0ZWOlATANGkuljqy3iLGP0Qs7IfvXblxkAW';
    
    RAISE NOTICE 'Password hashes updated for % users', user_count;
    
    IF user_count < 6 THEN
        RAISE EXCEPTION 'Expected at least 6 users with updated password hashes, found %', user_count;
    END IF;
END $$;