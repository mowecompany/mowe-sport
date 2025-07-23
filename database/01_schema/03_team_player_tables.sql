-- =====================================================
-- MOWE SPORT PLATFORM - TEAM AND PLAYER TABLES
-- =====================================================
-- Description: Teams, players, and their relationships
-- Dependencies: 01_core_tables.sql, 02_tournament_tables.sql
-- Execution Order: 3rd
-- =====================================================

-- =====================================================
-- TEAMS TABLE
-- =====================================================
-- Teams that participate in tournaments
CREATE TABLE public.teams (
    team_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name VARCHAR(200) NOT NULL,
    short_name VARCHAR(50),
    description TEXT,
    owner_user_id UUID NOT NULL REFERENCES public.user_profiles(user_id) ON DELETE RESTRICT,
    city_id UUID NOT NULL REFERENCES public.cities(city_id) ON DELETE RESTRICT,
    sport_id UUID NOT NULL REFERENCES public.sports(sport_id) ON DELETE RESTRICT,
    logo_url TEXT,
    primary_color VARCHAR(7), -- Hex color code
    secondary_color VARCHAR(7), -- Hex color code
    founded_date DATE,
    home_venue VARCHAR(200),
    contact_info JSONB,
    social_media JSONB,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    is_verified BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    
    -- Ensure unique team names within city/sport
    UNIQUE(name, city_id, sport_id)
);

-- Add comment for documentation
COMMENT ON TABLE public.teams IS 'Teams that participate in tournaments';
COMMENT ON COLUMN public.teams.short_name IS 'Abbreviated team name for displays';
COMMENT ON COLUMN public.teams.primary_color IS 'Primary team color in hex format (#RRGGBB)';
COMMENT ON COLUMN public.teams.is_verified IS 'Whether team has been verified by administrators';
COMMENT ON COLUMN public.teams.contact_info IS 'Team contact information in JSON format';
COMMENT ON COLUMN public.teams.social_media IS 'Social media links in JSON format';

-- =====================================================
-- PLAYERS TABLE
-- =====================================================
-- Individual players who can participate in multiple teams
CREATE TABLE public.players (
    player_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_profile_id UUID REFERENCES public.user_profiles(user_id) ON DELETE SET NULL,
    first_name VARCHAR(100) NOT NULL,
    last_name VARCHAR(100) NOT NULL,
    date_of_birth DATE NOT NULL,
    identification VARCHAR(50) UNIQUE NOT NULL,
    blood_type VARCHAR(5),
    gender VARCHAR(10) CHECK (gender IN ('male', 'female')),
    nationality VARCHAR(100) DEFAULT 'Colombian',
    email VARCHAR(255),
    phone VARCHAR(20),
    photo_url TEXT,
    height_cm INTEGER,
    weight_kg DECIMAL(5,2),
    emergency_contact JSONB,
    medical_info JSONB,
    preferred_position VARCHAR(50),
    dominant_foot VARCHAR(10) CHECK (dominant_foot IN ('left', 'right', 'both')),
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    is_available BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    
    -- Age validation
    CHECK (date_of_birth <= CURRENT_DATE - INTERVAL '5 years'), -- Minimum age 5
    CHECK (height_cm IS NULL OR (height_cm >= 100 AND height_cm <= 250)),
    CHECK (weight_kg IS NULL OR (weight_kg >= 20 AND weight_kg <= 200))
);

-- Add comment for documentation
COMMENT ON TABLE public.players IS 'Individual players who can participate in multiple teams';
COMMENT ON COLUMN public.players.user_profile_id IS 'Link to user account if player has one';
COMMENT ON COLUMN public.players.identification IS 'Government ID or passport number';
COMMENT ON COLUMN public.players.emergency_contact IS 'Emergency contact information in JSON format';
COMMENT ON COLUMN public.players.medical_info IS 'Medical information and allergies in JSON format';
COMMENT ON COLUMN public.players.is_available IS 'Whether player is available for selection';

