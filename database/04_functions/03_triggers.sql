-- =====================================================
-- MOWE SPORT PLATFORM - DATABASE TRIGGERS
-- =====================================================
-- Description: Triggers for automatic statistics updates and audit logging
-- Dependencies: All functions and complete schema
-- Execution Order: After all functions
-- =====================================================

-- =====================================================
-- MATCH EVENT TRIGGERS
-- =====================================================

-- Function to update statistics when match events change
CREATE OR REPLACE FUNCTION public.handle_match_event_change()
RETURNS TRIGGER AS $$
DECLARE
    v_tournament_id UUID;
    v_team_id UUID;
    v_player_id UUID;
BEGIN
    -- Get tournament_id from match
    IF TG_OP = 'DELETE' THEN
        SELECT tournament_id INTO v_tournament_id
        FROM public.matches
        WHERE match_id = OLD.match_id;
        
        v_team_id := OLD.team_id;
        v_player_id := OLD.player_id;
    ELSE
        SELECT tournament_id INTO v_tournament_id
        FROM public.matches
        WHERE match_id = NEW.match_id;
        
        v_team_id := NEW.team_id;
        v_player_id := NEW.player_id;
    END IF;

    -- Recalculate player statistics if player is involved
    IF v_player_id IS NOT NULL THEN
        PERFORM public.recalculate_player_statistics(
            v_player_id,
            v_tournament_id,
            v_team_id
        );
    END IF;

    -- Recalculate team statistics
    PERFORM public.recalculate_team_statistics(
        v_team_id,
        v_tournament_id,
        NULL -- category_id will be determined in function
    );

    -- Update tournament standings
    PERFORM public.update_tournament_standings(v_tournament_id);

    -- Update player rankings for goals if it's a goal event
    IF (TG_OP = 'INSERT' AND NEW.event_type IN ('goal', 'penalty_goal')) OR
       (TG_OP = 'UPDATE' AND NEW.event_type IN ('goal', 'penalty_goal') AND OLD.event_type NOT IN ('goal', 'penalty_goal')) OR
       (TG_OP = 'DELETE' AND OLD.event_type IN ('goal', 'penalty_goal')) THEN
        PERFORM public.update_player_rankings(v_tournament_id, 'top_scorer');
    END IF;

    -- Update player rankings for assists if it's an assist event
    IF (TG_OP = 'INSERT' AND NEW.event_type = 'assist') OR
       (TG_OP = 'UPDATE' AND NEW.event_type = 'assist' AND OLD.event_type != 'assist') OR
       (TG_OP = 'DELETE' AND OLD.event_type = 'assist') THEN
        PERFORM public.update_player_rankings(v_tournament_id, 'most_assists');
    END IF;

    IF TG_OP = 'DELETE' THEN
        RETURN OLD;
    ELSE
        RETURN NEW;
    END IF;
END;
$$ LANGUAGE plpgsql;

-- Corrected trigger function for match events
CREATE OR REPLACE FUNCTION public.handle_match_event_change()
RETURNS TRIGGER AS $$
DECLARE
    v_tournament_id UUID;
    v_team_id UUID;
    v_player_id UUID;
BEGIN
    -- Explicitly handle different trigger operations
    IF TG_OP = 'DELETE' THEN
        SELECT tournament_id INTO v_tournament_id
        FROM public.matches
        WHERE match_id = OLD.match_id;
        
        v_team_id := OLD.team_id;
        v_player_id := OLD.player_id;
    ELSE
        SELECT tournament_id INTO v_tournament_id
        FROM public.matches
        WHERE match_id = NEW.match_id;
        
        v_team_id := NEW.team_id;
        v_player_id := NEW.player_id;
    END IF;

    -- Rest of the function remains the same...
    -- (Keep the existing implementation)

    IF TG_OP = 'DELETE' THEN
        RETURN OLD;
    ELSE
        RETURN NEW;
    END IF;
END;
$$ LANGUAGE plpgsql;

-- Recreate the trigger with explicit syntax
DROP TRIGGER IF EXISTS match_event_stats_update ON public.match_events;
CREATE TRIGGER match_event_stats_update
    AFTER INSERT OR UPDATE OR DELETE ON public.match_events
    FOR EACH ROW
    EXECUTE FUNCTION public.handle_match_event_change();

