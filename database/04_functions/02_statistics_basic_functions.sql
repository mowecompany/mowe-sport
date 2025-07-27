-- =====================================================
-- MOWE SPORT PLATFORM - BASIC STATISTICS FUNCTIONS
-- =====================================================
-- Description: Basic statistics calculation functions
-- Dependencies: Statistics tables
-- =====================================================

-- Function to recalculate player statistics for a specific player/tournament/team
CREATE OR REPLACE FUNCTION public.recalculate_player_statistics_basic(
    p_player_id UUID,
    p_tournament_id UUID,
    p_team_id UUID
) RETURNS JSONB AS $$
DECLARE
    v_stats RECORD;
    v_sport_id UUID;
    v_wins INTEGER := 0;
    v_losses INTEGER := 0;
    v_draws INTEGER := 0;
    result JSONB;
BEGIN
    -- Get sport_id from tournament
    SELECT sport_id INTO v_sport_id
    FROM public.tournaments
    WHERE tournament_id = p_tournament_id;
    
    IF NOT FOUND THEN
        RETURN jsonb_build_object(
            'success', false,
            'message', 'Tournament not found'
        );
    END IF;
    
    -- Calculate basic statistics from match events
    SELECT 
        COUNT(DISTINCT m.match_id) as matches_played,
        COALESCE(SUM(90), 0) as minutes_played, -- Simplified calculation
        COUNT(CASE WHEN me.event_type = 'goal' THEN 1 END) as goals_scored,
        COUNT(CASE WHEN me.event_type = 'assist' THEN 1 END) as assists,
        COUNT(CASE WHEN me.event_type = 'yellow_card' THEN 1 END) as yellow_cards,
        COUNT(CASE WHEN me.event_type = 'red_card' THEN 1 END) as red_cards
    INTO v_stats
    FROM public.matches m
    LEFT JOIN public.match_events me ON m.match_id = me.match_id 
        AND me.player_id = p_player_id 
        AND me.team_id = p_team_id
    WHERE m.tournament_id = p_tournament_id
        AND m.status = 'completed'
        AND (m.home_team_id = p_team_id OR m.away_team_id = p_team_id);
    
    -- Calculate wins, losses, draws (simplified)
    SELECT 
        COUNT(CASE 
            WHEN (m.home_team_id = p_team_id AND m.home_score > m.away_score) OR
                 (m.away_team_id = p_team_id AND m.away_score > m.home_score)
            THEN 1 END) as wins,
        COUNT(CASE 
            WHEN (m.home_team_id = p_team_id AND m.home_score < m.away_score) OR
                 (m.away_team_id = p_team_id AND m.away_score < m.home_score)
            THEN 1 END) as losses,
        COUNT(CASE 
            WHEN m.home_score = m.away_score
            THEN 1 END) as draws
    INTO v_wins, v_losses, v_draws
    FROM public.matches m
    WHERE m.tournament_id = p_tournament_id
        AND m.status = 'completed'
        AND (m.home_team_id = p_team_id OR m.away_team_id = p_team_id);
    
    -- Insert or update player statistics
    INSERT INTO public.player_statistics (
        player_id, tournament_id, team_id, sport_id,
        matches_played, minutes_played,
        goals_scored, assists,
        yellow_cards, red_cards,
        wins, losses, draws,
        last_calculated_at
    ) VALUES (
        p_player_id, p_tournament_id, p_team_id, v_sport_id,
        COALESCE(v_stats.matches_played, 0), COALESCE(v_stats.minutes_played, 0),
        COALESCE(v_stats.goals_scored, 0), COALESCE(v_stats.assists, 0),
        COALESCE(v_stats.yellow_cards, 0), COALESCE(v_stats.red_cards, 0),
        COALESCE(v_wins, 0), COALESCE(v_losses, 0), COALESCE(v_draws, 0),
        NOW()
    )
    ON CONFLICT (player_id, tournament_id, team_id)
    DO UPDATE SET
        matches_played = EXCLUDED.matches_played,
        minutes_played = EXCLUDED.minutes_played,
        goals_scored = EXCLUDED.goals_scored,
        assists = EXCLUDED.assists,
        yellow_cards = EXCLUDED.yellow_cards,
        red_cards = EXCLUDED.red_cards,
        wins = EXCLUDED.wins,
        losses = EXCLUDED.losses,
        draws = EXCLUDED.draws,
        last_calculated_at = NOW(),
        updated_at = NOW();
    
    -- Log the recalculation
    INSERT INTO public.audit_logs (
        user_id,
        action,
        table_name,
        record_id,
        new_values
    ) VALUES (
        NULL, -- System action
        'PLAYER_STATS_RECALCULATED',
        'player_statistics',
        p_player_id,
        jsonb_build_object(
            'player_id', p_player_id,
            'tournament_id', p_tournament_id,
            'team_id', p_team_id,
            'matches_played', COALESCE(v_stats.matches_played, 0),
            'goals_scored', COALESCE(v_stats.goals_scored, 0),
            'assists', COALESCE(v_stats.assists, 0)
        )
    );
    
    result := jsonb_build_object(
        'success', true,
        'player_id', p_player_id,
        'tournament_id', p_tournament_id,
        'team_id', p_team_id,
        'statistics', jsonb_build_object(
            'matches_played', COALESCE(v_stats.matches_played, 0),
            'goals_scored', COALESCE(v_stats.goals_scored, 0),
            'assists', COALESCE(v_stats.assists, 0),
            'wins', COALESCE(v_wins, 0),
            'losses', COALESCE(v_losses, 0),
            'draws', COALESCE(v_draws, 0)
        ),
        'message', 'Player statistics recalculated successfully'
    );
    
    RETURN result;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to recalculate team statistics for a specific team/tournament
