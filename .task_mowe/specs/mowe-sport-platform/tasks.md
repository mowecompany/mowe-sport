# Plan de Implementación - Plataforma Mowe Sport

## Estado Actual
✅ Conexión con base de datos establecida  
✅ Estructura base del proyecto Go con Echo configurada  
✅ Esquema completo de base de datos implementado
✅ Tabla user_profiles con campos de autenticación completos
✅ Políticas RLS básicas implementadas
✅ Funciones de autenticación y estadísticas implementadas
✅ Índices básicos y avanzados implementados

## Tareas de Implementación

### Fase 1: Completar Esquema de Base de Datos y Seguridad

- [x] 1. Completar tabla user_profiles con campos de autenticación

  - Agregar campos password_hash, token_recovery, token_expiration_date
  - Implementar campos para 2FA (two_factor_secret, two_factor_enabled)
  - Agregar índices necesarios para email único y búsquedas eficientes
  - Crear trigger para updated_at automático
  - _Requisitos: 3.1, 3.5, 8.1_


- [x] 2. Configurar políticas de Row Level Security (RLS)
  - Habilitar RLS en todas las tablas sensibles
  - Implementar políticas para aislamiento multi-tenencia por ciudad/deporte
  - Crear políticas específicas por rol usando user_roles_by_city_sport
  - Implementar función current_user_id() para RLS
  - Probar políticas con diferentes usuarios y roles
  - _Requisitos: 1.1, 1.2, 5.1, 5.4_


- [x] 3. Implementar funciones de autenticación y seguridad
  - Crear funciones para validación de password_hash
  - Implementar funciones para manejo de intentos de login fallidos
  - Crear sistema de bloqueo progresivo de cuentas (15min -> 24hr)
  - Implementar funciones para recuperación de contraseñas con tokens
  - Crear funciones para 2FA con TOTP
  - Testing completo de funciones de seguridad

  - _Requisitos: 3.1, 3.5, 9.1, 9.4_

- [ ] 4. Crear datos iniciales del sistema
  - Insertar ciudades y deportes básicos para el sistema
  - Crear usuario super_admin inicial con credenciales seguras
  - Implementar datos de prueba para validación
  - Validar integridad referencial de todos los datos
  - _Requisitos: 1.4, 8.1_


### Fase 2: Servicios Core del Backend

- [ ] 5. Desarrollar servicio de autenticación completo
  - Crear endpoints de registro con validación de datos
  - Implementar endpoints de login/logout con JWT personalizado
  - Crear sistema de recuperación de contraseñas
  - Implementar endpoints para 2FA (setup, verify, disable)
  - Crear middleware de autenticación JWT
  - Implementar middleware de autorización RBAC
  - _Requisitos: 3.1, 3.5, 8.1_

- [ ] 6. Desarrollar servicio de gestión de usuarios y roles
  - Crear endpoints CRUD para user_profiles (solo para admins)
  - Implementar sistema de asignación de roles granulares
  - Crear endpoints para gestión de user_roles_by_city_sport
  - Implementar sistema de permisos de vista (user_view_permissions)
  - Crear endpoints para gestión de estado de cuentas
  - _Requisitos: 8.1, 8.2, 8.3, 8.4_

- [ ] 7. Desarrollar servicio de gestión de ciudades y deportes
  - Crear endpoints CRUD para entidades cities y sports
  - Implementar validaciones de negocio
  - Aplicar autorización por roles (solo super_admin puede crear ciudades)
  - Crear endpoints para consulta pública de ciudades/deportes
  - _Requisitos: 1.1, 1.4_

- [ ] 8. Implementar servicio completo de gestión de torneos
  - Crear endpoints para CRUD de torneos con validaciones
  - Implementar lógica de aprobación por administradores
  - Desarrollar sistema de inscripción de equipos a torneos
  - Crear endpoints para consulta pública de torneos
  - Implementar filtrado automático por ciudad/deporte según usuario
  - _Requisitos: 2.1, 2.2, 2.3, 2.4_

