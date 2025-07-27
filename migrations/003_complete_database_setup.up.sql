-- =====================================================
-- MOWE SPORT PLATFORM - COMPLETE DATABASE SETUP
-- =====================================================
-- Migration: 003_complete_database_setup
-- Description: Complete database setup with all remaining components
-- =====================================================

-- =====================================================
-- TEAMS TABLE
-- =====================================================
CREATE TABLE IF NOT EXISTS public.teams (
    team_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name VARCHAR(200) NOT NULL,
    short_name VARCHAR(50),
    description TEXT,
    owner_user_id UUID NOT NULL REFERENCES public.user_profiles(user_id) ON DELETE RESTRICT,
    city_id UUID NOT NULL REFERENCES public.cities(city_id) ON DELETE RESTRICT,
    sport_id UUID NOT NULL REFERENCES public.sports(sport_id) ON DELETE RESTRICT,
    logo_url TEXT,
    primary_color VARCHAR(7),
    secondary_color VARCHAR(7),
    founded_date DATE,
    home_venue VARCHAR(200),
    contact_info JSONB,
    social_media JSONB,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    is_verified BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    
    UNIQUE(name, city_id, sport_id)
);

-- =====================================================
-- PLAYERS TABLE
-- =====================================================
CREATE TABLE IF NOT EXISTS public.players (
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
    
    CHECK (date_of_birth <= CURRENT_DATE - INTERVAL '5 years'),
    CHECK (height_cm IS NULL OR (height_cm >= 100 AND height_cm <= 250)),
    CHECK (weight_kg IS NULL OR (weight_kg >= 20 AND weight_kg <= 200))
);

-- =====================================================
-- TEAM PLAYERS TABLE
-- =====================================================
CREATE TABLE IF NOT EXISTS public.team_players (
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
    
    CHECK (leave_date IS NULL OR leave_date >= join_date),
    CHECK (jersey_number IS NULL OR (jersey_number >= 1 AND jersey_number <= 99)),
    CHECK (NOT (is_captain = TRUE AND is_vice_captain = TRUE)),
    UNIQUE(team_id, player_id, join_date)
);

-- =====================================================
-- TOURNAMENT TEAMS TABLE
-- =====================================================
CREATE TABLE IF NOT EXISTS public.tournament_teams (
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
    seed_number INTEGER,
    notes TEXT,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    
    UNIQUE(tournament_id, team_id, category_id),
    CHECK (
        (status = 'approved' AND approved_by_user_id IS NOT NULL) OR 
        (status != 'approved')
    )
);

-- =====================================================
-- MATCHES TABLE
-- =====================================================
CREATE TABLE IF NOT EXISTS public.matches (
    match_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tournament_id UUID NOT NULL REFERENCES public.tournaments(tournament_id) ON DELETE CASCADE,
    phase_id UUID REFERENCES public.tournament_phases(phase_id) ON DELETE SET NULL,
    group_id UUID REFERENCES public.tournament_groups(group_id) ON DELETE SET NULL,
    sport_id UUID NOT NULL REFERENCES public.sports(sport_id) ON DELETE RESTRICT,
    home_team_id UUID NOT NULL REFERENCES public.teams(team_id) ON DELETE RESTRICT,
    away_team_id UUID NOT NULL REFERENCES public.teams(team_id) ON DELETE RESTRICT,
    match_date DATE NOT NULL,
    match_time TIME NOT NULL,
    venue VARCHAR(200),
    venue_address TEXT,
    referee_user_id UUID REFERENCES public.user_profiles(user_id) ON DELETE SET NULL,
    home_team_score INTEGER NOT NULL DEFAULT 0,
    away_team_score INTEGER NOT NULL DEFAULT 0,
    status VARCHAR(20) NOT NULL DEFAULT 'scheduled' CHECK (
        status IN (
            'scheduled', 
            'live', 
            'half_time', 
            'completed', 
            'cancelled', 
            'postponed',
            'abandoned'
        )
    ),
    match_duration_minutes INTEGER DEFAULT 90,
    actual_start_time TIMESTAMP WITH TIME ZONE,
    actual_end_time TIMESTAMP WITH TIME ZONE,
    weather_conditions VARCHAR(50),
    attendance INTEGER,
    match_notes TEXT,
    match_data JSONB,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    
    CHECK (home_team_id != away_team_id),
    CHECK (home_team_score >= 0 AND away_team_score >= 0),
    CHECK (attendance IS NULL OR attendance >= 0)
);

