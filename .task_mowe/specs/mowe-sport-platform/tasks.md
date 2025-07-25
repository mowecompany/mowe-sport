# Plan de Implementación - Plataforma Mowe Sport

## Estado Actual
✅ Conexión con Supabase establecida  
✅ Sistema de autenticación básico (registro/login) implementado  
✅ Estructura base del proyecto Go con Echo configurada  

## Tareas de Implementación

### Fase 1: Configuración de Base de Datos y Seguridad

- [x] 1. Implementar esquema completo de base de datos en Supabase




  - Crear todas las tablas definidas en el diseño (cities, sports, users, tournaments, teams, players, etc.)
  - Establecer relaciones de claves foráneas correctamente
  - Configurar tipos de datos UUID y JSONB según especificación
  - _Requisitos: 1.1, 3.1, 3.2_

- [ ] 2. Configurar políticas de Row Level Security (RLS)
  - Habilitar RLS en todas las tablas sensibles
  - Implementar políticas para aislamiento multi-tenencia por ciudad/deporte
  - Crear políticas específicas por rol (admin, propietario, árbitro, etc.)
  - Probar políticas con diferentes usuarios y roles
  - _Requisitos: 1.1, 1.2, 9.2, 9.3_

- [ ] 3. Implantar un sistema mejorado de gestión de usuarios con roles granulares
  - Crear la tabla user_profiles con los campos account_status y login security
  - Implementar la tabla user_roles_by_city_sport para la asignación granular de roles
  - Creación de la tabla user_view_permissions para el control de acceso a nivel de vista
  - Desarrollar una lógica de asignación de funciones con comprobaciones de autorización adecuadas
  - _Requisitos: 5.1, 5.2, 5.3, 11.1, 11.2, 11.3_

- [ ] 3.1. Implementar funciones avanzadas de seguridad de inicio de sesión
  - Crear un mecanismo de seguimiento de intentos de inicio de sesión y bloqueo de cuentas
  - Implementar bloqueo progresivo (15min -> 24hr) para intentos fallidos
  - Añadir gestión de sesiones con limitación a un único dispositivo
  - Crear recuperación de contraseñas con tokens de caducidad de 10 minutos
  - _Requirements: 12.1, 12.2, 12.3, 12.5_

- [ ] 3.2. Desarrollar un sistema de gestión del estado de las cuentas
  - Implantar la suspensión de cuentas por problemas de pago
  - Crear estado pendiente de pago con acceso restringido
  - Desarrollar vistas dinámicas que se oculten o muestren en función del estado de la cuenta
  - Reactivación automática de la cuenta tras la confirmación del pago
  - _Requirements: 11.1, 11.2_

- [ ] 4. Implementar autenticación de doble factor (2FA)
  - Configurar 2FA en Supabase Auth para roles administrativos
  - Crear endpoints para inscripción y verificación 2FA
  - Implementar middleware para requerir 2FA en operaciones sensibles
  - _Requisitos: 9.1, 9.4_

### Fase 2: Servicios Core del Backend

- [ ] 5. Desarrollar servicio de gestión de ciudades y deportes
  - Crear endpoints CRUD para entidades cities y sports
  - Implementar validaciones de negocio
  - Aplicar autorización por roles (solo super_admin puede crear ciudades)
  - _Requisitos: 1.1, 5.1_

- [ ] 6. Implementar servicio completo de gestión de torneos
  - Crear endpoints para CRUD de torneos con validaciones
  - Implementar lógica de aprobación por administradores
  - Desarrollar sistema de inscripción de equipos a torneos
  - Crear endpoints para consulta pública de torneos
  - _Requisitos: 2.1, 2.2, 2.3, 2.4_

- [ ] 7. Desarrollar un servicio completo de gestión de equipos y jugadores
  - Implementar operaciones CRUD completas para equipos con validación de propietarios
  - Crear gestión avanzada de jugadores con soporte multi-equipo a través de diferentes deportes
  - Desarrollar lógica de restricción para evitar que el mismo jugador esté en varios equipos del mismo deporte/categoría/torneo ya reguistrado.
  - Validación de elegibilidad de jugadores y detección de conflictos
  - Crear un sistema de búsqueda y asociación de jugadores
  - Añadir el seguimiento de la historia del jugador a través de equipos y deportes
  - _Requirements: 3.1, 3.2, 3.3, 3.4, 14.1, 14.2, 14.3, 14.4, 14.5_