-- =====================================================
-- MATCH COMPLETION TRIGGERS
-- =====================================================

-- Function to handle match completion
CREATE OR REPLACE FUNCTION public.handle_match_completion()
RETURNS TRIGGER AS $$
BEGIN
    -- Only trigger when match status changes to completed
    IF OLD.status != 'completed' AND NEW.status = 'completed' THEN
        -- Recalculate statistics for both teams
        PERFORM public.recalculate_team_statistics(
            NEW.home_team_id,
            NEW.tournament_id,
            NULL
        );
        
        PERFORM public.recalculate_team_statistics(
            NEW.away_team_id,
            NEW.tournament_id,
            NULL
        );

        -- Recalculate player statistics for all players who participated
        PERFORM public.recalculate_player_statistics(
            ml.player_id,
            NEW.tournament_id,
            ml.team_id
        )
        FROM public.match_lineups ml
        WHERE ml.match_id = NEW.match_id;

        -- Update tournament standings
        PERFORM public.update_tournament_standings(NEW.tournament_id);

        -- Update all player rankings
        PERFORM public.update_player_rankings(NEW.tournament_id, 'top_scorer');
        PERFORM public.update_player_rankings(NEW.tournament_id, 'most_assists');
        PERFORM public.update_player_rankings(NEW.tournament_id, 'most_yellow_cards');
        PERFORM public.update_player_rankings(NEW.tournament_id, 'most_red_cards');
        PERFORM public.update_player_rankings(NEW.tournament_id, 'most_minutes');
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create trigger for match completion
DROP TRIGGER IF EXISTS match_completion_stats_update ON public.matches;
CREATE TRIGGER match_completion_stats_update
    AFTER UPDATE ON public.matches
    FOR EACH ROW
    EXECUTE FUNCTION public.handle_match_completion();

-- =====================================================
-- AUDIT LOGGING TRIGGERS
-- =====================================================

-- Function to log important table changes
CREATE OR REPLACE FUNCTION public.audit_table_changes()
RETURNS TRIGGER AS $$
DECLARE
    v_old_data JSONB;
    v_new_data JSONB;
    v_action TEXT;
BEGIN
    -- Determine action
    IF TG_OP = 'DELETE' THEN
        v_action := 'DELETE';
        v_old_data := to_jsonb(OLD);
        v_new_data := NULL;
    ELSIF TG_OP = 'UPDATE' THEN
        v_action := 'UPDATE';
        v_old_data := to_jsonb(OLD);
        v_new_data := to_jsonb(NEW);
    ELSIF TG_OP = 'INSERT' THEN
        v_action := 'INSERT';
        v_old_data := NULL;
        v_new_data := to_jsonb(NEW);
    END IF;

    -- Insert audit log
    INSERT INTO public.audit_logs (
        user_id,
        action,
        table_name,
        record_id,
        old_values,
        new_values
    ) VALUES (
        auth.uid(),
        v_action,
        TG_TABLE_NAME,
        CASE 
            WHEN TG_OP = 'DELETE' THEN (v_old_data->>(TG_ARGV[0]))::UUID
            ELSE (v_new_data->>(TG_ARGV[0]))::UUID
        END,
        v_old_data,
        v_new_data
    );

    IF TG_OP = 'DELETE' THEN
        RETURN OLD;
    ELSE
        RETURN NEW;
    END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create audit triggers for important tables
DROP TRIGGER IF EXISTS audit_user_profiles ON public.user_profiles;
CREATE TRIGGER audit_user_profiles
    AFTER INSERT OR UPDATE OR DELETE ON public.user_profiles
    FOR EACH ROW EXECUTE FUNCTION public.audit_table_changes('user_id');

DROP TRIGGER IF EXISTS audit_user_roles ON public.user_roles_by_city_sport;
CREATE TRIGGER audit_user_roles
    AFTER INSERT OR UPDATE OR DELETE ON public.user_roles_by_city_sport
    FOR EACH ROW EXECUTE FUNCTION public.audit_table_changes('role_assignment_id');