-- =====================================================
-- MATCH EVENTS TABLE
-- =====================================================
CREATE TABLE IF NOT EXISTS public.match_events (
    event_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    match_id UUID NOT NULL REFERENCES public.matches(match_id) ON DELETE CASCADE,
    player_id UUID REFERENCES public.players(player_id) ON DELETE SET NULL,
    team_id UUID NOT NULL REFERENCES public.teams(team_id) ON DELETE CASCADE,
    event_type VARCHAR(50) NOT NULL CHECK (
        event_type IN (
            'goal', 
            'own_goal',
            'penalty_goal',
            'missed_penalty',
            'yellow_card', 
            'red_card', 
            'substitution_in',
            'substitution_out',
            'assist',
            'corner_kick',
            'free_kick',
            'offside',
            'foul',
            'injury',
            'timeout',
            'other'
        )
    ),
    event_minute INTEGER NOT NULL,
    additional_time INTEGER DEFAULT 0,
    description TEXT,
    related_player_id UUID REFERENCES public.players(player_id) ON DELETE SET NULL,
    event_data JSONB,
    is_deleted BOOLEAN NOT NULL DEFAULT FALSE,
    deleted_by_user_id UUID REFERENCES public.user_profiles(user_id),
    deleted_at TIMESTAMP WITH TIME ZONE,
    created_by_user_id UUID REFERENCES public.user_profiles(user_id),
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    
    CHECK (event_minute >= 0 AND event_minute <= 200),
    CHECK (additional_time >= 0 AND additional_time <= 30)
);

-- =====================================================
-- PLAYER STATISTICS TABLE
-- =====================================================
CREATE TABLE IF NOT EXISTS public.player_statistics (
    stat_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    player_id UUID NOT NULL REFERENCES public.players(player_id) ON DELETE CASCADE,
    tournament_id UUID NOT NULL REFERENCES public.tournaments(tournament_id) ON DELETE CASCADE,
    team_id UUID NOT NULL REFERENCES public.teams(team_id) ON DELETE CASCADE,
    sport_id UUID NOT NULL REFERENCES public.sports(sport_id) ON DELETE RESTRICT,
    
    matches_played INTEGER NOT NULL DEFAULT 0,
    matches_started INTEGER NOT NULL DEFAULT 0,
    matches_as_substitute INTEGER NOT NULL DEFAULT 0,
    minutes_played INTEGER NOT NULL DEFAULT 0,
    
    goals_scored INTEGER NOT NULL DEFAULT 0,
    penalty_goals INTEGER NOT NULL DEFAULT 0,
    own_goals INTEGER NOT NULL DEFAULT 0,
    assists INTEGER NOT NULL DEFAULT 0,
    
    yellow_cards INTEGER NOT NULL DEFAULT 0,
    red_cards INTEGER NOT NULL DEFAULT 0,
    
    wins INTEGER NOT NULL DEFAULT 0,
    losses INTEGER NOT NULL DEFAULT 0,
    draws INTEGER NOT NULL DEFAULT 0,
    
    additional_stats JSONB,
    
    last_calculated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    
    UNIQUE(player_id, tournament_id, team_id),
    
    CHECK (matches_played >= 0),
    CHECK (matches_started >= 0),
    CHECK (matches_as_substitute >= 0),
    CHECK (matches_started + matches_as_substitute <= matches_played),
    CHECK (minutes_played >= 0),
    CHECK (goals_scored >= 0),
    CHECK (assists >= 0),
    CHECK (yellow_cards >= 0),
    CHECK (red_cards >= 0),
    CHECK (wins + losses + draws = matches_played)
);

