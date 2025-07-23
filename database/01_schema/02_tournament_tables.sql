-- =====================================================
-- MOWE SPORT PLATFORM - TOURNAMENT TABLES
-- =====================================================
-- Description: Tournament management tables
-- Dependencies: 01_core_tables.sql
-- Execution Order: 2nd
-- =====================================================

-- =====================================================
-- TOURNAMENTS TABLE
-- =====================================================
-- Main tournaments table
CREATE TABLE public.tournaments (
    tournament_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name VARCHAR(200) NOT NULL,
    description TEXT,
    city_id UUID NOT NULL REFERENCES public.cities(city_id) ON DELETE RESTRICT,
    sport_id UUID NOT NULL REFERENCES public.sports(sport_id) ON DELETE RESTRICT,
    admin_user_id UUID NOT NULL REFERENCES public.user_profiles(user_id) ON DELETE RESTRICT,
    start_date DATE NOT NULL,
    end_date DATE NOT NULL,
    registration_deadline DATE,
    max_teams INTEGER,
    min_teams INTEGER DEFAULT 2,
    entry_fee DECIMAL(10,2) DEFAULT 0.00,
    prize_pool DECIMAL(10,2) DEFAULT 0.00,
    status VARCHAR(20) NOT NULL DEFAULT 'pending' CHECK (
        status IN (
            'pending', 
            'approved', 
            'active', 
            'completed', 
            'cancelled'
        )
    ),
    is_public BOOLEAN NOT NULL DEFAULT TRUE,
    tournament_format VARCHAR(20) DEFAULT 'league' CHECK (
        tournament_format IN (
            'league', 
            'knockout', 
            'group_stage', 
            'swiss'
        )
    ),
    rules JSONB,
    location VARCHAR(200),
    contact_info JSONB,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    
    -- Business logic constraints
    CHECK (end_date >= start_date),
    CHECK (registration_deadline IS NULL OR registration_deadline <= start_date),
    CHECK (max_teams IS NULL OR max_teams >= min_teams)
);

-- Add comment for documentation
COMMENT ON TABLE public.tournaments IS 'Tournament information and configuration';
COMMENT ON COLUMN public.tournaments.tournament_format IS 'Type of tournament format (league, knockout, etc.)';
COMMENT ON COLUMN public.tournaments.rules IS 'Tournament-specific rules in JSON format';
COMMENT ON COLUMN public.tournaments.contact_info IS 'Contact information for tournament organizer';

