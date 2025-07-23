# Mowe Sport Database - Supabase PostgreSQL

This directory contains all SQL scripts for the Mowe Sport platform database implementation in Supabase.

## Directory Structure

```
database/
├── README.md                    # This file
├── 01_schema/                   # Core database schema
│   ├── 01_core_tables.sql      # Cities, sports, user profiles
│   ├── 02_tournament_tables.sql # Tournaments and related tables
│   ├── 03_team_player_tables.sql # Teams, players, and relationships
│   ├── 04_match_tables.sql     # Matches and events
│   └── 05_statistics_tables.sql # Statistics tables
├── 02_indexes/                  # Performance indexes
│   ├── 01_core_indexes.sql     # Basic performance indexes
│   └── 02_advanced_indexes.sql # Advanced and partial indexes
├── 03_rls_policies/            # Row Level Security policies
│   ├── 01_user_policies.sql    # User and profile policies
│   ├── 02_tournament_policies.sql # Tournament access policies
│   ├── 03_team_policies.sql    # Team and player policies
│   └── 04_match_policies.sql   # Match and statistics policies
├── 04_functions/               # Database functions and triggers
│   ├── 01_auth_functions.sql   # Authentication helper functions
│   ├── 02_stats_functions.sql  # Statistics calculation functions
│   └── 03_triggers.sql         # Database triggers
├── 05_seed_data/               # Initial data
    ├── 01_cities_sports.sql    # Initial cities and sports
    └── 02_test_data.sql        # Test data for development

```

## Execution Order

Execute the SQL files in the following order:

1. **Schema Creation** (01_schema/)
   - Execute files in numerical order (01, 02, 03, 04, 05)

2. **Indexes** (02_indexes/)
   - Execute after schema creation for optimal performance

3. **RLS Policies** (03_rls_policies/)
   - Execute after schema and indexes for security

4. **Functions and Triggers** (04_functions/)
   - Execute after RLS policies for business logic

5. **Seed Data** (05_seed_data/)
   - Execute last for initial data population

## Important Notes

- All table names use `snake_case` convention
- All column names are in English following project standards
- UUID primary keys are used throughout for scalability
- JSONB columns are used for flexible data storage
- Timestamps include timezone information
- Row Level Security (RLS) is enabled on all sensitive tables

## Supabase Specific Features Used

- **Supabase Auth Integration**: `auth.users` table integration
- **Row Level Security**: Multi-tenant data isolation
- **Realtime**: Enabled on tables requiring live updates
- **UUID Generation**: Using `gen_random_uuid()` function
- **JSONB Support**: For flexible metadata storage

## Development vs Production

- Development scripts include test data and relaxed constraints
- Production scripts focus on performance and security
- Use appropriate script set based on environment

## Backup and Migration

- Always backup before running schema changes
- Test migrations on development environment first
- Use Supabase dashboard for monitoring query performance