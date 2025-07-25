La ideas un dashboard centralizado que gestiona múltiples ciudades, con administradores por ciudad/deporte y una base de datos única, es un enfoque muy sólido y escalable.


IMPORTATE TODO SE TIENE QUE TRABAJAR EN INGELES TANTO PARA NOMBRAR LAS VARIABLES LAS FUNCIONES TODO TIENE QUE ESTAR EN INGELS, MENOS LOS CHATS CON KIRO. ESTO ES PARA TENER UN BUENA ORGANIZACION Y LEGIBILIDAD, TAMBIEN SE TIENE QUE TRABAJAR CON SNAKE_CASE PARA NOMBRAR LAS VARIABLES.

Recomendaciones:
Utiliza nombres que reflejen el propósito de la variable. 
Asegúrate de que los nombres sean fáciles de leer y entender. 
Evita nombres demasiado cortos o vagos que puedan generar confusión. 
Si usas abreviaturas, asegúrate de que sean comúnmente entendidas. 
Considera las convenciones de nomenclatura de tu equipo o proyecto para mantener la consistencia. 


-----

# Guía de Tareas: Diseño e Implementación de la Base de Datos de Mowe Sport en Supabase (PostgreSQL)

## Introducción: La Columna Vertebral de Mowe Sport

La base de datos es el corazón de cualquier plataforma deportiva. Una estructura bien diseñada no solo garantiza la integridad y la consistencia de los datos, sino que también es fundamental para el rendimiento, la escalabilidad y la seguridad. En Mowe Sport, donde gestionaremos torneos, equipos, jugadores y estadísticas de múltiples ciudades y deportes, una base de datos robusta es clave para el éxito.

Utilizaremos **Supabase**, que se basa en **PostgreSQL**, una de las bases de datos relacionales más potentes y fiables del mundo. Supabase nos proporcionará herramientas esenciales como la autenticación de usuarios y la Seguridad a Nivel de Fila (RLS), que serán cruciales para aislar los datos por ciudad y por deporte, asegurando que cada administrador solo vea y gestione lo que le corresponde.

**Objetivo de esta guía:** Proporcionar una hoja de ruta detallada para diseñar e implementar la base de datos de Mowe Sport, con un enfoque en la claridad y la asignación de tareas para tu amigo, quien liderará esta área.

**Roles en esta fase:**

  * **Tu Amigo (Líder de Base de Datos):** Se encargará de la creación de tablas, la definición de relaciones, la implementación de RLS y la optimización inicial. Su experiencia en bases de datos será invaluable aquí.
  * **Tú (Asesor/Revisor):** Proporcionarás orientación, revisarás los diseños, ayudarás con consultas complejas y asegurarás la integración con el backend de Go.

-----

## Fase 1: Diseño Conceptual y Planificación (Colaborativa)

Esta fase es de discusión y diseño. Ambos deben participar para asegurar que la estructura de la base de datos cumpla con todos los requisitos del proyecto.

### 1.1. Entender los Requisitos Clave de la Base de Datos

**Objetivo:** Asegurar una comprensión compartida de cómo la base de datos manejará la complejidad de Mowe Sport.

  * **Tarea 1.1.1: Clarificar el Aislamiento de Datos.**
      * **Descripción:** Discutir cómo se garantizará que un administrador de la Ciudad A no pueda ver los torneos de la Ciudad B. Y cómo un administrador de fútbol en la Ciudad A no pueda ver los torneos de baloncesto en la misma ciudad, si esa es una necesidad. Esto se logrará principalmente con la Seguridad a Nivel de Fila (RLS) de PostgreSQL.
      * **Responsable:** Tú (Explicas el concepto de RLS), Amigo (Comprende la necesidad y cómo se aplicará).
      * **Notas para tu amigo:** RLS es como un "filtro" de seguridad que se aplica directamente en la base de datos. Significa que, aunque todos los datos estén en la misma tabla, la base de datos solo le mostrará a cada usuario las filas a las que tiene permiso de acceso. Esto es muy potente para la seguridad. [1, 2, 3]
  * **Tarea 1.1.2: Modelar la Participación de Jugadores.**
      * **Descripción:** Confirmar cómo un jugador puede pertenecer a múltiples equipos (Un jugador puede puede estar en diferentes equipos pero solo en diferentes deportes, No puede estar en un equipo del mimo deporte y tambien no puede perteneser a un equipo de su mismo categoria y torneo) y cómo se registrarán sus estadísticas de forma contextual.
      * **Responsable:** Tú (Explicas el modelo de relaciones muchos a muchos), Amigo (Comprende cómo se traducirá a tablas).
      * **Notas para tu amigo:** Un jugador es una persona única, pero puede jugar en muchos equipos pero de diferentes deportes/categorias/torneos. Un equipo puede tener muchos jugadores. Esto se resuelve con una tabla intermedia (o "tabla de unión") que conecta jugadores y equipos. [4, 5, 6, 7, 8, 9, 10, 11]

