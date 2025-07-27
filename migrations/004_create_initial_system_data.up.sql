-- =====================================================
-- MOWE SPORT PLATFORM - INITIAL SYSTEM DATA
-- =====================================================
-- Migration: 004_create_initial_system_data
-- Description: Create initial super admin user and test data
-- =====================================================

-- =====================================================
-- SUPER ADMIN USER CREATION
-- =====================================================
-- Create initial super admin user with secure credentials
-- Password: MoweSport2025! (hashed with bcrypt)

INSERT INTO public.user_profiles (
    user_id,
    email,
    password_hash,
    first_name,
    last_name,
    phone,
    identification,
    primary_role,
    is_active,
    account_status,
    two_factor_enabled,
    created_at,
    updated_at
) VALUES (
    '00000000-0000-0000-0000-000000000001',
    'admin@mowesport.com',
    '$2a$12$LQv3c1yqBWVHxkd0LHAkCOYz6TtxMQJqhN8/LewdBdXzgVjzZUOjG', -- MoweSport2025!
    'Super',
    'Admin',
    '+57 300 123 4567',
    '1234567890',
    'super_admin',
    TRUE,
    'active',
    FALSE,
    NOW(),
    NOW()
) ON CONFLICT (user_id) DO UPDATE SET
    email = EXCLUDED.email,
    password_hash = EXCLUDED.password_hash,
    first_name = EXCLUDED.first_name,
    last_name = EXCLUDED.last_name,
    phone = EXCLUDED.phone,
    identification = EXCLUDED.identification,
    primary_role = EXCLUDED.primary_role,
    is_active = EXCLUDED.is_active,
    account_status = EXCLUDED.account_status,
    updated_at = NOW();

-- =====================================================
-- CITY ADMIN USERS FOR MAJOR CITIES
-- =====================================================

-- Bogotá City Admin
INSERT INTO public.user_profiles (
    user_id,
    email,
    password_hash,
    first_name,
    last_name,
    phone,
    identification,
    primary_role,
    is_active,
    account_status,
    created_at,
    updated_at
) VALUES (
    '00000000-0000-0000-0000-000000000002',
    'admin.bogota@mowesport.com',
    '$2a$12$LQv3c1yqBWVHxkd0LHAkCOYz6TtxMQJqhN8/LewdBdXzgVjzZUOjG', -- MoweSport2025!
    'Carlos',
    'Rodríguez',
    '+57 301 234 5678',
    '1234567891',
    'city_admin',
    TRUE,
    'active',
    NOW(),
    NOW()
) ON CONFLICT (user_id) DO NOTHING;

-- Medellín City Admin
INSERT INTO public.user_profiles (
    user_id,
    email,
    password_hash,
    first_name,
    last_name,
    phone,
    identification,
    primary_role,
    is_active,
    account_status,
    created_at,
    updated_at
) VALUES (
    '00000000-0000-0000-0000-000000000003',
    'admin.medellin@mowesport.com',
    '$2a$12$LQv3c1yqBWVHxkd0LHAkCOYz6TtxMQJqhN8/LewdBdXzgVjzZUOjG', -- MoweSport2025!
    'María',
    'González',
    '+57 302 345 6789',
    '1234567892',
    'city_admin',
    TRUE,
    'active',
    NOW(),
    NOW()
) ON CONFLICT (user_id) DO NOTHING;

-- Cali City Admin
INSERT INTO public.user_profiles (
    user_id,
    email,
    password_hash,
    first_name,
    last_name,
    phone,
    identification,
    primary_role,
    is_active,
    account_status,
    created_at,
    updated_at
) VALUES (
    '00000000-0000-0000-0000-000000000004',
    'admin.cali@mowesport.com',
    '$2a$12$LQv3c1yqBWVHxkd0LHAkCOYz6TtxMQJqhN8/LewdBdXzgVjzZUOjG', -- MoweSport2025!
    'Luis',
    'Martínez',
    '+57 303 456 7890',
    '1234567893',
    'city_admin',
    TRUE,
    'active',
    NOW(),
    NOW()
) ON CONFLICT (user_id) DO NOTHING;

