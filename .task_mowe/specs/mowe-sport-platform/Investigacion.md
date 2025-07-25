# **Informe Técnico: Desarrollo de la Plataforma Deportiva Mowe Sport**

## **Resumen Ejecutivo**

El proyecto "Mowe Sport" tiene como objetivo transformar la gestión de torneos deportivos locales en ciudades y pueblos pequeños, ofreciendo una plataforma integral que incluye un panel de administración, un sitio web público y una aplicación móvil. Esta iniciativa busca replicar la experiencia profesional de grandes ligas como la Premier League, La Liga y ESPN, adaptándola a las necesidades de las competiciones comunitarias. El principal desafío arquitectónico radica en lograr una escalabilidad de nivel empresarial, una seguridad robusta, una gestión multi-inquilino (multi-ciudad y multi-deporte) y una administración compleja de jugadores y equipos, todo ello utilizando la pila tecnológica especificada: Go para el backend, React con Vite para el frontend y Supabase como base de datos.

La solución propuesta se centra en una arquitectura modular, aprovechando las capacidades de seguridad de Supabase RLS (Seguridad a Nivel de Fila), una estrategia de almacenamiento en caché inteligente y optimizaciones de rendimiento en todos los niveles. Se espera que esta aproximación resulte en una plataforma altamente performante, segura y fácil de usar, capaz de gestionar eficazmente los ecosistemas deportivos locales y proporcionar una experiencia superior tanto para administradores como para usuarios finales.

## **1. Visión General Arquitectónica: Construyendo una Plataforma Deportiva Escalable**

Esta sección establece los principios arquitectónicos fundamentales para Mowe Sport, inspirándose en las grandes plataformas deportivas y adaptándolos al contexto de torneos locales y a la pila tecnológica definida. El objetivo primordial es asegurar que la plataforma pueda manejar con fluidez el objetivo de 100.000 usuarios concurrentes y más.

### **1.1. Aprovechamiento de Microservicios para Modularidad y Escalabilidad**

La arquitectura de microservicios implica construir una aplicación como un conjunto de servicios pequeños e implementables de forma independiente, cada uno ejecutándose en su propio proceso y comunicándose a través de mecanismos ligeros, a menudo APIs HTTP.**1** Este enfoque permite el desarrollo, la implementación y la escalabilidad independiente de diferentes componentes.

Para Mowe Sport, dada la diversidad de funcionalidades (gestión de usuarios, gestión de torneos, gestión de equipos/jugadores, resultados de partidos, estadísticas, visualización pública, aplicación móvil), una arquitectura monolítica podría volverse difícil de manejar y un cuello de botella para el rendimiento y la velocidad de desarrollo. Los microservicios permiten que diferentes equipos trabajen en distintas partes del sistema simultáneamente y facilitan la escalabilidad de servicios específicos de alta demanda (por ejemplo, actualizaciones de resultados en tiempo real) de forma independiente.**1**

La capacidad de soportar 100.000 usuarios concurrentes, un requisito explícito del usuario, es un objetivo de escalabilidad muy ambicioso. La experiencia de grandes plataformas deportivas como ESPN, que opera con una arquitectura distribuida y aplicaciones separadas para diferentes deportes, agrupadas para la escalabilidad horizontal, demuestra que una aplicación monolítica tendría dificultades para satisfacer tales demandas de concurrencia y rendimiento.**3** Por lo tanto, adoptar un patrón de microservicios no es simplemente una buena práctica, sino una decisión arquitectónica fundamental para alcanzar este requisito no funcional. Permite una asignación granular de recursos y evita que un único punto de fallo o cuello de botella afecte a todo el sistema.

Aunque el usuario ha especificado Supabase como la base de datos principal, el principio de gestión de datos descentralizada, inherente a los microservicios, sugiere que cada servicio debería idealmente poseer su propio almacén de datos.**2** Si bien una interpretación estricta podría implicar múltiples instancias de Supabase, la plataforma Supabase se basa en PostgreSQL y promueve un enfoque de "comunidad de comunidades" donde las herramientas funcionan de forma aislada pero se integran.**4** Esto significa que, si bien se puede utilizar una única instancia de Supabase, la separación lógica de los datos (por ejemplo, mediante el uso de diferentes esquemas de PostgreSQL o tablas cuidadosamente gestionadas) para los distintos servicios es crucial para mantener los principios de los microservicios y evitar una capa de datos fuertemente acoplada. Esto influirá en cómo se diseñará la Seguridad a Nivel de Fila (RLS) y cómo los diferentes servicios accederán a los datos.

Los casos de uso específicos para microservicios en Mowe Sport incluyen:

- **Servicio de Usuarios y Autenticación**: Gestiona todos los roles de usuario, la autenticación (inicio de sesión, registro, 2FA) y la autorización.
- **Servicio de Gestión de Torneos**: Maneja la creación, aprobación, programación y ciclo de vida de los torneos.
- **Servicio de Gestión de Equipos y Jugadores**: Administra las listas de equipos, los perfiles de los jugadores y las asociaciones equipo-jugador.
- **Servicio de Partidos y Estadísticas**: Procesa eventos de partidos en tiempo real, calcula resultados y mantiene estadísticas de jugadores/equipos.
- **Servicio de Datos Públicos**: Sirve datos de solo lectura para el sitio web público y la aplicación móvil (por ejemplo, resultados en vivo, clasificaciones).
- **Servicio de Notificaciones**: Gestiona alertas en tiempo real y notificaciones push.

### **1.2. Diseño de API y Patrones de Comunicación**

El mecanismo de comunicación principal entre el frontend, los servicios de backend y los microservicios internos debe ser a través de APIs RESTful, utilizando métodos HTTP (GET, POST, PUT, DELETE) para las operaciones CRUD.**5** El framework Echo de Go es muy adecuado para construir APIs RESTful robustas.**6**

Las mejores prácticas para el diseño de APIs incluyen:

- **JSON para el Intercambio de Datos**: Aceptar y responder con cargas útiles JSON.**5**
- **Sustantivos para los Endpoints**: Utilizar sustantivos en plural para los nombres de las colecciones (por ejemplo, `/torneos`, `/jugadores`) y evitar verbos en las rutas. Las acciones se indican mediante métodos HTTP.**5**
- **Anidamiento Lógico**: Anidar recursos para objetos jerárquicos (por ejemplo, `/torneos/{tournamentId}/partidos`), pero evitar el anidamiento excesivo (limitar a 2-3 niveles).**5**
- **Manejo Elegante de Errores**: Devolver códigos de estado HTTP estándar (4xx para errores del cliente, 5xx para errores del servidor) con mensajes de error claros.**5**
- **Filtrado, Ordenación y Paginación**: Implementar estas capacidades para una recuperación eficiente de datos, especialmente para listas grandes de torneos, equipos o jugadores.**5**
- **Versionado**: Planificar el versionado de las APIs (por ejemplo, `/v1/torneos`) para gestionar los cambios importantes de forma elegante.**5**

Para una plataforma que aspira a ser "profesional y completa" como la Premier League o ESPN, la gestión robusta de APIs es fundamental. Una API Gateway, o una implementación de sus funcionalidades, centraliza preocupaciones como el balanceo de carga, la autenticación/autorización, la limitación de tasas y el monitoreo, protegiendo los servicios de backend y simplificando las interacciones del cliente.**7** Esto se vuelve crítico a medida que el número de microservicios crece, ya que abstrae la complejidad del frontend y las aplicaciones móviles.

Para la comunicación interna entre servicios, se pueden considerar mecanismos ligeros como HTTP/JSON o, potencialmente, una cola de mensajes (por ejemplo, Kafka/RabbitMQ) para operaciones asíncronas, especialmente para eventos de alto rendimiento como las actualizaciones de partidos. La gestión de datos de juego en tiempo real es una necesidad clave de la plataforma. Grandes sistemas como ESPN utilizan brokers JMS y arquitecturas Pub/Sub para distribuir mensajes y flujos de datos a un repositorio central.**3** Además, AWS sugiere el uso de servicios como Kinesis para la ingesta y procesamiento de flujos de datos de eventos deportivos en tiempo real, donde los dispositivos pueden emitir de 20 a 50 mensajes por segundo.**8** Esto indica que las llamadas directas y síncronas a la API para cada evento podrían no ser lo suficientemente eficientes para un alto volumen de datos en tiempo real (por ejemplo, movimientos de jugadores, cambios de puntuación). Un sistema de mensajería asíncrona desacoplaría a los productores de datos (árbitros, anotadores) de los consumidores de datos (servicio de estadísticas, visualización pública), permitiendo un mayor rendimiento y resiliencia.

### **1.3. Flujo de Datos en Tiempo Real con WebSockets**

Los WebSockets proporcionan un canal de comunicación persistente y dúplex completo entre el cliente y el servidor, ideal para actualizaciones en tiempo real sin necesidad de un sondeo constante.**9**

