# **📌 Requerimientos Funcionales - Plataforma de Mowe Sport ⚽**


### **1. Introducción**

Este documento integra los requerimientos funcionales y no funcionales para el desarrollo de una plataforma deportiva que gestionará equipos, jugadores, torneos, estadísticas y accesos.

- **Roles definidos**:

- Super Admin

- Administrador

- Propietario

- Entrenador

- Árbitro

- Jugador

- Cliente (Usuario Final)

- **Alcance inicial**: Gestión de accesos al sistema. Posteriormente, se expandirá a otros módulos (equipos, torneos, estadísticas, suscripciones).

---

### **2. Requerimientos Funcionales**

### **2.1 Gestión de Usuarios y Roles**

### **2.1.1 Acceso al Sistema para Super Administrador**

- Los **Super Administradores** serán registrados manualmente por los desarrolladores o mediante una configuración inicial del sistema.

- Datos requeridos para el registro:

- Correo electrónico

- Contraseña (Generada o escrita)

- Funcionalidades:

- Acceder a todas las funciones del sistema.

- Crear, actualizar y eliminar cuentas de cualquier **Usuario**.

- Gestionar configuraciones globales de la plataforma.


### **2.1.2 Acceso al Sistema para Administrador**


- Los **Administradores** serán registrados por el **Super Administrador**.

- Datos requeridos para el registro:

- Nombres y apellidos

- Teléfono

- Identificación

- Correo electrónico

- Foto de perfil (Opcional)

- Contraseña (Generada o escrita, despues el admin podra cambiarla para tener una propia)

- Funcionalidades:

- Gestionar cuentas de **Propietarios y Árbitros**.

- Aprobar o rechazar registros de **Equipos y Torneos**.

- Supervisar el sistema y reportes de actividad.

### **2.1.3 Acceso al Sistema para Propietario**

- Los **Propietarios** serán registrados por un **Administrador**.

- Datos requeridos:

- Nombres y apellidos

- Teléfono

- Identificación

- Correo electrónico

- Foto de perfil (Opcional)

- Contraseña (Generada o escrita)

- Funcionalidades:

- Registrar y gestionar **Equipos**.

- Registrar y gestionar **Jugadores** dentro de su equipo.

- Consultar torneos en los que participa su equipo.

### **2.1.4 Acceso al Sistema para Entrenador**

- Los **Entrenadores** serán registrados por un **Propietario**.

- Datos requeridos:

- Nombres y apellidos

- Teléfono

- Identificación

- Correo electrónico

- Foto de perfil (Opcional)

- Contraseña (Generada o escrita)

- Funcionalidades:

- Gestionar tácticas y estrategias de equipo.

- Acceder a estadísticas y rendimiento de jugadores.

### **2.1.5 Acceso al Sistema para Árbitro**

- Los **Árbitros** serán registrados por un **Administrador**.

- Datos requeridos:

- Nombres y apellidos

- Teléfono

- Identificación

- Correo electrónico

- Foto de perfil (Opcional)

- Contraseña (Generada o escrita)

- Funcionalidades:

- Gestionar reportes de partidos.

- Registrar sanciones y eventos del partido.

### **2.1.6 Acceso al Sistema para Cliente (Usuario Final)**

- Los **Clientes** podrán registrarse mediante **Google o un formulario manual**.

- Datos requeridos:

- Nombres y apellidos

- Teléfono

- Identificación (Opcional)

- Correo electrónico

- Foto de perfil (Opcional)

- Contraseña (Generada o escrita)

- Funcionalidades:

- Consultar información de **equipos, jugadores, torneos y estadísticas**.

### **2.1.7 Acceso al Sistema para Jugadores**

- Los **Jugadores** serán registrados por un **Propietario**.

- Datos requeridos:

- Nombres y apellidos

- Fecha de nacimiento

- Teléfono

- Identificación

- Tipo de sangre

- Correo electrónico

- Foto de perfil (Opcional)

- Contraseña (Generada o escrita)

- Funcionalidades:

- Acceder a sus propias estadísticas y rendimiento.

- Ver próximas competiciones y torneos en los que participa su equipo.

---

**Registro por rol**:

- **Super Administrador**:

- Registrado manualmente por desarrolladores o configuración inicial.

