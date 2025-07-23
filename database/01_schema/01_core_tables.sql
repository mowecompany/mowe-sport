-- =====================================================
-- MOWE SPORT PLATFORM - CORE TABLES
-- =====================================================
-- Description: Core tables for cities, sports, and user management
-- Dependencies: Supabase Auth (auth.users table)
-- Execution Order: 1st
-- =====================================================

-- Enable UUID extension if not already enabled
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- =====================================================
-- CITIES TABLE
-- =====================================================
-- Stores information about cities/municipalities using the platform
CREATE TABLE public.cities (
    city_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name VARCHAR(100) NOT NULL UNIQUE,
    region VARCHAR(100),
    country VARCHAR(100) NOT NULL DEFAULT 'Colombia',
    timezone VARCHAR(50) DEFAULT 'America/Bogota',
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW()
);

-- Add comment for documentation
COMMENT ON TABLE public.cities IS 'Cities and municipalities that use the Mowe Sport platform';
COMMENT ON COLUMN public.cities.timezone IS 'Timezone for scheduling matches and events';

-- =====================================================
-- SPORTS TABLE
-- =====================================================
-- Stores available sports in the platform
CREATE TABLE public.sports (
    sport_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name VARCHAR(100) NOT NULL UNIQUE,
    description TEXT,
    rules JSONB,
    default_match_duration INTEGER DEFAULT 90, -- in minutes
    team_size INTEGER DEFAULT 11, -- default players per team
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW()
);

-- Add comment for documentation
COMMENT ON TABLE public.sports IS 'Available sports in the platform';
COMMENT ON COLUMN public.sports.rules IS 'Sport-specific rules in JSON format';
COMMENT ON COLUMN public.sports.default_match_duration IS 'Default match duration in minutes';

-- =====================================================
-- USER PROFILES TABLE
-- =====================================================
-- Extends Supabase auth.users with platform-specific information
CREATE TABLE public.user_profiles (
    user_id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    email VARCHAR(255) NOT NULL UNIQUE,
    first_name VARCHAR(100) NOT NULL,
    last_name VARCHAR(100) NOT NULL,
    phone VARCHAR(20),
    identification VARCHAR(50) UNIQUE,
    photo_url TEXT,
    primary_role VARCHAR(20) NOT NULL CHECK (
        primary_role IN (
            'super_admin', 
            'city_admin', 
            'tournament_admin', 
            'owner', 
            'coach', 
            'referee', 
            'player', 
            'client'
        )
    ),
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    account_status VARCHAR(20) NOT NULL DEFAULT 'active' CHECK (
        account_status IN (
            'active', 
            'suspended', 
            'payment_pending', 
            'disabled'
        )
    ),
    last_login_at TIMESTAMP WITH TIME ZONE,
    failed_login_attempts INTEGER NOT NULL DEFAULT 0,
    locked_until TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW()
);

-- Add comment for documentation
COMMENT ON TABLE public.user_profiles IS 'Extended user profiles with platform-specific information';
COMMENT ON COLUMN public.user_profiles.primary_role IS 'Primary role of the user in the system';
COMMENT ON COLUMN public.user_profiles.account_status IS 'Account status for payment and access control';
COMMENT ON COLUMN public.user_profiles.failed_login_attempts IS 'Counter for failed login attempts';
COMMENT ON COLUMN public.user_profiles.locked_until IS 'Account lock expiration timestamp';

-- =====================================================
-- USER ROLES BY CITY/SPORT TABLE
-- =====================================================
-- Granular role assignments per city and sport
CREATE TABLE public.user_roles_by_city_sport (
    role_assignment_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES public.user_profiles(user_id) ON DELETE CASCADE,
    city_id UUID REFERENCES public.cities(city_id) ON DELETE CASCADE,
    sport_id UUID REFERENCES public.sports(sport_id) ON DELETE CASCADE,
    role_name VARCHAR(20) NOT NULL CHECK (
        role_name IN (
            'city_admin', 
            'tournament_admin', 
            'owner', 
            'coach', 
            'referee', 
            'player', 
            'client'
        )
    ),
    assigned_by_user_id UUID REFERENCES public.user_profiles(user_id),
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    
    -- Ensure unique role assignment per user/city/sport combination
    UNIQUE(user_id, city_id, sport_id, role_name)
);

-- Add comment for documentation
COMMENT ON TABLE public.user_roles_by_city_sport IS 'Granular role assignments per city and sport';
COMMENT ON COLUMN public.user_roles_by_city_sport.city_id IS 'NULL means role applies to all cities';
COMMENT ON COLUMN public.user_roles_by_city_sport.sport_id IS 'NULL means role applies to all sports';

-- =====================================================
-- USER VIEW PERMISSIONS TABLE
-- =====================================================
-- Fine-grained view-level permissions for users
CREATE TABLE public.user_view_permissions (
    permission_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES public.user_profiles(user_id) ON DELETE CASCADE,
    role_name VARCHAR(20),
    view_name VARCHAR(100) NOT NULL,
    is_allowed BOOLEAN NOT NULL DEFAULT TRUE,
    configured_by_user_id UUID NOT NULL REFERENCES public.user_profiles(user_id),
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    
    -- Either user_id or role_name must be specified, not both
    CHECK (
        (user_id IS NOT NULL AND role_name IS NULL) OR 
        (user_id IS NULL AND role_name IS NOT NULL)
    )
);

-- Add comment for documentation
COMMENT ON TABLE public.user_view_permissions IS 'Fine-grained view-level permissions';
COMMENT ON COLUMN public.user_view_permissions.user_id IS 'Specific user (NULL for role-based permission)';
COMMENT ON COLUMN public.user_view_permissions.role_name IS 'Role name (NULL for user-specific permission)';
COMMENT ON COLUMN public.user_view_permissions.view_name IS 'Name of the view/component to control access';

-- =====================================================
-- AUDIT LOG TABLE
-- =====================================================
-- Track important system events and changes
CREATE TABLE public.audit_logs (
    log_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES public.user_profiles(user_id),
    action VARCHAR(50) NOT NULL,
    table_name VARCHAR(50),
    record_id UUID,
    old_values JSONB,
    new_values JSONB,
    ip_address INET,
    user_agent TEXT,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW()
);

-- Add comment for documentation
COMMENT ON TABLE public.audit_logs IS 'Audit trail for important system events';
COMMENT ON COLUMN public.audit_logs.action IS 'Type of action performed (CREATE, UPDATE, DELETE, LOGIN, etc.)';
COMMENT ON COLUMN public.audit_logs.old_values IS 'Previous values before change (for UPDATE actions)';
COMMENT ON COLUMN public.audit_logs.new_values IS 'New values after change';

-- =====================================================
-- UPDATE TRIGGERS FOR TIMESTAMPS
-- =====================================================

-- Function to update the updated_at timestamp
CREATE OR REPLACE FUNCTION public.update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ language 'plpgsql';

-- Add update triggers to tables with updated_at columns
CREATE TRIGGER update_cities_updated_at 
    BEFORE UPDATE ON public.cities 
    FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

CREATE TRIGGER update_sports_updated_at 
    BEFORE UPDATE ON public.sports 
    FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

CREATE TRIGGER update_user_profiles_updated_at 
    BEFORE UPDATE ON public.user_profiles 
    FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

CREATE TRIGGER update_user_view_permissions_updated_at 
    BEFORE UPDATE ON public.user_view_permissions 
    FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

-- =====================================================
-- INITIAL DATA CONSTRAINTS
-- =====================================================

-- Ensure at least one super_admin exists (will be added in seed data)
-- This constraint will be added after initial super_admin is created