-- =====================================================
-- MOWE SPORT PLATFORM - MIGRATION VALIDATION
-- =====================================================
-- Description: Comprehensive validation of users table migration
-- Usage: Run after migration to verify data integrity
-- =====================================================

-- =====================================================
-- VALIDATION FUNCTIONS
-- =====================================================

-- Function to generate migration validation report
CREATE OR REPLACE FUNCTION public.validate_users_migration()
RETURNS TABLE (
    validation_category TEXT,
    test_name TEXT,
    expected_value BIGINT,
    actual_value BIGINT,
    status TEXT,
    details TEXT
) AS $$
DECLARE
    original_count BIGINT;
    migrated_count BIGINT;
    mapping_count BIGINT;
    role_assignments_count BIGINT;
    temp_emails_count BIGINT;
    super_admins_count BIGINT;
    active_users_count BIGINT;
    users_with_identification BIGINT;
BEGIN
    -- Get counts for validation
    SELECT COUNT(*) INTO original_count FROM public.users_original;
    SELECT COUNT(*) INTO migrated_count FROM public.user_profiles;
    SELECT COUNT(*) INTO mapping_count FROM public.user_id_mapping;
    SELECT COUNT(*) INTO role_assignments_count FROM public.user_roles_by_city_sport;
    SELECT COUNT(*) INTO temp_emails_count FROM public.user_profiles WHERE email LIKE '%@temp.local';
    SELECT COUNT(*) INTO super_admins_count FROM public.user_profiles WHERE primary_role = 'super_admin';
    SELECT COUNT(*) INTO active_users_count FROM public.user_profiles WHERE is_active = true;
    SELECT COUNT(*) INTO users_with_identification FROM public.user_profiles WHERE identification IS NOT NULL;
    
    -- Test 1: User count preservation
    RETURN QUERY SELECT 
        'Data Integrity'::TEXT,
        'User Count Preservation'::TEXT,
        original_count,
        migrated_count,
        CASE WHEN original_count = migrated_count THEN 'PASS' ELSE 'FAIL' END::TEXT,
        CASE WHEN original_count = migrated_count 
             THEN 'All users successfully migrated'
             ELSE 'User count mismatch - check for data loss' END::TEXT;
    
    -- Test 2: ID Mapping completeness
    RETURN QUERY SELECT 
        'Data Integrity'::TEXT,
        'ID Mapping Completeness'::TEXT,
        original_count,
        mapping_count,
        CASE WHEN original_count = mapping_count THEN 'PASS' ELSE 'FAIL' END::TEXT,
        CASE WHEN original_count = mapping_count 
             THEN 'All users have ID mappings'
             ELSE 'Some users missing ID mappings' END::TEXT;
    
    -- Test 3: Role assignments for non-super-admins
    RETURN QUERY SELECT 
        'Role Management'::TEXT,
        'Role Assignments Created'::TEXT,
        migrated_count - super_admins_count,
        role_assignments_count,
        CASE WHEN (migrated_count - super_admins_count) = role_assignments_count THEN 'PASS' ELSE 'FAIL' END::TEXT,
        CASE WHEN (migrated_count - super_admins_count) = role_assignments_count 
             THEN 'All non-super-admin users have role assignments'
             ELSE 'Some users missing role assignments' END::TEXT;
    
    -- Test 4: Email validity
    RETURN QUERY SELECT 
        'Data Quality'::TEXT,
        'Temporary Email Usage'::TEXT,
        0::BIGINT,
        temp_emails_count,
        CASE WHEN temp_emails_count = 0 THEN 'PASS' 
             WHEN temp_emails_count < (original_count * 0.1) THEN 'WARNING'
             ELSE 'FAIL' END::TEXT,
        CASE WHEN temp_emails_count = 0 THEN 'All users have valid emails'
             WHEN temp_emails_count < (original_count * 0.1) THEN temp_emails_count || ' users have temporary emails (acceptable)'
             ELSE temp_emails_count || ' users have temporary emails (review required)' END::TEXT;
    
    -- Test 5: Active users preservation
    RETURN QUERY SELECT 
        'Account Status'::TEXT,
        'Active Users Count'::TEXT,
        (SELECT COUNT(*) FROM public.users_original WHERE COALESCE(status, true) = true),
        active_users_count,
        CASE WHEN (SELECT COUNT(*) FROM public.users_original WHERE COALESCE(status, true) = true) = active_users_count 
             THEN 'PASS' ELSE 'WARNING' END::TEXT,
        'Active status preserved for ' || active_users_count || ' users'::TEXT;
    
    -- Test 6: Data completeness
    RETURN QUERY SELECT 
        'Data Completeness'::TEXT,
        'Users with Identification'::TEXT,
        (SELECT COUNT(*) FROM public.users_original WHERE document IS NOT NULL AND TRIM(document) != ''),
        users_with_identification,
        'INFO'::TEXT,
        users_with_identification || ' users have identification documents'::TEXT;