-- =====================================================
-- ASSIGN CITY ADMIN ROLES
-- =====================================================

-- Bogotá City Admin Role
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
    '10000000-0000-0000-0000-000000000001',
    '00000000-0000-0000-0000-000000000002',
    '550e8400-e29b-41d4-a716-446655440001', -- Bogotá
    NULL, -- All sports
    'city_admin',
    '00000000-0000-0000-0000-000000000001', -- Assigned by super admin
    TRUE,
    NOW()
) ON CONFLICT (user_id, city_id, sport_id, role_name) DO NOTHING;

-- Medellín City Admin Role
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
    '10000000-0000-0000-0000-000000000002',
    '00000000-0000-0000-0000-000000000003',
    '550e8400-e29b-41d4-a716-446655440002', -- Medellín
    NULL, -- All sports
    'city_admin',
    '00000000-0000-0000-0000-000000000001', -- Assigned by super admin
    TRUE,
    NOW()
) ON CONFLICT (user_id, city_id, sport_id, role_name) DO NOTHING;

-- Cali City Admin Role
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
    '10000000-0000-0000-0000-000000000003',
    '00000000-0000-0000-0000-000000000004',
    '550e8400-e29b-41d4-a716-446655440003', -- Cali
    NULL, -- All sports
    'city_admin',
    '00000000-0000-0000-0000-000000000001', -- Assigned by super admin
    TRUE,
    NOW()
) ON CONFLICT (user_id, city_id, sport_id, role_name) DO NOTHING;

-- =====================================================
-- SAMPLE TEAM OWNERS
-- =====================================================

-- Team Owner 1 - Bogotá
INSERT INTO public.user_profiles (
    user_id,
    email,
    password_hash,
    first_name,
    last_name,
    phone,
    identification,
    primary_role,
    is_active,
    account_status,
    created_at,
    updated_at
) VALUES (
    '00000000-0000-0000-0000-000000000010',
    'owner1@mowesport.com',
    '$2a$12$LQv3c1yqBWVHxkd0LHAkCOYz6TtxMQJqhN8/LewdBdXzgVjzZUOjG', -- MoweSport2025!
    'Diego',
    'Hernández',
    '+57 310 123 4567',
    '1234567900',
    'owner',
    TRUE,
    'active',
    NOW(),
    NOW()
) ON CONFLICT (user_id) DO NOTHING;

-- Team Owner 2 - Medellín
INSERT INTO public.user_profiles (
    user_id,
    email,
    password_hash,
    first_name,
    last_name,
    phone,
    identification,
    primary_role,
    is_active,
    account_status,
    created_at,
    updated_at
) VALUES (
    '00000000-0000-0000-0000-000000000011',
    'owner2@mowesport.com',
    '$2a$12$LQv3c1yqBWVHxkd0LHAkCOYz6TtxMQJqhN8/LewdBdXzgVjzZUOjG', -- MoweSport2025!
    'Ana',
    'López',
    '+57 311 234 5678',
    '1234567901',
    'owner',
    TRUE,
    'active',
    NOW(),
    NOW()
) ON CONFLICT (user_id) DO NOTHING;

-- =====================================================
-- ASSIGN OWNER ROLES
-- =====================================================

-- Owner 1 Role - Bogotá Football
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
    '10000000-0000-0000-0000-000000000010',
    '00000000-0000-0000-0000-000000000010',
    '550e8400-e29b-41d4-a716-446655440001', -- Bogotá
    '660e8400-e29b-41d4-a716-446655440001', -- Fútbol
    'owner',
    '00000000-0000-0000-0000-000000000002', -- Assigned by Bogotá admin
    TRUE,
    NOW()
) ON CONFLICT (user_id, city_id, sport_id, role_name) DO NOTHING;

