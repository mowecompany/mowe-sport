import React from 'react';
import { Navigate } from 'react-router-dom';
import { useAuth } from '@/hooks/useAuth';
import { Card, CardBody } from '@heroui/card';
import { Icon } from '@iconify/react';
import type { UserRole } from '@/services/types';

interface ProtectedPageProps {
  children: React.ReactNode;
  allowedRoles: UserRole[];
  fallbackPath?: string;
  showForbidden?: boolean;
}

export const ProtectedPage: React.FC<ProtectedPageProps> = ({
  children,
  allowedRoles,
  fallbackPath = '/dashboard',
  showForbidden = true
}) => {
  const { user, isAuthenticated } = useAuth();

  // Si no está autenticado, redirigir al login
  if (!isAuthenticated || !user) {
    return <Navigate to="/auth/sign-in" replace />;
  }

  // Verificar si el usuario tiene uno de los roles permitidos
  const hasPermission = allowedRoles.includes(user.primary_role as UserRole);

  if (!hasPermission) {
    if (showForbidden) {
      return (
        <div className="min-h-screen flex items-center justify-center bg-gray-50">
          <Card className="max-w-md w-full mx-4">
            <CardBody className="text-center py-8">
              <div className="mb-4">
                <Icon 
                  icon="mdi:lock-outline" 
                  className="w-16 h-16 text-gray-400 mx-auto" 
                />
              </div>
              <h2 className="text-xl font-semibold text-gray-800 mb-2">
                Acceso Restringido
              </h2>
              <p className="text-gray-600 mb-4">
                No tienes permisos para acceder a esta página.
              </p>
              <p className="text-sm text-gray-500 mb-6">
                Tu rol actual: <span className="font-medium">{user.primary_role}</span>
              </p>
              <div className="flex gap-2 justify-center">
                <button
                  onClick={() => window.history.back()}
                  className="px-4 py-2 text-sm bg-gray-100 hover:bg-gray-200 rounded-lg transition-colors"
                >
                  Volver
                </button>
                <button
                  onClick={() => window.location.href = fallbackPath}
                  className="px-4 py-2 text-sm bg-blue-500 hover:bg-blue-600 text-white rounded-lg transition-colors"
                >
                  Ir al Dashboard
                </button>
              </div>
            </CardBody>
          </Card>
        </div>
      );
    }
    return <Navigate to={fallbackPath} replace />;
  }

  return <>{children}</>;
};

// Hook para verificar permisos en componentes
export const usePermissions = () => {
  const { user } = useAuth();

  const hasRole = (allowedRoles: UserRole[]): boolean => {
    if (!user) return false;
    return allowedRoles.includes(user.primary_role as UserRole);
  };

  const canAccess = (requiredRole: UserRole): boolean => {
    if (!user) return false;
    // Super admin puede acceder a todo
    if (user.primary_role === 'super_admin') return true;
    return user.primary_role === requiredRole;
  };

  const canAccessMultiple = (allowedRoles: UserRole[]): boolean => {
    if (!user) return false;
    // Super admin puede acceder a todo
    if (user.primary_role === 'super_admin') return true;
    return allowedRoles.includes(user.primary_role as UserRole);
  };

  return {
    hasRole,
    canAccess,
    canAccessMultiple,
    userRole: user?.primary_role as UserRole,
    isAuthenticated: !!user
  };
};