### 1.2. Identificación de Entidades y Atributos

**Objetivo:** Listar todas las "cosas" que necesitamos almacenar y qué información necesitamos de cada una.

  * **Tarea 1.2.1: Listado de Entidades Principales.**
      * **Descripción:** Identificar las entidades clave: Ciudades, Deportes, Usuarios (con sus perfiles y roles), Torneos, Equipos, Jugadores, Partidos, Eventos de Partidos, Estadísticas de Jugadores, Estadísticas de Equipos.
      * **Responsable:** Amigo (Propone), Tú (Revisas y completas).
  * **Tarea 1.2.2: Definición de Atributos y Tipos de Datos.**
      * **Descripción:** Para cada entidad, listar las columnas necesarias (ej., `nombre`, `fecha_inicio`, `estado`) y sus tipos de datos (ej., `TEXT`, `INTEGER`, `DATE`, `UUID`). Usaremos `UUID` para la mayoría de las claves primarias por su naturaleza distribuida y para evitar problemas de concurrencia.
      * **Responsable:** Amigo (Propone), Tú (Revisas y sugieres tipos de datos óptimos para PostgreSQL).
      * **Notas para tu amigo:** `UUID` es un identificador único universal. Es bueno para claves primarias porque se pueden generar en cualquier lugar (frontend, backend) sin preocuparse por colisiones, lo que ayuda a la escalabilidad.

### 1.3. Esbozo de Relaciones y Claves

**Objetivo:** Dibujar cómo se conectan las tablas entre sí.

  * **Tarea 1.3.1: Diagrama de Entidad-Relación (DER) Conceptual.**
      * **Descripción:** Crear un diagrama simple que muestre las entidades y cómo se relacionan (uno a uno, uno a muchos, muchos a muchos). No es necesario que sea muy detallado, solo para visualizar las conexiones.
      * **Responsable:** Amigo (Dibuja), Tú (Revisas).

-----

## Fase 2: Configuración Inicial en Supabase (Amigo Lidera)

Esta fase es práctica y tu amigo puede empezar a familiarizarse con el dashboard de Supabase.

### 2.1. Creación del Proyecto Supabase

**Objetivo:** Tener un entorno de base de datos listo para trabajar.

  * **Tarea 2.1.1: Crear una Nueva Instancia de Proyecto.**
      * **Descripción:** Ir a Supabase.com, registrarse (si no lo ha hecho) y crear un nuevo proyecto. Elegir la región más cercana para un mejor rendimiento.
      * **Responsable:** Amigo.
      * **Notas para tu amigo:** Supabase es muy intuitivo. Una vez creado el proyecto, tendrás acceso a un dashboard con un editor SQL y herramientas de gestión de tablas.

### 2.2. Configuración Básica de Autenticación

**Objetivo:** Preparar Supabase para gestionar usuarios.

  * **Tarea 2.2.1: Habilitar Proveedores de Autenticación.**
      * **Descripción:** En el dashboard de Supabase, ir a la sección "Authentication" y habilitar los métodos de inicio de sesión que se usarán (ej., Email/Password, Google OAuth).
      * **Responsable:** Amigo.
      * **Notas para tu amigo:** Supabase Auth gestiona automáticamente las tablas de usuarios (`auth.users`) y las sesiones. Esto es una gran ventaja. [12, 13]

-----

## Fase 3: Implementación Detallada del Esquema (Amigo Lidera con tu Asesoramiento)

Aquí es donde se construyen las tablas. Tu amigo puede usar el editor SQL de Supabase o la interfaz visual para crear las tablas.

### 3.1. Tablas Centrales y de Gestión

