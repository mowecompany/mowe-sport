-- =====================================================
-- MOWE SPORT PLATFORM - PERFORMANCE OPTIMIZATION
-- =====================================================
-- Description: Query optimization, materialized views, and performance analysis
-- Dependencies: 01_core_indexes.sql, 02_advanced_indexes.sql
-- Execution Order: After all indexes are created
-- =====================================================

-- =====================================================
-- MATERIALIZED VIEWS FOR COMPLEX QUERIES
-- =====================================================

-- Tournament standings materialized view for fast leaderboards
CREATE MATERIALIZED VIEW IF NOT EXISTS mv_tournament_standings AS
SELECT 
    ts.tournament_id,
    ts.team_id,
    t.name as team_name,
    t.short_name,
    t.logo_url,
    ts.matches_played,
    ts.wins,
    ts.draws,
    ts.losses,
    ts.goals_for,
    ts.goals_against,
    ts.goal_difference,
    ts.points,
    ts.current_position,
    ts.previous_position,
    ts.recent_form,
    ts.home_wins,
    ts.home_draws,
    ts.home_losses,
    ts.away_wins,
    ts.away_draws,
    ts.away_losses,
    ts.updated_at,
    -- Calculate additional metrics
    CASE 
        WHEN ts.matches_played > 0 
        THEN ROUND((ts.points::decimal / (ts.matches_played * 3)) * 100, 2)
        ELSE 0 
    END as points_percentage,
    CASE 
        WHEN ts.matches_played > 0 
        THEN ROUND(ts.goals_for::decimal / ts.matches_played, 2)
        ELSE 0 
    END as goals_per_match,
    CASE 
        WHEN ts.matches_played > 0 
        THEN ROUND(ts.goals_against::decimal / ts.matches_played, 2)
        ELSE 0 
    END as goals_conceded_per_match
FROM team_statistics ts
JOIN teams t ON ts.team_id = t.team_id
WHERE ts.matches_played > 0
ORDER BY ts.tournament_id, ts.current_position NULLS LAST, ts.points DESC, ts.goal_difference DESC;

-- Create index on materialized view
CREATE UNIQUE INDEX IF NOT EXISTS idx_mv_tournament_standings_pk 
ON mv_tournament_standings(tournament_id, team_id);

CREATE INDEX IF NOT EXISTS idx_mv_tournament_standings_position 
ON mv_tournament_standings(tournament_id, current_position);

-- Player statistics leaderboard materialized view
CREATE MATERIALIZED VIEW IF NOT EXISTS mv_player_leaderboards AS
SELECT 
    ps.tournament_id,
    ps.player_id,
    p.first_name,
    p.last_name,
    p.photo_url,
    ps.team_id,
    t.name as team_name,
    t.short_name as team_short_name,
    ps.matches_played,
    ps.goals_scored,
    ps.assists,
    ps.yellow_cards,
    ps.red_cards,
    ps.minutes_played,
    ps.shots_on_target,
    ps.shots_off_target,
    ps.passes_completed,
    ps.passes_attempted,
    ps.updated_at,
    -- Calculate performance metrics
    CASE 
        WHEN ps.minutes_played > 0 
        THEN ROUND(ps.goals_scored::decimal / (ps.minutes_played / 90.0), 2)
        ELSE 0 
    END as goals_per_90min,
    CASE 
        WHEN ps.matches_played > 0 
        THEN ROUND(ps.goals_scored::decimal / ps.matches_played, 2)
        ELSE 0 
    END as goals_per_match,
    CASE 
        WHEN ps.passes_attempted > 0 
        THEN ROUND((ps.passes_completed::decimal / ps.passes_attempted) * 100, 2)
        ELSE 0 
    END as pass_accuracy,
    CASE 
        WHEN (ps.shots_on_target + ps.shots_off_target) > 0 
        THEN ROUND((ps.shots_on_target::decimal / (ps.shots_on_target + ps.shots_off_target)) * 100, 2)
        ELSE 0 
    END as shot_accuracy,
    -- Ranking calculations
    ROW_NUMBER() OVER (PARTITION BY ps.tournament_id ORDER BY ps.goals_scored DESC, ps.assists DESC) as goals_rank,
    ROW_NUMBER() OVER (PARTITION BY ps.tournament_id ORDER BY ps.assists DESC, ps.goals_scored DESC) as assists_rank,
    ROW_NUMBER() OVER (PARTITION BY ps.tournament_id ORDER BY (ps.goals_scored + ps.assists) DESC) as points_rank
