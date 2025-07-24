-- =====================================================
-- MOWE SPORT PLATFORM - USER TABLE MIGRATION
-- =====================================================
-- Description: Migrate existing users table to new schema
-- Dependencies: Complete schema must be created first
-- Execution Order: After schema creation, before RLS policies
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
    '{"migration_type": "users_to_user_profiles", "backup_created": true}'::jsonb,
    '127.0.0.1'::inet,
    'Database Migration Script'
);

-- =====================================================
-- DATA ANALYSIS AND VALIDATION
-- =====================================================

-- Analyze current data structure
DO $$
DECLARE
    total_users INTEGER;
    users_with_email INTEGER;
    users_with_role INTEGER;
    duplicate_emails INTEGER;
BEGIN
    -- Count total users
    SELECT COUNT(*) INTO total_users FROM public.users;
    
    -- Count users with email
    SELECT COUNT(*) INTO users_with_email FROM public.users WHERE email IS NOT NULL AND email != '';
    
    -- Count users with role
    SELECT COUNT(*) INTO users_with_role FROM public.users WHERE role IS NOT NULL AND role != '';
    
    -- Count duplicate emails
    SELECT COUNT(*) - COUNT(DISTINCT email) INTO duplicate_emails 
    FROM public.users 
    WHERE email IS NOT NULL AND email != '';
    
    -- Log analysis results
    INSERT INTO public.audit_logs (
        user_id,
        action,
        table_name,
        new_values
    ) VALUES (
        NULL,
        'MIGRATION_ANALYSIS',
        'users',
        json_build_object(
            'total_users', total_users,
            'users_with_email', users_with_email,
            'users_with_role', users_with_role,
            'duplicate_emails', duplicate_emails
        )
    );
    
    -- Raise warning if there are issues
    IF duplicate_emails > 0 THEN
        RAISE WARNING 'Found % duplicate emails in users table', duplicate_emails;
    END IF;
END $$;

-- =====================================================
-- CREATE NEW USER_PROFILES TABLE STRUCTURE
-- =====================================================

-- Drop existing user_profiles if it exists (for clean migration)
DROP TABLE IF EXISTS public.user_profiles CASCADE;

-- Create new user_profiles table with complete structure
CREATE TABLE public.user_profiles (
    user_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    email VARCHAR(255) NOT NULL UNIQUE,
    first_name VARCHAR(100) NOT NULL,
    last_name VARCHAR(100) NOT NULL,
    phone VARCHAR(20),
    identification VARCHAR(50),
    identification_type VARCHAR(20) DEFAULT 'cedula',
    photo_url TEXT,
    date_of_birth DATE,
    gender VARCHAR(10),
    nationality VARCHAR(50) DEFAULT 'Colombia',
    address TEXT,
    emergency_contact_name TEXT,
    emergency_contact_phone TEXT,
    primary_role VARCHAR(20) NOT NULL DEFAULT 'client' 
        CHECK (primary_role IN ('super_admin', 'city_admin', 'tournament_admin', 'owner', 'coach', 'referee', 'player', 'client')),
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    account_status VARCHAR(20) NOT NULL DEFAULT 'active' 
        CHECK (account_status IN ('active', 'suspended', 'payment_pending', 'disabled')),
    last_login_at TIMESTAMP WITH TIME ZONE,
    failed_login_attempts INTEGER NOT NULL DEFAULT 0,
    locked_until TIMESTAMP WITH TIME ZONE,
    password_recovery_token VARCHAR(255),
    token_expiration_date TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW()
);

-- Create indexes for performance
CREATE INDEX idx_user_profiles_email ON public.user_profiles(email);
CREATE INDEX idx_user_profiles_role ON public.user_profiles(primary_role);
CREATE INDEX idx_user_profiles_active ON public.user_profiles(is_active);
CREATE INDEX idx_user_profiles_status ON public.user_profiles(account_status);

-- =====================================================
-- MIGRATE DATA FROM USERS TO USER_PROFILES
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

-- Migrate data with proper transformations
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
    COALESCE(clean_email(u.email), 'user' || u.id || '@temp.local') as email,
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

-- Handle users with invalid/duplicate emails by creating unique emails
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
WHERE clean_email(u.email) IS NULL OR u.email IN (
    SELECT email 
    FROM public.users 
    WHERE email IS NOT NULL 
    GROUP BY email 
    HAVING COUNT(*) > 1
);

-- =====================================================
-- CREATE MAPPING TABLE FOR OLD TO NEW IDS
-- =====================================================

-- Create mapping table to track old ID to new UUID mapping
CREATE TABLE public.user_id_mapping (
    old_id INTEGER,
    new_user_id UUID,
    email VARCHAR(255),
    created_at TIMESTAMP DEFAULT NOW()
);

-- Populate mapping table
INSERT INTO public.user_id_mapping (old_id, new_user_id, email)
SELECT 
    u.id as old_id,
    up.user_id as new_user_id,
    up.email