**Objetivo:** Crear las tablas fundamentales para la estructura de la plataforma.

  * **Tarea 3.1.1: Tabla `cities` (Ciudades).**
      * **Descripción:** Almacena la información de cada ciudad/municipio que usará la plataforma.
      * **Columnas:**
          * `id` (UUID, Primary Key, Default `gen_random_uuid()`)
          * `name` (TEXT, NOT NULL, UNIQUE)
          * `country` (TEXT, NOT NULL)
          * `region` (TEXT, NULLABLE)
          * `created_at` (TIMESTAMP WITH TIME ZONE, NOT NULL, Default `now()`)
      * **Responsable:** Amigo.
  * **Tarea 3.1.2: Tabla `sports` (Deportes).**
      * **Descripción:** Lista de los deportes disponibles en la plataforma.
      * **Columnas:**
          * `id` (UUID, Primary Key, Default `gen_random_uuid()`)
          * `name` (TEXT, NOT NULL, UNIQUE)
          * `description` (TEXT, NULLABLE)
          * `created_at` (TIMESTAMP WITH TIME ZONE, NOT NULL, Default `now()`)
      * **Responsable:** Amigo.
  * **Tarea 3.1.3: Tabla `user_profiles` (Perfiles de Usuario).**
      * **Descripción:** Extiende la información de los usuarios de `auth.users` con datos específicos de Mowe Sport y el rol principal.
      * **Columnas:**
          * `id` (UUID, Primary Key, Foreign Key a `auth.users.id`, NOT NULL)
          * `first_name` (TEXT, NOT NULL)
          * `last_name` (TEXT, NOT NULL)
          * `identification` (TEXT, UNIQUE, NULLABLE)
          * `phone` (TEXT, NULLABLE)
          * `photo_url` (TEXT, NULLABLE)
          * `role` (TEXT, NOT NULL, Enum: 'super\_admin', 'city\_admin', 'tournament\_admin', 'owner', 'coach', 'referee', 'player', 'client') - Rol principal.
          * `is_active` (BOOLEAN, NOT NULL, Default `TRUE`)
          * `created_at` (TIMESTAMP WITH TIME ZONE, NOT NULL, Default `now()`)
          * `updated_at` (TIMESTAMP WITH TIME ZONE, NOT NULL, Default `now()`)
      * **Responsable:** Amigo.
      * **Notas para tu amigo:** Esta tabla es crucial para RLS. El `id` de esta tabla debe ser el mismo `id` que el usuario tiene en la tabla `auth.users` de Supabase.
  * **Tarea 3.1.4: Tabla `user_roles_by_city_sport` (Roles Granulares por Ciudad/Deporte).**
      * **Descripción:** Permite asignar roles específicos a un usuario dentro de una ciudad o un deporte en particular. Un usuario puede tener múltiples entradas aquí.
      * **Columnas:**
          * `id` (UUID, Primary Key, Default `gen_random_uuid()`)
          * `user_id` (UUID, Foreign Key a `user_profiles.id`, NOT NULL)
          * `city_id` (UUID, Foreign Key a `cities.id`, NULLABLE) - Si es NULL, el rol aplica globalmente o a todos los deportes de la ciudad.
          * `sport_id` (UUID, Foreign Key a `sports.id`, NULLABLE) - Si es NULL, el rol aplica a todos los deportes de la ciudad/global.
          * `role_name` (TEXT, NOT NULL, Enum: 'city\_admin', 'tournament\_admin', 'owner', 'coach', 'referee', 'player', 'client') - Rol específico.
          * `assigned_by_user_id` (UUID, Foreign Key a `user_profiles.id`, NULLABLE) - Quién asignó este rol.
          * `created_at` (TIMESTAMP WITH TIME ZONE, NOT NULL, Default `now()`)
          * `UNIQUE(user_id, city_id, sport_id, role_name)` - Asegura que una combinación de usuario-ciudad-deporte-rol sea única.
      * **Responsable:** Amigo.
      * **Notas para tu amigo:** Esta tabla es clave para la flexibilidad de permisos. Por ejemplo, un usuario puede ser `city_admin` para Bogotá (sin `sport_id`) y `owner` de un equipo de fútbol en Medellín.

### 3.2. Tablas de Gestión Deportiva

