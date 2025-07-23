-- =====================================================
-- MOWE SPORT PLATFORM - INITIAL SEED DATA
-- =====================================================
-- Description: Initial cities, sports, and basic configuration data
-- Dependencies: Complete schema
-- Execution Order: After schema, indexes, and RLS policies
-- =====================================================

-- =====================================================
-- INITIAL CITIES DATA
-- =====================================================

INSERT INTO public.cities (city_id, name, region, country, timezone, is_active) VALUES
-- Major Colombian Cities
('550e8400-e29b-41d4-a716-446655440001', 'Bogotá', 'Cundinamarca', 'Colombia', 'America/Bogota', TRUE),
('550e8400-e29b-41d4-a716-446655440002', 'Medellín', 'Antioquia', 'Colombia', 'America/Bogota', TRUE),
('550e8400-e29b-41d4-a716-446655440003', 'Cali', 'Valle del Cauca', 'Colombia', 'America/Bogota', TRUE),
('550e8400-e29b-41d4-a716-446655440004', 'Barranquilla', 'Atlántico', 'Colombia', 'America/Bogota', TRUE),
('550e8400-e29b-41d4-a716-446655440005', 'Cartagena', 'Bolívar', 'Colombia', 'America/Bogota', TRUE),
('550e8400-e29b-41d4-a716-446655440006', 'Bucaramanga', 'Santander', 'Colombia', 'America/Bogota', TRUE),
('550e8400-e29b-41d4-a716-446655440007', 'Pereira', 'Risaralda', 'Colombia', 'America/Bogota', TRUE),
('550e8400-e29b-41d4-a716-446655440008', 'Manizales', 'Caldas', 'Colombia', 'America/Bogota', TRUE),
('550e8400-e29b-41d4-a716-446655440009', 'Santa Marta', 'Magdalena', 'Colombia', 'America/Bogota', TRUE),
('550e8400-e29b-41d4-a716-446655440010', 'Ibagué', 'Tolima', 'Colombia', 'America/Bogota', TRUE),
('550e8400-e29b-41d4-a716-446655440011', 'Pasto', 'Nariño', 'Colombia', 'America/Bogota', TRUE),
('550e8400-e29b-41d4-a716-446655440012', 'Cúcuta', 'Norte de Santander', 'Colombia', 'America/Bogota', TRUE),
('550e8400-e29b-41d4-a716-446655440013', 'Villavicencio', 'Meta', 'Colombia', 'America/Bogota', TRUE),
('550e8400-e29b-41d4-a716-446655440014', 'Armenia', 'Quindío', 'Colombia', 'America/Bogota', TRUE),
('550e8400-e29b-41d4-a716-446655440015', 'Neiva', 'Huila', 'Colombia', 'America/Bogota', TRUE),

-- Smaller Cities/Towns (Examples)
('550e8400-e29b-41d4-a716-446655440016', 'Chía', 'Cundinamarca', 'Colombia', 'America/Bogota', TRUE),
('550e8400-e29b-41d4-a716-446655440017', 'Zipaquirá', 'Cundinamarca', 'Colombia', 'America/Bogota', TRUE),
('550e8400-e29b-41d4-a716-446655440018', 'Facatativá', 'Cundinamarca', 'Colombia', 'America/Bogota', TRUE),
('550e8400-e29b-41d4-a716-446655440019', 'Soacha', 'Cundinamarca', 'Colombia', 'America/Bogota', TRUE),
('550e8400-e29b-41d4-a716-446655440020', 'Fusagasugá', 'Cundinamarca', 'Colombia', 'America/Bogota', TRUE)

ON CONFLICT (city_id) DO NOTHING;

-- =====================================================
-- INITIAL SPORTS DATA
-- =====================================================

INSERT INTO public.sports (sport_id, name, description, default_match_duration, team_size, rules, is_active) VALUES
-- Football/Soccer
(
    '660e8400-e29b-41d4-a716-446655440001', 
    'Fútbol', 
    'El deporte más popular en Colombia y el mundo', 
    90, 
    11,
    '{
        "field_dimensions": {"length": "100-110m", "width": "64-75m"},
        "players_per_team": 11,
        "substitutions_allowed": 5,
        "offside_rule": true,
        "yellow_cards_suspension": 2,
        "red_card_suspension": 1,
        "points_system": {"win": 3, "draw": 1, "loss": 0}
    }'::jsonb,
    TRUE
),

