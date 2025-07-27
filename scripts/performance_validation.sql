-- =====================================================
-- MOWE SPORT PLATFORM - PERFORMANCE VALIDATION SCRIPT
-- =====================================================
-- Description: Comprehensive performance testing and validation
-- Usage: Run after all performance optimizations are applied
-- =====================================================

-- =====================================================
-- PERFORMANCE TEST QUERIES
-- =====================================================

-- Test 1: Tournament Standings Performance
-- Expected: < 100ms for tournaments with up to 20 teams
EXPLAIN (ANALYZE, BUFFERS, FORMAT TEXT)
SELECT 
    ts.team_id,
    t.name as team_name,
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
WHERE ts.tournament_id = (SELECT tournament_id FROM tournaments LIMIT 1)
AND ts.matches_played > 0
ORDER BY ts.points DESC, ts.goal_difference DESC, ts.goals_for DESC;

-- Test 2: Player Leaderboard Performance
-- Expected: < 200ms for tournaments with up to 500 players
EXPLAIN (ANALYZE, BUFFERS, FORMAT TEXT)
SELECT 
    ps.player_id,
    p.first_name,
    p.last_name,
    t.name as team_name,
    ps.goals_scored,
    ps.assists,
    ps.matches_played,
    ps.minutes_played
FROM player_statistics ps
JOIN players p ON ps.player_id = p.player_id
JOIN teams t ON ps.team_id = t.team_id
WHERE ps.tournament_id = (SELECT tournament_id FROM tournaments LIMIT 1)
AND ps.matches_played > 0
ORDER BY ps.goals_scored DESC, ps.assists DESC
LIMIT 50;

-- Test 3: Live Match Events Performance
-- Expected: < 50ms for real-time updates
EXPLAIN (ANALYZE, BUFFERS, FORMAT TEXT)
SELECT 
    me.event_id,
    me.event_type,
    me.event_minute,
    p.first_name,
    p.last_name,
    t.name as team_name,
    me.description,
    me.created_at
FROM match_events me
LEFT JOIN players p ON me.player_id = p.player_id
JOIN teams t ON me.team_id = t.team_id
WHERE me.match_id = (SELECT match_id FROM matches WHERE status IN ('live', 'half_time') LIMIT 1)
AND me.is_deleted = FALSE
ORDER BY me.event_minute DESC, me.created_at DESC;

-- Test 4: User Authentication Performance
-- Expected: < 50ms for login queries
EXPLAIN (ANALYZE, BUFFERS, FORMAT TEXT)
SELECT 
    user_id,
    email,
    password_hash,
    first_name,
    last_name,
    primary_role,
    is_active,
    account_status,
    failed_login_attempts,
    locked_until
FROM user_profiles
WHERE LOWER(email) = 'test@example.com'
AND is_active = TRUE
AND account_status = 'active';

-- Test 5: Tournament Listings Performance
-- Expected: < 300ms for public tournament listings
EXPLAIN (ANALYZE, BUFFERS, FORMAT TEXT)
SELECT 
    t.tournament_id,
    t.name,
    c.name as city_name,
    s.name as sport_name,
    t.start_date,
    t.end_date,
    t.status,
    COUNT(tt.team_id) as registered_teams
FROM tournaments t
JOIN cities c ON t.city_id = c.city_id
JOIN sports s ON t.sport_id = s.sport_id
LEFT JOIN tournament_teams tt ON t.tournament_id = tt.tournament_id AND tt.status = 'approved'
WHERE t.is_public = TRUE
AND t.status IN ('approved', 'active')
GROUP BY t.tournament_id, t.name, c.name, s.name, t.start_date, t.end_date, t.status
ORDER BY t.start_date DESC
LIMIT 20;

-- Test 6: Full-Text Search Performance
-- Expected: < 500ms for team search
EXPLAIN (ANALYZE, BUFFERS, FORMAT TEXT)
SELECT 
    t.team_id,
    t.name,
    t.short_name,
    c.name as city_name,
    s.name as sport_name,
    ts_rank(to_tsvector('spanish', t.name), plainto_tsquery('spanish', 'futbol')) as rank
FROM teams t
JOIN cities c ON t.city_id = c.city_id
JOIN sports s ON t.sport_id = s.sport_id
WHERE to_tsvector('spanish', t.name || ' ' || COALESCE(t.short_name, ''))
      @@ plainto_tsquery('spanish', 'futbol')
AND t.is_active = TRUE
ORDER BY rank DESC
LIMIT 20;

-- =====================================================
-- INDEX USAGE ANALYSIS
-- =====================================================