Supabase ofrece un motor Realtime que aprovecha los WebSockets para transmitir cambios en la base de datos, gestionar la presencia de usuarios y difundir mensajes.**10** Esto se ajusta perfectamente a la necesidad de mostrar resultados en vivo, eventos de partidos y estadísticas actualizadas en el sitio web público y la aplicación móvil. El frontend de React puede suscribirse a los canales de Supabase Realtime para recibir actualizaciones en vivo, asegurando que la interfaz de usuario refleje los datos más recientes al instante.**11**

La capacidad de proporcionar actualizaciones en tiempo real es un diferenciador clave para los torneos locales. El usuario ha señalado que las ciudades y pueblos más pequeños carecen de una gestión adecuada para sus torneos. Las plataformas como la Premier League, La Liga y ESPN son conocidas por sus actualizaciones en tiempo real.**13** Para los torneos locales, ofrecer resultados y estadísticas en vivo a través de una aplicación móvil y un sitio web público sería un avance significativo. Esta característica aborda directamente una necesidad no cubierta en las comunidades más pequeñas y mejora la participación de los usuarios, haciendo que la plataforma sea verdaderamente "profesional y completa" como se desea.

Para manejar 100.000 usuarios concurrentes, la escalabilidad del sistema en tiempo real es fundamental. ESPN, por ejemplo, puede enviar 1 millón de eventos en menos de 100 milisegundos y más de 3 mil millones de mensajes en un día ocupado.**9** Supabase Realtime está diseñado como un motor WebSocket escalable.**10** Esto implica que, si bien Supabase maneja la funcionalidad central de Realtime, un diseño cuidadoso de los canales (por ejemplo, canales por torneo o por partido) y cargas de datos eficientes serán necesarios para garantizar que el objetivo de 100.000 usuarios concurrentes se cumpla para las actualizaciones en tiempo real sin sobrecargar el sistema.

## **2. Diseño de Base de Datos y Gestión de Datos con Supabase**

Esta sección aborda la estructura central de los datos y los desafíos críticos de la gestión multi-inquilino y de jugadores, aprovechando las capacidades de Supabase.

### **2.1. Esquema Relacional Central para Deportes, Torneos, Equipos, Jugadores, Partidos y Estadísticas**

Supabase se basa en PostgreSQL, una base de datos relacional robusta.**4** Un esquema bien normalizado es crucial para la integridad de los datos, la flexibilidad y el rendimiento.

La tabla de `users` (usuarios) servirá como el centro de identidad para la Seguridad a Nivel de Fila (RLS). El sistema de roles del usuario es complejo, y la integración con Supabase Auth es clave. Las políticas de RLS de Supabase a menudo se basan en `auth.uid()`, que es el UUID del usuario de la tabla `auth.users`.**14** Para mapear roles personalizados y atributos de usuario adicionales (como nombres, teléfono, identificación) a este UUID, una tabla

`users` (o `profiles`, como se sugiere en los fragmentos **15**) vinculada por

`user_id` a `auth.uid()` es esencial. Esta tabla `users` servirá como el punto central para que las políticas de RLS determinen el `city_id`, `sport_id` y `role` de un usuario, permitiendo un control de acceso granular en toda la base de datos.

La gestión de goleadores y otras estadísticas es una necesidad clave. Para estadísticas de uso frecuente (como máximos goleadores, clasificaciones de equipos), almacenar agregados precalculados (`player_statistics`, `team_statistics`) es crucial para el rendimiento, especialmente con 100.000 usuarios concurrentes. Estos pueden actualizarse mediante disparadores de base de datos o trabajos por lotes a partir de los eventos de los partidos.**16** Las estadísticas menos frecuentes o muy dinámicas pueden derivarse mediante vistas o consultas complejas. Esto equilibra la frescura de los datos con el rendimiento de las consultas.

Las entidades y relaciones clave incluyen:

- **`cities`**: `city_id` (PK), `name`, `region`, `country`.
- **`sports`**: `sport_id` (PK), `name`, `description`.
- **`users`**: `user_id` (PK, UUID de Supabase Auth), `email`, `first_name`, `last_name`, `phone`, `identification`, `photo_url`, `role` (e.g., 'super_admin', 'admin', 'propietario', 'arbitro', 'jugador', 'cliente'), `city_id` (FK, para administradores de ciudad), `sport_id` (FK, para administradores de deporte o deportes preferidos de clientes). Esta tabla se vincularía a la tabla `auth.users` de Supabase.
- **`tournaments`**: `tournament_id` (PK), `name`, `city_id` (FK), `sport_id` (FK), `start_date`, `end_date`, `status`, `admin_user_id` (FK a `users` para el administrador del torneo), `is_public` (BOOLEAN).
- **`teams`**: `team_id` (PK), `name`, `owner_user_id` (FK a `users` para el propietario del equipo), `city_id` (FK), `sport_id` (FK).
- **`players`**: `player_id` (PK), `first_name`, `last_name`, `date_of_birth`, `identification`, `type_of_blood`, `email`, `phone`, `photo_url`. (Nota: `team_id` NO debe estar directamente en `players` para soportar múltiples equipos).**17**
- **`tournament_teams`**: `tournament_team_id` (PK), `tournament_id` (FK), `team_id` (FK), `registration_date`, `status` (e.g., 'approved', 'pending'). Esta es una relación muchos a muchos entre torneos y equipos.
- **`team_players`**: `team_player_id` (PK), `team_id` (FK), `player_id` (FK), `join_date`, `leave_date`, `is_active`. Esto vincula a los jugadores con los equipos.
- **`matches`**: `match_id` (PK), `tournament_id` (FK), `sport_id` (FK), `team1_id` (FK), `team2_id` (FK), `match_date`, `match_time`, `location`, `score_team1`, `score_team2`, `status` (e.g., 'scheduled', 'live', 'completed'), `referee_user_id` (FK a `users`).
- **`match_events`**: `event_id` (PK), `match_id` (FK), `player_id` (FK, anulable para eventos no relacionados con jugadores), `event_type` (e.g., 'goal', 'foul', 'red_card'), `event_time`, `description`. Esto captura datos granulares del partido.
- **`player_statistics`**: `stat_id` (PK), `player_id` (FK), `tournament_id` (FK), `sport_id` (FK), `matches_played`, `goals_scored`, `assists`, `red_cards`, `yellow_cards`, `wins`, `losses`, `draws`, `points`. Esta tabla contendría estadísticas agregadas, actualizadas potencialmente mediante disparadores o trabajos por lotes a partir de `match_events`.**16**
- **`team_statistics`**: Similar a `player_statistics` pero para equipos.

A continuación, se presenta un diagrama conceptual del esquema de la base de datos:

**Fragmento de código**

`erDiagram
CITIES {
UUID city_id PK
VARCHAR name
VARCHAR region
VARCHAR country
}
SPORTS {
UUID sport_id PK
VARCHAR name
VARCHAR description
}
USERS {
UUID user_id PK "from auth.users"
VARCHAR email
VARCHAR first_name
VARCHAR last_name
VARCHAR phone
VARCHAR identification
TEXT photo_url
VARCHAR role "super_admin, admin, propietario, entrenador, arbitro, jugador, cliente"
UUID city_id FK
UUID sport_id FK
}
TOURNAMENTS {
UUID tournament_id PK
VARCHAR name
UUID city_id FK
UUID sport_id FK
DATE start_date
DATE end_date
VARCHAR status
UUID admin_user_id FK "admin of this tournament"
BOOLEAN is_public
}
TEAMS {
UUID team_id PK
VARCHAR name
UUID owner_user_id FK "propietario of this team"
UUID city_id FK
UUID sport_id FK
}
PLAYERS {
UUID player_id PK
VARCHAR first_name
VARCHAR last_name
DATE date_of_birth
VARCHAR identification
VARCHAR type_of_blood
VARCHAR email
VARCHAR phone
TEXT photo_url
}
TOURNAMENT_TEAMS {
UUID tournament_team_id PK
UUID tournament_id FK
UUID team_id FK
DATE registration_date
VARCHAR status
}
TEAM_PLAYERS {
UUID team_player_id PK
UUID team_id FK
UUID player_id FK
DATE join_date
DATE leave_date
BOOLEAN is_active
}
MATCHES {
UUID match_id PK
UUID tournament_id FK
UUID sport_id FK
UUID team1_id FK
UUID team2_id FK
TIMESTAMP match_date
TIME match_time
VARCHAR location
INTEGER score_team1
INTEGER score_team2
VARCHAR status
UUID referee_user_id FK
}
MATCH_EVENTS {
UUID event_id PK
UUID match_id FK
UUID player_id FK "nullable"
VARCHAR event_type
TIME event_time
TEXT description
}
PLAYER_STATISTICS {
UUID stat_id PK
UUID player_id FK
UUID tournament_id FK
UUID sport_id FK
INTEGER matches_played
INTEGER goals_scored
INTEGER assists
INTEGER red_cards
INTEGER yellow_cards
INTEGER wins
INTEGER losses
INTEGER draws
INTEGER points
}
TEAM_STATISTICS {
UUID stat_id PK
UUID team_id FK
UUID tournament_id FK
UUID sport_id FK
INTEGER matches_played
INTEGER wins
INTEGER losses
INTEGER draws
INTEGER points
-- other team-specific stats
}

    CITIES |

|--o{ USERS : "manages"
SPORTS |

|--o{ USERS : "manages"
CITIES |

|--o{ TOURNAMENTS : "contains"
SPORTS |

|--o{ TOURNAMENTS : "features"
USERS |

|--o{ TOURNAMENTS : "administers"
CITIES |

|--o{ TEAMS : "contains"
SPORTS |

|--o{ TEAMS : "plays"
USERS |

|--o{ TEAMS : "owns"
PLAYERS |

|--o{ TEAM_PLAYERS : "participates_in"
TEAMS |

|--o{ TEAM_PLAYERS : "has_players"
TOURNAMENTS |

|--o{ TOURNAMENT_TEAMS : "includes"
TEAMS |

|--o{ TOURNAMENT_TEAMS : "participates_in"
TOURNAMENTS |

|--o{ MATCHES : "contains"
SPORTS |

|--o{ MATCHES : "is_of_type"
TEAMS |

|--o{ MATCHES : "competes_in"
USERS |

|--o{ MATCHES : "referees"
MATCHES |

|--o{ MATCH_EVENTS : "generates"
PLAYERS |

|--o{ MATCH_EVENTS : "performs"
PLAYERS |

|--o{ PLAYER_STATISTICS : "has"
TOURNAMENTS |

|--o{ PLAYER_STATISTICS : "in"
SPORTS |

|--o{ PLAYER_STATISTICS : "in"
TEAMS |

|--o{ TEAM_STATISTICS : "has"
TOURNAMENTS |

|--o{ TEAM_STATISTICS : "in"
SPORTS |

|--o{ TEAM_STATISTICS : "in"`