END;
$$ LANGUAGE plpgsql;

-- =====================================================
-- RUN COMPREHENSIVE VALIDATION
-- =====================================================

-- Execute validation and display results
SELECT * FROM public.validate_users_migration();

-- =====================================================
-- DETAILED DATA ANALYSIS
-- =====================================================

-- Role distribution analysis
SELECT 
    'Role Distribution' as analysis_type,
    primary_role,
    COUNT(*) as count,
    ROUND(COUNT(*) * 100.0 / (SELECT COUNT(*) FROM public.user_profiles), 2) as percentage
FROM public.user_profiles 
GROUP BY primary_role 
ORDER BY count DESC;

-- Account status analysis
SELECT 
    'Account Status Distribution' as analysis_type,
    account_status,
    COUNT(*) as count,
    ROUND(COUNT(*) * 100.0 / (SELECT COUNT(*) FROM public.user_profiles), 2) as percentage
FROM public.user_profiles 
GROUP BY account_status 
ORDER BY count DESC;

-- Email domain analysis
SELECT 
    'Email Domain Analysis' as analysis_type,
    CASE 
        WHEN email LIKE '%@temp.local' THEN 'Temporary Email'
        WHEN email LIKE '%@gmail.com' THEN 'Gmail'
        WHEN email LIKE '%@hotmail.com' OR email LIKE '%@outlook.com' THEN 'Microsoft'
        WHEN email LIKE '%@yahoo.com' THEN 'Yahoo'
        ELSE 'Other'
    END as email_domain,
    COUNT(*) as count
FROM public.user_profiles 
GROUP BY 
    CASE 
        WHEN email LIKE '%@temp.local' THEN 'Temporary Email'
        WHEN email LIKE '%@gmail.com' THEN 'Gmail'
        WHEN email LIKE '%@hotmail.com' OR email LIKE '%@outlook.com' THEN 'Microsoft'
        WHEN email LIKE '%@yahoo.com' THEN 'Yahoo'
        ELSE 'Other'
    END
ORDER BY count DESC;

-- Data completeness analysis
SELECT 
    'Data Completeness' as analysis_type,
    'Field Completeness' as metric,
    COUNT(*) as total_users,
    COUNT(phone) as users_with_phone,
    COUNT(identification) as users_with_identification,
    COUNT(CASE WHEN first_name != 'Usuario' THEN 1 END) as users_with_real_names,
    COUNT(CASE WHEN email NOT LIKE '%@temp.local' THEN 1 END) as users_with_real_emails
FROM public.user_profiles;

-- =====================================================
-- IDENTIFY POTENTIAL ISSUES
-- =====================================================

-- Users with potential data quality issues
SELECT 
    'Data Quality Issues' as issue_category,
    user_id,
    email,
    first_name,
    last_name,
    primary_role,
    ARRAY_AGG(
        CASE 
            WHEN email LIKE '%@temp.local' THEN 'Temporary Email'
            WHEN first_name = 'Usuario' THEN 'Default First Name'
            WHEN last_name = 'Apellido' THEN 'Default Last Name'
            WHEN identification IS NULL THEN 'Missing Identification'
            WHEN phone IS NULL THEN 'Missing Phone'
        END
    ) FILTER (WHERE 
        email LIKE '%@temp.local' OR 
        first_name = 'Usuario' OR 
        last_name = 'Apellido' OR 
        identification IS NULL OR 
        phone IS NULL
    ) as issues