-- Basketball
(
    '660e8400-e29b-41d4-a716-446655440002', 
    'Baloncesto', 
    'Deporte de canasta muy popular en colegios y universidades', 
    48, 
    5,
    '{
        "court_dimensions": {"length": "28m", "width": "15m"},
        "players_per_team": 5,
        "quarters": 4,
        "quarter_duration": 12,
        "shot_clock": 24,
        "three_point_line": true,
        "points_system": {"win": 2, "loss": 0}
    }'::jsonb,
    TRUE
),

-- Volleyball
(
    '660e8400-e29b-41d4-a716-446655440003', 
    'Voleibol', 
    'Deporte de red popular en playas y colegios', 
    90, 
    6,
    '{
        "court_dimensions": {"length": "18m", "width": "9m"},
        "players_per_team": 6,
        "sets_to_win": 3,
        "points_per_set": 25,
        "final_set_points": 15,
        "substitutions_per_set": 6,
        "points_system": {"win": 3, "loss": 0}
    }'::jsonb,
    TRUE
),

-- Futsal
(
    '660e8400-e29b-41d4-a716-446655440004', 
    'Fútbol Sala', 
    'Fútbol en cancha cerrada, muy popular en Colombia', 
    40, 
    5,
    '{
        "court_dimensions": {"length": "38-42m", "width": "20-25m"},
        "players_per_team": 5,
        "halves": 2,
        "half_duration": 20,
        "unlimited_substitutions": true,
        "accumulated_fouls": 5,
        "points_system": {"win": 3, "draw": 1, "loss": 0}
    }'::jsonb,
    TRUE
),

-- Tennis
(
    '660e8400-e29b-41d4-a716-446655440005', 
    'Tenis', 
    'Deporte individual o de parejas', 
    120, 
    1,
    '{
        "court_dimensions": {"length": "23.77m", "width": "8.23m"},
        "players_per_side": 1,
        "doubles_width": "10.97m",
        "sets_to_win": 2,
        "games_per_set": 6,
        "tiebreak_at": 6,
        "points_system": {"win": 2, "loss": 0}
    }'::jsonb,
    TRUE
),

-- Table Tennis
(
    '660e8400-e29b-41d4-a716-446655440006', 
    'Tenis de Mesa', 
    'Ping pong competitivo', 
    60, 
    1,
    '{
        "table_dimensions": {"length": "2.74m", "width": "1.525m"},
        "players_per_side": 1,
        "sets_to_win": 3,
        "points_per_set": 11,
        "serve_rotation": 2,
        "points_system": {"win": 2, "loss": 0}
    }'::jsonb,
    TRUE
),

-- Cycling
(
    '660e8400-e29b-41d4-a716-446655440007', 
    'Ciclismo', 
    'Deporte muy popular en Colombia', 
    180, 
    1,
    '{
        "categories": ["ruta", "montaña", "pista", "bmx"],
        "individual_sport": true,
        "team_classifications": true,
        "time_trials": true,
        "points_system": {"position_based": true}
    }'::jsonb,
    TRUE
),

-- Swimming
(
    '660e8400-e29b-41d4-a716-446655440008', 
    'Natación', 
    'Deporte acuático individual', 
    30, 
    1,
    '{
        "pool_length": "50m",
        "lanes": 8,
        "strokes": ["libre", "espalda", "pecho", "mariposa"],
        "individual_sport": true,
        "relay_events": true,
        "points_system": {"time_based": true}
    }'::jsonb,
    TRUE
),

-- Athletics
(
    '660e8400-e29b-41d4-a716-446655440009', 
    'Atletismo', 
    'Deporte de pista y campo', 
    240, 
    1,
    '{
        "track_events": ["velocidad", "medio_fondo", "fondo", "vallas", "relevos"],
        "field_events": ["saltos", "lanzamientos"],
        "individual_sport": true,
        "team_scoring": true,
        "points_system": {"performance_based": true}
    }'::jsonb,
    TRUE
),

-- Baseball
(
    '660e8400-e29b-41d4-a716-446655440010', 
    'Béisbol', 
    'Popular en la costa caribe colombiana', 
    180, 
    9,
    '{
        "field_type": "diamond",
        "players_per_team": 9,
        "innings": 9,
        "strikes_for_out": 3,
        "balls_for_walk": 4,
        "substitutions": "unlimited",
        "points_system": {"win": 2, "loss": 0}
    }'::jsonb,
    TRUE
)

ON CONFLICT (sport_id) DO NOTHING;

-- =====================================================
-- INITIAL SUPER ADMIN USER
-- =====================================================
-- Note: This will be created manually or through Supabase Auth
-- The user_id should match the auth.users.id from Supabase Auth