### **2.2. Implementación de Multi-Tenencia y Aislamiento de Datos (Específico por Ciudad y Deporte)**

El desafío principal es evitar que los administradores de una ciudad/deporte vean datos de otra, y que los usuarios vean datos de deportes para los que no están autorizados. El modelo de "Base de Datos Compartida, Esquema Compartido" con columnas `city_id` y `sport_id` en cada tabla relevante es el enfoque más rentable y manejable para Supabase.**19** Esto implica añadir claves foráneas

`city_id` y `sport_id` a las tablas `tournaments`, `teams`, `matches`, `player_statistics`, etc.

La Seguridad a Nivel de Fila (RLS) es el mecanismo principal para el aislamiento de datos multi-inquilino y multi-deporte. El usuario ha expresado una preocupación explícita sobre el aislamiento de datos por ciudad y deporte, y Supabase destaca la RLS para aplicaciones multi-inquilino.**20** La RLS permite filtrar datos basándose en un

`tenant_id` (o `city_id`/`sport_id` en este contexto) directamente a nivel de base de datos.**19** Esto significa que el código de la aplicación no necesita añadir manualmente cláusulas

`WHERE` a cada consulta, lo que reduce significativamente el riesgo de fugas de datos (una preocupación importante con los esquemas compartidos) y simplifica el desarrollo.**14** Esta es una decisión de seguridad y arquitectura crítica que aborda directamente la preocupación del usuario.

La RLS impone reglas de acceso directamente a nivel de base de datos, asegurando que los usuarios solo accedan a los datos autorizados, independientemente del método de acceso (API, acceso directo a la base de datos).**14** Para implementarla, se debe habilitar RLS en las tablas relevantes:

`ALTER TABLE table_name ENABLE ROW LEVEL SECURITY;`.**14** Las políticas de RLS definen las condiciones bajo las cuales un usuario puede realizar operaciones (SELECT, INSERT, UPDATE, DELETE).**14** Para vincular al usuario autenticado con sus permisos de

`city_id` y `sport_id`, una política se uniría a la tabla `users`.

Ejemplo de Política RLS (SQL):

**SQL**

- `- Política para la tabla 'tournaments':
-- Los administradores pueden ver todos los torneos en su ciudad asignada.
-- Los Propietarios solo pueden ver los torneos en los que participan sus equipos (requiere una unión más compleja).
-- Los Clientes pueden ver los torneos públicos en su ciudad/deportes seguidos.
-- Política para Administradores (Aislamiento a nivel de ciudad)
CREATE POLICY "Admins can manage tournaments in their city" ON tournaments
FOR ALL TO authenticated
USING ( EXISTS (SELECT 1 FROM users WHERE users.user_id = auth.uid() AND users.role = 'administrador' AND users.city_id = tournaments.city_id)
)
WITH CHECK ( -- Para INSERT/UPDATE, asegurar que solo pueden añadir/modificar en su ciudad EXISTS (SELECT 1 FROM users WHERE users.user_id = auth.uid() AND users.role = 'administrador' AND users.city_id = tournaments.city_id)
);
-- Política para Clientes (Visualización pública con filtro de ciudad/deporte)
CREATE POLICY "Clients can view public tournaments in their city/sport" ON tournaments
FOR SELECT TO authenticated
USING ( tournaments.is_public = TRUE AND -- Asumiendo un flag 'is_public' para torneos públicos EXISTS (SELECT 1 FROM users WHERE users.user_id = auth.uid() AND users.role = 'cliente' AND (users.city_id = tournaments.city_id OR users.city_id IS NULL) -- Los clientes pueden ver los torneos de su ciudad o los torneos públicos globales AND (users.preferred_sport_id = tournaments.sport_id OR users.preferred_sport_id IS NULL) -- Los clientes pueden ver los torneos de su deporte preferido o todos los torneos públicos )
);`

Para roles más complejos como "Propietario" o "Jugador" que necesitan acceder a datos específicos de sus equipos/jugadores, las políticas implicarán uniones a las tablas `team_players` o `tournament_teams`, asegurando que solo vean sus datos asociados.**15**

Es importante destacar la necesidad de un usuario "global" o "del sistema" para tareas administrativas. Si bien la RLS es potente, habrá escenarios en los que el propio sistema (por ejemplo, un trabajo en segundo plano, una herramienta de desarrollo de superadministrador) necesite acceder a datos de todos los inquilinos/deportes. Supabase permite que las políticas de RLS sean omitidas por el propietario del esquema o por roles con el privilegio `bypassrls`.**20** Esto implica que una "función de servicio" o una cuenta de "superadministrador" dedicada (distinta del rol de

`Super Administrador` en los requisitos del usuario, que sigue estando sujeta a RLS por seguridad) con capacidades de `bypassrls` es necesaria para operaciones a nivel de sistema, migraciones de datos e informes globales, asegurando que las operaciones críticas no se vean obstaculizadas por las políticas de RLS destinadas a los usuarios de la aplicación.

### **2.3. Manejo de la Participación de Jugadores en Múltiples Equipos y Deportes**

El sistema debe permitir que un jugador participe en diferentes equipos para diferentes deportes o incluso en diferentes equipos dentro del mismo deporte. La pregunta del usuario sobre un jugador que juega en dos equipos/deportes diferentes resalta un desafío común en el modelado de datos. La clave es separar la entidad `Player` (que representa la identidad del individuo y su perfil central) de su `Participación` en un equipo específico, para un deporte específico, dentro de un torneo específico. Las tablas `team_players` y `player_statistics` son cruciales para esto. Este enfoque permite que un jugador exista una sola vez en el sistema, pero tenga múltiples registros de rendimiento y asociaciones de equipo distintos, reflejando con precisión los escenarios del mundo real en los deportes locales.**17** Este diseño garantiza la integridad de los datos y evita la redundancia.

El esquema propuesto con las tablas `players`, `teams`, `team_players`, `tournaments` y `tournament_teams` proporciona las relaciones de muchos a muchos necesarias. Un registro de `player` representa al individuo. Un registro de `team` representa un equipo específico. `team_players` vincula a un `player` con un `team` (muchos a muchos). `tournament_teams` vincula a un `team` con un `tournament` (muchos a muchos). Es crucial que las `player_statistics` estén vinculadas a `player_id`, `tournament_id` y `sport_id` para rastrear con precisión el rendimiento por jugador y por contexto.**17**

Cuando un "Propietario" registra a un jugador en su equipo para un torneo específico, el sistema crea una entrada en `team_players` (si aún no existe para ese jugador/equipo) y asegura que el equipo esté registrado para el torneo a través de `tournament_teams`. Si un jugador desea jugar en dos equipos diferentes (del mismo deporte o de deportes diferentes), esto es compatible de forma natural con las relaciones de muchos a muchos. La tabla `team_players` permite que un jugador se asocie con múltiples equipos, y `tournament_teams` permite que los equipos participen en múltiples torneos. El sistema simplemente debe permitir el registro, ya que el esquema de la base de datos lo soporta. La clave es que las estadísticas de los jugadores se rastrean contextualmente (por jugador, por torneo, por deporte).**24**

