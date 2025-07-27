-- =====================================================
-- MOWE SPORT PLATFORM - SUPER ADMIN LOGIN TEST
-- =====================================================
-- Test script to verify super admin credentials
-- =====================================================

\echo '=== SUPER ADMIN LOGIN TEST ==='
\echo ''

-- Test super admin user exists and is active
\echo '--- Super Admin User Details ---'
SELECT 
    user_id,
    email,
    first_name,
    last_name,
    primary_role,
    is_active,
    account_status,
    two_factor_enabled,
    failed_login_attempts,
    locked_until,
    created_at
FROM public.user_profiles 
WHERE user_id = '00000000-0000-0000-0000-000000000001';

\echo ''
\echo '--- Password Hash Verification ---'
-- Note: The password for admin@mowesport.com is: MoweSport2024!
-- This should be changed immediately after first login
SELECT 
    email,
    CASE 
        WHEN password_hash IS NOT NULL AND LENGTH(password_hash) > 50 THEN '✅ Password hash exists and is properly formatted'
        ELSE '❌ Password hash issue detected'
    END as password_status,
    CASE 
        WHEN password_hash LIKE '$2a$12$%' THEN '✅ Bcrypt hash with cost 12 detected'
        ELSE '❌ Unexpected hash format'
    END as hash_format
FROM public.user_profiles 
WHERE user_id = '00000000-0000-0000-0000-000000000001';

\echo ''
\echo '--- Account Security Status ---'
SELECT 
    email,
    CASE 
        WHEN is_active = TRUE THEN '✅ Account is active'
        ELSE '❌ Account is inactive'
    END as active_status,
    CASE 
        WHEN account_status = 'active' THEN '✅ Account status is active'
        ELSE '❌ Account status: ' || account_status
    END as account_status,
    CASE 
        WHEN failed_login_attempts = 0 THEN '✅ No failed login attempts'
        ELSE '⚠️ Failed attempts: ' || failed_login_attempts::text
    END as login_attempts,
    CASE 
        WHEN locked_until IS NULL THEN '✅ Account is not locked'
        ELSE '❌ Account locked until: ' || locked_until::text
    END as lock_status
FROM public.user_profiles 
WHERE user_id = '00000000-0000-0000-0000-000000000001';

\echo ''
\echo '--- Two-Factor Authentication Status ---'
SELECT 
    email,
    CASE 
        WHEN two_factor_enabled = FALSE THEN '⚠️ 2FA is disabled (should be enabled after first login)'
        ELSE '✅ 2FA is enabled'
    END as tfa_status,
    CASE 
        WHEN two_factor_secret IS NULL THEN '⚠️ No 2FA secret configured'
        ELSE '✅ 2FA secret is configured'
    END as tfa_secret_status
FROM public.user_profiles 
WHERE user_id = '00000000-0000-0000-0000-000000000001';

\echo ''
\echo '--- Super Admin Permissions Check ---'
-- Check if super admin has global access (no city/sport restrictions)
SELECT 
    'Super Admin Global Access' as permission_type,
    CASE 
        WHEN COUNT(*) = 0 THEN '✅ Super admin has global access (no city/sport restrictions)'
        ELSE '❌ Super admin has restricted access: ' || COUNT(*)::text || ' restrictions found'
    END as access_status
FROM public.user_roles_by_city_sport 
WHERE user_id = '00000000-0000-0000-0000-000000000001';

\echo ''
\echo '--- City Admin Users Created ---'
SELECT 
    email,
    first_name || ' ' || last_name as full_name,
    primary_role,
    is_active,
    account_status
FROM public.user_profiles 
WHERE primary_role = 'city_admin'
ORDER BY email;

\echo ''
\echo '--- City Admin Role Assignments ---'
SELECT 
    up.email,
    up.first_name || ' ' || up.last_name as admin_name,
    c.name as assigned_city,
    COALESCE(s.name, 'All Sports') as assigned_sport,
    ur.role_name,
    ur.is_active
FROM public.user_roles_by_city_sport ur
JOIN public.user_profiles up ON ur.user_id = up.user_id
LEFT JOIN public.cities c ON ur.city_id = c.city_id
LEFT JOIN public.sports s ON ur.sport_id = s.sport_id
WHERE ur.role_name = 'city_admin'
ORDER BY up.email;

\echo ''
\echo '=== IMPORTANT SECURITY NOTES ==='
\echo '1. Default super admin password: MoweSport2024!'
\echo '2. This password MUST be changed immediately after first login'
\echo '3. Enable 2FA for the super admin account after first login'
\echo '4. City admin accounts use the same default password'
\echo '5. All default passwords should be changed in production'
\echo ''
\echo '=== TEST COMPLETE ==='