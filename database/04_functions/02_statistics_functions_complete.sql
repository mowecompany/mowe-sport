-- =====================================================
-- MOWE SPORT PLATFORM - COMPREHENSIVE STATISTICS FUNCTIONS
-- =====================================================
-- Description: Complete statistics calculation and management functions
-- Dependencies: All schema tables, especially statistics tables
-- Execution Order: After all schema and basic functions
-- =====================================================

-- =====================================================
-- PLAYER STATISTICS CALCULATION FUNCTIONS
-- =====================================================

-- Function to recalculate player statistics for a specific player/tournament/team
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
    v_clean_sheets INTEGER := 0;
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
    
    -- Calculate basic statistics from match events and lineups
    SELECT 
        COUNT(DISTINCT m.match_id) as matches_played,
        COUNT(DISTINCT CASE WHEN ml.is_starter THEN m.match_id END) as matches_started,
        COUNT(DISTINCT CASE WHEN NOT COALESCE(ml.is_starter, false) THEN m.match_id END) as matches_as_substitute,
        COALESCE(SUM(
            CASE 
                WHEN ml.substituted_at_minute IS NOT NULL 
                THEN ml.substituted_at_minute 
                WHEN ml.substituted_in_minute IS NOT NULL
                THEN 90 - ml.substituted_in_minute
                ELSE 90 
            END
        ), 0) as minutes_played,
        COUNT(CASE WHEN me.event_type = 'goal' AND me.event_data->>'type' != 'own_goal' THEN 1 END) as goals_scored,
        COUNT(CASE WHEN me.event_type = 'goal' AND me.event_data->>'type' = 'penalty' THEN 1 END) as penalty_goals,
        COUNT(CASE WHEN me.event_type = 'goal' AND me.event_data->>'type' = 'own_goal' THEN 1 END) as own_goals,
        COUNT(CASE WHEN me.event_type = 'assist' THEN 1 END) as assists,
        COUNT(CASE WHEN me.event_type = 'yellow_card' THEN 1 END) as yellow_cards,
        COUNT(CASE WHEN me.event_type = 'red_card' THEN 1 END) as red_cards,
        COUNT(CASE WHEN me.event_type = 'shot' AND me.event_data->>'on_target' = 'true' THEN 1 END) as shots_on_target,
        COUNT(CASE WHEN me.event_type = 'shot' AND me.event_data->>'on_target' = 'false' THEN 1 END) as shots_off_target,
        COUNT(CASE WHEN me.event_type = 'corner' THEN 1 END) as corners_taken,
        COUNT(CASE WHEN me.event_type = 'free_kick' THEN 1 END) as free_kicks_taken,
        COUNT(CASE WHEN me.event_type = 'penalty' THEN 1 END) as penalties_taken,
        COUNT(CASE WHEN me.event_type = 'penalty' AND me.event_data->>'scored' = 'true' THEN 1 END) as penalties_scored
    INTO v_stats
    FROM public.matches m
    LEFT JOIN public.match_lineups ml ON m.match_id = ml.match_id 
        AND ml.player_id = p_player_id 
        AND ml.team_id = p_team_id
    LEFT JOIN public.match_events me ON m.match_id = me.match_id 
        AND me.player_id = p_player_id 
        AND me.team_id = p_team_id
        AND COALESCE(me.is_deleted, false) = false
    WHERE m.tournament_id = p_tournament_id
        AND m.status = 'completed'
        AND (m.home_team_id = p_team_id OR m.away_team_id = p_team_id);
    
    -- Calculate wins, losses, draws
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
            THEN 1 END) as draws,
        COUNT(CASE 
            WHEN (m.home_team_id = p_team_id AND m.away_score = 0) OR
                 (m.away_team_id = p_team_id AND m.home_score = 0)
            THEN 1 END) as clean_sheets
    INTO v_wins, v_losses, v_draws, v_clean_sheets
    FROM public.matches m
    JOIN public.match_lineups ml ON m.match_id = ml.match_id 
        AND ml.player_id = p_player_id 
        AND ml.team_id = p_team_id
    WHERE m.tournament_id = p_tournament_id
        AND m.status = 'completed'
        AND (m.home_team_id = p_team_id OR m.away_team_id = p_team_id);
    
    -- Insert or update player statistics
    INSERT INTO public.player_statistics (
        player_id, tournament_id, team_id, sport_id,
        matches_played, matches_started, matches_as_substitute, minutes_played,
        goals_scored, penalty_goals, own_goals, assists,
        yellow_cards, red_cards,
        shots_on_target, shots_off_target, corners_taken, free_kicks_taken,
        penalties_taken, penalties_scored,
        wins, losses, draws, clean_sheets,
        last_calculated_at
    ) VALUES (
        p_player_id, p_tournament_id, p_team_id, v_sport_id,
        COALESCE(v_stats.matches_played, 0), COALESCE(v_stats.matches_started, 0), 
        COALESCE(v_stats.matches_as_substitute, 0), COALESCE(v_stats.minutes_played, 0),
        COALESCE(v_stats.goals_scored, 0), COALESCE(v_stats.penalty_goals, 0), 
        COALESCE(v_stats.own_goals, 0), COALESCE(v_stats.assists, 0),
        COALESCE(v_stats.yellow_cards, 0), COALESCE(v_stats.red_cards, 0),
        COALESCE(v_stats.shots_on_target, 0), COALESCE(v_stats.shots_off_target, 0),
        COALESCE(v_stats.corners_taken, 0), COALESCE(v_stats.free_kicks_taken, 0),
        COALESCE(v_stats.penalties_taken, 0), COALESCE(v_stats.penalties_scored, 0),
        COALESCE(v_wins, 0), COALESCE(v_losses, 0), COALESCE(v_draws, 0), COALESCE(v_clean_sheets, 0),
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
        shots_off_target = EXCLUDED.shots_off_target,
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
            'minutes_played', COALESCE(v_stats.minutes_played, 0),
            'wins', COALESCE(v_wins, 0),
            'losses', COALESCE(v_losses, 0),
            'draws', COALESCE(v_draws, 0)
        ),
        'message', 'Player statistics recalculated successfully'
    );
    
    RETURN result;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to recalculate all player statistics for a tournament
