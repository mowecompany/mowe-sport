import { Card, CardBody, CardHeader } from "@heroui/card";
import { Button } from "@heroui/button";
import { Switch } from "@heroui/switch";
import { Select, SelectItem } from "@heroui/select";
import { useAuth } from "@/hooks/useAuth";
import { useUserRole } from "@/hooks/useUserRole";
import { title } from "@/components/primitives";
import { ThemeSwitch } from "@/components/theme_switch";
import DefaultLayout from "@/layouts/default";

export default function SettingsPage() {
  const { user, isLoading, forceRefresh } = useAuth();

  // Debug logging
  console.log('SettingsPage - Rendering with:', { user, isLoading });

  if (isLoading) {
    console.log('SettingsPage - Showing loading state');
    return (
      <DefaultLayout>
        <div className="flex items-center justify-center min-h-screen">
          <div className="animate-spin rounded-full h-8 w-8 border-b-2 border-primary"></div>
        </div>
      </DefaultLayout>
    );
  }

  if (!user) {
    console.log('SettingsPage - No user data, showing error state');
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

  console.log('SettingsPage - Rendering with user data:', user);

  // Enhanced role detection for settings access
  let userCapabilities;
  try {
    const roleHook = useUserRole(user.primary_role);
    userCapabilities = roleHook.capabilities;
  } catch (error) {
    console.error('Error with role hook in settings:', error);
    userCapabilities = {
      canExportData: false,
      canDeleteAccount: false,
      label: 'Usuario'
    };
  }

  return (
    <DefaultLayout>
      <section className="flex flex-col items-center justify-center gap-4 py-8 md:py-10">
        <div className="w-full max-w-4xl">
          <h1 className={title()}>Configuración</h1>
          
          <div className="grid grid-cols-1 md:grid-cols-2 gap-6 mt-8">
            {/* Appearance Settings */}
            <Card>
              <CardHeader>
                <h3 className="text-lg font-semibold">Apariencia</h3>
              </CardHeader>
              <CardBody className="space-y-4">
                <div className="flex items-center justify-between">
                  <div>
                    <p className="font-medium">Tema</p>
                    <p className="text-sm text-default-500">Cambiar entre modo claro y oscuro</p>
                  </div>
                  <ThemeSwitch />
                </div>
                
                <div className="border-t border-divider my-2" />
                
                <div className="flex items-center justify-between">
                  <div>
                    <p className="font-medium">Idioma</p>
                    <p className="text-sm text-default-500">Seleccionar idioma de la interfaz</p>
                  </div>
                  <Select
                    size="sm"
                    className="w-32"
                    defaultSelectedKeys={["es"]}
                    isDisabled
                  >
                    <SelectItem key="es">Español</SelectItem>
                    <SelectItem key="en">English</SelectItem>
                  </Select>
                </div>
              </CardBody>
            </Card>

            {/* Security Settings */}
            <Card>
              <CardHeader>
                <h3 className="text-lg font-semibold">Seguridad</h3>
              </CardHeader>
              <CardBody className="space-y-4">
                <div className="flex items-center justify-between">
                  <div>
                    <p className="font-medium">Autenticación de dos factores (2FA)</p>
                    <p className="text-sm text-default-500">
                      {user.two_factor_enabled ? 'Habilitado' : 'Deshabilitado'}
                    </p>
                  </div>
                  <Switch 
                    isSelected={user.two_factor_enabled} 
                    isDisabled
                  />
                </div>
                
                <div className="border-t border-divider my-2" />
                
                <div>
                  <Button variant="bordered" size="sm" isDisabled>
                    Cambiar Contraseña
                  </Button>
                </div>
                
                <div>
                  <Button variant="bordered" size="sm" isDisabled>
                    Ver Sesiones Activas
                  </Button>
                </div>
              </CardBody>
            </Card>

            {/* Notification Settings */}
            <Card>
              <CardHeader>
                <h3 className="text-lg font-semibold">Notificaciones</h3>
              </CardHeader>
              <CardBody className="space-y-4">
                <div className="flex items-center justify-between">
                  <div>
                    <p className="font-medium">Notificaciones por email</p>
                    <p className="text-sm text-default-500">Recibir actualizaciones por correo</p>
                  </div>
                  <Switch defaultSelected isDisabled />
                </div>
                
                <div className="border-t border-divider my-2" />
                
                <div className="flex items-center justify-between">
                  <div>
                    <p className="font-medium">Notificaciones push</p>
                    <p className="text-sm text-default-500">Notificaciones en tiempo real</p>
                  </div>
                  <Switch defaultSelected isDisabled />
                </div>
                
                <div className="border-t border-divider my-2" />
                
                <div className="flex items-center justify-between">
                  <div>
                    <p className="font-medium">Resumen semanal</p>
                    <p className="text-sm text-default-500">Recibir resumen de actividad</p>
                  </div>
                  <Switch isDisabled />
                </div>
              </CardBody>
            </Card>

            {/* Account Settings */}
            <Card>
              <CardHeader>
                <h3 className="text-lg font-semibold">Cuenta</h3>
              </CardHeader>
              <CardBody className="space-y-4">
                <div>
                  <p className="font-medium mb-2">Información de la cuenta</p>
                  <div className="text-sm text-default-500 space-y-1">
                    <p>Usuario desde: {new Date(user.created_at).toLocaleDateString()}</p>
                    <p>Último acceso: {user.last_login_at ? new Date(user.last_login_at).toLocaleDateString() : 'N/A'}</p>
                    <p>Estado: {user.account_status?.toUpperCase() || 'ACTIVO'}</p>
                    <p>Rol: {userCapabilities.label}</p>
                    {user.failed_login_attempts > 0 && (
                      <p>Intentos fallidos: {user.failed_login_attempts}</p>
                    )}
                  </div>
                </div>
                
                <div className="border-t border-divider my-2" />
                
                <div className="space-y-2">
                  {userCapabilities.canExportData && (
                    <Button variant="bordered" size="sm" isDisabled>
                      Exportar Datos
                    </Button>
                  )}
                  {userCapabilities.canDeleteAccount && (
                    <Button variant="bordered" size="sm" color="danger" isDisabled>
                      Eliminar Cuenta
                    </Button>
                  )}
                  {!userCapabilities.canExportData && !userCapabilities.canDeleteAccount && (
                    <p className="text-xs text-default-400">
                      No tienes permisos para realizar acciones de cuenta avanzadas.
                    </p>
                  )}
                </div>
              </CardBody>
            </Card>
          </div>
          
          {/* Info Card */}
          <Card className="mt-6">
            <CardBody>
              <div className="p-4 bg-blue-50 rounded-lg border border-blue-200">
                <p className="text-sm text-blue-700">
                  <strong>Nota:</strong> Muchas de estas configuraciones estarán disponibles en futuras actualizaciones. 
                  Por ahora, solo el cambio de tema está completamente funcional.
                </p>
              </div>
            </CardBody>
          </Card>
        </div>
      </section>
    </DefaultLayout>
  );
}