- [ ] 8. Crear servicio de gestión de partidos
  - Implementar CRUD para partidos con programación
  - Desarrollar sistema de asignación de árbitros
  - Crear endpoints para consulta pública de horarios y resultados
  - Implementar validaciones de fechas y conflictos
  - _Requisitos: 6.1, 6.2_

### Fase 3: Sistema de Eventos y Estadísticas en Tiempo Real

- [ ] 9. Implementar sistema de eventos de partido en tiempo real
  - Crear endpoints para registro de eventos por árbitros
  - Desarrollar lógica para diferentes tipos de eventos (gol, tarjeta, etc.)
  - Implementar validaciones y correcciones de eventos
  - Integrar con Supabase Realtime para actualizaciones instantáneas
  - _Requisitos: 6.3, 6.4, 4.1, 4.2_

- [ ] 10. Desarrollar motor de cálculo de estadísticas
  - Implementar cálculo automático de estadísticas de jugadores
  - Crear sistema de estadísticas de equipos y clasificaciones
  - Desarrollar triggers o jobs para actualización automática
  - Optimizar consultas para estadísticas complejas
  - _Requisitos: 6.5, 4.3_

- [ ] 11. Configurar sistema de caché con Redis
  - Instalar y configurar Redis en el entorno de desarrollo
  - Implementar patrones de caché para estadísticas frecuentes
  - Crear sistema de invalidación de caché inteligente
  - Optimizar consultas de clasificaciones y goleadores
  - _Requisitos: 8.4, 8.1_

### Fase 4: Desarrollo del Frontend - Panel de Administración

- [ ] 12. Crear un sistema de autenticación frontend completo
  - Implementar páginas de inicio de sesión con integración Supabase Auth y Google OAuth
  - Desarrollar la gestión de sesiones con JWT y cierre de sesión automático del dispositivo
  - Crear componentes 2FA para superadministradores y administradores
  - Implementar redirección basada en roles y manejo de estado de cuenta
  - Añadir seguimiento de intentos de inicio de sesión con feedback de usuario para bloqueos
  - Creación de un flujo de recuperación de contraseñas con verificación por correo electrónico
  - Implementar mensajes de estado de cuenta (pago pendiente, suspendido, etc.)
  - _Requirements: 5.4, 9.1, 12.1, 12.2, 12.3, 12.4, 12.5, 13.4_

- [ ] 13. Desarrollar un sistema avanzado de cuadros de mando basado en roles
  - Crear interfaces específicas para cada función (superadministrador, administrador de la ciudad, propietario, etc.)
  - Implementar navegación contextual basada en permisos granulares
  - Desarrollar un sistema dinámico de visualización y ocultación controlado por el superadministrador.
  - Creación de widgets y paneles de métricas específicos para cada función
  - Implementación de interfaces de registro de usuarios para cada nivel de función
  - Añadir herramientas de gestión de cuentas para el superadministrador (activar/desactivar cuentas)
  - Creación de herramientas de supervisión del estado de los pagos y de suspensión de cuentas
  - _Requirements: 5.1, 5.2, 5.3, 5.5, 11.3, 11.4, 13.1, 13.2, 13.3_

- [ ] 13.1. Implantar un sistema jerárquico de registro de usuarios
  - Crear una interfaz Super Admin para el registro de Administradores de la Ciudad
  - Desarrollar la interfaz City Admin para registrar Propietarios y Árbitros
  - Implementar interfaz de Propietario para registrar Jugadores y Entrenadores
  - Añadir auto-registro del cliente con la integración de Google OAuth
  - Creación de un sistema automatizado de generación de credenciales y notificación por correo electrónico
  - _Requirements: 13.1, 13.2, 13.3, 13.4, 13.5_

- [ ] 14. Implementar gestión de torneos en frontend
  - Crear formularios para creación y edición de torneos
  - Desarrollar interfaz de aprobación para administradores
  - Implementar sistema de inscripción de equipos
  - Crear vistas de programación y gestión de partidos
  - _Requisitos: 2.1, 2.2, 2.3_

- [ ] 15. Desarrollar gestión de equipos y jugadores
  - Crear interfaces para CRUD de equipos
  - Implementar sistema de gestión de jugadores con búsqueda
  - Desarrollar funcionalidad para asociar jugadores a múltiples equipos
  - Crear vistas de historial y estadísticas de jugadores
  - _Requisitos: 3.1, 3.2, 3.3, 3.4_

- [ ] 16. Crear interfaz de arbitraje en tiempo real
  - Desarrollar panel de control para árbitros durante partidos
  - Implementar botones rápidos para eventos comunes
  - Crear sistema de corrección y validación de eventos
  - Integrar actualizaciones en tiempo real con Supabase Realtime
  - _Requisitos: 6.3, 6.4, 4.1, 4.2_

