-- =====================================================
-- MIGRATION 002: MIGRATE USERS DATA
-- =====================================================
-- Description: Migrate existing users table to user_profiles
-- Author: Migration System
-- Date: 2025-01-23
-- Dependencies: 001_create_initial_schema
-- =====================================================

-- =====================================================
-- BACKUP EXISTING DATA
-- =====================================================

-- Create backup table with current data
CREATE TABLE IF NOT EXISTS public.users_backup AS 
SELECT * FROM public.users;

-- Log migration start
INSERT INTO public.audit_logs (
    user_id,
    action,
    table_name,
    new_values,
    ip_address,
    user_agent
) VALUES (
    NULL,
    'MIGRATION_START',
    'users',
    '{"migration": "002_migrate_users_data", "backup_created": true}'::jsonb,
    '127.0.0.1'::inet,
    'Database Migration System'
);

-- =====================================================
-- HELPER FUNCTIONS
-- =====================================================

-- Function to clean and validate email
CREATE OR REPLACE FUNCTION clean_email(input_email TEXT) 
RETURNS TEXT AS $$
BEGIN
    IF input_email IS NULL OR TRIM(input_email) = '' THEN
        RETURN NULL;
    END IF;
    
    -- Basic email validation and cleaning
    input_email := LOWER(TRIM(input_email));
    
    -- Check if it looks like an email
    IF input_email ~ '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$' THEN
        RETURN input_email;
    ELSE
        RETURN NULL;
    END IF;
END;
$$ LANGUAGE plpgsql;

-- Function to map old roles to new roles
CREATE OR REPLACE FUNCTION map_user_role(old_role TEXT) 
RETURNS TEXT AS $$
BEGIN
    CASE LOWER(COALESCE(old_role, ''))
        WHEN 'admin' THEN RETURN 'city_admin';
        WHEN 'super_admin' THEN RETURN 'super_admin';
        WHEN 'superadmin' THEN RETURN 'super_admin';
        WHEN 'owner' THEN RETURN 'owner';
        WHEN 'coach' THEN RETURN 'coach';
        WHEN 'referee' THEN RETURN 'referee';
        WHEN 'player' THEN RETURN 'player';
        WHEN 'client' THEN RETURN 'client';
        WHEN 'user' THEN RETURN 'client';
        ELSE RETURN 'client';
    END CASE;
END;
$$ LANGUAGE plpgsql;

-- =====================================================
-- CREATE DEFAULT CITY AND SPORT
-- =====================================================

-- Insert default city for migration
INSERT INTO public.cities (city_id, name, region, country, timezone, is_active)
VALUES (
    '550e8400-e29b-41d4-a716-446655440000',
    'Ciudad por Defecto',
    'Región por Defecto',
    'Colombia',
    'America/Bogota',
    TRUE
) ON CONFLICT (city_id) DO NOTHING;

-- Insert default sport for migration
INSERT INTO public.sports (sport_id, name, description, default_match_duration, team_size, is_active)
VALUES (
    '660e8400-e29b-41d4-a716-446655440000',
    'Deporte por Defecto',
    'Deporte asignado durante migración',
    90,
    11,
    TRUE
) ON CONFLICT (sport_id) DO NOTHING;

-- =====================================================
-- MIGRATE USER DATA
-- =====================================================

-- Migrate users with valid emails first
INSERT INTO public.user_profiles (
    user_id,
    email,
    first_name,
    last_name,
    phone,
    identification,
    identification_type,
    primary_role,
    is_active,
    account_status,
    password_recovery_token,
    token_expiration_date,
    created_at,
    updated_at
)
SELECT 
    gen_random_uuid() as user_id,
    clean_email(u.email) as email,
    COALESCE(NULLIF(TRIM(u.name), ''), 'Usuario') as first_name,
    COALESCE(NULLIF(TRIM(u.last_name), ''), 'Apellido') as last_name,
    NULLIF(TRIM(u.phone), '') as phone,
    NULLIF(TRIM(u.document), '') as identification,
    CASE 
        WHEN LOWER(TRIM(COALESCE(u.document_type, ''))) IN ('cedula', 'cc') THEN 'cedula'
        WHEN LOWER(TRIM(COALESCE(u.document_type, ''))) IN ('passport', 'pasaporte') THEN 'passport'
        WHEN LOWER(TRIM(COALESCE(u.document_type, ''))) IN ('ti', 'tarjeta_identidad') THEN 'tarjeta_identidad'
        ELSE 'cedula'
    END as identification_type,
    map_user_role(u.role) as primary_role,
    COALESCE(u.status, true) as is_active,
    CASE 
        WHEN COALESCE(u.status, true) = true THEN 'active'
        ELSE 'suspended'
    END as account_status,
    NULLIF(TRIM(u.token_recovery), '') as password_recovery_token,
    CASE 
        WHEN u.token_expiration_date IS NOT NULL AND u.token_expiration_date != '' THEN
            u.token_expiration_date::timestamp with time zone
        ELSE NULL
    END as token_expiration_date,
    COALESCE(u.created_at, NOW()) as created_at,
    COALESCE(u.updated_at, NOW()) as updated_at
FROM public.users u
WHERE clean_email(u.email) IS NOT NULL
ON CONFLICT (email) DO NOTHING;

