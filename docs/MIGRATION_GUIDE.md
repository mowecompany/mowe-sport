# Guía de Migración de Base de Datos - Mowe Sport

## ¿Qué son las Migraciones?

Las migraciones son **scripts versionados** que permiten evolucionar tu esquema de base de datos de forma **controlada** y **reproducible**. Cada migración tiene:

- **Número de versión**: Para orden secuencial
- **UP script**: Aplica los cambios
- **DOWN script**: Revierte los cambios

## Estructura de Archivos

```
migrations/
├── 001_create_initial_schema.up.sql    # Crea esquema completo
├── 001_create_initial_schema.down.sql  # Elimina esquema completo
├── 002_migrate_users_data.up.sql       # Migra datos de users
├── 002_migrate_users_data.down.sql     # Revierte migración de datos
└── ...                                 # Futuras migraciones
```

## Mejores Prácticas Implementadas

### ✅ 1. Versionado Secuencial
- Cada migración tiene un número único
- Se ejecutan en orden estricto
- No se pueden saltar versiones

### ✅ 2. Siempre UP y DOWN
- **UP**: Aplica el cambio hacia adelante
- **DOWN**: Revierte el cambio hacia atrás
- Permite rollback seguro

### ✅ 3. Nunca Modificar Migraciones Aplicadas
- Si ya se aplicó en producción, NO la edites
- Crea una nueva migración para corregir
- Mantiene historial consistente

### ✅ 4. Migraciones Idempotentes
- Pueden ejecutarse múltiples veces
- Usan `IF NOT EXISTS`, `ON CONFLICT`, etc.
- No fallan si ya están aplicadas

### ✅ 5. Backup Automático
- Cada migración crea backup antes de ejecutar
- Permite recuperación manual si es necesario
- Logs detallados de todos los cambios

## Comandos de Migración

### Aplicar Migraciones
```bash
# Aplicar todas las migraciones pendientes
scripts\migrate.bat up

# Aplicar solo la siguiente migración
scripts\migrate.bat up 1

# Aplicar las siguientes 2 migraciones
scripts\migrate.bat up 2
```

### Revertir Migraciones
```bash
# Revertir la última migración
scripts\migrate.bat down 1

# Revertir las últimas 2 migraciones
scripts\migrate.bat down 2

# ⚠️ PELIGROSO: Revertir todas las migraciones
scripts\migrate.bat down
```

### Ver Estado
```bash
# Ver versión actual
scripts\migrate.bat version

# Ver estado detallado
scripts\migrate.bat status
```

### Comandos de Emergencia
```bash
# Forzar versión específica (solo en emergencias)
scripts\migrate.bat force 1
```

## Proceso de Migración Paso a Paso

### Situación Actual
Tu base de datos tiene una tabla `users` básica que necesita evolucionar al esquema completo de Mowe Sport.

### Paso 1: Verificar Estado Actual
```bash
scripts\migrate.bat status
```

### Paso 2: Aplicar Esquema Completo
```bash
# Esto crea todas las tablas nuevas (user_profiles, cities, sports, etc.)
scripts\migrate.bat up 1
```

### Paso 3: Migrar Datos de Usuarios
```bash
# Esto migra datos de 'users' a 'user_profiles'
scripts\migrate.bat up 1
```

### Paso 4: Verificar Migración
```bash
scripts\migrate.bat version
```

## Detalles de las Migraciones

### Migración 001: Crear Esquema Completo
**Archivo**: `001_create_initial_schema.up.sql`

**Qué hace**:
- Crea todas las tablas del esquema Mowe Sport
- Establece relaciones y constraints
- Crea índices básicos
- Configura triggers para `updated_at`

**Tablas creadas**:
- `cities`, `sports` (datos maestros)
- `user_profiles` (reemplaza `users`)
- `user_roles_by_city_sport` (roles granulares)
- `tournaments`, `teams`, `players` (gestión deportiva)
- `matches`, `match_events` (partidos)
- `player_statistics`, `team_statistics` (estadísticas)
- `audit_logs` (auditoría)

### Migración 002: Migrar Datos de Usuarios
**Archivo**: `002_migrate_users_data.up.sql`