CREATE OR REPLACE FUNCTION public.recalculate_team_statistics_basic(
    p_team_id UUID,
    p_tournament_id UUID,
    p_category_id UUID DEFAULT NULL
) RETURNS JSONB AS $$
DECLARE
    v_stats RECORD;
    v_sport_id UUID;
    result JSONB;
BEGIN
    -- Get sport_id from tournament
    SELECT sport_id INTO v_sport_id
    FROM public.tournaments
    WHERE tournament_id = p_tournament_id;
    
    IF NOT FOUND THEN
        RETURN jsonb_build_object(
            'success', false,
            'message', 'Tournament not found'
        );
    END IF;
    
    -- Calculate team statistics from matches
    SELECT 
        COUNT(*) as matches_played,
        COUNT(CASE 
            WHEN (m.home_team_id = p_team_id AND m.home_score > m.away_score) OR
                 (m.away_team_id = p_team_id AND m.away_score > m.home_score)
            THEN 1 END) as wins,
        COUNT(CASE 
            WHEN (m.home_team_id = p_team_id AND m.home_score < m.away_score) OR
                 (m.away_team_id = p_team_id AND m.away_score < m.home_score)
            THEN 1 END) as losses,
        COUNT(CASE 
            WHEN m.home_score = m.away_score
            THEN 1 END) as draws,
        SUM(CASE 
            WHEN m.home_team_id = p_team_id THEN m.home_score
            ELSE m.away_score
        END) as goals_for,
        SUM(CASE 
            WHEN m.home_team_id = p_team_id THEN m.away_score
            ELSE m.home_score
        END) as goals_against
    INTO v_stats
    FROM public.matches m
    WHERE m.tournament_id = p_tournament_id
        AND m.status = 'completed'
        AND (m.home_team_id = p_team_id OR m.away_team_id = p_team_id)
        AND (p_category_id IS NULL OR m.category_id = p_category_id);
    
    -- Calculate points (3 for win, 1 for draw, 0 for loss)
    v_stats.points := (COALESCE(v_stats.wins, 0) * 3) + COALESCE(v_stats.draws, 0);
    
    -- Insert or update team statistics
    INSERT INTO public.team_statistics (
        team_id, tournament_id, sport_id, category_id,
        matches_played, wins, losses, draws,
        goals_for, goals_against, points,
        last_calculated_at
    ) VALUES (
        p_team_id, p_tournament_id, v_sport_id, p_category_id,
        COALESCE(v_stats.matches_played, 0), COALESCE(v_stats.wins, 0), 
        COALESCE(v_stats.losses, 0), COALESCE(v_stats.draws, 0),
        COALESCE(v_stats.goals_for, 0), COALESCE(v_stats.goals_against, 0), 
        COALESCE(v_stats.points, 0),
        NOW()
    )
    ON CONFLICT (team_id, tournament_id, category_id)
    DO UPDATE SET
        matches_played = EXCLUDED.matches_played,
        wins = EXCLUDED.wins,
        losses = EXCLUDED.losses,
        draws = EXCLUDED.draws,
        goals_for = EXCLUDED.goals_for,
        goals_against = EXCLUDED.goals_against,
        points = EXCLUDED.points,
        last_calculated_at = NOW(),
        updated_at = NOW();
    
    -- Log the recalculation
    INSERT INTO public.audit_logs (
        user_id,
        action,
        table_name,
        record_id,
        new_values
    ) VALUES (
        NULL, -- System action
        'TEAM_STATS_RECALCULATED',
        'team_statistics',
        p_team_id,
        jsonb_build_object(
            'team_id', p_team_id,
            'tournament_id', p_tournament_id,
            'category_id', p_category_id,
            'matches_played', COALESCE(v_stats.matches_played, 0),
            'wins', COALESCE(v_stats.wins, 0),
            'points', COALESCE(v_stats.points, 0),
            'goals_for', COALESCE(v_stats.goals_for, 0),
            'goals_against', COALESCE(v_stats.goals_against, 0)
        )
    );
    
    result := jsonb_build_object(
        'success', true,
        'team_id', p_team_id,
        'tournament_id', p_tournament_id,
        'category_id', p_category_id,
        'statistics', jsonb_build_object(
            'matches_played', COALESCE(v_stats.matches_played, 0),
            'wins', COALESCE(v_stats.wins, 0),
            'losses', COALESCE(v_stats.losses, 0),
            'draws', COALESCE(v_stats.draws, 0),
            'points', COALESCE(v_stats.points, 0),
            'goals_for', COALESCE(v_stats.goals_for, 0),
            'goals_against', COALESCE(v_stats.goals_against, 0),
            'goal_difference', COALESCE(v_stats.goals_for, 0) - COALESCE(v_stats.goals_against, 0)
        ),
        'message', 'Team statistics recalculated successfully'
    );
    
    RETURN result;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to update tournament standings