**Objetivo:** Almacenar la información de torneos, equipos, jugadores y sus relaciones.

  * **Tarea 3.2.1: Tabla `tournaments` (Torneos).**
      * **Descripción:** Detalles de cada torneo.
      * **Columnas:**
          * `id` (UUID, Primary Key, Default `gen_random_uuid()`)
          * `name` (TEXT, NOT NULL)
          * `city_id` (UUID, Foreign Key a `cities.id`, NOT NULL)
          * `sport_id` (UUID, Foreign Key a `sports.id`, NOT NULL)
          * `start_date` (DATE, NOT NULL)
          * `end_date` (DATE, NOT NULL)
          * `status` (TEXT, NOT NULL, Enum: 'pending', 'active', 'completed', 'cancelled')
          * `admin_user_id` (UUID, Foreign Key a `user_profiles.id`, NOT NULL) - El administrador que lo creó/gestiona.
          * `is_public` (BOOLEAN, NOT NULL, Default `TRUE`) - Si es visible para usuarios no autenticados.
          * `created_at` (TIMESTAMP WITH TIME ZONE, NOT NULL, Default `now()`)
          * `updated_at` (TIMESTAMP WITH TIME ZONE, NOT NULL, Default `now()`)
      * **Responsable:** Amigo.
  * **Tarea 3.2.2: Tabla `teams` (Equipos).**
      * **Descripción:** Información de los equipos.
      * **Columnas:**
          * `id` (UUID, Primary Key, Default `gen_random_uuid()`)
          * `name` (TEXT, NOT NULL)
          * `city_id` (UUID, Foreign Key a `cities.id`, NOT NULL)
          * `sport_id` (UUID, Foreign Key a `sports.id`, NOT NULL)
          * `owner_user_id` (UUID, Foreign Key a `user_profiles.id`, NOT NULL) - El propietario del equipo.
          * `created_at` (TIMESTAMP WITH TIME ZONE, NOT NULL, Default `now()`)
          * `updated_at` (TIMESTAMP WITH TIME ZONE, NOT NULL, Default `now()`)
      * **Responsable:** Amigo.
  * **Tarea 3.2.3: Tabla `players` (Jugadores).**
      * **Descripción:** Perfiles de los jugadores.
      * **Columnas:**
          * `id` (UUID, Primary Key, Default `gen_random_uuid()`)
          * `user_profile_id` (UUID, Foreign Key a `user_profiles.id`, NULLABLE) - Si el jugador tiene una cuenta de usuario.
          * `first_name` (TEXT, NOT NULL)
          * `last_name` (TEXT, NOT NULL)
          * `date_of_birth` (DATE, NULLABLE)
          * `identification` (TEXT, UNIQUE, NULLABLE)
          * `type_of_blood` (TEXT, NULLABLE)
          * `photo_url` (TEXT, NULLABLE)
          * `created_at` (TIMESTAMP WITH TIME ZONE, NOT NULL, Default `now()`)
          * `updated_at` (TIMESTAMP WITH TIME ZONE, NOT NULL, Default `now()`)
      * **Responsable:** Amigo.
      * **Notas para tu amigo:** Un jugador puede existir aquí sin tener una cuenta de usuario en la plataforma. Si luego se registra, se vincula con `user_profile_id`.
  * **Tarea 3.2.4: Tabla `team_players` (Jugadores por Equipo).**
      * **Descripción:** Tabla de unión para la relación muchos a muchos entre `teams` y `players`. Permite que un jugador esté en varios equipos.
      * **Columnas:**
          * `id` (UUID, Primary Key, Default `gen_random_uuid()`)
          * `team_id` (UUID, Foreign Key a `teams.id`, NOT NULL)
          * `player_id` (UUID, Foreign Key a `players.id`, NOT NULL)
          * `join_date` (DATE, NOT NULL, Default `now()`)
          * `leave_date` (DATE, NULLABLE)
          * `is_active` (BOOLEAN, NOT NULL, Default `TRUE`)
          * `jersey_number` (INTEGER, NULLABLE)
          * `position` (TEXT, NULLABLE)
          * `created_at` (TIMESTAMP WITH TIME ZONE, NOT NULL, Default `now()`)
          * `UNIQUE(team_id, player_id, join_date)` - Permite que un jugador se una al mismo equipo en diferentes momentos.
      * **Responsable:** Amigo.
  * **Tarea 3.2.5: Tabla `tournament_teams` (Equipos por Torneo).**
      * **Descripción:** Tabla de unión para la relación muchos a muchos entre `tournaments` y `teams`.
      * **Columnas:**
          * `id` (UUID, Primary Key, Default `gen_random_uuid()`)
          * `tournament_id` (UUID, Foreign Key a `tournaments.id`, NOT NULL)
          * `team_id` (UUID, Foreign Key a `teams.id`, NOT NULL)
          * `registration_date` (TIMESTAMP WITH TIME ZONE, NOT NULL, Default `now()`)
          * `status` (TEXT, NOT NULL, Enum: 'pending', 'approved', 'rejected')
          * `created_at` (TIMESTAMP WITH TIME ZONE, NOT NULL, Default `now()`)
          * `UNIQUE(tournament_id, team_id)`
      * **Responsable:** Amigo.

