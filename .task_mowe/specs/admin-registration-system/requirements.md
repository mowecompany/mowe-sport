# Especificación de Requisitos - Sistema de Registro de Administradores

## Introducción

El sistema de registro de administradores permite a los Super Administradores crear nuevas cuentas de administradores de ciudad con todos los campos requeridos según el esquema `user_profiles` y el sistema de roles granulares implementado. Este sistema debe integrar completamente con la autenticación JWT, políticas RLS y el sistema de roles por ciudad/deporte.

**Estado Actual**: Vista frontend básica implementada con campos limitados. Backend con modelos completos pero sin endpoints de registro.

**Estado Objetivo**: Sistema completo de registro de administradores con validación, seguridad, asignación de roles granulares y integración con el sistema de autenticación existente.

## Requisitos

### Requisito 1: Formulario Completo de Registro de Administrador

**User Story:** Como Super Administrador, quiero un formulario completo para registrar nuevos administradores de ciudad, para que pueda crear cuentas con toda la información necesaria según el esquema de base de datos.

#### Acceptance Criteria

1. WHEN abra el modal de registro THEN el sistema SHALL mostrar todos los campos requeridos de user_profiles
2. WHEN complete los campos obligatorios THEN el sistema SHALL validar formato de email, teléfono e identificación
3. IF faltan campos requeridos THEN el sistema SHALL mostrar mensajes de error específicos
4. WHEN seleccione ciudad y deporte THEN el sistema SHALL cargar datos desde las tablas cities y sports
5. WHEN envíe el formulario THEN el sistema SHALL generar password temporal y enviar por email

### Requisito 2: Endpoint de Registro de Administrador con Validación

**User Story:** Como sistema backend, quiero un endpoint seguro para crear administradores, para que solo Super Administradores puedan registrar nuevos administradores de ciudad con validación completa.

#### Acceptance Criteria

1. WHEN reciba request de registro THEN el sistema SHALL validar que el usuario sea super_admin
2. WHEN valide los datos THEN el sistema SHALL verificar email único y formato de campos
3. IF el email ya existe THEN el sistema SHALL retornar error específico
4. WHEN cree el usuario THEN el sistema SHALL generar password_hash seguro
5. WHEN complete el registro THEN el sistema SHALL crear entrada en user_roles_by_city_sport

### Requisito 3: Sistema de Generación de Contraseñas Temporales

**User Story:** Como administrador recién registrado, quiero recibir una contraseña temporal segura, para que pueda acceder al sistema y cambiar mi contraseña en el primer login.

#### Acceptance Criteria

1. WHEN se registre un admin THEN el sistema SHALL generar contraseña temporal de 12 caracteres
2. WHEN genere la contraseña THEN el sistema SHALL incluir mayúsculas, minúsculas, números y símbolos
3. IF se envíe por email THEN el sistema SHALL usar template profesional con instrucciones
4. WHEN el admin haga login THEN el sistema SHALL forzar cambio de contraseña temporal
5. IF la contraseña temporal expira THEN el sistema SHALL permitir regeneración

### Requisito 4: Asignación Automática de Roles Granulares

**User Story:** Como sistema, quiero asignar automáticamente roles granulares por ciudad/deporte, para que cada administrador tenga permisos específicos según su jurisdicción.

#### Acceptance Criteria

1. WHEN se registre un admin THEN el sistema SHALL crear entrada en user_roles_by_city_sport
2. WHEN asigne el rol THEN el sistema SHALL usar city_admin como role_name
3. IF se especifique ciudad y deporte THEN el sistema SHALL asociar correctamente los IDs
4. WHEN complete la asignación THEN el sistema SHALL registrar assigned_by_user_id del super_admin
5. IF hay error en asignación THEN el sistema SHALL hacer rollback completo del registro

### Requisito 5: Validación de Datos y Seguridad

**User Story:** Como sistema de seguridad, quiero validar exhaustivamente todos los datos de entrada, para prevenir inyecciones y mantener integridad de datos.

