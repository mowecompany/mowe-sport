-- =====================================================
-- MOWE SPORT PLATFORM - DATA VALIDATION SCRIPT
-- =====================================================
-- Description: Validate that initial system data was created correctly
-- =====================================================

-- =====================================================
-- VALIDATE CORE DATA
-- =====================================================

-- Check cities count
SELECT 'Cities' as table_name, COUNT(*) as record_count 
FROM public.cities WHERE is_active = TRUE;

-- Check sports count
SELECT 'Sports' as table_name, COUNT(*) as record_count 
FROM public.sports WHERE is_active = TRUE;

-- =====================================================
-- VALIDATE USER DATA
-- =====================================================

-- Check user profiles by role
SELECT 
    'User Profiles by Role' as validation_type,
    primary_role,
    COUNT(*) as count
FROM public.user_profiles 
WHERE is_active = TRUE
GROUP BY primary_role
ORDER BY primary_role;

-- Check super admin exists
SELECT 
    'Super Admin Validation' as validation_type,
    CASE 
        WHEN COUNT(*) = 1 THEN 'PASS - Super admin exists'
        ELSE 'FAIL - Super admin missing or duplicated'
    END as result
FROM public.user_profiles 
WHERE primary_role = 'super_admin' AND is_active = TRUE;

-- =====================================================
-- VALIDATE ROLE ASSIGNMENTS
-- =====================================================

-- Check role assignments
SELECT 
    'Role Assignments' as validation_type,
    ur.role_name,
    c.name as city_name,
    s.name as sport_name,
    COUNT(*) as assignments
FROM public.user_roles_by_city_sport ur
LEFT JOIN public.cities c ON ur.city_id = c.city_id
LEFT JOIN public.sports s ON ur.sport_id = s.sport_id
WHERE ur.is_active = TRUE
GROUP BY ur.role_name, c.name, s.name
ORDER BY ur.role_name, c.name, s.name;

-- =====================================================
-- VALIDATE TEAMS AND PLAYERS
-- =====================================================

-- Check teams
SELECT 
    'Teams' as validation_type,
    t.name as team_name,
    c.name as city_name,
    s.name as sport_name,
    up.first_name || ' ' || up.last_name as owner_name
FROM public.teams t
JOIN public.cities c ON t.city_id = c.city_id
JOIN public.sports s ON t.sport_id = s.sport_id
JOIN public.user_profiles up ON t.owner_user_id = up.user_id
WHERE t.is_active = TRUE;

-- Check players and their team assignments
SELECT 
    'Player Assignments' as validation_type,
    p.first_name || ' ' || p.last_name as player_name,
    t.name as team_name,
    tp.position,
    tp.jersey_number,
    tp.is_captain
FROM public.team_players tp
JOIN public.players p ON tp.player_id = p.player_id
JOIN public.teams t ON tp.team_id = t.team_id
WHERE tp.is_active = TRUE
ORDER BY t.name, tp.jersey_number;

-- =====================================================
-- VALIDATE TOURNAMENTS
-- =====================================================

-- Check tournaments
SELECT 
    'Tournaments' as validation_type,
    t.name as tournament_name,
    c.name as city_name,
    s.name as sport_name,
    t.status,
    t.start_date,
    t.end_date,
    t.registration_deadline
FROM public.tournaments t
JOIN public.cities c ON t.city_id = c.city_id
JOIN public.sports s ON t.sport_id = s.sport_id;

-- Check tournament registrations
SELECT 
    'Tournament Registrations' as validation_type,
    t.name as tournament_name,
    tm.name as team_name,
    tt.status as registration_status,
    tt.registration_fee_paid
FROM public.tournament_teams tt
JOIN public.tournaments t ON tt.tournament_id = t.tournament_id
JOIN public.teams tm ON tt.team_id = tm.team_id;

-- =====================================================
-- VALIDATE DATA INTEGRITY
-- =====================================================

-- Check for orphaned records
SELECT 
    'Orphaned Records Check' as validation_type,
    'user_roles_by_city_sport' as table_name,
    COUNT(*) as orphaned_count
FROM public.user_roles_by_city_sport ur
LEFT JOIN public.user_profiles up ON ur.user_id = up.user_id
WHERE up.user_id IS NULL

UNION ALL

SELECT 
    'Orphaned Records Check' as validation_type,
    'teams' as table_name,
    COUNT(*) as orphaned_count
FROM public.teams t
LEFT JOIN public.user_profiles up ON t.owner_user_id = up.user_id
WHERE up.user_id IS NULL

UNION ALL

SELECT 
    'Orphaned Records Check' as validation_type,
    'team_players' as table_name,
    COUNT(*) as orphaned_count
FROM public.team_players tp
LEFT JOIN public.teams t ON tp.team_id = t.team_id
LEFT JOIN public.players p ON tp.player_id = p.player_id
WHERE t.team_id IS NULL OR p.player_id IS NULL;

-- =====================================================
-- VALIDATE AUTHENTICATION DATA
-- =====================================================

-- Check password hashes are set
SELECT 
    'Password Hash Validation' as validation_type,
    CASE 
        WHEN COUNT(*) = 0 THEN 'PASS - All users have password hashes'
        ELSE 'FAIL - ' || COUNT(*) || ' users missing password hashes'
    END as result
FROM public.user_profiles 
WHERE password_hash IS NULL OR password_hash = '';

-- Check email uniqueness
SELECT 
    'Email Uniqueness' as validation_type,
    CASE 
        WHEN COUNT(*) = COUNT(DISTINCT email) THEN 'PASS - All emails are unique'
        ELSE 'FAIL - Duplicate emails found'
    END as result
FROM public.user_profiles;

-- =====================================================
-- VALIDATE AUDIT LOGS
-- =====================================================

-- Check audit logs were created
SELECT 
    'Audit Logs' as validation_type,
    action,
    COUNT(*) as log_count
FROM public.audit_logs 
WHERE action IN ('INITIAL_DATA_CREATED', 'DATA_INTEGRITY_CHECK', 'SYSTEM_INIT')
GROUP BY action
ORDER BY action;

-- =====================================================
-- SUMMARY VALIDATION
-- =====================================================

-- Overall system health check
SELECT 
    'System Health Summary' as validation_type,
    'Total Users: ' || (SELECT COUNT(*) FROM public.user_profiles WHERE is_active = TRUE) ||
    ', Total Teams: ' || (SELECT COUNT(*) FROM public.teams WHERE is_active = TRUE) ||
    ', Total Players: ' || (SELECT COUNT(*) FROM public.players WHERE is_active = TRUE) ||
    ', Total Tournaments: ' || (SELECT COUNT(*) FROM public.tournaments) ||
    ', Total Cities: ' || (SELECT COUNT(*) FROM public.cities WHERE is_active = TRUE) ||
    ', Total Sports: ' || (SELECT COUNT(*) FROM public.sports WHERE is_active = TRUE) as summary;