### 3.3. Tablas de Partidos y Eventos

**Objetivo:** Registrar los detalles de los partidos y los eventos que ocurren en ellos.

  * **Tarea 3.3.1: Tabla `matches` (Partidos).**
      * **Descripción:** Información de cada partido.
      * **Columnas:**
          * `id` (UUID, Primary Key, Default `gen_random_uuid()`)
          * `tournament_id` (UUID, Foreign Key a `tournaments.id`, NOT NULL)
          * `sport_id` (UUID, Foreign Key a `sports.id`, NOT NULL) - Redundante pero útil para consultas y RLS.
          * `team1_id` (UUID, Foreign Key a `teams.id`, NOT NULL)
          * `team2_id` (UUID, Foreign Key a `teams.id`, NOT NULL)
          * `match_date` (DATE, NOT NULL)
          * `match_time` (TIME, NOT NULL)
          * `location` (TEXT, NULLABLE)
          * `score_team1` (INTEGER, NOT NULL, Default `0`)
          * `score_team2` (INTEGER, NOT NULL, Default `0`)
          * `status` (TEXT, NOT NULL, Enum: 'scheduled', 'live', 'completed', 'postponed', 'cancelled')
          * `referee_user_id` (UUID, Foreign Key a `user_profiles.id`, NULLABLE) - El árbitro asignado.
          * `created_at` (TIMESTAMP WITH TIME ZONE, NOT NULL, Default `now()`)
          * `updated_at` (TIMESTAMP WITH TIME ZONE, NOT NULL, Default `now()`)
      * **Responsable:** Amigo.
  * **Tarea 3.3.2: Tabla `match_events` (Eventos de Partido).**
      * **Descripción:** Registra eventos detallados durante un partido (goles, faltas, tarjetas, etc.).
      * **Columnas:**
          * `id` (UUID, Primary Key, Default `gen_random_uuid()`)
          * `match_id` (UUID, Foreign Key a `matches.id`, NOT NULL)
          * `event_type` (TEXT, NOT NULL, Enum: 'goal', 'foul', 'yellow\_card', 'red\_card', 'substitution', 'assist', 'penalty', 'other')
          * `event_time_minutes` (INTEGER, NOT NULL) - Minuto del partido en que ocurrió el evento.
          * `player_id` (UUID, Foreign Key a `players.id`, NULLABLE) - Jugador involucrado (si aplica).
          * `team_id` (UUID, Foreign Key a `teams.id`, NULLABLE) - Equipo involucrado (si aplica).
          * `description` (TEXT, NULLABLE) - Descripción adicional del evento.
          * `created_at` (TIMESTAMP WITH TIME ZONE, NOT NULL, Default `now()`)
      * **Responsable:** Amigo.

### 3.4. Tablas de Estadísticas (Vistas Materializadas o Tablas de Resumen)