CREATE OR REPLACE FUNCTION public.recalculate_all_player_statistics(
    p_tournament_id UUID
) RETURNS JSONB AS $$
DECLARE
    player_record RECORD;
    processed_count INTEGER := 0;
    error_count INTEGER := 0;
    result JSONB;
BEGIN
    -- Recalculate for all players who have participated in the tournament
    FOR player_record IN
        SELECT DISTINCT ml.player_id, ml.team_id
        FROM public.match_lineups ml
        JOIN public.matches m ON ml.match_id = m.match_id
        WHERE m.tournament_id = p_tournament_id
    LOOP
        BEGIN
            PERFORM public.recalculate_player_statistics(
                player_record.player_id,
                p_tournament_id,
                player_record.team_id
            );
            processed_count := processed_count + 1;
        EXCEPTION WHEN OTHERS THEN
            error_count := error_count + 1;
            -- Log the error but continue processing
            INSERT INTO public.audit_logs (
                action,
                table_name,
                new_values
            ) VALUES (
                'PLAYER_STATS_RECALC_ERROR',
                'player_statistics',
                jsonb_build_object(
                    'player_id', player_record.player_id,
                    'tournament_id', p_tournament_id,
                    'team_id', player_record.team_id,
                    'error', SQLERRM
                )
            );
        END;
    END LOOP;
    
    result := jsonb_build_object(
        'success', true,
        'tournament_id', p_tournament_id,
        'processed_players', processed_count,
        'errors', error_count,
        'message', format('Recalculated statistics for %s players with %s errors', processed_count, error_count)
    );
    
    RETURN result;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- =====================================================
-- TEAM STATISTICS CALCULATION FUNCTIONS
-- =====================================================

