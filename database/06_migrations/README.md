# Migración de Base de Datos Mowe Sport

## Descripción General

Esta migración transforma la tabla `users` básica existente al esquema completo de la plataforma Mowe Sport, incluyendo:

- Migración de datos de usuarios existentes
- Creación del esquema completo con todas las tablas necesarias
- Implementación de seguridad multi-tenencia con RLS
- Optimización de rendimiento con índices
- Sistema de roles granulares

## Estado Actual vs Objetivo

### Estado Actual
Tabla `users` con campos básicos:
- id (SERIAL)
- email, password_hash
- name, last_name, phone
- document, document_type
- role (VARCHAR)
- token_recovery, token_expiration_date
- status (BOOLEAN)
- created_at, updated_at

### Estado Objetivo
Esquema completo con:
- `user_profiles` (reemplaza users) con UUID y campos extendidos
- `user_roles_by_city_sport` para roles granulares
- `cities`, `sports` para multi-tenencia
- Todas las tablas deportivas (tournaments, teams, players, matches, etc.)
- Políticas RLS para seguridad
- Funciones de autenticación avanzadas

## Orden de Ejecución

### Pre-requisitos
1. **Backup completo de la base de datos**
2. **Verificar que tienes los scripts del esquema completo**:
   - `database/01_schema/` - Esquemas de tablas
   - `database/02_indexes/` - Índices de rendimiento
   - `database/03_rls_policies/` - Políticas de seguridad
   - `database/04_functions/` - Funciones de base de datos
   - `database/05_seed_data/` - Datos iniciales

### Ejecución Paso a Paso

#### 1. Crear Esquema Completo (Si no existe)
```sql
-- Ejecutar en orden:
\i database/01_schema/01_core_tables.sql
\i database/01_schema/02_sports_tables.sql
\i database/01_schema/03_tournament_tables.sql
\i database/01_schema/04_match_tables.sql
\i database/01_schema/05_statistics_tables.sql
```

#### 2. Crear Índices
```sql
\i database/02_indexes/01_core_indexes.sql
\i database/02_indexes/02_advanced_indexes.sql
```

#### 3. Ejecutar Migración de Usuarios
```sql
\i database/06_migrations/01_migrate_users_table.sql
```

#### 4. Implementar Seguridad RLS
```sql
\i database/03_rls_policies/01_user_policies.sql
\i database/03_rls_policies/02_tournament_policies.sql
\i database/03_rls_policies/03_team_policies.sql
\i database/03_rls_policies/04_match_policies.sql
```

#### 5. Crear Funciones de Autenticación
```sql
\i database/04_functions/01_auth_functions.sql
\i database/04_functions/02_statistics_functions.sql
```

#### 6. Insertar Datos Iniciales
```sql
\i database/05_seed_data/01_cities_sports.sql
```

#### 7. Validar Migración
```sql
\i database/06_migrations/01_validate_migration.sql
```

## Scripts de Migración

### 01_migrate_users_table.sql
**Propósito**: Script principal de migración
**Funciones**:
- Crea backup automático de datos existentes
- Analiza y valida datos actuales
- Transforma datos de `users` a `user_profiles`
- Crea mapeo de IDs antiguos a nuevos UUIDs
- Asigna roles granulares automáticamente
- Genera reportes de validación

**Transformaciones de Datos**:
```sql
users.id → user_profiles.user_id (SERIAL → UUID)
users.email → user_profiles.email (limpieza y validación)
users.name → user_profiles.first_name
users.last_name → user_profiles.last_name
users.role → user_profiles.primary_role (mapeo de roles)
users.status → user_profiles.is_active + account_status
```

### 01_rollback_users_migration.sql
**Propósito**: Revertir migración en caso de problemas
**Funciones**:
- Crea backup del estado migrado
- Restaura tabla `users` original
- Limpia tablas creadas durante migración
- Restaura índices y restricciones originales

### 01_validate_migration.sql
**Propósito**: Validación completa post-migración
**Funciones**:
- Verifica integridad de datos
- Compara conteos antes/después
- Analiza calidad de datos
- Genera recomendaciones
- Identifica problemas potenciales

## Mapeo de Roles

| Rol Antiguo | Rol Nuevo | Descripción |
|-------------|-----------|-------------|
| admin | city_admin | Administrador de ciudad |
| super_admin | super_admin | Super administrador |
| owner | owner | Propietario de equipo |
| coach | coach | Entrenador |
| referee | referee | Árbitro |
| player | player | Jugador |
| client/user | client | Cliente/Usuario público |

## Validaciones Automáticas

La migración incluye validaciones automáticas:

1. **Preservación de datos**: Todos los usuarios migrados
2. **Mapeo de IDs**: Cada usuario tiene mapeo old_id → new_uuid
3. **Roles asignados**: Usuarios no-super-admin tienen roles granulares
4. **Emails válidos**: Detección y manejo de emails inválidos
5. **Integridad referencial**: Todas las foreign keys válidas

## Manejo de Casos Especiales

### Emails Duplicados/Inválidos
- Emails inválidos → `user{id}_{timestamp}@temp.local`
- Emails duplicados → Se mantiene el primero, otros reciben email temporal

### Nombres Faltantes
- name vacío → "Usuario"
- last_name vacío → "Apellido"

### Roles Inválidos
- Roles no reconocidos → "client"
- Mapeo automático de variaciones (admin → city_admin)

## Monitoreo y Logs

Todos los eventos se registran en `audit_logs`:
- `MIGRATION_START` - Inicio de migración
- `MIGRATION_ANALYSIS` - Análisis de datos
- `MIGRATION_VALIDATION` - Validación de resultados
- `MIGRATION_COMPLETE` - Finalización exitosa

## Rollback de Emergencia

Si necesitas revertir la migración:

```sql
-- SOLO EN CASO DE EMERGENCIA
\i database/06_migrations/01_rollback_users_migration.sql
```

**⚠️ ADVERTENCIA**: El rollback eliminará todos los datos creados después de la migración.

## Verificación Post-Migración

Después de la migración, verifica:

1. **Conteo de usuarios**: `SELECT COUNT(*) FROM user_profiles;`
2. **Roles asignados**: `SELECT role_name, COUNT(*) FROM user_roles_by_city_sport GROUP BY role_name;`
3. **Emails temporales**: `SELECT COUNT(*) FROM user_profiles WHERE email LIKE '%@temp.local';`
4. **Funciones activas**: Prueba login y operaciones básicas

## Troubleshooting

### Error: "function does not exist"
- Ejecutar primero los scripts de funciones: `database/04_functions/`

### Error: "relation does not exist"
- Ejecutar primero los scripts de esquema: `database/01_schema/`

### Error: "duplicate key value"
- Verificar que no hay datos duplicados en tablas existentes
- Limpiar datos antes de migración

### Emails temporales excesivos
- Revisar calidad de datos originales
- Considerar limpieza manual de emails antes de migración

## Contacto y Soporte

Para problemas con la migración:
1. Revisar logs en `audit_logs` tabla
2. Ejecutar script de validación
3. Consultar este README para casos comunes
4. En caso de problemas críticos, ejecutar rollback

---

**Última actualización**: 2025-01-23
**Versión de migración**: 1.0
**Compatibilidad**: PostgreSQL 13+, Supabase