FROM player_statistics ps
JOIN players p ON ps.player_id = p.player_id
JOIN teams t ON ps.team_id = t.team_id
WHERE ps.matches_played > 0;

-- Create indexes on player leaderboards materialized view
CREATE UNIQUE INDEX IF NOT EXISTS idx_mv_player_leaderboards_pk 
ON mv_player_leaderboards(tournament_id, player_id, team_id);

CREATE INDEX IF NOT EXISTS idx_mv_player_leaderboards_goals 
ON mv_player_leaderboards(tournament_id, goals_rank);

CREATE INDEX IF NOT EXISTS idx_mv_player_leaderboards_assists 
ON mv_player_leaderboards(tournament_id, assists_rank);

-- Live match events summary materialized view
CREATE MATERIALIZED VIEW IF NOT EXISTS mv_live_match_summary AS
SELECT 
    m.match_id,
    m.tournament_id,
    m.home_team_id,
    m.away_team_id,
    ht.name as home_team_name,
    ht.short_name as home_team_short,
    at.name as away_team_name,
    at.short_name as away_team_short,
    m.match_date,
    m.match_time,
    m.status,
    m.home_team_score,
    m.away_team_score,
    m.actual_start_time,
    -- Event summaries
    COALESCE(goals.home_goals, 0) as home_goals_detail,
    COALESCE(goals.away_goals, 0) as away_goals_detail,
    COALESCE(cards.home_yellow_cards, 0) as home_yellow_cards,
    COALESCE(cards.away_yellow_cards, 0) as away_yellow_cards,
    COALESCE(cards.home_red_cards, 0) as home_red_cards,
    COALESCE(cards.away_red_cards, 0) as away_red_cards,
    -- Latest events
    latest_events.latest_event_time,
    latest_events.latest_event_type,
    latest_events.latest_event_description
FROM matches m
JOIN teams ht ON m.home_team_id = ht.team_id
JOIN teams at ON m.away_team_id = at.team_id
LEFT JOIN (
    SELECT 
        match_id,
        SUM(CASE WHEN team_id = m2.home_team_id AND event_type IN ('goal', 'penalty_goal') THEN 1 ELSE 0 END) as home_goals,
        SUM(CASE WHEN team_id = m2.away_team_id AND event_type IN ('goal', 'penalty_goal') THEN 1 ELSE 0 END) as away_goals
    FROM match_events me
    JOIN matches m2 ON me.match_id = m2.match_id
    WHERE me.is_deleted = FALSE
    GROUP BY match_id
) goals ON m.match_id = goals.match_id
LEFT JOIN (
    SELECT 
        match_id,
        SUM(CASE WHEN team_id = m3.home_team_id AND event_type = 'yellow_card' THEN 1 ELSE 0 END) as home_yellow_cards,
        SUM(CASE WHEN team_id = m3.away_team_id AND event_type = 'yellow_card' THEN 1 ELSE 0 END) as away_yellow_cards,
        SUM(CASE WHEN team_id = m3.home_team_id AND event_type = 'red_card' THEN 1 ELSE 0 END) as home_red_cards,
        SUM(CASE WHEN team_id = m3.away_team_id AND event_type = 'red_card' THEN 1 ELSE 0 END) as away_red_cards
    FROM match_events me
    JOIN matches m3 ON me.match_id = m3.match_id
    WHERE me.is_deleted = FALSE
    GROUP BY match_id
) cards ON m.match_id = cards.match_id
LEFT JOIN (
    SELECT DISTINCT ON (match_id)
        match_id,
        event_minute as latest_event_time,
        event_type as latest_event_type,
        description as latest_event_description
    FROM match_events
    WHERE is_deleted = FALSE
    ORDER BY match_id, created_at DESC
) latest_events ON m.match_id = latest_events.match_id
WHERE m.status IN ('live', 'half_time', 'completed');

-- Create indexes on live match summary
CREATE UNIQUE INDEX IF NOT EXISTS idx_mv_live_match_summary_pk 
ON mv_live_match_summary(match_id);

CREATE INDEX IF NOT EXISTS idx_mv_live_match_summary_tournament 
ON mv_live_match_summary(tournament_id, status, match_date);

-- =====================================================
-- PERFORMANCE ANALYSIS FUNCTIONS
-- =====================================================

