-- =====================================================
-- MIGRATION 001: CREATE INITIAL SCHEMA
-- =====================================================
-- Description: Create complete Mowe Sport schema
-- Author: Migration System
-- Date: 2025-01-23
-- =====================================================

-- Enable UUID extension
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- =====================================================
-- CORE TABLES
-- =====================================================

-- Cities table
CREATE TABLE IF NOT EXISTS public.cities (
    city_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name VARCHAR(100) NOT NULL,
    region VARCHAR(100),
    country VARCHAR(100) NOT NULL DEFAULT 'Colombia',
    timezone VARCHAR(50) DEFAULT 'America/Bogota',
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW()
);

-- Sports table
CREATE TABLE IF NOT EXISTS public.sports (
    sport_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name VARCHAR(100) NOT NULL,
    description TEXT,
    default_match_duration INTEGER DEFAULT 90,
    team_size INTEGER DEFAULT 11,
    rules JSONB,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW()
);

-- User profiles table (NEW - will replace users)
CREATE TABLE IF NOT EXISTS public.user_profiles (
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

-- User roles by city/sport (granular role management)
CREATE TABLE IF NOT EXISTS public.user_roles_by_city_sport (
    role_assignment_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES public.user_profiles(user_id) ON DELETE CASCADE,
    city_id UUID REFERENCES public.cities(city_id),
    sport_id UUID REFERENCES public.sports(sport_id),
    role_name VARCHAR(20) NOT NULL CHECK (role_name IN ('city_admin', 'tournament_admin', 'owner', 'coach', 'referee', 'player', 'client')),
    assigned_by_user_id UUID REFERENCES public.user_profiles(user_id),
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    UNIQUE(user_id, city_id, sport_id, role_name)
);

-- User view permissions
CREATE TABLE IF NOT EXISTS public.user_view_permissions (
    permission_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES public.user_profiles(user_id) ON DELETE CASCADE,
    role_name VARCHAR(20),
    view_name VARCHAR(100) NOT NULL,
    is_allowed BOOLEAN NOT NULL DEFAULT TRUE,
    configured_by_user_id UUID NOT NULL REFERENCES public.user_profiles(user_id),
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    UNIQUE(COALESCE(user_id, '00000000-0000-0000-0000-000000000000'::UUID), COALESCE(role_name, ''), view_name)
);

-- Audit logs
CREATE TABLE IF NOT EXISTS public.audit_logs (
    log_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES public.user_profiles(user_id),
    action VARCHAR(50) NOT NULL,
    table_name VARCHAR(100),
    record_id UUID,
    old_values JSONB,
    new_values JSONB,
    ip_address INET,
    user_agent TEXT,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW()
);

-- =====================================================
-- TOURNAMENT TABLES
-- =====================================================

-- Tournaments
CREATE TABLE IF NOT EXISTS public.tournaments (
    tournament_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name VARCHAR(200) NOT NULL,
    description TEXT,
    city_id UUID NOT NULL REFERENCES public.cities(city_id),
    sport_id UUID NOT NULL REFERENCES public.sports(sport_id),
    admin_user_id UUID NOT NULL REFERENCES public.user_profiles(user_id),
    start_date DATE NOT NULL,
    end_date DATE NOT NULL,
    registration_deadline DATE,
    max_teams INTEGER,
    status VARCHAR(20) NOT NULL DEFAULT 'pending' 
        CHECK (status IN ('pending', 'approved', 'active', 'completed', 'cancelled')),
    is_public BOOLEAN NOT NULL DEFAULT TRUE,
    rules JSONB,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW()
);

-- Tournament categories
CREATE TABLE IF NOT EXISTS public.tournament_categories (
    category_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tournament_id UUID NOT NULL REFERENCES public.tournaments(tournament_id) ON DELETE CASCADE,
    name VARCHAR(100) NOT NULL,
    description TEXT,
    min_age INTEGER,
    max_age INTEGER,
    gender VARCHAR(10) CHECK (gender IN ('male', 'female', 'mixed')),
    max_teams INTEGER,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW()
);

-- Tournament settings
CREATE TABLE IF NOT EXISTS public.tournament_settings (
    setting_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tournament_id UUID NOT NULL REFERENCES public.tournaments(tournament_id) ON DELETE CASCADE,
    setting_key VARCHAR(100) NOT NULL,
    setting_value JSONB NOT NULL,
    description TEXT,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    UNIQUE(tournament_id, setting_key)
);

-- =====================================================
-- TEAM AND PLAYER TABLES
-- =====================================================

-- Teams
CREATE TABLE IF NOT EXISTS public.teams (
    team_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name VARCHAR(200) NOT NULL,
    short_name VARCHAR(50),
    description TEXT,
    owner_user_id UUID NOT NULL REFERENCES public.user_profiles(user_id),
    city_id UUID NOT NULL REFERENCES public.cities(city_id),
    sport_id UUID NOT NULL REFERENCES public.sports(sport_id),
    logo_url TEXT,
    founded_date DATE,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    is_verified BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW()
);

-- Players
CREATE TABLE IF NOT EXISTS public.players (
    player_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_profile_id UUID REFERENCES public.user_profiles(user_id),
    first_name VARCHAR(100) NOT NULL,
    last_name VARCHAR(100) NOT NULL,
    date_of_birth DATE NOT NULL,
    identification VARCHAR(50) UNIQUE NOT NULL,
    blood_type VARCHAR(5),
    email VARCHAR(255),
    phone VARCHAR(20),
    photo_url TEXT,
    preferred_position VARCHAR(50),
    nationality VARCHAR(50) DEFAULT 'Colombia',
    emergency_contact JSONB,
    medical_info JSONB,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    is_available BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW()
);

-- Team players (many-to-many)
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
    registered_by_user_id UUID NOT NULL REFERENCES public.user_profiles(user_id),
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    UNIQUE(team_id, player_id, join_date)
);