- [ ] 9. Desarrollar servicio completo de gestión de equipos y jugadores
  - Implementar operaciones CRUD completas para equipos con validación de propietarios
  - Crear gestión avanzada de jugadores con soporte multi-equipo a través de diferentes deportes
  - Desarrollar lógica de restricción para evitar que el mismo jugador esté en varios equipos del mismo deporte/torneo
  - Validación de elegibilidad de jugadores y detección de conflictos
  - Crear sistema de búsqueda y asociación de jugadores
  - Añadir seguimiento del historial del jugador a través de equipos y deportes
  - _Requisitos: 4.1, 4.2, 4.3, 4.4_

- [ ] 10. Crear servicio de gestión de partidos
  - Implementar CRUD para partidos con programación
  - Desarrollar sistema de asignación de árbitros
  - Crear endpoints para consulta pública de horarios y resultados
  - Implementar validaciones de fechas y conflictos
  - _Requisitos: 2.1, 2.4_

### Fase 3: Sistema de Eventos y Estadísticas en Tiempo Real

- [ ] 11. Implementar sistema de eventos de partido en tiempo real
  - Crear endpoints para registro de eventos por árbitros
  - Desarrollar lógica para diferentes tipos de eventos (gol, tarjeta, etc.)
  - Implementar validaciones y correcciones de eventos
  - Integrar actualizaciones en tiempo real
  - _Requisitos: 7.1, 7.2, 7.3_

- [ ] 12. Desarrollar motor de cálculo de estadísticas
  - Implementar cálculo automático de estadísticas de jugadores
  - Crear sistema de estadísticas de equipos y clasificaciones
  - Desarrollar triggers para actualización automática

  - Optimizar consultas para estadísticas complejas
  - _Requisitos: 7.1, 7.2, 7.3, 7.4_

- [ ] 13. Implementar funciones de estadísticas y cálculos
  - Crear función recalculate_player_statistics para estadísticas individuales
  - Implementar función recalculate_team_statistics para métricas de equipo
  - Crear función update_tournament_standings para tablas de posiciones
  - Implementar triggers automáticos para actualización en tiempo real
  - Testing de precisión de cálculos con datos de prueba
  - _Requisitos: 7.1, 7.2, 7.3_

- [ ] 14. Configurar sistema de caché con Redis
  - Instalar y configurar Redis en el entorno de desarrollo
  - Implementar patrones de caché para estadísticas frecuentes
  - Crear sistema de invalidación de caché inteligente
  - Optimizar consultas de clasificaciones y goleadores

  - _Requisitos: 6.1, 6.2_

### Fase 4: Optimización de Rendimiento

- [ ] 15. Implementar índices optimizados de rendimiento
  - Crear índices primarios para consultas frecuentes de usuarios
  - Implementar índices para consultas de torneos y equipos
  - Crear índices optimizados para búsquedas de jugadores

  - Implementar índices para consultas de estadísticas y rankings
  - Crear índices compuestos para consultas multi-tabla
  - Implementar índices de texto completo para búsquedas avanzadas
  - _Requisitos: 6.1, 6.2, 6.3_

- [ ] 16. Optimizar rendimiento de consultas críticas
  - Analizar y optimizar consultas de estadísticas en tiempo real
  - Implementar optimizaciones para consultas de RLS
  - Crear vistas materializadas para consultas pesadas si es necesario
  - Testing de rendimiento con volúmenes de datos realistas
  - _Requisitos: 6.1, 6.2, 6.3_

### Fase 5: Desarrollo del Frontend - Panel de Administración

- [ ] 17. Crear sistema de autenticación frontend completo
  - Implementar páginas de inicio de sesión con validación
  - Desarrollar gestión de sesiones con JWT
  - Crear componentes 2FA para superadministradores y administradores
  - Implementar redirección basada en roles y manejo de estado de cuenta
  - Añadir seguimiento de intentos de inicio de sesión con feedback de usuario
  - Crear flujo de recuperación de contraseñas con verificación por correo
  - Implementar mensajes de estado de cuenta (pago pendiente, suspendido, etc.)
  - _Requisitos: 3.1, 3.5, 8.1_