-- Owner 2 Role - Medellín Football
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
    '10000000-0000-0000-0000-000000000011',
    '00000000-0000-0000-0000-000000000011',
    '550e8400-e29b-41d4-a716-446655440002', -- Medellín
    '660e8400-e29b-41d4-a716-446655440001', -- Fútbol
    'owner',
    '00000000-0000-0000-0000-000000000003', -- Assigned by Medellín admin
    TRUE,
    NOW()
) ON CONFLICT (user_id, city_id, sport_id, role_name) DO NOTHING;

-- =====================================================
-- SAMPLE TEAMS
-- =====================================================

-- Team 1 - Bogotá
INSERT INTO public.teams (
    team_id,
    name,
    short_name,
    description,
    owner_user_id,
    city_id,
    sport_id,
    primary_color,
    secondary_color,
    founded_date,
    home_venue,
    is_active,
    is_verified,
    created_at,
    updated_at
) VALUES (
    '20000000-0000-0000-0000-000000000001',
    'Águilas Doradas Bogotá',
    'ÁGUILAS',
    'Equipo de fútbol profesional de Bogotá',
    '00000000-0000-0000-0000-000000000010',
    '550e8400-e29b-41d4-a716-446655440001', -- Bogotá
    '660e8400-e29b-41d4-a716-446655440001', -- Fútbol
    '#FFD700',
    '#000000',
    '2020-01-15',
    'Estadio El Campín',
    TRUE,
    TRUE,
    NOW(),
    NOW()
) ON CONFLICT (team_id) DO NOTHING;

-- Team 2 - Medellín
INSERT INTO public.teams (
    team_id,
    name,
    short_name,
    description,
    owner_user_id,
    city_id,
    sport_id,
    primary_color,
    secondary_color,
    founded_date,
    home_venue,
    is_active,
    is_verified,
    created_at,
    updated_at
) VALUES (
    '20000000-0000-0000-0000-000000000002',
    'Leones de Medellín',
    'LEONES',
    'Equipo de fútbol tradicional de Medellín',
    '00000000-0000-0000-0000-000000000011',
    '550e8400-e29b-41d4-a716-446655440002', -- Medellín
    '660e8400-e29b-41d4-a716-446655440001', -- Fútbol
    '#FF0000',
    '#FFFFFF',
    '2019-03-10',
    'Estadio Atanasio Girardot',
    TRUE,
    TRUE,
    NOW(),
    NOW()
) ON CONFLICT (team_id) DO NOTHING;

-- =====================================================
-- SAMPLE PLAYERS
-- =====================================================

-- Player 1 - Águilas Doradas
INSERT INTO public.players (
    player_id,
    user_profile_id,
    first_name,
    last_name,
    date_of_birth,
    identification,
    blood_type,
    gender,
    nationality,
    email,
    phone,
    preferred_position,
    dominant_foot,
    is_active,
    is_available,
    created_at,
    updated_at
) VALUES (
    '30000000-0000-0000-0000-000000000001',
    NULL,
    'Juan',
    'Pérez',
    '1995-05-15',
    '1234567910',
    'O+',
    'male',
    'Colombian',
    'juan.perez@email.com',
    '+57 320 123 4567',
    'Delantero',
    'right',
    TRUE,
    TRUE,
    NOW(),
    NOW()
) ON CONFLICT (player_id) DO NOTHING;

-- Player 2 - Águilas Doradas
INSERT INTO public.players (
    player_id,
    user_profile_id,
    first_name,
    last_name,
    date_of_birth,
    identification,
    blood_type,
    gender,
    nationality,
    email,
    phone,
    preferred_position,
    dominant_foot,
    is_active,
    is_available,
    created_at,
    updated_at
) VALUES (
    '30000000-0000-0000-0000-000000000002',
    NULL,
    'Carlos',
    'Gómez',
    '1993-08-22',
    '1234567911',
    'A+',
    'male',
    'Colombian',
    'carlos.gomez@email.com',
    '+57 321 234 5678',
    'Portero',
    'right',
    TRUE,
    TRUE,
    NOW(),
    NOW()
) ON CONFLICT (player_id) DO NOTHING;

