import { useEffect } from 'react';
import { useNavigate } from 'react-router-dom';
import { useAuth } from '@/hooks/useAuth';

interface ProtectedRouteProps {
  children: React.ReactNode;
  requireAuth?: boolean;
}

export const ProtectedRoute = ({ children, requireAuth = true }: ProtectedRouteProps) => {
  const navigate = useNavigate();
  const { isAuthenticated, isLoading } = useAuth();

  useEffect(() => {
    if (isLoading) return;

    // Solo redirigir si requiere autenticación y no está autenticado
    if (requireAuth && !isAuthenticated) {
      navigate('/', { replace: true });
    }
  }, [isAuthenticated, requireAuth, navigate, isLoading]);

  // Mostrar loading mientras se verifica la autenticación
  if (isLoading) {
    return (
      <div className="flex items-center justify-center min-h-screen">
        <div className="animate-spin rounded-full h-8 w-8 border-b-2 border-primary"></div>
      </div>
    );
  }

  // Si requiere autenticación y no está autenticado, no renderizar nada
  if (requireAuth && !isAuthenticated) {
    return null;
  }

  return <>{children}</>;
};