-- Check index usage statistics
SELECT 
    schemaname,
    tablename,
    indexname,
    idx_scan,
    idx_tup_read,
    idx_tup_fetch,
    CASE 
        WHEN idx_scan > 0 
        THEN ROUND((idx_tup_read::NUMERIC / idx_scan), 2)
        ELSE 0 
    END as avg_tuples_per_scan
FROM pg_stat_user_indexes 
WHERE schemaname = 'public'
AND idx_scan > 0
ORDER BY idx_scan DESC
LIMIT 20;

-- Identify unused indexes
SELECT 
    schemaname,
    tablename,
    indexname,
    pg_size_pretty(pg_relation_size(indexrelid)) as index_size
FROM pg_stat_user_indexes 
WHERE idx_scan = 0 
AND schemaname = 'public'
AND indexname NOT LIKE '%_pkey'
ORDER BY pg_relation_size(indexrelid) DESC;

-- =====================================================
-- TABLE STATISTICS ANALYSIS
-- =====================================================

-- Table size and activity analysis
SELECT 
    schemaname,
    tablename,
    pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename)) as total_size,
    pg_size_pretty(pg_relation_size(schemaname||'.'||tablename)) as table_size,
    pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename) - 
                   pg_relation_size(schemaname||'.'||tablename)) as index_size,
    n_live_tup as estimated_rows,
    n_dead_tup as dead_rows,
    CASE 
        WHEN n_live_tup > 0 
        THEN ROUND((n_dead_tup::NUMERIC / n_live_tup) * 100, 2)
        ELSE 0 
    END as dead_row_percentage,
    last_vacuum,
    last_analyze
FROM pg_stat_user_tables 
WHERE schemaname = 'public'
ORDER BY pg_total_relation_size(schemaname||'.'||tablename) DESC;

-- =====================================================
-- QUERY PERFORMANCE BENCHMARKS
-- =====================================================

-- Benchmark critical queries
DO $$
DECLARE
    start_time TIMESTAMP;
    end_time TIMESTAMP;
    execution_time INTERVAL;
    row_count INTEGER;
BEGIN
    RAISE NOTICE 'Starting Performance Benchmarks...';
    
    -- Benchmark 1: Tournament Standings
    start_time := clock_timestamp();
    SELECT COUNT(*) INTO row_count
    FROM team_statistics ts
    JOIN teams t ON ts.team_id = t.team_id
    WHERE ts.matches_played > 0;
    end_time := clock_timestamp();
    execution_time := end_time - start_time;
    
    RAISE NOTICE 'Tournament Standings Query: % ms (%% rows)', 
        EXTRACT(MILLISECONDS FROM execution_time), row_count;
    
    -- Benchmark 2: Player Statistics
    start_time := clock_timestamp();
    SELECT COUNT(*) INTO row_count
    FROM player_statistics ps
    JOIN players p ON ps.player_id = p.player_id
    WHERE ps.matches_played > 0;
    end_time := clock_timestamp();
    execution_time := end_time - start_time;
    
    RAISE NOTICE 'Player Statistics Query: % ms (%% rows)', 
        EXTRACT(MILLISECONDS FROM execution_time), row_count;
    
    -- Benchmark 3: Live Matches
    start_time := clock_timestamp();
    SELECT COUNT(*) INTO row_count
    FROM matches m
    WHERE m.status IN ('live', 'half_time', 'scheduled');
    end_time := clock_timestamp();
    execution_time := end_time - start_time;
    
    RAISE NOTICE 'Live Matches Query: % ms (%% rows)', 
        EXTRACT(MILLISECONDS FROM execution_time), row_count;
    
    -- Benchmark 4: User Authentication
    start_time := clock_timestamp();
    SELECT COUNT(*) INTO row_count
    FROM user_profiles
    WHERE is_active = TRUE AND account_status = 'active';
    end_time := clock_timestamp();
    execution_time := end_time - start_time;
    
    RAISE NOTICE 'User Authentication Query: % ms (%% rows)', 
        EXTRACT(MILLISECONDS FROM execution_time), row_count;
    
    RAISE NOTICE 'Performance Benchmarks Completed!';
END $$;

-- =====================================================
-- MATERIALIZED VIEW PERFORMANCE TEST
-- =====================================================

-- Test materialized view performance
DO $$
DECLARE
    start_time TIMESTAMP;
    end_time TIMESTAMP;
    execution_time INTERVAL;
    row_count INTEGER;