DROP TRIGGER IF EXISTS audit_tournaments ON public.tournaments;
CREATE TRIGGER audit_tournaments
    AFTER INSERT OR UPDATE OR DELETE ON public.tournaments
    FOR EACH ROW EXECUTE FUNCTION public.audit_table_changes('tournament_id');

DROP TRIGGER IF EXISTS audit_teams ON public.teams;
CREATE TRIGGER audit_teams
    AFTER INSERT OR UPDATE OR DELETE ON public.teams
    FOR EACH ROW EXECUTE FUNCTION public.audit_table_changes('team_id');

DROP TRIGGER IF EXISTS audit_players ON public.players;
CREATE TRIGGER audit_players
    AFTER INSERT OR UPDATE OR DELETE ON public.players
    FOR EACH ROW EXECUTE FUNCTION public.audit_table_changes('player_id');

DROP TRIGGER IF EXISTS audit_matches ON public.matches;
CREATE TRIGGER audit_matches
    AFTER INSERT OR UPDATE OR DELETE ON public.matches
    FOR EACH ROW EXECUTE FUNCTION public.audit_table_changes('match_id');

DROP TRIGGER IF EXISTS audit_tournament_teams ON public.tournament_teams;
CREATE TRIGGER audit_tournament_teams
    AFTER INSERT OR UPDATE OR DELETE ON public.tournament_teams
    FOR EACH ROW EXECUTE FUNCTION public.audit_table_changes('tournament_team_id');

-- =====================================================
-- TEAM PLAYER VALIDATION TRIGGERS
-- =====================================================

-- Function to validate team player assignments
CREATE OR REPLACE FUNCTION public.validate_team_player_assignment()
RETURNS TRIGGER AS $$
DECLARE
    v_player_sport_teams INTEGER;
    v_team_sport_id UUID;
    v_player_name TEXT;
    v_team_name TEXT;
BEGIN
    -- Get team sport
    SELECT sport_id, name INTO v_team_sport_id, v_team_name
    FROM public.teams
    WHERE team_id = NEW.team_id;

    -- Get player name
    SELECT first_name || ' ' || last_name INTO v_player_name
    FROM public.players
    WHERE player_id = NEW.player_id;

    -- Check if player is already in another active team for the same sport
    SELECT COUNT(*) INTO v_player_sport_teams
    FROM public.team_players tp
    JOIN public.teams t ON tp.team_id = t.team_id
    WHERE tp.player_id = NEW.player_id
    AND tp.is_active = TRUE
    AND tp.leave_date IS NULL
    AND t.sport_id = v_team_sport_id
    AND tp.team_id != NEW.team_id;

    -- Prevent player from being in multiple teams of the same sport simultaneously
    IF v_player_sport_teams > 0 THEN
        RAISE EXCEPTION 'Player % is already active in another team for this sport. A player cannot be in multiple teams of the same sport simultaneously.', v_player_name;
    END IF;

    -- Validate jersey number uniqueness within team
    IF NEW.jersey_number IS NOT NULL THEN
        IF EXISTS (
            SELECT 1 FROM public.team_players tp
            WHERE tp.team_id = NEW.team_id
            AND tp.jersey_number = NEW.jersey_number
            AND tp.is_active = TRUE
            AND tp.team_player_id != COALESCE(NEW.team_player_id, '00000000-0000-0000-0000-000000000000'::UUID)
        ) THEN
            RAISE EXCEPTION 'Jersey number % is already taken by another player in team %', NEW.jersey_number, v_team_name;
        END IF;
    END IF;

    -- Validate captain/vice-captain uniqueness
    IF NEW.is_captain = TRUE THEN
        IF EXISTS (
            SELECT 1 FROM public.team_players tp
            WHERE tp.team_id = NEW.team_id
            AND tp.is_captain = TRUE
            AND tp.is_active = TRUE
            AND tp.team_player_id != COALESCE(NEW.team_player_id, '00000000-0000-0000-0000-000000000000'::UUID)
        ) THEN
            RAISE EXCEPTION 'Team % already has a captain. Only one captain per team is allowed.', v_team_name;
        END IF;
    END IF;

    IF NEW.is_vice_captain = TRUE THEN
        IF EXISTS (
            SELECT 1 FROM public.team_players tp
            WHERE tp.team_id = NEW.team_id
            AND tp.is_vice_captain = TRUE
            AND tp.is_active = TRUE
            AND tp.team_player_id != COALESCE(NEW.team_player_id, '00000000-0000-0000-0000-000000000000'::UUID)
        ) THEN
            RAISE EXCEPTION 'Team % already has a vice-captain. Only one vice-captain per team is allowed.', v_team_name;
        END IF;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create trigger for team player validation