Si un jugador puede estar en varios equipos/deportes, la interfaz de usuario para que los "Propietarios" registren jugadores debe distinguir claramente entre añadir un jugador *existente* a un equipo y añadir un jugador *nuevo* al sistema. De manera similar, los perfiles de los jugadores en el sitio público y en el panel de control deben mostrar estadísticas agregadas de todas sus participaciones, pero también permitir la exploración detallada de estadísticas específicas de un equipo, torneo o deporte. Esto impacta directamente la experiencia del usuario tanto para los administradores como para los usuarios finales, requiriendo un diseño cuidadoso de las funcionalidades de búsqueda, selección y visualización de jugadores.

### **2.4. Optimización del Rendimiento de la Base de Datos: Indexación y Ajuste de Consultas**

Con 100.000 usuarios concurrentes y consultas complejas para estadísticas, el rendimiento de la base de datos es primordial.

**Indexación**:

- **Claves Primarias (PKs) y Claves Foráneas (FKs)**: PostgreSQL las indexa automáticamente, pero es fundamental asegurarse de que se utilicen en las uniones.**26**
- **Cláusulas `WHERE`**: Indexar las columnas utilizadas con frecuencia en las cláusulas `WHERE` (por ejemplo, `city_id`, `sport_id`, `status`, `date`).**26**
- **Cláusulas `ORDER BY`**: Indexar las columnas utilizadas para la ordenación, especialmente con cláusulas `LIMIT` (por ejemplo, `match_date`, `goals_scored` para las tablas de clasificación).**26**
- **Índices Compuestos**: Para consultas que filtran/unen múltiples columnas (por ejemplo, `(city_id, sport_id, status)` en `tournaments`).**26**
- **Índices Parciales**: Para subconjuntos de datos consultados con frecuencia (por ejemplo, `status = 'live'` en `matches`).**26**

**Ajuste de Consultas**:

- **`EXPLAIN`**: Utilizar el comando `EXPLAIN` de PostgreSQL para analizar los planes de ejecución de las consultas e identificar cuellos de botella (por ejemplo, escaneos secuenciales).**26**
- **Pool de Conexiones**: Supabase proporciona Supavisor, un pool de conexiones multi-inquilino para PostgreSQL, esencial para gestionar un gran número de conexiones concurrentes desde el backend de Go.**4**
- **Estadísticas**: Realizar `ANALYZE` periódicamente en las tablas para asegurar que el planificador de consultas tenga estadísticas actualizadas.**26**
- **Evitar la Sobre-indexación**: Los índices aceleran las lecturas pero ralentizan las escrituras. Es importante equilibrar estos factores.**26**

**Monitorización**: Utilizar `pg_stat_statements` para rastrear consultas lentas o ejecutadas con frecuencia.**28**

El pool de conexiones juega un papel fundamental en la escalabilidad de Go/Supabase. Las aplicaciones Go son altamente concurrentes, y cada goroutine puede abrir una conexión a la base de datos. PostgreSQL tiene límites de conexión, y excederlos lleva a errores.**27** Supabase ofrece Supavisor como un pool de conexiones.**4** Esto implica que conectar directamente desde cada solicitud/goroutine de Go a Supabase sin un pool adecuado agotaría rápidamente los límites de conexión y provocaría una degradación del rendimiento o interrupciones. La implementación de un pool de conexiones (a través de Supavisor o un pooler nativo de Go como

`pgx` con `jackc/pgx` **29**) es absolutamente esencial para que el backend de Go gestione eficientemente las conexiones a la base de datos y soporte 100.000 usuarios concurrentes.

La optimización proactiva de consultas es una tarea operativa continua. El rendimiento de la base de datos no es una configuración única; es un proceso continuo. Las herramientas como `EXPLAIN`, `ANALYZE` y `pg_stat_statements` **26** no son solo para uso puntual, sino para diagnóstico y mantenimiento. Esto implica que el equipo de desarrollo debe integrar el monitoreo y la optimización del rendimiento de las consultas en su flujo de trabajo regular de desarrollo y operaciones. Sin un monitoreo y ajuste continuos, el rendimiento se degradará a medida que aumenten el volumen de datos y la actividad de los usuarios, lo que afectará directamente el requisito no funcional de 2 segundos de tiempo de carga.

## **3. Desarrollo de Backend con Go y Echo**

Esta sección se centra en el backend de Go, haciendo hincapié en el diseño de la API, la seguridad y el rendimiento.

### **3.1. Mejores Prácticas de Diseño de API RESTful**

El framework Echo es un framework web de Go de alto rendimiento y extensible, muy adecuado para construir APIs RESTful.**6** Su enrutador optimizado y el soporte de middleware contribuyen a la eficiencia. La estructura de la API debe organizar los endpoints lógicamente, utilizando sustantivos para los recursos y métodos HTTP para las acciones (por ejemplo,

`GET /api/v1/tournaments`, `POST /api/v1/tournaments`).**5** Es crucial implementar una validación robusta de la entrada en el lado del servidor para todas las solicitudes entrantes, con el fin de prevenir datos mal formados y vulnerabilidades de seguridad. Las respuestas deben ser consistentemente en formato JSON, incluyendo los códigos de estado HTTP apropiados para escenarios de éxito y error.**5** Para los endpoints de lista (por ejemplo, obtener todos los torneos, equipos, jugadores), se deben implementar parámetros de consulta para la paginación (

`?page=1&limit=10`), el filtrado (`?city_id=X&sport_id=Y`) y la ordenación (`?sort_by=date&order=desc`).**5**

La necesidad de una especificación de API bien definida desde el principio es fundamental. Un buen diseño de API enfatiza la coherencia, la documentación y el versionado.**7** La creación de una especificación OpenAPI (Swagger) permite un diseño, revisión y generación automática más sencillos del código del servidor Go y los SDKs del cliente.**7** Esto significa que, en lugar de codificar primero y documentar después, definir el contrato de la API de antemano garantizará la coherencia entre los servicios, simplificará la integración del frontend y las aplicaciones móviles, y facilitará el mantenimiento y la extensión de la plataforma a largo plazo. Esto es crucial para una plataforma "profesional y completa".

A continuación, se presenta una matriz de endpoints de API para ilustrar la estructura propuesta:

| Endpoint Path | Método HTTP | Descripción | Rol(es) Requerido(s) | Autenticación Requerida | Autorización Requerida |
| --- | --- | --- | --- | --- | --- |
| `/api/v1/auth/register` | POST | Registra un nuevo usuario (Cliente) | N/A | No | No |
| `/api/v1/auth/login` | POST | Inicia sesión de usuario y devuelve JWT | N/A | No | No |
| `/api/v1/auth/2fa/enroll` | POST | Inicia el proceso de inscripción 2FA | Autenticado | Sí | Sí |
| `/api/v1/auth/2fa/verify` | POST | Verifica el código 2FA durante el inicio de sesión | Autenticado | Sí | Sí |
| `/api/v1/users` | GET | Obtiene la lista de usuarios (filtrado por rol, ciudad, deporte) | Super Administrador, Administrador | Sí | Sí |
| `/api/v1/users/{id}` | GET | Obtiene detalles de un usuario específico | Super Administrador, Administrador, Propietario (propio perfil) | Sí | Sí |
| `/api/v1/users/{id}` | PUT | Actualiza los detalles de un usuario | Super Administrador, Administrador, Propietario (propio perfil) | Sí | Sí |
| `/api/v1/tournaments` | GET | Obtiene la lista de torneos (filtrado por ciudad, deporte, estado) | Todos | No (público), Sí (privado) | No (público), Sí (privado) |
| `/api/v1/tournaments` | POST | Crea un nuevo torneo | Administrador | Sí | Sí |
| `/api/v1/tournaments/{id}` | GET | Obtiene detalles de un torneo específico | Todos | No (público), Sí (privado) | No (público), Sí (privado) |
| `/api/v1/tournaments/{id}/approve` | PUT | Aprueba un torneo pendiente | Administrador | Sí | Sí |
| `/api/v1/teams` | GET | Obtiene la lista de equipos (filtrado por ciudad, deporte, propietario) | Todos | No (público), Sí (privado) | No (público), Sí (privado) |
| `/api/v1/teams` | POST | Crea un nuevo equipo | Propietario | Sí | Sí |
| `/api/v1/teams/{id}/players` | GET | Obtiene la lista de jugadores de un equipo específico | Propietario, Entrenador, Cliente | Sí | Sí |
| `/api/v1/teams/{id}/players` | POST | Añade un jugador a un equipo | Propietario | Sí | Sí |
| `/api/v1/matches` | GET | Obtiene la lista de partidos (filtrado por torneo, equipo, fecha) | Todos | No (público), Sí (privado) | No (público), Sí (privado) |
| `/api/v1/matches/{id}/report` | POST | Envía el informe de un partido (resultados, eventos) | Árbitro | Sí | Sí |
| `/api/v1/players/{id}/statistics` | GET | Obtiene estadísticas de un jugador específico (por torneo/deporte) | Jugador (propio), Cliente, Propietario, Entrenador | Sí | Sí |
| `/api/v1/leaderboards/{sportId}` | GET | Obtiene clasificaciones (goleadores, equipos) por deporte | Todos | No | No |