**Objetivo:** Almacenar estadísticas agregadas para un acceso rápido. Estas tablas se actualizarán automáticamente o mediante procesos en segundo plano. [14]

  * **Tarea 3.4.1: Tabla `player_statistics` (Estadísticas de Jugadores).**
      * **Descripción:** Estadísticas agregadas por jugador, opcionalmente por equipo, torneo o deporte.
      * **Columnas:**
          * `id` (UUID, Primary Key, Default `gen_random_uuid()`)
          * `player_id` (UUID, Foreign Key a `players.id`, NOT NULL)
          * `team_id` (UUID, Foreign Key a `teams.id`, NULLABLE) - Si son estadísticas específicas de un equipo.
          * `tournament_id` (UUID, Foreign Key a `tournaments.id`, NULLABLE) - Si son estadísticas específicas de un torneo.
          * `sport_id` (UUID, Foreign Key a `sports.id`, NOT NULL)
          * `matches_played` (INTEGER, NOT NULL, Default `0`)
          * `goals_scored` (INTEGER, NOT NULL, Default `0`)
          * `assists` (INTEGER, NOT NULL, Default `0`)
          * `red_cards` (INTEGER, NOT NULL, Default `0`)
          * `yellow_cards` (INTEGER, NOT NULL, Default `0`)
          * `wins` (INTEGER, NOT NULL, Default `0`)
          * `losses` (INTEGER, NOT NULL, Default `0`)
          * `draws` (INTEGER, NOT NULL, Default `0`)
          * `points` (INTEGER, NOT NULL, Default `0`)
          * `updated_at` (TIMESTAMP WITH TIME ZONE, NOT NULL, Default `now()`)
          * `UNIQUE(player_id, team_id, tournament_id, sport_id)` - Para asegurar una entrada única por contexto.
      * **Responsable:** Amigo.
  * **Tarea 3.4.2: Tabla `team_statistics` (Estadísticas de Equipos).**
      * **Descripción:** Estadísticas agregadas por equipo, opcionalmente por torneo o deporte.
      * **Columnas:**
          * `id` (UUID, Primary Key, Default `gen_random_uuid()`)
          * `team_id` (UUID, Foreign Key a `teams.id`, NOT NULL)
          * `tournament_id` (UUID, Foreign Key a `tournaments.id`, NULLABLE)
          * `sport_id` (UUID, Foreign Key a `sports.id`, NOT NULL)
          * `matches_played` (INTEGER, NOT NULL, Default `0`)
          * `wins` (INTEGER, NOT NULL, Default `0`)
          * `losses` (INTEGER, NOT NULL, Default `0`)
          * `draws` (INTEGER, NOT NULL, Default `0`)
          * `points` (INTEGER, NOT NULL, Default `0`)
          * `goals_for` (INTEGER, NOT NULL, Default `0`)
          * `goals_against` (INTEGER, NOT NULL, Default `0`)
          * `updated_at` (TIMESTAMP WITH TIME ZONE, NOT NULL, Default `now()`)
          * `UNIQUE(team_id, tournament_id, sport_id)`
      * **Responsable:** Amigo.

-----

## Fase 4: Implementación de Seguridad a Nivel de Fila (RLS) (Amigo Lidera)

Esta es la parte más crítica para el aislamiento de datos. Tu amigo necesitará entender bien los conceptos.

### 4.1. Habilitar RLS en Tablas Clave

**Objetivo:** Activar la seguridad a nivel de fila para que las políticas puedan aplicarse.

  * **Tarea 4.1.1: Habilitar RLS en Todas las Tablas Relevantes.**
      * **Descripción:** Para cada tabla que contenga datos que deban ser aislados por usuario, ciudad o deporte, ejecutar el comando `ALTER TABLE table_name ENABLE ROW LEVEL SECURITY;`. Esto incluye `user_profiles`, `user_roles_by_city_sport`, `tournaments`, `teams`, `players`, `team_players`, `tournament_teams`, `matches`, `match_events`, `player_statistics`, `team_statistics`.
      * **Responsable:** Amigo.
      * **Notas para tu amigo:** Una vez que RLS está habilitado en una tabla, ¡nadie puede ver los datos hasta que se definan políticas\! Esto es por diseño, para forzar la seguridad. [1, 2, 3]

### 4.2. Definir Políticas RLS por Rol y Contexto

