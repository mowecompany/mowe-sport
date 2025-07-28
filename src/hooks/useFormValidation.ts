import { useState, useCallback } from 'react';
import validator from 'validator';
import { isValidPhoneNumber } from 'libphonenumber-js';

export interface ValidationRule {
  required?: boolean;
  minLength?: number;
  maxLength?: number;
  pattern?: RegExp;
  custom?: (value: any) => string | null;
}

export interface ValidationRules {
  [key: string]: ValidationRule;
}

export interface ValidationErrors {
  [key: string]: string;
}

export interface ValidationState {
  errors: ValidationErrors;
  touched: { [key: string]: boolean };
  isValid: boolean;
  isValidating: boolean;
}

export const useFormValidation = (rules: ValidationRules) => {
  const [validationState, setValidationState] = useState<ValidationState>({
    errors: {},
    touched: {},
    isValid: true,
    isValidating: false
  });

  // Sanitize input to prevent XSS
  const sanitizeInput = useCallback((value: string): string => {
    if (typeof value !== 'string') return '';
    
    // Remove potentially dangerous characters
    return value
      .replace(/<script\b[^<]*(?:(?!<\/script>)<[^<]*)*<\/script>/gi, '')
      .replace(/<[^>]*>/g, '')
      .trim();
  }, []);

  // Validate individual field
  const validateField = useCallback((fieldName: string, value: any): string | null => {
    const rule = rules[fieldName];
    if (!rule) return null;

    // Convert to string and sanitize
    const stringValue = typeof value === 'string' ? sanitizeInput(value) : String(value || '');

    // Required validation
    if (rule.required && (!stringValue || stringValue.length === 0)) {
      return `${fieldName.replace('_', ' ')} es requerido`;
    }

    // Skip other validations if field is empty and not required
    if (!stringValue && !rule.required) {
      return null;
    }

    // Min length validation
    if (rule.minLength && stringValue.length < rule.minLength) {
      return `${fieldName.replace('_', ' ')} debe tener al menos ${rule.minLength} caracteres`;
    }

    // Max length validation
    if (rule.maxLength && stringValue.length > rule.maxLength) {
      return `${fieldName.replace('_', ' ')} no puede tener más de ${rule.maxLength} caracteres`;
    }

    // Pattern validation
    if (rule.pattern && !rule.pattern.test(stringValue)) {
      return `Formato de ${fieldName.replace('_', ' ')} inválido`;
    }

    // Custom validation
    if (rule.custom) {
      return rule.custom(stringValue);
    }

    return null;
  }, [rules, sanitizeInput]);

  // Validate all fields
  const validateForm = useCallback((formData: { [key: string]: any }): boolean => {
    const newErrors: ValidationErrors = {};
    let isFormValid = true;

    Object.keys(rules).forEach(fieldName => {
      const error = validateField(fieldName, formData[fieldName]);
      if (error) {
        newErrors[fieldName] = error;
        isFormValid = false;
      }
    });

    setValidationState(prev => ({
      ...prev,
      errors: newErrors,
      isValid: isFormValid
    }));

    return isFormValid;
  }, [rules, validateField]);

  // Validate single field (for real-time validation)
  const validateSingleField = useCallback((fieldName: string, value: any) => {
    const error = validateField(fieldName, value);
    
    setValidationState(prev => ({
      ...prev,
      errors: {
        ...prev.errors,
        [fieldName]: error || ''
      },
      touched: {
        ...prev.touched,
        [fieldName]: true
      }
    }));

    return !error;
  }, [validateField]);

  // Clear field error
  const clearFieldError = useCallback((fieldName: string) => {
    setValidationState(prev => ({
      ...prev,
      errors: {
        ...prev.errors,
        [fieldName]: ''
      }
    }));
  }, []);

  // Reset validation state
  const resetValidation = useCallback(() => {
    setValidationState({
      errors: {},
      touched: {},
      isValid: true,
      isValidating: false
    });
  }, []);

  // Set validation loading state
  const setValidating = useCallback((isValidating: boolean) => {
    setValidationState(prev => ({
      ...prev,
      isValidating
    }));
  }, []);

  return {
    validationState,
    validateForm,
    validateSingleField,
    clearFieldError,
    resetValidation,
    setValidating,
    sanitizeInput
  };
};

// Predefined validation rules for common fields
export const commonValidationRules = {
  email: {
    required: true,
    custom: (value: string) => {
      if (!validator.isEmail(value)) {
        return 'Formato de email inválido';
      }
      return null;
    }
  },
  
  phone: {
    required: false,
    custom: (value: string) => {
      if (!value) return null;
      
      try {
        if (!isValidPhoneNumber(value)) {
          return 'Formato de teléfono inválido';
        }
        return null;
      } catch {
        return 'Formato de teléfono inválido';
      }
    }
  },
  
  identification: {
    required: false,
    minLength: 5,
    maxLength: 20,
    custom: (value: string) => {
      if (!value) return null;
      
      // Basic identification format validation (numbers and letters)
      const idPattern = /^[A-Za-z0-9\-\.]+$/;
      if (!idPattern.test(value)) {
        return 'La identificación solo puede contener letras, números, guiones y puntos';
      }
      return null;
    }
  },
  
  name: {
    required: true,
    minLength: 2,
    maxLength: 100,
    pattern: /^[a-zA-ZáéíóúÁÉÍÓÚñÑ\s]+$/,
    custom: (value: string) => {
      if (value && value.length < 2) {
        return 'Debe tener al menos 2 caracteres';
      }
      return null;
    }
  },
  
  url: {
    required: false,
    custom: (value: string) => {
      if (!value) return null;
      
      if (!validator.isURL(value, { require_protocol: true })) {
        return 'URL inválida. Debe incluir http:// o https://';
      }
    