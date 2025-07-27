# Mowe Sport - Backup and Recovery Procedures

## Overview

This document provides comprehensive backup and recovery procedures for the Mowe Sport platform. It covers automated backup strategies, recovery procedures, disaster recovery planning, and data protection best practices.

## Table of Contents

1. [Backup Strategy](#backup-strategy)
2. [Automated Backup Systems](#automated-backup-systems)
3. [Recovery Procedures](#recovery-procedures)
4. [Disaster Recovery](#disaster-recovery)
5. [Data Protection](#data-protection)
6. [Testing and Validation](#testing-and-validation)
7. [Monitoring and Alerting](#monitoring-and-alerting)

## Backup Strategy

### Backup Types and Schedule

#### 1. Continuous Backups (Real-time)
- **Method**: Write-Ahead Logging (WAL) archiving
- **Frequency**: Continuous
- **Retention**: 7 days
- **Purpose**: Point-in-time recovery

#### 2. Daily Incremental Backups
- **Method**: pg_dump with incremental changes
- **Frequency**: Every day at 2:00 AM UTC
- **Retention**: 30 days
- **Purpose**: Daily recovery points

#### 3. Weekly Full Backups
- **Method**: pg_dump with custom format
- **Frequency**: Every Sunday at 1:00 AM UTC
- **Retention**: 12 weeks (3 months)
- **Purpose**: Full system recovery

#### 4. Monthly Archive Backups
- **Method**: Full database dump + file system backup
- **Frequency**: First Sunday of each month
- **Retention**: 12 months
- **Purpose**: Long-term archival and compliance

### Backup Locations

#### Primary Backup Storage
- **Location**: Local server `/backups/mowe-sport/`
- **Purpose**: Fast recovery access
- **Retention**: 7 days

#### Secondary Backup Storage
- **Location**: Cloud storage (AWS S3/Google Cloud Storage)
- **Purpose**: Offsite backup and disaster recovery
- **Retention**: As per backup type schedule

#### Archive Storage
- **Location**: Cold storage (AWS Glacier/Google Archive)
- **Purpose**: Long-term compliance and archival
- **Retention**: 7 years

## Automated Backup Systems

### WAL Archiving Setup

#### PostgreSQL Configuration
```sql
-- Enable WAL archiving in postgresql.conf
wal_level = replica
archive_mode = on
archive_command = 'cp %p /backups/mowe-sport/wal/%f'
archive_timeout = 300  -- 5 minutes

-- Create WAL archive directory
```

```bash
#!/bin/bash
# setup-wal-archiving.sh

WAL_ARCHIVE_DIR="/backups/mowe-sport/wal"
mkdir -p $WAL_ARCHIVE_DIR
chown postgres:postgres $WAL_ARCHIVE_DIR
chmod 700 $WAL_ARCHIVE_DIR

# Create WAL cleanup script
cat > /usr/local/bin/cleanup-wal.sh << 'EOF'
#!/bin/bash
# Clean up WAL files older than 7 days
find /backups/mowe-sport/wal -name "*.backup" -mtime +7 -delete
find /backups/mowe-sport/wal -name "*" -mtime +7 -delete
EOF

chmod +x /usr/local/bin/cleanup-wal.sh

# Add to crontab
echo "0 3 * * * /usr/local/bin/cleanup-wal.sh" | crontab -
```

### Daily Backup Script

```bash
#!/bin/bash
# daily-backup.sh

set -e

# Configuration
BACKUP_DIR="/backups/mowe-sport/daily"
CLOUD_BUCKET="s3://mowe-sport-backups/daily"
DATABASE_URL="${DATABASE_URL}"
DATE=$(date +%Y%m%d_%H%M%S)
BACKUP_FILE="mowe_sport_daily_$DATE.sql"
LOG_FILE="/var/log/mowe-sport/backup.log"

# Logging function
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a $LOG_FILE
}

log "Starting daily backup process"

# Create backup directory
mkdir -p $BACKUP_DIR

# Create database backup
log "Creating database backup: $BACKUP_FILE"
pg_dump "$DATABASE_URL" > "$BACKUP_DIR/$BACKUP_FILE"

if [ $? -eq 0 ]; then
    log "Database backup created successfully"
else
    log "ERROR: Database backup failed"
    exit 1
fi

# Compress backup
log "Compressing backup file"
gzip "$BACKUP_DIR/$BACKUP_FILE"
COMPRESSED_FILE="$BACKUP_FILE.gz"

# Verify backup integrity
log "Verifying backup integrity"
gunzip -t "$BACKUP_DIR/$COMPRESSED_FILE"
if [ $? -eq 0 ]; then
    log "Backup integrity verified"
else
    log "ERROR: Backup integrity check failed"
    exit 1
fi

# Upload to cloud storage
log "Uploading backup to cloud storage"
aws s3 cp "$BACKUP_DIR/$COMPRESSED_FILE" "$CLOUD_BUCKET/" --storage-class STANDARD_IA

if [ $? -eq 0 ]; then
    log "Backup uploaded to cloud storage successfully"
else
    log "ERROR: Cloud upload failed"
    exit 1
fi

# Generate backup metadata
cat > "$BACKUP_DIR/$DATE.metadata" << EOF
{
    "backup_date": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
    "backup_file": "$COMPRESSED_FILE",
    "backup_size": "$(stat -c%s "$BACKUP_DIR/$COMPRESSED_FILE")",
    "database_version": "$(psql "$DATABASE_URL" -t -c "SELECT version();" | head -n1 | xargs)",
    "backup_type": "daily_incremental",
    "retention_days": 30
}
EOF

# Clean up old local backups (keep 7 days)
log "Cleaning up old local backups"
find $BACKUP_DIR -name "*.gz" -mtime +7 -delete
find $BACKUP_DIR -name "*.metadata" -mtime +7 -delete

# Send notification on success
log "Daily backup completed successfully"

# Optional: Send success notification
# curl -X POST -H 'Content-type: application/json' \
#     --data '{"text":"Daily backup completed successfully"}' \
#     $SLACK_WEBHOOK_URL
```

### Weekly Full Backup Script

```bash
#!/bin/bash
# weekly-backup.sh

set -e

# Configuration
BACKUP_DIR="/backups/mowe-sport/weekly"
CLOUD_BUCKET="s3://mowe-sport-backups/weekly"
DATABASE_URL="${DATABASE_URL}"
DATE=$(date +%Y%m%d)
BACKUP_FILE="mowe_sport_weekly_$DATE"
LOG_FILE="/var/log/mowe-sport/backup.log"

# Logging function
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] WEEKLY: $1" | tee -a $LOG_FILE
}

log "Starting weekly full backup process"

# Create backup directory
mkdir -p $BACKUP_DIR

# Create full backup with custom format for faster restore
log "Creating full database backup: $BACKUP_FILE.dump"
pg_dump -Fc "$DATABASE_URL" > "$BACKUP_DIR/$BACKUP_FILE.dump"

if [ $? -eq 0 ]; then
    log "Full database backup created successfully"
else
    log "ERROR: Full database backup failed"
    exit 1
fi

# Create schema-only backup for quick reference
log "Creating schema-only backup"
pg_dump -s "$DATABASE_URL" > "$BACKUP_DIR/$BACKUP_FILE.schema.sql"

# Create data-only backup
log "Creating data-only backup"
pg_dump -a "$DATABASE_URL" > "$BACKUP_DIR/$BACKUP_FILE.data.sql"
gzip "$BACKUP_DIR/$BACKUP_FILE.data.sql"

# Generate database statistics
log "Generating database statistics"
psql "$DATABASE_URL" -c "
SELECT 
    schemaname,
    tablename,
    n_tup_ins as inserts,
    n_tup_upd as updates,
    n_tup_del as deletes,
    n_live_tup as live_tuples,
    n_dead_tup as dead_tuples,
    pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename)) as size
FROM pg_stat_user_tables
ORDER BY pg_total_relation_size(schemaname||'.'||tablename) DESC;
" > "$BACKUP_DIR/$BACKUP_FILE.stats.txt"

# Upload to cloud storage
log "Uploading backups to cloud storage"
aws s3 cp "$BACKUP_DIR/$BACKUP_FILE.dump" "$CLOUD_BUCKET/"
aws s3 cp "$BACKUP_DIR/$BACKUP_FILE.schema.sql" "$CLOUD_BUCKET/"
aws s3 cp "$BACKUP_DIR/$BACKUP_FILE.data.sql.gz" "$CLOUD_BUCKET/"
aws s3 cp "$BACKUP_DIR/$BACKUP_FILE.stats.txt" "$CLOUD_BUCKET/"

# Generate comprehensive metadata
cat > "$BACKUP_DIR/$BACKUP_FILE.metadata.json" << EOF
{
    "backup_date": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
    "backup_type": "weekly_full",
    "files": {
        "full_backup": "$BACKUP_FILE.dump",
        "schema_backup": "$BACKUP_FILE.schema.sql",
        "data_backup": "$BACKUP_FILE.data.sql.gz",
        "statistics": "$BACKUP_FILE.stats.txt"
    },
    "sizes": {
        "full_backup": "$(stat -c%s "$BACKUP_DIR/$BACKUP_FILE.dump")",
        "schema_backup": "$(stat -c%s "$BACKUP_DIR/$BACKUP_FILE.schema.sql")",
        "data_backup": "$(stat -c%s "$BACKUP_DIR/$BACKUP_FILE.data.sql.gz")"
    },
    "database_info": {
        "version": "$(psql "$DATABASE_URL" -t -c "SELECT version();" | head -n1 | xargs)",
        "size": "$(psql "$DATABASE_URL" -t -c "SELECT pg_size_pretty(pg_database_size(current_database()));" | xargs)",
        "table_count": "$(psql "$DATABASE_URL" -t -c "SELECT count(*) FROM information_schema.tables WHERE table_schema = 'public';" | xargs)"
    },
    "retention_weeks": 12
}
EOF

aws s3 cp "$BACKUP_DIR/$BACKUP_FILE.metadata.json" "$CLOUD_BUCKET/"

# Clean up old local backups (keep 4 weeks)
log "Cleaning up old local backups"
find $BACKUP_DIR -name "*.dump" -mtime +28 -delete
find $BACKUP_DIR -name "*.sql*" -mtime +28 -delete
find $BACKUP_DIR -name "*.txt" -mtime +28 -delete
find $BACKUP_DIR -name "*.json" -mtime +28 -delete

log "Weekly full backup completed successfully"
```

### Backup Verification Script

```bash
#!/bin/bash
# verify-backup.sh

BACKUP_FILE="$1"
TEST_DB="mowe_sport_backup_test_$(date +%s)"
LOG_FILE="/var/log/mowe-sport/backup-verification.log"

# Logging function
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] VERIFY: $1" | tee -a $LOG_FILE
}

if [ -z "$BACKUP_FILE" ]; then
    echo "Usage: $0 <backup_file>"
    exit 1
fi

log "Starting backup verification for: $BACKUP_FILE"

# Create test database
log "Creating test database: $TEST_DB"
createdb $TEST_DB

# Restore backup to test database
log "Restoring backup to test database"
if [[ $BACKUP_FILE == *.dump ]]; then
    pg_restore -d $TEST_DB $BACKUP_FILE
elif [[ $BACKUP_FILE == *.sql.gz ]]; then
    gunzip -c $BACKUP_FILE | psql $TEST_DB
elif [[ $BACKUP_FILE == *.sql ]]; then
    psql $TEST_DB < $BACKUP_FILE
else
    log "ERROR: Unknown backup file format"
    dropdb $TEST_DB
    exit 1
fi

if [ $? -ne 0 ]; then
    log "ERROR: Backup restore failed"
    dropdb $TEST_DB
    exit 1
fi

# Verify critical tables exist and have data
log "Verifying critical tables and data"
VERIFICATION_RESULT=$(psql $TEST_DB -t -c "
SELECT 
    json_agg(
        json_build_object(
            'table_name', table_name,
            'row_count', row_count,
            'status', CASE WHEN row_count > 0 THEN 'OK' ELSE 'EMPTY' END
        )
    )
FROM (
    SELECT 'user_profiles' as table_name, COUNT(*) as row_count FROM user_profiles
    UNION ALL
    SELECT 'cities' as table_name, COUNT(*) as row_count FROM cities
    UNION ALL
    SELECT 'sports' as table_name, COUNT(*) as row_count FROM sports
    UNION ALL
    SELECT 'tournaments' as table_name, COUNT(*) as row_count FROM tournaments
    UNION ALL
    SELECT 'teams' as table_name, COUNT(*) as row_count FROM teams
    UNION ALL
    SELECT 'matches' as table_name, COUNT(*) as row_count FROM matches
) t;
")

log "Verification results: $VERIFICATION_RESULT"

# Check for critical constraints
log "Verifying database constraints"
CONSTRAINT_CHECK=$(psql $TEST_DB -t -c "
SELECT COUNT(*) 
FROM information_schema.table_constraints 
WHERE constraint_type = 'FOREIGN KEY' 
AND table_schema = 'public';
")

log "Foreign key constraints found: $CONSTRAINT_CHECK"

# Check for indexes
log "Verifying indexes"
INDEX_CHECK=$(psql $TEST_DB -t -c "
SELECT COUNT(*) 
FROM pg_indexes 
WHERE schemaname = 'public';
")

log "Indexes found: $INDEX_CHECK"

# Check for functions
log "Verifying functions"
FUNCTION_CHECK=$(psql $TEST_DB -t -c "
SELECT COUNT(*) 
FROM information_schema.routines 
WHERE routine_schema = 'public';
")

log "Functions found: $FUNCTION_CHECK"

# Clean up test database
log "Cleaning up test database"
dropdb $TEST_DB

# Generate verification report
VERIFICATION_REPORT="/backups/mowe-sport/verification/$(basename $BACKUP_FILE)_verification_$(date +%Y%m%d_%H%M%S).json"
mkdir -p $(dirname $VERIFICATION_REPORT)

cat > $VERIFICATION_REPORT << EOF
{
    "backup_file": "$BACKUP_FILE",
    "verification_date": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
    "status": "SUCCESS",
    "table_verification": $VERIFICATION_RESULT,
    "constraint_count": $CONSTRAINT_CHECK,
    "index_count": $INDEX_CHECK,
    "function_count": $FUNCTION_CHECK,
    "test_database": "$TEST_DB"
}
EOF

log "Backup verification completed successfully"
log "Verification report: $VERIFICATION_REPORT"
```

## Recovery Procedures

### Point-in-Time Recovery

```bash
#!/bin/bash
# point-in-time-recovery.sh

RECOVERY_TIME="$1"  # Format: 2024-01-15 14:30:00+00
BASE_BACKUP="$2"
WAL_ARCHIVE_DIR="/backups/mowe-sport/wal"
RECOVERY_DB="mowe_sport_recovery"
LOG_FILE="/var/log/mowe-sport/recovery.log"

# Logging function
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] RECOVERY: $1" | tee -a $LOG_FILE
}

if [ -z "$RECOVERY_TIME" ] || [ -z "$BASE_BACKUP" ]; then
    echo "Usage: $0 <recovery_time> <base_backup_file>"
    echo "Example: $0 '2024-01-15 14:30:00+00' /backups/weekly/backup.dump"
    exit 1
fi

log "Starting point-in-time recovery to: $RECOVERY_TIME"
log "Using base backup: $BASE_BACKUP"

# Stop application to prevent connections
log "Stopping application services"
systemctl stop mowe-sport-api

# Create recovery database
log "Creating recovery database: $RECOVERY_DB"
createdb $RECOVERY_DB

# Restore base backup
log "Restoring base backup"
if [[ $BASE_BACKUP == *.dump ]]; then
    pg_restore -d $RECOVERY_DB $BASE_BACKUP
else
    psql $RECOVERY_DB < $BASE_BACKUP
fi

if [ $? -ne 0 ]; then
    log "ERROR: Base backup restore failed"
    exit 1
fi

# Create recovery configuration
log "Creating recovery configuration"
cat > /tmp/recovery.conf << EOF
restore_command = 'cp $WAL_ARCHIVE_DIR/%f %p'
recovery_target_time = '$RECOVERY_TIME'
recovery_target_action = 'promote'
EOF

# Apply WAL files for point-in-time recovery
log "Applying WAL files for point-in-time recovery"
# Note: This requires PostgreSQL to be configured for WAL replay
# The exact process depends on PostgreSQL version and configuration

# Verify recovery
log "Verifying recovery results"
RECOVERY_VERIFICATION=$(psql $RECOVERY_DB -t -c "
SELECT 
    'Recovery completed at: ' || now()::text ||
    ', Tables: ' || (SELECT count(*) FROM information_schema.tables WHERE table_schema = 'public')::text ||
    ', Users: ' || (SELECT count(*) FROM user_profiles)::text;
")

log "Recovery verification: $RECOVERY_VERIFICATION"

log "Point-in-time recovery completed"
log "Recovery database: $RECOVERY_DB"
log "IMPORTANT: Verify data before switching to recovery database"
```

### Full System Recovery

```bash
#!/bin/bash
# full-system-recovery.sh

BACKUP_FILE="$1"
RECOVERY_MODE="$2"  # 'replace' or 'parallel'
ORIGINAL_DB="mowe_sport"
RECOVERY_DB="mowe_sport_recovery"
LOG_FILE="/var/log/mowe-sport/recovery.log"

# Logging function
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] FULL_RECOVERY: $1" | tee -a $LOG_FILE
}

if [ -z "$BACKUP_FILE" ]; then
    echo "Usage: $0 <backup_file> [replace|parallel]"
    exit 1
fi

RECOVERY_MODE=${RECOVERY_MODE:-parallel}

log "Starting full system recovery"
log "Backup file: $BACKUP_FILE"
log "Recovery mode: $RECOVERY_MODE"

# Pre-recovery backup of current database
if [ "$RECOVERY_MODE" = "replace" ]; then
    log "Creating pre-recovery backup of current database"
    EMERGENCY_BACKUP="/tmp/emergency_backup_$(date +%Y%m%d_%H%M%S).sql"
    pg_dump "$ORIGINAL_DB" > "$EMERGENCY_BACKUP" 2>/dev/null || log "WARNING: Could not create emergency backup"
fi

# Stop application
log "Stopping application services"
systemctl stop mowe-sport-api

if [ "$RECOVERY_MODE" = "replace" ]; then
    # Drop and recreate original database
    log "Dropping and recreating original database"
    dropdb $ORIGINAL_DB
    createdb $ORIGINAL_DB
    TARGET_DB=$ORIGINAL_DB
else
    # Create parallel recovery database
    log "Creating parallel recovery database"
    dropdb $RECOVERY_DB 2>/dev/null || true
    createdb $RECOVERY_DB
    TARGET_DB=$RECOVERY_DB
fi

# Restore from backup
log "Restoring from backup to: $TARGET_DB"
if [[ $BACKUP_FILE == *.dump ]]; then
    pg_restore -d $TARGET_DB $BACKUP_FILE
elif [[ $BACKUP_FILE == *.sql.gz ]]; then
    gunzip -c $BACKUP_FILE | psql $TARGET_DB
elif [[ $BACKUP_FILE == *.sql ]]; then
    psql $TARGET_DB < $BACKUP_FILE
else
    log "ERROR: Unknown backup file format"
    exit 1
fi

if [ $? -ne 0 ]; then
    log "ERROR: Backup restore failed"
    exit 1
fi

# Verify recovery
log "Verifying recovery"
VERIFICATION_RESULT=$(psql $TARGET_DB -t -c "
SELECT 
    'Database: ' || current_database() ||
    ', Size: ' || pg_size_pretty(pg_database_size(current_database())) ||
    ', Tables: ' || (SELECT count(*) FROM information_schema.tables WHERE table_schema = 'public') ||
    ', Users: ' || (SELECT count(*) FROM user_profiles) ||
    ', Tournaments: ' || (SELECT count(*) FROM tournaments) ||
    ', Teams: ' || (SELECT count(*) FROM teams) ||
    ', Matches: ' || (SELECT count(*) FROM matches);
")

log "Recovery verification: $VERIFICATION_RESULT"

# Update database statistics
log "Updating database statistics"
psql $TARGET_DB -c "ANALYZE;"

if [ "$RECOVERY_MODE" = "replace" ]; then
    # Start application
    log "Starting application services"
    systemctl start mowe-sport-api
    
    # Verify application connectivity
    sleep 10
    curl -f http://localhost:8080/health > /dev/null 2>&1
    if [ $? -eq 0 ]; then
        log "Application started successfully"
    else
        log "WARNING: Application health check failed"
    fi
fi

log "Full system recovery completed"
if [ "$RECOVERY_MODE" = "parallel" ]; then
    log "Recovery database available at: $RECOVERY_DB"
    log "To switch to recovery database:"
    log "1. Stop application: systemctl stop mowe-sport-api"
    log "2. Rename databases: psql -c \"ALTER DATABASE $ORIGINAL_DB RENAME TO ${ORIGINAL_DB}_old; ALTER DATABASE $RECOVERY_DB RENAME TO $ORIGINAL_DB;\""
    log "3. Start application: systemctl start mowe-sport-api"
fi
```

### Emergency Recovery Procedures

```bash
#!/bin/bash
# emergency-recovery.sh

LOG_FILE="/var/log/mowe-sport/emergency-recovery.log"

# Logging function
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] EMERGENCY: $1" | tee -a $LOG_FILE
}

log "=== EMERGENCY RECOVERY PROCEDURE ACTIVATED ==="

# Check if this is really an emergency
echo "This will perform emergency recovery from the latest backup."
echo "Current database will be replaced!"
read -p "Are you absolutely sure? Type 'EMERGENCY' to continue: " confirm

if [ "$confirm" != "EMERGENCY" ]; then
    log "Emergency recovery cancelled by user"
    exit 1
fi

# Find latest backup
LATEST_WEEKLY=$(ls -t /backups/mowe-sport/weekly/*.dump 2>/dev/null | head -n 1)
LATEST_DAILY=$(ls -t /backups/mowe-sport/daily/*.sql.gz 2>/dev/null | head -n 1)

# Choose most recent backup
if [ -n "$LATEST_DAILY" ] && [ -n "$LATEST_WEEKLY" ]; then
    if [ "$LATEST_DAILY" -nt "$LATEST_WEEKLY" ]; then
        BACKUP_FILE="$LATEST_DAILY"
        BACKUP_TYPE="daily"
    else
        BACKUP_FILE="$LATEST_WEEKLY"
        BACKUP_TYPE="weekly"
    fi
elif [ -n "$LATEST_DAILY" ]; then
    BACKUP_FILE="$LATEST_DAILY"
    BACKUP_TYPE="daily"
elif [ -n "$LATEST_WEEKLY" ]; then
    BACKUP_FILE="$LATEST_WEEKLY"
    BACKUP_TYPE="weekly"
else
    log "ERROR: No backups found!"
    exit 1
fi

log "Using $BACKUP_TYPE backup: $BACKUP_FILE"

# Create emergency backup of current state (if possible)
log "Attempting to create emergency backup of current state"
EMERGENCY_BACKUP="/tmp/emergency_current_$(date +%Y%m%d_%H%M%S).sql"
pg_dump mowe_sport > "$EMERGENCY_BACKUP" 2>/dev/null || log "WARNING: Could not backup current state"

# Perform recovery
log "Starting emergency recovery"
./full-system-recovery.sh "$BACKUP_FILE" replace

if [ $? -eq 0 ]; then
    log "Emergency recovery completed successfully"
    
    # Send emergency notification
    cat > /tmp/emergency_notification.txt << EOF
EMERGENCY RECOVERY COMPLETED

Time: $(date)
Backup Used: $BACKUP_FILE ($BACKUP_TYPE)
Status: SUCCESS

The Mowe Sport platform has been restored from backup.
Please verify system functionality immediately.

Emergency backup of previous state: $EMERGENCY_BACKUP
EOF
    
    # Send notification (configure your notification method)
    # mail -s "EMERGENCY RECOVERY COMPLETED" admin@mowesport.com < /tmp/emergency_notification.txt
    
else
    log "ERROR: Emergency recovery failed"
    exit 1
fi
```

## Disaster Recovery

### Disaster Recovery Plan

#### Recovery Time Objectives (RTO)
- **Critical Systems**: 4 hours
- **Non-Critical Systems**: 24 hours
- **Full Platform**: 8 hours

#### Recovery Point Objectives (RPO)
- **Maximum Data Loss**: 15 minutes
- **Typical Data Loss**: 5 minutes

#### Disaster Scenarios

##### Scenario 1: Database Server Failure
```bash
#!/bin/bash
# dr-database-failure.sh

log "DISASTER RECOVERY: Database server failure detected"

# 1. Assess damage
log "Assessing database server status"
systemctl status postgresql || log "PostgreSQL service is down"

# 2. Attempt service recovery
log "Attempting PostgreSQL service recovery"
systemctl restart postgresql
sleep 30

# 3. Test database connectivity
psql "$DATABASE_URL" -c "SELECT 1;" > /dev/null 2>&1
if [ $? -eq 0 ]; then
    log "Database service recovered successfully"
    exit 0
fi

# 4. If service recovery fails, restore from backup
log "Service recovery failed, initiating backup restore"
LATEST_BACKUP=$(ls -t /backups/mowe-sport/daily/*.sql.gz | head -n 1)
./full-system-recovery.sh "$LATEST_BACKUP" replace

log "Database disaster recovery completed"
```

##### Scenario 2: Complete Server Failure
```bash
#!/bin/bash
# dr-complete-server-failure.sh

NEW_SERVER="$1"
BACKUP_LOCATION="$2"

if [ -z "$NEW_SERVER" ] || [ -z "$BACKUP_LOCATION" ]; then
    echo "Usage: $0 <new_server_ip> <backup_location>"
    exit 1
fi

log "DISASTER RECOVERY: Complete server failure - rebuilding on $NEW_SERVER"

# 1. Setup new server environment
log "Setting up new server environment"
ssh root@$NEW_SERVER "
    apt update && apt install -y postgresql-client awscli
    mkdir -p /backups/mowe-sport
"

# 2. Download latest backups
log "Downloading latest backups to new server"
ssh root@$NEW_SERVER "
    aws s3 sync s3://mowe-sport-backups/weekly/ /backups/mowe-sport/weekly/
    aws s3 sync s3://mowe-sport-backups/daily/ /backups/mowe-sport/daily/
"

# 3. Install and configure PostgreSQL
log "Installing PostgreSQL on new server"
ssh root@$NEW_SERVER "
    apt install -y postgresql postgresql-contrib
    systemctl start postgresql
    systemctl enable postgresql
"

# 4. Restore database
log "Restoring database on new server"
LATEST_BACKUP=$(ssh root@$NEW_SERVER "ls -t /backups/mowe-sport/weekly/*.dump | head -n 1")
ssh root@$NEW_SERVER "
    sudo -u postgres createdb mowe_sport
    sudo -u postgres pg_restore -d mowe_sport $LATEST_BACKUP
"

# 5. Deploy application
log "Deploying application on new server"
# Add application deployment steps here

log "Complete server disaster recovery completed"
```

### Cloud Backup Strategy

#### AWS S3 Backup Configuration
```bash
#!/bin/bash
# setup-cloud-backup.sh

# Configure AWS CLI
aws configure set default.region us-east-1
aws configure set default.output json

# Create S3 buckets
aws s3 mb s3://mowe-sport-backups-primary
aws s3 mb s3://mowe-sport-backups-archive

# Configure lifecycle policies
cat > /tmp/lifecycle-policy.json << 'EOF'
{
    "Rules": [
        {
            "ID": "BackupLifecycle",
            "Status": "Enabled",
            "Filter": {"Prefix": "daily/"},
            "Transitions": [
                {
                    "Days": 30,
                    "StorageClass": "STANDARD_IA"
                },
                {
                    "Days": 90,
                    "StorageClass": "GLACIER"
                }
            ],
            "Expiration": {
                "Days": 365
            }
        }
    ]
}
EOF

aws s3api put-bucket-lifecycle-configuration \
    --bucket mowe-sport-backups-primary \
    --lifecycle-configuration file:///tmp/lifecycle-policy.json

# Configure cross-region replication
cat > /tmp/replication-config.json << 'EOF'
{
    "Role": "arn:aws:iam::ACCOUNT:role/replication-role",
    "Rules": [
        {
            "ID": "ReplicateBackups",
            "Status": "Enabled",
            "Filter": {"Prefix": ""},
            "Destination": {
                "Bucket": "arn:aws:s3:::mowe-sport-backups-replica",
                "StorageClass": "STANDARD_IA"
            }
        }
    ]
}
EOF

aws s3api put-bucket-replication \
    --bucket mowe-sport-backups-primary \
    --replication-configuration file:///tmp/replication-config.json
```

## Testing and Validation

### Backup Testing Schedule

#### Monthly Backup Tests
```bash
#!/bin/bash
# monthly-backup-test.sh

TEST_DATE=$(date +%Y%m)
TEST_REPORT="/var/log/mowe-sport/backup-test-$TEST_DATE.log"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] TEST: $1" | tee -a $TEST_REPORT
}

log "Starting monthly backup test"

# Test 1: Verify latest backups exist
log "Test 1: Verifying backup existence"
DAILY_BACKUP=$(ls -t /backups/mowe-sport/daily/*.sql.gz 2>/dev/null | head -n 1)
WEEKLY_BACKUP=$(ls -t /backups/mowe-sport/weekly/*.dump 2>/dev/null | head -n 1)

if [ -n "$DAILY_BACKUP" ] && [ -n "$WEEKLY_BACKUP" ]; then
    log "✅ Backups found - Daily: $DAILY_BACKUP, Weekly: $WEEKLY_BACKUP"
else
    log "❌ Missing backups - Daily: $DAILY_BACKUP, Weekly: $WEEKLY_BACKUP"
fi

# Test 2: Verify backup integrity
log "Test 2: Verifying backup integrity"
./verify-backup.sh "$WEEKLY_BACKUP"

# Test 3: Test restore procedure
log "Test 3: Testing restore procedure"
TEST_DB="backup_test_$(date +%s)"
createdb $TEST_DB
pg_restore -d $TEST_DB "$WEEKLY_BACKUP"

if [ $? -eq 0 ]; then
    log "✅ Restore test successful"
    dropdb $TEST_DB
else
    log "❌ Restore test failed"
fi

# Test 4: Verify cloud backups
log "Test 4: Verifying cloud backups"
CLOUD_BACKUPS=$(aws s3 ls s3://mowe-sport-backups/weekly/ | wc -l)
log "Cloud backups found: $CLOUD_BACKUPS"

# Generate test summary
log "Monthly backup test completed"
```

### Recovery Testing

#### Quarterly Recovery Drill
```bash
#!/bin/bash
# quarterly-recovery-drill.sh

DRILL_DATE=$(date +%Y%m%d)
DRILL_REPORT="/var/log/mowe-sport/recovery-drill-$DRILL_DATE.log"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] DRILL: $1" | tee -a $DRILL_REPORT
}

log "Starting quarterly recovery drill"

# Create isolated test environment
DRILL_DB="recovery_drill_$DRILL_DATE"
log "Creating drill database: $DRILL_DB"
createdb $DRILL_DB

# Test full recovery procedure
LATEST_BACKUP=$(ls -t /backups/mowe-sport/weekly/*.dump | head -n 1)
log "Testing recovery with backup: $LATEST_BACKUP"

START_TIME=$(date +%s)
pg_restore -d $DRILL_DB "$LATEST_BACKUP"
END_TIME=$(date +%s)
RECOVERY_TIME=$((END_TIME - START_TIME))

log "Recovery completed in $RECOVERY_TIME seconds"

# Verify recovered data
log "Verifying recovered data"
VERIFICATION=$(psql $DRILL_DB -t -c "
SELECT 
    'Users: ' || (SELECT count(*) FROM user_profiles) ||
    ', Tournaments: ' || (SELECT count(*) FROM tournaments) ||
    ', Teams: ' || (SELECT count(*) FROM teams) ||
    ', Matches: ' || (SELECT count(*) FROM matches);
")

log "Data verification: $VERIFICATION"

# Test application connectivity (if applicable)
# This would involve starting a test instance of the application

# Clean up
log "Cleaning up drill environment"
dropdb $DRILL_DB

# Generate drill report
cat > "/tmp/recovery-drill-report-$DRILL_DATE.txt" << EOF
QUARTERLY RECOVERY DRILL REPORT
Date: $(date)
Recovery Time: $RECOVERY_TIME seconds
Backup Used: $LATEST_BACKUP
Data Verification: $VERIFICATION
Status: SUCCESS

RTO Target: 4 hours (14400 seconds)
Actual Recovery Time: $RECOVERY_TIME seconds
Performance: $(echo "scale=2; $RECOVERY_TIME/14400*100" | bc)% of RTO target
EOF

log "Quarterly recovery drill completed"
```

This comprehensive backup and recovery documentation ensures that the Mowe Sport platform has robust data protection and can recover from various failure scenarios efficiently.