-- =====================================================
-- TEAM PLAYERS TABLE (Many-to-Many Relationship)
-- =====================================================
-- Links players to teams with historical tracking
CREATE TABLE public.team_players (
    team_player_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    team_id UUID NOT NULL REFERENCES public.teams(team_id) ON DELETE CASCADE,
    player_id UUID NOT NULL REFERENCES public.players(player_id) ON DELETE CASCADE,
    join_date DATE NOT NULL DEFAULT CURRENT_DATE,
    leave_date DATE,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    position VARCHAR(50),
    jersey_number INTEGER,
    is_captain BOOLEAN NOT NULL DEFAULT FALSE,
    is_vice_captain BOOLEAN NOT NULL DEFAULT FALSE,
    contract_type VARCHAR(20) DEFAULT 'amateur' CHECK (
        contract_type IN ('amateur', 'semi_professional', 'professional')
    ),
    salary DECIMAL(10,2),
    registered_by_user_id UUID NOT NULL REFERENCES public.user_profiles(user_id),
    notes TEXT,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    
    -- Business logic constraints
    CHECK (leave_date IS NULL OR leave_date >= join_date),
    CHECK (jersey_number IS NULL OR (jersey_number >= 1 AND jersey_number <= 99)),
    CHECK (NOT (is_captain = TRUE AND is_vice_captain = TRUE)),
    
    -- Prevent duplicate active memberships for same player/team
    UNIQUE(team_id, player_id, join_date)
);

-- Add comment for documentation
COMMENT ON TABLE public.team_players IS 'Many-to-many relationship between teams and players with history';
COMMENT ON COLUMN public.team_players.leave_date IS 'NULL means player is still active in team';
COMMENT ON COLUMN public.team_players.contract_type IS 'Type of contract/agreement with team';
COMMENT ON COLUMN public.team_players.registered_by_user_id IS 'User who registered this player to the team';

-- =====================================================
-- TOURNAMENT TEAMS TABLE (Many-to-Many Relationship)
-- =====================================================
-- Teams registered for specific tournaments
CREATE TABLE public.tournament_teams (
    tournament_team_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tournament_id UUID NOT NULL REFERENCES public.tournaments(tournament_id) ON DELETE CASCADE,
    team_id UUID NOT NULL REFERENCES public.teams(team_id) ON DELETE CASCADE,
    category_id UUID REFERENCES public.tournament_categories(category_id) ON DELETE CASCADE,
    group_id UUID REFERENCES public.tournament_groups(group_id) ON DELETE SET NULL,
    registration_date TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    status VARCHAR(20) NOT NULL DEFAULT 'pending' CHECK (
        status IN ('pending', 'approved', 'rejected', 'withdrawn')
    ),
    approved_by_user_id UUID REFERENCES public.user_profiles(user_id),
    approval_date TIMESTAMP WITH TIME ZONE,
    registration_fee_paid BOOLEAN NOT NULL DEFAULT FALSE,
    payment_date TIMESTAMP WITH TIME ZONE,
    seed_number INTEGER, -- For tournament seeding
    notes TEXT,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    
    -- Ensure unique team registration per tournament/category
    UNIQUE(tournament_id, team_id, category_id),
    
    -- Approval logic
    CHECK (
        (status = 'approved' AND approved_by_user_id IS NOT NULL) OR 
        (status != 'approved')
    )
);

-- Add comment for documentation
COMMENT ON TABLE public.tournament_teams IS 'Teams registered for specific tournaments';
COMMENT ON COLUMN public.tournament_teams.seed_number IS 'Tournament seeding position';
COMMENT ON COLUMN public.tournament_teams.registration_fee_paid IS 'Whether registration fee has been paid';

-- =====================================================
-- TOURNAMENT TEAM PLAYERS TABLE
-- =====================================================
-- Specific players registered for a tournament with a team
CREATE TABLE public.tournament_team_players (
    tournament_team_player_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tournament_team_id UUID NOT NULL REFERENCES public.tournament_teams(tournament_team_id) ON DELETE CASCADE,
    player_id UUID NOT NULL REFERENCES public.players(player_id) ON DELETE CASCADE,
    jersey_number INTEGER NOT NULL,
    position VARCHAR(50),
    is_captain BOOLEAN NOT NULL DEFAULT FALSE,
    is_vice_captain BOOLEAN NOT NULL DEFAULT FALSE,
    registration_date TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    is_eligible BOOLEAN NOT NULL DEFAULT TRUE,
    eligibility_notes TEXT,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    
    -- Ensure unique jersey numbers within tournament team
    UNIQUE(tournament_team_id, jersey_number),
    -- Ensure unique player registration per tournament team
    UNIQUE(tournament_team_id, player_id),
    
    -- Jersey number validation
    CHECK (jersey_number >= 1 AND jersey_number <= 99),
    -- Captain logic
    CHECK (NOT (is_captain = TRUE AND is_vice_captain = TRUE))
);

