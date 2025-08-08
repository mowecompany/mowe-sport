import { useState, useEffect } from 'react';
import { authService } from '@/services/auth';

interface PasswordStatus {
  is_temporary: boolean;
  requires_change: boolean;
  expires_at?: string;
  is_expired?: boolean;
  time_remaining?: string;
}

export const usePasswordStatus = () => {
  const [passwordStatus, setPasswordStatus] = useState<PasswordStatus | null>(null);
  const [isLoading, setIsLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  const checkPasswordStatus = async () => {
    try {
      setIsLoading(true);
      setError(null);
      
      // First check local storage for quick response
      const requiresChange = authService.requiresPasswordChange();
      const expirationDate = authService.getPasswordExpirationDate();
      
      if (requiresChange) {
        setPasswordStatus({
          is_temporary: true,
          requires_change: true,
          expires_at: expirationDate?.toISOString(),
          is_expired: expirationDate ? new Date() > expirationDate : false
        });
      }

      // Then check with server for accurate status
      const serverStatus = await authService.checkPasswordStatus();
      setPasswordStatus(serverStatus);
      
    } catch (err) {
      console.error('Error checking password status:', err);
      setError(err instanceof Error ? err.message : 'Error checking password status');
      
      // Fallback to local storage data
      const requiresChange = authService.requiresPasswordChange();
      if (requiresChange) {
        const expirationDate = authService.getPasswordExpirationDate();
        setPasswordStatus({
          is_temporary: true,
          requires_change: true,
          expires_at: expirationDate?.toISOString(),
          is_expired: expirationDate ? new Date() > expirationDate : false
        });
      }
    } finally {
      setIsLoading(false);
    }
  };

  const clearPasswordStatus = () => {
    setPasswordStatus(null);
    localStorage.removeItem('requires_password_change');
    localStorage.removeItem('password_expires_at');
  };

  useEffect(() => {
    // Only check if user is authenticated
    if (authService.isAuthenticated()) {
      checkPasswordStatus();
    } else {
      setIsLoading(false);
    }
  }, []);

  // Listen for auth changes
  useEffect(() => {
    const handleAuthChange = () => {
      if (authService.isAuthenticated()) {
        checkPasswordStatus();
      } else {
        setPasswordStatus(null);
        setIsLoading(false);
      }
    };

    window.addEventListener('auth:signed-in', handleAuthChange);
    window.addEventListener('auth:signed-out', handleAuthChange);

    return () => {
      window.removeEventListener('auth:signed-in', handleAuthChange);
      window.removeEventListener('auth:signed-out', handleAuthChange);
    };
  }, []);

  return {
    passwordStatus,
    isLoading,
    error,
    requiresPasswordChange: passwordStatus?.requires_change || false,
    isTemporary: passwordStatus?.is_temporary || false,
    isExpired: passwordStatus?.is_expired || false,
    expiresAt: passwordStatus?.expires_at ? new Date(passwordStatus.expires_at) : null,
    timeRemaining: passwordStatus?.time_remaining,
    checkPasswordStatus,
    clearPasswordStatus
  };
};