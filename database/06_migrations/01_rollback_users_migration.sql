-- =====================================================
-- MOWE SPORT PLATFORM - ROLLBACK USER MIGRATION
-- =====================================================
-- Description: Rollback users table migration to original state
-- Usage: Execute only if migration needs to be reverted
-- WARNING: This will lose any data created after migration
-- =====================================================

-- =====================================================
-- VALIDATION BEFORE ROLLBACK
-- =====================================================

DO $$
DECLARE
    backup_exists BOOLEAN;
    original_exists BOOLEAN;
BEGIN
    -- Check if backup table exists
    SELECT EXISTS (
        SELECT FROM information_schema.tables 
        WHERE table_schema = 'public' 
        AND table_name = 'users_backup'
    ) INTO backup_exists;
    
    -- Check if original renamed table exists
    SELECT EXISTS (
        SELECT FROM information_schema.tables 
        WHERE table_schema = 'public' 
        AND table_name = 'users_original'
    ) INTO original_exists;
    
    IF NOT backup_exists AND NOT original_exists THEN
        RAISE EXCEPTION 'No backup tables found. Cannot perform rollback safely.';
    END IF;
    
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
        'ROLLBACK_START',
        'users',
        json_build_object(
            'backup_exists', backup_exists,
            'original_exists', original_exists,
            'timestamp', NOW()
        ),
        '127.0.0.1'::inet,
        'Database Rollback Script'
    );
END $$;

-- =====================================================
-- BACKUP CURRENT STATE BEFORE ROLLBACK
-- =====================================================

-- Create backup of current migrated state
CREATE TABLE IF NOT EXISTS public.user_profiles_pre_rollback AS 
SELECT * FROM public.user_profiles;

CREATE TABLE IF NOT EXISTS public.user_roles_by_city_sport_pre_rollback AS 
SELECT * FROM public.user_roles_by_city_sport;

CREATE TABLE IF NOT EXISTS public.user_id_mapping_pre_rollback AS 
SELECT * FROM public.user_id_mapping;

-- =====================================================
-- REMOVE MIGRATED TABLES AND DATA
-- =====================================================

-- Drop triggers first
DROP TRIGGER IF EXISTS update_user_profiles_updated_at ON public.user_profiles;

-- Drop new tables created during migration
DROP TABLE IF EXISTS public.user_profiles CASCADE;
DROP TABLE IF EXISTS public.user_roles_by_city_sport CASCADE;
DROP TABLE IF EXISTS public.user_id_mapping CASCADE;
DROP TABLE IF EXISTS public.user_view_permissions CASCADE;

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
-- RECREATE ORIGINAL INDEXES AND CONSTRAINTS
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

-- Recreate unique constraint on email if needed
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT constraint_name 
        FROM information_schema.table_constraints 
        WHERE table_name = 'users' 
        AND constraint_type = 'UNIQUE'
        AND constraint_name LIKE '%email%'
    ) THEN
        ALTER TABLE public.users ADD CONSTRAINT users_email_unique UNIQUE (email);
    END IF;
EXCEPTION
    WHEN duplicate_key THEN
        RAISE NOTICE 'Email unique constraint not added due to duplicate values';
END $$;

-- =====================================================
-- REMOVE MIGRATION-SPECIFIC FUNCTIONS
-- =====================================================

-- Drop functions created during migration
DROP FUNCTION IF EXISTS public.update_updated_at_column();

-- =====================================================
-- CLEAN UP AUDIT LOGS
-- =====================================================

-- Optionally remove migration-related audit logs
-- Uncomment if you want to clean up audit trail
/*
DELETE FROM public.audit_logs 
WHERE action IN (
    'MIGRATION_START',
    'MIGRATION_ANALYSIS', 
    'MIGRATION_VALIDATION',
    'MIGRATION_COMPLETE'
);
*/

-- =====================================================
-- FINAL ROLLBACK LOG
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
    'ROLLBACK_COMPLETE',
    'users',
    json_build_object(
        'rollback_type', 'users_migration_rollback',
        'status', 'completed',
        'backup_tables_created', true,
        'timestamp', NOW()
    ),
    '127.0.0.1'::inet,
    'Database Rollback Script'
);

-- =====================================================
-- VERIFICATION QUERIES (COMMENTED)
-- =====================================================

/*
-- Run these queries to verify rollback success:

-- Check that users table is restored
SELECT COUNT(*) as user_count FROM public.users;

-- Check table structure
\d public.users;

-- Verify no migration tables exist
SELECT table_name 
FROM information_schema.tables 
WHERE table_schema = 'public' 
AND table_name IN ('user_profiles', 'user_roles_by_city_sport', 'user_id_mapping');

-- Check backup tables were created
SELECT table_name 
FROM information_schema.tables 
WHERE table_schema = 'public' 
AND table_name LIKE '%_pre_rollback';
*/

-- =====================================================
-- ROLLBACK NOTES
-- =====================================================

/*
IMPORTANT NOTES AFTER ROLLBACK:

1. BACKUP TABLES CREATED:
   - user_profiles_pre_rollback: Contains migrated user profiles
   - user_roles_by_city_sport_pre_rollback: Contains role assignments
   - user_id_mapping_pre_rollback: Contains ID mappings
   
2. ORIGINAL STATE RESTORED:
   - users table restored from users_original or users_backup
   - Original constraints and indexes recreated
   
3. DATA CONSIDERATIONS:
   - Any data created after migration will be lost
   - User authentication may need to be reconfigured
   - Application code may need to be updated to use old schema
   
4. CLEANUP RECOMMENDATIONS:
   - Review and remove backup tables when no longer needed
   - Update application configuration if necessary
   - Test authentication and user management functionality
   
5. RE-MIGRATION:
   - If you need to re-run migration, ensure all backup tables are cleaned up first
   - Review and fix any issues that caused the rollback need
*/