FROM public.user_profiles
WHERE 
    email LIKE '%@temp.local' OR 
    first_name = 'Usuario' OR 
    last_name = 'Apellido' OR 
    identification IS NULL OR 
    phone IS NULL
GROUP BY user_id, email, first_name, last_name, primary_role
ORDER BY array_length(ARRAY_AGG(
    CASE 
        WHEN email LIKE '%@temp.local' THEN 'Temporary Email'
        WHEN first_name = 'Usuario' THEN 'Default First Name'
        WHEN last_name = 'Apellido' THEN 'Default Last Name'
        WHEN identification IS NULL THEN 'Missing Identification'
        WHEN phone IS NULL THEN 'Missing Phone'
    END
) FILTER (WHERE 
    email LIKE '%@temp.local' OR 
    first_name = 'Usuario' OR 
    last_name = 'Apellido' OR 
    identification IS NULL OR 
    phone IS NULL
), 1) DESC
LIMIT 10;

-- =====================================================
-- MIGRATION AUDIT LOG SUMMARY
-- =====================================================

-- Summary of migration-related audit logs
SELECT 
    action,
    COUNT(*) as occurrence_count,
    MIN(created_at) as first_occurrence,
    MAX(created_at) as last_occurrence
FROM public.audit_logs 
WHERE action IN (
    'MIGRATION_START',
    'MIGRATION_ANALYSIS',
    'MIGRATION_VALIDATION',
    'MIGRATION_COMPLETE'
)
GROUP BY action
ORDER BY first_occurrence;

-- =====================================================
-- RECOMMENDATIONS
-- =====================================================

-- Generate recommendations based on validation results
DO $$
DECLARE
    temp_email_count INTEGER;
    default_name_count INTEGER;
    missing_identification_count INTEGER;
    recommendations TEXT[];
BEGIN
    -- Count issues
    SELECT COUNT(*) INTO temp_email_count FROM public.user_profiles WHERE email LIKE '%@temp.local';
    SELECT COUNT(*) INTO default_name_count FROM public.user_profiles WHERE first_name = 'Usuario' OR last_name = 'Apellido';
    SELECT COUNT(*) INTO missing_identification_count FROM public.user_profiles WHERE identification IS NULL;
    
    -- Build recommendations
    recommendations := ARRAY[]::TEXT[];
    
    IF temp_email_count > 0 THEN
        recommendations := array_append(recommendations, 
            'RECOMMENDATION: ' || temp_email_count || ' users have temporary emails. Consider implementing email verification process.');
    END IF;
    
    IF default_name_count > 0 THEN
        recommendations := array_append(recommendations, 
            'RECOMMENDATION: ' || default_name_count || ' users have default names. Encourage users to update their profiles.');
    END IF;
    
    IF missing_identification_count > 0 THEN
        recommendations := array_append(recommendations, 
            'RECOMMENDATION: ' || missing_identification_count || ' users lack identification. This may be required for tournament registration.');
    END IF;
    
    -- Log recommendations
    INSERT INTO public.audit_logs (
        user_id,
        action,
        table_name,
        new_values
    ) VALUES (
        NULL,
        'MIGRATION_RECOMMENDATIONS',
        'user_profiles',
        json_build_object(
            'recommendations', recommendations,
            'temp_email_count', temp_email_count,
            'default_name_count', default_name_count,
            'missing_identification_count', missing_identification_count,
            'timestamp', NOW()
        )
    );
    
    -- Display recommendations
    FOR i IN 1..array_length(recommendations, 1) LOOP
        RAISE NOTICE '%', recommendations[i];
    END LOOP;
END $$;

-- =====================================================
-- CLEANUP VALIDATION FUNCTION
-- =====================================================

-- Drop the validation function after use
DROP FUNCTION IF EXISTS public.validate_users_migration();

-- =====================================================
-- FINAL VALIDATION LOG
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
    'MIGRATION_VALIDATION_COMPLETE',
    'user_profiles',
    '{"validation_type": "comprehensive_migration_validation", "status": "completed"}'::jsonb,
    '127.0.0.1'::inet,
    'Database Validation Script'
);

RAISE NOTICE 'Migration validation completed. Check the results above and audit logs for detailed information.';