### **3.2. Implementación de Seguridad Robusta: Autenticación, Autorización (RBAC), 2FA y Prevención de Vulnerabilidades (SQLi, XSS, CSRF)**

Una plataforma "profesional y completa" con diversos roles y componentes públicos requiere un enfoque de seguridad por capas.

Autenticación (AuthN):

Se aprovechará Supabase Auth para el registro de usuarios, el inicio de sesión y la gestión de sesiones, que ofrece varios métodos, incluidos correo electrónico/contraseña, Google OAuth y OTP.30 Supabase Auth emite JWTs (JSON Web Tokens) para los usuarios autenticados.30 El backend de Go, utilizando el framework Echo, validará estos JWTs en las rutas protegidas.32 El JWT contiene información del usuario (por ejemplo,

`auth.uid()`) y puede extenderse con claims personalizados para roles (`role`, `city_id`, `sport_id`).**15**

Para la Autenticación de Doble Factor (2FA), Supabase Auth soporta 2FA basado en TOTP. El flujo de inscripción y desafío puede integrarse en las páginas de inicio de sesión y configuración de la aplicación.**31** Esto es un requisito crítico para Super Administradores y Administradores. Para la gestión de sesiones, se utilizarán JWTs para una autenticación sin estado. Se implementarán tokens de actualización para mantener a los usuarios conectados de forma segura sin necesidad de iniciar sesión con frecuencia.**32** Se asegurará el almacenamiento seguro de los tokens de actualización (en la base de datos, no en memoria) y la rotación de tokens.**32**

Autorización (AuthZ) - Control de Acceso Basado en Roles (RBAC):

Mientras que la RLS maneja la autorización a nivel de fila en la base de datos, el backend de Go implementará RBAC a nivel de API. Esto implica verificar el rol del usuario (a partir de los claims del JWT) contra los permisos requeridos para un endpoint de API específico.32 Se crearán middlewares personalizados de Echo para realizar comprobaciones de roles antes de permitir el acceso a ciertas rutas o grupos de rutas.32 Se definirán roles granulares (Super Administrador, Administrador, Propietario, Entrenador, Árbitro, Jugador, Cliente) y se mapearán a permisos de API específicos.32

La combinación de Supabase RLS (a nivel de base de datos), el middleware JWT de Echo (autenticación a nivel de API), el middleware RBAC personalizado (autorización a nivel de API) y las técnicas estándar de prevención de vulnerabilidades web (consultas parametrizadas, codificación de salida, tokens CSRF) crea una defensa robusta y de múltiples capas. Este enfoque holístico es esencial para proteger los datos deportivos sensibles y la información de los usuarios, especialmente con los diversos roles y los componentes de cara al público.

A continuación, se presenta una matriz de permisos de roles de usuario para una comprensión clara:

| Rol | Crear Usuario (cualquier rol) | Crear Torneo | Aprobar Torneo | Gestionar Equipo | Gestionar Jugador | Gestionar Informe de Partido | Ver Estadísticas (propias) | Ver Estadísticas (todas) | Ver Información Pública | Comprar Suscripción |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| **Super Administrador** | Y | Y | Y | Y | Y | Y | Y | Y | Y | N |
| **Administrador** | N (solo Propietarios, Árbitros, Clientes) | Y | Y | N | N | N | N | Y (su ciudad/deporte) | Y | N |
| **Propietario** | N | N | N | Y (sus equipos) | Y (sus jugadores) | N | N | N | Y | N |
| **Entrenador** | N | N | N | N | N | N | Y (sus jugadores/equipo) | N | Y | N |
| **Árbitro** | N | N | N | N | N | Y | Y (sus partidos) | N | Y | N |
| **Jugador** | N | N | N | N | N | N | Y (propias) | N | Y | N |
| **Cliente** | N | N | N | N | N | N | N | Y | Y | Y |

**Prevención de Vulnerabilidades**:

- **Inyección SQL (SQLi)**: La defensa más efectiva es el uso de consultas parametrizadas. Se utilizará el paquete `database/sql` de Go con marcadores de posición (por ejemplo, `?` o `$1`) en lugar de la concatenación de cadenas para las consultas SQL.**36** Las bibliotecas cliente de Supabase y los ORMs generalmente manejan esto automáticamente, pero las consultas personalizadas en Go deben usar este método. Aunque las consultas parametrizadas son la defensa principal, la sanitización adicional de la entrada (por ejemplo, eliminar/escapar caracteres potencialmente maliciosos) puede añadir una capa de defensa.**36**
- **Cross-Site Scripting (XSS)**: Es crucial codificar los datos en la salida. Se debe asegurar que todos los datos controlables por el usuario que se renderizan en contextos HTML/JavaScript estén correctamente codificados (entidades HTML para HTML, escape Unicode para cadenas JS).**38** También es importante validar estrictamente la entrada al momento de la recepción (por ejemplo, que las URLs comiencen con protocolos seguros, que los valores numéricos sean enteros).**38** El middleware

  `Secure` de Echo establece encabezados de protección XSS (`X-XSS-Protection`, `Content-Security-Policy`).**39**

- **Cross-Site Request Forgery (CSRF)**: Se implementarán tokens CSRF para métodos HTTP que cambian el estado (POST, PUT, DELETE, PATCH). El servidor generará un token único, lo enviará al cliente y lo verificará en solicitudes posteriores.**40** Echo ofrece un middleware

  `CSRF` para manejar la generación y validación de tokens, a menudo utilizando una cookie o un encabezado.**41** Se utilizarán cookies

  `SameSite=Lax` o `Strict` para las cookies de sesión para mitigar algunos ataques CSRF, aunque no es una solución completa.**40**


La seguridad no es una implementación única, sino un compromiso continuo. La necesidad de auditorías de seguridad regulares, sanitización de entradas y actualización de software **36** significa que el equipo de desarrollo debe integrar las prácticas de seguridad en su flujo de trabajo de desarrollo y operaciones. Esto incluye la integración de prácticas de seguridad en el pipeline de CI/CD (por ejemplo, análisis SQL automatizado, análisis de código estático), la realización de pruebas de penetración periódicas y el mantenimiento actualizado de las mejores prácticas de seguridad para Go, React y Supabase. Esta postura proactiva es vital para mantener la integridad de la plataforma y la confianza de los usuarios.

### **3.3. Consideraciones de Concurrencia y Rendimiento en Go**

El modelo de concurrencia de Go, utilizando goroutines (hilos ligeros) y canales (para la comunicación entre goroutines), está diseñado para la concurrencia.**42** Esto convierte a Go en una excelente opción para un backend de alto rendimiento.

La capacidad de Go para manejar la concurrencia es una ventaja natural para el procesamiento de datos deportivos en tiempo real. La necesidad del usuario de actualizaciones de resultados en tiempo real y el procesamiento de estadísticas se alinea perfectamente con las fortalezas de Go en el manejo de alta concurrencia y operaciones con uso intensivo de E/S. Las goroutines y los canales permiten un procesamiento eficiente de numerosas solicitudes concurrentes (por ejemplo, varios árbitros actualizando partidos simultáneamente, muchos usuarios consultando resultados en vivo) sin bloquear el hilo principal. Esta ventaja de diseño inherente de Go soporta directamente el objetivo de 100.000 usuarios concurrentes y la naturaleza en tiempo real de la plataforma.

**Optimización del Rendimiento**:

- **Uso Eficiente de Recursos**: Minimizar las asignaciones de memoria innecesarias, reutilizar objetos con `sync.Pool` y evitar la copia excesiva de slices.**29**
- **Patrones de Concurrencia**: Utilizar canales para la comunicación y primitivas de sincronización (mutexes, wait groups) para proteger los recursos compartidos y coordinar las goroutines.**42**
- **Pools de Workers**: Emplear pools de workers para gestionar un número fijo de goroutines para tareas intensivas en CPU, reduciendo la sobrecarga de la creación/destrucción frecuente de goroutines.**42**
- **Interacciones con la Base de Datos**: Utilizar drivers de base de datos eficientes (por ejemplo, `jackc/pgx` para PostgreSQL) y asegurar un pool de conexiones adecuado (como se discutió en 2.4).**29**
- **Almacenamiento en Caché**: Integrar eficazmente el almacenamiento en caché con Redis (ver Sección 6.1) para reducir la carga de la base de datos.**29**

Aunque Go es performante por defecto, lograr el máximo rendimiento para 100.000 usuarios concurrentes requiere más que solo usar el lenguaje. El perfilado de CPU puede identificar cuellos de botella como llamadas a funciones ineficientes o una recolección de basura excesiva.**29** Esto implica que el equipo de desarrollo debe perfilar regularmente su aplicación Go bajo carga para identificar y optimizar puntos críticos específicos, en lugar de depender solo de las mejores prácticas generales. Este proceso de optimización iterativa es clave para cumplir con los estrictos requisitos de rendimiento (tiempos de carga de 2 segundos).

