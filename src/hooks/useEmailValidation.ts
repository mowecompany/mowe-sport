import { useState, useCallback, useRef } from 'react';
import { debounce } from 'lodash';
import validator from 'validator';
import { adminService } from '@/services/adminService';

interface EmailValidationResult {
  isValid: boolean;
  isChecking: boolean;
  error?: string;
  lastCheckedEmail?: string;
}

export const useEmailValidation = () => {
  const [validationState, setValidationState] = useState<EmailValidationResult>({
    isValid: true,
    isChecking: false
  });

  const abortControllerRef = useRef<AbortController | null>(null);

  const validateEmailUniqueness = useCallback(
    debounce(async (email: string) => {
      // Skip if email is empty
      if (!email?.trim()) {
        setValidationState({ 
          isValid: true, 
          isChecking: false,
          lastCheckedEmail: undefined
        });
        return;
      }

      // Validate format first
      if (!isValidEmailFormat(email)) {
        setValidationState({ 
          isValid: false, 
          isChecking: false,
          error: 'Formato de email inválido',
          lastCheckedEmail: email
        });
        return;
      }

      // Skip if already validated this email
      if (validationState.lastCheckedEmail === email && !validationState.isChecking) {
        return;
      }

      // Cancel previous request if exists
      if (abortControllerRef.current) {
        abortControllerRef.current.abort();
      }

      setValidationState(prev => ({ 
        ...prev, 
        isChecking: true,
        error: undefined
      }));

      try {
        const result = await adminService.validateEmailUniqueness(email);
        
        setValidationState({
          isValid: result.isUnique,
          isChecking: false,
          error: result.isUnique ? undefined : (result.message || 'Este email ya está registrado en el sistema'),
          lastCheckedEmail: email
        });
      } catch (error) {
        console.error('Error validating email:', error);
        setValidationState({
          isValid: false,
          isChecking: false,
          error: 'Error validando email. Verifique su conexión.',
          lastCheckedEmail: email
        });
      }
    }, 500), // Increased debounce time for better UX
    [validationState.lastCheckedEmail]
  );

  const isValidEmailFormat = useCallback((email: string): boolean => {
    if (!email) return false;
    return validator.isEmail(email);
  }, []);

  // Reset validation state
  const resetValidation = useCallback(() => {
    if (abortControllerRef.current) {
      abortControllerRef.current.abort();
    }
    
    setValidationState({
      isValid: true,
      isChecking: false,
      error: undefined,
      lastCheckedEmail: undefined
    });
  }, []);

  // Cancel ongoing validation
  const cancelValidation = useCallback(() => {
    if (abortControllerRef.current) {
      abortControllerRef.current.abort();
    }
    
    setValidationState(prev => ({
      ...prev,
      isChecking: false
    }));
  }, []);

  return {
    validationState,
    validateEmailUniqueness,
    isValidEmailFormat,
    resetValidation,
    cancelValidation
  };
};