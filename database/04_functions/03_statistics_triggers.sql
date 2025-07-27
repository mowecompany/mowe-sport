-- =====================================================
-- MOWE SPORT PLATFORM - STATISTICS TRIGGERS
-- =====================================================
-- Description: Automatic triggers for real-time statistics updates
-- Dependencies: Statistics functions and all schema tables
-- Execution Order: After statistics functions
-- =====================================================

-- =====================================================
-- TRIGGER FUNCTIONS FOR AUTOMATIC STATISTICS UPDATES
-- =====================================================

-- Function to handle match completion and trigger statistics recalculation
CREATE OR REPLACE FUNCTION public.handle_match_completion()
RETURNS TRIGGER AS $$
DECLARE
    affected_players RECORD;
BEGIN
    -- Only process when match status changes to 'completed'
    IF NEW.status = 'completed' AND (OLD.status IS NULL OR OLD.status != 'completed') THEN
        
        -- Recalculate team statistics for both teams
        PERFORM public.recalculate_team_statistics(NEW.home_team_id, NEW.tournament_id, NEW.category_id);
        PERFORM public.recalculate_team_statistics(NEW.away_team_id, NEW.tournament_id, NEW.category_id);
        
        -- Recalculate player statistics for all players who participated
        FOR affected_players IN
            SELECT DISTINCT ml.player_id, ml.team_id
            FROM public.match_lineups ml
            WHERE ml.match_id = NEW.match_id
        LOOP
            PERFORM public.recalculate_player_statistics(
                affected_players.player_id,
                NEW.tournament_id,
                affected_players.team_id
            );
        END LOOP;
        
        -- Update tournament standings
        PERFORM public.update_tournament_standings(NEW.tournament_id, NEW.category_id);
        
        -- Update player rankings (async to avoid blocking)
        PERFORM public.update_all_player_rankings(NEW.tournament_id, NEW.category_id);
        
        -- Log the automatic update
        INSERT INTO public.audit_logs (
            user_id,
            action,
            table_name,
            record_id,
            new_values
        ) VALUES (
            NULL, -- System action
            'AUTO_STATS_UPDATE_MATCH_COMPLETED',
            'matches',
            NEW.match_id,
            jsonb_build_object(
                'match_id', NEW.match_id,
                'tournament_id', NEW.tournament_id,
                'home_team_id', NEW.home_team_id,
                'away_team_id', NEW.away_team_id,
                'home_score', NEW.home_score,
                'away_score', NEW.away_score
            )
        );
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to handle match event changes and trigger statistics updates
CREATE OR REPLACE FUNCTION public.handle_match_event_change()
RETURNS TRIGGER AS $$
DECLARE
    match_info RECORD;
BEGIN
    -- Get match information
    SELECT m.tournament_id, m.status, m.home_team_id, m.away_team_id, m.category_id
    INTO match_info
    FROM public.matches m
    WHERE m.match_id = COALESCE(NEW.match_id, OLD.match_id);
    
    -- Only process for completed matches
    IF match_info.status = 'completed' THEN
        
        -- Handle INSERT or UPDATE
        IF TG_OP = 'INSERT' OR TG_OP = 'UPDATE' THEN
            -- Recalculate statistics for the affected player and team
            IF NEW.player_id IS NOT NULL THEN
                PERFORM public.recalculate_player_statistics(
                    NEW.player_id,
                    match_info.tournament_id,
                    NEW.team_id
                );
            END IF;
            
            -- Recalculate team statistics
            PERFORM public.recalculate_team_statistics(
                NEW.team_id,
                match_info.tournament_id,
                match_info.category_id
            );
        END IF;
        
        -- Handle DELETE or UPDATE (old values)
        IF TG_OP = 'DELETE' OR TG_OP = 'UPDATE' THEN
            -- Recalculate statistics for the previously affected player and team
            IF OLD.player_id IS NOT NULL THEN
                PERFORM public.recalculate_player_statistics(
                    OLD.player_id,
                    match_info.tournament_id,
                    OLD.team_id
                );
            END IF;
            
            -- Recalculate team statistics if team changed
            IF TG_OP = 'DELETE' OR (TG_OP = 'UPDATE' AND OLD.team_id != NEW.team_id) THEN
                PERFORM public.recalculate_team_statistics(
                    OLD.team_id,
                    match_info.tournament_id,
                    match_info.category_id
                );
            END IF;
        END IF;
        
        -- Update tournament standings and rankings
        PERFORM public.update_tournament_standings(match_info.tournament_id, match_info.category_id);
        PERFORM public.update_all_player_rankings(match_info.tournament_id, match_info.category_id);
        
        -- Log the automatic update
        INSERT INTO public.audit_logs (
            user_id,
            action,
            table_name,
            record_id,
            new_values
        ) VALUES (
            NULL, -- System action
            'AUTO_STATS_UPDATE_MATCH_EVENT',
            'match_events',
            COALESCE(NEW.event_id, OLD.event_id),
            jsonb_build_object(
                'operation', TG_OP,
                'match_id', COALESCE(NEW.match_id, OLD.match_id),
                'tournament_id', match_info.tournament_id,
                'event_type', COALESCE(NEW.event_type, OLD.event_type),
                'player_id', COALESCE(NEW.player_id, OLD.player_id),
                'team_id', COALESCE(NEW.team_id, OLD.team_id)
            )
        );
    END IF;
    
    RETURN COALESCE(NEW, OLD);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to handle match lineup changes