-- Tournament teams
CREATE TABLE IF NOT EXISTS public.tournament_teams (
    tournament_team_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tournament_id UUID NOT NULL REFERENCES public.tournaments(tournament_id) ON DELETE CASCADE,
    team_id UUID NOT NULL REFERENCES public.teams(team_id) ON DELETE CASCADE,
    category_id UUID REFERENCES public.tournament_categories(category_id),
    registration_date TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    status VARCHAR(20) NOT NULL DEFAULT 'pending' 
        CHECK (status IN ('pending', 'approved', 'rejected')),
    registration_fee_paid BOOLEAN NOT NULL DEFAULT FALSE,
    payment_date TIMESTAMP WITH TIME ZONE,
    approved_by_user_id UUID REFERENCES public.user_profiles(user_id),
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    UNIQUE(tournament_id, team_id)
);

-- =====================================================
-- MATCH TABLES
-- =====================================================

-- Matches
CREATE TABLE IF NOT EXISTS public.matches (
    match_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tournament_id UUID NOT NULL REFERENCES public.tournaments(tournament_id),
    sport_id UUID NOT NULL REFERENCES public.sports(sport_id),
    team1_id UUID NOT NULL REFERENCES public.teams(team_id),
    team2_id UUID NOT NULL REFERENCES public.teams(team_id),
    match_date DATE NOT NULL,
    match_time TIME NOT NULL,
    actual_start_time TIMESTAMP WITH TIME ZONE,
    actual_end_time TIMESTAMP WITH TIME ZONE,
    venue VARCHAR(200),
    venue_address TEXT,
    referee_user_id UUID REFERENCES public.user_profiles(user_id),
    score_team1 INTEGER NOT NULL DEFAULT 0,
    score_team2 INTEGER NOT NULL DEFAULT 0,
    status VARCHAR(20) NOT NULL DEFAULT 'scheduled' 
        CHECK (status IN ('scheduled', 'live', 'half_time', 'completed', 'cancelled', 'postponed')),
    match_data JSONB,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    CHECK (team1_id != team2_id)
);

-- Match events
CREATE TABLE IF NOT EXISTS public.match_events (
    event_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    match_id UUID NOT NULL REFERENCES public.matches(match_id) ON DELETE CASCADE,
    player_id UUID REFERENCES public.players(player_id),
    team_id UUID NOT NULL REFERENCES public.teams(team_id),
    event_type VARCHAR(50) NOT NULL,
    event_minute INTEGER NOT NULL,
    additional_time INTEGER DEFAULT 0,
    description TEXT,
    event_data JSONB,
    is_deleted BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW()
);

