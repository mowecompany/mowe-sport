import React, { useState } from 'react';
import { Modal, ModalContent, ModalHeader, ModalBody, ModalFooter } from '@heroui/modal';
import { Button } from '@heroui/button';
import { Input } from '@heroui/input';
import { Icon } from '@iconify/react';
import { authService } from '@/services/auth';

interface PasswordChangeModalProps {
  isOpen: boolean;
  onClose: () => void;
  onSuccess: () => void;
  isTemporary?: boolean;
  expiresAt?: Date;
}

export const PasswordChangeModal: React.FC<PasswordChangeModalProps> = ({
  isOpen,
  onClose,
  onSuccess,
  isTemporary = false,
  expiresAt
}) => {
  const [formData, setFormData] = useState({
    current_password: '',
    new_password: '',
    confirm_password: ''
  });
  const [errors, setErrors] = useState<Record<string, string>>({});
  const [isLoading, setIsLoading] = useState(false);
  const [showPasswords, setShowPasswords] = useState({
    current: false,
    new: false,
    confirm: false
  });

  const validateForm = () => {
    const newErrors: Record<string, string> = {};

    if (!formData.current_password) {
      newErrors.current_password = 'Contraseña actual es requerida';
    }

    if (!formData.new_password) {
      newErrors.new_password = 'Nueva contraseña es requerida';
    } else if (formData.new_password.length < 8) {
      newErrors.new_password = 'La contraseña debe tener al menos 8 caracteres';
    } else if (!/(?=.*[a-z])(?=.*[A-Z])(?=.*\d)(?=.*[@$!%*?&])[A-Za-z\d@$!%*?&]/.test(formData.new_password)) {
      newErrors.new_password = 'La contraseña debe incluir mayúsculas, minúsculas, números y símbolos';
    }

    if (!formData.confirm_password) {
      newErrors.confirm_password = 'Confirmación de contraseña es requerida';
    } else if (formData.new_password !== formData.confirm_password) {
      newErrors.confirm_password = 'Las contraseñas no coinciden';
    }

    if (formData.current_password === formData.new_password) {
      newErrors.new_password = 'La nueva contraseña debe ser diferente a la actual';
    }

    setErrors(newErrors);
    return Object.keys(newErrors).length === 0;
  };

  const handleSubmit = async () => {
    if (!validateForm()) return;

    setIsLoading(true);
    try {
      await authService.changePassword(formData);
      
      // Reset form
      setFormData({
        current_password: '',
        new_password: '',
        confirm_password: ''
      });
      setErrors({});
      
      onSuccess();
    } catch (error) {
      console.error('Error changing password:', error);
      
      if (error instanceof Error) {
        if (error.message.includes('current_password') || error.message.includes('incorrect')) {
          setErrors({ current_password: 'La contraseña actual es incorrecta' });
        } else if (error.message.includes('validation')) {
          setErrors({ new_password: 'La nueva contraseña no cumple con los requisitos' });
        } else {
          setErrors({ general: 'Error al cambiar la contraseña. Inténtalo de nuevo.' });
        }
      } else {
        setErrors({ general: 'Error interno del servidor' });
      }
    } finally {
      setIsLoading(false);
    }
  };

  const handleInputChange = (field: string, value: string) => {
    setFormData(prev => ({ ...prev, [field]: value }));
    // Clear error when user starts typing
    if (errors[field]) {
      setErrors(prev => ({ ...prev, [field]: '' }));
    }
  };

  const togglePasswordVisibility = (field: 'current' | 'new' | 'confirm') => {
    setShowPasswords(prev => ({ ...prev, [field]: !prev[field] }));
  };

  const getTimeRemaining = () => {
    if (!expiresAt) return null;
    
    const now = new Date();
    const diff = expiresAt.getTime() - now.getTime();
    
    if (diff <= 0) return 'Expirada';
    
    const hours = Math.floor(diff / (1000 * 60 * 60));
    const minutes = Math.floor((diff % (1000 * 60 * 60)) / (1000 * 60));
    
    if (hours > 0) {
      return `${hours}h ${minutes}m restantes`;
    } else {
      return `${minutes}m restantes`;
    }
  };

  return (
    <Modal 
      isOpen={isOpen} 
      onOpenChange={onClose}
      placement="center"
      size="lg"
      isDismissable={!isTemporary}
      hideCloseButton={isTemporary}
    >
      <ModalContent>
        {(onModalClose) => (
          <>
            <ModalHeader className="flex flex-col gap-1">
              <div className="flex items-center gap-2">
                {isTemporary ? (
                  <div className="p-2 bg-orange-100 rounded-full">
                    <Icon icon="mdi:lock-alert" className="w-6 h-6 text-orange-600" />
                  </div>
                ) : (
                  <div className="p-2 bg-blue-100 rounded-full">
                    <Icon icon="mdi:lock-reset" className="w-6 h-6 text-blue-600" />
                  </div>
                )}
                <div>
                  <h3 className="text-lg font-semibold">
                    {isTemporary ? 'Cambio de Contraseña Requerido' : 'Cambiar Contraseña'}
                  </h3>
                  {isTemporary && (
                    <p className="text-sm text-gray-600 font-normal">
                      Debes cambiar tu contraseña temporal antes de continuar
                    </p>
                  )}
                </div>
              </div>
            </ModalHeader>
            
            <ModalBody>
              <div className="flex flex-col gap-4">
                {isTemporary && expiresAt && (
                  <div className="bg-orange-50 border border-orange-200 rounded-lg p-4">
                    <div className="flex items-start gap-2">
                      <Icon icon="mdi:clock-alert-outline" className="w-5 h-5 text-orange-600 mt-0.5" />
                      <div className="text-sm text-orange-800">
                        <p className="font-medium">Contraseña Temporal</p>
                        <p>Tu contraseña temporal expira pronto: {getTimeRemaining()}</p>
                      </div>
                    </div>
                  </div>
                )}

                {errors.general && (
                  <div className="bg-red-50 border border-red-200 rounded-lg p-3">
                    <div className="flex items-center gap-2">
                      <Icon icon="mdi:alert-circle" className="w-4 h-4 text-red-600" />
                      <span className="text-sm text-red-800">{errors.general}</span>
                    </div>
                  </div>
                )}

                <Input
                  label="Contraseña Actual"
                  placeholder="Ingresa tu contraseña actual"
                  type={showPasswords.current ? 'text' : 'password'}
                  value={formData.current_password}
                  onValueChange={(value) => handleInputChange('current_password', value)}
                  variant="bordered"
                  isInvalid={!!errors.current_password}
                  errorMessage={errors.current_password}
                  startContent={
                    <Icon icon="mdi:lock-outline" className="w-4 h-4 text-gray-400" />
                  }
                  endContent={
                    <button
                      type="button"
                      onClick={() => togglePasswordVisibility('current')}
                      className="focus:outline-none"
                    >
                      <Icon
                        icon={showPasswords.current ? 'mdi:eye-off' : 'mdi:eye'}
                        className="w-4 h-4 text-gray-400 hover:text-gray-600"
                      />
                    </button>
                  }
                />

                <Input
                  label="Nueva Contraseña"
                  placeholder="Ingresa tu nueva contraseña"
                  type={showPasswords.new ? 'text' : 'password'}
                  value={formData.new_password}
                  onValueChange={(value) => handleInputChange('new_password', value)}
                  variant="bordered"
                  isInvalid={!!errors.new_password}
                  errorMessage={errors.new_password}
                  startContent={
                    <Icon icon="mdi:lock-plus-outline" className="w-4 h-4 text-gray-400" />
                  }
                  endContent={
                    <button
                      type="button"
                      onClick={() => togglePasswordVisibility('new')}
                      className="focus:outline-none"
                    >
                      <Icon
                        icon={showPasswords.new ? 'mdi:eye-off' : 'mdi:eye'}
                        className="w-4 h-4 text-gray-400 hover:text-gray-600"
                      />
                    </button>
                  }
                />

                <Input
                  label="Confirmar Nueva Contraseña"
                  placeholder="Confirma tu nueva contraseña"
                  type={showPasswords.confirm ? 'text' : 'password'}
                  value={formData.confirm_password}
                  onValueChange={(value) => handleInputChange('confirm_password', value)}
                  variant="bordered"
                  isInvalid={!!errors.confirm_password}
                  errorMessage={errors.confirm_password}
                  startContent={
                    <Icon icon="mdi:lock-check-outline" className="w-4 h-4 text-gray-400" />
                  }
                  endContent={
                    <button
                      type="button"
                      onClick={() => togglePasswordVisibility('confirm')}
                      className="focus:outline-none"
                    >
                      <Icon
                        icon={showPasswords.confirm ? 'mdi:eye-off' : 'mdi:eye'}
                        className="w-4 h-4 text-gray-400 hover:text-gray-600"
                      />
                    </button>
                  }
                />

                <div className="bg-blue-50 border border-blue-200 rounded-lg p-4">
                  <div className="flex items-start gap-2">
                    <Icon icon="mdi:information-outline" className="w-5 h-5 text-blue-600 mt-0.5" />
                    <div className="text-sm text-blue-800">
                      <p className="font-medium mb-1">Requisitos de Contraseña:</p>
                      <ul className="list-disc list-inside space-y-1">
                        <li>Mínimo 8 caracteres</li>
                        <li>Al menos una letra mayúscula</li>
                        <li>Al menos una letra minúscula</li>
                        <li>Al menos un número</li>
                        <li>Al menos un símbolo (@$!%*?&)</li>
                      </ul>
                    </div>
                  </div>
                </div>
              </div>
            </ModalBody>
            
            <ModalFooter>
              {!isTemporary && (
                <Button
                  color="danger"
                  variant="light"
                  onPress={onModalClose}
                  isDisabled={isLoading}
                >
                  Cancelar
                </Button>
              )}
              <Button
                color="primary"
                onPress={handleSubmit}
                isLoading={isLoading}
                startContent={!isLoading ? <Icon icon="mdi:check" className="w-4 h-4" /> : null}
              >
                {isLoading ? 'Cambiando...' : 'Cambiar Contraseña'}
              </Button>
            </ModalFooter>
          </>
        )}
      </ModalContent>
    </Modal>
  );
};