**Monitorización**: Implementar un registro y métricas robustos (por ejemplo, métricas de Prometheus) para monitorear el rendimiento de la API, el uso de goroutines y la recolección de basura.**7**

## **4. Desarrollo Frontend con React y Vite**

Esta sección se centra en la construcción de un frontend de alto rendimiento, responsivo y fácil de usar, tanto para el panel de control como para las aplicaciones de cara al público.

### **4.1. Técnicas de Optimización del Rendimiento para Aplicaciones a Gran Escala**

Vite ofrece una experiencia de desarrollo rápida con ESM nativo y compilaciones optimizadas con Rollup para producción, incluyendo división automática de código y tree-shaking.**43**

La velocidad de carga de menos de 2 segundos, un requisito no funcional del usuario, depende en gran medida del rendimiento del frontend. Incluso si el backend es rápido, un frontend que tarda en cargar y renderizar negará la experiencia del usuario. Técnicas como la división de código, la carga diferida y la virtualización de listas abordan esto directamente al reducir la cantidad de datos que el navegador necesita descargar y procesar inicialmente, lo que hace que la aplicación se sienta más rápida y receptiva, especialmente en dispositivos móviles y para usuarios con conexiones más lentas. Esto impacta directamente la satisfacción del usuario y la percepción de una plataforma "profesional".

**Estrategias clave de optimización**:

- **Compilación de Producción**: Siempre implementar la compilación de producción minificada de React, ya que las advertencias de desarrollo la hacen más grande y lenta.**44**
- **División de Código y Carga Diferida (Lazy Loading)**: Utilizar `React.lazy` y `Suspense` para cargar dinámicamente componentes (por ejemplo, división a nivel de ruta, componentes grandes) solo cuando sean necesarios, reduciendo el tamaño inicial del paquete y mejorando los tiempos de carga.**43**
- **Virtualización para Listas Largas**: Para mostrar cientos o miles de filas (por ejemplo, listas de jugadores, historiales de partidos), utilizar bibliotecas de "windowing" o "virtualización de listas" como `react-window` o `react-virtualized`. Estas renderizan solo los elementos visibles, conservando recursos y optimizando el rendimiento del desplazamiento.**44**
- **Prevenir Re-renderizaciones Innecesarias**: Utilizar `React.memo`, `useCallback` y `useMemo` para evitar que los componentes se re-rendericen cuando sus props o estados no han cambiado realmente.**44**
- **Optimizar el DOM Virtual**: Dividir los componentes en partes más pequeñas y enfocadas, y asegurar propiedades `key` únicas para los elementos de la lista.**45**
- **Optimización de Imágenes**: Cargar imágenes de forma diferida y optimizar sus tamaños y formatos.
- **Uso de SWC**: Considerar reemplazar Babel por SWC para una compilación más rápida y recargas en caliente.**43**

Vite fue elegido por su rápida experiencia de desarrollo.**43** Sin embargo, algunas prácticas de desarrollo (por ejemplo, plugins excesivos, deshabilitar el almacenamiento en caché del navegador en las herramientas de desarrollo) pueden obstaculizar el rendimiento en producción.**43** Esto implica que, si bien la velocidad de desarrollo es importante, el equipo debe ser disciplinado en la aplicación de optimizaciones específicas para producción y evitar errores comunes para garantizar que la aplicación implementada final cumpla con los objetivos de rendimiento.

**Monitorización**: Utilizar herramientas como `rollup-plugin-visualizer` para analizar el tamaño del paquete e identificar áreas de optimización.**43**

### **4.2. Integración de CDN para una Entrega Eficiente de Activos**

Una Red de Entrega de Contenidos (CDN) almacena en caché los activos estáticos (paquetes JavaScript, CSS, imágenes) geográficamente más cerca de los usuarios, reduciendo la latencia y mejorando los tiempos de carga.**3** Esto es crucial para lograr tiempos de carga de menos de 2 segundos y manejar 100.000 usuarios concurrentes.

La CDN es un componente crítico para el alcance global y el 99.9% de tiempo de actividad. El usuario busca una plataforma "profesional y completa" con un 99.9% de tiempo de actividad garantizado y tiempos de carga inferiores a 2 segundos. Las grandes plataformas como ESPN utilizan CDNs para sus recursos estáticos.**3** Una CDN no solo acelera la entrega de contenido al servir activos desde ubicaciones de borde, sino que también descarga el tráfico del servidor principal, lo que contribuye a una mayor disponibilidad y resiliencia contra picos de tráfico. Esta es una decisión de infraestructura fundamental para una plataforma que apunta a una amplia base de usuarios y alta disponibilidad.

**Configuración de Vite**: Vite puede configurarse para servir activos desde una CDN. Esto implica establecer la opción de configuración `base` a la URL de la CDN para las compilaciones de producción.**48** Para bibliotecas externas,

`rollupOptions.output.paths` puede mapear nombres de módulos a URLs de CDN.**49**

**Implementación**: Para React y otras bibliotecas grandes, se considerará cargarlas desde una CDN como `esm.sh` directamente a través de importaciones `https` en desarrollo, y asegurar que el proceso de compilación de Vite maneje correctamente las rutas de la CDN para producción.**50**

### **4.3. Implementación de Actualizaciones de UI en Tiempo Real**

Las aplicaciones React pueden aprovechar el SDK de JavaScript de Supabase para suscribirse a cambios en tiempo real desde la base de datos PostgreSQL.**11** Cuando los datos cambian en la base de datos (por ejemplo, una actualización de puntuación de partido, un nuevo jugador registrado), Supabase Realtime envía estos cambios a los componentes de React suscritos, que luego se re-renderizan instantáneamente para reflejar los nuevos datos.**11** Los casos de uso incluyen marcadores en vivo, actualizaciones de estadísticas de jugadores en tiempo real y notificaciones instantáneas de eventos de partidos.

Las actualizaciones en tiempo real son un factor clave de la participación y la retención de los usuarios. Para los aficionados al deporte, el acceso inmediato a los resultados y las estadísticas en vivo es primordial. Los ejemplos de la "Premier League", "La Liga" y "ESPN" lo demuestran. Supabase Realtime permite esto directamente.**10** Esto implica que, más allá de simplemente mostrar datos, el aspecto en tiempo real crea una experiencia dinámica e inmersiva que mantiene a los usuarios comprometidos con la plataforma, fomentando la lealtad y convirtiéndola en una fuente de referencia para la información deportiva local.

## **5. Diseño UI/UX para una Experiencia Deportiva Atractiva**

Esta sección describirá los principios de diseño tanto para el panel de administración como para las aplicaciones de cara al público, centrándose en la usabilidad, la claridad y la visualización de datos.

### **5.1. Principios de Diseño del Panel de Control para Administradores y Organizadores de Torneos**

El diseño debe priorizar las necesidades de los Super Administradores, Administradores, Propietarios, Entrenadores y Árbitros. Esto requiere comprender sus flujos de trabajo y puntos débiles.**52** El panel de control es una herramienta de productividad, no solo una pantalla. El usuario describe el panel de control para "gestionar" deportes, torneos, etc. Esto implica una herramienta activa y operativa más que una pantalla pasiva. Los paneles de control efectivos para administradores deben priorizar los datos procesables y los flujos de trabajo optimizados, reduciendo el tiempo y el esfuerzo necesarios para las tareas de gestión.**52** Esto es clave para atraer y retener a los organizadores de torneos en ciudades más pequeñas, ya que resuelve directamente su problema de falta de herramientas de gestión.

**Claridad y Jerarquía Visual**: Presentar información crítica (por ejemplo, torneos activos, aprobaciones pendientes, próximos partidos, estadísticas clave) con una jerarquía visual clara. Utilizar el diseño, el color y la tipografía estratégicamente para guiar la atención.**52**

**Visualización de Datos**:

- **Orientada a un Propósito**: Los paneles de control no solo deben presentar datos, sino también contar una historia, guiando a los usuarios hacia decisiones informadas.**52**
- **Visualizaciones Apropiadas**: Utilizar gráficos de barras para comparaciones, gráficos de líneas para tendencias y otros gráficos relevantes para estadísticas (por ejemplo, rendimiento de jugadores, clasificaciones de equipos).**52**
- **Interactividad**: Implementar funciones de desglose (drill-downs), filtros y vistas personalizadas para permitir a los administradores explorar los datos a su propio ritmo y adaptar el panel a sus necesidades.**52**
- **Información Procesable**: Resaltar las métricas clave y las advertencias que requieren una acción inmediata (por ejemplo, torneos que necesitan aprobación, informes de partidos atrasados).**52**

La importancia de la investigación de usuarios para las herramientas administrativas es crucial. El diseño exitoso de paneles de control comienza con la definición del propósito y las necesidades del usuario.**52** Para los administradores, esto significa comprender sus procesos manuales actuales (hojas de cálculo, llamadas telefónicas) e identificar los puntos débiles.**54** La realización de entrevistas a usuarios y el mapeo de flujos de trabajo con posibles organizadores de torneos y propietarios de equipos serán fundamentales para garantizar que el panel de control aborde realmente sus necesidades y proporcione valor, haciéndolo intuitivo y eficiente.