BEGIN
    RAISE NOTICE 'Testing Materialized View Performance...';
    
    -- Test tournament standings materialized view
    start_time := clock_timestamp();
    SELECT COUNT(*) INTO row_count FROM mv_tournament_standings;
    end_time := clock_timestamp();
    execution_time := end_time - start_time;
    
    RAISE NOTICE 'Tournament Standings MV Query: % ms (%% rows)', 
        EXTRACT(MILLISECONDS FROM execution_time), row_count;
    
    -- Refresh materialized view and measure time
    start_time := clock_timestamp();
    REFRESH MATERIALIZED VIEW CONCURRENTLY mv_tournament_standings;
    end_time := clock_timestamp();
    execution_time := end_time - start_time;
    
    RAISE NOTICE 'Tournament Standings MV Refresh: % ms', 
        EXTRACT(MILLISECONDS FROM execution_time);
    
    RAISE NOTICE 'Materialized View Performance Test Completed!';
END $$;

-- =====================================================
-- PERFORMANCE RECOMMENDATIONS
-- =====================================================

-- Generate performance recommendations
WITH index_usage AS (
    SELECT 
        schemaname,
        tablename,
        indexname,
        idx_scan,
        pg_relation_size(indexrelid) as index_size
    FROM pg_stat_user_indexes 
    WHERE schemaname = 'public'
),
table_stats AS (
    SELECT 
        schemaname,
        tablename,
        n_live_tup,
        n_dead_tup,
        pg_total_relation_size(schemaname||'.'||tablename) as total_size
    FROM pg_stat_user_tables 
    WHERE schemaname = 'public'
)
SELECT 
    'PERFORMANCE RECOMMENDATIONS' as category,
    CASE 
        WHEN EXISTS (SELECT 1 FROM index_usage WHERE idx_scan = 0 AND index_size > 1048576)
        THEN 'Consider dropping unused indexes larger than 1MB'
        WHEN EXISTS (SELECT 1 FROM table_stats WHERE n_dead_tup > n_live_tup * 0.1)
        THEN 'Consider running VACUUM on tables with >10% dead tuples'
        WHEN EXISTS (SELECT 1 FROM table_stats WHERE total_size > 104857600 AND schemaname = 'public')
        THEN 'Consider partitioning tables larger than 100MB'
        ELSE 'Database performance looks good'
    END as recommendation;

-- =====================================================
-- FINAL PERFORMANCE SUMMARY
-- =====================================================

-- Generate final performance summary
SELECT 
    'PERFORMANCE SUMMARY' as section,
    'Total Indexes' as metric,
    COUNT(*)::TEXT as value
FROM pg_stat_user_indexes 
WHERE schemaname = 'public'

UNION ALL

SELECT 
    'PERFORMANCE SUMMARY',
    'Active Indexes',
    COUNT(*)::TEXT
FROM pg_stat_user_indexes 
WHERE schemaname = 'public' AND idx_scan > 0

UNION ALL

SELECT 
    'PERFORMANCE SUMMARY',
    'Unused Indexes',
    COUNT(*)::TEXT
FROM pg_stat_user_indexes 
WHERE schemaname = 'public' AND idx_scan = 0 AND indexname NOT LIKE '%_pkey'

UNION ALL

SELECT 
    'PERFORMANCE SUMMARY',
    'Total Database Size',
    pg_size_pretty(SUM(pg_total_relation_size(schemaname||'.'||tablename)))
FROM pg_stat_user_tables 
WHERE schemaname = 'public'

UNION ALL

SELECT 
    'PERFORMANCE SUMMARY',
    'Largest Table',
    tablename
FROM pg_stat_user_tables 
WHERE schemaname = 'public'
ORDER BY pg_total_relation_size(schemaname||'.'||tablename) DESC
LIMIT 1;

-- =====================================================
-- MAINTENANCE RECOMMENDATIONS
-- =====================================================

COMMENT ON SCRIPT IS '
PERFORMANCE VALIDATION CHECKLIST:

1. RUN THIS SCRIPT AFTER ALL PERFORMANCE OPTIMIZATIONS
2. VERIFY ALL CRITICAL QUERIES EXECUTE WITHIN EXPECTED TIME LIMITS
3. CHECK INDEX USAGE STATISTICS FOR OPTIMIZATION OPPORTUNITIES
4. MONITOR TABLE SIZES AND DEAD TUPLE PERCENTAGES
5. REVIEW MATERIALIZED VIEW PERFORMANCE
6. IMPLEMENT RECOMMENDED MAINTENANCE TASKS

EXPECTED PERFORMANCE TARGETS:
- Tournament Standings: < 100ms
- Player Leaderboards: < 200ms
- Live Match Events: < 50ms
- User Authentication: < 50ms
- Tournament Listings: < 300ms
- Full-Text Search: < 500ms

MAINTENANCE SCHEDULE:
- Daily: Monitor live match performance
- Weekly: Refresh materialized views
- Monthly: Analyze and optimize indexes
- Quarterly: Full performance review
';

-- Log performance validation completion
INSERT INTO audit_logs (action, table_name, description, created_at)
VALUES ('PERFORMANCE_VALIDATION', 'system', 'Performance validation script completed', NOW());