-- Function to recalculate team statistics for a specific team/tournament
CREATE OR REPLACE FUNCTION public.recalculate_team_statistics(
    p_team_id UUID,
    p_tournament_id UUID,
    p_category_id UUID DEFAULT NULL
) RETURNS JSONB AS $$
DECLARE
    v_stats RECORD;
    v_sport_id UUID;
    v_recent_matches TEXT := '';
    v_match_record RECORD;
    v_match_count INTEGER := 0;
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
        END) as goals_against,
        COUNT(CASE 
            WHEN (m.home_team_id = p_team_id AND m.away_score = 0) OR
                 (m.away_team_id = p_team_id AND m.home_score = 0)
            THEN 1 END) as clean_sheets,
        COUNT(CASE 
            WHEN (m.home_team_id = p_team_id AND m.home_score = 0) OR
                 (m.away_team_id = p_team_id AND m.away_score = 0)
            THEN 1 END) as failed_to_score,
        SUM(CASE 
            WHEN me.event_type = 'yellow_card' THEN 1 
            ELSE 0 
        END) as yellow_cards,
        SUM(CASE 
            WHEN me.event_type = 'red_card' THEN 1 
            ELSE 0 
        END) as red_cards
    INTO v_stats
    FROM public.matches m
    LEFT JOIN public.match_events me ON m.match_id = me.match_id 
        AND me.team_id = p_team_id
        AND COALESCE(me.is_deleted, false) = false
    WHERE m.tournament_id = p_tournament_id
        AND m.status = 'completed'
        AND (m.home_team_id = p_team_id OR m.away_team_id = p_team_id)
        AND (p_category_id IS NULL OR m.category_id = p_category_id);
    
    -- Calculate points (3 for win, 1 for draw, 0 for loss)
    v_stats.points := (COALESCE(v_stats.wins, 0) * 3) + COALESCE(v_stats.draws, 0);
    
    -- Get recent form (last 5 matches)
    FOR v_match_record IN
        SELECT 
            CASE 
                WHEN (m.home_team_id = p_team_id AND m.home_score > m.away_score) OR
                     (m.away_team_id = p_team_id AND m.away_score > m.home_score)
                THEN 'W'
                WHEN m.home_score = m.away_score
                THEN 'D'
                ELSE 'L'
            END as result
        FROM public.matches m
        WHERE m.tournament_id = p_tournament_id
            AND m.status = 'completed'
            AND (m.home_team_id = p_team_id OR m.away_team_id = p_team_id)
            AND (p_category_id IS NULL OR m.category_id = p_category_id)
        ORDER BY m.match_date DESC, m.match_time DESC
        LIMIT 5
    LOOP
        v_recent_matches := v_recent_matches || v_match_record.result;
        v_match_count := v_match_count + 1;
    END LOOP;
    
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
        COALESCE(v_stats.matches_played, 0), COALESCE(v_stats.wins, 0), 
        COALESCE(v_stats.losses, 0), COALESCE(v_stats.draws, 0),
        COALESCE(v_stats.goals_for, 0), COALESCE(v_stats.goals_against, 0), 
        COALESCE(v_stats.points, 0),
        COALESCE(v_stats.clean_sheets, 0), COALESCE(v_stats.failed_to_score, 0),
        COALESCE(v_stats.yellow_cards, 0), COALESCE(v_stats.red_cards, 0),
        v_recent_matches,
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
            'goal_difference', COALESCE(v_stats.goals_for, 0) - COALESCE(v_stats.goals_against, 0),
            'recent_form', v_recent_matches
        ),
        'message', 'Team statistics recalculated successfully'
    );
    
    RETURN result;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to recalculate all team statistics for a tournament
CREATE OR REPLACE FUNCTION public.recalculate_all_team_statistics(
    p_tournament_id UUID,
    p_category_id UUID DEFAULT NULL
) RETURNS JSONB AS $$
DECLARE
    team_record RECORD;
    processed_count INTEGER := 0;
    error_count INTEGER := 0;
    result JSONB;
