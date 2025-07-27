-- =====================================================
-- MOWE SPORT PLATFORM - CORE TABLES MIGRATION
-- =====================================================
-- Migration: 001_create_core_tables
-- Description: Create core tables for cities, sports, and user management
-- =====================================================

-- Enable UUID extension if not already enabled
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- =====================================================
-- CITIES TABLE
-- =====================================================
CREATE TABLE IF NOT EXISTS public.cities (
    city_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name VARCHAR(100) NOT NULL UNIQUE,
    region VARCHAR(100),
    country VARCHAR(100) NOT NULL DEFAULT 'Colombia',
    timezone VARCHAR(50) DEFAULT 'America/Bogota',
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW()
);

COMMENT ON TABLE public.cities IS 'Cities and municipalities that use the Mowe Sport platform';
COMMENT ON COLUMN public.cities.timezone IS 'Timezone for scheduling matches and events';

-- =====================================================
-- SPORTS TABLE
-- =====================================================
CREATE TABLE IF NOT EXISTS public.sports (
    sport_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name VARCHAR(100) NOT NULL UNIQUE,
    description TEXT,
    rules JSONB,
    default_match_duration INTEGER DEFAULT 90,
    team_size INTEGER DEFAULT 11,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW()
);

COMMENT ON TABLE public.sports IS 'Available sports in the platform';
COMMENT ON COLUMN public.sports.rules IS 'Sport-specific rules in JSON format';
COMMENT ON COLUMN public.sports.default_match_duration IS 'Default match duration in minutes';

-- =====================================================
-- USER PROFILES TABLE
-- =====================================================
CREATE TABLE IF NOT EXISTS public.user_profiles (
    user_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    email VARCHAR(255) NOT NULL UNIQUE,
    password_hash VARCHAR(255) NOT NULL,
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
    token_recovery VARCHAR(255),
    token_expiration_date TIMESTAMP WITH TIME ZONE,
    two_factor_secret VARCHAR(255),
    two_factor_enabled BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW()
);

COMMENT ON TABLE public.user_profiles IS 'Main user table with authentication and platform-specific information';

-- =====================================================
-- USER ROLES BY CITY SPORT TABLE
-- =====================================================
CREATE TABLE IF NOT EXISTS public.user_roles_by_city_sport (
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
    
    UNIQUE(user_id, city_id, sport_id, role_name)
);

COMMENT ON TABLE public.user_roles_by_city_sport IS 'Granular role assignments per city and sport';

-- =====================================================
-- USER VIEW PERMISSIONS TABLE
-- =====================================================
CREATE TABLE IF NOT EXISTS public.user_view_permissions (
    permission_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES public.user_profiles(user_id) ON DELETE CASCADE,
    role_name VARCHAR(20),
    view_name VARCHAR(100) NOT NULL,
    is_allowed BOOLEAN NOT NULL DEFAULT TRUE,
    configured_by_user_id UUID NOT NULL REFERENCES public.user_profiles(user_id),
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    
    CHECK (
        (user_id IS NOT NULL AND role_name IS NULL) OR 
        (user_id IS NULL AND role_name IS NOT NULL)
    )
);

COMMENT ON TABLE public.user_view_permissions IS 'Fine-grained view-level permissions';

-- =====================================================
-- AUDIT LOG TABLE
-- =====================================================
CREATE TABLE IF NOT EXISTS public.audit_logs (
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

COMMENT ON TABLE public.audit_logs IS 'Audit trail for important system events';

-- =====================================================
-- UPDATE TRIGGERS FOR TIMESTAMPS
-- =====================================================

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