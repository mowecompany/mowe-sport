import React, { useEffect, useState } from 'react';
import { usePasswordStatus } from '@/hooks/usePasswordStatus';
import { PasswordChangeModal } from './PasswordChangeModal';
import { useNotification } from '@/hooks/useNotification';

interface PasswordGuardProps {
  children: React.ReactNode;
}

export const PasswordGuard: React.FC<PasswordGuardProps> = ({ children }) => {
  const {
    requiresPasswordChange,
    isTemporary,
    isExpired,
    expiresAt,
    timeRemaining,
    clearPasswordStatus
  } = usePasswordStatus();
  
  const [showPasswordModal, setShowPasswordModal] = useState(false);
  const { showSuccess, showWarning } = useNotification();

  useEffect(() => {
    if (requiresPasswordChange) {
      setShowPasswordModal(true);
      
      if (isExpired) {
        showWarning(
          'Contraseña Expirada',
          'Tu contraseña temporal ha expirado. Debes cambiarla para continuar.'
        );
      } else if (timeRemaining) {
        showWarning(
          'Cambio de Contraseña Requerido',
          `Tu contraseña temporal expira en ${timeRemaining}. Cámbiala ahora para evitar interrupciones.`
        );
      }
    }
  }, [requiresPasswordChange, isExpired, timeRemaining, showWarning]);

  const handlePasswordChangeSuccess = () => {
    clearPasswordStatus();
    setShowPasswordModal(false);
    showSuccess(
      'Contraseña Cambiada',
      'Tu contraseña ha sido cambiada exitosamente. Ya puedes usar la plataforma normalmente.'
    );
  };

  const handleModalClose = () => {
    // Only allow closing if password is not temporary or expired
    if (!isTemporary || !requiresPasswordChange) {
      setShowPasswordModal(false);
    }
  };

  return (
    <>
      {children}
      
      <PasswordChangeModal
        isOpen={showPasswordModal}
        onClose={handleModalClose}
        onSuccess={handlePasswordChangeSuccess}
        isTemporary={isTemporary}
        expiresAt={expiresAt}
      />
    </>
  );
};