BEGIN
    -- Recalculate for all teams in the tournament
    FOR team_record IN
        SELECT DISTINCT 
            CASE WHEN m.home_team_id IS NOT NULL THEN m.home_team_id ELSE m.away_team_id END as team_id
        FROM public.matches m
        WHERE m.tournament_id = p_tournament_id
            AND (p_category_id IS NULL OR m.category_id = p_category_id)
        UNION
        SELECT DISTINCT 
            CASE WHEN m.away_team_id IS NOT NULL THEN m.away_team_id ELSE m.home_team_id END as team_id
        FROM public.matches m
        WHERE m.tournament_id = p_tournament_id
            AND (p_category_id IS NULL OR m.category_id = p_category_id)
    LOOP
        BEGIN
            PERFORM public.recalculate_team_statistics(
                team_record.team_id,
                p_tournament_id,
                p_category_id
            );
            processed_count := processed_count + 1;
        EXCEPTION WHEN OTHERS THEN
            error_count := error_count + 1;
            -- Log the error but continue processing
            INSERT INTO public.audit_logs (
                action,
                table_name,
                new_values
            ) VALUES (
                'TEAM_STATS_RECALC_ERROR',
                'team_statistics',
                jsonb_build_object(
                    'team_id', team_record.team_id,
                    'tournament_id', p_tournament_id,
                    'category_id', p_category_id,
                    'error', SQLERRM
                )
            );
        END;
    END LOOP;
    
    result := jsonb_build_object(
        'success', true,
        'tournament_id', p_tournament_id,
        'category_id', p_category_id,
        'processed_teams', processed_count,
        'errors', error_count,
        'message', format('Recalculated statistics for %s teams with %s errors', processed_count, error_count)
    );
    
    RETURN result;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- =====================================================
-- TOURNAMENT STANDINGS CALCULATION FUNCTIONS
-- =====================================================

-- Function to update tournament standings
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
            'phase_id', p_phase_id,
            'group_id', p_group_id,
            'teams_processed', processed_count
        )
    );
    
    result := jsonb_build_object(
        'success', true,
        'tournament_id', p_tournament_id,
        'category_id', p_category_id,
        'phase_id', p_phase_id,
        'group_id', p_group_id,
        'teams_processed', processed_count,
        'message', format('Tournament standings updated for %s teams', processed_count)
    );
    
    RETURN result;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- =====================================================
-- PLAYER RANKINGS CALCULATION FUNCTIONS
-- =====================================================

-- Function to update player rankings
CREATE OR REPLACE FUNCTION public.update_player_rankings(
    p_tournament_id UUID,
    p_ranking_type VARCHAR(30),
    p_category_id UUID DEFAULT NULL
) RETURNS JSONB AS $$
DECLARE
    player_record RECORD;
    position_counter INTEGER := 1;
    processed_count INTEGER := 0;
    ranking_query TEXT;
    result JSONB;
