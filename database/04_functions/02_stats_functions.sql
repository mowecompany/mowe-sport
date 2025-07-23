-- =====================================================
-- MOWE SPORT PLATFORM - STATISTICS FUNCTIONS
-- =====================================================
-- Description: Functions for calculating and managing statistics
-- Dependencies: Complete schema and auth functions
-- Execution Order: After auth functions
-- =====================================================

-- =====================================================
-- PLAYER STATISTICS FUNCTIONS
-- =====================================================

-- Function to recalculate player statistics for a tournament/team
CREATE OR REPLACE FUNCTION public.recalculate_player_statistics(
    p_player_id UUID,
    p_tournament_id UUID,
    p_team_id UUID
) RETURNS VOID AS $$
DECLARE
    v_stats RECORD;
    v_sport_id UUID;
BEGIN
    -- Get sport_id from tournament
    SELECT sport_id INTO v_sport_id
    FROM public.tournaments
    WHERE tournament_id = p_tournament_id;
    
    -- Calculate statistics from match events and lineups
    SELECT 
        COUNT(DISTINCT m.match_id) as matches_played,
        COUNT(DISTINCT CASE WHEN ml.is_starter THEN m.match_id END) as matches_started,
        COUNT(DISTINCT CASE WHEN NOT COALESCE(ml.is_starter, FALSE) THEN m.match_id END) as matches_as_substitute,
        COALESCE(SUM(
            CASE 
                WHEN ml.substituted_at_minute IS NOT NULL THEN ml.substituted_at_minute
                WHEN ml.is_starter THEN 90
                ELSE 30 -- Estimated minutes for substitutes
            END
        ), 0) as minutes_played,
        COUNT(CASE WHEN me.event_type = 'goal' THEN 1 END) as goals_scored,
        COUNT(CASE WHEN me.event_type = 'penalty_goal' THEN 1 END) as penalty_goals,
        COUNT(CASE WHEN me.event_type = 'own_goal' THEN 1 END) as own_goals,
        COUNT(CASE WHEN me.event_type = 'assist' THEN 1 END) as assists,
        COUNT(CASE WHEN me.event_type = 'yellow_card' THEN 1 END) as yellow_cards,
        COUNT(CASE WHEN me.event_type = 'red_card' THEN 1 END) as red_cards,
        COUNT(CASE WHEN me.event_type IN ('goal', 'penalty_goal') AND me.related_player_id IS NOT NULL THEN 1 END) as shots_on_target,
        COUNT(CASE WHEN me.event_type = 'corner_kick' THEN 1 END) as corners_taken,
        COUNT(CASE WHEN me.event_type = 'free_kick' THEN 1 END) as free_kicks_taken,
        COUNT(CASE WHEN me.event_type IN ('penalty_goal', 'missed_penalty') THEN 1 END) as penalties_taken,
        COUNT(CASE WHEN me.event_type = 'penalty_goal' THEN 1 END) as penalties_scored
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

    -- Calculate wins, losses, draws
    WITH match_results AS (
        SELECT 
            m.match_id,
            CASE 
                WHEN (m.home_team_id = p_team_id AND m.home_team_score > m.away_team_score) OR
                     (m.away_team_id = p_team_id AND m.away_team_score > m.home_team_score) THEN 'win'
                WHEN m.home_team_score = m.away_team_score THEN 'draw'
                ELSE 'loss'
            END as result
        FROM public.matches m
        JOIN public.match_lineups ml ON m.match_id = ml.match_id
        WHERE m.tournament_id = p_tournament_id
            AND m.status = 'completed'
            AND (m.home_team_id = p_team_id OR m.away_team_id = p_team_id)
            AND ml.player_id = p_player_id
            AND ml.team_id = p_team_id
    )
    SELECT 
        v_stats.matches_played,
        v_stats.matches_started,
        v_stats.matches_as_substitute,
        v_stats.minutes_played,
        v_stats.goals_scored,
        v_stats.penalty_goals,
        v_stats.own_goals,
        v_stats.assists,
        v_stats.yellow_cards,
        v_stats.red_cards,
        v_stats.shots_on_target,
        v_stats.corners_taken,
        v_stats.free_kicks_taken,
        v_stats.penalties_taken,
        v_stats.penalties_scored,
        COUNT(CASE WHEN mr.result = 'win' THEN 1 END) as wins,
        COUNT(CASE WHEN mr.result = 'loss' THEN 1 END) as losses,
        COUNT(CASE WHEN mr.result = 'draw' THEN 1 END) as draws,
        -- Clean sheets for goalkeepers (matches where team didn't concede)
        COUNT(CASE 
            WHEN (m.home_team_id = p_team_id AND m.away_team_score = 0) OR
                 (m.away_team_id = p_team_id AND m.home_team_score = 0) 
            THEN 1 
        END) as clean_sheets
    INTO v_stats
    FROM match_results mr
    LEFT JOIN public.matches m ON mr.match_id = m.match_id;

    -- Insert or update player statistics
    INSERT INTO public.player_statistics (
        player_id, tournament_id, team_id, sport_id,
        matches_played, matches_started, matches_as_substitute, minutes_played,
        goals_scored, penalty_goals, own_goals, assists,
        yellow_cards, red_cards, shots_on_target, corners_taken,
        free_kicks_taken, penalties_taken, penalties_scored,
        wins, losses, draws, clean_sheets,
        last_calculated_at
    ) VALUES (
        p_player_id, p_tournament_id, p_team_id, v_sport_id,
        COALESCE(v_stats.matches_played, 0),
        COALESCE(v_stats.matches_started, 0),
        COALESCE(v_stats.matches_as_substitute, 0),
        COALESCE(v_stats.minutes_played, 0),
        COALESCE(v_stats.goals_scored, 0),
        COALESCE(v_stats.penalty_goals, 0),
        COALESCE(v_stats.own_goals, 0),
        COALESCE(v_stats.assists, 0),
        COALESCE(v_stats.yellow_cards, 0),
        COALESCE(v_stats.red_cards, 0),
        COALESCE(v_stats.shots_on_target, 0),
        COALESCE(v_stats.corners_taken, 0),
        COALESCE(v_stats.free_kicks_taken, 0),
        COALESCE(v_stats.penalties_taken, 0),
        COALESCE(v_stats.penalties_scored, 0),
        COALESCE(v_stats.wins, 0),
        COALESCE(v_stats.losses, 0),
        COALESCE(v_stats.draws, 0),
        COALESCE(v_stats.clean_sheets, 0),
        NOW()
    )
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
        shots_on_target = EXCLUDED.shots_on_target,
        corners_taken = EXCLUDED.corners_taken,
        free_kicks_taken = EXCLUDED.free_kicks_taken,
        penalties_taken = EXCLUDED.penalties_taken,
        penalties_scored = EXCLUDED.penalties_scored,
        wins = EXCLUDED.wins,
        losses = EXCLUDED.losses,
        draws = EXCLUDED.draws,
        clean_sheets = EXCLUDED.clean_sheets,
        last_calculated_at = NOW(),
        updated_at = NOW();
END;
$$ LANGUAGE plpgsql;

-- =====================================================
-- TEAM STATISTICS FUNCTIONS
-- =====================================================

-- Function to recalculate team statistics for a tournament
CREATE OR REPLACE FUNCTION public.recalculate_team_statistics(
    p_team_id UUID,
    p_tournament_id UUID,
    p_category_id UUID DEFAULT NULL
) RETURNS VOID AS $$
DECLARE
    v_stats RECORD;
    v_sport_id UUID;
    v_recent_matches TEXT[];
    v_form VARCHAR(5);
BEGIN
    -- Get sport_id from tournament
    SELECT sport_id INTO v_sport_id
    FROM public.tournaments
    WHERE tournament_id = p_tournament_id;
    
    -- Calculate basic team statistics
    SELECT 
        COUNT(*) as matches_played,
        COUNT(CASE 
            WHEN (m.home_team_id = p_team_id AND m.home_team_score > m.away_team_score) OR
                 (m.away_team_id = p_team_id AND m.away_team_score > m.home_team_score) 
            THEN 1 
        END) as wins,
        COUNT(CASE 
            WHEN (m.home_team_id = p_team_id AND m.home_team_score < m.away_team_score) OR
                 (m.away_team_id = p_team_id AND m.away_team_score < m.home_team_score) 
            THEN 1 
        END) as losses,
        COUNT(CASE 
            WHEN m.home_team_score = m.away_team_score 
            THEN 1 
        END) as draws,
        SUM(CASE 
            WHEN m.home_team_id = p_team_id THEN m.home_team_score 
            ELSE m.away_team_score 
        END) as goals_for,
        SUM(CASE 
            WHEN m.home_team_id = p_team_id THEN m.away_team_score 
            ELSE m.home_team_score 
        END) as goals_against,
        COUNT(CASE 
            WHEN (m.home_team_id = p_team_id AND m.away_team_score = 0) OR
                 (m.away_team_id = p_team_id AND m.home_team_score = 0) 
            THEN 1 
        END) as clean_sheets,
        COUNT(CASE 
            WHEN (m.home_team_id = p_team_id AND m.home_team_score = 0) OR
                 (m.away_team_id = p_team_id AND m.away_team_score = 0) 
            THEN 1 
        END) as failed_to_score
    INTO v_stats
    FROM public.matches m
    WHERE m.tournament_id = p_tournament_id
        AND m.status = 'completed'
        AND (m.home_team_id = p_team_id OR m.away_team_id = p_team_id);

    -- Calculate points (assuming 3 for win, 1 for draw, 0 for loss)
    v_stats.points := (COALESCE(v_stats.wins, 0) * 3) + COALESCE(v_stats.draws, 0);

    -- Get recent form (last 5 matches)
    SELECT ARRAY_AGG(
        CASE 
            WHEN (m.home_team_id = p_team_id AND m.home_team_score > m.away_team_score) OR
                 (m.away_team_id = p_team_id AND m.away_team_score > m.home_team_score) 
            THEN 'W'
            WHEN m.home_team_score = m.away_team_score THEN 'D'
            ELSE 'L'
        END
        ORDER BY m.match_date DESC, m.match_time DESC
    ) INTO v_recent_matches
    FROM public.matches m
    WHERE m.tournament_id = p_tournament_id
        AND m.status = 'completed'
        AND (m.home_team_id = p_team_id OR m.away_team_id = p_team_id)
    ORDER BY m.match_date DESC, m.match_time DESC
    LIMIT 5;

    -- Convert array to string (last 5 matches)
    v_form := COALESCE(array_to_string(v_recent_matches[1:5], ''), '');

    -- Calculate disciplinary statistics
    SELECT 
        COUNT(CASE WHEN me.event_type = 'yellow_card' THEN 1 END) as yellow_cards,
        COUNT(CASE WHEN me.event_type = 'red_card' THEN 1 END) as red_cards
    INTO v_stats.yellow_cards, v_stats.red_cards
    FROM public.match_events me
    JOIN public.matches m ON me.match_id = m.match_id
    WHERE m.tournament_id = p_tournament_id
        AND m.status = 'completed'
        AND me.team_id = p_team_id
        AND me.is_deleted = FALSE;

    -- Insert or update team statistics
    INSERT INTO public.team_statistics (
        team_id, tournament_id, sport_id, category_id,
        matches_played, wins, losses, draws,
        goals_for, goals_against, points,
        clean_sheets, failed_to_score,
        yellow_cards, red_cards,
        recent_form,
        last_calculated_at
    ) VALUES (
        p_team_id, p_tournament_id, v_sport_id, p_category_id,
        COALESCE(v_stats.matches_played, 0),
        COALESCE(v_stats.wins, 0),
        COALESCE(v_stats.losses, 0),
        COALESCE(v_stats.draws, 0),
        COALESCE(v_stats.goals_for, 0),
        COALESCE(v_stats.goals_against, 0),
        COALESCE(v_stats.points, 0),
        COALESCE(v_stats.clean_sheets, 0),
        COALESCE(v_stats.failed_to_score, 0),
        COALESCE(v_stats.yellow_cards, 0),
        COALESCE(v_stats.red_cards, 0),
        v_form,
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
        clean_sheets = EXCLUDED.clean_sheets,
        failed_to_score = EXCLUDED.failed_to_score,
        yellow_cards = EXCLUDED.yellow_cards,
        red_cards = EXCLUDED.red_cards,
        recent_form = EXCLUDED.recent_form,
        last_calculated_at = NOW(),
        updated_at = NOW();
END;
$$ LANGUAGE plpgsql;

-- =====================================================
-- TOURNAMENT STANDINGS FUNCTIONS
-- =====================================================

-- Function to update tournament standings
CREATE OR REPLACE FUNCTION public.update_tournament_standings(
    p_tournament_id UUID,
    p_category_id UUID DEFAULT NULL
) RETURNS VOID AS $$
DECLARE
    v_team RECORD;
    v_position INTEGER := 1;
BEGIN
    -- Delete existing standings for this tournament/category
    DELETE FROM public.tournament_standings
    WHERE tournament_id = p_tournament_id
    AND (p_category_id IS NULL OR category_id = p_category_id);

    -- Insert new standings based on team statistics
    FOR v_team IN
        SELECT 
            ts.team_id,
            ts.points,
            ts.matches_played,
            ts.wins,
            ts.draws,
            ts.losses,
            ts.goals_for,
            ts.goals_against,
            ts.goal_difference
        FROM public.team_statistics ts
        WHERE ts.tournament_id = p_tournament_id
        AND (p_category_id IS NULL OR ts.category_id = p_category_id)
        ORDER BY 
            ts.points DESC,
            ts.goal_difference DESC,
            ts.goals_for DESC,
            ts.wins DESC,
            ts.matches_played ASC
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
            v_team.team_id,
            p_category_id,
            v_position,
            v_team.points,
            v_team.matches_played,
            v_team.wins,
            v_team.draws,
            v_team.losses,
            v_team.goals_for,
            v_team.goals_against,
            NOW()
        );
        
        v_position := v_position + 1;
    END LOOP;

    -- Update current position in team statistics
    UPDATE public.team_statistics ts
    SET 
        previous_position = current_position,
        current_position = st.position,
        highest_position = CASE 
            WHEN highest_position IS NULL OR st.position < highest_position 
            THEN st.position 
            ELSE highest_position 
        END,
        lowest_position = CASE 
            WHEN lowest_position IS NULL OR st.position > lowest_position 
            THEN st.position 
            ELSE lowest_position 
        END
    FROM public.tournament_standings st
    WHERE ts.team_id = st.team_id
    AND ts.tournament_id = st.tournament_id
    AND (p_category_id IS NULL OR ts.category_id = st.category_id);
END;
$$ LANGUAGE plpgsql;

-- =====================================================
-- PLAYER RANKINGS FUNCTIONS
-- =====================================================

-- Function to update player rankings
CREATE OR REPLACE FUNCTION public.update_player_rankings(
    p_tournament_id UUID,
    p_ranking_type VARCHAR(30),
    p_category_id UUID DEFAULT NULL
) RETURNS VOID AS $$
DECLARE
    v_player RECORD;
    v_position INTEGER := 1;
    v_column_name TEXT;
BEGIN
    -- Map ranking type to column name
    v_column_name := CASE p_ranking_type
        WHEN 'top_scorer' THEN 'goals_scored'
        WHEN 'most_assists' THEN 'assists'
        WHEN 'most_yellow_cards' THEN 'yellow_cards'
        WHEN 'most_red_cards' THEN 'red_cards'
        WHEN 'most_minutes' THEN 'minutes_played'
        ELSE 'goals_scored'
    END;

    -- Delete existing rankings
    DELETE FROM public.player_rankings
    WHERE tournament_id = p_tournament_id
    AND ranking_type = p_ranking_type
    AND (p_category_id IS NULL OR category_id = p_category_id);

    -- Create dynamic query for rankings
    FOR v_player IN
        EXECUTE format('
            SELECT 
                ps.player_id,
                ps.team_id,
                ps.%I as value
            FROM public.player_statistics ps
            JOIN public.tournaments t ON ps.tournament_id = t.tournament_id
            WHERE ps.tournament_id = $1
            AND ps.%I > 0
            ORDER BY ps.%I DESC, ps.goals_scored DESC, ps.assists DESC
            LIMIT 50
        ', v_column_name, v_column_name, v_column_name)
        USING p_tournament_id
    LOOP
        INSERT INTO public.player_rankings (
            tournament_id,
            sport_id,
            category_id,
            player_id,
            team_id,
            ranking_type,
            position,
            value,
            last_updated_at
        ) 
        SELECT 
            p_tournament_id,
            t.sport_id,
            p_category_id,
            v_player.player_id,
            v_player.team_id,
            p_ranking_type,
            v_position,
            v_player.value,
            NOW()
        FROM public.tournaments t
        WHERE t.tournament_id = p_tournament_id;
        
        v_position := v_position + 1;
    END LOOP;
END;
$$ LANGUAGE plpgsql;

-- =====================================================
-- BATCH STATISTICS UPDATE FUNCTIONS
-- =====================================================

-- Function to recalculate all statistics for a tournament
CREATE OR REPLACE FUNCTION public.recalculate_tournament_statistics(
    p_tournament_id UUID
) RETURNS VOID AS $$
DECLARE
    v_team_player RECORD;
    v_team RECORD;
BEGIN
    -- Recalculate player statistics
    FOR v_team_player IN
        SELECT DISTINCT tp.player_id, tp.team_id
        FROM public.team_players tp
        JOIN public.tournament_teams tt ON tp.team_id = tt.team_id
        WHERE tt.tournament_id = p_tournament_id
        AND tp.is_active = TRUE
        AND tt.status = 'approved'
    LOOP
        PERFORM public.recalculate_player_statistics(
            v_team_player.player_id,
            p_tournament_id,
            v_team_player.team_id
        );
    END LOOP;

    -- Recalculate team statistics
    FOR v_team IN
        SELECT DISTINCT tt.team_id, tt.category_id
        FROM public.tournament_teams tt
        WHERE tt.tournament_id = p_tournament_id
        AND tt.status = 'approved'
    LOOP
        PERFORM public.recalculate_team_statistics(
            v_team.team_id,
            p_tournament_id,
            v_team.category_id
        );
    END LOOP;

    -- Update tournament standings
    PERFORM public.update_tournament_standings(p_tournament_id);

    -- Update player rankings
    PERFORM public.update_player_rankings(p_tournament_id, 'top_scorer');
    PERFORM public.update_player_rankings(p_tournament_id, 'most_assists');
    PERFORM public.update_player_rankings(p_tournament_id, 'most_yellow_cards');
    PERFORM public.update_player_rankings(p_tournament_id, 'most_red_cards');
    PERFORM public.update_player_rankings(p_tournament_id, 'most_minutes');
END;
$$ LANGUAGE plpgsql;

-- Function to recalculate statistics for all active tournaments
CREATE OR REPLACE FUNCTION public.recalculate_all_active_statistics()
RETURNS VOID AS $$
DECLARE
    v_tournament RECORD;
BEGIN
    FOR v_tournament IN
        SELECT tournament_id
        FROM public.tournaments
        WHERE status IN ('active', 'completed')
    LOOP
        PERFORM public.recalculate_tournament_statistics(v_tournament.tournament_id);
    END LOOP;
END;
$$ LANGUAGE plpgsql;

-- =====================================================
-- FUNCTION COMMENTS
-- =====================================================

COMMENT ON FUNCTION public.recalculate_player_statistics(UUID, UUID, UUID) IS 'Recalculates all statistics for a specific player in a tournament/team';
COMMENT ON FUNCTION public.recalculate_team_statistics(UUID, UUID, UUID) IS 'Recalculates all statistics for a specific team in a tournament';
COMMENT ON FUNCTION public.update_tournament_standings(UUID, UUID) IS 'Updates tournament standings based on team statistics';
COMMENT ON FUNCTION public.update_player_rankings(UUID, VARCHAR, UUID) IS 'Updates player rankings for a specific statistic type';
COMMENT ON FUNCTION public.recalculate_tournament_statistics(UUID) IS 'Recalculates all statistics for an entire tournament';
COMMENT ON FUNCTION public.recalculate_all_active_statistics() IS 'Recalculates statistics for all active tournaments (use with caution)';