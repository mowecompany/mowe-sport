import { Card, CardBody, CardHeader } from "@heroui/card";
import { Avatar } from "@heroui/avatar";
import { Button } from "@heroui/button";
import { Input } from "@heroui/input";
import { Chip } from "@heroui/chip";
import { Badge } from "@heroui/badge";
import { Divider } from "@heroui/divider";
import { useAuth } from "@/hooks/useAuth";
import { useUserRole, useAccountStatus } from "@/hooks/useUserRole";
import { title } from "@/components/primitives";
import { UserDebugInfo } from "@/components/UserDebugInfo";
import DefaultLayout from "@/layouts/default";

export default function ProfilePage() {
  const { user, isLoading, forceRefresh } = useAuth();

  // Debug logging
  console.log('ProfilePage - Rendering with:', { user, isLoading });

  if (isLoading) {
    console.log('ProfilePage - Showing loading state');
    return (
      <DefaultLayout>
        <div className="flex items-center justify-center min-h-screen">
          <div className="animate-spin rounded-full h-8 w-8 border-b-2 border-primary"></div>
        </div>
      </DefaultLayout>
    );
  }

  if (!user) {
    console.log('ProfilePage - No user data, showing error state');
    return (
      <DefaultLayout>
        <div className="flex items-center justify-center min-h-screen">
          <div className="text-center">
            <p className="text-lg text-default-500">No se pudo cargar la información del usuario</p>
            <p className="text-sm text-default-400 mt-2">Por favor, intenta recargar la página</p>
            <Button color="primary" onPress={forceRefresh} className="mt-4">
              Reintentar
            </Button>
          </div>
        </div>
      </DefaultLayout>
    );
  }

  console.log('ProfilePage - Rendering with user data:', user);

  // Debug logging
  console.log('ProfilePage - User data:', user);
  console.log('ProfilePage - first_name:', user.first_name);
  console.log('ProfilePage - last_name:', user.last_name);

  const userInitials = `${user.first_name?.charAt(0) || ''}${user.last_name?.charAt(0) || ''}`.toUpperCase() || 'U';
  const fullName = `${user.first_name || ''} ${user.last_name || ''}`.trim() || 'Usuario';
  
  // Enhanced role detection and formatting
  let roleInfo, accountStatusInfo;
  try {
    const roleHook = useUserRole(user.primary_role);
    roleInfo = roleHook.roleInfo;
    accountStatusInfo = useAccountStatus(user.account_status);
  } catch (error) {
    console.error('Error with role hooks:', error);
    roleInfo = { label: 'Usuario', color: 'default' as const, description: 'Usuario del sistema' };
    accountStatusInfo = { label: 'Activa', color: 'success' as const, description: 'Cuenta activa' };
  }

  // Debug info for development
  const debugInfo = {
    hasFirstName: !!user.first_name,
    hasLastName: !!user.last_name,
    firstName: user.first_name,
    lastName: user.last_name,
    fullName: fullName,
    userInitials: userInitials
  };
  console.log('ProfilePage - Debug info:', debugInfo);

  return (
    <DefaultLayout>
      <section className="flex flex-col items-center justify-center gap-4 py-8 md:py-10">
        <div className="w-full max-w-4xl">
          <h1 className={title()}>Mi Perfil</h1>
          
          <div className="grid grid-cols-1 md:grid-cols-3 gap-6 mt-8">
            {/* Profile Card */}
            <Card className="md:col-span-1">
              <CardHeader className="flex flex-col items-center pb-0">
                <Avatar
                  size="lg"
                  src={user.photo_url || undefined}
                  name={userInitials}
                  className="w-24 h-24 mb-4"
                  showFallback
                />
                <h2 className="text-xl font-semibold">{fullName}</h2>
                <Chip 
                  color={roleInfo.color} 
                  variant="flat" 
                  className="mt-2"
                >
                  {roleInfo.label}
                </Chip>
                <p className="text-xs text-default-400 mt-1 text-center">
                  {roleInfo.description}
                </p>
              </CardHeader>
              <CardBody className="pt-4">
                <div className="space-y-2 text-sm">
                  <div>
                    <span className="text-default-500">Email:</span>
                    <p className="font-medium">{user.email}</p>
                  </div>
                  {user.phone && (
                    <div>
                      <span className="text-default-500">Teléfono:</span>
                      <p className="font-medium">{user.phone}</p>
                    </div>
                  )}
                  {user.identification && (
                    <div>
                      <span className="text-default-500">Identificación:</span>
                      <p className="font-medium">{user.identification}</p>
                    </div>
                  )}
                  <div>
                    <span className="text-default-500">Estado de cuenta:</span>
                    <Chip 
                      color={accountStatusInfo.color} 
                      size="sm" 
                      className="ml-2"
                    >
                      {accountStatusInfo.label}
                    </Chip>
                    <p className="text-xs text-default-400 mt-1">
                      {accountStatusInfo.description}
                    </p>
                  </div>
                  <div>
                    <span className="text-default-500">Cuenta creada:</span>
                    <p className="font-medium">
                      {new Date(user.created_at).toLocaleDateString('es-ES', {
                        year: 'numeric',
                        month: 'long',
                        day: 'numeric'
                      })}
                    </p>
                  </div>
                  {user.last_login_at && (
                    <div>
                      <span className="text-default-500">Último acceso:</span>
                      <p className="font-medium">
                        {new Date(user.last_login_at).toLocaleDateString('es-ES', {
                          year: 'numeric',
                          month: 'long',
                          day: 'numeric',
                          hour: '2-digit',
                          minute: '2-digit'
                        })}
                      </p>
                    </div>
                  )}
                  {user.failed_login_attempts > 0 && (
                    <div>
                      <span className="text-default-500">Intentos fallidos:</span>
                      <Chip 
                        color={user.failed_login_attempts >= 3 ? 'danger' : 'warning'} 
                        size="sm" 
                        className="ml-2"
                      >
                        {user.failed_login_attempts}
                      </Chip>
                    </div>
                  )}
                  {user.locked_until && new Date(user.locked_until) > new Date() && (
                    <div>
                      <span className="text-default-500">Cuenta bloqueada hasta:</span>
                      <p className="font-medium text-danger">
                        {new Date(user.locked_until).toLocaleDateString('es-ES', {
                          year: 'numeric',
                          month: 'long',
                          day: 'numeric',
                          hour: '2-digit',
                          minute: '2-digit'
                        })}
                      </p>
                    </div>
                  )}
                  {user.two_factor_enabled && (
                    <div>
                      <span className="text-default-500">2FA:</span>
                      <Chip color="success" size="sm" className="ml-2">
                        HABILITADO
                      </Chip>
                    </div>
                  )}
                </div>
              </CardBody>
            </Card>

            {/* Edit Profile Form */}
            <Card className="md:col-span-2">
              <CardHeader>
                <h3 className="text-lg font-semibold">Editar Información</h3>
              </CardHeader>
              <CardBody>
                <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
                  <Input
                    label="Nombre"
                    placeholder="Tu nombre"
                    value={user.first_name || ''}
                    variant="bordered"
                    isReadOnly
                  />
                  <Input
                    label="Apellido"
                    placeholder="Tu apellido"
                    value={user.last_name || ''}
                    variant="bordered"
                    isReadOnly
                  />
                  <Input
                    label="Email"
                    placeholder="tu@email.com"
                    value={user.email}
                    variant="bordered"
                    isReadOnly
                  />
                  <Input
                    label="Teléfono"
                    placeholder="Tu teléfono"
                    value={user.phone || ''}
                    variant="bordered"
                    isReadOnly
                  />
                  <Input
                    label="Identificación"
                    placeholder="Tu identificación"
                    value={user.identification || ''}
                    variant="bordered"
                    isReadOnly
                    className="md:col-span-2"
                  />
                </div>
                
                <div className="flex justify-end mt-6 gap-2">
                  <Button variant="bordered">
                    Cancelar
                  </Button>
                  <Button color="primary" isDisabled>
                    Guardar Cambios
                  </Button>
                </div>
                
                <div className="mt-4 p-4 bg-warning-50 rounded-lg border border-warning-200">
                  <p className="text-sm text-warning-700">
                    <strong>Nota:</strong> La edición de perfil estará disponible en una próxima actualización. 
                    Por ahora, contacta al administrador para realizar cambios.
                  </p>
                </div>
              </CardBody>
            </Card>
          </div>
          
          {/* Debug component */}
          <UserDebugInfo />
        </div>
      </section>
    </DefaultLayout>
  );
}