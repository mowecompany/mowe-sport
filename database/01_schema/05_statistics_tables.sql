-- =====================================================
-- MOWE SPORT PLATFORM - STATISTICS TABLES
-- =====================================================
-- Description: Player and team statistics, rankings, and aggregated data
-- Dependencies: All previous schema files
-- Execution Order: 5th (Final schema file)
-- =====================================================

-- =====================================================
-- PLAYER STATISTICS TABLE
-- =====================================================
-- Aggregated statistics for players by tournament/team/sport
CREATE TABLE public.player_statistics (
    stat_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    player_id UUID NOT NULL REFERENCES public.players(player_id) ON DELETE CASCADE,
    tournament_id UUID NOT NULL REFERENCES public.tournaments(tournament_id) ON DELETE CASCADE,
    team_id UUID NOT NULL REFERENCES public.teams(team_id) ON DELETE CASCADE,
    sport_id UUID NOT NULL REFERENCES public.sports(sport_id) ON DELETE RESTRICT,
    
    -- Match participation
    matches_played INTEGER NOT NULL DEFAULT 0,
    matches_started INTEGER NOT NULL DEFAULT 0,
    matches_as_substitute INTEGER NOT NULL DEFAULT 0,
    minutes_played INTEGER NOT NULL DEFAULT 0,
    
    -- Scoring statistics
    goals_scored INTEGER NOT NULL DEFAULT 0,
    penalty_goals INTEGER NOT NULL DEFAULT 0,
    own_goals INTEGER NOT NULL DEFAULT 0,
    assists INTEGER NOT NULL DEFAULT 0,
    
    -- Disciplinary statistics
    yellow_cards INTEGER NOT NULL DEFAULT 0,
    red_cards INTEGER NOT NULL DEFAULT 0,
    
    -- Performance statistics
    shots_on_target INTEGER NOT NULL DEFAULT 0,
    shots_off_target INTEGER NOT NULL DEFAULT 0,
    corners_taken INTEGER NOT NULL DEFAULT 0,
    free_kicks_taken INTEGER NOT NULL DEFAULT 0,
    penalties_taken INTEGER NOT NULL DEFAULT 0,
    penalties_scored INTEGER NOT NULL DEFAULT 0,
    
    -- Team performance
    wins INTEGER NOT NULL DEFAULT 0,
    losses INTEGER NOT NULL DEFAULT 0,
    draws INTEGER NOT NULL DEFAULT 0,
    clean_sheets INTEGER NOT NULL DEFAULT 0, -- For goalkeepers/defenders
    
    -- Calculated fields
    goals_per_match DECIMAL(4,2) GENERATED ALWAYS AS (
        CASE WHEN matches_played > 0 THEN goals_scored::DECIMAL / matches_played ELSE 0 END
    ) STORED,
    minutes_per_goal DECIMAL(8,2) GENERATED ALWAYS AS (
        CASE WHEN goals_scored > 0 THEN minutes_played::DECIMAL / goals_scored ELSE NULL END
    ) STORED,
    
    -- Sport-specific statistics (JSON for flexibility)
    additional_stats JSONB,
    
    -- Metadata
    last_calculated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    
    -- Ensure unique stats per player/tournament/team combination
    UNIQUE(player_id, tournament_id, team_id),
    
    -- Validation constraints
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

-- Add comment for documentation
COMMENT ON TABLE public.player_statistics IS 'Aggregated player statistics by tournament and team';
COMMENT ON COLUMN public.player_statistics.additional_stats IS 'Sport-specific statistics in JSON format';
COMMENT ON COLUMN public.player_statistics.last_calculated_at IS 'When statistics were last recalculated';

-- =====================================================
-- TEAM STATISTICS TABLE
-- =====================================================
-- Aggregated statistics for teams by tournament
CREATE TABLE public.team_statistics (
    stat_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    team_id UUID NOT NULL REFERENCES public.teams(team_id) ON DELETE CASCADE,
    tournament_id UUID NOT NULL REFERENCES public.tournaments(tournament_id) ON DELETE CASCADE,
    sport_id UUID NOT NULL REFERENCES public.sports(sport_id) ON DELETE RESTRICT,
    category_id UUID REFERENCES public.tournament_categories(category_id) ON DELETE CASCADE,
    phase_id UUID REFERENCES public.tournament_phases(phase_id) ON DELETE SET NULL,
    group_id UUID REFERENCES public.tournament_groups(group_id) ON DELETE SET NULL,
    
    -- Match results
    matches_played INTEGER NOT NULL DEFAULT 0,
    wins INTEGER NOT NULL DEFAULT 0,
    losses INTEGER NOT NULL DEFAULT 0,
    draws INTEGER NOT NULL DEFAULT 0,
    
    -- Scoring statistics
    goals_for INTEGER NOT NULL DEFAULT 0,
    goals_against INTEGER NOT NULL DEFAULT 0,
    goal_difference INTEGER GENERATED ALWAYS AS (goals_for - goals_against) STORED,
    
    -- Points calculation (typically 3 for win, 1 for draw, 0 for loss)
    points INTEGER NOT NULL DEFAULT 0,
    
    -- Performance metrics
    clean_sheets INTEGER NOT NULL DEFAULT 0,
    failed_to_score INTEGER NOT NULL DEFAULT 0,
    
    -- Disciplinary
    yellow_cards INTEGER NOT NULL DEFAULT 0,
    red_cards INTEGER NOT NULL DEFAULT 0,
    
    -- Position and ranking
    current_position INTEGER,
    previous_position INTEGER,
    highest_position INTEGER,
    lowest_position INTEGER,
    
    -- Form (last 5 matches)
    recent_form VARCHAR(5), -- e.g., "WWDLW"
    
    -- Calculated averages
    points_per_match DECIMAL(4,2) GENERATED ALWAYS AS (
        CASE WHEN matches_played > 0 THEN points::DECIMAL / matches_played ELSE 0 END
    ) STORED,
    goals_per_match DECIMAL(4,2) GENERATED ALWAYS AS (
        CASE WHEN matches_played > 0 THEN goals_for::DECIMAL / matches_played ELSE 0 END
    ) STORED,
    goals_conceded_per_match DECIMAL(4,2) GENERATED ALWAYS AS (
        CASE WHEN matches_played > 0 THEN goals_against::DECIMAL / matches_played ELSE 0 END
    ) STORED,
    
    -- Sport-specific statistics
    additional_stats JSONB,
    
    -- Metadata
    last_calculated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    
    -- Ensure unique stats per team/tournament/category combination
    UNIQUE(team_id, tournament_id, category_id),
    
    -- Validation constraints
    CHECK (matches_played >= 0),
    CHECK (wins >= 0 AND losses >= 0 AND draws >= 0),
    CHECK (wins + losses + draws = matches_played),
    CHECK (goals_for >= 0 AND goals_against >= 0),
    CHECK (points >= 0),
    CHECK (current_position IS NULL OR current_position > 0),
    CHECK (LENGTH(recent_form) <= 5)
);

-- Add comment for documentation
COMMENT ON TABLE public.team_statistics IS 'Aggregated team statistics by tournament';
COMMENT ON COLUMN public.team_statistics.recent_form IS 'Last 5 match results (W=Win, D=Draw, L=Loss)';
COMMENT ON COLUMN public.team_statistics.additional_stats IS 'Sport-specific statistics in JSON format';

-- =====================================================
-- TOURNAMENT STANDINGS TABLE
-- =====================================================
-- Current standings/rankings for tournaments
CREATE TABLE public.tournament_standings (
    standing_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tournament_id UUID NOT NULL REFERENCES public.tournaments(tournament_id) ON DELETE CASCADE,
    team_id UUID NOT NULL REFERENCES public.teams(team_id) ON DELETE CASCADE,
    category_id UUID REFERENCES public.tournament_categories(category_id) ON DELETE CASCADE,
    phase_id UUID REFERENCES public.tournament_phases(phase_id) ON DELETE CASCADE,
    group_id UUID REFERENCES public.tournament_groups(group_id) ON DELETE SET NULL,
    
    position INTEGER NOT NULL,
    points INTEGER NOT NULL DEFAULT 0,
    matches_played INTEGER NOT NULL DEFAULT 0,
    wins INTEGER NOT NULL DEFAULT 0,
    draws INTEGER NOT NULL DEFAULT 0,
    losses INTEGER NOT NULL DEFAULT 0,
    goals_for INTEGER NOT NULL DEFAULT 0,
    goals_against INTEGER NOT NULL DEFAULT 0,
    goal_difference INTEGER GENERATED ALWAYS AS (goals_for - goals_against) STORED,
    
    -- Tiebreaker information
    head_to_head_points INTEGER DEFAULT 0,
    head_to_head_goal_difference INTEGER DEFAULT 0,
    
    -- Qualification status
    qualification_status VARCHAR(20) CHECK (
        qualification_status IN (
            'qualified', 
            'playoff', 
            'eliminated', 
            'relegated', 
            'promoted',
            'champion'
        )
    ),
    
    -- Metadata
    last_updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    
    -- Ensure unique position per tournament/category/phase/group
    UNIQUE(tournament_id, category_id, phase_id, group_id, position),
    -- Ensure unique team per tournament/category/phase/group
    UNIQUE(tournament_id, category_id, phase_id, group_id, team_id),
    
    -- Validation
    CHECK (position > 0),
    CHECK (points >= 0),
    CHECK (matches_played >= 0),
    CHECK (wins + draws + losses = matches_played)
);

-- Add comment for documentation
COMMENT ON TABLE public.tournament_standings IS 'Current tournament standings and rankings';
COMMENT ON COLUMN public.tournament_standings.qualification_status IS 'Team qualification status in tournament';

-- =====================================================
-- PLAYER RANKINGS TABLE
-- =====================================================
-- Rankings for individual players (top scorers, etc.)
CREATE TABLE public.player_rankings (
    ranking_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tournament_id UUID NOT NULL REFERENCES public.tournaments(tournament_id) ON DELETE CASCADE,
    sport_id UUID NOT NULL REFERENCES public.sports(sport_id) ON DELETE RESTRICT,
    category_id UUID REFERENCES public.tournament_categories(category_id) ON DELETE CASCADE,
    player_id UUID NOT NULL REFERENCES public.players(player_id) ON DELETE CASCADE,
    team_id UUID NOT NULL REFERENCES public.teams(team_id) ON DELETE CASCADE,
    
    ranking_type VARCHAR(30) NOT NULL CHECK (
        ranking_type IN (
            'top_scorer',
            'most_assists',
            'most_yellow_cards',
            'most_red_cards',
            'most_minutes',
            'best_goalkeeper',
            'most_valuable_player'
        )
    ),
    
    position INTEGER NOT NULL,
    value INTEGER NOT NULL, -- The actual statistic value
    additional_info JSONB,
    
    last_updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    
    -- Ensure unique position per ranking type/tournament/category
    UNIQUE(tournament_id, category_id, ranking_type, position),
    
    -- Validation
    CHECK (position > 0),
    CHECK (value >= 0)
);

-- Add comment for documentation
COMMENT ON TABLE public.player_rankings IS 'Player rankings for various statistics';
COMMENT ON COLUMN public.player_rankings.value IS 'The statistic value for this ranking';

-- =====================================================
-- HISTORICAL STATISTICS TABLE
-- =====================================================
-- Historical snapshots of statistics for trend analysis
CREATE TABLE public.historical_statistics (
    history_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    entity_type VARCHAR(20) NOT NULL CHECK (entity_type IN ('player', 'team')),
    entity_id UUID NOT NULL, -- player_id or team_id
    tournament_id UUID NOT NULL REFERENCES public.tournaments(tournament_id) ON DELETE CASCADE,
    snapshot_date DATE NOT NULL,
    statistics_data JSONB NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    
    -- Ensure unique snapshot per entity/tournament/date
    UNIQUE(entity_type, entity_id, tournament_id, snapshot_date)
);

-- Add comment for documentation
COMMENT ON TABLE public.historical_statistics IS 'Historical snapshots of statistics for trend analysis';
COMMENT ON COLUMN public.historical_statistics.statistics_data IS 'Complete statistics snapshot in JSON format';

-- =====================================================
-- UPDATE TRIGGERS FOR TIMESTAMPS
-- =====================================================

CREATE TRIGGER update_player_statistics_updated_at 
    BEFORE UPDATE ON public.player_statistics 
    FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

CREATE TRIGGER update_team_statistics_updated_at 
    BEFORE UPDATE ON public.team_statistics 
    FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

-- =====================================================
-- FUNCTIONS FOR STATISTICS CALCULATION
-- =====================================================

-- Function to recalculate player statistics
CREATE OR REPLACE FUNCTION public.recalculate_player_statistics(
    p_player_id UUID,
    p_tournament_id UUID,
    p_team_id UUID
) RETURNS VOID AS $$
DECLARE
    v_stats RECORD;
BEGIN
    -- Calculate statistics from match events
    SELECT 
        COUNT(DISTINCT m.match_id) as matches_played,
        COUNT(DISTINCT CASE WHEN ml.is_starter THEN m.match_id END) as matches_started,
        COUNT(DISTINCT CASE WHEN NOT ml.is_starter THEN m.match_id END) as matches_as_substitute,
        COALESCE(SUM(CASE 
            WHEN ml.substituted_at_minute IS NOT NULL 
            THEN ml.substituted_at_minute 
            ELSE 90 
        END), 0) as minutes_played,
        COUNT(CASE WHEN me.event_type = 'goal' THEN 1 END) as goals_scored,
        COUNT(CASE WHEN me.event_type = 'penalty_goal' THEN 1 END) as penalty_goals,
        COUNT(CASE WHEN me.event_type = 'own_goal' THEN 1 END) as own_goals,
        COUNT(CASE WHEN me.event_type = 'assist' THEN 1 END) as assists,
        COUNT(CASE WHEN me.event_type = 'yellow_card' THEN 1 END) as yellow_cards,
        COUNT(CASE WHEN me.event_type = 'red_card' THEN 1 END) as red_cards
    INTO v_stats
    FROM public.matches m
    LEFT JOIN public.match_lineups ml ON m.match_id = ml.match_id 
        AND ml.player_id = p_player_id 
        AND ml.team_id = p_team_id
    LEFT JOIN public.match_events me ON m.match_id = me.match_id 
        AND me.player_id = p_player_id 
        AND me.team_id = p_team_id
        AND me.is_deleted = FALSE
    WHERE m.tournament_id = p_tournament_id
        AND m.status = 'completed'
        AND (m.home_team_id = p_team_id OR m.away_team_id = p_team_id);

    -- Insert or update player statistics
    INSERT INTO public.player_statistics (
        player_id, tournament_id, team_id, sport_id,
        matches_played, matches_started, matches_as_substitute, minutes_played,
        goals_scored, penalty_goals, own_goals, assists,
        yellow_cards, red_cards,
        last_calculated_at
    )
    SELECT 
        p_player_id, p_tournament_id, p_team_id, t.sport_id,
        v_stats.matches_played, v_stats.matches_started, v_stats.matches_as_substitute, v_stats.minutes_played,
        v_stats.goals_scored, v_stats.penalty_goals, v_stats.own_goals, v_stats.assists,
        v_stats.yellow_cards, v_stats.red_cards,
        NOW()
    FROM public.tournaments t
    WHERE t.tournament_id = p_tournament_id
    ON CONFLICT (player_id, tournament_id, team_id)
    DO UPDATE SET
        matches_played = EXCLUDED.matches_played,
        matches_started = EXCLUDED.matches_started,
        matches_as_substitute = EXCLUDED.matches_as_substitute,
        minutes_played = EXCLUDED.minutes_played,
        goals_scored = EXCLUDED.goals_scored,
        penalty_goals = EXCLUDED.penalty_goals,
        own_goals = EXCLUDED.own_goals,
        assists = EXCLUDED.assists,
        yellow_cards = EXCLUDED.yellow_cards,
        red_cards = EXCLUDED.red_cards,
        last_calculated_at = NOW(),
        updated_at = NOW();
END;
$$ LANGUAGE plpgsql;

-- Add comment for function
COMMENT ON FUNCTION public.recalculate_player_statistics IS 'Recalculates statistics for a specific player in a tournament/team';

-- =====================================================
-- INDEXES FOR PERFORMANCE
-- =====================================================

-- Player statistics indexes
CREATE INDEX idx_player_statistics_player ON public.player_statistics(player_id);
CREATE INDEX idx_player_statistics_tournament ON public.player_statistics(tournament_id);
CREATE INDEX idx_player_statistics_team ON public.player_statistics(team_id);
CREATE INDEX idx_player_statistics_goals ON public.player_statistics(tournament_id, goals_scored DESC);
CREATE INDEX idx_player_statistics_assists ON public.player_statistics(tournament_id, assists DESC);

-- Team statistics indexes
CREATE INDEX idx_team_statistics_tournament ON public.team_statistics(tournament_id);
CREATE INDEX idx_team_statistics_team ON public.team_statistics(team_id);
CREATE INDEX idx_team_statistics_points ON public.team_statistics(tournament_id, points DESC);
CREATE INDEX idx_team_statistics_position ON public.team_statistics(tournament_id, current_position);

-- Tournament standings indexes
CREATE INDEX idx_tournament_standings_tournament ON public.tournament_standings(tournament_id);
CREATE INDEX idx_tournament_standings_position ON public.tournament_standings(tournament_id, category_id, phase_id, position);
CREATE INDEX idx_tournament_standings_team ON public.tournament_standings(team_id);

-- Player rankings indexes
CREATE INDEX idx_player_rankings_tournament ON public.player_rankings(tournament_id);
CREATE INDEX idx_player_rankings_type ON public.player_rankings(ranking_type, tournament_id);
CREATE INDEX idx_player_rankings_player ON public.player_rankings(player_id);

-- Historical statistics indexes
CREATE INDEX idx_historical_statistics_entity ON public.historical_statistics(entity_type, entity_id);
CREATE INDEX idx_historical_statistics_tournament ON public.historical_statistics(tournament_id);
CREATE INDEX idx_historical_statistics_date ON public.historical_statistics(snapshot_date);

-- =====================================================
-- VIEWS FOR COMMON QUERIES
-- =====================================================

-- View for current top scorers
CREATE VIEW public.current_top_scorers AS
SELECT 
    ps.tournament_id,
    ps.player_id,
    p.first_name,
    p.last_name,
    t.name as team_name,
    ps.goals_scored,
    ps.matches_played,
    ps.goals_per_match,
    ROW_NUMBER() OVER (PARTITION BY ps.tournament_id ORDER BY ps.goals_scored DESC, ps.goals_per_match DESC) as position
FROM public.player_statistics ps
JOIN public.players p ON ps.player_id = p.player_id
JOIN public.teams t ON ps.team_id = t.team_id
WHERE ps.goals_scored > 0
ORDER BY ps.tournament_id, ps.goals_scored DESC;

-- Add comment for view
COMMENT ON VIEW public.current_top_scorers IS 'Current top scorers by tournament';

-- =====================================================
-- ENABLE REALTIME FOR STATISTICS TABLES
-- =====================================================
-- Enable Supabase Realtime for live statistics updates
ALTER PUBLICATION supabase_realtime ADD TABLE public.player_statistics;
ALTER PUBLICATION supabase_realtime ADD TABLE public.team_statistics;
ALTER PUBLICATION supabase_realtime ADD TABLE public.tournament_standings;
ALTER PUBLICATION supabase_realtime ADD TABLE public.player_rankings;