-- Function to analyze query performance
CREATE OR REPLACE FUNCTION analyze_query_performance(query_text TEXT)
RETURNS TABLE(
    query_plan TEXT,
    execution_time_ms NUMERIC,
    total_cost NUMERIC,
    rows_estimate BIGINT
) 
LANGUAGE plpgsql
AS $$
DECLARE
    start_time TIMESTAMP;
    end_time TIMESTAMP;
    plan_result TEXT;
BEGIN
    -- Record start time
    start_time := clock_timestamp();
    
    -- Execute EXPLAIN ANALYZE
    EXECUTE 'EXPLAIN (ANALYZE, BUFFERS, FORMAT TEXT) ' || query_text INTO plan_result;
    
    -- Record end time
    end_time := clock_timestamp();
    
    -- Return results
    RETURN QUERY SELECT 
        plan_result,
        EXTRACT(MILLISECONDS FROM (end_time - start_time)),
        0::NUMERIC, -- Will be parsed from plan if needed
        0::BIGINT;  -- Will be parsed from plan if needed
END;
$$;

-- Function to get index usage statistics
CREATE OR REPLACE FUNCTION get_index_usage_stats()
RETURNS TABLE(
    schemaname TEXT,
    tablename TEXT,
    indexname TEXT,
    idx_scan BIGINT,
    idx_tup_read BIGINT,
    idx_tup_fetch BIGINT,
    usage_ratio NUMERIC
)
LANGUAGE sql
AS $$
    SELECT 
        schemaname::TEXT,
        tablename::TEXT,
        indexname::TEXT,
        idx_scan,
        idx_tup_read,
        idx_tup_fetch,
        CASE 
            WHEN idx_scan > 0 
            THEN ROUND((idx_tup_read::NUMERIC / idx_scan), 2)
            ELSE 0 
        END as usage_ratio
    FROM pg_stat_user_indexes 
    WHERE schemaname = 'public'
    ORDER BY idx_scan DESC;
$$;

-- Function to identify unused indexes
CREATE OR REPLACE FUNCTION get_unused_indexes()
RETURNS TABLE(
    schemaname TEXT,
    tablename TEXT,
    indexname TEXT,
    index_size TEXT
)
LANGUAGE sql
AS $$
    SELECT 
        schemaname::TEXT,
        tablename::TEXT,
        indexname::TEXT,
        pg_size_pretty(pg_relation_size(indexrelid))::TEXT as index_size
    FROM pg_stat_user_indexes 
    WHERE idx_scan = 0 
    AND schemaname = 'public'
    AND indexname NOT LIKE '%_pkey'  -- Exclude primary keys
    ORDER BY pg_relation_size(indexrelid) DESC;
$$;

-- Function to get table statistics
CREATE OR REPLACE FUNCTION get_table_stats()
RETURNS TABLE(
    schemaname TEXT,
    tablename TEXT,
    n_tup_ins BIGINT,
    n_tup_upd BIGINT,
    n_tup_del BIGINT,
    n_live_tup BIGINT,
    n_dead_tup BIGINT,
    last_vacuum TIMESTAMP,
    last_analyze TIMESTAMP
)
LANGUAGE sql
AS $$
    SELECT 
        schemaname::TEXT,
        tablename::TEXT,
        n_tup_ins,
        n_tup_upd,
        n_tup_del,
        n_live_tup,
        n_dead_tup,
        last_vacuum,
        last_analyze
    FROM pg_stat_user_tables 
    WHERE schemaname = 'public'
    ORDER BY n_live_tup DESC;
$$;

-- =====================================================
-- QUERY OPTIMIZATION VIEWS
-- =====================================================

-- View for slow query identification
CREATE OR REPLACE VIEW v_slow_queries AS
SELECT 
    query,
    calls,
    total_time,
    mean_time,
    min_time,
    max_time,
    stddev_time,
    rows,
    100.0 * shared_blks_hit / nullif(shared_blks_hit + shared_blks_read, 0) AS hit_percent
FROM pg_stat_statements 
WHERE mean_time > 100  -- Queries taking more than 100ms on average
ORDER BY mean_time DESC;

-- View for database size analysis
CREATE OR REPLACE VIEW v_database_size_analysis AS
SELECT 
    schemaname,
    tablename,
    pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename)) as total_size,
    pg_size_pretty(pg_relation_size(schemaname||'.'||tablename)) as table_size,
    pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename) - pg_relation_size(schemaname||'.'||tablename)) as index_size,
    n_live_tup as estimated_rows
FROM pg_stat_user_tables 
WHERE schemaname = 'public'
ORDER BY pg_total_relation_size(schemaname||'.'||tablename) DESC;