**Objetivo:** Escribir las reglas SQL que dictan quién puede ver y modificar qué datos.

  * **Tarea 4.2.1: Políticas para `user_profiles`.**
      * **Descripción:**
          * **SELECT:** Los usuarios pueden ver su propio perfil. Los `super_admin` pueden ver todos. Los `city_admin` pueden ver perfiles de usuarios en su ciudad.
          * **UPDATE:** Los usuarios pueden actualizar su propio perfil. Los `super_admin` pueden actualizar todos. Los `city_admin` pueden actualizar perfiles de usuarios que gestionan.
      * **Ejemplo (SELECT para usuario propio):**
        ```sql
        CREATE POLICY "Users can view their own profile" ON public.user_profiles
        FOR SELECT TO authenticated
        USING (auth.uid() = id);
        ```
      * **Ejemplo (SELECT para super\_admin):**
        ```sql
        CREATE POLICY "Super Admins can view all profiles" ON public.user_profiles
        FOR SELECT TO authenticated
        USING (
          EXISTS (SELECT 1 FROM public.user_profiles WHERE id = auth.uid() AND role = 'super_admin')
        );
        ```
      * **Responsable:** Amigo (con tu ayuda para la lógica compleja).
      * **Notas para tu amigo:** `auth.uid()` devuelve el ID del usuario actualmente autenticado. `auth.jwt() ->> 'claim_name'` permite acceder a datos personalizados en el token JWT (como el rol o el ID de la ciudad si se añaden como claims personalizados). [1, 15, 2, 3, 16, 17]
  * **Tarea 4.2.2: Políticas para `user_roles_by_city_sport`.**
      * **Descripción:**
          * **SELECT:** Los usuarios pueden ver sus propios roles. Los `super_admin` pueden ver todos. Los `city_admin` pueden ver roles dentro de su ciudad.
          * **INSERT/UPDATE/DELETE:** Solo `super_admin` puede gestionar roles de `city_admin`. Los `city_admin` pueden gestionar roles de `owner`, `coach`, `referee`, `player`, `client` dentro de su ciudad/deporte.
      * **Responsable:** Amigo (con tu ayuda).
  * **Tarea 4.2.3: Políticas para `tournaments`.**
      * **Descripción:**
          * **SELECT:** Torneos públicos visibles para `client`. `city_admin` puede ver todos los torneos en su ciudad. `tournament_admin` puede ver/gestionar sus torneos específicos. `owner` puede ver torneos en los que participan sus equipos.
          * **INSERT/UPDATE:** Solo `city_admin` o `tournament_admin` pueden crear/actualizar torneos en su ciudad/deporte.
      * **Ejemplo (SELECT para city\_admin):**
        ```sql
        CREATE POLICY "City Admins can view tournaments in their city" ON public.tournaments
        FOR SELECT TO authenticated
        USING (
          EXISTS (SELECT 1 FROM public.user_roles_by_city_sport
                  WHERE user_id = auth.uid() AND role_name = 'city_admin' AND city_id = tournaments.city_id)
        );
        ```
      * **Responsable:** Amigo (con tu ayuda).
  * **Tarea 4.2.4: Políticas para `teams`, `players`, `team_players`, `tournament_teams`.**
      * **Descripción:** Definir políticas similares, asegurando que los `owner` solo gestionen sus equipos/jugadores, y los `city_admin` gestionen todo dentro de su ciudad/deporte.
      * **Responsable:** Amigo (con tu ayuda).
  * **Tarea 4.2.5: Políticas para `matches` y `match_events`.**
      * **Descripción:**
          * **SELECT:** Partidos/eventos públicos visibles para `client`. `city_admin` puede ver todos en su ciudad. `referee` puede ver los partidos que le han sido asignados.
          * **INSERT/UPDATE:** Solo `referee` puede actualizar resultados/eventos de sus partidos asignados. `city_admin` puede gestionar partidos en su ciudad.
      * **Responsable:** Amigo (con tu ayuda).
  * **Tarea 4.2.6: Políticas para `player_statistics` y `team_statistics`.**
      * **Descripción:**
          * **SELECT:** Estadísticas públicas visibles para `client`. `player` puede ver sus propias estadísticas. `coach` puede ver estadísticas de jugadores en su equipo. `city_admin` puede ver todas las estadísticas en su ciudad.
          * **UPDATE:** Solo el sistema (triggers/funciones de base de datos) o `super_admin` pueden actualizar estas tablas.
      * **Responsable:** Amigo (con tu ayuda).

### 4.3. Pruebas de RLS

**Objetivo:** Verificar que las políticas de seguridad funcionan como se espera.

  * **Tarea 4.3.1: Usar la Función de Impersonación de Supabase.**
      * **Descripción:** En el editor SQL de Supabase, puedes "impersonar" a un usuario específico (ej., un `city_admin` de Bogotá) y luego ejecutar consultas `SELECT` para asegurarte de que solo ve los datos de Bogotá. Luego, intenta ver datos de otra ciudad y verifica que no los ve. [1]
      * **Responsable:** Amigo.
      * **Notas para tu amigo:** Esto es crucial. Si las políticas no están bien, la seguridad de los datos podría verse comprometida.
  * **Tarea 4.3.2: Pruebas con Diferentes Roles.**
      * **Descripción:** Repetir las pruebas de impersonación para cada rol (`owner`, `referee`, `player`, `client`) para verificar que solo acceden a los datos que les corresponden.
      * **Responsable:** Amigo.