-- =====================================================
-- TOURNAMENT CATEGORIES TABLE
-- =====================================================
-- Categories within tournaments (e.g., U-18, Senior, Women's)
CREATE TABLE public.tournament_categories (
    category_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tournament_id UUID NOT NULL REFERENCES public.tournaments(tournament_id) ON DELETE CASCADE,
    name VARCHAR(100) NOT NULL,
    description TEXT,
    min_age INTEGER,
    max_age INTEGER,
    gender VARCHAR(10) CHECK (gender IN ('male', 'female', 'mixed')),
    max_teams INTEGER,
    entry_fee DECIMAL(10,2) DEFAULT 0.00,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    
    -- Ensure unique category names within tournament
    UNIQUE(tournament_id, name),
    
    -- Age constraints
    CHECK (min_age IS NULL OR min_age >= 0),
    CHECK (max_age IS NULL OR max_age >= 0),
    CHECK (min_age IS NULL OR max_age IS NULL OR max_age >= min_age)
);

-- Add comment for documentation
COMMENT ON TABLE public.tournament_categories IS 'Categories within tournaments (age groups, gender divisions)';
COMMENT ON COLUMN public.tournament_categories.gender IS 'Gender restriction for the category';

-- =====================================================
-- TOURNAMENT PHASES TABLE
-- =====================================================
-- Different phases of a tournament (Group Stage, Quarter Finals, etc.)
CREATE TABLE public.tournament_phases (
    phase_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tournament_id UUID NOT NULL REFERENCES public.tournaments(tournament_id) ON DELETE CASCADE,
    category_id UUID REFERENCES public.tournament_categories(category_id) ON DELETE CASCADE,
    name VARCHAR(100) NOT NULL,
    phase_order INTEGER NOT NULL,
    phase_type VARCHAR(20) NOT NULL CHECK (
        phase_type IN (
            'group_stage', 
            'round_of_32', 
            'round_of_16', 
            'quarter_final', 
            'semi_final', 
            'final', 
            'third_place', 
            'league'
        )
    ),
    start_date DATE,
    end_date DATE,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    
    -- Ensure unique phase order within tournament/category
    UNIQUE(tournament_id, category_id, phase_order),
    
    -- Date constraints
    CHECK (end_date IS NULL OR start_date IS NULL OR end_date >= start_date)
);

-- Add comment for documentation
COMMENT ON TABLE public.tournament_phases IS 'Different phases/rounds within tournaments';
COMMENT ON COLUMN public.tournament_phases.phase_order IS 'Order of phases (1 = first phase)';

-- =====================================================
-- TOURNAMENT GROUPS TABLE
-- =====================================================
-- Groups within tournament phases (for group stage tournaments)
CREATE TABLE public.tournament_groups (
    group_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    phase_id UUID NOT NULL REFERENCES public.tournament_phases(phase_id) ON DELETE CASCADE,
    name VARCHAR(50) NOT NULL, -- Group A, Group B, etc.
    description TEXT,
    max_teams INTEGER DEFAULT 4,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    
    -- Ensure unique group names within phase
    UNIQUE(phase_id, name)
);

-- Add comment for documentation
COMMENT ON TABLE public.tournament_groups IS 'Groups within tournament phases for group stage format';

-- =====================================================
-- TOURNAMENT SETTINGS TABLE
-- =====================================================
-- Additional tournament configuration settings
CREATE TABLE public.tournament_settings (
    setting_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tournament_id UUID NOT NULL REFERENCES public.tournaments(tournament_id) ON DELETE CASCADE,
    setting_key VARCHAR(100) NOT NULL,
    setting_value JSONB NOT NULL,
    description TEXT,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    
    -- Ensure unique settings per tournament
    UNIQUE(tournament_id, setting_key)
);

-- Add comment for documentation
COMMENT ON TABLE public.tournament_settings IS 'Additional tournament configuration settings';
COMMENT ON COLUMN public.tournament_settings.setting_key IS 'Setting name (e.g., points_for_win, points_for_draw)';
COMMENT ON COLUMN public.tournament_settings.setting_value IS 'Setting value in JSON format';

-- =====================================================
-- UPDATE TRIGGERS FOR TIMESTAMPS
-- =====================================================

CREATE TRIGGER update_tournaments_updated_at 
    BEFORE UPDATE ON public.tournaments 
    FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

CREATE TRIGGER update_tournament_categories_updated_at 
    BEFORE UPDATE ON public.tournament_categories 
    FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

CREATE TRIGGER update_tournament_phases_updated_at 
    BEFORE UPDATE ON public.tournament_phases 
    FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

CREATE TRIGGER update_tournament_groups_updated_at 
    BEFORE UPDATE ON public.tournament_groups 
    FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

CREATE TRIGGER update_tournament_settings_updated_at 
    BEFORE UPDATE ON public.tournament_settings 
    FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

-- =====================================================
-- INDEXES FOR PERFORMANCE
-- =====================================================

-- Indexes for common queries
CREATE INDEX idx_tournaments_city_sport ON public.tournaments(city_id, sport_id);
CREATE INDEX idx_tournaments_status ON public.tournaments(status);
CREATE INDEX idx_tournaments_dates ON public.tournaments(start_date, end_date);
CREATE INDEX idx_tournaments_admin ON public.tournaments(admin_user_id);

-- Partial indexes for active records
CREATE INDEX idx_tournaments_active ON public.tournaments(city_id, sport_id, status) 
    WHERE status IN ('approved', 'active');

CREATE INDEX idx_tournament_categories_active ON public.tournament_categories(tournament_id) 
    WHERE is_active = TRUE;