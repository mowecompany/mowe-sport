import React, { useState } from 'react';
import { Card, CardBody, CardHeader } from '@heroui/card';
import { Button } from '@heroui/button';
import { Chip } from '@heroui/chip';
import { Divider } from '@heroui/divider';
import { useDisclosure } from '@heroui/modal';
import { Icon } from '@iconify/react';
import { useAuth } from '@/hooks/useAuth';
import { useUserRole } from '@/hooks/useUserRole';
import { UserRegistrationModal } from './UserRegistrationModal';
import type { UserRole } from '@/services/types';
import type { UserRegistrationResponse } from '@/services/userRegistrationService';

// Define hierarchical registration permissions
const REGISTRATION_HIERARCHY: Record<UserRole, {
  canRegister: UserRole[];
  description: string;
  nextLevel?: string;
}> = {
  super_admin: {
    canRegister: ['city_admin'],
    description: 'Como Super Administrador, puedes registrar Administradores de Ciudad que gestionarán deportes en ciudades específicas.',
    nextLevel: 'Los Administradores de Ciudad podrán registrar Propietarios y Árbitros'
  },
  city_admin: {
    canRegister: ['owner', 'referee'],
    description: 'Como Administrador de Ciudad, puedes registrar Propietarios de equipos y Árbitros para tu ciudad y deporte.',
    nextLevel: 'Los Propietarios podrán registrar Jugadores y Entrenadores'
  },
  tournament_admin: {
    canRegister: [],
    description: 'Como Administrador de Torneo, tu rol se enfoca en la gestión de torneos específicos.',
  },
  owner: {
    canRegister: ['player', 'coach'],
    description: 'Como Propietario, puedes registrar Jugadores y Entrenadores para tus equipos.',
  },
  coach: {
    canRegister: [],
    description: 'Como Entrenador, tu rol se enfoca en el entrenamiento y desarrollo de jugadores.',
  },
  referee: {
    canRegister: [],
    description: 'Como Árbitro, tu rol se enfoca en dirigir partidos y mantener el fair play.',
  },
  player: {
    canRegister: [],
    description: 'Como Jugador, tu rol se enfoca en participar en equipos y competiciones.',
  },
  client: {
    canRegister: [],
    description: 'Como Cliente, puedes ver información de torneos, equipos y estadísticas.',
  }
};

const USER_TYPE_CONFIGS = {
  city_admin: {
    title: 'Administrador de Ciudad',
    description: 'Gestiona una ciudad y deporte específico',
    icon: 'mdi:shield-account',
    color: 'warning' as const,
    features: ['Gestión de propietarios', 'Gestión de árbitros', 'Aprobación de torneos']
  },
  owner: {
    title: 'Propietario de Equipo',
    description: 'Gestiona equipos y sus miembros',
    icon: 'mdi:account-tie',
    color: 'primary' as const,
    features: ['Gestión de equipos', 'Registro de jugadores', 'Registro de entrenadores']
  },
  referee: {
    title: 'Árbitro',
    description: 'Dirige partidos y eventos deportivos',
    icon: 'mdi:whistle',
    color: 'secondary' as const,
    features: ['Arbitraje de partidos', 'Registro de eventos', 'Gestión de sanciones']
  },
  player: {
    title: 'Jugador',
    description: 'Participa en equipos y competiciones',
    icon: 'mdi:account-group',
    color: 'success' as const,
    features: ['Participación en equipos', 'Estadísticas personales', 'Historial de partidos']
  },
  coach: {
    title: 'Entrenador',
    description: 'Entrena y desarrolla jugadores',
    icon: 'mdi:account-supervisor',
    color: 'info' as const,
    features: ['Entrenamiento de equipos', 'Desarrollo de tácticas', 'Gestión de entrenamientos']
  }
} as const;

interface HierarchicalRegistrationDashboardProps {
  onRegistrationSuccess?: (userData: UserRegistrationResponse) => void;
}

