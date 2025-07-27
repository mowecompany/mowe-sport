-- =====================================================
-- MOWE SPORT PLATFORM - DROP AND RECREATE STATISTICS FUNCTIONS
-- =====================================================
-- Description: Drop existing statistics functions and recreate with correct signatures
-- =====================================================

-- Drop existing statistics functions
DROP FUNCTION IF EXISTS public.recalculate_player_statistics(UUID, UUID, UUID);
DROP FUNCTION IF EXISTS public.recalculate_all_player_statistics(UUID);
DROP FUNCTION IF EXISTS public.recalculate_team_statistics(UUID, UUID, UUID);
DROP FUNCTION IF EXISTS public.recalculate_all_team_statistics(UUID, UUID);
DROP FUNCTION IF EXISTS public.update_tournament_standings(UUID, UUID, UUID, UUID);
DROP FUNCTION IF EXISTS public.update_player_rankings(UUID, VARCHAR, UUID);
DROP FUNCTION IF EXISTS public.update_all_player_rankings(UUID, UUID);
DROP FUNCTION IF EXISTS public.recalculate_tournament_statistics(UUID, UUID);
DROP FUNCTION IF EXISTS public.daily_statistics_maintenance();
DROP FUNCTION IF EXISTS public.get_tournament_statistics_summary(UUID);

-- Drop existing trigger functions
DROP FUNCTION IF EXISTS public.handle_match_completion();
DROP FUNCTION IF EXISTS public.handle_match_event_change();
DROP FUNCTION IF EXISTS public.handle_match_lineup_change();
DROP FUNCTION IF EXISTS public.handle_tournament_status_change();

-- Drop existing triggers
DROP TRIGGER IF EXISTS trigger_match_completion ON public.matches;
DROP TRIGGER IF EXISTS trigger_match_event_change ON public.match_events;
DROP TRIGGER IF EXISTS trigger_match_lineup_change ON public.match_lineups;
DROP TRIGGER IF EXISTS trigger_tournament_status_change ON public.tournaments;

-- Now recreate the basic recalculate_player_statistics function
CREATE OR REPLACE FUNCTION public.recalculate_player_statistics(
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

-- Create basic team statistics function
CREATE OR REPLACE FUNCTION public.recalculate_team_statistics(
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
            'goals_against', COALESCE(v_stats.goals_against, 0)
        ),
        'message', 'Team statistics recalculated successfully'
    );
    
    RETURN result;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create basic tournament standings function
CREATE OR REPLACE FUNCTION public.update_tournament_standings(
    p_tournament_id UUID,
    p_category_id UUID DEFAULT NULL,
    p_phase_id UUID DEFAULT NULL,
    p_group_id UUID DEFAULT NULL
) RETURNS JSONB AS $$
DECLARE
    team_record RECORD;
    position_counter INTEGER := 1;
    processed_count INTEGER := 0;
    result JSONB;
BEGIN
    -- Clear existing standings for this tournament/category/phase/group
    DELETE FROM public.tournament_standings
    WHERE tournament_id = p_tournament_id
        AND (p_category_id IS NULL OR category_id = p_category_id)
        AND (p_phase_id IS NULL OR phase_id = p_phase_id)
        AND (p_group_id IS NULL OR group_id = p_group_id);
    
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
            phase_id,
            group_id,
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
            p_phase_id,
            p_group_id,
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
        
        position_counter := position_counter + 1;
        processed_count := processed_count + 1;
    END LOOP;
    
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

-- Create basic statistics summary function
CREATE OR REPLACE FUNCTION public.get_tournament_statistics_summary(
    p_tournament_id UUID
) RETURNS JSONB AS $$
DECLARE
    tournament_info RECORD;
    team_count INTEGER;
    player_count INTEGER;
    match_count INTEGER;
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
    
    SELECT COUNT(*) INTO match_count
    FROM public.matches
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
            'total_matches', COALESCE(match_count, 0)
        ),
        'last_updated', NOW()
    );
    
    RETURN result;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Add function comments
COMMENT ON FUNCTION public.recalculate_player_statistics(UUID, UUID, UUID) IS 'Recalculates statistics for a specific player in a tournament/team';
COMMENT ON FUNCTION public.recalculate_team_statistics(UUID, UUID, UUID) IS 'Recalculates statistics for a specific team in a tournament';
COMMENT ON FUNCTION public.update_tournament_standings(UUID, UUID, UUID, UUID) IS 'Updates tournament standings based on team statistics';
COMMENT ON FUNCTION public.get_tournament_statistics_summary(UUID) IS 'Get comprehensive statistics summary for a tournament';