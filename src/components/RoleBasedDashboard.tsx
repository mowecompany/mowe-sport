import { Card, CardBody, CardHeader } from "@heroui/card";
import { Chip } from "@heroui/chip";
import { Button } from "@heroui/button";
import { Divider } from "@heroui/divider";
import { useAuth } from "@/hooks/useAuth";
import { useNavigate } from "react-router-dom";

import {
  UserGroupIcon,
  TrophyIcon,
  ChartBarIcon,
  Cog6ToothIcon,
  UsersIcon,
  DocumentTextIcon
} from "@heroicons/react/24/outline";

export const RoleBasedDashboard = () => {
  const { user } = useAuth();
  const navigate = useNavigate();

  if (!user) return null;

  const getRoleSpecificContent = () => {
    switch (user.primary_role) {
      case 'super_admin':
        return {
          title: 'Panel de Super Administrador',
          description: 'Gestiona todo el sistema, usuarios y configuraciones globales',
          color: 'danger' as const,
          actions: [
            {
              title: 'Gestionar Usuarios',
              description: 'Ver y gestionar todos los usuarios del sistema',
              icon: <UsersIcon className="w-6 h-6" />,
              path: '/administration/users',
              color: 'primary' as const
            },
            {
              title: 'Gestionar Administradores',
              description: 'Crear y gestionar administradores de ciudad',
              icon: <UsersIcon className="w-6 h-6" />,
              path: '/administration/admins',
              color: 'secondary' as const
            },
            {
              title: 'Configuración Global',
              description: 'Configurar parámetros del sistema',
              icon: <Cog6ToothIcon className="w-6 h-6" />,
              path: '/administration/super_admin',
              color: 'secondary' as const
            },
            {
              title: 'Reportes del Sistema',
              description: 'Ver estadísticas y reportes globales',
              icon: <ChartBarIcon className="w-6 h-6" />,
              path: '/reports/system',
              color: 'success' as const
            }
          ]
        };

      case 'city_admin':
        return {
          title: 'Panel de Administrador de Ciudad',
          description: 'Gestiona torneos, equipos y usuarios en tu ciudad',
          color: 'primary' as const,
          actions: [
            {
              title: 'Gestionar Usuarios',
              description: 'Registrar propietarios, árbitros y gestionar usuarios',
              icon: <UsersIcon className="w-6 h-6" />,
              path: '/administration/users',
              color: 'primary' as const
            },
            {
              title: 'Aprobar Torneos',
              description: 'Revisar y aprobar solicitudes de torneos',
              icon: <TrophyIcon className="w-6 h-6" />,
              path: '/tournaments/approval',
              color: 'warning' as const
            }
          ]
        };

      case 'owner':
        return {
          title: 'Panel de Propietario',
          description: 'Gestiona tus equipos y jugadores',
          color: 'success' as const,
          actions: [
            {
              title: 'Mis Equipos',
              description: 'Gestionar equipos y jugadores',
              icon: <UserGroupIcon className="w-6 h-6" />,
              path: '/main/teams',
              color: 'primary' as const
            },
            {
              title: 'Gestionar Usuarios',
              description: 'Registrar jugadores, entrenadores y gestionar tu equipo',
              icon: <UsersIcon className="w-6 h-6" />,
              path: '/administration/users',
              color: 'success' as const
            },
            {
              title: 'Torneos Disponibles',
              description: 'Ver torneos disponibles para inscripción',
              icon: <TrophyIcon className="w-6 h-6" />,
              path: '/tournaments/available',
              color: 'warning' as const
            }
          ]
        };

      case 'coach':
        return {
          title: 'Panel de Entrenador',
          description: 'Gestiona entrenamientos y estrategias',
          color: 'warning' as const,
          actions: [
            {
              title: 'Mi Equipo',
              description: 'Ver información del equipo asignado',
              icon: <UserGroupIcon className="w-6 h-6" />,
              path: '/team/assigned',
              color: 'primary' as const
            },
            {
              title: 'Estadísticas',
              description: 'Ver estadísticas de jugadores',
              icon: <ChartBarIcon className="w-6 h-6" />,
              path: '/statistics/players',
              color: 'success' as const
            }
          ]
        };

      case 'referee':
        return {
          title: 'Panel de Árbitro',
          description: 'Gestiona partidos y reportes',
          color: 'secondary' as const,
          actions: [
            {
              title: 'Mis Partidos',
              description: 'Ver partidos asignados',
              icon: <TrophyIcon className="w-6 h-6" />,
              path: '/matches/assigned',
              color: 'primary' as const
            },
            {
              title: 'Reportes de Partidos',
              description: 'Crear reportes de partidos',
              icon: <DocumentTextIcon className="w-6 h-6" />,
              path: '/matches/reports',
              color: 'warning' as const
            }
          ]
        };

      case 'player':
        return {
          title: 'Panel de Jugador',
          description: 'Ve tus estadísticas y próximos partidos',
          color: 'success' as const,
          actions: [
            {
              title: 'Mis Estadísticas',
              description: 'Ver tu rendimiento y estadísticas',
              icon: <ChartBarIcon className="w-6 h-6" />,
              path: '/statistics/personal',
              color: 'success' as const
            },
            {
              title: 'Próximos Partidos',
              description: 'Ver calendario de partidos',
              icon: <TrophyIcon className="w-6 h-6" />,
              path: '/matches/upcoming',
              color: 'primary' as const
            }
          ]
        };

      default:
        return {
          title: 'Panel de Usuario',
          description: 'Explora torneos y equipos',
          color: 'default' as const,
          actions: [
            {
              title: 'Explorar Torneos',
              description: 'Ver torneos disponibles',
              icon: <TrophyIcon className="w-6 h-6" />,
              path: '/tournaments/public',
              color: 'primary' as const
            },
            {
              title: 'Ver Equipos',
              description: 'Explorar equipos y jugadores',
              icon: <UserGroupIcon className="w-6 h-6" />,
              path: '/teams/public',
              color: 'success' as const
            }
          ]
        };
    }
  };

  const roleContent = getRoleSpecificContent();

  return (
    <div className="w-full max-w-6xl mx-auto mt-8 space-y-8">
      {/* Role Header */}
      <Card className="mb-6">
        <CardHeader className="flex flex-col items-start">
          <div className="flex items-center gap-3 w-full">
            <div>
              <h2 className="text-2xl font-bold">{roleContent.title}</h2>
              <p className="text-default-500 mt-1">{roleContent.description}</p>
            </div>
            <Chip color={roleContent.color} variant="flat" className="ml-auto">
              {user.primary_role?.replace('_', ' ').toUpperCase()}
            </Chip>
          </div>
        </CardHeader>
      </Card>



      {/* Main Actions */}
      <div>
        <h3 className="text-xl font-semibold mb-4">Acciones Principales</h3>
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
          {roleContent.actions.map((action, index) => (
            <Card key={index} className="hover:shadow-lg transition-shadow cursor-pointer" isPressable>
              <CardBody className="p-6">
                <div className="flex items-start gap-4">
                  <div className="p-3 rounded-lg bg-primary-100 text-primary-600">
                    {action.icon}
                  </div>
                  <div className="flex-1">
                    <h3 className="font-semibold text-lg mb-2">{action.title}</h3>
                    <p className="text-default-500 text-sm mb-4">{action.description}</p>
                    <Button 
                      color={action.color} 
                      variant="flat" 
                      size="sm"
                      onClick={() => navigate(action.path)}
                    >
                      Acceder
                    </Button>
                  </div>
                </div>
              </CardBody>
            </Card>
          ))}
        </div>
      </div>
    </div>
  );
};