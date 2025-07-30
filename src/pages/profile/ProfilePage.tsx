import { Card, CardBody, CardHeader } from "@heroui/card";
import { Avatar } from "@heroui/avatar";
import { Button } from "@heroui/button";
import { Input } from "@heroui/input";
import { Chip } from "@heroui/chip";
import { useAuth } from "@/hooks/useAuth";
import { title } from "@/components/primitives";
import DefaultLayout from "@/layouts/default";

export default function ProfilePage() {
  const { user } = useAuth();

  if (!user) {
    return (
      <DefaultLayout>
        <div className="flex items-center justify-center min-h-screen">
          <div className="animate-spin rounded-full h-8 w-8 border-b-2 border-primary"></div>
        </div>
      </DefaultLayout>
    );
  }

  const userInitials = `${user.first_name?.charAt(0) || ''}${user.last_name?.charAt(0) || ''}`.toUpperCase();
  const fullName = `${user.first_name || ''} ${user.last_name || ''}`.trim();

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
                <h2 className="text-xl font-semibold">{fullName || 'Usuario'}</h2>
                <Chip 
                  color="primary" 
                  variant="flat" 
                  className="mt-2"
                >
                  {user.primary_role?.replace('_', ' ').toUpperCase() || 'USUARIO'}
                </Chip>
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
                    <span className="text-default-500">Estado:</span>
                    <Chip 
                      color={user.account_status === 'active' ? 'success' : 'warning'} 
                      size="sm" 
                      className="ml-2"
                    >
                      {user.account_status?.toUpperCase() || 'ACTIVO'}
                    </Chip>
                  </div>
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
        </div>
      </section>
    </DefaultLayout>
  );
}