- Funcionalidades: Acceso total al sistema, gestión de Administradores y configuraciones globales, podra desactivar y avilitar las cuentas de todo los usuarios esto lo que hace es poder tener una buan getion tanto los pagos por ejemplo si un admin no queire pagar por la pagiana el super admin puede desacticar la cuenta y mostar un mensaje que se mensione que se activara toda la pagia web cuanod realice el pago por el servicio de la pagina web, esto agra que la cuenta de los diferentes roles pueda o no pueda seguir navegando por la pagina web, poder mostrar vistas o ocultar vistas para los diferentes roles, que pueden ver o no, el super admin pude hacer mostra/oculte vistas/opciones para todos los rol o tambien para sirtos roles o tambien puede solo hacer que se le active/desactive a un sirto usuario.

- **Administrador**:

- Registrado por Super Administrador.

- Funcionalidades: Gestionar Propietarios, Árbitros y Clientes; aprobar/rechazar registros de Equipos y Torneos.

- **Propietario**:

- Registrado por Administrador.

- Funcionalidades: Registrar y gestionar Equipos y Jugadores; consultar torneos de su equipo.

- **Entrenador**:

- Registrado por Propietario.

- Funcionalidades: Gestionar tácticas de equipo; acceder a estadísticas de jugadores.

- **Árbitro**:

- Registrado por Administrador.

- Funcionalidades: Gestionar reportes de partidos; registrar sanciones.

- **Jugador**:

- Registrado por Propietario.

- Funcionalidades: Acceder a estadísticas personales; ver próximas competiciones.

- **Cliente**:

- Registro autónomo mediante correo/contraseña, Google.

- Funcionalidades: Consultar equipos, jugadores y torneos; comprar suscripciones premium.

**2.1.2 Inicio de Sesión**

- Métodos:

- Correo electrónico + contraseña.

- Autenticación con Google (solo Clientes).

- Doble factor de autenticación (2FA) para Super Administradores y Administradores.

- Seguridad:

- Bloqueo temporal tras 5 intentos fallidos.

- Bloque por los 5 intentos por 15min y vuelve a fallar son 24h(Se envía un mensaje).

- Registro de última fecha/hora de acceso en la base de datos.

**2.1.3 Recuperación de Contraseña**

- Opciones:

- Envío de enlace al correo electrónico (expira en 10 minutos).

- Restablecimiento mediante código OTP (correo).

- Verificación por SMS.

**2.1.4 Gestión de Sesiones**

- Una sesión activa por dispositivo.

- Cierre automático de sesión anterior al iniciar en otro dispositivo.

- Uso de tokens JWT para autenticación.


**2.1.5 Gestión de Permisos**

- **Super Administrador**: Acceso total.

- **Administrador**: Gestión de torneos, equipos y usuarios en su área.

- **Propietario**: Administración de sus equipos y jugadores.

- **Entrenador**: Gestión de entrenamientos y partidos, sele mostrara las vistas que solo el super admin le permita.

- **Árbitro**: Reporte de resultados de partidos.

- **Jugador**: Acceso a perfil y estadísticas personales.

- **Cliente**: Visualización de contenido deportivo.

**2.1.6 Cierre de Sesión**

- Opción de cerrar sesión desde cualquier dispositivo.

- Cierre automático si el usuario es desactivado.

---

### **3. Requerimientos No Funcionales**

### **3.1 Seguridad**

- Cifrado SSL/TLS para datos en tránsito.

- Hash de contraseñas con bcrypt o Argon2.

- Prevención de ataques mediante:

- reCAPTCHA.

- Bloqueo de IP por intentos sospechosos.

- Auditoría de accesos y acciones críticas.

- Autenticación JWT.

- Protección contra SQL Injection.

### **3.2 Rendimiento y Escalabilidad**

- Soporte para 100,000 usuarios concurrentes.

- Optimización de consultas con índices y caché (Redis).

- Uso de CDN para recursos estáticos.

- Arquitectura de microservicios para escalabilidad.

### **3.3 Usabilidad y Experiencia de Usuario**

- Diseño responsivo (móvil y escritorio).

- Tiempos de carga menores a 2 segundos.

- Notificaciones en tiempo real (inicio de sesión, recuperación de cuenta).

- Soporte para múltiples idiomas (español e inglés).

- Modo claro y oscuro.

### **3.4 Disponibilidad**

- 99.9% de uptime garantizado.

- Balanceo de carga para alta disponibilidad (HA).

- Backups automáticos diarios.

- Monitoreo en tiempo real del sistema.

---

### **4. Consideraciones Generales**

- **Módulos futuros**:

- Gestión de Equipos y Jugadores.

- Gestión de Torneos y Estadísticas.

- Módulo de Suscripciones y Monetización.

- **Recomendaciones**:

- Validar requerimientos con el equipo de desarrollo.

- Iterar en fases para priorizar funcionalidades críticas.