-- =====================================================
-- PERFORMANCE MONITORING PROCEDURES
-- =====================================================

-- Procedure to refresh all materialized views
CREATE OR REPLACE PROCEDURE refresh_materialized_views()
LANGUAGE plpgsql
AS $$
BEGIN
    -- Refresh tournament standings
    REFRESH MATERIALIZED VIEW CONCURRENTLY mv_tournament_standings;
    
    -- Refresh player leaderboards
    REFRESH MATERIALIZED VIEW CONCURRENTLY mv_player_leaderboards;
    
    -- Refresh live match summary
    REFRESH MATERIALIZED VIEW CONCURRENTLY mv_live_match_summary;
    
    -- Log the refresh
    INSERT INTO audit_logs (action, table_name, description, created_at)
    VALUES ('MATERIALIZED_VIEW_REFRESH', 'system', 'All materialized views refreshed', NOW());
    
    RAISE NOTICE 'All materialized views refreshed successfully';
END;
$$;

-- Procedure to update table statistics
CREATE OR REPLACE PROCEDURE update_table_statistics()
LANGUAGE plpgsql
AS $$
DECLARE
    table_record RECORD;
BEGIN
    -- Analyze all main tables
    FOR table_record IN 
        SELECT tablename 
        FROM pg_tables 
        WHERE schemaname = 'public' 
        AND tablename NOT LIKE 'pg_%'
    LOOP
        EXECUTE 'ANALYZE public.' || quote_ident(table_record.tablename);
        RAISE NOTICE 'Analyzed table: %', table_record.tablename;
    END LOOP;
    
    -- Log the operation
    INSERT INTO audit_logs (action, table_name, description, created_at)
    VALUES ('ANALYZE_TABLES', 'system', 'Table statistics updated', NOW());
    
    RAISE NOTICE 'Table statistics updated successfully';
END;
$$;

-- =====================================================
-- CRITICAL QUERY OPTIMIZATIONS
-- =====================================================

-- Optimized query for tournament standings (example)
CREATE OR REPLACE FUNCTION get_tournament_standings_optimized(p_tournament_id UUID)
RETURNS TABLE(
    team_id UUID,
    team_name VARCHAR,
    matches_played INTEGER,
    wins INTEGER,
    draws INTEGER,
    losses INTEGER,
    goals_for INTEGER,
    goals_against INTEGER,
    goal_difference INTEGER,
    points INTEGER,
    position INTEGER
)
LANGUAGE sql
STABLE
AS $$
    SELECT 
        ts.team_id,
        t.name,
        ts.matches_played,
        ts.wins,
        ts.draws,
        ts.losses,
        ts.goals_for,
        ts.goals_against,
        ts.goal_difference,
        ts.points,
        ts.current_position
    FROM team_statistics ts
    JOIN teams t ON ts.team_id = t.team_id
    WHERE ts.tournament_id = p_tournament_id
    AND ts.matches_played > 0
    ORDER BY ts.points DESC, ts.goal_difference DESC, ts.goals_for DESC;
$$;

-- Optimized query for player statistics
CREATE OR REPLACE FUNCTION get_player_stats_optimized(p_tournament_id UUID, p_stat_type VARCHAR DEFAULT 'goals')
RETURNS TABLE(
    player_id UUID,
    first_name VARCHAR,
    last_name VARCHAR,
    team_name VARCHAR,
    stat_value INTEGER,
    matches_played INTEGER
)
LANGUAGE sql
STABLE
AS $$
    SELECT 
        ps.player_id,
        p.first_name,
        p.last_name,
        t.name,
        CASE p_stat_type
            WHEN 'goals' THEN ps.goals_scored
            WHEN 'assists' THEN ps.assists
            WHEN 'yellow_cards' THEN ps.yellow_cards
            WHEN 'red_cards' THEN ps.red_cards
            ELSE ps.goals_scored
        END as stat_value,
        ps.matches_played
    FROM player_statistics ps
    JOIN players p ON ps.player_id = p.player_id
    JOIN teams t ON ps.team_id = t.team_id
    WHERE ps.tournament_id = p_tournament_id
    AND ps.matches_played > 0
    ORDER BY stat_value DESC, ps.matches_played DESC
    LIMIT 50;
$$;

-- =====================================================
-- PERFORMANCE TESTING QUERIES
-- =====================================================

-- Test query performance for common operations
CREATE OR REPLACE FUNCTION test_query_performance()
RETURNS TABLE(
    test_name TEXT,
    execution_time_ms NUMERIC,
    result_count BIGINT
)
LANGUAGE plpgsql
AS $$
DECLARE
    start_time TIMESTAMP;
    end_time TIMESTAMP;
    result_count_var BIGINT;