**Consistencia**: Mantener elementos de diseño, terminología y patrones de interacción consistentes en todo el panel para facilitar su uso.**52**

Minimizar la Carga Cognitiva: Evitar abrumar a los usuarios con demasiada información a la vez. Agrupar el contenido relacionado.52

Responsividad: Asegurar que el panel de control sea utilizable y visualmente atractivo en varios tamaños de pantalla (escritorio, tableta).52

### **5.2. Diseño de Sitio Web y Aplicación Móvil para Usuarios Finales (Aficionados)**

**Navegación Intuitiva**: Diseñar para un acceso fácil a resultados, horarios, perfiles de jugadores e información de torneos.**53**

Actualizaciones en Tiempo Real: Resaltar visualmente los resultados en vivo y las estadísticas en tiempo real, haciéndolos prominentes y fáciles de digerir.57

Características de Participación: Considerar características que fomenten la comunidad, como tablas de clasificación, opciones para compartir en redes sociales y, potencialmente, secciones de comentarios (si se alinea con la visión futura).58

Personalización: Permitir a los usuarios seguir equipos, jugadores o torneos específicos para recibir actualizaciones y contenido personalizado.57

Atractivo Visual: Elaborar diseños visualmente atractivos alineados con la identidad de la marca, utilizando tipografía clara y esquemas de color apropiados (incluyendo modo claro/oscuro).52

Enfoque Mobile-First: Dado que se planea una aplicación móvil, adoptar una estrategia de diseño mobile-first para garantizar una experiencia óptima en pantallas más pequeñas.52

La aplicación móvil es el canal de consumo principal para los aficionados a los deportes locales. El usuario menciona explícitamente una aplicación móvil para "usuarios que siguen estos torneos locales". Dada la naturaleza de los deportes locales (padres, amigos siguiendo los partidos sobre la marcha), la aplicación móvil será probablemente la interfaz más utilizada por los aficionados. Esto implica que la aplicación móvil no debe ser una consideración secundaria, sino un enfoque principal para el diseño de la UI/UX, asegurando que proporcione actualizaciones en tiempo real sin problemas y una experiencia atractiva, incluso antes de que se desarrolle el sitio web público completo.

El "efecto pegajoso" de la comunidad y el contenido personalizado es un factor importante. Las principales aplicaciones deportivas como ESPN se centran en la participación de los aficionados.**13** Funciones como la creación de comunidades, las tablas de clasificación y el contenido personalizado (seguir equipos/jugadores) mejoran la participación y retención de los usuarios.**58** Para los deportes locales, fomentar un sentido de comunidad en torno a los equipos y torneos puede crear un fuerte "efecto pegajoso", convirtiendo a los espectadores ocasionales en usuarios leales y defensores de la plataforma. Esto va más allá de simplemente proporcionar datos; construye una experiencia conectada.

### **5.3. Visualización Eficaz de Datos para Estadísticas Deportivas**

La visualización de datos debe ser limpia, clara y comprensible para usuarios con cualquier nivel de conocimiento en análisis de datos.**56** La visualización de datos es una propuesta de valor clave para los deportes locales. El usuario desea gestionar "goleadores" y proporcionar "estadísticas". Para los deportes locales, las estadísticas bien presentadas pueden mejorar significativamente la experiencia de jugadores, entrenadores y aficionados, proporcionando información que actualmente no está disponible. Esto implica que invertir en visualizaciones de datos de alta calidad no es solo una elección estética, sino una característica central que añade un valor y profesionalismo significativos a la plataforma, diferenciándola de los métodos de gestión locales rudimentarios.

**Contextualización**: Incrustar datos dentro de un contexto (por ejemplo, estadísticas de jugadores comparadas con promedios de liga, rendimiento del equipo a lo largo del tiempo).**60**

Pistas Visuales: Utilizar el color, el tamaño y la posición para resaltar métricas y tendencias clave. Evitar depender únicamente del color para el significado (considerar líneas, rellenos, texturas para la accesibilidad).52

Narración de Datos: Guiar a los usuarios a través de los datos para comprender las tendencias de rendimiento y el progreso.56

Elementos Interactivos: Permitir a los usuarios filtrar, ordenar y profundizar en las estadísticas para obtener información más detallada.52

El equilibrio entre el detalle y la visión general para diferentes tipos de usuarios es importante. Mientras que algunos usuarios (entrenadores, jugadores) pueden desear datos granulares, los aficionados en general podrían preferir visiones generales de alto nivel.**9** El comportamiento de lectura en "patrón F" para las páginas web sugiere colocar los KPI principales en la parte superior.**56** Esto implica que el diseño debe ofrecer tanto vistas resumidas como la capacidad de "profundizar" en estadísticas detalladas, atendiendo a las diversas necesidades de información de los diferentes roles de usuario sin abrumarlos.

## **6. Garantizando Escalabilidad, Fiabilidad y Mantenibilidad**

Esta sección detalla los aspectos operativos críticos para una plataforma robusta y profesional.

### **6.1. Estrategia de Caché con Redis**

El almacenamiento en caché guarda los datos a los que se accede con frecuencia en la memoria, reduciendo la carga de la base de datos y mejorando los tiempos de respuesta.**61** Esto es crucial para lograr tiempos de carga de 2 segundos y manejar 100.000 usuarios concurrentes. Redis es un almacén de datos en memoria adecuado para el almacenamiento en caché, pub/sub y datos en tiempo real.**63**

El almacenamiento en caché es la principal defensa contra los cuellos de botella de la base de datos para operaciones de lectura intensiva. Las plataformas deportivas son inherentemente intensivas en lectura (muchos usuarios viendo resultados, estadísticas, horarios). La base de datos (Supabase) será el cuello de botella para 100.000 usuarios concurrentes si cada lectura la golpea. Redis, al ser un almacén en memoria, proporciona una latencia de sub-milisegundos.**63** Esto implica que el almacenamiento en caché agresivo de datos de cara al público (resultados, horarios, perfiles de jugadores) no es solo una optimización, sino un requisito fundamental para descargar la base de datos y alcanzar los objetivos de rendimiento y escalabilidad.

**Patrones de Caché**:

- **Cache-Aside**: La aplicación primero verifica la caché; si no se encuentra, recupera de la base de datos, actualiza la caché y luego devuelve los datos. Ideal para cargas de trabajo intensivas en lectura.**62**
- **Write-Through**: Los datos se escriben tanto en la caché como en el almacén de datos principal simultáneamente, asegurando la coherencia de la caché. Bueno para datos leídos y actualizados con frecuencia.**62**
- **Write-Behind**: Los datos se escriben en la caché y luego asincrónicamente en la base de datos. Ofrece un mejor rendimiento de escritura, pero un mayor riesgo de pérdida de datos en caso de fallo.**62**
- **Refresh-Ahead**: Actualiza preventivamente los datos en caché antes de que caduquen, evitando retrasos para los usuarios.**62**

**Invalidación de Caché**:

- **Tiempo de Vida (TTL)**: Establecer tiempos de expiración para los elementos en caché.**64**
- **Invalidación/Actualización por Escritura**: Invalidar o actualizar las entradas de caché cuando los datos se modifican en la base de datos principal.**65**
- **Invalidación Basada en Etiquetas**: Para escenarios más complejos, asociar etiquetas con elementos en caché e invalidar todos los elementos con una etiqueta determinada.**65**

La invalidación de caché y la coherencia de los datos representan un desafío. Si bien el almacenamiento en caché mejora el rendimiento, asegurar que los datos en caché no estén obsoletos es un desafío significativo.**65** El usuario desea actualizaciones en tiempo real. Esto implica la necesidad de considerar cuidadosamente las estrategias de invalidación de caché (TTL, write-through/behind, basadas en etiquetas) para equilibrar el rendimiento con la frescura de los datos. Para datos críticos en tiempo real, una combinación de Redis para el almacenamiento en caché y Supabase Realtime para enviar actualizaciones a los clientes es ideal, asegurando la coherencia de los datos para los usuarios.

**Integración con Go**: Utilizar una biblioteca cliente de Redis para Go (por ejemplo, `github.com/go-redis/redis`) para integrar la lógica de caché en el backend de Echo.**66**

### **6.2. Consideraciones de Alta Disponibilidad y Balanceo de Carga**

Alta Disponibilidad (HA): El objetivo es un 99.9% de tiempo de actividad. Esto requiere componentes redundantes y mecanismos de conmutación por error.

Balanceo de Carga: Distribuir el tráfico entrante entre múltiples instancias de servicios de backend (aplicaciones Go Echo) para asegurar que ningún servidor se vea sobrecargado.3

HA de Supabase: Supabase maneja gran parte de la HA y escalabilidad de la base de datos (agrupación de PostgreSQL, réplicas de lectura).4