### Fase 5: Frontend Público y Aplicación Móvil

- [ ] 17. Desarrollar sitio web público
  - Crear páginas de inicio con torneos destacados
  - Implementar vistas de resultados y clasificaciones en tiempo real
  - Desarrollar perfiles públicos de equipos y jugadores
  - Crear sistema de búsqueda y filtros
  - _Requisitos: 7.1, 7.2, 7.4_

- [ ] 18. Implementar actualizaciones en tiempo real en frontend público
  - Integrar Supabase Realtime para marcadores en vivo
  - Desarrollar notificaciones de eventos de partido
  - Crear sistema de suscripción a equipos favoritos
  - Implementar actualizaciones automáticas de estadísticas
  - _Requisitos: 4.1, 4.2, 4.3, 7.5_

- [ ] 19. Optimizar rendimiento del frontend
  - Implementar code splitting y lazy loading
  - Configurar virtualización para listas largas
  - Aplicar técnicas de prevención de re-renders innecesarios
  - Configurar CDN para activos estáticos
  - _Requisitos: 8.1, 8.2_

- [ ] 20. Desarrollar aplicación móvil base (Kotlin/Compose)
  - Configurar proyecto Android con Jetpack Compose
  - Implementar autenticación móvil con Supabase
  - Crear navegación principal y estructura de pantallas
  - Desarrollar componentes base reutilizables
  - _Requisitos: 7.1, 7.3_

- [ ] 21. Implementar funcionalidades core en app móvil
  - Desarrollar vistas de resultados y clasificaciones
  - Crear sistema de notificaciones push
  - Implementar seguimiento de equipos favoritos
  - Integrar actualizaciones en tiempo real
  - _Requisitos: 7.2, 7.4, 7.5, 4.1_

### Fase 6: Optimización y Producción

- [ ] 22. Implementar sistema de monitoreo y logging
  - Configurar logging estructurado en backend Go
  - Implementar métricas de rendimiento y health checks
  - Crear dashboards de monitoreo operacional
  - Configurar alertas para errores críticos
  - _Requisitos: 8.5_

- [ ] 23. Realizar optimización de base de datos
  - Crear índices optimizados para consultas frecuentes
  - Implementar análisis de rendimiento con EXPLAIN
  - Optimizar consultas de estadísticas complejas
  - Configurar connection pooling adecuado
  - _Requisitos: 8.1, 8.3_

- [ ] 24. Implementar medidas de seguridad avanzadas
  - Configurar rate limiting por usuario y endpoint
  - Implementar validación exhaustiva de inputs
  - Crear sistema de auditoría de acciones críticas
  - Realizar testing de seguridad automatizado
  - _Requisitos: 9.1, 9.2, 9.3, 9.4, 9.5_

- [ ] 25. Configurar entorno de producción
  - Configurar despliegue con CI/CD
  - Implementar estrategia de backup automatizado
  - Configurar balanceador de carga y alta disponibilidad
  - Realizar pruebas de carga para 100k usuarios concurrentes
  - _Requisitos: 8.5, 8.3_

### Fase 7: Testing y Calidad

- [ ] 26. Implementar suite de testing completa
  - Escribir tests unitarios para lógica de negocio crítica
  - Crear tests de integración para APIs principales
  - Desarrollar tests end-to-end para flujos críticos
  - Implementar tests de rendimiento automatizados
  - _Requisitos: Todos los requisitos de calidad_

- [ ] 27. Realizar testing de usuario y refinamiento
  - Conducir pruebas de usabilidad con usuarios reales
  - Recopilar feedback de administradores de torneos locales
  - Refinar interfaces basado en feedback de usuarios
  - Optimizar flujos de trabajo críticos
  - _Requisitos: 5.1, 7.1, 7.2_

### Fase 8: Gestión avanzada de usuarios y funciones de seguridad

- [ ] 28. Implementar el panel de control Super Admin para la gestión de la plataforma
  - Crear una interfaz completa de gestión de cuentas de usuario
  - Desarrollar el control del estado de la cuenta (activar/desactivar/suspender)
  - Implementar el control del estado de los pagos y las suspensiones automáticas
  - Crear un sistema de gestión de permisos de visualización para roles y usuarios individuales
  - Añadir operaciones masivas para la gestión de usuarios
  - Implementar el registro de auditoría para todas las acciones administrativas
  - _Requirements: 11.1, 11.2, 11.3, 11.4, 11.5_

