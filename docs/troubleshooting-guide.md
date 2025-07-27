# Mowe Sport - Troubleshooting Guide

## Overview

This guide provides solutions to common issues that may arise when working with the Mowe Sport platform. It covers database issues, authentication problems, performance concerns, and deployment challenges.

## Table of Contents

1. [Database Issues](#database-issues)
2. [Authentication Problems](#authentication-problems)
3. [RLS Policy Issues](#rls-policy-issues)
4. [Performance Problems](#performance-problems)
5. [API and Backend Issues](#api-and-backend-issues)
6. [Frontend Issues](#frontend-issues)
7. [Deployment Issues](#deployment-issues)
8. [Monitoring and Logging](#monitoring-and-logging)

## Database Issues

### Connection Problems

#### Issue: Database connection timeout
```
Error: connection timeout
```

**Diagnosis:**
```sql
-- Check active connections
SELECT count(*) as active_connections 
FROM pg_stat_activity 
WHERE state = 'active';

-- Check connection limits
SHOW max_connections;
```

**Solutions:**
1. **Increase connection pool size:**
   ```go
   config.MaxConns = 50
   config.MinConns = 10
   config.MaxConnLifetime = time.Hour
   ```

2. **Check for connection leaks:**
   ```go
   defer conn.Close(context.Background())
   ```

3. **Implement connection retry logic:**
   ```go
   func connectWithRetry(databaseURL string, maxRetries int) (*pgx.Conn, error) {
       for i := 0; i < maxRetries; i++ {
           conn, err := pgx.Connect(context.Background(), databaseURL)
           if err == nil {
               return conn, nil
           }
           time.Sleep(time.Duration(i+1) * time.Second)
       }
       return nil, fmt.Errorf("failed to connect after %d retries", maxRetries)
   }
   ```

#### Issue: SSL connection required
```
Error: SSL connection required
```

**Solution:**
```bash
# Update connection string
DATABASE_URL="postgresql://user:pass@host:5432/db?sslmode=require"
```

### Migration Issues

#### Issue: Migration fails with constraint violation
```
Error: duplicate key value violates unique constraint
```

**Diagnosis:**
```sql
-- Check for duplicate data
SELECT email, COUNT(*) 
FROM user_profiles 
GROUP BY email 
HAVING COUNT(*) > 1;
```

**Solutions:**
1. **Clean duplicate data before migration:**
   ```sql
   -- Remove duplicates keeping the latest
   DELETE FROM user_profiles 
   WHERE user_id NOT IN (
       SELECT DISTINCT ON (email) user_id 
       FROM user_profiles 
       ORDER BY email, created_at DESC
   );
   ```

2. **Use ON CONFLICT for upserts:**
   ```sql
   INSERT INTO user_profiles (email, first_name, last_name)
   VALUES ('user@example.com', 'John', 'Doe')
   ON CONFLICT (email) DO UPDATE SET
       first_name = EXCLUDED.first_name,
       last_name = EXCLUDED.last_name;
   ```

#### Issue: Foreign key constraint fails
```
Error: foreign key constraint "fk_tournament_city" is violated
```

**Diagnosis:**
```sql
-- Find orphaned records
SELECT t.* 
FROM tournaments t 
LEFT JOIN cities c ON t.city_id = c.city_id 
WHERE c.city_id IS NULL;
```

**Solutions:**
1. **Create missing parent records:**
   ```sql
   INSERT INTO cities (city_id, name, country)
   SELECT DISTINCT city_id, 'Unknown City', 'Unknown'
   FROM tournaments t
   WHERE NOT EXISTS (SELECT 1 FROM cities c WHERE c.city_id = t.city_id);
   ```

2. **Temporarily disable constraints:**
   ```sql
   ALTER TABLE tournaments DISABLE TRIGGER ALL;
   -- Perform data fixes
   ALTER TABLE tournaments ENABLE TRIGGER ALL;
   ```

### Index Issues

#### Issue: Slow query performance
```
Query takes > 5 seconds to execute
```

**Diagnosis:**
```sql
-- Analyze query performance
EXPLAIN (ANALYZE, BUFFERS) 
SELECT * FROM tournaments 
WHERE city_id = 'uuid-here' AND status = 'active';

-- Check index usage
SELECT schemaname, tablename, indexname, idx_scan, idx_tup_read
FROM pg_stat_user_indexes
ORDER BY idx_scan DESC;
```

**Solutions:**
1. **Create missing indexes:**
   ```sql
   CREATE INDEX CONCURRENTLY idx_tournaments_city_status 
   ON tournaments(city_id, status);
   ```

2. **Update table statistics:**
   ```sql
   ANALYZE tournaments;
   ```

3. **Reindex if needed:**
   ```sql
   REINDEX INDEX CONCURRENTLY idx_tournaments_city_status;
   ```

## Authentication Problems

### Login Issues

#### Issue: User cannot login with correct credentials
```
Error: Invalid email or password
```

**Diagnosis:**
```sql
-- Check user account status
SELECT user_id, email, is_active, account_status, 
       failed_login_attempts, locked_until
FROM user_profiles 
WHERE email = 'user@example.com';

-- Check password hash format
SELECT LENGTH(password_hash), 
       SUBSTRING(password_hash, 1, 6) as hash_prefix
FROM user_profiles 
WHERE email = 'user@example.com';
```

**Solutions:**
1. **Check account lock status:**
   ```sql
   SELECT is_account_locked_detailed('user@example.com');
   ```

2. **Reset failed login attempts:**
   ```sql
   SELECT reset_failed_login_attempts_enhanced('user@example.com');
   ```

3. **Verify password hash:**
   ```sql
   SELECT verify_password('user_password', password_hash)
   FROM user_profiles 
   WHERE email = 'user@example.com';
   ```

#### Issue: Account locked due to failed attempts
```
Error: Account is temporarily locked
```

**Solutions:**
1. **Check lock details:**
   ```sql
   SELECT is_account_locked_detailed('user@example.com');
   ```

2. **Manual unlock (admin only):**
   ```sql
   UPDATE user_profiles 
   SET failed_login_attempts = 0, 
       locked_until = NULL 
   WHERE email = 'user@example.com';
   ```

3. **Wait for automatic unlock:**
   - 15 minutes for 5-9 failed attempts
   - 24 hours for 10+ failed attempts

### JWT Token Issues

#### Issue: JWT token expired or invalid
```
Error: Token is expired or invalid
```

**Diagnosis:**
```go
// Check token expiration
token, err := jwt.Parse(tokenString, func(token *jwt.Token) (interface{}, error) {
    return []byte(secretKey), nil
})

if claims, ok := token.Claims.(jwt.MapClaims); ok {
    exp := claims["exp"].(float64)
    if int64(exp) < time.Now().Unix() {
        // Token is expired
    }
}
```

**Solutions:**
1. **Implement token refresh:**
   ```go
   func refreshToken(refreshToken string) (string, error) {
       // Validate refresh token
       // Generate new access token
       // Return new token
   }
   ```

2. **Check token format:**
   ```go
   parts := strings.Split(tokenString, ".")
   if len(parts) != 3 {
       return errors.New("invalid token format")
   }
   ```

### 2FA Issues

#### Issue: 2FA code not working
```
Error: Invalid 2FA code
```

**Diagnosis:**
```sql
-- Check 2FA status
SELECT two_factor_enabled, two_factor_secret IS NOT NULL as has_secret
FROM user_profiles 
WHERE email = 'user@example.com';
```

**Solutions:**
1. **Regenerate 2FA secret:**
   ```sql
   SELECT generate_2fa_secret('user@example.com');
   ```

2. **Check time synchronization:**
   - Ensure server and client clocks are synchronized
   - TOTP codes are time-sensitive (30-second windows)

3. **Disable 2FA temporarily:**
   ```sql
   UPDATE user_profiles 
   SET two_factor_enabled = FALSE 
   WHERE email = 'user@example.com';
   ```

## RLS Policy Issues

### Access Denied Errors

#### Issue: User cannot access their own data
```
Error: Access denied or no rows returned
```

**Diagnosis:**
```sql
-- Check current user context
SELECT current_user_id(), current_user_role();

-- Check user roles
SELECT * FROM user_roles_by_city_sport 
WHERE user_id = current_user_id();

-- Test RLS policy
SET app.current_user_id = 'user-uuid-here';
SELECT * FROM tournaments WHERE tournament_id = 'tournament-uuid';
```

**Solutions:**
1. **Set user context properly:**
   ```sql
   SELECT set_config('app.current_user_id', 'user-uuid', true);
   ```

2. **Check role assignments:**
   ```sql
   INSERT INTO user_roles_by_city_sport 
   (user_id, city_id, sport_id, role_name, is_active)
   VALUES 
   ('user-uuid', 'city-uuid', 'sport-uuid', 'city_admin', true);
   ```

3. **Temporarily disable RLS for debugging:**
   ```sql
   ALTER TABLE tournaments DISABLE ROW LEVEL SECURITY;
   -- Test query
   ALTER TABLE tournaments ENABLE ROW LEVEL SECURITY;
   ```

#### Issue: RLS policy too restrictive
```
Error: Users cannot access data they should be able to see
```

**Solutions:**
1. **Review policy logic:**
   ```sql
   -- Check existing policies
   SELECT schemaname, tablename, policyname, permissive, roles, cmd, qual
   FROM pg_policies 
   WHERE tablename = 'tournaments';
   ```

2. **Add more permissive policy:**
   ```sql
   CREATE POLICY "additional_access" ON tournaments
   FOR SELECT TO authenticated
   USING (
       -- Add additional access conditions
       is_public = TRUE OR 
       admin_user_id = current_user_id()
   );
   ```

### Multi-Tenancy Issues

#### Issue: Data bleeding between tenants
```
Error: User can see data from other cities/sports
```

**Diagnosis:**
```sql
-- Test data isolation
SET app.current_user_id = 'user1-uuid';
SELECT city_id, sport_id, COUNT(*) 
FROM tournaments 
GROUP BY city_id, sport_id;

-- Check user's assigned cities/sports
SELECT city_id, sport_id, role_name 
FROM user_roles_by_city_sport 
WHERE user_id = 'user1-uuid' AND is_active = true;
```

**Solutions:**
1. **Strengthen RLS policies:**
   ```sql
   DROP POLICY IF EXISTS "city_admin_tournaments" ON tournaments;
   CREATE POLICY "city_admin_tournaments" ON tournaments
   FOR ALL TO authenticated
   USING (
       EXISTS (
           SELECT 1 FROM user_roles_by_city_sport ur
           WHERE ur.user_id = current_user_id()
           AND ur.role_name = 'city_admin'
           AND ur.city_id = tournaments.city_id
           AND ur.sport_id = tournaments.sport_id  -- Ensure both match
           AND ur.is_active = TRUE
       )
   );
   ```

## Performance Problems

### Slow Queries

#### Issue: Database queries taking too long
```
Query execution time > 2 seconds
```

**Diagnosis:**
```sql
-- Enable query logging
SET log_statement = 'all';
SET log_min_duration_statement = 1000; -- Log queries > 1 second

-- Check slow queries
SELECT query, mean_time, calls, total_time
FROM pg_stat_statements
ORDER BY mean_time DESC
LIMIT 10;

-- Analyze specific query
EXPLAIN (ANALYZE, BUFFERS, VERBOSE) 
SELECT * FROM tournaments t
JOIN cities c ON t.city_id = c.city_id
WHERE t.status = 'active';
```

**Solutions:**
1. **Add missing indexes:**
   ```sql
   CREATE INDEX CONCURRENTLY idx_tournaments_status_city 
   ON tournaments(status, city_id) 
   WHERE status IN ('active', 'approved');
   ```

2. **Optimize query structure:**
   ```sql
   -- Instead of
   SELECT * FROM tournaments WHERE city_id IN (
       SELECT city_id FROM cities WHERE country = 'Colombia'
   );
   
   -- Use JOIN
   SELECT t.* FROM tournaments t
   JOIN cities c ON t.city_id = c.city_id
   WHERE c.country = 'Colombia';
   ```

3. **Use partial indexes:**
   ```sql
   CREATE INDEX CONCURRENTLY idx_active_tournaments 
   ON tournaments(city_id, sport_id) 
   WHERE status = 'active' AND is_public = true;
   ```

### Memory Issues

#### Issue: High memory usage
```
Error: Out of memory
```

**Diagnosis:**
```sql
-- Check memory usage
SELECT name, setting, unit 
FROM pg_settings 
WHERE name IN ('shared_buffers', 'work_mem', 'maintenance_work_mem');

-- Check query memory usage
SELECT query, temp_blks_read, temp_blks_written
FROM pg_stat_statements
WHERE temp_blks_read > 0
ORDER BY temp_blks_read DESC;
```

**Solutions:**
1. **Optimize work_mem:**
   ```sql
   SET work_mem = '256MB'; -- For specific session
   ```

2. **Use LIMIT in queries:**
   ```sql
   SELECT * FROM tournaments 
   ORDER BY created_at DESC 
   LIMIT 50 OFFSET 0;
   ```

3. **Implement pagination:**
   ```go
   func GetTournaments(page, pageSize int) ([]Tournament, error) {
       offset := (page - 1) * pageSize
       query := `
           SELECT * FROM tournaments 
           ORDER BY created_at DESC 
           LIMIT $1 OFFSET $2
       `
       // Execute query
   }
   ```

## API and Backend Issues

### Server Startup Issues

#### Issue: Server fails to start
```
Error: Failed to bind to port 8080
```

**Solutions:**
1. **Check port availability:**
   ```bash
   netstat -tulpn | grep :8080
   lsof -i :8080
   ```

2. **Use different port:**
   ```bash
   export PORT=8081
   go run cmd/api/main.go
   ```

3. **Kill existing process:**
   ```bash
   sudo kill -9 $(lsof -t -i:8080)
   ```

### Database Connection in API

#### Issue: API cannot connect to database
```
Error: failed to connect to database
```

**Diagnosis:**
```go
// Test connection
func TestDatabaseConnection() error {
    conn, err := pgx.Connect(context.Background(), databaseURL)
    if err != nil {
        return fmt.Errorf("connection failed: %w", err)
    }
    defer conn.Close(context.Background())
    
    var result int
    err = conn.QueryRow(context.Background(), "SELECT 1").Scan(&result)
    if err != nil {
        return fmt.Errorf("query failed: %w", err)
    }
    
    return nil
}
```

**Solutions:**
1. **Check environment variables:**
   ```bash
   echo $DATABASE_URL
   ```

2. **Validate connection string format:**
   ```
   postgresql://username:password@host:port/database?sslmode=require
   ```

3. **Test with psql:**
   ```bash
   psql "$DATABASE_URL" -c "SELECT version();"
   ```

### Middleware Issues

#### Issue: CORS errors in browser
```
Error: CORS policy blocked the request
```

**Solution:**
```go
func setupCORS(e *echo.Echo) {
    e.Use(middleware.CORSWithConfig(middleware.CORSConfig{
        AllowOrigins: []string{
            "http://localhost:3000",
            "https://yourdomain.com",
        },
        AllowMethods: []string{
            http.MethodGet,
            http.MethodPost,
            http.MethodPut,
            http.MethodDelete,
            http.MethodOptions,
        },
        AllowHeaders: []string{
            echo.HeaderOrigin,
            echo.HeaderContentType,
            echo.HeaderAccept,
            echo.HeaderAuthorization,
        },
        AllowCredentials: true,
    }))
}
```

## Frontend Issues

### Authentication State Issues

#### Issue: User logged out unexpectedly
```
Error: Authentication state lost
```

**Solutions:**
1. **Implement token refresh:**
   ```javascript
   const refreshToken = async () => {
       try {
           const response = await fetch('/api/auth/refresh', {
               method: 'POST',
               credentials: 'include'
           });
           const data = await response.json();
           localStorage.setItem('token', data.token);
           return data.token;
       } catch (error) {
           // Redirect to login
           window.location.href = '/login';
       }
   };
   ```

2. **Check token expiration:**
   ```javascript
   const isTokenExpired = (token) => {
       try {
           const payload = JSON.parse(atob(token.split('.')[1]));
           return payload.exp * 1000 < Date.now();
       } catch {
           return true;
       }
   };
   ```

### Real-time Connection Issues

#### Issue: Supabase realtime not working
```
Error: Realtime subscription failed
```

**Solutions:**
1. **Check connection status:**
   ```javascript
   const subscription = supabase
       .channel('match-updates')
       .on('postgres_changes', {
           event: '*',
           schema: 'public',
           table: 'matches'
       }, (payload) => {
           console.log('Change received!', payload);
       })
       .subscribe((status) => {
           console.log('Subscription status:', status);
       });
   ```

2. **Handle connection errors:**
   ```javascript
   const handleRealtimeError = (error) => {
       console.error('Realtime error:', error);
       // Implement reconnection logic
       setTimeout(() => {
           subscription.unsubscribe();
           setupRealtimeSubscription();
       }, 5000);
   };
   ```

## Deployment Issues

### Environment Configuration

#### Issue: Environment variables not loaded
```
Error: DATABASE_URL is not defined
```

**Solutions:**
1. **Check .env file:**
   ```bash
   cat .env
   ```

2. **Load environment in production:**
   ```bash
   export $(cat .env | xargs)
   ```

3. **Use environment-specific configs:**
   ```go
   func loadConfig() *Config {
       if os.Getenv("ENV") == "production" {
           return loadProductionConfig()
       }
       return loadDevelopmentConfig()
   }
   ```

### SSL/TLS Issues

#### Issue: SSL certificate problems
```
Error: x509: certificate signed by unknown authority
```

**Solutions:**
1. **Skip SSL verification (development only):**
   ```go
   config.TLSConfig = &tls.Config{InsecureSkipVerify: true}
   ```

2. **Use proper SSL mode:**
   ```
   DATABASE_URL="...?sslmode=require"
   ```

## Monitoring and Logging

### Log Analysis

#### Issue: Finding specific errors in logs
```
Need to trace user action through system
```

**Solutions:**
1. **Structured logging:**
   ```go
   logger.WithFields(logrus.Fields{
       "user_id": userID,
       "action": "login_attempt",
       "ip": clientIP,
   }).Info("User login attempt")
   ```

2. **Correlation IDs:**
   ```go
   correlationID := uuid.New().String()
   ctx = context.WithValue(ctx, "correlation_id", correlationID)
   ```

3. **Database audit logs:**
   ```sql
   SELECT * FROM audit_logs 
   WHERE user_id = 'user-uuid' 
   AND created_at > NOW() - INTERVAL '1 hour'
   ORDER BY created_at DESC;
   ```

### Performance Monitoring

#### Issue: Identifying performance bottlenecks
```
System is slow but cause is unknown
```

**Solutions:**
1. **Database query monitoring:**
   ```sql
   -- Enable pg_stat_statements
   CREATE EXTENSION IF NOT EXISTS pg_stat_statements;
   
   -- Check slow queries
   SELECT query, calls, total_time, mean_time
   FROM pg_stat_statements
   ORDER BY total_time DESC
   LIMIT 10;
   ```

2. **Application metrics:**
   ```go
   // Add metrics to handlers
   func (h *Handler) handleLogin(c echo.Context) error {
       start := time.Now()
       defer func() {
           duration := time.Since(start)
           metrics.RecordHandlerDuration("login", duration)
       }()
       
       // Handler logic
   }
   ```

## Emergency Procedures

### System Recovery

#### Issue: Complete system failure
```
Database is down or corrupted
```

**Recovery Steps:**
1. **Check system status:**
   ```bash
   systemctl status postgresql
   systemctl status your-app
   ```

2. **Restore from backup:**
   ```bash
   pg_restore -d mowe_sport backup_file.dump
   ```

3. **Verify data integrity:**
   ```sql
   -- Run integrity checks
   SELECT COUNT(*) FROM user_profiles;
   SELECT COUNT(*) FROM tournaments;
   -- Check for orphaned records
   ```

### Data Corruption

#### Issue: Data inconsistency detected
```
Foreign key violations or orphaned records
```

**Recovery Steps:**
1. **Identify corruption:**
   ```sql
   -- Find orphaned tournaments
   SELECT t.* FROM tournaments t
   LEFT JOIN cities c ON t.city_id = c.city_id
   WHERE c.city_id IS NULL;
   ```

2. **Fix data integrity:**
   ```sql
   -- Create missing parent records or remove orphans
   DELETE FROM tournaments 
   WHERE city_id NOT IN (SELECT city_id FROM cities);
   ```

3. **Prevent future issues:**
   ```sql
   -- Add constraints if missing
   ALTER TABLE tournaments 
   ADD CONSTRAINT fk_tournament_city 
   FOREIGN KEY (city_id) REFERENCES cities(city_id);
   ```

This troubleshooting guide should help resolve most common issues encountered in the Mowe Sport platform. For issues not covered here, check the system logs and consider reaching out to the development team with specific error messages and context.