-- Add comment for documentation
COMMENT ON TABLE public.tournament_team_players IS 'Players registered for specific tournaments with teams';
COMMENT ON COLUMN public.tournament_team_players.is_eligible IS 'Whether player is eligible to play';
COMMENT ON COLUMN public.tournament_team_players.eligibility_notes IS 'Notes about player eligibility status';

-- =====================================================
-- PLAYER TRANSFERS TABLE
-- =====================================================
-- Track player transfers between teams
CREATE TABLE public.player_transfers (
    transfer_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    player_id UUID NOT NULL REFERENCES public.players(player_id) ON DELETE CASCADE,
    from_team_id UUID REFERENCES public.teams(team_id) ON DELETE SET NULL,
    to_team_id UUID NOT NULL REFERENCES public.teams(team_id) ON DELETE CASCADE,
    transfer_date DATE NOT NULL DEFAULT CURRENT_DATE,
    transfer_type VARCHAR(20) NOT NULL CHECK (
        transfer_type IN ('loan', 'permanent', 'free_transfer', 'trade')
    ),
    transfer_fee DECIMAL(10,2),
    contract_duration_months INTEGER,
    approved_by_user_id UUID REFERENCES public.user_profiles(user_id),
    status VARCHAR(20) NOT NULL DEFAULT 'pending' CHECK (
        status IN ('pending', 'approved', 'rejected', 'completed')
    ),
    notes TEXT,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    
    -- Cannot transfer to same team
    CHECK (from_team_id != to_team_id OR from_team_id IS NULL)
);

-- Add comment for documentation
COMMENT ON TABLE public.player_transfers IS 'Track player transfers between teams';
COMMENT ON COLUMN public.player_transfers.from_team_id IS 'NULL for new player registrations';
COMMENT ON COLUMN public.player_transfers.transfer_type IS 'Type of transfer (loan, permanent, etc.)';

-- =====================================================
-- UPDATE TRIGGERS FOR TIMESTAMPS
-- =====================================================

CREATE TRIGGER update_teams_updated_at 
    BEFORE UPDATE ON public.teams 
    FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

CREATE TRIGGER update_players_updated_at 
    BEFORE UPDATE ON public.players 
    FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

CREATE TRIGGER update_team_players_updated_at 
    BEFORE UPDATE ON public.team_players 
    FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

CREATE TRIGGER update_tournament_teams_updated_at 
    BEFORE UPDATE ON public.tournament_teams 
    FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

CREATE TRIGGER update_player_transfers_updated_at 
    BEFORE UPDATE ON public.player_transfers 
    FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

-- =====================================================
-- INDEXES FOR PERFORMANCE
-- =====================================================

-- Teams indexes
CREATE INDEX idx_teams_city_sport ON public.teams(city_id, sport_id);
CREATE INDEX idx_teams_owner ON public.teams(owner_user_id);
CREATE INDEX idx_teams_active ON public.teams(is_active) WHERE is_active = TRUE;

-- Players indexes
CREATE INDEX idx_players_name ON public.players(first_name, last_name);
CREATE INDEX idx_players_identification ON public.players(identification);
CREATE INDEX idx_players_birth_date ON public.players(date_of_birth);
CREATE INDEX idx_players_active ON public.players(is_active) WHERE is_active = TRUE;

-- Team players indexes
CREATE INDEX idx_team_players_team ON public.team_players(team_id);
CREATE INDEX idx_team_players_player ON public.team_players(player_id);
CREATE INDEX idx_team_players_active ON public.team_players(team_id, is_active) WHERE is_active = TRUE;
CREATE INDEX idx_team_players_jersey ON public.team_players(team_id, jersey_number) WHERE is_active = TRUE;

-- Tournament teams indexes
CREATE INDEX idx_tournament_teams_tournament ON public.tournament_teams(tournament_id);
CREATE INDEX idx_tournament_teams_team ON public.tournament_teams(team_id);
CREATE INDEX idx_tournament_teams_status ON public.tournament_teams(status);
CREATE INDEX idx_tournament_teams_approved ON public.tournament_teams(tournament_id, status) WHERE status = 'approved';

-- Tournament team players indexes
CREATE INDEX idx_tournament_team_players_team ON public.tournament_team_players(tournament_team_id);
CREATE INDEX idx_tournament_team_players_player ON public.tournament_team_players(player_id);

-- Player transfers indexes
CREATE INDEX idx_player_transfers_player ON public.player_transfers(player_id);
CREATE INDEX idx_player_transfers_teams ON public.player_transfers(from_team_id, to_team_id);
CREATE INDEX idx_player_transfers_date ON public.player_transfers(transfer_date);