CREATE OR REPLACE FUNCTION public.update_tournament_standings_basic(
    p_tournament_id UUID,
    p_category_id UUID DEFAULT NULL
) RETURNS JSONB AS $$
DECLARE
    team_record RECORD;
    position_counter INTEGER := 1;
    processed_count INTEGER := 0;
    result JSONB;
BEGIN
    -- Clear existing standings for this tournament/category
    DELETE FROM public.tournament_standings
    WHERE tournament_id = p_tournament_id
        AND (p_category_id IS NULL OR category_id = p_category_id);
    
    -- Calculate and insert new standings
    FOR team_record IN
        SELECT 
            ts.team_id,
            ts.matches_played,
            ts.wins,
            ts.draws,
            ts.losses,
            ts.goals_for,
            ts.goals_against,
            ts.points,
            (ts.goals_for - ts.goals_against) as goal_difference
        FROM public.team_statistics ts
        WHERE ts.tournament_id = p_tournament_id
            AND (p_category_id IS NULL OR ts.category_id = p_category_id)
        ORDER BY 
            ts.points DESC,
            (ts.goals_for - ts.goals_against) DESC,
            ts.goals_for DESC,
            ts.wins DESC
    LOOP
        INSERT INTO public.tournament_standings (
            tournament_id,
            team_id,
            category_id,
            position,
            points,
            matches_played,
            wins,
            draws,
            losses,
            goals_for,
            goals_against,
            last_updated_at
        ) VALUES (
            p_tournament_id,
            team_record.team_id,
            p_category_id,
            position_counter,
            team_record.points,
            team_record.matches_played,
            team_record.wins,
            team_record.draws,
            team_record.losses,
            team_record.goals_for,
            team_record.goals_against,
            NOW()
        );
        
        -- Update team statistics with current position
        UPDATE public.team_statistics
        SET 
            previous_position = current_position,
            current_position = position_counter,
            updated_at = NOW()
        WHERE team_id = team_record.team_id
            AND tournament_id = p_tournament_id
            AND (p_category_id IS NULL OR category_id = p_category_id);
        
        position_counter := position_counter + 1;
        processed_count := processed_count + 1;
    END LOOP;
    
    -- Log the standings update
    INSERT INTO public.audit_logs (
        user_id,
        action,
        table_name,
        record_id,
        new_values
    ) VALUES (
        NULL, -- System action
        'TOURNAMENT_STANDINGS_UPDATED',
        'tournament_standings',
        p_tournament_id,
        jsonb_build_object(
            'tournament_id', p_tournament_id,
            'category_id', p_category_id,
            'teams_processed', processed_count
        )
    );
    
    result := jsonb_build_object(
        'success', true,
        'tournament_id', p_tournament_id,
        'category_id', p_category_id,
        'teams_processed', processed_count,
        'message', format('Tournament standings updated for %s teams', processed_count)
    );
    
    RETURN result;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to get statistics summary for a tournament