CREATE OR REPLACE FUNCTION public.handle_match_lineup_change()
RETURNS TRIGGER AS $$
DECLARE
    match_info RECORD;
BEGIN
    -- Get match information
    SELECT m.tournament_id, m.status, m.category_id
    INTO match_info
    FROM public.matches m
    WHERE m.match_id = COALESCE(NEW.match_id, OLD.match_id);
    
    -- Only process for completed matches
    IF match_info.status = 'completed' THEN
        
        -- Handle INSERT or UPDATE
        IF TG_OP = 'INSERT' OR TG_OP = 'UPDATE' THEN
            PERFORM public.recalculate_player_statistics(
                NEW.player_id,
                match_info.tournament_id,
                NEW.team_id
            );
        END IF;
        
        -- Handle DELETE or UPDATE (old values)
        IF TG_OP = 'DELETE' OR TG_OP = 'UPDATE' THEN
            PERFORM public.recalculate_player_statistics(
                OLD.player_id,
                match_info.tournament_id,
                OLD.team_id
            );
        END IF;
        
        -- Log the automatic update
        INSERT INTO public.audit_logs (
            user_id,
            action,
            table_name,
            record_id,
            new_values
        ) VALUES (
            NULL, -- System action
            'AUTO_STATS_UPDATE_MATCH_LINEUP',
            'match_lineups',
            COALESCE(NEW.lineup_id, OLD.lineup_id),
            jsonb_build_object(
                'operation', TG_OP,
                'match_id', COALESCE(NEW.match_id, OLD.match_id),
                'tournament_id', match_info.tournament_id,
                'player_id', COALESCE(NEW.player_id, OLD.player_id),
                'team_id', COALESCE(NEW.team_id, OLD.team_id)
            )
        );
    END IF;
    
    RETURN COALESCE(NEW, OLD);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to handle tournament status changes
CREATE OR REPLACE FUNCTION public.handle_tournament_status_change()
RETURNS TRIGGER AS $$
BEGIN
    -- When tournament is completed, do final statistics calculation
    IF NEW.status = 'completed' AND (OLD.status IS NULL OR OLD.status != 'completed') THEN
        
        -- Perform comprehensive statistics recalculation
        PERFORM public.recalculate_tournament_statistics(NEW.tournament_id);
        
        -- Create historical snapshot
        INSERT INTO public.historical_statistics (
            entity_type,
            entity_id,
            tournament_id,
            snapshot_date,
            statistics_data
        )
        SELECT 
            'tournament',
            NEW.tournament_id,
            NEW.tournament_id,
            CURRENT_DATE,
            jsonb_build_object(
                'tournament_name', NEW.name,
                'completion_date', NOW(),
                'total_teams', (
                    SELECT COUNT(DISTINCT team_id)
                    FROM public.team_statistics
                    WHERE tournament_id = NEW.tournament_id
                ),
                'total_matches', (
                    SELECT COUNT(*)
                    FROM public.matches
                    WHERE tournament_id = NEW.tournament_id
                    AND status = 'completed'
                ),
                'total_goals', (
                    SELECT SUM(goals_for)
                    FROM public.team_statistics
                    WHERE tournament_id = NEW.tournament_id
                )
            );
        
        -- Log the tournament completion
        INSERT INTO public.audit_logs (
            user_id,
            action,
            table_name,
            record_id,
            new_values
        ) VALUES (
            NULL, -- System action
            'TOURNAMENT_COMPLETED_STATS_FINAL',
            'tournaments',
            NEW.tournament_id,
            jsonb_build_object(
                'tournament_id', NEW.tournament_id,
                'tournament_name', NEW.name,
                'completion_date', NOW()
            )
        );
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- =====================================================
-- CREATE TRIGGERS
-- =====================================================

-- Trigger for match completion
DROP TRIGGER IF EXISTS trigger_match_completion ON public.matches;
CREATE TRIGGER trigger_match_completion
    AFTER UPDATE ON public.matches
    FOR EACH ROW
    EXECUTE FUNCTION public.handle_match_completion();

-- Trigger for match events changes
DROP TRIGGER IF EXISTS trigger_match_event_change ON public.match_events;
CREATE TRIGGER trigger_match_event_change
    AFTER INSERT OR UPDATE OR DELETE ON public.match_events
    FOR EACH ROW
    EXECUTE FUNCTION public.handle_match_event_change();

-- Trigger for match lineup changes
DROP TRIGGER IF EXISTS trigger_match_lineup_change ON public.match_lineups;
CREATE TRIGGER trigger_match_lineup_change
    AFTER INSERT OR UPDATE OR DELETE ON public.match_lineups
    FOR EACH ROW
    EXECUTE FUNCTION public.handle_match_lineup_change();

