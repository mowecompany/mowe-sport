-- =====================================================
-- MOWE SPORT PLATFORM - TEST USERS
-- =====================================================
-- Description: Test users for development and testing
-- Dependencies: Complete schema and seed data
-- =====================================================

-- =====================================================
-- SUPER ADMIN TEST USER
-- =====================================================

INSERT INTO public.user_profiles (
    user_id,
    email,
    password_hash,
    first_name,
    last_name,
    primary_role,
    is_active,
    account_status,
    failed_login_attempts,
    two_factor_enabled,
    created_at,
    updated_at
) VALUES (
    'd5c37951-c387-49f7-a115-903ea94a41e6',
    'admin@mowesport.com',
    '$2a$10$rJAkkiZaQcczNhVUcDQuHuGYkVdVDe7IwLgscYAvXuHIQxJleVgL2', -- admin123
    'Super',
    'Admin',
    'super_admin',
    TRUE,
    'active',
    0,
    FALSE,
    NOW(),
    NOW()
) ON CONFLICT (user_id) DO UPDATE SET
    email = EXCLUDED.email,
    password_hash = EXCLUDED.password_hash,
    first_name = EXCLUDED.first_name,
    last_name = EXCLUDED.last_name,
    primary_role = EXCLUDED.primary_role,
    updated_at = NOW();

-- =====================================================
-- CITY ADMIN TEST USER
-- =====================================================

INSERT INTO public.user_profiles (
    user_id,
    email,
    password_hash,
    first_name,
    last_name,
    primary_role,
    is_active,
    account_status,
    failed_login_attempts,
    two_factor_enabled,
    created_at,
    updated_at
) VALUES (
    'a1b2c3d4-e5f6-7890-abcd-ef1234567890',
    'cityadmin@mowesport.com',
    '$2a$10$rJAkkiZaQcczNhVUcDQuHuGYkVdVDe7IwLgscYAvXuHIQxJleVgL2', -- admin123
    'City',
    'Admin',
    'city_admin',
    TRUE,
    'active',
    0,
    FALSE,
    NOW(),
    NOW()
) ON CONFLICT (user_id) DO UPDATE SET
    email = EXCLUDED.email,
    password_hash = EXCLUDED.password_hash,
    first_name = EXCLUDED.first_name,
    last_name = EXCLUDED.last_name,
    primary_role = EXCLUDED.primary_role,
    updated_at = NOW();

-- =====================================================
-- ASSIGN CITY ADMIN ROLE
-- =====================================================

INSERT INTO public.user_roles_by_city_sport (
    role_assignment_id,
    user_id,
    city_id,
    sport_id,
    role_name,
    assigned_by_user_id,
    is_active,
    created_at
) VALUES (
    'role-001-city-admin-bogota-football',
    'a1b2c3d4-e5f6-7890-abcd-ef1234567890',
    '550e8400-e29b-41d4-a716-446655440001', -- Bogotá
    '660e8400-e29b-41d4-a716-446655440001', -- Fútbol
    'city_admin',
    'd5c37951-c387-49f7-a115-903ea94a41e6', -- Assigned by super admin
    TRUE,
    NOW()
) ON CONFLICT (role_assignment_id) DO UPDATE SET
    is_active = EXCLUDED.is_active,
    created_at = NOW();

-- =====================================================
-- TEST CLIENT USER
-- =====================================================

INSERT INTO public.user_profiles (
    user_id,
    email,
    password_hash,
    first_name,
    last_name,
    phone,
    primary_role,
    is_active,
    account_status,
    failed_login_attempts,
    two_factor_enabled,
    created_at,
    updated_at
) VALUES (
    'client-001-test-user-uuid-here',
    'client@mowesport.com',
    '$2a$10$rJAkkiZaQcczNhVUcDQuHuGYkVdVDe7IwLgscYAvXuHIQxJleVgL2', -- admin123
    'Test',
    'Client',
    '+57 300 123 4567',
    'client',
    TRUE,
    'active',
    0,
    FALSE,
    NOW(),
    NOW()
) ON CONFLICT (user_id) DO UPDATE SET
    email = EXCLUDED.email,
    password_hash = EXCLUDED.password_hash,
    first_name = EXCLUDED.first_name,
    last_name = EXCLUDED.last_name,
    phone = EXCLUDED.phone,
    primary_role = EXCLUDED.primary_role,
    updated_at = NOW();

-- =====================================================
-- VERIFICATION QUERIES
-- =====================================================

-- Verify test users were created
-- SELECT user_id, email, first_name, last_name, primary_role, is_active, account_status 
-- FROM public.user_profiles 
-- WHERE email IN ('admin@mowesport.com', 'cityadmin@mowesport.com', 'client@mowesport.com');

-- Verify role assignments
-- SELECT ur.role_assignment_id, up.email, ur.role_name, c.name as city, s.name as sport
-- FROM public.user_roles_by_city_sport ur
-- JOIN public.user_profiles up ON ur.user_id = up.user_id
-- LEFT JOIN public.cities c ON ur.city_id = c.city_id
-- LEFT JOIN public.sports s ON ur.sport_id = s.sport_id
-- WHERE up.email IN ('admin@mowesport.com', 'cityadmin@mowesport.com');

-- =====================================================
-- NOTES
-- =====================================================

/*
TEST CREDENTIALS:
- Super Admin: admin@mowesport.com / admin123
- City Admin: cityadmin@mowesport.com / admin123  
- Client: client@mowesport.com / admin123

IMPORTANT:
- These are test users for development only
- Change passwords before production deployment
- Remove or disable test users in production
- The super admin can create additional administrators through the web interface
*/