- [ ] 18. Desarrollar sistema avanzado de dashboards basado en roles
  - Crear interfaces específicas para cada función (superadministrador, administrador de ciudad, propietario, etc.)
  - Implementar navegación contextual basada en permisos granulares
  - Desarrollar sistema dinámico de visualización controlado por el superadministrador
  - Crear widgets y paneles de métricas específicos para cada función
  - Implementar interfaces de registro de usuarios para cada nivel de función
  - Añadir herramientas de gestión de cuentas para el superadministrador
  - _Requisitos: 8.1, 8.2, 8.3, 8.4_

- [ ] 19. Implementar sistema jerárquico de registro de usuarios
  - Crear interfaz Super Admin para registro de Administradores de Ciudad
  - Desarrollar interfaz City Admin para registrar Propietarios y Árbitros
  - Implementar interfaz de Propietario para registrar Jugadores y Entrenadores
  - Crear sistema automatizado de generación de credenciales
  - Implementar notificación por correo electrónico para nuevos usuarios
  - _Requisitos: 8.1, 8.2, 8.3_

- [ ] 20. Implementar gestión de torneos en frontend
  - Crear formularios para creación y edición de torneos
  - Desarrollar interfaz de aprobación para administradores
  - Implementar sistema de inscripción de equipos
  - Crear vistas de programación y gestión de partidos
  - _Requisitos: 2.1, 2.2, 2.3_

- [ ] 21. Desarrollar gestión de equipos y jugadores
  - Crear interfaces para CRUD de equipos
  - Implementar sistema de gestión de jugadores con búsqueda
  - Desarrollar funcionalidad para asociar jugadores a múltiples equipos
  - Crear vistas de historial y estadísticas de jugadores
  - Implementar validación de elegibilidad en tiempo real
  - _Requisitos: 4.1, 4.2, 4.3, 4.4_

- [ ] 22. Crear interfaz de arbitraje en tiempo real
  - Desarrollar panel de control para árbitros durante partidos
  - Implementar botones rápidos para eventos comunes
  - Crear sistema de corrección y validación de eventos
  - Integrar actualizaciones en tiempo real
  - _Requisitos: 7.1, 7.2_

### Fase 6: Frontend Público y Aplicación Móvil

- [ ] 23. Desarrollar sitio web público
  - Crear páginas de inicio con torneos destacados
  - Implementar vistas de resultados y clasificaciones en tiempo real
  - Desarrollar perfiles públicos de equipos y jugadores
  - Crear sistema de búsqueda y filtros
  - _Requisitos: 2.1, 4.1, 7.1_

- [ ] 24. Implementar actualizaciones en tiempo real en frontend público
  - Integrar sistema de tiempo real para marcadores en vivo
  - Desarrollar notificaciones de eventos de partido
  - Crear sistema de suscripción a equipos favoritos
  - Implementar actualizaciones automáticas de estadísticas
  - _Requisitos: 7.1, 7.2, 7.3_

- [ ] 25. Optimizar rendimiento del frontend
  - Implementar code splitting y lazy loading
  - Configurar virtualización para listas largas
  - Aplicar técnicas de prevención de re-renders innecesarios
  - Configurar CDN para activos estáticos
  - _Requisitos: 6.1, 6.2_

### Fase 7: Testing y Validación Completa

- [ ] 26. Implementar suite de testing completa
  - Escribir tests unitarios para lógica de negocio crítica
  - Crear tests de integración para APIs principales
  - Desarrollar tests end-to-end para flujos críticos
  - Implementar tests de rendimiento automatizados
  - Testing de políticas RLS con diferentes roles de usuario
  - _Requisitos: Todos los requisitos de calidad_

- [ ] 27. Testing de seguridad y casos edge
  - Validar aislamiento de datos entre ciudades y deportes
  - Testing de intentos de acceso no autorizado
  - Verificar funcionamiento de auditoría y logging
  - Testing de casos límite y manejo de errores
  - Validar funciones de autenticación y 2FA
  - _Requisitos: 5.1, 5.4, 9.1, 9.4_

