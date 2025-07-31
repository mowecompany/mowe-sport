import { useState, useEffect } from 'react';
import { authService } from '@/services/auth';
import type { UserProfile } from '@/services/types';

export const useAuth = () => {
  // Inicializar con los valores actuales inmediatamente para evitar parpadeo
  const [isAuthenticated, setIsAuthenticated] = useState(() => authService.isAuthenticated());
  const [user, setUser] = useState<UserProfile | null>(() => authService.getCurrentUser());
  const [isLoading, setIsLoading] = useState(false);

  useEffect(() => {
    // Función para obtener datos frescos del usuario (solo cuando sea necesario)
    const refreshUserData = async () => {
      if (authService.isAuthenticated()) {
        try {
          setIsLoading(true);
          // Primero usar datos del cache para respuesta inmediata
          const cachedUser = authService.getCurrentUser();
          if (cachedUser) {
            setUser(cachedUser);
            setIsAuthenticated(true);
          }
          
          // Luego obtener datos frescos del servidor (solo si no hay datos en cache)
          if (!cachedUser) {
            const freshUserData = await authService.getCurrentUserFresh();
            setUser(freshUserData);
            setIsAuthenticated(!!freshUserData);
          }
        } catch (error) {
          console.error('Error refreshing user data:', error);
          // En caso de error, usar datos del cache
          const cachedUser = authService.getCurrentUser();
          setUser(cachedUser);
          setIsAuthenticated(!!cachedUser);
        } finally {
          setIsLoading(false);
        }
      } else {
        setUser(null);
        setIsAuthenticated(false);
        setIsLoading(false);
      }
    };

    // Verificar autenticación inicial
    const checkAuth = async () => {
      const authStatus = authService.isAuthenticated();
      const cachedUser = authService.getCurrentUser();
      
      if (authStatus && cachedUser) {
        // Si está autenticado y hay datos en cache, usar esos datos inmediatamente
        setIsAuthenticated(true);
        setUser(cachedUser);
        setIsLoading(false);
      } else if (authStatus) {
        // Si está autenticado pero no hay datos en cache, obtener del servidor
        await refreshUserData();
      } else {
        // Si no está autenticado, limpiar estado
        setIsAuthenticated(false);
        setUser(null);
        setIsLoading(false);
      }
    };

    // Ejecutar check inicial
    checkAuth();

    // Escuchar eventos de autenticación
    const handleSignIn = async () => {
      console.log('handleSignIn called'); // Debug log
      await refreshUserData();
    };

    const handleSignOut = () => {
      console.log('handleSignOut called in useAuth'); // Debug log
      setIsAuthenticated(false);
      setUser(null);
      setIsLoading(false);
    };

    const handleStorageChange = async () => {
      const authStatus = authService.isAuthenticated();
      if (authStatus) {
        await refreshUserData();
      } else {
        setIsAuthenticated(false);
        setUser(null);
      }
    };

    // Agregar event listeners
    window.addEventListener('auth:signed-in', handleSignIn);
    window.addEventListener('auth:signed-out', handleSignOut);
    window.addEventListener('storage', handleStorageChange);

    return () => {
      window.removeEventListener('auth:signed-in', handleSignIn);
      window.removeEventListener('auth:signed-out', handleSignOut);
      window.removeEventListener('storage', handleStorageChange);
    };
  }, []);

  const forceRefresh = async () => {
    console.log('Force refresh called'); // Debug log
    const authStatus = authService.isAuthenticated();
    
    if (authStatus) {
      try {
        setIsLoading(true);
        const freshUserData = await authService.getCurrentUserFresh();
        setUser(freshUserData);
        setIsAuthenticated(!!freshUserData);
      } catch (error) {
        console.error('Error in force refresh:', error);
        const cachedUser = authService.getCurrentUser();
        setUser(cachedUser);
        setIsAuthenticated(!!cachedUser);
      } finally {
        setIsLoading(false);
      }
    } else {
      setIsAuthenticated(false);
      setUser(null);
      setIsLoading(false);
    }
  };

  return {
    isAuthenticated,
    user,
    isLoading,
    signOut: () => {
      authService.signOut();
    },
    forceRefresh
  };
};