Beneficios de los Microservicios: La propia arquitectura de microservicios contribuye a la HA, ya que el fallo de un servicio no afecta a toda la aplicación.1

Entorno de Implementación: Considerar proveedores de nube (por ejemplo, AWS, GCP, Azure) que ofrecen servicios gestionados para balanceo de carga, grupos de autoescalado e implementaciones multi-AZ para la resiliencia.

La distribución geográfica es crucial para un rendimiento y resiliencia óptimos. Aunque no se establece explícitamente, una plataforma "profesional y completa" implica servir a usuarios en ubicaciones geográficas potencialmente diversas. Las grandes plataformas como ESPN tienen centros de datos en diferentes ubicaciones.**3** La implementación de una estrategia de implementación multi-región (o al menos el uso de una CDN para activos estáticos, como se discutió) puede reducir significativamente la latencia para usuarios geográficamente dispersos y proporcionar capacidades de recuperación ante desastres, contribuyendo tanto al tiempo de carga de 2 segundos como al requisito de tiempo de actividad del 99.9%.

### **6.3. Monitorización, Registro y Copias de Seguridad Automatizadas**

**Monitorización**: Implementar una monitorización exhaustiva para todos los componentes (servicios de backend, base de datos, caché, frontend). Realizar un seguimiento de métricas clave como tiempos de respuesta, tasas de error, uso de CPU/memoria, conexiones a la base de datos, tasas de aciertos de caché.**7**

Registro (Logging): Centralizar el registro para facilitar la depuración y la auditoría. Registrar acciones críticas (por ejemplo, inicios de sesión de usuarios, modificaciones de datos) para la seguridad y el cumplimiento.7

Copias de Seguridad Automatizadas: Supabase gestiona las copias de seguridad diarias automáticas para su base de datos PostgreSQL [Consulta del Usuario]. Se debe asegurar que esto esté configurado y probado. Para otros componentes (por ejemplo, fotos subidas por los usuarios), implementar estrategias de copia de seguridad separadas.

Alertas: Configurar alertas para problemas críticos (por ejemplo, altas tasas de error, poco espacio en disco, interrupciones del servicio) para permitir una respuesta proactiva.

La observabilidad proactiva es la piedra angular de la excelencia operativa. Lograr un 99.9% de tiempo de actividad y una resolución rápida de problemas requiere más que solo correcciones reactivas. La monitorización y el registro exhaustivos (observabilidad) permiten al equipo identificar la degradación del rendimiento *antes* de que se convierta en una interrupción crítica, comprender rápidamente las causas raíz y garantizar la salud del sistema.**7** Esto implica que invertir en herramientas y prácticas de observabilidad desde el principio es crucial para mantener una plataforma "profesional" y fiable.

## **7. Estrategias de Monetización (Módulo Futuro)**

Esta sección proporcionará recomendaciones de alto nivel para la monetización futura, como se insinúa en la consulta del usuario.

### **7.1. Modelos de Suscripción por Niveles**

Ofrecer diferentes niveles (por ejemplo, Gratuito, Básico, Premium) con distintos niveles de acceso a las funciones.**67**

- **Nivel Gratuito**: Acceso público básico a resultados, horarios (con anuncios).
- **Nivel Básico**: Experiencia sin anuncios, estadísticas más detalladas, capacidad para seguir más equipos/jugadores.
- **Nivel Premium**: Contenido exclusivo, análisis avanzados (por ejemplo, información detallada sobre el rendimiento de los jugadores para entrenadores/ojeadores), soporte prioritario, potencialmente acceso anticipado a nuevas funciones.**67**

La monetización debe ser un valor añadido, no una ocurrencia tardía. El usuario menciona "suscripciones" en los requisitos, lo que indica un futuro módulo de monetización. Los modelos de suscripción exitosos en los medios deportivos ofrecen contenido exclusivo y experiencias mejoradas.**68** Esto implica que la monetización debe integrarse en la estrategia del producto desde las primeras etapas, identificando por qué características "premium" los usuarios (especialmente organizadores de torneos, propietarios de equipos y aficionados dedicados) estarían dispuestos a pagar, en lugar de simplemente colocar anuncios en todo. Esto asegura un modelo de negocio sostenible que se alinea con la propuesta de valor de la plataforma.

### **7.2. Anuncios Dirigidos**

Implementar banners y anuncios de video en la aplicación, especialmente durante momentos clave (por ejemplo, páginas de partidos en vivo).**67** Utilizar los datos del usuario (con consideraciones de privacidad) para personalizar los anuncios y lograr mayores tasas de clics.**67**

### **7.3. Asociaciones y Patrocinios**

Colaborar con marcas deportivas locales, minoristas de equipos o incluso empresas locales para contenido de marca compartida y promociones exclusivas.**67** Ofrecer secciones o características patrocinadas dentro de la plataforma (por ejemplo, "Torneo patrocinado por [Negocio Local X]").**67**

Las asociaciones localizadas son una vía de monetización única para "Mowe Sport". A diferencia de las plataformas globales, Mowe Sport se dirige a "ciudades más pequeñas". Esto presenta una oportunidad única para patrocinios localizados y marketing de afiliación con tiendas deportivas locales, gimnasios o negocios comunitarios.**67** Esto implica que la estrategia de monetización debe aprovechar el enfoque local de la plataforma, creando relaciones simbióticas dentro de la comunidad que beneficien tanto a la plataforma como a las empresas locales, lo que podría conducir a una mayor participación e ingresos que los anuncios genéricos.

## **8. Conclusión y Próximos Pasos Recomendados**

### **8.1. Resumen de Recomendaciones Clave**

Para el éxito de Mowe Sport, se recomienda encarecidamente adoptar una arquitectura modular orientada a microservicios para garantizar la escalabilidad y la mantenibilidad a largo plazo. La Seguridad a Nivel de Fila (RLS) de Supabase, combinada con un esquema de base de datos bien diseñado, será fundamental para implementar un robusto sistema multi-inquilino y de aislamiento de datos, abordando las necesidades específicas de ciudades y deportes. Se debe priorizar el modelo de concurrencia de Go y el uso estratégico de Redis para el almacenamiento en caché, lo cual es vital para lograr un alto rendimiento y tiempos de respuesta rápidos. El diseño de la interfaz de usuario y la experiencia de usuario (UI/UX) debe ser centrado en el usuario, con un énfasis particular en la visualización clara de datos, tanto para el panel de administración como para las aplicaciones de cara al público. Finalmente, la implementación de un enfoque de seguridad por capas y un monitoreo proactivo son esenciales para la fiabilidad y la protección de la plataforma.

### **8.2. Próximos Pasos Accionables**

1. **Diseño Detallado del Esquema de la Base de Datos**: Finalizar el esquema relacional, definiendo explícitamente todas las tablas, columnas, tipos de datos, claves primarias/foráneas e índices. Esto sentará las bases para la integridad y el rendimiento de los datos.
2. **Desarrollo y Pruebas de Políticas RLS**: Desarrollar y probar rigurosamente todas las políticas de RLS en Supabase para garantizar un aislamiento de datos granular para todos los roles y escenarios, validando que se cumplan los requisitos de multi-tenencia.
3. **Definición del Contrato de la API**: Crear una especificación OpenAPI completa para todas las APIs del backend. Esto asegurará la coherencia y facilitará el desarrollo del frontend y las aplicaciones móviles, actuando como un contrato claro entre los servicios.
4. **Prueba de Concepto para Tiempo Real y Caché**: Construir pequeñas pruebas de concepto para validar la integración de Supabase Realtime con React y el almacenamiento en caché de Redis en Go. Estas PoC demostrarán las ganancias de rendimiento esperadas y confirmarán la viabilidad técnica.
5. **Prototipado UI/UX y Pruebas de Usuario**: Desarrollar prototipos de alta fidelidad tanto para el panel de control como para las aplicaciones públicas. Realizar pruebas de usuario con administradores y aficionados de ciudades pequeñas para recopilar comentarios e iterar el diseño, asegurando que la plataforma sea intuitiva y satisfaga las necesidades reales.**52**
6. **Plan de Auditoría de Seguridad**: Elaborar un plan para auditorías de seguridad regulares, revisiones de código y pruebas de penetración. Esto es crucial para identificar y mitigar vulnerabilidades de forma continua.
7. **Pruebas de Escalabilidad**: Planificar pruebas de carga de la plataforma para validar el objetivo de 100.000 usuarios concurrentes una vez que las funcionalidades principales estén implementadas. Esto proporcionará datos concretos sobre el rendimiento bajo carga.
8. **Desarrollo por Fases**: Adoptar un enfoque iterativo, priorizando las funcionalidades principales (gestión de usuarios, creación de torneos, informes básicos de partidos, visualización pública) antes de expandirse a características avanzadas y módulos de monetización.
9. **Desarrollo de Habilidades del Equipo**: Asegurar que el equipo de desarrollo tenga conocimientos sólidos en la concurrencia de Go, la optimización del rendimiento de React y la RLS de Supabase, invirtiendo en capacitación si es necesario.