import { useState, useEffect } from 'react';
import { authService } from '@/services/auth';
import type { UserProfile } from '@/services/types';

export const useAuth = () => {
  const [isAuthenticated, setIsAuthenticated] = useState(authService.isAuthenticated());
  const [user, setUser] = useState<UserProfile | null>(authService.getCurrentUser());
  const [isLoading, setIsLoading] = useState(true);

  useEffect(() => {
    // Verificar autenticación inicial
    const checkAuth = () => {
      const authStatus = authService.isAuthenticated();
      const currentUser = authService.getCurrentUser();
      
      setIsAuthenticated(authStatus);
      setUser(currentUser);
      setIsLoading(false);
    };

    checkAuth();

    // Escuchar eventos de autenticación
    const handleSignIn = () => {
      console.log('handleSignIn called'); // Debug log
      const authStatus = authService.isAuthenticated();
      const currentUser = authService.getCurrentUser();
      
      console.log('Auth status after sign in:', authStatus); // Debug log
      console.log('Current user after sign in:', currentUser); // Debug log
      
      setIsAuthenticated(authStatus);
      setUser(currentUser);
    };

    const handleSignOut = () => {
      setIsAuthenticated(false);
      setUser(null);
    };

    const handleStorageChange = () => {
      const authStatus = authService.isAuthenticated();
      const currentUser = authService.getCurrentUser();
      
      setIsAuthenticated(authStatus);
      setUser(currentUser);
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

  return {
    isAuthenticated,
    user,
    isLoading,
    signOut: () => {
      authService.signOut();
    }
  };
};