- [ ] 29. Desarrollar funciones avanzadas de seguridad y supervisión
  - Implantar un sistema completo de registro de auditorías
  - Crear un sistema de supervisión y alerta de eventos de seguridad
  - Desarrollar restricciones de acceso y supervisión basadas en IP
  - Añadir huellas dactilares de dispositivos para mejorar la seguridad
  - Implantación de detección y respuesta automatizadas ante amenazas
  - Creación de un panel de seguridad para administradores
  - _Requirements: 9.3, 12.4, 12.5_

- [ ] 30. Crear un sistema de elegibilidad de jugadores y gestión de conflictos
  - Implementar búsqueda avanzada de jugadores y detección de duplicados
  - Crear un sistema de resolución de conflictos para la participación de varios equipos
  - Desarrollar un motor de reglas de validación de elegibilidad
  - Añadir notificaciones automáticas para conflictos de registro
  - Implementar un sistema de transferencia de jugadores entre equipos
  - Creación de un seguimiento exhaustivo del historial y las estadísticas de los jugadores
  - _Requirements: 14.1, 14.2, 14.3, 14.4, 14.5_

### Fase 9: Preparación para Monetización (Futuro)

- [ ] 31. Diseñar arquitectura de suscripciones
  - Planificar niveles de suscripción (Gratuito, Básico, Premium)
  - Diseñar sistema de límites y características por nivel
  - Investigar integración con pasarelas de pago
  - Crear estructura de base de datos para billing
  - Integrar con sistema de suspensión de cuentas por falta de pago
  - _Requisitos: 10.1, 10.3, 11.1_

- [ ] 32. Preparar infraestructura para anuncios
  - Diseñar espacios publicitarios en interfaces
  - Planificar sistema de targeting por ubicación/deporte
  - Investigar redes publicitarias apropiadas
  - Crear métricas de engagement para anunciantes
  - _Requisitos: 10.2, 10.4_

## Notas de Implementación

### Prioridades por Rol de Desarrollo

**Tu enfoque principal (Fullstack Lead):**
- Tareas 9-11: Sistema de tiempo real y estadísticas (core técnico complejo)
- Tareas 16, 18: Interfaces de tiempo real (requiere expertise en React + WebSockets)
- Tareas 22-25: Optimización y producción (requiere experiencia fullstack)
- Tareas 28-30: Funcionalidades avanzadas de administración y seguridad

**Colaboración (Backend/DB specialist):**
- Tareas 1-2: Esquema de DB y RLS avanzado (fortaleza en bases de datos)
- Tareas 3-3.2: Sistema de usuarios y seguridad avanzada (lógica de base de datos compleja)
- Tarea 6: Lógica de torneos (puede liderar la lógica de negocio)
- Tarea 7: Sistema avanzado de jugadores multi-equipo (requiere lógica de DB compleja)
- Tarea 23: Optimización de DB (experiencia en SQL y rendimiento)
- Tareas 13-13.1: Puede colaborar en lógica de registro jerárquico

### Dependencias Críticas

1. **Tareas 1-4 deben completarse antes que cualquier desarrollo de servicios**
2. **Tareas 5-8 son prerequisitos para el frontend administrativo**
3. **Tareas 9-11 son críticas para las funcionalidades en tiempo real**
4. **Tarea 17 depende de que los servicios públicos estén completos**

### Estimación de Tiempo

- **Fase 1-2**: 5-7 semanas (base sólida crítica con seguridad avanzada)
- **Fase 3**: 4-5 semanas (complejidad de tiempo real + gestión avanzada de usuarios)
- **Fase 4**: 5-6 semanas (múltiples interfaces por rol + sistema de registro jerárquico)
- **Fase 5**: 4-5 semanas (frontend público + móvil base + funcionalidades avanzadas)
- **Fase 6-7**: 3-4 semanas (optimización y testing exhaustivo)
- **Fase 8**: 3-4 semanas (funcionalidades avanzadas de administración)

**Total estimado**: 24-31 semanas para MVP completo con funcionalidades avanzadas

### Criterios de Éxito por Fase

**Fase 1-2**: Base de datos completa, APIs core funcionando, autenticación robusta
**Fase 3**: Partidos en tiempo real funcionando, estadísticas actualizándose automáticamente  
**Fase 4**: Administradores pueden gestionar torneos completos end-to-end
**Fase 5**: Público puede seguir torneos en tiempo real desde web y móvil
**Fase 6-7**: Sistema soporta carga objetivo, métricas de rendimiento cumplidas