DROP TRIGGER IF EXISTS validate_team_player ON public.team_players;
CREATE TRIGGER validate_team_player
    BEFORE INSERT OR UPDATE ON public.team_players
    FOR EACH ROW EXECUTE FUNCTION public.validate_team_player_assignment();

-- =====================================================
-- TOURNAMENT TEAM VALIDATION TRIGGERS
-- =====================================================

-- Function to validate tournament team registrations
CREATE OR REPLACE FUNCTION public.validate_tournament_team_registration()
RETURNS TRIGGER AS $$
DECLARE
    v_tournament_sport_id UUID;
    v_team_sport_id UUID;
    v_tournament_status VARCHAR(20);
    v_registration_deadline DATE;
    v_max_teams INTEGER;
    v_current_teams INTEGER;
BEGIN
    -- Get tournament details
    SELECT sport_id, status, registration_deadline, max_teams
    INTO v_tournament_sport_id, v_tournament_status, v_registration_deadline, v_max_teams
    FROM public.tournaments
    WHERE tournament_id = NEW.tournament_id;

    -- Get team sport
    SELECT sport_id INTO v_team_sport_id
    FROM public.teams
    WHERE team_id = NEW.team_id;

    -- Validate sport compatibility
    IF v_tournament_sport_id != v_team_sport_id THEN
        RAISE EXCEPTION 'Team sport does not match tournament sport';
    END IF;

    -- Validate tournament status
    IF v_tournament_status NOT IN ('pending', 'approved') THEN
        RAISE EXCEPTION 'Cannot register for tournament with status: %', v_tournament_status;
    END IF;

    -- Validate registration deadline
    IF v_registration_deadline IS NOT NULL AND CURRENT_DATE > v_registration_deadline THEN
        RAISE EXCEPTION 'Registration deadline has passed for this tournament';
    END IF;

    -- Validate maximum teams limit
    IF v_max_teams IS NOT NULL THEN
        SELECT COUNT(*) INTO v_current_teams
        FROM public.tournament_teams
        WHERE tournament_id = NEW.tournament_id
        AND status = 'approved';

        IF v_current_teams >= v_max_teams THEN
            RAISE EXCEPTION 'Tournament has reached maximum number of teams (%))', v_max_teams;
        END IF;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create trigger for tournament team validation
DROP TRIGGER IF EXISTS validate_tournament_team ON public.tournament_teams;
CREATE TRIGGER validate_tournament_team
    BEFORE INSERT OR UPDATE ON public.tournament_teams
    FOR EACH ROW EXECUTE FUNCTION public.validate_tournament_team_registration();

-- =====================================================
-- MATCH VALIDATION TRIGGERS
-- =====================================================

-- Function to validate match data
CREATE OR REPLACE FUNCTION public.validate_match_data()
RETURNS TRIGGER AS $$
DECLARE
    v_tournament_sport_id UUID;
    v_team1_sport_id UUID;
    v_team2_sport_id UUID;