-----

## Fase 5: Optimización del Rendimiento de la Base de Datos (Colaborativa)

Una base de datos bien diseñada también debe ser rápida.

### 5.1. Estrategia de Indexación

**Objetivo:** Acelerar las consultas más frecuentes.

  * **Tarea 5.1.1: Indexar Claves Foráneas y Columnas de Filtro.**
      * **Descripción:** PostgreSQL indexa automáticamente las claves primarias. Sin embargo, es vital crear índices en todas las claves foráneas (`FK`) y en las columnas que se utilizan con frecuencia en las cláusulas `WHERE` o `ORDER BY` (ej., `city_id`, `sport_id`, `status`, `match_date`). Esto es especialmente importante para las columnas usadas en las políticas RLS. [18, 19, 20, 21, 22]
      * **Ejemplo:**
        ```sql
        CREATE INDEX idx_tournaments_city_sport_status ON public.tournaments (city_id, sport_id, status);
        CREATE INDEX idx_matches_tournament_date ON public.matches (tournament_id, match_date);
        CREATE INDEX idx_user_roles_by_city_sport_user_city_sport ON public.user_roles_by_city_sport (user_id, city_id, sport_id);
        ```
      * **Responsable:** Amigo (Identifica columnas), Tú (Revisas y sugieres índices compuestos).
      * **Notas para tu amigo:** Los índices son como el índice de un libro: ayudan a la base de datos a encontrar la información mucho más rápido sin tener que leer todo. Pero demasiados índices pueden ralentizar las escrituras, así que hay que ser estratégico. [18]

### 5.2. Optimización de Consultas y Monitoreo

**Objetivo:** Identificar y mejorar las consultas lentas.

  * **Tarea 5.2.1: Habilitar `pg_stat_statements`.**
      * **Descripción:** En el dashboard de Supabase, ir a "Database" -\> "Extensions" y habilitar `pg_stat_statements`. Esto nos permitirá ver qué consultas son las más lentas o las más ejecutadas. [23, 24]
      * **Responsable:** Amigo.
  * **Tarea 5.2.2: Analizar Consultas Lentas con `EXPLAIN ANALYZE`.**
      * **Descripción:** Cuando identifiques una consulta lenta (usando `pg_stat_statements`), usa `EXPLAIN ANALYZE` antes de la consulta para ver cómo PostgreSQL la ejecuta y dónde está el cuello de botella. [18, 21]
      * **Responsable:** Amigo (Ejecuta `EXPLAIN ANALYZE`), Tú (Interpretas los resultados y sugieres mejoras).
      * **Notas para tu amigo:** `EXPLAIN ANALYZE` te mostrará si la base de datos está usando tus índices o si está haciendo un "escaneo completo de tabla" (lo cual es lento).
  * **Tarea 5.2.3: Considerar Vistas Materializadas para Estadísticas.**
      * **Descripción:** Para las tablas de estadísticas (`player_statistics`, `team_statistics`), considera implementarlas como vistas materializadas si las consultas son muy pesadas y los datos no necesitan estar *absolutamente* en tiempo real (se pueden refrescar periódicamente). [14]
      * **Responsable:** Tú (Investigas la implementación de vistas materializadas), Amigo (Implementa).

-----

## Consideraciones Adicionales para tu Amigo

  * **Documentación de Supabase:** La documentación de Supabase es excelente y muy práctica. Anímale a consultarla para cada paso.
  * **Editor SQL:** El editor SQL del dashboard de Supabase es una herramienta poderosa para crear tablas, ejecutar consultas y probar políticas RLS.
  * **Consistencia:** Mantener la consistencia en los nombres de las columnas (ej., `_id` para claves foráneas, `_at` para timestamps) y los tipos de datos es crucial para la mantenibilidad.
  * **Errores:** Es normal cometer errores al diseñar bases de datos. Lo importante es aprender de ellos y corregirlos. La flexibilidad de PostgreSQL y Supabase lo permite.

Esta guía proporciona una base sólida para la base de datos de Mowe Sport. Con esta estructura, estarán bien equipados para gestionar la complejidad de múltiples ciudades, deportes y roles, asegurando una plataforma profesional y escalable. ¡Mucho éxito\!