-- =====================================================
-- TEAM STATISTICS TABLE
-- =====================================================
CREATE TABLE IF NOT EXISTS public.team_statistics (
    stat_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    team_id UUID NOT NULL REFERENCES public.teams(team_id) ON DELETE CASCADE,
    tournament_id UUID NOT NULL REFERENCES public.tournaments(tournament_id) ON DELETE CASCADE,
    sport_id UUID NOT NULL REFERENCES public.sports(sport_id) ON DELETE RESTRICT,
    category_id UUID REFERENCES public.tournament_categories(category_id) ON DELETE CASCADE,
    phase_id UUID REFERENCES public.tournament_phases(phase_id) ON DELETE SET NULL,
    group_id UUID REFERENCES public.tournament_groups(group_id) ON DELETE SET NULL,
    
    matches_played INTEGER NOT NULL DEFAULT 0,
    wins INTEGER NOT NULL DEFAULT 0,
    losses INTEGER NOT NULL DEFAULT 0,
    draws INTEGER NOT NULL DEFAULT 0,
    
    goals_for INTEGER NOT NULL DEFAULT 0,
    goals_against INTEGER NOT NULL DEFAULT 0,
    
    points INTEGER NOT NULL DEFAULT 0,
    
    clean_sheets INTEGER NOT NULL DEFAULT 0,
    failed_to_score INTEGER NOT NULL DEFAULT 0,
    
    yellow_cards INTEGER NOT NULL DEFAULT 0,
    red_cards INTEGER NOT NULL DEFAULT 0,
    
    current_position INTEGER,
    previous_position INTEGER,
    highest_position INTEGER,
    lowest_position INTEGER,
    
    recent_form VARCHAR(5),
    
    additional_stats JSONB,
    
    last_calculated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    
    UNIQUE(team_id, tournament_id, category_id),
    
    CHECK (matches_played >= 0),
    CHECK (wins >= 0 AND losses >= 0 AND draws >= 0),
    CHECK (wins + losses + draws = matches_played),
    CHECK (goals_for >= 0 AND goals_against >= 0),
    CHECK (points >= 0),
    CHECK (current_position IS NULL OR current_position > 0),
    CHECK (LENGTH(recent_form) <= 5)
);

-- =====================================================
-- UPDATE TRIGGERS FOR TIMESTAMPS
-- =====================================================

DO $$
BEGIN
    -- Teams
    IF NOT EXISTS (SELECT 1 FROM pg_trigger WHERE tgname = 'update_teams_updated_at') THEN
        CREATE TRIGGER update_teams_updated_at 
            BEFORE UPDATE ON public.teams 
            FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();
    END IF;

    -- Players
    IF NOT EXISTS (SELECT 1 FROM pg_trigger WHERE tgname = 'update_players_updated_at') THEN
        CREATE TRIGGER update_players_updated_at 
            BEFORE UPDATE ON public.players 
            FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();
    END IF;

    -- Team Players
    IF NOT EXISTS (SELECT 1 FROM pg_trigger WHERE tgname = 'update_team_players_updated_at') THEN
        CREATE TRIGGER update_team_players_updated_at 
            BEFORE UPDATE ON public.team_players 
            FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();
    END IF;

    -- Tournament Teams
    IF NOT EXISTS (SELECT 1 FROM pg_trigger WHERE tgname = 'update_tournament_teams_updated_at') THEN
        CREATE TRIGGER update_tournament_teams_updated_at 
            BEFORE UPDATE ON public.tournament_teams 
            FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();
    END IF;

    -- Matches
    IF NOT EXISTS (SELECT 1 FROM pg_trigger WHERE tgname = 'update_matches_updated_at') THEN
        CREATE TRIGGER update_matches_updated_at 
            BEFORE UPDATE ON public.matches 
            FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();
    END IF;

    -- Player Statistics
    IF NOT EXISTS (SELECT 1 FROM pg_trigger WHERE tgname = 'update_player_statistics_updated_at') THEN
        CREATE TRIGGER update_player_statistics_updated_at 
            BEFORE UPDATE ON public.player_statistics 
            FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();
    END IF;

    -- Team Statistics
    IF NOT EXISTS (SELECT 1 FROM pg_trigger WHERE tgname = 'update_team_statistics_updated_at') THEN
        CREATE TRIGGER update_team_statistics_updated_at 
            BEFORE UPDATE ON public.team_statistics 
            FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();
    END IF;