- [ ] 28. Realizar testing de usuario y refinamiento
  - Conducir pruebas de usabilidad con usuarios reales
  - Recopilar feedback de administradores de torneos locales
  - Refinar interfaces basado en feedback de usuarios
  - Optimizar flujos de trabajo críticos
  - _Requisitos: 8.1, 8.2_

### Fase 8: Producción y Monitoreo

- [ ] 29. Implementar sistema de monitoreo y logging
  - Configurar logging estructurado en backend Go
  - Implementar métricas de rendimiento y health checks
  - Crear dashboards de monitoreo operacional
  - Configurar alertas para errores críticos
  - Implementar auditoría completa de acciones críticas
  - _Requisitos: 9.1, 9.2, 9.3, 9.4_

- [ ] 30. Implementar medidas de seguridad avanzadas
  - Configurar rate limiting por usuario y endpoint
  - Implementar validación exhaustiva de inputs
  - Crear sistema de auditoría de acciones críticas
  - Realizar testing de seguridad automatizado
  - Implementar detección de patrones sospechosos
  - _Requisitos: 9.1, 9.2, 9.3, 9.4_

- [ ] 31. Configurar entorno de producción
  - Configurar despliegue con CI/CD
  - Implementar estrategia de backup automatizado
  - Configurar balanceador de carga y alta disponibilidad
  - Realizar pruebas de carga para múltiples usuarios concurrentes
  - _Requisitos: 10.1, 10.2, 10.3, 10.4_

- [ ] 32. Preparación para escalabilidad futura
  - Documentar arquitectura para nuevas ciudades
  - Crear guías de onboarding para nuevos administradores
  - Implementar métricas de uso y engagement
  - Preparar infraestructura para monetización futura
  - _Requisitos: 10.1, 10.2, 10.3, 10.4_

## Notas de Implementación

### Prioridades por Fase

**Fase 1 (Crítica)**: Base de datos completa con autenticación segura
**Fase 2 (Core)**: APIs fundamentales funcionando correctamente
**Fase 3 (Diferenciador)**: Funcionalidades en tiempo real que destacan la plataforma
**Fase 4 (Rendimiento)**: Optimización para escala
**Fase 5-6 (UX)**: Interfaces de usuario completas
**Fase 7-8 (Calidad)**: Testing, seguridad y producción

### Dependencias Críticas

1. **Tareas 1-4 deben completarse antes que cualquier desarrollo de servicios**
2. **Tareas 5-6 son prerequisitos para cualquier funcionalidad de frontend**
3. **Tareas 11-13 son críticas para las funcionalidades en tiempo real**
4. **Tarea 23 depende de que los servicios públicos estén completos**

### Estimación de Tiempo

- **Fase 1**: 2-3 semanas (base crítica con autenticación completa)
- **Fase 2**: 4-5 semanas (servicios core del backend)
- **Fase 3**: 3-4 semanas (tiempo real y estadísticas)
- **Fase 4**: 2-3 semanas (optimización de rendimiento)
- **Fase 5**: 4-5 semanas (frontend administrativo completo)
- **Fase 6**: 3-4 semanas (frontend público)
- **Fase 7**: 2-3 semanas (testing exhaustivo)
- **Fase 8**: 2-3 semanas (producción y monitoreo)

**Total estimado**: 22-30 semanas para plataforma completa

### Criterios de Éxito por Fase

**Fase 1**: Autenticación segura funcionando, RLS implementado
**Fase 2**: APIs core completas, sistema de roles granulares funcionando
**Fase 3**: Estadísticas en tiempo real, eventos de partidos funcionando
**Fase 4**: Rendimiento optimizado, consultas rápidas
**Fase 5**: Administradores pueden gestionar todo el sistema end-to-end
**Fase 6**: Público puede seguir torneos en tiempo real
**Fase 7**: Sistema completamente testado y seguro
**Fase 8**: Sistema en producción, monitoreado y escalable