BEGIN
    -- Test 1: Tournament listings
    start_time := clock_timestamp();
    SELECT COUNT(*) INTO result_count_var
    FROM tournaments t
    JOIN cities c ON t.city_id = c.city_id
    JOIN sports s ON t.sport_id = s.sport_id
    WHERE t.status IN ('active', 'approved')
    AND t.is_public = TRUE;
    end_time := clock_timestamp();
    
    RETURN QUERY SELECT 
        'Tournament Listings'::TEXT,
        EXTRACT(MILLISECONDS FROM (end_time - start_time)),
        result_count_var;
    
    -- Test 2: Team statistics calculation
    start_time := clock_timestamp();
    SELECT COUNT(*) INTO result_count_var
    FROM team_statistics ts
    JOIN teams t ON ts.team_id = t.team_id
    WHERE ts.matches_played > 0;
    end_time := clock_timestamp();
    
    RETURN QUERY SELECT 
        'Team Statistics'::TEXT,
        EXTRACT(MILLISECONDS FROM (end_time - start_time)),
        result_count_var;
    
    -- Test 3: Player search
    start_time := clock_timestamp();
    SELECT COUNT(*) INTO result_count_var
    FROM players p
    WHERE to_tsvector('spanish', p.first_name || ' ' || p.last_name) @@ plainto_tsquery('spanish', 'test');
    end_time := clock_timestamp();
    
    RETURN QUERY SELECT 
        'Player Search'::TEXT,
        EXTRACT(MILLISECONDS FROM (end_time - start_time)),
        result_count_var;
    
    -- Test 4: Live match events
    start_time := clock_timestamp();
    SELECT COUNT(*) INTO result_count_var
    FROM match_events me
    JOIN matches m ON me.match_id = m.match_id
    WHERE m.status IN ('live', 'half_time')
    AND me.is_deleted = FALSE;
    end_time := clock_timestamp();
    
    RETURN QUERY SELECT 
        'Live Match Events'::TEXT,
        EXTRACT(MILLISECONDS FROM (end_time - start_time)),
        result_count_var;
END;
$$;

-- =====================================================
-- MAINTENANCE PROCEDURES
-- =====================================================

-- Procedure for regular maintenance
CREATE OR REPLACE PROCEDURE perform_regular_maintenance()
LANGUAGE plpgsql
AS $$
BEGIN
    -- Update table statistics
    CALL update_table_statistics();
    
    -- Refresh materialized views
    CALL refresh_materialized_views();
    
    -- Vacuum analyze critical tables
    VACUUM ANALYZE tournaments;
    VACUUM ANALYZE teams;
    VACUUM ANALYZE players;
    VACUUM ANALYZE matches;
    VACUUM ANALYZE match_events;
    VACUUM ANALYZE team_statistics;
    VACUUM ANALYZE player_statistics;
    
    -- Log maintenance completion
    INSERT INTO audit_logs (action, table_name, description, created_at)
    VALUES ('REGULAR_MAINTENANCE', 'system', 'Regular maintenance completed', NOW());
    
    RAISE NOTICE 'Regular maintenance completed successfully';
END;
$$;

-- =====================================================
-- COMMENTS AND DOCUMENTATION
-- =====================================================

COMMENT ON MATERIALIZED VIEW mv_tournament_standings IS 'Materialized view for fast tournament standings - refresh every 5 minutes during active tournaments';
COMMENT ON MATERIALIZED VIEW mv_player_leaderboards IS 'Materialized view for player statistics leaderboards - refresh every 10 minutes';
COMMENT ON MATERIALIZED VIEW mv_live_match_summary IS 'Materialized view for live match summaries - refresh every 30 seconds during live matches';

COMMENT ON FUNCTION get_tournament_standings_optimized IS 'Optimized function for tournament standings with proper indexing';
COMMENT ON FUNCTION get_player_stats_optimized IS 'Optimized function for player statistics with configurable stat types';
COMMENT ON FUNCTION test_query_performance IS 'Function to test performance of critical queries';

COMMENT ON PROCEDURE refresh_materialized_views IS 'Procedure to refresh all materialized views - run every 5-10 minutes';
COMMENT ON PROCEDURE update_table_statistics IS 'Procedure to update table statistics - run daily';
COMMENT ON PROCEDURE perform_regular_maintenance IS 'Complete maintenance procedure - run weekly';