-- Trigger for tournament status changes
DROP TRIGGER IF EXISTS trigger_tournament_status_change ON public.tournaments;
CREATE TRIGGER trigger_tournament_status_change
    AFTER UPDATE ON public.tournaments
    FOR EACH ROW
    EXECUTE FUNCTION public.handle_tournament_status_change();

-- =====================================================
-- SCHEDULED STATISTICS RECALCULATION FUNCTIONS
-- =====================================================

-- Function to perform daily statistics maintenance
CREATE OR REPLACE FUNCTION public.daily_statistics_maintenance()
RETURNS JSONB AS $$
DECLARE
    tournament_record RECORD;
    processed_tournaments INTEGER := 0;
    total_errors INTEGER := 0;
    result JSONB;
BEGIN
    -- Recalculate statistics for all active tournaments
    FOR tournament_record IN
        SELECT tournament_id, name
        FROM public.tournaments
        WHERE status IN ('active', 'approved')
        AND end_date >= CURRENT_DATE - INTERVAL '7 days' -- Only recent tournaments
    LOOP
        BEGIN
            PERFORM public.recalculate_tournament_statistics(tournament_record.tournament_id);
            processed_tournaments := processed_tournaments + 1;
        EXCEPTION WHEN OTHERS THEN
            total_errors := total_errors + 1;
            -- Log the error
            INSERT INTO public.audit_logs (
                action,
                table_name,
                new_values
            ) VALUES (
                'DAILY_MAINTENANCE_ERROR',
                'tournaments',
                jsonb_build_object(
                    'tournament_id', tournament_record.tournament_id,
                    'tournament_name', tournament_record.name,
                    'error', SQLERRM
                )
            );
        END;
    END LOOP;
    
    -- Create daily historical snapshots for active tournaments
    INSERT INTO public.historical_statistics (
        entity_type,
        entity_id,
        tournament_id,
        snapshot_date,
        statistics_data
    )
    SELECT 
        'team',
        ts.team_id,
        ts.tournament_id,
        CURRENT_DATE,
        jsonb_build_object(
            'matches_played', ts.matches_played,
            'wins', ts.wins,
            'losses', ts.losses,
            'draws', ts.draws,
            'points', ts.points,
            'goals_for', ts.goals_for,
            'goals_against', ts.goals_against,
            'current_position', ts.current_position,
            'snapshot_date', CURRENT_DATE
        )
    FROM public.team_statistics ts
    JOIN public.tournaments t ON ts.tournament_id = t.tournament_id
    WHERE t.status IN ('active', 'approved')
        AND t.end_date >= CURRENT_DATE - INTERVAL '7 days'
    ON CONFLICT (entity_type, entity_id, tournament_id, snapshot_date) DO NOTHING;
    
    -- Log the maintenance completion
    INSERT INTO public.audit_logs (
        user_id,
        action,
        table_name,
        new_values
    ) VALUES (
        NULL, -- System action
        'DAILY_STATISTICS_MAINTENANCE',
        'statistics_maintenance',
        jsonb_build_object(
            'date', CURRENT_DATE,
            'tournaments_processed', processed_tournaments,
            'errors', total_errors,
            'completion_time', NOW()
        )
    );
    
    result := jsonb_build_object(
        'success', true,
        'date', CURRENT_DATE,
        'tournaments_processed', processed_tournaments,
        'errors', total_errors,
        'message', format('Daily maintenance completed: %s tournaments processed with %s errors', processed_tournaments, total_errors)
    );
    
    RETURN result;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- =====================================================
-- UTILITY FUNCTIONS FOR STATISTICS MANAGEMENT
-- =====================================================

-- Function to get statistics summary for a tournament
CREATE OR REPLACE FUNCTION public.get_tournament_statistics_summary(
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

-- =====================================================
-- FUNCTION COMMENTS AND DOCUMENTATION
-- =====================================================

COMMENT ON FUNCTION public.handle_match_completion() IS 'Trigger function to automatically update statistics when a match is completed';
COMMENT ON FUNCTION public.handle_match_event_change() IS 'Trigger function to update statistics when match events change';
COMMENT ON FUNCTION public.handle_match_lineup_change() IS 'Trigger function to update statistics when match lineups change';
COMMENT ON FUNCTION public.handle_tournament_status_change() IS 'Trigger function to handle tournament completion and final statistics';
COMMENT ON FUNCTION public.daily_statistics_maintenance() IS 'Daily maintenance function for statistics recalculation and cleanup';
COMMENT ON FUNCTION public.get_tournament_statistics_summary(UUID) IS 'Get comprehensive statistics summary for a tournament';

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
    'statistics_triggers',
    NULL,
    '{"message": "Statistics triggers and automation functions implemented", "triggers_created": ["match_completion", "match_events", "match_lineups", "tournament_status"], "functions_created": ["daily_maintenance", "statistics_summary"]}'::jsonb,
    '127.0.0.1'::inet,
    'Mowe Sport Database Migration'
);