FROM public.users u
JOIN public.user_profiles up ON (
    (clean_email(u.email) IS NOT NULL AND up.email = clean_email(u.email)) OR
    (clean_email(u.email) IS NULL AND up.email = 'user' || u.id || '_' || extract(epoch from now())::bigint || '@temp.local')
);

-- =====================================================
-- CREATE DEFAULT CITY AND SPORT FOR MIGRATION
-- =====================================================

-- Insert default city if not exists
INSERT INTO public.cities (city_id, name, region, country, timezone, is_active)
VALUES (
    '550e8400-e29b-41d4-a716-446655440000',
    'Ciudad por Defecto',
    'Región por Defecto',
    'Colombia',
    'America/Bogota',
    TRUE
) ON CONFLICT (city_id) DO NOTHING;

-- Insert default sport if not exists
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
-- CREATE INITIAL ROLE ASSIGNMENTS
-- =====================================================

-- Create role assignments for migrated users
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
-- VALIDATION AND REPORTING
-- =====================================================

-- Create validation report
DO $$
DECLARE
    original_count INTEGER;
    migrated_count INTEGER;
    mapping_count INTEGER;
    role_assignments_count INTEGER;
    validation_report JSONB;
BEGIN
    -- Count original users
    SELECT COUNT(*) INTO original_count FROM public.users;
    
    -- Count migrated users
    SELECT COUNT(*) INTO migrated_count FROM public.user_profiles;
    
    -- Count mappings
    SELECT COUNT(*) INTO mapping_count FROM public.user_id_mapping;
    
    -- Count role assignments
    SELECT COUNT(*) INTO role_assignments_count FROM public.user_roles_by_city_sport;
    
    -- Build validation report
    validation_report := json_build_object(
        'original_users_count', original_count,
        'migrated_users_count', migrated_count,
        'mapping_records_count', mapping_count,
        'role_assignments_count', role_assignments_count,
        'migration_success', (original_count = migrated_count AND mapping_count = original_count),
        'timestamp', NOW()
    );
    
    -- Log validation results
    INSERT INTO public.audit_logs (
        user_id,
        action,
        table_name,
        new_values
    ) VALUES (
        NULL,
        'MIGRATION_VALIDATION',
        'user_profiles',
        validation_report
    );
    
    -- Raise notice with results
    RAISE NOTICE 'Migration completed: Original=%, Migrated=%, Mapped=%, Roles=%', 
        original_count, migrated_count, mapping_count, role_assignments_count;
END $$;

-- =====================================================
-- RENAME ORIGINAL TABLE
-- =====================================================

-- Rename original users table to keep as backup
ALTER TABLE public.users RENAME TO users_original;

-- =====================================================
-- CREATE UPDATED TIMESTAMP TRIGGER
-- =====================================================

-- Create trigger function for updated_at
CREATE OR REPLACE FUNCTION public.update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create trigger for user_profiles
CREATE TRIGGER update_user_profiles_updated_at
    BEFORE UPDATE ON public.user_profiles
    FOR EACH ROW
    EXECUTE FUNCTION public.update_updated_at_column();

-- =====================================================
-- CLEANUP HELPER FUNCTIONS
-- =====================================================

-- Drop helper functions
DROP FUNCTION IF EXISTS clean_email(TEXT);
DROP FUNCTION IF EXISTS map_user_role(TEXT);

-- =====================================================
-- FINAL MIGRATION LOG
-- =====================================================

INSERT INTO public.audit_logs (
    user_id,
    action,
    table_name,
    new_values,
    ip_address,
    user_agent
) VALUES (
    NULL,
    'MIGRATION_COMPLETE',
    'user_profiles',
    '{"migration_type": "users_to_user_profiles", "status": "completed", "original_table_renamed": "users_original"}'::jsonb,
    '127.0.0.1'::inet,
    'Database Migration Script'
);

-- =====================================================
-- VERIFICATION QUERIES (COMMENTED)
-- =====================================================

/*
-- Run these queries to verify migration success:

-- Check migration counts
SELECT 
    'Original' as table_name, COUNT(*) as count FROM public.users_original
UNION ALL
SELECT 
    'Migrated' as table_name, COUNT(*) as count FROM public.user_profiles
UNION ALL
SELECT 
    'Mappings' as table_name, COUNT(*) as count FROM public.user_id_mapping;

-- Check role distribution
SELECT primary_role, COUNT(*) as count 
FROM public.user_profiles 
GROUP BY primary_role 
ORDER BY count DESC;

-- Check account status distribution
SELECT account_status, COUNT(*) as count 
FROM public.user_profiles 
GROUP BY account_status;

-- Check for any data issues
SELECT 
    COUNT(*) as total_users,
    COUNT(CASE WHEN email LIKE '%@temp.local' THEN 1 END) as temp_emails,
    COUNT(CASE WHEN first_name = 'Usuario' THEN 1 END) as default_names,
    COUNT(CASE WHEN identification IS NOT NULL THEN 1 END) as with_identification
FROM public.user_profiles;

-- Check role assignments
SELECT 
    ur.role_name,
    COUNT(*) as assignments_count
FROM public.user_roles_by_city_sport ur
GROUP BY ur.role_name
ORDER BY assignments_count DESC;
*/