END $$;

-- =====================================================
-- CORE PERFORMANCE INDEXES
-- =====================================================

-- Teams indexes
CREATE INDEX IF NOT EXISTS idx_teams_city_sport ON public.teams(city_id, sport_id);
CREATE INDEX IF NOT EXISTS idx_teams_owner ON public.teams(owner_user_id);
CREATE INDEX IF NOT EXISTS idx_teams_active ON public.teams(is_active) WHERE is_active = TRUE;

-- Players indexes
CREATE INDEX IF NOT EXISTS idx_players_name ON public.players(first_name, last_name);
CREATE INDEX IF NOT EXISTS idx_players_identification ON public.players(identification);
CREATE INDEX IF NOT EXISTS idx_players_birth_date ON public.players(date_of_birth);
CREATE INDEX IF NOT EXISTS idx_players_active ON public.players(is_active) WHERE is_active = TRUE;

-- Team players indexes
CREATE INDEX IF NOT EXISTS idx_team_players_team ON public.team_players(team_id);
CREATE INDEX IF NOT EXISTS idx_team_players_player ON public.team_players(player_id);
CREATE INDEX IF NOT EXISTS idx_team_players_active ON public.team_players(team_id, is_active) WHERE is_active = TRUE;

-- Tournament teams indexes
CREATE INDEX IF NOT EXISTS idx_tournament_teams_tournament ON public.tournament_teams(tournament_id);
CREATE INDEX IF NOT EXISTS idx_tournament_teams_team ON public.tournament_teams(team_id);
CREATE INDEX IF NOT EXISTS idx_tournament_teams_status ON public.tournament_teams(status);

-- Matches indexes
CREATE INDEX IF NOT EXISTS idx_matches_tournament ON public.matches(tournament_id);
CREATE INDEX IF NOT EXISTS idx_matches_teams ON public.matches(home_team_id, away_team_id);
CREATE INDEX IF NOT EXISTS idx_matches_date_time ON public.matches(match_date, match_time);
CREATE INDEX IF NOT EXISTS idx_matches_status ON public.matches(status);

-- Match events indexes
CREATE INDEX IF NOT EXISTS idx_match_events_match ON public.match_events(match_id);
CREATE INDEX IF NOT EXISTS idx_match_events_player ON public.match_events(player_id);
CREATE INDEX IF NOT EXISTS idx_match_events_team ON public.match_events(team_id);
CREATE INDEX IF NOT EXISTS idx_match_events_type ON public.match_events(event_type);
CREATE INDEX IF NOT EXISTS idx_match_events_active ON public.match_events(match_id, is_deleted) WHERE is_deleted = FALSE;

-- Statistics indexes
CREATE INDEX IF NOT EXISTS idx_player_statistics_player ON public.player_statistics(player_id);
CREATE INDEX IF NOT EXISTS idx_player_statistics_tournament ON public.player_statistics(tournament_id);
CREATE INDEX IF NOT EXISTS idx_player_statistics_goals ON public.player_statistics(tournament_id, goals_scored DESC);

CREATE INDEX IF NOT EXISTS idx_team_statistics_tournament ON public.team_statistics(tournament_id);
CREATE INDEX IF NOT EXISTS idx_team_statistics_team ON public.team_statistics(team_id);
CREATE INDEX IF NOT EXISTS idx_team_statistics_points ON public.team_statistics(tournament_id, points DESC);

-- =====================================================
-- SEED DATA - CITIES
-- =====================================================

