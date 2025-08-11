import { useState, useEffect } from 'react';
import { title } from "@/components/primitives";
import DefaultLayout from "@/layouts/default";
import { Button } from '@heroui/button';
import { Card, CardBody, CardHeader } from '@heroui/card';
import { Chip } from '@heroui/chip';
import { Avatar } from '@heroui/avatar';
import { Input } from '@heroui/input';
import { Select, SelectItem } from '@heroui/select';
import { Dropdown, DropdownTrigger, DropdownMenu, DropdownItem } from '@heroui/dropdown';
import { Pagination } from '@heroui/pagination';
import { Spinner } from '@heroui/spinner';
import { Modal, ModalContent, ModalHeader, ModalBody, ModalFooter, useDisclosure } from '@heroui/modal';
import { Icon } from '@iconify/react';
import { useAuth } from '@/hooks/useAuth';
import { useUserRole } from '@/hooks/useUserRole';
import { useNotification } from '@/hooks/useNotification';
import { UserRegistrationModal } from '@/components/UserRegistrationModal';
import {
  userRegistrationService,
  type UserListRequest,
  type UserSummary,
  type UserRegistrationResponse
} from '@/services/userRegistrationService';
import type { UserRole, AccountStatus } from '@/services/types';

// Define what user types each role can register
const REGISTRATION_PERMISSIONS: Record<UserRole, UserRole[]> = {
  super_admin: ['city_admin'],
  city_admin: ['owner', 'referee'],
  tournament_admin: [],
  owner: ['player', 'coach'],
  coach: [],
  referee: [],
  player: [],
  client: []
};


