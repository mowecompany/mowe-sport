-- =====================================================
-- MOWE SPORT PLATFORM - MATCH TABLES
-- =====================================================
-- Description: Matches, events, and real-time match data
-- Dependencies: 01_core_tables.sql, 02_tournament_tables.sql, 03_team_player_tables.sql
-- Execution Order: 4th
-- =====================================================

-- =====================================================
-- MATCHES TABLE
-- =====================================================
-- Individual matches between teams
CREATE TABLE public.matches (
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
    assistant_referee_1_id UUID REFERENCES public.user_profiles(user_id) ON DELETE SET NULL,
    assistant_referee_2_id UUID REFERENCES public.user_profiles(user_id) ON DELETE SET NULL,
    fourth_official_id UUID REFERENCES public.user_profiles(user_id) ON DELETE SET NULL,
    home_team_score INTEGER NOT NULL DEFAULT 0,
    away_team_score INTEGER NOT NULL DEFAULT 0,
    home_team_penalty_score INTEGER DEFAULT 0,
    away_team_penalty_score INTEGER DEFAULT 0,
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
    ticket_price DECIMAL(8,2),
    live_stream_url TEXT,
    match_notes TEXT,
    match_data JSONB, -- Additional match metadata
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    
    -- Business logic constraints
    CHECK (home_team_id != away_team_id),
    CHECK (home_team_score >= 0 AND away_team_score >= 0),
    CHECK (home_team_penalty_score IS NULL OR home_team_penalty_score >= 0),
    CHECK (away_team_penalty_score IS NULL OR away_team_penalty_score >= 0),
    CHECK (attendance IS NULL OR attendance >= 0),
    CHECK (actual_end_time IS NULL OR actual_start_time IS NULL OR actual_end_time >= actual_start_time)
);

-- Add comment for documentation
COMMENT ON TABLE public.matches IS 'Individual matches between teams in tournaments';
COMMENT ON COLUMN public.matches.match_duration_minutes IS 'Planned duration of match in minutes';
COMMENT ON COLUMN public.matches.actual_start_time IS 'When match actually started';
COMMENT ON COLUMN public.matches.actual_end_time IS 'When match actually ended';
COMMENT ON COLUMN public.matches.match_data IS 'Additional match metadata in JSON format';

-- =====================================================
-- MATCH EVENTS TABLE
-- =====================================================
-- Events that occur during matches (goals, cards, substitutions, etc.)
CREATE TABLE public.match_events (
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
    related_player_id UUID REFERENCES public.players(player_id) ON DELETE SET NULL, -- For substitutions, assists
    event_data JSONB, -- Additional event metadata
    is_deleted BOOLEAN NOT NULL DEFAULT FALSE,
    deleted_by_user_id UUID REFERENCES public.user_profiles(user_id),
    deleted_at TIMESTAMP WITH TIME ZONE,
    created_by_user_id UUID REFERENCES public.user_profiles(user_id),
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    
    -- Event minute validation
    CHECK (event_minute >= 0 AND event_minute <= 200), -- Allow for very long matches
    CHECK (additional_time >= 0 AND additional_time <= 30)
);

-- Add comment for documentation
COMMENT ON TABLE public.match_events IS 'Events that occur during matches';
COMMENT ON COLUMN public.match_events.event_minute IS 'Minute when event occurred';
COMMENT ON COLUMN public.match_events.additional_time IS 'Additional time (injury time) when event occurred';
COMMENT ON COLUMN public.match_events.related_player_id IS 'Related player (e.g., player coming in for substitution)';
COMMENT ON COLUMN public.match_events.is_deleted IS 'Soft delete flag for event corrections';

-- =====================================================
-- MATCH LINEUPS TABLE
-- =====================================================
-- Starting lineups and formations for each match
CREATE TABLE public.match_lineups (
    lineup_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    match_id UUID NOT NULL REFERENCES public.matches(match_id) ON DELETE CASCADE,
    team_id UUID NOT NULL REFERENCES public.teams(team_id) ON DELETE CASCADE,
    player_id UUID NOT NULL REFERENCES public.players(player_id) ON DELETE CASCADE,
    jersey_number INTEGER NOT NULL,
    position VARCHAR(50) NOT NULL,
    is_starter BOOLEAN NOT NULL DEFAULT TRUE,
    is_captain BOOLEAN NOT NULL DEFAULT FALSE,
    formation_position INTEGER, -- Position in formation (1-11 for starters)
    substituted_at_minute INTEGER,
    substituted_by_player_id UUID REFERENCES public.players(player_id),
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    
    -- Ensure unique player per match per team
    UNIQUE(match_id, team_id, player_id),
    -- Ensure unique jersey numbers per team per match
    UNIQUE(match_id, team_id, jersey_number),
    -- Ensure unique captain per team per match
    UNIQUE(match_id, team_id, is_captain) DEFERRABLE INITIALLY DEFERRED,
    
    -- Validation
    CHECK (jersey_number >= 1 AND jersey_number <= 99),
    CHECK (formation_position IS NULL OR (formation_position >= 1 AND formation_position <= 11)),
    CHECK (substituted_at_minute IS NULL OR substituted_at_minute >= 0)
);

-- Add comment for documentation
COMMENT ON TABLE public.match_lineups IS 'Starting lineups and formations for matches';
COMMENT ON COLUMN public.match_lineups.formation_position IS 'Position in team formation (1-11)';
COMMENT ON COLUMN public.match_lineups.substituted_at_minute IS 'Minute when player was substituted';