CREATE OR REPLACE FUNCTION public.get_tournament_statistics_summary_basic(
    p_tournament_id UUID
) RETURNS JSONB AS $$
DECLARE
    tournament_info RECORD;
    team_count INTEGER;
    player_count INTEGER;
    match_count INTEGER;
    completed_matches INTEGER;
    total_goals INTEGER;
    result JSONB;
BEGIN
    -- Get tournament basic info
    SELECT name, status, start_date, end_date
    INTO tournament_info
    FROM public.tournaments
    WHERE tournament_id = p_tournament_id;
    
    IF NOT FOUND THEN
        RETURN jsonb_build_object(
            'success', false,
            'message', 'Tournament not found'
        );
    END IF;
    
    -- Get statistics counts
    SELECT COUNT(*) INTO team_count
    FROM public.team_statistics
    WHERE tournament_id = p_tournament_id;
    
    SELECT COUNT(DISTINCT ps.player_id) INTO player_count
    FROM public.player_statistics ps
    WHERE ps.tournament_id = p_tournament_id;
    
    SELECT COUNT(*), COUNT(CASE WHEN status = 'completed' THEN 1 END)
    INTO match_count, completed_matches
    FROM public.matches
    WHERE tournament_id = p_tournament_id;
    
    SELECT SUM(goals_for) INTO total_goals
    FROM public.team_statistics
    WHERE tournament_id = p_tournament_id;
    
    result := jsonb_build_object(
        'success', true,
        'tournament_id', p_tournament_id,
        'tournament_info', jsonb_build_object(
            'name', tournament_info.name,
            'status', tournament_info.status,
            'start_date', tournament_info.start_date,
            'end_date', tournament_info.end_date
        ),
        'statistics_summary', jsonb_build_object(
            'total_teams', COALESCE(team_count, 0),
            'total_players', COALESCE(player_count, 0),
            'total_matches', COALESCE(match_count, 0),
            'completed_matches', COALESCE(completed_matches, 0),
            'total_goals', COALESCE(total_goals, 0),
            'average_goals_per_match', 
                CASE 
                    WHEN completed_matches > 0 THEN ROUND(total_goals::DECIMAL / completed_matches, 2)
                    ELSE 0 
                END
        ),
        'last_updated', NOW()
    );
    
    RETURN result;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Add function comments
COMMENT ON FUNCTION public.recalculate_player_statistics_basic(UUID, UUID, UUID) IS 'Basic player statistics recalculation for a specific player in a tournament/team';
COMMENT ON FUNCTION public.recalculate_team_statistics_basic(UUID, UUID, UUID) IS 'Basic team statistics recalculation for a specific team in a tournament';
COMMENT ON FUNCTION public.update_tournament_standings_basic(UUID, UUID) IS 'Basic tournament standings update based on team statistics';
COMMENT ON FUNCTION public.get_tournament_statistics_summary_basic(UUID) IS 'Get basic statistics summary for a tournament';

-- Log completion
INSERT INTO public.audit_logs (
    user_id,
    action,
    table_name,
    record_id,
    new_values,
    ip_address,
    user_agent
) VALUES (
    '00000000-0000-0000-0000-000000000001',
    'SYSTEM_INIT',
    'statistics_functions_basic',
    NULL,
    '{"message": "Basic statistics functions implemented", "functions_created": ["player_statistics_basic", "team_statistics_basic", "tournament_standings_basic", "statistics_summary_basic"]}'::jsonb,
    '127.0.0.1'::inet,
    'Mowe Sport Database Migration'
);