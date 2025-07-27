-- =====================================================
-- MOWE SPORT PLATFORM - FIX PASSWORD HASHES ROLLBACK
-- =====================================================
-- Migration: 005_fix_password_hashes (DOWN)
-- Description: Rollback password hash fixes
-- =====================================================

-- Revert to the old (incorrect) password hash
UPDATE public.user_profiles 
SET password_hash = '$2a$12$LQv3c1yqBWVHxkd0LHAkCOYz6TtxMQJqhN8/LewdBdXzgVrqUfLrm',
    updated_at = NOW()
WHERE password_hash = '$2a$12$IafTzL7jg7UGML0rCF0ZWOlATANGkuljqy3iLGP0Qs7IfvXblxkAW';

-- Remove the audit log entry
DELETE FROM public.audit_logs 
WHERE action = 'SYSTEM_INIT' 
AND new_values->>'message' = 'Password hashes corrected for all users';