INSERT INTO public.cities (city_id, name, region, country, timezone, is_active) VALUES
('550e8400-e29b-41d4-a716-446655440001', 'Bogotá', 'Cundinamarca', 'Colombia', 'America/Bogota', TRUE),
('550e8400-e29b-41d4-a716-446655440002', 'Medellín', 'Antioquia', 'Colombia', 'America/Bogota', TRUE),
('550e8400-e29b-41d4-a716-446655440003', 'Cali', 'Valle del Cauca', 'Colombia', 'America/Bogota', TRUE),
('550e8400-e29b-41d4-a716-446655440004', 'Barranquilla', 'Atlántico', 'Colombia', 'America/Bogota', TRUE),
('550e8400-e29b-41d4-a716-446655440005', 'Cartagena', 'Bolívar', 'Colombia', 'America/Bogota', TRUE),
('550e8400-e29b-41d4-a716-446655440006', 'Bucaramanga', 'Santander', 'Colombia', 'America/Bogota', TRUE),
('550e8400-e29b-41d4-a716-446655440007', 'Pereira', 'Risaralda', 'Colombia', 'America/Bogota', TRUE),
('550e8400-e29b-41d4-a716-446655440008', 'Manizales', 'Caldas', 'Colombia', 'America/Bogota', TRUE),
('550e8400-e29b-41d4-a716-446655440009', 'Santa Marta', 'Magdalena', 'Colombia', 'America/Bogota', TRUE),
('550e8400-e29b-41d4-a716-446655440010', 'Ibagué', 'Tolima', 'Colombia', 'America/Bogota', TRUE)
ON CONFLICT (city_id) DO NOTHING;

-- =====================================================
-- SEED DATA - SPORTS
-- =====================================================

INSERT INTO public.sports (sport_id, name, description, default_match_duration, team_size, rules, is_active) VALUES
(
    '660e8400-e29b-41d4-a716-446655440001', 
    'Fútbol', 
    'El deporte más popular en Colombia y el mundo', 
    90, 
    11,
    '{
        "field_dimensions": {"length": "100-110m", "width": "64-75m"},
        "players_per_team": 11,
        "substitutions_allowed": 5,
        "offside_rule": true,
        "yellow_cards_suspension": 2,
        "red_card_suspension": 1,
        "points_system": {"win": 3, "draw": 1, "loss": 0}
    }'::jsonb,
    TRUE
),
(
    '660e8400-e29b-41d4-a716-446655440002', 
    'Baloncesto', 
    'Deporte de canasta muy popular en colegios y universidades', 
    48, 
    5,
    '{
        "court_dimensions": {"length": "28m", "width": "15m"},
        "players_per_team": 5,
        "quarters": 4,
        "quarter_duration": 12,
        "shot_clock": 24,
        "three_point_line": true,
        "points_system": {"win": 2, "loss": 0}
    }'::jsonb,
    TRUE
),
(
    '660e8400-e29b-41d4-a716-446655440004', 
    'Fútbol Sala', 
    'Fútbol en cancha cerrada, muy popular en Colombia', 
    40, 
    5,
    '{
        "court_dimensions": {"length": "38-42m", "width": "20-25m"},
        "players_per_team": 5,
        "halves": 2,
        "half_duration": 20,
        "unlimited_substitutions": true,
        "accumulated_fouls": 5,
        "points_system": {"win": 3, "draw": 1, "loss": 0}
    }'::jsonb,
    TRUE
)
ON CONFLICT (sport_id) DO NOTHING;

-- =====================================================
-- INITIAL AUDIT LOG ENTRY
-- =====================================================

INSERT INTO public.audit_logs (
    user_id,
    action,
    table_name,
    record_id,
    new_values,
    ip_address,
    user_agent
) VALUES (
    NULL,
    'SYSTEM_INIT',
    'complete_setup',
    NULL,
    '{"message": "Complete database setup completed", "migration": "003_complete_database_setup"}'::jsonb,
    '127.0.0.1'::inet,
    'Mowe Sport Database Migration'
) ON CONFLICT DO NOTHING;