-- Example super admin profile (replace with actual auth user ID)
-- INSERT INTO public.user_profiles (
--     user_id, 
--     email, 
--     first_name, 
--     last_name, 
--     primary_role, 
--     is_active, 
--     account_status
-- ) VALUES (
--     'auth-user-id-from-supabase', 
--     'admin@mowesport.com', 
--     'Super', 
--     'Admin', 
--     'super_admin', 
--     TRUE, 
--     'active'
-- ) ON CONFLICT (user_id) DO NOTHING;

-- =====================================================
-- TOURNAMENT SETTINGS TEMPLATES
-- =====================================================
-- Note: Tournament settings are specific to tournaments and will be created
-- when tournaments are created. These templates are commented out as they
-- require actual tournament IDs.

-- Example tournament settings that can be used when creating tournaments:
/*
-- Football tournament settings template
INSERT INTO public.tournament_settings (tournament_id, setting_key, setting_value, description) 
VALUES (
    '[tournament_id_here]',
    'football_points_system',
    '{"win": 3, "draw": 1, "loss": 0, "walkover_win": 3, "walkover_loss": 0}'::jsonb,
    'Standard football points system'
);

-- Basketball tournament settings template
INSERT INTO public.tournament_settings (tournament_id, setting_key, setting_value, description) 
VALUES (
    '[tournament_id_here]',
    'basketball_points_system',
    '{"win": 2, "loss": 0, "overtime_win": 2, "overtime_loss": 1}'::jsonb,
    'Standard basketball points system'
);
*/

-- =====================================================
-- SAMPLE TOURNAMENT CATEGORIES
-- =====================================================
-- Common age categories that can be used across tournaments

-- Note: These will be inserted when actual tournaments are created
-- This is just for reference of common categories used in Colombian sports

/*
Common Age Categories in Colombian Sports:
- Pre-infantil: Under 10
- Infantil: Under 12  
- Pre-juvenil: Under 14
- Juvenil: Under 16
- Junior: Under 18
- Sub-20: Under 20
- Mayores: Open/Senior (18+)
- Veteranos: Masters (35+)
- Super Veteranos: Super Masters (45+)
*/

-- =====================================================
-- INITIAL AUDIT LOG ENTRY
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
    NULL, -- System action
    'SYSTEM_INIT',
    'cities',
    NULL,
    '{"message": "Initial seed data loaded", "cities_count": 20, "sports_count": 10}'::jsonb,
    '127.0.0.1'::inet,
    'Mowe Sport Database Initialization'
);

-- =====================================================
-- VERIFICATION QUERIES
-- =====================================================
-- These can be run to verify the seed data was inserted correctly

-- Verify cities were inserted
-- SELECT COUNT(*) as cities_count FROM public.cities WHERE is_active = TRUE;

-- Verify sports were inserted  
-- SELECT COUNT(*) as sports_count FROM public.sports WHERE is_active = TRUE;

-- List all cities by region
-- SELECT region, COUNT(*) as city_count 
-- FROM public.cities 
-- WHERE is_active = TRUE 
-- GROUP BY region 
-- ORDER BY city_count DESC;

-- List all sports with their team sizes
-- SELECT name, team_size, default_match_duration 
-- FROM public.sports 
-- WHERE is_active = TRUE 
-- ORDER BY name;

-- =====================================================
-- NOTES FOR PRODUCTION DEPLOYMENT
-- =====================================================

/*
IMPORTANT NOTES FOR PRODUCTION:

1. SUPER ADMIN CREATION:
   - Create the first super admin user through Supabase Auth dashboard
   - Then insert their profile into user_profiles table with primary_role = 'super_admin'
   - This user will be able to create other administrators

2. CITY CUSTOMIZATION:
   - Add/remove cities based on your target market
   - Update timezone information if expanding to other countries
   - Consider adding more detailed city information (population, coordinates, etc.)

3. SPORTS CUSTOMIZATION:
   - Add/remove sports based on local popularity
   - Customize rules JSON for each sport based on local regulations
   - Update match durations and team sizes as needed

4. LOCALIZATION:
   - All sport names are in Spanish for Colombian market
   - Consider adding multi-language support for sport names
   - Update descriptions based on local terminology

5. PERFORMANCE:
   - Monitor query performance after data insertion
   - Consider adding more indexes if needed based on usage patterns
   - Update statistics after bulk inserts: ANALYZE;

6. SECURITY:
   - Ensure RLS policies are working correctly after seed data
   - Test with different user roles to verify access controls
   - Monitor audit logs for any security issues

7. BACKUP:
   - Take a backup after successful seed data insertion
   - Document the seed data version for future reference
*/