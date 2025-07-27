-- =====================================================
-- MOWE SPORT PLATFORM - INITIAL SYSTEM DATA ROLLBACK
-- =====================================================
-- Migration: 004_create_initial_system_data (DOWN)
-- Description: Rollback initial system data creation
-- =====================================================

-- Delete in reverse dependency order

-- Delete tournament team registrations
DELETE FROM public.tournament_teams WHERE tournament_team_id IN (
    '60000000-0000-0000-0000-000000000001'
);

-- Delete sample tournament
DELETE FROM public.tournaments WHERE tournament_id = '50000000-0000-0000-0000-000000000001';

-- Delete team player assignments
DELETE FROM public.team_players WHERE team_player_id IN (
    '40000000-0000-0000-0000-000000000001',
    '40000000-0000-0000-0000-000000000002',
    '40000000-0000-0000-0000-000000000003'
);

-- Delete sample players
DELETE FROM public.players WHERE player_id IN (
    '30000000-0000-0000-0000-000000000001',
    '30000000-0000-0000-0000-000000000002',
    '30000000-0000-0000-0000-000000000003'
);

-- Delete sample teams
DELETE FROM public.teams WHERE team_id IN (
    '20000000-0000-0000-0000-000000000001',
    '20000000-0000-0000-0000-000000000002'
);

-- Delete role assignments
DELETE FROM public.user_roles_by_city_sport WHERE role_assignment_id IN (
    '10000000-0000-0000-0000-000000000001',
    '10000000-0000-0000-0000-000000000002',
    '10000000-0000-0000-0000-000000000003',
    '10000000-0000-0000-0000-000000000010',
    '10000000-0000-0000-0000-000000000011'
);

-- Delete sample users (keep super admin)
DELETE FROM public.user_profiles WHERE user_id IN (
    '00000000-0000-0000-0000-000000000002',
    '00000000-0000-0000-0000-000000000003',
    '00000000-0000-0000-0000-000000000004',
    '00000000-0000-0000-0000-000000000010',
    '00000000-0000-0000-0000-000000000011'
);

-- Optionally delete super admin (commented out for safety)
-- DELETE FROM public.user_profiles WHERE user_id = '00000000-0000-0000-0000-000000000001';

-- Delete audit logs related to initial data
DELETE FROM public.audit_logs WHERE action IN ('INITIAL_DATA_CREATED', 'DATA_INTEGRITY_CHECK');