export const HierarchicalRegistrationDashboard: React.FC<HierarchicalRegistrationDashboardProps> = ({
  onRegistrationSuccess
}) => {
  const { user } = useAuth();
  const { roleInfo } = useUserRole(user?.primary_role);
  const { isOpen, onOpen, onOpenChange } = useDisclosure();
  const [selectedUserType, setSelectedUserType] = useState<UserRole | null>(null);

  if (!user) {
    return null;
  }

  const hierarchy = REGISTRATION_HIERARCHY[user.primary_role];
  const canRegisterUsers = hierarchy.canRegister.length > 0;

  const handleRegistrationClick = (userType: UserRole) => {
    setSelectedUserType(userType);
    onOpen();
  };

  const handleRegistrationSuccess = (userData: UserRegistrationResponse) => {
    onRegistrationSuccess?.(userData);
  };

  return (
    <div className="space-y-6">
      {/* Current Role Info */}
      <Card>
        <CardHeader className="pb-3">
          <div className="flex items-center gap-3">
            <div className={`p-3 bg-${roleInfo.color}-100 rounded-lg`}>
              <Icon 
                icon={
                  user.primary_role === 'super_admin' ? 'mdi:crown' :
                  user.primary_role === 'city_admin' ? 'mdi:shield-account' :
                  user.primary_role === 'owner' ? 'mdi:account-tie' :
                  user.primary_role === 'referee' ? 'mdi:whistle' :
                  user.primary_role === 'coach' ? 'mdi:account-supervisor' :
                  user.primary_role === 'player' ? 'mdi:account-group' :
                  'mdi:account'
                } 
                className={`w-6 h-6 text-${roleInfo.color}-600`} 
              />
            </div>
            <div>
              <h3 className="text-lg font-semibold">{roleInfo.label}</h3>
              <p className="text-sm text-gray-600">{roleInfo.description}</p>
            </div>
          </div>
        </CardHeader>
        <CardBody className="pt-0">
          <p className="text-gray-700 mb-4">{hierarchy.description}</p>
          {hierarchy.nextLevel && (
            <div className="bg-blue-50 border border-blue-200 rounded-lg p-3">
              <div className="flex items-center gap-2">
                <Icon icon="mdi:information" className="w-4 h-4 text-blue-600" />
                <span className="text-sm text-blue-800 font-medium">Jerarquía siguiente:</span>
              </div>
              <p className="text-sm text-blue-700 mt-1">{hierarchy.nextLevel}</p>
            </div>
          )}
        </CardBody>
      </Card>

      {/* Registration Options */}
      {canRegisterUsers ? (
        <div className="space-y-4">
          <div className="flex items-center gap-2">
            <Icon icon="mdi:account-plus" className="w-5 h-5 text-gray-600" />
            <h4 className="text-lg font-semibold">Tipos de Usuario que Puedes Registrar</h4>
          </div>
          
          <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
            {hierarchy.canRegister.map((userType) => {
              const config = USER_TYPE_CONFIGS[userType as keyof typeof USER_TYPE_CONFIGS];
              if (!config) return null;

              return (
                <Card key={userType} className="hover:shadow-md transition-shadow">
                  <CardHeader className="pb-3">
                    <div className="flex items-center justify-between w-full">
                      <div className="flex items-center gap-3">
                        <div className={`p-2 bg-${config.color}-100 rounded-lg`}>
                          <Icon icon={config.icon} className={`w-5 h-5 text-${config.color}-600`} />
                        </div>
                        <div>
                          <h5 className="font-semibold">{config.title}</h5>
                          <p className="text-sm text-gray-600">{config.description}</p>
                        </div>
                      </div>
                      <Chip
                        size="sm"
                        color={config.color}
                        variant="flat"
                      >
                        {userType}
                      </Chip>
                    </div>
                  </CardHeader>
                  <CardBody className="pt-0">
                    <div className="space-y-3">
                      <div>
                        <h6 className="text-sm font-medium text-gray-700 mb-2">Funcionalidades:</h6>
                        <ul className="space-y-1">
                          {config.features.map((feature, index) => (
                            <li key={index} className="flex items-center gap-2 text-sm text-gray-600">
                              <Icon icon="mdi:check-circle" className="w-3 h-3 text-green-500" />
                              {feature}
                            </li>
                          ))}
                        </ul>
                      </div>
                      
                      <Divider />
                      
                      <Button
                        color={config.color}
                        variant="flat"
                        fullWidth
                        startContent={<Icon icon="mdi:plus" className="w-4 h-4" />}
                        onPress={() => handleRegistrationClick(userType)}
                      >
                        Registrar {config.title}
                      </Button>
                    </div>
                  </CardBody>
                </Card>
              );
            })}
          </div>
        </div>
      ) : (
        <Card>
          <CardBody className="text-center py-8">
            <Icon icon="mdi:account-off" className="w-16 h-16 text-gray-400 mx-auto mb-4" />
            <h4 className="text-lg font-semibold text-gray-600 mb-2">Sin Permisos de Registro</h4>
            <p className="text-gray-500">
              Tu rol actual no tiene permisos para registrar otros usuarios en el sistema.
            </p>
            {user.primary_role === 'player' && (
              <div className="mt-4 bg-green-50 border border-green-200 rounded-lg p-3">
                <p className="text-sm text-green-800">
                  Como jugador, tu enfoque está en participar en equipos y mejorar tu rendimiento deportivo.
                </p>
              </div>
            )}
            {user.primary_role === 'coach' && (
              <div className="mt-4 bg-blue-50 border border-blue-200 rounded-lg p-3">
                <p className="text-sm text-blue-800">
                  Como entrenador, tu enfoque está en desarrollar las habilidades de los jugadores y crear estrategias ganadoras.
                </p>
              </div>
            )}
            {user.primary_role === 'referee' && (
              <div className="mt-4 bg-purple-50 border border-purple-200 rounded-lg p-3">
                <p className="text-sm text-purple-800">
                  Como árbitro, tu enfoque está en mantener el fair play y dirigir partidos de manera imparcial.
                </p>
              </div>
            )}
          </CardBody>
        </Card>
      )}

      {/* Registration Modal */}
      {selectedUserType && (
        <UserRegistrationModal
          isOpen={isOpen}
          onOpenChange={onOpenChange}
          userType={selectedUserType}
          onSuccess={handleRegistrationSuccess}
        />
      )}
    </div>
  );
};