-- Handle users with invalid/duplicate emails
INSERT INTO public.user_profiles (
    user_id,
    email,
    first_name,
    last_name,
    phone,
    identification,
    identification_type,
    primary_role,
    is_active,
    account_status,
    password_recovery_token,
    token_expiration_date,
    created_at,
    updated_at
)
SELECT 
    gen_random_uuid() as user_id,
    'user' || u.id || '_' || extract(epoch from now())::bigint || '@temp.local' as email,
    COALESCE(NULLIF(TRIM(u.name), ''), 'Usuario') as first_name,
    COALESCE(NULLIF(TRIM(u.last_name), ''), 'Apellido') as last_name,
    NULLIF(TRIM(u.phone), '') as phone,
    NULLIF(TRIM(u.document), '') as identification,
    CASE 
        WHEN LOWER(TRIM(COALESCE(u.document_type, ''))) IN ('cedula', 'cc') THEN 'cedula'
        WHEN LOWER(TRIM(COALESCE(u.document_type, ''))) IN ('passport', 'pasaporte') THEN 'passport'
        WHEN LOWER(TRIM(COALESCE(u.document_type, ''))) IN ('ti', 'tarjeta_identidad') THEN 'tarjeta_identidad'
        ELSE 'cedula'
    END as identification_type,
    map_user_role(u.role) as primary_role,
    COALESCE(u.status, true) as is_active,
    CASE 
        WHEN COALESCE(u.status, true) = true THEN 'active'
        ELSE 'suspended'
    END as account_status,
    NULLIF(TRIM(u.token_recovery), '') as password_recovery_token,
    CASE 
        WHEN u.token_expiration_date IS NOT NULL AND u.token_expiration_date != '' THEN
            u.token_expiration_date::timestamp with time zone
        ELSE NULL
    END as token_expiration_date,
    COALESCE(u.created_at, NOW()) as created_at,
    COALESCE(u.updated_at, NOW()) as updated_at
FROM public.users u
WHERE clean_email(u.email) IS NULL 
   OR u.email IN (
       SELECT email 
       FROM public.users 
       WHERE email IS NOT NULL 
       GROUP BY email 
       HAVING COUNT(*) > 1
   );

-- =====================================================
-- CREATE ID MAPPING TABLE
-- =====================================================

-- Create mapping table to track old ID to new UUID mapping
CREATE TABLE IF NOT EXISTS public.user_id_mapping (
    old_id INTEGER,
    new_user_id UUID,
    email VARCHAR(255),
    created_at TIMESTAMP DEFAULT NOW()
);

-- Populate mapping table for users with valid emails
INSERT INTO public.user_id_mapping (old_id, new_user_id, email)
SELECT 
    u.id as old_id,
    up.user_id as new_user_id,
    up.email
FROM public.users u
JOIN public.user_profiles up ON clean_email(u.email) = up.email
WHERE clean_email(u.email) IS NOT NULL;

-- Populate mapping table for users with temporary emails
INSERT INTO public.user_id_mapping (old_id, new_user_id, email)
SELECT 
    u.id as old_id,
    up.user_id as new_user_id,
    up.email
FROM public.users u
JOIN public.user_profiles up ON up.email = ('user' || u.id || '_' || extract(epoch from now())::bigint || '@temp.local')
WHERE clean_email(u.email) IS NULL;

-- =====================================================
-- CREATE ROLE ASSIGNMENTS
-- =====================================================

-- Create role assignments for migrated users (except super_admin)
INSERT INTO public.user_roles_by_city_sport (
    user_id,
    city_id,
    sport_id,
    role_name,
    assigned_by_user_id,
    is_active
)
SELECT 
    up.user_id,
    '550e8400-e29b-41d4-a716-446655440000'::uuid as city_id,
    '660e8400-e29b-41d4-a716-446655440000'::uuid as sport_id,
    up.primary_role,
    NULL as assigned_by_user_id, -- System assignment
    TRUE as is_active
FROM public.user_profiles up
WHERE up.primary_role != 'super_admin' -- Super admins don't need city/sport assignment
ON CONFLICT (user_id, city_id, sport_id, role_name) DO NOTHING;

-- =====================================================
-- RENAME ORIGINAL TABLE
-- =====================================================

-- Rename original users table to keep as backup
ALTER TABLE public.users RENAME TO users_original;

-- =====================================================
-- CLEANUP HELPER FUNCTIONS
-- =====================================================

-- Drop helper functions
DROP FUNCTION IF EXISTS clean_email(TEXT);
DROP FUNCTION IF EXISTS map_user_role(TEXT);

-- =====================================================
-- VALIDATION AND LOGGING
-- =====================================================

-- Log migration completion with statistics
DO $$
DECLARE
    original_count INTEGER;
    migrated_count INTEGER;
    mapping_count INTEGER;
    role_assignments_count INTEGER;
BEGIN
    -- Count records
    SELECT COUNT(*) INTO original_count FROM public.users_original;
    SELECT COUNT(*) INTO migrated_count FROM public.user_profiles;
    SELECT COUNT(*) INTO mapping_count FROM public.user_id_mapping;
    SELECT COUNT(*) INTO role_assignments_count FROM public.user_roles_by_city_sport;
    
    -- Log completion
    INSERT INTO public.audit_logs (
        user_id,
        action,
        table_name,
        new_values
    ) VALUES (
        NULL,
        'MIGRATION_COMPLETE',
        'user_profiles',
        json_build_object(
            'migration', '002_migrate_users_data',
            'original_users_count', original_count,
            'migrated_users_count', migrated_count,
            'mapping_records_count', mapping_count,
            'role_assignments_count', role_assignments_count,
            'migration_success', (original_count = migrated_count AND mapping_count = original_count)
        )
    );
END $$;