BEGIN
    -- Clear existing rankings for this type/tournament/category
    DELETE FROM public.player_rankings
    WHERE tournament_id = p_tournament_id
        AND ranking_type = p_ranking_type
        AND (p_category_id IS NULL OR category_id = p_category_id);
    
    -- Build query based on ranking type
    CASE p_ranking_type
        WHEN 'top_scorer' THEN
            ranking_query := '
                SELECT 
                    ps.player_id,
                    ps.team_id,
                    ps.goals_scored as value,
                    jsonb_build_object(
                        ''matches_played'', ps.matches_played,
                        ''goals_per_match'', ps.goals_per_match,
                        ''penalty_goals'', ps.penalty_goals
                    ) as additional_info
                FROM public.player_statistics ps
                WHERE ps.tournament_id = $1
                    AND ps.goals_scored > 0
                ORDER BY ps.goals_scored DESC, ps.goals_per_match DESC, ps.matches_played ASC';
        
        WHEN 'most_assists' THEN
            ranking_query := '
                SELECT 
                    ps.player_id,
                    ps.team_id,
                    ps.assists as value,
                    jsonb_build_object(
                        ''matches_played'', ps.matches_played,
                        ''goals_scored'', ps.goals_scored
                    ) as additional_info
                FROM public.player_statistics ps
                WHERE ps.tournament_id = $1
                    AND ps.assists > 0
                ORDER BY ps.assists DESC, ps.goals_scored DESC, ps.matches_played ASC';
        
        WHEN 'most_yellow_cards' THEN
            ranking_query := '
                SELECT 
                    ps.player_id,
                    ps.team_id,
                    ps.yellow_cards as value,
                    jsonb_build_object(
                        ''matches_played'', ps.matches_played,
                        ''red_cards'', ps.red_cards
                    ) as additional_info
                FROM public.player_statistics ps
                WHERE ps.tournament_id = $1
                    AND ps.yellow_cards > 0
                ORDER BY ps.yellow_cards DESC, ps.red_cards DESC, ps.matches_played DESC';
        
        WHEN 'most_red_cards' THEN
            ranking_query := '
                SELECT 
                    ps.player_id,
                    ps.team_id,
                    ps.red_cards as value,
                    jsonb_build_object(
                        ''matches_played'', ps.matches_played,
                        ''yellow_cards'', ps.yellow_cards
                    ) as additional_info
                FROM public.player_statistics ps
                WHERE ps.tournament_id = $1
                    AND ps.red_cards > 0
                ORDER BY ps.red_cards DESC, ps.yellow_cards DESC, ps.matches_played DESC';
        
        WHEN 'most_minutes' THEN
            ranking_query := '
                SELECT 
                    ps.player_id,
                    ps.team_id,
                    ps.minutes_played as value,
                    jsonb_build_object(
                        ''matches_played'', ps.matches_played,
                        ''matches_started'', ps.matches_started
                    ) as additional_info
                FROM public.player_statistics ps
                WHERE ps.tournament_id = $1
                    AND ps.minutes_played > 0
                ORDER BY ps.minutes_played DESC, ps.matches_played DESC';
        
        ELSE
            RETURN jsonb_build_object(
                'success', false,
                'message', 'Invalid ranking type: ' || p_ranking_type
            );
    END CASE;
    
    -- Execute the ranking query and insert results
    FOR player_record IN EXECUTE ranking_query USING p_tournament_id
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
            additional_info,
            last_updated_at
        )
        SELECT 
            p_tournament_id,
            t.sport_id,
            p_category_id,
            player_record.player_id,
            player_record.team_id,
            p_ranking_type,
            position_counter,
            player_record.value,
            player_record.additional_info,
            NOW()
        FROM public.tournaments t
        WHERE t.tournament_id = p_tournament_id;
        
        position_counter := position_counter + 1;
        processed_count := processed_count + 1;
    END LOOP;
    
    -- Log the rankings update
    INSERT INTO public.audit_logs (
        user_id,
        action,
        table_name,
        record_id,
        new_values
    ) VALUES (
        NULL, -- System action
        'PLAYER_RANKINGS_UPDATED',
        'player_rankings',
        p_tournament_id,
        jsonb_build_object(
            'tournament_id', p_tournament_id,
            'ranking_type', p_ranking_type,
            'category_id', p_category_id,
            'players_processed', processed_count
        )
    );
    
    result := jsonb_build_object(
        'success', true,
        'tournament_id', p_tournament_id,
        'ranking_type', p_ranking_type,
        'category_id', p_category_id,
        'players_processed', processed_count,
        'message', format('%s ranking updated for %s players', p_ranking_type, processed_count)
    );
    
    RETURN result;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to update all player rankings for a tournament
CREATE OR REPLACE FUNCTION public.update_all_player_rankings(
    p_tournament_id UUID,
    p_category_id UUID DEFAULT NULL
) RETURNS JSONB AS $$
DECLARE
    ranking_type VARCHAR(30);
    ranking_types VARCHAR(30)[] := ARRAY[
        'top_scorer',
        'most_assists',
        'most_yellow_cards',
        'most_red_cards',
        'most_minutes'
    ];
    processed_rankings INTEGER := 0;
    total_players INTEGER := 0;
    result JSONB;
    ranking_result JSONB;
BEGIN
    -- Update each ranking type
    FOREACH ranking_type IN ARRAY ranking_types
    LOOP
        ranking_result := public.update_player_rankings(
            p_tournament_id,
            ranking_type,
            p_category_id
        );
        
        IF (ranking_result->>'success')::BOOLEAN THEN
            processed_rankings := processed_rankings + 1;
            total_players := total_players + (ranking_result->>'players_processed')::INTEGER;
        END IF;
    END LOOP;
    
    result := jsonb_build_object(
        'success', true,
        'tournament_id', p_tournament_id,
        'category_id', p_category_id,
        'rankings_updated', processed_rankings,
        'total_players_processed', total_players,
        'message', format('Updated %s ranking types with %s total player entries', processed_rankings, total_players)
    );
    
    RETURN result;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- =====================================================