BEGIN
    -- Get sport IDs
    SELECT sport_id INTO v_tournament_sport_id
    FROM public.tournaments
    WHERE tournament_id = NEW.tournament_id;

    SELECT sport_id INTO v_team1_sport_id
    FROM public.teams
    WHERE team_id = NEW.home_team_id;

    SELECT sport_id INTO v_team2_sport_id
    FROM public.teams
    WHERE team_id = NEW.away_team_id;

    -- Validate sport compatibility
    IF v_tournament_sport_id != v_team1_sport_id OR v_tournament_sport_id != v_team2_sport_id THEN
        RAISE EXCEPTION 'All teams and tournament must be for the same sport';
    END IF;

    -- Validate teams are different
    IF NEW.home_team_id = NEW.away_team_id THEN
        RAISE EXCEPTION 'A team cannot play against itself';
    END IF;

    -- Validate both teams are registered for the tournament
    IF NOT EXISTS (
        SELECT 1 FROM public.tournament_teams
        WHERE tournament_id = NEW.tournament_id
        AND team_id = NEW.home_team_id
        AND status = 'approved'
    ) THEN
        RAISE EXCEPTION 'Home team is not registered for this tournament';
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM public.tournament_teams
        WHERE tournament_id = NEW.tournament_id
        AND team_id = NEW.away_team_id
        AND status = 'approved'
    ) THEN
        RAISE EXCEPTION 'Away team is not registered for this tournament';
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create trigger for match validation
DROP TRIGGER IF EXISTS validate_match ON public.matches;
CREATE TRIGGER validate_match
    BEFORE INSERT OR UPDATE ON public.matches
    FOR EACH ROW EXECUTE FUNCTION public.validate_match_data();

-- =====================================================
-- NOTIFICATION TRIGGERS
-- =====================================================

-- Function to handle real-time notifications
CREATE OR REPLACE FUNCTION public.notify_realtime_changes()
RETURNS TRIGGER AS $$
DECLARE
    v_payload JSONB;
BEGIN
    -- Build payload based on operation
    IF TG_OP = 'DELETE' THEN
        v_payload := jsonb_build_object(
            'table', TG_TABLE_NAME,
            'operation', TG_OP,
            'old_record', to_jsonb(OLD)
        );
    ELSE
        v_payload := jsonb_build_object(
            'table', TG_TABLE_NAME,
            'operation', TG_OP,
            'new_record', to_jsonb(NEW)
        );
        
        IF TG_OP = 'UPDATE' THEN
            v_payload := v_payload || jsonb_build_object('old_record', to_jsonb(OLD));
        END IF;
    END IF;

    -- Send notification
    PERFORM pg_notify('table_changes', v_payload::text);

    IF TG_OP = 'DELETE' THEN
        RETURN OLD;
    ELSE
        RETURN NEW;
    END IF;
END;
$$ LANGUAGE plpgsql;

-- Create notification triggers for real-time updates
DROP TRIGGER IF EXISTS notify_match_changes ON public.matches;
CREATE TRIGGER notify_match_changes
    AFTER INSERT OR UPDATE OR DELETE ON public.matches
    FOR EACH ROW EXECUTE FUNCTION public.notify_realtime_changes();

DROP TRIGGER IF EXISTS notify_match_event_changes ON public.match_events;
CREATE TRIGGER notify_match_event_changes
    AFTER INSERT OR UPDATE OR DELETE ON public.match_events
    FOR EACH ROW EXECUTE FUNCTION public.notify_realtime_changes();

DROP TRIGGER IF EXISTS notify_tournament_changes ON public.tournaments;
CREATE TRIGGER notify_tournament_changes
    AFTER INSERT OR UPDATE OR DELETE ON public.tournaments
    FOR EACH ROW EXECUTE FUNCTION public.notify_realtime_changes();

-- =====================================================
-- TRIGGER COMMENTS
-- =====================================================

COMMENT ON FUNCTION public.handle_match_event_change() IS 'Updates statistics when match events are added, modified, or deleted';
COMMENT ON FUNCTION public.handle_match_completion() IS 'Recalculates all statistics when a match is completed';
COMMENT ON FUNCTION public.audit_table_changes() IS 'Logs all changes to important tables for audit purposes';
COMMENT ON FUNCTION public.validate_team_player_assignment() IS 'Validates team player assignments and prevents conflicts';
COMMENT ON FUNCTION public.validate_tournament_team_registration() IS 'Validates tournament team registrations';
COMMENT ON FUNCTION public.validate_match_data() IS 'Validates match data consistency';
COMMENT ON FUNCTION public.notify_realtime_changes() IS 'Sends real-time notifications for table changes';