-- Player 3 - Leones de Medellín
INSERT INTO public.players (
    player_id,
    user_profile_id,
    first_name,
    last_name,
    date_of_birth,
    identification,
    blood_type,
    gender,
    nationality,
    email,
    phone,
    preferred_position,
    dominant_foot,
    is_active,
    is_available,
    created_at,
    updated_at
) VALUES (
    '30000000-0000-0000-0000-000000000003',
    NULL,
    'Miguel',
    'Rodríguez',
    '1994-12-03',
    '1234567912',
    'B+',
    'male',
    'Colombian',
    'miguel.rodriguez@email.com',
    '+57 322 345 6789',
    'Mediocampista',
    'left',
    TRUE,
    TRUE,
    NOW(),
    NOW()
) ON CONFLICT (player_id) DO NOTHING;

-- =====================================================
-- TEAM PLAYER ASSIGNMENTS
-- =====================================================

-- Assign players to Águilas Doradas
INSERT INTO public.team_players (
    team_player_id,
    team_id,
    player_id,
    join_date,
    is_active,
    position,
    jersey_number,
    is_captain,
    registered_by_user_id,
    created_at,
    updated_at
) VALUES 
(
    '40000000-0000-0000-0000-000000000001',
    '20000000-0000-0000-0000-000000000001', -- Águilas Doradas
    '30000000-0000-0000-0000-000000000001', -- Juan Pérez
    '2024-01-15',
    TRUE,
    'Delantero',
    9,
    TRUE,
    '00000000-0000-0000-0000-000000000010', -- Registered by owner
    NOW(),
    NOW()
),
(
    '40000000-0000-0000-0000-000000000002',
    '20000000-0000-0000-0000-000000000001', -- Águilas Doradas
    '30000000-0000-0000-0000-000000000002', -- Carlos Gómez
    '2024-01-15',
    TRUE,
    'Portero',
    1,
    FALSE,
    '00000000-0000-0000-0000-000000000010', -- Registered by owner
    NOW(),
    NOW()
) ON CONFLICT (team_player_id) DO NOTHING;

-- Assign player to Leones de Medellín
INSERT INTO public.team_players (
    team_player_id,
    team_id,
    player_id,
    join_date,
    is_active,
    position,
    jersey_number,
    is_captain,
    registered_by_user_id,
    created_at,
    updated_at
) VALUES (
    '40000000-0000-0000-0000-000000000003',
    '20000000-0000-0000-0000-000000000002', -- Leones de Medellín
    '30000000-0000-0000-0000-000000000003', -- Miguel Rodríguez
    '2024-02-01',
    TRUE,
    'Mediocampista',
    10,
    TRUE,
    '00000000-0000-0000-0000-000000000011', -- Registered by owner
    NOW(),
    NOW()
) ON CONFLICT (team_player_id) DO NOTHING;

-- =====================================================
-- SAMPLE TOURNAMENT
-- =====================================================

INSERT INTO public.tournaments (
    tournament_id,
    name,
    description,
    city_id,
    sport_id,
    admin_user_id,
    start_date,
    end_date,
    registration_deadline,
    max_teams,
    min_teams,
    entry_fee,
    status,
    is_public,
    tournament_format,
    location,
    created_at,
    updated_at
) VALUES (
    '50000000-0000-0000-0000-000000000001',
    'Copa Bogotá 2025',
    'Torneo de fútbol profesional de la ciudad de Bogotá',
    '550e8400-e29b-41d4-a716-446655440001', -- Bogotá
    '660e8400-e29b-41d4-a716-446655440001', -- Fútbol
    '00000000-0000-0000-0000-000000000002', -- Bogotá admin
    '2025-08-01',
    '2025-09-30',
    '2025-07-31',
    16,
    8,
    500000.00,
    'approved',
    TRUE,
    'knockout',
    'Bogotá, Colombia',
    NOW(),
    NOW()
) ON CONFLICT (tournament_id) DO NOTHING;