-- COMPREHENSIVE STATISTICS UPDATE FUNCTION
-- =====================================================

-- Function to recalculate all statistics for a tournament
CREATE OR REPLACE FUNCTION public.recalculate_tournament_statistics(
    p_tournament_id UUID,
    p_category_id UUID DEFAULT NULL
) RETURNS JSONB AS $$
DECLARE
    player_result JSONB;
    team_result JSONB;
    standings_result JSONB;
    rankings_result JSONB;
    final_result JSONB;
BEGIN
    -- Step 1: Recalculate all player statistics
    player_result := public.recalculate_all_player_statistics(p_tournament_id);
    
    -- Step 2: Recalculate all team statistics
    team_result := public.recalculate_all_team_statistics(p_tournament_id, p_category_id);
    
    -- Step 3: Update tournament standings
    standings_result := public.update_tournament_standings(p_tournament_id, p_category_id);
    
    -- Step 4: Update all player rankings
    rankings_result := public.update_all_player_rankings(p_tournament_id, p_category_id);
    
    -- Log the comprehensive update
    INSERT INTO public.audit_logs (
        user_id,
        action,
        table_name,
        record_id,
        new_values
    ) VALUES (
        NULL, -- System action
        'TOURNAMENT_STATS_FULL_RECALC',
        'tournaments',
        p_tournament_id,
        jsonb_build_object(
            'tournament_id', p_tournament_id,
            'category_id', p_category_id,
            'player_stats', player_result,
            'team_stats', team_result,
            'standings', standings_result,
            'rankings', rankings_result
        )
    );
    
    final_result := jsonb_build_object(
        'success', true,
        'tournament_id', p_tournament_id,
        'category_id', p_category_id,
        'results', jsonb_build_object(
            'player_statistics', player_result,
            'team_statistics', team_result,
            'tournament_standings', standings_result,
            'player_rankings', rankings_result
        ),
        'message', 'Complete tournament statistics recalculation completed successfully'
    );
    
    RETURN final_result;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- =====================================================
-- FUNCTION COMMENTS AND DOCUMENTATION
-- =====================================================

COMMENT ON FUNCTION public.recalculate_player_statistics(UUID, UUID, UUID) IS 'Recalculates statistics for a specific player in a tournament/team';
COMMENT ON FUNCTION public.recalculate_all_player_statistics(UUID) IS 'Recalculates statistics for all players in a tournament';
COMMENT ON FUNCTION public.recalculate_team_statistics(UUID, UUID, UUID) IS 'Recalculates statistics for a specific team in a tournament';
COMMENT ON FUNCTION public.recalculate_all_team_statistics(UUID, UUID) IS 'Recalculates statistics for all teams in a tournament';
COMMENT ON FUNCTION public.update_tournament_standings(UUID, UUID, UUID, UUID) IS 'Updates tournament standings based on team statistics';
COMMENT ON FUNCTION public.update_player_rankings(UUID, VARCHAR, UUID) IS 'Updates player rankings for a specific ranking type';
COMMENT ON FUNCTION public.update_all_player_rankings(UUID, UUID) IS 'Updates all player ranking types for a tournament';
COMMENT ON FUNCTION public.recalculate_tournament_statistics(UUID, UUID) IS 'Comprehensive recalculation of all tournament statistics';

-- =====================================================
-- LOG COMPLETION
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
    '00000000-0000-0000-0000-000000000001',
    'SYSTEM_INIT',
    'statistics_functions',
    NULL,
    '{"message": "Comprehensive statistics and calculation functions implemented", "functions_created": ["player_statistics", "team_statistics", "tournament_standings", "player_rankings", "comprehensive_recalculation"]}'::jsonb,
    '127.0.0.1'::inet,
    'Mowe Sport Database Migration'
);