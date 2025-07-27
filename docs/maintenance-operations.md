# Mowe Sport - Maintenance and Operations Guide

## Overview

This document provides comprehensive guidance for maintaining and operating the Mowe Sport platform. It covers routine maintenance tasks, monitoring procedures, backup strategies, and operational best practices.

## Table of Contents

1. [Daily Operations](#daily-operations)
2. [Database Maintenance](#database-maintenance)
3. [Backup and Recovery](#backup-and-recovery)
4. [Performance Monitoring](#performance-monitoring)
5. [Security Maintenance](#security-maintenance)
6. [System Updates](#system-updates)
7. [Troubleshooting Procedures](#troubleshooting-procedures)
8. [Emergency Response](#emergency-response)

## Daily Operations

### Morning Checklist

#### System Health Check
```bash
#!/bin/bash
# daily-health-check.sh

echo "=== Mowe Sport Daily Health Check ==="
echo "Date: $(date)"
echo

# Check application status
echo "1. Application Status:"
systemctl status mowe-sport-api
echo

# Check database connectivity
echo "2. Database Connectivity:"
psql "$DATABASE_URL" -c "SELECT version();" > /dev/null 2>&1
if [ $? -eq 0 ]; then
    echo "✅ Database connection: OK"
else
    echo "❌ Database connection: FAILED"
fi

# Check disk space
echo "3. Disk Space:"
df -h | grep -E "(/$|/var|/tmp)"

# Check memory usage
echo "4. Memory Usage:"
free -h

# Check active connections
echo "5. Database Connections:"
psql "$DATABASE_URL" -c "SELECT count(*) as active_connections FROM pg_stat_activity WHERE state = 'active';"

echo "=== Health Check Complete ==="
```

#### Key Metrics Review
```sql
-- Daily metrics query
SELECT 
    'Active Users (24h)' as metric,
    COUNT(DISTINCT user_id) as value
FROM audit_logs 
WHERE created_at > NOW() - INTERVAL '24 hours'

UNION ALL

SELECT 
    'New Tournaments (24h)' as metric,
    COUNT(*) as value
FROM tournaments 
WHERE created_at > NOW() - INTERVAL '24 hours'

UNION ALL

SELECT 
    'Matches Played (24h)' as metric,
    COUNT(*) as value
FROM matches 
WHERE status = 'completed' 
AND updated_at > NOW() - INTERVAL '24 hours'

UNION ALL

SELECT 
    'Failed Login Attempts (24h)' as metric,
    COUNT(*) as value
FROM audit_logs 
WHERE action = 'failed_login_attempt' 
AND created_at > NOW() - INTERVAL '24 hours';
```

### Log Review

#### Application Logs
```bash
# Check for errors in application logs
tail -n 1000 /var/log/mowe-sport/app.log | grep -i error

# Check for authentication issues
tail -n 1000 /var/log/mowe-sport/app.log | grep -i "authentication\|login\|failed"

# Check for database connection issues
tail -n 1000 /var/log/mowe-sport/app.log | grep -i "database\|connection\|timeout"
```

#### Database Logs
```bash
# Check PostgreSQL logs for errors
sudo tail -n 500 /var/log/postgresql/postgresql-*.log | grep -i error

# Check for slow queries
sudo tail -n 500 /var/log/postgresql/postgresql-*.log | grep -i "duration:"
```

## Database Maintenance

### Weekly Maintenance Tasks

#### Statistics Update
```sql
-- Update table statistics for query optimization
ANALYZE;

-- Update specific tables if needed
ANALYZE user_profiles;
ANALYZE tournaments;
ANALYZE matches;
ANALYZE player_statistics;
ANALYZE team_statistics;
```

#### Index Maintenance
```sql
-- Check index usage statistics
SELECT 
    schemaname,
    tablename,
    indexname,
    idx_scan,
    idx_tup_read,
    idx_tup_fetch
FROM pg_stat_user_indexes
ORDER BY idx_scan DESC;

-- Identify unused indexes
SELECT 
    schemaname,
    tablename,
    indexname,
    idx_scan
FROM pg_stat_user_indexes
WHERE idx_scan = 0
AND indexname NOT LIKE '%_pkey';

-- Reindex if necessary (during maintenance window)
REINDEX INDEX CONCURRENTLY idx_tournaments_city_sport;
```

#### Vacuum Operations
```sql
-- Regular vacuum (can run during normal operations)
VACUUM (ANALYZE) user_profiles;
VACUUM (ANALYZE) tournaments;
VACUUM (ANALYZE) matches;

-- Full vacuum (requires maintenance window)
-- VACUUM FULL tournaments; -- Only if absolutely necessary
```

### Monthly Maintenance Tasks

#### Database Size Monitoring
```sql
-- Check database size
SELECT 
    pg_size_pretty(pg_database_size(current_database())) as database_size;

-- Check table sizes
SELECT 
    schemaname,
    tablename,
    pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename)) as size,
    pg_size_pretty(pg_relation_size(schemaname||'.'||tablename)) as table_size,
    pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename) - pg_relation_size(schemaname||'.'||tablename)) as index_size
FROM pg_tables 
WHERE schemaname = 'public'
ORDER BY pg_total_relation_size(schemaname||'.'||tablename) DESC;
```

#### Audit Log Cleanup
```sql
-- Archive old audit logs (older than 1 year)
CREATE TABLE audit_logs_archive AS 
SELECT * FROM audit_logs 
WHERE created_at < NOW() - INTERVAL '1 year';

-- Delete archived records
DELETE FROM audit_logs 
WHERE created_at < NOW() - INTERVAL '1 year';

-- Vacuum after large delete
VACUUM ANALYZE audit_logs;
```

#### Performance Review
```sql
-- Check slow queries from pg_stat_statements
SELECT 
    query,
    calls,
    total_time,
    mean_time,
    stddev_time,
    rows
FROM pg_stat_statements
WHERE mean_time > 1000  -- Queries taking more than 1 second on average
ORDER BY mean_time DESC
LIMIT 20;

-- Reset statistics if needed (start of new monitoring period)
-- SELECT pg_stat_statements_reset();
```

## Backup and Recovery

### Automated Backup Strategy

#### Daily Backups
```bash
#!/bin/bash
# daily-backup.sh

BACKUP_DIR="/backups/mowe-sport"
DATE=$(date +%Y%m%d_%H%M%S)
BACKUP_FILE="mowe_sport_backup_$DATE.sql"

# Create backup directory if it doesn't exist
mkdir -p $BACKUP_DIR

# Create database backup
pg_dump "$DATABASE_URL" > "$BACKUP_DIR/$BACKUP_FILE"

# Compress backup
gzip "$BACKUP_DIR/$BACKUP_FILE"

# Upload to cloud storage (example with AWS S3)
aws s3 cp "$BACKUP_DIR/$BACKUP_FILE.gz" "s3://mowe-sport-backups/daily/"

# Clean up local backups older than 7 days
find $BACKUP_DIR -name "*.gz" -mtime +7 -delete

echo "Backup completed: $BACKUP_FILE.gz"
```

#### Weekly Full Backups
```bash
#!/bin/bash
# weekly-backup.sh

BACKUP_DIR="/backups/mowe-sport/weekly"
DATE=$(date +%Y%m%d)
BACKUP_FILE="mowe_sport_full_backup_$DATE"

mkdir -p $BACKUP_DIR

# Create full backup with custom format for faster restore
pg_dump -Fc "$DATABASE_URL" > "$BACKUP_DIR/$BACKUP_FILE.dump"

# Upload to cloud storage
aws s3 cp "$BACKUP_DIR/$BACKUP_FILE.dump" "s3://mowe-sport-backups/weekly/"

# Keep only last 4 weekly backups locally
ls -t $BACKUP_DIR/*.dump | tail -n +5 | xargs rm -f

echo "Weekly backup completed: $BACKUP_FILE.dump"
```

### Backup Verification
```bash
#!/bin/bash
# verify-backup.sh

BACKUP_FILE="$1"
TEST_DB="mowe_sport_test_restore"

# Create test database
createdb $TEST_DB

# Restore backup to test database
if [[ $BACKUP_FILE == *.dump ]]; then
    pg_restore -d $TEST_DB $BACKUP_FILE
else
    psql $TEST_DB < $BACKUP_FILE
fi

# Verify critical tables exist and have data
psql $TEST_DB -c "
SELECT 
    'user_profiles' as table_name, COUNT(*) as row_count 
FROM user_profiles
UNION ALL
SELECT 
    'tournaments' as table_name, COUNT(*) as row_count 
FROM tournaments
UNION ALL
SELECT 
    'matches' as table_name, COUNT(*) as row_count 
FROM matches;
"

# Clean up test database
dropdb $TEST_DB

echo "Backup verification completed for: $BACKUP_FILE"
```

### Recovery Procedures

#### Point-in-Time Recovery
```bash
#!/bin/bash
# point-in-time-recovery.sh

RECOVERY_TIME="$1"  # Format: 2024-01-15 14:30:00
BACKUP_FILE="$2"

echo "Starting point-in-time recovery to: $RECOVERY_TIME"

# Stop application
systemctl stop mowe-sport-api

# Create recovery database
createdb mowe_sport_recovery

# Restore from backup
pg_restore -d mowe_sport_recovery $BACKUP_FILE

# Apply WAL files up to recovery time (if available)
# This requires WAL archiving to be configured

echo "Recovery completed. Verify data before switching databases."
```

#### Emergency Recovery
```bash
#!/bin/bash
# emergency-recovery.sh

echo "=== EMERGENCY RECOVERY PROCEDURE ==="
echo "This will restore from the latest backup"
read -p "Are you sure? (yes/no): " confirm

if [ "$confirm" != "yes" ]; then
    echo "Recovery cancelled"
    exit 1
fi

# Stop application
systemctl stop mowe-sport-api

# Backup current database (if accessible)
pg_dump "$DATABASE_URL" > "/tmp/emergency_backup_$(date +%Y%m%d_%H%M%S).sql" 2>/dev/null

# Find latest backup
LATEST_BACKUP=$(ls -t /backups/mowe-sport/*.dump | head -n 1)

echo "Restoring from: $LATEST_BACKUP"

# Drop and recreate database
dropdb mowe_sport
createdb mowe_sport

# Restore from backup
pg_restore -d mowe_sport $LATEST_BACKUP

# Start application
systemctl start mowe-sport-api

echo "Emergency recovery completed"
```

## Performance Monitoring

### Real-time Monitoring

#### Database Performance
```sql
-- Monitor active queries
SELECT 
    pid,
    now() - pg_stat_activity.query_start AS duration,
    query,
    state
FROM pg_stat_activity
WHERE (now() - pg_stat_activity.query_start) > interval '5 minutes'
AND state = 'active';

-- Monitor locks
SELECT 
    blocked_locks.pid AS blocked_pid,
    blocked_activity.usename AS blocked_user,
    blocking_locks.pid AS blocking_pid,
    blocking_activity.usename AS blocking_user,
    blocked_activity.query AS blocked_statement,
    blocking_activity.query AS current_statement_in_blocking_process
FROM pg_catalog.pg_locks blocked_locks
JOIN pg_catalog.pg_stat_activity blocked_activity ON blocked_activity.pid = blocked_locks.pid
JOIN pg_catalog.pg_locks blocking_locks ON blocking_locks.locktype = blocked_locks.locktype
    AND blocking_locks.database IS NOT DISTINCT FROM blocked_locks.database
    AND blocking_locks.relation IS NOT DISTINCT FROM blocked_locks.relation
    AND blocking_locks.page IS NOT DISTINCT FROM blocked_locks.page
    AND blocking_locks.tuple IS NOT DISTINCT FROM blocked_locks.tuple
    AND blocking_locks.virtualxid IS NOT DISTINCT FROM blocked_locks.virtualxid
    AND blocking_locks.transactionid IS NOT DISTINCT FROM blocked_locks.transactionid
    AND blocking_locks.classid IS NOT DISTINCT FROM blocked_locks.classid
    AND blocking_locks.objid IS NOT DISTINCT FROM blocked_locks.objid
    AND blocking_locks.objsubid IS NOT DISTINCT FROM blocked_locks.objsubid
    AND blocking_locks.pid != blocked_locks.pid
JOIN pg_catalog.pg_stat_activity blocking_activity ON blocking_activity.pid = blocking_locks.pid
WHERE NOT blocked_locks.granted;
```

#### System Resources
```bash
#!/bin/bash
# system-monitor.sh

echo "=== System Resource Monitoring ==="

# CPU Usage
echo "CPU Usage:"
top -bn1 | grep "Cpu(s)" | awk '{print $2 $3 $4 $5 $6 $7 $8}'

# Memory Usage
echo "Memory Usage:"
free -h

# Disk I/O
echo "Disk I/O:"
iostat -x 1 1

# Network connections
echo "Network Connections:"
netstat -an | grep :8080 | wc -l

# Database connections
echo "Database Connections:"
psql "$DATABASE_URL" -c "
SELECT 
    state,
    COUNT(*) as connection_count
FROM pg_stat_activity 
GROUP BY state;
"
```

### Performance Alerts

#### Database Alert Script
```bash
#!/bin/bash
# performance-alerts.sh

# Check database connection count
CONN_COUNT=$(psql "$DATABASE_URL" -t -c "SELECT count(*) FROM pg_stat_activity WHERE state = 'active';")
MAX_CONNECTIONS=$(psql "$DATABASE_URL" -t -c "SHOW max_connections;" | tr -d ' ')

if [ $CONN_COUNT -gt $((MAX_CONNECTIONS * 80 / 100)) ]; then
    echo "ALERT: High database connection usage: $CONN_COUNT/$MAX_CONNECTIONS"
    # Send notification (email, Slack, etc.)
fi

# Check for long-running queries
LONG_QUERIES=$(psql "$DATABASE_URL" -t -c "
SELECT COUNT(*) 
FROM pg_stat_activity 
WHERE state = 'active' 
AND now() - query_start > interval '5 minutes';
")

if [ $LONG_QUERIES -gt 0 ]; then
    echo "ALERT: $LONG_QUERIES long-running queries detected"
fi

# Check disk space
DISK_USAGE=$(df / | awk 'NR==2 {print $5}' | sed 's/%//')
if [ $DISK_USAGE -gt 85 ]; then
    echo "ALERT: High disk usage: $DISK_USAGE%"
fi
```

## Security Maintenance

### Security Audits

#### Weekly Security Check
```sql
-- Check for suspicious login patterns
SELECT 
    user_id,
    COUNT(*) as failed_attempts,
    COUNT(DISTINCT ip_address) as distinct_ips,
    MIN(created_at) as first_attempt,
    MAX(created_at) as last_attempt
FROM audit_logs 
WHERE action = 'failed_login_attempt'
AND created_at > NOW() - INTERVAL '7 days'
GROUP BY user_id
HAVING COUNT(*) > 10 OR COUNT(DISTINCT ip_address) > 5
ORDER BY failed_attempts DESC;

-- Check for accounts with excessive privileges
SELECT 
    up.email,
    up.primary_role,
    COUNT(ur.role_assignment_id) as role_count,
    array_agg(DISTINCT ur.role_name) as roles
FROM user_profiles up
JOIN user_roles_by_city_sport ur ON up.user_id = ur.user_id
WHERE ur.is_active = TRUE
GROUP BY up.user_id, up.email, up.primary_role
HAVING COUNT(ur.role_assignment_id) > 3
ORDER BY role_count DESC;

-- Check for inactive admin accounts
SELECT 
    email,
    primary_role,
    last_login_at,
    is_active
FROM user_profiles 
WHERE primary_role IN ('super_admin', 'city_admin')
AND (last_login_at < NOW() - INTERVAL '30 days' OR last_login_at IS NULL)
AND is_active = TRUE;
```

#### Password Policy Compliance
```sql
-- Check for users who haven't changed passwords recently
SELECT 
    email,
    primary_role,
    created_at,
    updated_at,
    CASE 
        WHEN updated_at = created_at THEN 'Never changed'
        WHEN updated_at < NOW() - INTERVAL '90 days' THEN 'Stale password'
        ELSE 'Recent'
    END as password_status
FROM user_profiles 
WHERE primary_role IN ('super_admin', 'city_admin', 'tournament_admin')
AND is_active = TRUE
ORDER BY updated_at ASC;
```

### Security Updates

#### Monthly Security Tasks
```bash
#!/bin/bash
# monthly-security-maintenance.sh

echo "=== Monthly Security Maintenance ==="

# Update system packages
sudo apt update && sudo apt upgrade -y

# Check for security updates
sudo unattended-upgrades --dry-run

# Review SSL certificates
echo "SSL Certificate Status:"
echo | openssl s_client -servername yourdomain.com -connect yourdomain.com:443 2>/dev/null | openssl x509 -noout -dates

# Check for failed login attempts
echo "Failed Login Summary (Last 30 days):"
psql "$DATABASE_URL" -c "
SELECT 
    DATE(created_at) as date,
    COUNT(*) as failed_attempts
FROM audit_logs 
WHERE action = 'failed_login_attempt'
AND created_at > NOW() - INTERVAL '30 days'
GROUP BY DATE(created_at)
ORDER BY date DESC;
"

# Generate security report
echo "Security Report generated: $(date)"
```

## System Updates

### Application Updates

#### Deployment Checklist
```bash
#!/bin/bash
# deployment-checklist.sh

echo "=== Pre-Deployment Checklist ==="

# 1. Backup database
echo "1. Creating backup..."
pg_dump "$DATABASE_URL" > "/backups/pre-deployment-$(date +%Y%m%d_%H%M%S).sql"

# 2. Run tests
echo "2. Running tests..."
go test ./...

# 3. Check database migrations
echo "3. Checking migrations..."
# Run migration check command

# 4. Verify configuration
echo "4. Verifying configuration..."
# Check environment variables and config files

echo "Pre-deployment checks completed"
```

#### Rolling Update Procedure
```bash
#!/bin/bash
# rolling-update.sh

NEW_VERSION="$1"

echo "Starting rolling update to version: $NEW_VERSION"

# 1. Update application code
git fetch origin
git checkout $NEW_VERSION

# 2. Build new version
go build -o mowe-sport-api-new cmd/api/main.go

# 3. Run database migrations
./migrate up

# 4. Test new binary
./mowe-sport-api-new --test-mode &
TEST_PID=$!
sleep 5

# Test health endpoint
curl -f http://localhost:8081/health || {
    echo "Health check failed"
    kill $TEST_PID
    exit 1
}

kill $TEST_PID

# 5. Replace binary
systemctl stop mowe-sport-api
mv mowe-sport-api-new mowe-sport-api
systemctl start mowe-sport-api

# 6. Verify deployment
sleep 10
curl -f http://localhost:8080/health || {
    echo "Deployment verification failed"
    exit 1
}

echo "Rolling update completed successfully"
```

### Database Updates

#### Schema Migration Process
```bash
#!/bin/bash
# schema-migration.sh

MIGRATION_FILE="$1"

echo "Applying schema migration: $MIGRATION_FILE"

# 1. Backup before migration
pg_dump "$DATABASE_URL" > "/backups/pre-migration-$(date +%Y%m%d_%H%M%S).sql"

# 2. Test migration on copy
createdb mowe_sport_migration_test
pg_dump "$DATABASE_URL" | psql mowe_sport_migration_test

# Apply migration to test database
psql mowe_sport_migration_test < $MIGRATION_FILE

if [ $? -eq 0 ]; then
    echo "Migration test successful"
    dropdb mowe_sport_migration_test
else
    echo "Migration test failed"
    dropdb mowe_sport_migration_test
    exit 1
fi

# 3. Apply to production (during maintenance window)
echo "Applying migration to production..."
psql "$DATABASE_URL" < $MIGRATION_FILE

# 4. Verify migration
echo "Verifying migration..."
psql "$DATABASE_URL" -c "SELECT version();"

echo "Schema migration completed"
```

## Emergency Response

### Incident Response Plan

#### Severity Levels

**Critical (P0)**: System completely down
- Response time: Immediate
- Escalation: All hands on deck

**High (P1)**: Major functionality impaired
- Response time: 15 minutes
- Escalation: Senior team members

**Medium (P2)**: Minor functionality issues
- Response time: 2 hours
- Escalation: Regular team members

**Low (P3)**: Cosmetic or non-critical issues
- Response time: Next business day
- Escalation: Standard process

#### Emergency Contacts
```
Primary On-Call: +1-XXX-XXX-XXXX
Secondary On-Call: +1-XXX-XXX-XXXX
Database Admin: +1-XXX-XXX-XXXX
Security Team: security@mowesport.com
```

#### Emergency Procedures

##### System Down Response
```bash
#!/bin/bash
# emergency-response.sh

echo "=== EMERGENCY RESPONSE ACTIVATED ==="
echo "Time: $(date)"

# 1. Check system status
systemctl status mowe-sport-api
systemctl status postgresql

# 2. Check logs for errors
tail -n 100 /var/log/mowe-sport/app.log | grep -i error

# 3. Check database connectivity
psql "$DATABASE_URL" -c "SELECT 1;" > /dev/null 2>&1
if [ $? -ne 0 ]; then
    echo "DATABASE CONNECTION FAILED"
    # Attempt database restart
    sudo systemctl restart postgresql
fi

# 4. Check disk space
df -h

# 5. Check memory
free -h

# 6. Attempt service restart
systemctl restart mowe-sport-api

# 7. Verify recovery
sleep 30
curl -f http://localhost:8080/health

echo "Emergency response completed"
```

### Communication Templates

#### Incident Notification
```
Subject: [INCIDENT] Mowe Sport Platform Issue - P{severity}

Incident Details:
- Time: {timestamp}
- Severity: P{severity}
- Description: {description}
- Impact: {impact}
- Status: {status}

Actions Taken:
- {action1}
- {action2}

Next Steps:
- {next_step1}
- {next_step2}

Estimated Resolution: {eta}

Updates will be provided every {interval} minutes.
```

#### Resolution Notification
```
Subject: [RESOLVED] Mowe Sport Platform Issue

The incident reported at {start_time} has been resolved.

Resolution Summary:
- Root Cause: {root_cause}
- Resolution: {resolution}
- Duration: {duration}

Post-Incident Actions:
- {action1}
- {action2}

A detailed post-mortem will be conducted within 24 hours.
```

This maintenance and operations guide provides the foundation for reliable operation of the Mowe Sport platform. Regular execution of these procedures will ensure system stability, security, and performance.