-- =====================================================
-- TOURNAMENT TEAM REGISTRATIONS
-- =====================================================

INSERT INTO public.tournament_teams (
    tournament_team_id,
    tournament_id,
    team_id,
    registration_date,
    status,
    approved_by_user_id,
    approval_date,
    registration_fee_paid,
    payment_date,
    created_at,
    updated_at
) VALUES 
(
    '60000000-0000-0000-0000-000000000001',
    '50000000-0000-0000-0000-000000000001', -- Copa Bogotá 2025
    '20000000-0000-0000-0000-000000000001', -- Águilas Doradas
    NOW() - INTERVAL '10 days',
    'approved',
    '00000000-0000-0000-0000-000000000002', -- Approved by Bogotá admin
    NOW() - INTERVAL '5 days',
    TRUE,
    NOW() - INTERVAL '7 days',
    NOW(),
    NOW()
) ON CONFLICT (tournament_team_id) DO NOTHING;

-- =====================================================
-- AUDIT LOG FOR INITIAL DATA CREATION
-- =====================================================

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
    'INITIAL_DATA_CREATED',
    'system_initialization',
    NULL,
    '{
        "message": "Initial system data created successfully",
        "super_admin_created": true,
        "city_admins_created": 3,
        "sample_teams_created": 2,
        "sample_players_created": 3,
        "sample_tournament_created": 1,
        "migration": "004_create_initial_system_data"
    }'::jsonb,
    '127.0.0.1'::inet,
    'Mowe Sport Database Migration'
);

-- =====================================================
-- DATA INTEGRITY VALIDATION
-- =====================================================

-- Verify all foreign key relationships are valid
DO $$
DECLARE
    integrity_check_result BOOLEAN := TRUE;
    error_message TEXT := '';
BEGIN
    -- Check user_roles_by_city_sport references
    IF EXISTS (
        SELECT 1 FROM public.user_roles_by_city_sport ur
        LEFT JOIN public.user_profiles up ON ur.user_id = up.user_id
        WHERE up.user_id IS NULL
    ) THEN
        integrity_check_result := FALSE;
        error_message := 'Invalid user_id in user_roles_by_city_sport';
    END IF;
    
    -- Check team ownership references
    IF EXISTS (
        SELECT 1 FROM public.teams t
        LEFT JOIN public.user_profiles up ON t.owner_user_id = up.user_id
        WHERE up.user_id IS NULL
    ) THEN
        integrity_check_result := FALSE;
        error_message := 'Invalid owner_user_id in teams';
    END IF;
    
    -- Check team_players references
    IF EXISTS (
        SELECT 1 FROM public.team_players tp
        LEFT JOIN public.teams t ON tp.team_id = t.team_id
        LEFT JOIN public.players p ON tp.player_id = p.player_id
        WHERE t.team_id IS NULL OR p.player_id IS NULL
    ) THEN
        integrity_check_result := FALSE;
        error_message := 'Invalid references in team_players';
    END IF;
    
    -- Log validation result
    INSERT INTO public.audit_logs (
        user_id,
        action,
        table_name,
        new_values,
        ip_address,
        user_agent
    ) VALUES (
        '00000000-0000-0000-0000-000000000001',
        'DATA_INTEGRITY_CHECK',
        'system_validation',
        json_build_object(
            'integrity_check_passed', integrity_check_result,
            'error_message', error_message,
            'check_timestamp', NOW()
        ),
        '127.0.0.1'::inet,
        'Mowe Sport Database Migration'
    );
    
    IF NOT integrity_check_result THEN
        RAISE EXCEPTION 'Data integrity check failed: %', error_message;
    END IF;
END $$;