#### Acceptance Criteria

1. WHEN valide email THEN el sistema SHALL verificar formato RFC 5322 y dominio válido
2. WHEN valide teléfono THEN el sistema SHALL aceptar formatos internacionales estándar
3. IF valide identificación THEN el sistema SHALL verificar formato según país/región
4. WHEN procese datos THEN el sistema SHALL sanitizar inputs contra XSS e inyección SQL
5. IF detecte intento malicioso THEN el sistema SHALL logear y bloquear IP temporalmente

### Requisito 6: Integración con Sistema de Autenticación Existente

**User Story:** Como desarrollador, quiero que el registro se integre completamente con JWT y RLS, para mantener consistencia con el sistema de autenticación existente.

#### Acceptance Criteria

1. WHEN autentique request THEN el sistema SHALL usar middleware JWT existente
2. WHEN valide permisos THEN el sistema SHALL verificar rol super_admin en token
3. IF aplique RLS THEN el sistema SHALL usar función current_user_id() existente
4. WHEN registre actividad THEN el sistema SHALL usar sistema de auditoría implementado
5. IF hay error de autenticación THEN el sistema SHALL usar manejo de errores estándar

### Requisito 7: Notificación por Email y Onboarding

**User Story:** Como administrador recién registrado, quiero recibir información completa de bienvenida, para entender mis responsabilidades y cómo usar el sistema.

#### Acceptance Criteria

1. WHEN se complete el registro THEN el sistema SHALL enviar email de bienvenida
2. WHEN envíe credenciales THEN el sistema SHALL incluir URL de login y instrucciones
3. IF incluya documentación THEN el sistema SHALL adjuntar guía de administrador
4. WHEN el admin acceda THEN el sistema SHALL mostrar tour de onboarding
5. IF requiera soporte THEN el sistema SHALL proveer contactos de ayuda

### Requisito 8: Gestión de Estados de Cuenta

**User Story:** Como Super Administrador, quiero controlar el estado de las cuentas de administradores, para gestionar accesos y pagos según las necesidades del negocio.

#### Acceptance Criteria

1. WHEN registre admin THEN el sistema SHALL establecer account_status como 'active' por defecto
2. WHEN cambie estado THEN el sistema SHALL permitir active, suspended, payment_pending, disabled
3. IF suspenda cuenta THEN el sistema SHALL bloquear acceso inmediatamente
4. WHEN reactive cuenta THEN el sistema SHALL restaurar permisos automáticamente
5. IF esté en payment_pending THEN el sistema SHALL mostrar mensaje de pago requerido

### Requisito 9: Validación de Unicidad y Conflictos

**User Story:** Como sistema de integridad, quiero prevenir duplicados y conflictos, para mantener consistencia en los datos de administradores.

#### Acceptance Criteria

1. WHEN valide email THEN el sistema SHALL verificar unicidad en user_profiles
2. WHEN valide identificación THEN el sistema SHALL verificar no duplicados si se proporciona
3. IF detecte conflicto THEN el sistema SHALL mostrar mensaje específico del campo
4. WHEN asigne ciudad/deporte THEN el sistema SHALL verificar que no exista admin duplicado
5. IF hay múltiples admins THEN el sistema SHALL permitir solo si están en deportes diferentes

### Requisito 10: Logging y Auditoría de Registros

**User Story:** Como auditor del sistema, quiero un registro completo de todos los registros de administradores, para mantener trazabilidad y seguridad.

#### Acceptance Criteria

1. WHEN se intente registro THEN el sistema SHALL logear intento con IP y timestamp
2. WHEN se complete registro THEN el sistema SHALL registrar todos los datos creados
3. IF falle el registro THEN el sistema SHALL logear error específico y contexto
4. WHEN se asignen roles THEN el sistema SHALL auditar cambios en user_roles_by_city_sport
5. IF se detecte actividad sospechosa THEN el sistema SHALL alertar automáticamente