-- Match lineups
CREATE TABLE IF NOT EXISTS public.match_lineups (
    lineup_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    match_id UUID NOT NULL REFERENCES public.matches(match_id) ON DELETE CASCADE,
    team_id UUID NOT NULL REFERENCES public.teams(team_id),
    player_id UUID NOT NULL REFERENCES public.players(player_id),
    is_starter BOOLEAN NOT NULL DEFAULT TRUE,
    formation_position VARCHAR(20),
    jersey_number INTEGER,
    substituted_at_minute INTEGER,
    substituted_by_player_id UUID REFERENCES public.players(player_id),
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    UNIQUE(match_id, team_id, player_id)
);

-- Match comments
CREATE TABLE IF NOT EXISTS public.match_comments (
    comment_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    match_id UUID NOT NULL REFERENCES public.matches(match_id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES public.user_profiles(user_id),
    comment_type VARCHAR(20) NOT NULL DEFAULT 'general' 
        CHECK (comment_type IN ('general', 'referee_report', 'incident_report')),
    comment_text TEXT NOT NULL,
    is_public BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW()
);

-- =====================================================
-- STATISTICS TABLES
-- =====================================================

-- Player statistics
CREATE TABLE IF NOT EXISTS public.player_statistics (
    stat_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    player_id UUID NOT NULL REFERENCES public.players(player_id) ON DELETE CASCADE,
    tournament_id UUID NOT NULL REFERENCES public.tournaments(tournament_id) ON DELETE CASCADE,
    team_id UUID NOT NULL REFERENCES public.teams(team_id),
    sport_id UUID NOT NULL REFERENCES public.sports(sport_id),
    matches_played INTEGER NOT NULL DEFAULT 0,
    goals_scored INTEGER NOT NULL DEFAULT 0,
    assists INTEGER NOT NULL DEFAULT 0,
    yellow_cards INTEGER NOT NULL DEFAULT 0,
    red_cards INTEGER NOT NULL DEFAULT 0,
    minutes_played INTEGER NOT NULL DEFAULT 0,
    wins INTEGER NOT NULL DEFAULT 0,
    losses INTEGER NOT NULL DEFAULT 0,
    draws INTEGER NOT NULL DEFAULT 0,
    goals_per_match DECIMAL(4,2) DEFAULT 0,
    minutes_per_goal DECIMAL(6,2) DEFAULT 0,
    additional_stats JSONB,
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    UNIQUE(player_id, tournament_id, team_id)
);

-- Team statistics
CREATE TABLE IF NOT EXISTS public.team_statistics (
    stat_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    team_id UUID NOT NULL REFERENCES public.teams(team_id) ON DELETE CASCADE,
    tournament_id UUID NOT NULL REFERENCES public.tournaments(tournament_id) ON DELETE CASCADE,
    sport_id UUID NOT NULL REFERENCES public.sports(sport_id),
    matches_played INTEGER NOT NULL DEFAULT 0,
    wins INTEGER NOT NULL DEFAULT 0,
    losses INTEGER NOT NULL DEFAULT 0,
    draws INTEGER NOT NULL DEFAULT 0,
    goals_for INTEGER NOT NULL DEFAULT 0,
    goals_against INTEGER NOT NULL DEFAULT 0,
    goal_difference INTEGER NOT NULL DEFAULT 0,
    points INTEGER NOT NULL DEFAULT 0,
    current_position INTEGER,
    recent_form VARCHAR(10),
    additional_stats JSONB,
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    UNIQUE(team_id, tournament_id)
);

-- Tournament standings
CREATE TABLE IF NOT EXISTS public.tournament_standings (
    standing_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tournament_id UUID NOT NULL REFERENCES public.tournaments(tournament_id) ON DELETE CASCADE,
    category_id UUID REFERENCES public.tournament_categories(category_id),
    team_id UUID NOT NULL REFERENCES public.teams(team_id),
    position INTEGER NOT NULL,
    points INTEGER NOT NULL DEFAULT 0,
    matches_played INTEGER NOT NULL DEFAULT 0,
    wins INTEGER NOT NULL DEFAULT 0,
    draws INTEGER NOT NULL DEFAULT 0,
    losses INTEGER NOT NULL DEFAULT 0,
    goals_for INTEGER NOT NULL DEFAULT 0,
    goals_against INTEGER NOT NULL DEFAULT 0,
    goal_difference INTEGER NOT NULL DEFAULT 0,
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    UNIQUE(tournament_id, category_id, team_id)
);

-- Player rankings
CREATE TABLE IF NOT EXISTS public.player_rankings (
    ranking_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tournament_id UUID NOT NULL REFERENCES public.tournaments(tournament_id) ON DELETE CASCADE,
    player_id UUID NOT NULL REFERENCES public.players(player_id),
    ranking_type VARCHAR(50) NOT NULL,
    position INTEGER NOT NULL,
    value DECIMAL(10,2) NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    UNIQUE(tournament_id, player_id, ranking_type)
);

-- Historical statistics
CREATE TABLE IF NOT EXISTS public.historical_statistics (
    history_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    entity_type VARCHAR(20) NOT NULL CHECK (entity_type IN ('player', 'team')),
    entity_id UUID NOT NULL,
    tournament_id UUID REFERENCES public.tournaments(tournament_id),
    snapshot_date DATE NOT NULL,
    statistics_data JSONB NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW()
);

-- Player transfers
CREATE TABLE IF NOT EXISTS public.player_transfers (
    transfer_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    player_id UUID NOT NULL REFERENCES public.players(player_id),
    from_team_id UUID REFERENCES public.teams(team_id),
    to_team_id UUID NOT NULL REFERENCES public.teams(team_id),
    transfer_date DATE NOT NULL,
    status VARCHAR(20) NOT NULL DEFAULT 'pending' 
        CHECK (status IN ('pending', 'approved', 'rejected', 'cancelled')),
    approved_by_user_id UUID REFERENCES public.user_profiles(user_id),
    notes TEXT,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW()
);

-- =====================================================
-- BASIC INDEXES
-- =====================================================

-- User profiles indexes
CREATE INDEX IF NOT EXISTS idx_user_profiles_email ON public.user_profiles(email);
CREATE INDEX IF NOT EXISTS idx_user_profiles_role ON public.user_profiles(primary_role);
CREATE INDEX IF NOT EXISTS idx_user_profiles_active ON public.user_profiles(is_active);

-- User roles indexes
CREATE INDEX IF NOT EXISTS idx_user_roles_user_id ON public.user_roles_by_city_sport(user_id);
CREATE INDEX IF NOT EXISTS idx_user_roles_city_sport ON public.user_roles_by_city_sport(city_id, sport_id);

-- Tournament indexes
CREATE INDEX IF NOT EXISTS idx_tournaments_city_sport ON public.tournaments(city_id, sport_id);
CREATE INDEX IF NOT EXISTS idx_tournaments_status ON public.tournaments(status);
CREATE INDEX IF NOT EXISTS idx_tournaments_dates ON public.tournaments(start_date, end_date);

-- Team indexes
CREATE INDEX IF NOT EXISTS idx_teams_owner ON public.teams(owner_user_id);
CREATE INDEX IF NOT EXISTS idx_teams_city_sport ON public.teams(city_id, sport_id);

-- Match indexes
CREATE INDEX IF NOT EXISTS idx_matches_tournament ON public.matches(tournament_id);
CREATE INDEX IF NOT EXISTS idx_matches_date ON public.matches(match_date);
CREATE INDEX IF NOT EXISTS idx_matches_teams ON public.matches(team1_id, team2_id);

-- Statistics indexes
CREATE INDEX IF NOT EXISTS idx_player_stats_tournament ON public.player_statistics(tournament_id);
CREATE INDEX IF NOT EXISTS idx_team_stats_tournament ON public.team_statistics(tournament_id);

-- Audit logs index
CREATE INDEX IF NOT EXISTS idx_audit_logs_created_at ON public.audit_logs(created_at);
CREATE INDEX IF NOT EXISTS idx_audit_logs_user_action ON public.audit_logs(user_id, action);

-- =====================================================
-- UPDATED_AT TRIGGERS
-- =====================================================

-- Create trigger function for updated_at
CREATE OR REPLACE FUNCTION public.update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Apply triggers to tables with updated_at
CREATE TRIGGER update_cities_updated_at BEFORE UPDATE ON public.cities FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();
CREATE TRIGGER update_sports_updated_at BEFORE UPDATE ON public.sports FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();
CREATE TRIGGER update_user_profiles_updated_at BEFORE UPDATE ON public.user_profiles FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();
CREATE TRIGGER update_tournaments_updated_at BEFORE UPDATE ON public.tournaments FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();
CREATE TRIGGER update_teams_updated_at BEFORE UPDATE ON public.teams FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();
CREATE TRIGGER update_players_updated_at BEFORE UPDATE ON public.players FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();
CREATE TRIGGER update_matches_updated_at BEFORE UPDATE ON public.matches FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();