export default function UsersPage() {
  const { user } = useAuth();
  const { roleInfo } = useUserRole(user?.primary_role);
  const { showSuccess, showError } = useNotification();
  const { isOpen: isRegistrationOpen, onOpenChange: onRegistrationOpenChange } = useDisclosure();
  const { isOpen: isConfirmOpen, onOpen: onConfirmOpen, onOpenChange: onConfirmOpenChange } = useDisclosure();

  const [users, setUsers] = useState<UserSummary[]>([]);
  const [loading, setLoading] = useState(true);
  const [selectedUserType] = useState<UserRole | null>(null);
  const [userToDelete, setUserToDelete] = useState<UserSummary | null>(null);
  
  // Filters and pagination
  const [filters, setFilters] = useState<UserListRequest>({
    page: 1,
    limit: 12,
    search: '',
    role: undefined,
    account_status: undefined,
    sort_by: 'created_at',
    sort_order: 'desc'
  });
  
  const [pagination, setPagination] = useState({
    total: 0,
    totalPages: 0,
    hasNext: false,
    hasPrev: false
  });

  // Get allowed registration types for current user
  const allowedRegistrationTypes = user ? REGISTRATION_PERMISSIONS[user.primary_role] || [] : [];

  useEffect(() => {
    loadUsers();
  }, [filters]);

  const loadUsers = async () => {
    setLoading(true);
    try {
      const response = await userRegistrationService.getUsersList(filters);
      setUsers(response.users);
      setPagination({
        total: response.total,
        totalPages: response.total_pages,
        hasNext: response.has_next,
        hasPrev: response.has_prev
      });
    } catch (error) {
      console.error('Error loading users:', error);
      showError('Error', 'Failed to load users');
    } finally {
      setLoading(false);
    }
  };

  const handleRegistrationSuccess = (userData: UserRegistrationResponse) => {
    showSuccess(
      'Usuario Registrado',
      `${userData.first_name} ${userData.last_name} ha sido registrado exitosamente`
    );
    loadUsers();
  };

  const handleDeleteUser = async () => {
    if (!userToDelete) return;

    try {
      await userRegistrationService.updateUserStatus(userToDelete.user_id, 'disabled', 'Deleted by administrator');
      showSuccess('Usuario Eliminado', 'El usuario ha sido deshabilitado exitosamente');
      loadUsers();
      onConfirmOpenChange(false);
      setUserToDelete(null);
    } catch (error) {
      console.error('Error deleting user:', error);
      showError('Error', 'Failed to delete user');
    }
  };

  const handleStatusChange = async (userId: string, newStatus: AccountStatus) => {
    try {
      await userRegistrationService.updateUserStatus(userId, newStatus);
      showSuccess('Estado Actualizado', 'El estado del usuario ha sido actualizado');
      loadUsers();
    } catch (error) {
      console.error('Error updating status:', error);
      showError('Error', 'Failed to update user status');
    }
  };

  const getStatusColor = (status: AccountStatus) => {
    const statusColors = {
      active: 'success',
      suspended: 'danger',
      payment_pending: 'warning',
      disabled: 'default'
    } as const;
    return statusColors[status] || 'default';
  };

  const getStatusLabel = (status: AccountStatus) => {
    const statusLabels = {
      active: 'Activo',
      suspended: 'Suspendido',
      payment_pending: 'Pago Pendiente',
      disabled: 'Deshabilitado'
    };
    return statusLabels[status] || status;
  };

  const getRoleColor = (role: UserRole) => {
    const roleColors = {
      super_admin: 'danger',
      city_admin: 'warning',
      tournament_admin: 'secondary',
      owner: 'primary',
      coach: 'success',
      referee: 'default',
      player: 'success',
      client: 'default'
    } as const;
    return roleColors[role] || 'default';
  };

  const getRoleLabel = (role: UserRole) => {
    const roleLabels = {
      super_admin: 'Super Admin',
      city_admin: 'Admin Ciudad',
      tournament_admin: 'Admin Torneo',
      owner: 'Propietario',
      coach: 'Entrenador',
      referee: 'Árbitro',
      player: 'Jugador',
      client: 'Cliente'
    };
    return roleLabels[role] || role;
  };

  return (
    <DefaultLayout>
      <section className="flex flex-col gap-6 px-4">
        {/* Header */}
        <div className="flex flex-col gap-4">
          <div className="flex flex-col sm:flex-row gap-4 justify-between items-start sm:items-center">
            <div className="flex gap-2 sm:items-center">
              <h1 className={title()}>Usuarios</h1>
              <div className="p-2 bg-blue-100 rounded-lg">
                <Icon icon="mdi:account-group" className="w-6 h-6 text-blue-500" />
              </div>
            </div>
          </div>

          <div className="flex flex-col gap-1">
            <h2 className="text-xl font-semibold">Gestión Jerárquica de Usuarios</h2>
            <p className="text-gray-600">
              Como {roleInfo.label}, puedes registrar: {allowedRegistrationTypes.length > 0 
                ? allowedRegistrationTypes.map(type => getRoleLabel(type)).join(', ')
                : 'Ningún tipo de usuario'
              }
            </p>
          </div>

          {/* Filters */}
          <div className="flex flex-col sm:flex-row gap-4 justify-between items-start sm:items-center">
            <div className="flex gap-2 flex-wrap">
              <Input
                placeholder="Buscar usuarios..."
                startContent={<Icon icon="mdi:magnify" className="w-4 h-4 text-gray-400" />}
                className="max-w-xs"
                variant="bordered"
                value={filters.search}
                onValueChange={(value) => setFilters(prev => ({ ...prev, search: value, page: 1 }))}
              />

              <Select
                placeholder="Filtrar por rol"
                className="max-w-xs"
                variant="bordered"
                selectedKeys={filters.role ? [filters.role] : []}
                onSelectionChange={(keys) => {
                  const role = Array.from(keys)[0] as UserRole;
                  setFilters(prev => ({ ...prev, role: role || undefined, page: 1 }));
                }}
              >
                <SelectItem key="city_admin">Admin</SelectItem>
                <SelectItem key="owner">Propietario</SelectItem>
                <SelectItem key="referee">Árbitro</SelectItem>
                <SelectItem key="player">Jugador</SelectItem>
                <SelectItem key="coach">Entrenador</SelectItem>
              </Select>

              <Select
                placeholder="Filtrar por estado"
                className="max-w-xs"
                variant="bordered"
                selectedKeys={filters.account_status ? [filters.account_status] : []}
                onSelectionChange={(keys) => {
                  const status = Array.from(keys)[0] as AccountStatus;
                  setFilters(prev => ({ ...prev, account_status: status || undefined, page: 1 }));
                }}
              >
                <SelectItem key="active">Activo</SelectItem>
                <SelectItem key="suspended">Suspendido</SelectItem>
                <SelectItem key="payment_pending">Pago Pendiente</SelectItem>
                <SelectItem key="disabled">Deshabilitado</SelectItem>
              </Select>
            </div>

            <Button
              variant="bordered"
              startContent={<Icon icon="mdi:refresh" className="w-4 h-4" />}
              onPress={loadUsers}
              isLoading={loading}
            >
              Actualizar
            </Button>
          </div>
        </div>

        {/* Users Grid */}
        {loading ? (
          <div className="flex justify-center items-center py-12">
            <Spinner size="lg" />
          </div>
        ) : users.length === 0 ? (
          <Card className="py-12">
            <CardBody className="text-center">
              <Icon icon="mdi:account-off" className="w-16 h-16 text-gray-400 mx-auto mb-4" />
              <h3 className="text-lg font-semibold text-gray-600 mb-2">No hay usuarios</h3>
              <p className="text-gray-500">
                {allowedRegistrationTypes.length > 0 
                  ? 'Comienza registrando tu primer usuario usando los botones de arriba'
                  : 'No tienes permisos para registrar usuarios'
                }
              </p>
            </CardBody>
          </Card>
        ) : (
          <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4 gap-4">
            {users.map((user) => (
              <Card key={user.user_id} className="p-4">
                <CardHeader className="flex justify-between items-start p-0 pb-3">
                  <div className="flex items-center gap-3">
                    <Avatar
                      src={user.photo_url}
                      name={`${user.first_name} ${user.last_name}`}
                      size="md"
                    />
                    <div>
                      <h3 className="font-semibold text-sm">
                        {user.first_name} {user.last_name}
                      </h3>
                      <Chip
                        size="sm"
                        color={getRoleColor(user.primary_role)}
                        variant="flat"
                      >
                        {getRoleLabel(user.primary_role)}
                      </Chip>
                    </div>
                  </div>
                  
                  <Dropdown>
                    <DropdownTrigger>
                      <Button
                        isIconOnly
                        variant="light"
                        size="sm"
                      >
                        <Icon icon="mdi:dots-vertical" className="w-4 h-4" />
                      </Button>
                    </DropdownTrigger>
                    <DropdownMenu>
                      <DropdownItem key="view">Ver Detalles</DropdownItem>
                      <DropdownItem key="edit">Editar</DropdownItem>
                      <DropdownItem 
                        key="suspend"
                        className="text-warning"
                        onPress={() => handleStatusChange(user.user_id, 'suspended')}
                      >
                        Suspender
                      </DropdownItem>
                      <DropdownItem 
                        key="activate"
                        onPress={() => handleStatusChange(user.user_id, 'active')}
                      >
                        Activar
                      </DropdownItem>
                      <DropdownItem 
                        key="delete" 
                        className="text-danger"
                        onPress={() => {
                          setUserToDelete(user);
                          onConfirmOpen();
                        }}
                      >
                        Eliminar
                      </DropdownItem>
                    </DropdownMenu>
                  </Dropdown>
                </CardHeader>

                <CardBody className="p-0 gap-3">
                  <div className="flex flex-col gap-2 text-sm">
                    <div className="flex items-center gap-2">
                      <Icon icon="mdi:email-outline" className="w-4 h-4 text-gray-500" />
                      <span className="text-gray-700 truncate">{user.email}</span>
                    </div>
                    {user.phone && (
                      <div className="flex items-center gap-2">
                        <Icon icon="mdi:phone-outline" className="w-4 h-4 text-gray-500" />
                        <span className="text-gray-700">{user.phone}</span>
                      </div>
                    )}
                    <div className="flex items-center gap-2">
                      <Icon icon="mdi:calendar-outline" className="w-4 h-4 text-gray-500" />
                      <span className="text-gray-700">
                        {new Date(user.created_at).toLocaleDateString()}
                      </span>
                    </div>
                    {user.city_name && (
                      <div className="flex items-center gap-2">
                        <Icon icon="mdi:map-marker-outline" className="w-4 h-4 text-gray-500" />
                        <span className="text-gray-700 truncate">{user.city_name}</span>
                      </div>
                    )}
                  </div>

                  <div className="flex justify-between items-center pt-2">
                    <Chip
                      size="sm"
                      color={getStatusColor(user.account_status)}
                      variant="flat"
                    >
                      {getStatusLabel(user.account_status)}
                    </Chip>
                    {user.last_login_at && (
                      <span className="text-xs text-gray-500">
                        Último acceso: {new Date(user.last_login_at).toLocaleDateString()}
                      </span>
                    )}
                  </div>
                </CardBody>
              </Card>
            ))}
          </div>
        )}

        {/* Pagination */}
        {pagination.totalPages > 1 && (
          <div className="flex flex-col sm:flex-row gap-4 justify-between items-center pt-4">
            <div className="flex items-center gap-4">
              <span className="text-sm text-gray-600">
                {pagination.total} usuarios encontrados
              </span>
              <div className="flex items-center gap-2">
                <span className="text-sm">Usuarios por página</span>
                <Select
                  size="sm"
                  className="w-20"
                  selectedKeys={[filters.limit?.toString() || '12']}
                  onSelectionChange={(keys) => {
                    const limit = parseInt(Array.from(keys)[0] as string);
                    setFilters(prev => ({ ...prev, limit, page: 1 }));
                  }}
                >
                  <SelectItem key="12">12</SelectItem>
                  <SelectItem key="24">24</SelectItem>
                  <SelectItem key="48">48</SelectItem>
                </Select>
              </div>
            </div>

            <Pagination
              total={pagination.totalPages}
              page={filters.page || 1}
              onChange={(page) => setFilters(prev => ({ ...prev, page }))}
              size="sm"
              showControls
            />
          </div>
        )}

        {/* Registration Modal */}
        {selectedUserType && (
          <UserRegistrationModal
            isOpen={isRegistrationOpen}
            onOpenChange={onRegistrationOpenChange}
            userType={selectedUserType}
            onSuccess={handleRegistrationSuccess}
          />
        )}

        {/* Delete Confirmation Modal */}
        <Modal isOpen={isConfirmOpen} onOpenChange={onConfirmOpenChange}>
          <ModalContent>
            {(onClose) => (
              <>
                <ModalHeader className="flex flex-col gap-1">
                  <h3 className="text-lg font-semibold">Confirmar Eliminación</h3>
                </ModalHeader>
                <ModalBody>
                  <p>
                    ¿Estás seguro de que deseas eliminar a{' '}
                    <strong>
                      {userToDelete?.first_name} {userToDelete?.last_name}
                    </strong>
                    ?
                  </p>
                  <p className="text-sm text-gray-600">
                    Esta acción deshabilitará la cuenta del usuario. Podrás reactivarla más tarde si es necesario.
                  </p>
                </ModalBody>
                <ModalFooter>
                  <Button color="default" variant="light" onPress={onClose}>
                    Cancelar
                  </Button>
                  <Button color="danger" onPress={handleDeleteUser}>
                    Eliminar Usuario
                  </Button>
                </ModalFooter>
              </>
            )}
          </ModalContent>
        </Modal>
      </section>
    </DefaultLayout>
  );
}
