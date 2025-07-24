-- =====================================================
-- MIGRATION 002 ROLLBACK: RESTORE USERS DATA
-- =====================================================
-- Description: Rollback users data migration
-- Author: Migration System
-- Date: 2025-01-23
-- WARNING: This will restore original users table and remove migrated data
-- =====================================================

-- Log rollback start
INSERT INTO public.audit_logs (
    user_id,
    action,
    table_name,
    new_values,
    ip_address,
    user_agent
) VALUES (
    NULL,
    'MIGRATION_ROLLBACK_START',
    'users',
    '{"migration": "002_migrate_users_data", "action": "rollback"}'::jsonb,
    '127.0.0.1'::inet,
    'Database Migration System'
);

-- =====================================================
-- BACKUP CURRENT MIGRATED STATE
-- =====================================================

-- Create backup of migrated state before rollback
CREATE TABLE IF NOT EXISTS public.user_profiles_pre_rollback AS 
SELECT * FROM public.user_profiles;

CREATE TABLE IF NOT EXISTS public.user_roles_by_city_sport_pre_rollback AS 
SELECT * FROM public.user_roles_by_city_sport;

CREATE TABLE IF NOT EXISTS public.user_id_mapping_pre_rollback AS 
SELECT * FROM public.user_id_mapping;

-- =====================================================
-- REMOVE MIGRATED DATA
-- =====================================================

-- Remove role assignments created during migration
DELETE FROM public.user_roles_by_city_sport 
WHERE city_id = '550e8400-e29b-41d4-a716-446655440000'
   OR sport_id = '660e8400-e29b-41d4-a716-446655440000';

-- Remove migrated user profiles
DELETE FROM public.user_profiles;

-- Remove ID mapping
DROP TABLE IF EXISTS public.user_id_mapping;

-- Remove default city and sport created for migration
DELETE FROM public.cities WHERE city_id = '550e8400-e29b-41d4-a716-446655440000';
DELETE FROM public.sports WHERE sport_id = '660e8400-e29b-41d4-a716-446655440000';

-- =====================================================
-- RESTORE ORIGINAL USERS TABLE
-- =====================================================

-- Restore from users_original if it exists
DO $$
BEGIN
    IF EXISTS (
        SELECT FROM information_schema.tables 
        WHERE table_schema = 'public' 
        AND table_name = 'users_original'
    ) THEN
        -- Rename users_original back to users
        ALTER TABLE public.users_original RENAME TO users;
        
        RAISE NOTICE 'Restored users table from users_original';
    ELSIF EXISTS (
        SELECT FROM information_schema.tables 
        WHERE table_schema = 'public' 
        AND table_name = 'users_backup'
    ) THEN
        -- Restore from backup if original doesn't exist
        CREATE TABLE public.users AS SELECT * FROM public.users_backup;
        
        RAISE NOTICE 'Restored users table from users_backup';
    ELSE
        RAISE EXCEPTION 'No backup table found for restoration';
    END IF;
END $$;

-- =====================================================
-- RECREATE ORIGINAL CONSTRAINTS
-- =====================================================

-- Recreate primary key if needed
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT constraint_name 
        FROM information_schema.table_constraints 
        WHERE table_name = 'users' 
        AND constraint_type = 'PRIMARY KEY'
    ) THEN
        ALTER TABLE public.users ADD PRIMARY KEY (id);
    END IF;
END $$;

-- =====================================================
-- LOG ROLLBACK COMPLETION
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
    'MIGRATION_ROLLBACK_COMPLETE',
    'users',
    '{"migration": "002_migrate_users_data", "action": "rollback_complete", "backup_tables_created": true}'::jsonb,
    '127.0.0.1'::inet,
    'Database Migration System'
);