**Qué hace**:
1. **Backup**: Crea `users_backup` con datos actuales
2. **Limpieza**: Valida y limpia emails
3. **Transformación**: Convierte datos al nuevo formato
4. **Mapeo**: Crea tabla `user_id_mapping` (old_id → new_uuid)
5. **Roles**: Asigna roles granulares automáticamente
6. **Validación**: Verifica integridad de datos

**Transformaciones**:
```sql
users.id → user_profiles.user_id (SERIAL → UUID)
users.email → user_profiles.email (validación + limpieza)
users.name → user_profiles.first_name
users.last_name → user_profiles.last_name
users.role → user_profiles.primary_role (mapeo automático)
users.status → user_profiles.is_active + account_status
```

**Mapeo de Roles**:
- `admin` → `city_admin`
- `super_admin` → `super_admin`
- `owner` → `owner`
- `coach` → `coach`
- `referee` → `referee`
- `player` → `player`
- `client`/`user` → `client`

## Casos Especiales Manejados

### Emails Inválidos/Duplicados
- Emails inválidos → `user{id}_{timestamp}@temp.local`
- Emails duplicados → Primero se mantiene, otros reciben email temporal

### Nombres Faltantes
- `name` vacío → "Usuario"
- `last_name` vacío → "Apellido"

### Roles Inválidos
- Roles no reconocidos → "client"
- Mapeo automático de variaciones

## Rollback de Emergencia

Si algo sale mal, puedes revertir:

```bash
# Revertir migración de datos (vuelve a tabla users original)
scripts\migrate.bat down 1

# Revertir esquema completo (elimina todas las tablas nuevas)
scripts\migrate.bat down 1
```

**⚠️ ADVERTENCIA**: El rollback eliminará todos los datos creados después de la migración.

## Validación Post-Migración

Después de migrar, verifica:

```sql
-- 1. Conteo de usuarios
SELECT COUNT(*) FROM user_profiles;

-- 2. Distribución de roles
SELECT primary_role, COUNT(*) 
FROM user_profiles 
GROUP BY primary_role;

-- 3. Emails temporales (deberían ser pocos)
SELECT COUNT(*) 
FROM user_profiles 
WHERE email LIKE '%@temp.local';

-- 4. Mapeo de IDs
SELECT COUNT(*) FROM user_id_mapping;

-- 5. Roles granulares asignados
SELECT role_name, COUNT(*) 
FROM user_roles_by_city_sport 
GROUP BY role_name;
```

## Troubleshooting

### Error: "relation does not exist"
**Causa**: Intentas migrar datos antes de crear el esquema
**Solución**: Ejecuta las migraciones en orden: `up 1`, luego `up 1`

### Error: "duplicate key value"
**Causa**: Datos duplicados en tabla original
**Solución**: Limpia datos duplicados antes de migrar

### Error: "function does not exist"
**Causa**: Dependencias faltantes
**Solución**: Verifica que todas las migraciones anteriores se aplicaron

### Muchos Emails Temporales
**Causa**: Datos de email de baja calidad en tabla original
**Solución**: Limpia emails manualmente antes de migrar

## Monitoreo

Todos los eventos se registran en `audit_logs`:
- `MIGRATION_START` - Inicio de migración
- `MIGRATION_COMPLETE` - Finalización exitosa
- `MIGRATION_ROLLBACK_START` - Inicio de rollback
- `MIGRATION_ROLLBACK_COMPLETE` - Rollback completado

```sql
-- Ver logs de migración
SELECT action, new_values, created_at 
FROM audit_logs 
WHERE action LIKE 'MIGRATION%' 
ORDER BY created_at DESC;
```

## Próximos Pasos

Después de completar la migración:

1. **Actualizar aplicación**: Cambiar código para usar `user_profiles` en lugar de `users`
2. **Implementar RLS**: Aplicar políticas de seguridad
3. **Crear funciones**: Implementar funciones de autenticación avanzadas
4. **Testing**: Probar todas las funcionalidades
5. **Cleanup**: Eliminar tablas de backup cuando todo funcione

## Contacto y Soporte

Para problemas con migraciones:
1. Revisar logs en `audit_logs`
2. Ejecutar `scripts\migrate.bat status`
3. Consultar esta guía para casos comunes
4. En emergencias, usar rollback

---

**Recuerda**: Las migraciones son **irreversibles** en producción. Siempre prueba en desarrollo primero.