-- =====================================================
-- MATCH OFFICIALS TABLE
-- =====================================================
-- Additional officials for matches (beyond main referee)
CREATE TABLE public.match_officials (
    official_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    match_id UUID NOT NULL REFERENCES public.matches(match_id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES public.user_profiles(user_id) ON DELETE CASCADE,
    official_role VARCHAR(30) NOT NULL CHECK (
        official_role IN (
            'referee',
            'assistant_referee_1',
            'assistant_referee_2', 
            'fourth_official',
            'var_referee',
            'avar_referee',
            'timekeeper',
            'scorer'
        )
    ),
    fee DECIMAL(8,2),
    notes TEXT,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    
    -- Ensure unique role per match
    UNIQUE(match_id, official_role),
    -- Ensure unique official per match (can't have multiple roles)
    UNIQUE(match_id, user_id)
);

-- Add comment for documentation
COMMENT ON TABLE public.match_officials IS 'Officials assigned to matches';
COMMENT ON COLUMN public.match_officials.fee IS 'Fee paid to official for the match';

-- =====================================================
-- MATCH COMMENTS TABLE
-- =====================================================
-- Comments and notes about matches from officials and administrators
CREATE TABLE public.match_comments (
    comment_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    match_id UUID NOT NULL REFERENCES public.matches(match_id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES public.user_profiles(user_id) ON DELETE CASCADE,
    comment_type VARCHAR(20) NOT NULL CHECK (
        comment_type IN (
            'referee_report',
            'admin_note',
            'incident_report',
            'general_comment'
        )
    ),
    title VARCHAR(200),
    content TEXT NOT NULL,
    is_public BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW()
);

-- Add comment for documentation
COMMENT ON TABLE public.match_comments IS 'Comments and reports about matches';
COMMENT ON COLUMN public.match_comments.is_public IS 'Whether comment is visible to public';

-- =====================================================
-- MATCH MEDIA TABLE
-- =====================================================
-- Photos, videos, and other media from matches
CREATE TABLE public.match_media (
    media_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    match_id UUID NOT NULL REFERENCES public.matches(match_id) ON DELETE CASCADE,
    uploaded_by_user_id UUID NOT NULL REFERENCES public.user_profiles(user_id) ON DELETE CASCADE,
    media_type VARCHAR(20) NOT NULL CHECK (
        media_type IN ('photo', 'video', 'audio', 'document')
    ),
    file_url TEXT NOT NULL,
    thumbnail_url TEXT,
    title VARCHAR(200),
    description TEXT,
    file_size_bytes BIGINT,
    duration_seconds INTEGER, -- For video/audio
    is_highlight BOOLEAN NOT NULL DEFAULT FALSE,
    is_public BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW()
);

-- Add comment for documentation
COMMENT ON TABLE public.match_media IS 'Photos, videos, and other media from matches';
COMMENT ON COLUMN public.match_media.is_highlight IS 'Whether this is a match highlight';

-- =====================================================
-- UPDATE TRIGGERS FOR TIMESTAMPS
-- =====================================================

CREATE TRIGGER update_matches_updated_at 
    BEFORE UPDATE ON public.matches 
    FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

CREATE TRIGGER update_match_comments_updated_at 
    BEFORE UPDATE ON public.match_comments 
    FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

-- =====================================================
-- INDEXES FOR PERFORMANCE
-- =====================================================

-- Matches indexes
CREATE INDEX idx_matches_tournament ON public.matches(tournament_id);
CREATE INDEX idx_matches_teams ON public.matches(home_team_id, away_team_id);
CREATE INDEX idx_matches_date_time ON public.matches(match_date, match_time);
CREATE INDEX idx_matches_status ON public.matches(status);
CREATE INDEX idx_matches_referee ON public.matches(referee_user_id);
CREATE INDEX idx_matches_live ON public.matches(tournament_id, status) WHERE status IN ('live', 'half_time');

-- Match events indexes
CREATE INDEX idx_match_events_match ON public.match_events(match_id);
CREATE INDEX idx_match_events_player ON public.match_events(player_id);
CREATE INDEX idx_match_events_team ON public.match_events(team_id);
CREATE INDEX idx_match_events_type ON public.match_events(event_type);
CREATE INDEX idx_match_events_time ON public.match_events(match_id, event_minute);
CREATE INDEX idx_match_events_active ON public.match_events(match_id, is_deleted) WHERE is_deleted = FALSE;

-- Match lineups indexes
CREATE INDEX idx_match_lineups_match_team ON public.match_lineups(match_id, team_id);
CREATE INDEX idx_match_lineups_player ON public.match_lineups(player_id);
CREATE INDEX idx_match_lineups_starters ON public.match_lineups(match_id, team_id, is_starter) WHERE is_starter = TRUE;

-- Match officials indexes
CREATE INDEX idx_match_officials_match ON public.match_officials(match_id);
CREATE INDEX idx_match_officials_user ON public.match_officials(user_id);

-- Match comments indexes
CREATE INDEX idx_match_comments_match ON public.match_comments(match_id);
CREATE INDEX idx_match_comments_user ON public.match_comments(user_id);
CREATE INDEX idx_match_comments_public ON public.match_comments(match_id, is_public) WHERE is_public = TRUE;

-- Match media indexes
CREATE INDEX idx_match_media_match ON public.match_media(match_id);
CREATE INDEX idx_match_media_user ON public.match_media(uploaded_by_user_id);
CREATE INDEX idx_match_media_type ON public.match_media(media_type);
CREATE INDEX idx_match_media_highlights ON public.match_media(match_id, is_highlight) WHERE is_highlight = TRUE;