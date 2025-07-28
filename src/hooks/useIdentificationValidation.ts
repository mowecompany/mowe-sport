import { useState, useCallback } from 'react';

interface IdentificationValidationResult {
  isValid: boolean;
  error?: string;
  type?: string;
  formattedId?: string;
}

export type CountryCode = 'CO' | 'US' | 'MX' | 'AR' | 'CL' | 'PE' | 'EC' | 'VE';

interface IdentificationRule {
  name: string;
  pattern: RegExp;
  format?: (id: string) => string;
  validate?: (id: string) => boolean;
  errorMessage: string;
}

const identificationRules: Record<CountryCode, IdentificationRule[]> = {
  CO: [
    {
      name: 'Cédula de Ciudadanía',
      pattern: /^\d{6,10}$/,
      format: (id: string) => id.replace(/\B(?=(\d{3})+(?!\d))/g, '.'),
      errorMessage: 'La cédula debe tener entre 6 y 10 dígitos'
    },
    {
      name: 'Cédula de Extranjería',
      pattern: /^[0-9]{6,10}$/,
      errorMessage: 'La cédula de extranjería debe tener entre 6 y 10 dígitos'
    },
    {
      name: 'Pasaporte',
      pattern: /^[A-Z]{2}[0-9]{6,8}$/,
      errorMessage: 'El pasaporte debe tener formato AA123456'
    }
  ],
  US: [
    {
      name: 'Social Security Number',
      pattern: /^\d{3}-?\d{2}-?\d{4}$/,
      format: (id: string) => id.replace(/(\d{3})(\d{2})(\d{4})/, '$1-$2-$3'),
      errorMessage: 'SSN debe tener formato 123-45-6789'
    },
    {
      name: 'Driver License',
      pattern: /^[A-Z0-9]{5,20}$/,
      errorMessage: 'Licencia de conducir inválida'
    }
  ],
  MX: [
    {
      name: 'CURP',
      pattern: /^[A-Z]{4}\d{6}[HM][A-Z]{5}[0-9A-Z]\d$/,
      errorMessage: 'CURP debe tener 18 caracteres en formato válido'
    },
    {
      name: 'RFC',
      pattern: /^[A-Z&Ñ]{3,4}\d{6}[A-V1-9][A-Z1-9][0-9A]$/,
      errorMessage: 'RFC debe tener formato válido'
    }
  ],
  AR: [
    {
      name: 'DNI',
      pattern: /^\d{7,8}$/,
      format: (id: string) => id.replace(/\B(?=(\d{3})+(?!\d))/g, '.'),
      errorMessage: 'DNI debe tener 7 u 8 dígitos'
    }
  ],
  CL: [
    {
      name: 'RUT',
      pattern: /^\d{7,8}-?[0-9K]$/,
      format: (id: string) => {
        const clean = id.replace(/[^0-9K]/g, '');
        return clean.slice(0, -1).replace(/\B(?=(\d{3})+(?!\d))/g, '.') + '-' + clean.slice(-1);
      },
      validate: (id: string) => {
        // RUT validation algorithm
        const clean = id.replace(/[^0-9K]/g, '');
        const number = clean.slice(0, -1);
        const verifier = clean.slice(-1);
        
        let sum = 0;
        let multiplier = 2;
        
        for (let i = number.length - 1; i >= 0; i--) {
          sum += parseInt(number[i]) * multiplier;
          multiplier = multiplier === 7 ? 2 : multiplier + 1;
        }
        
        const remainder = sum % 11;
        const calculatedVerifier = remainder < 2 ? remainder.toString() : (11 - remainder === 10 ? 'K' : (11 - remainder).toString());
        
        return verifier === calculatedVerifier;
      },
      errorMessage: 'RUT inválido'
    }
  ],
  PE: [
    {
      name: 'DNI',
      pattern: /^\d{8}$/,
      errorMessage: 'DNI debe tener 8 dígitos'
    }
  ],
  EC: [
    {
      name: 'Cédula',
      pattern: /^\d{10}$/,
      validate: (id: string) => {
        // Ecuador cedula validation algorithm
        const digits = id.split('').map(Number);
        const province = parseInt(id.substring(0, 2));
        
        if (province < 1 || province > 24) return false;
        
        const coefficients = [2, 1, 2, 1, 2, 1, 2, 1, 2];
        let sum = 0;
        
        for (let i = 0; i < 9; i++) {
          let result = digits[i] * coefficients[i];
          if (result > 9) result -= 9;
          sum += result;
        }
        
        const verifier = sum % 10 === 0 ? 0 : 10 - (sum % 10);
        return verifier === digits[9];
      },
      errorMessage: 'Cédula ecuatoriana inválida'
    }
  ],
  VE: [
    {
      name: 'Cédula',
      pattern: /^[VE]-?\d{7,8}$/,
      format: (id: string) => {
        const clean = id.replace(/[^VE0-9]/g, '');
        return clean.charAt(0) + '-' + clean.slice(1).replace(/\B(?=(\d{3})+(?!\d))/g, '.');
      },
      errorMessage: 'Cédula debe tener formato V-12345678'
    }
  ]
};

export const useIdentificationValidation = (country: CountryCode = 'CO') => {
  const [validationState, setValidationState] = useState<IdentificationValidationResult>({
    isValid: true
  });

  const validateIdentification = useCallback((identification: string): IdentificationValidationResult => {
    // If empty, it's valid (optional field)
    if (!identification?.trim()) {
      return { isValid: true };
    }

    const rules = identificationRules[country];
    if (!rules) {
      return {
        isValid: false,
        error: 'País no soportado para validación de identificación'
      };
    }

    // Try each rule for the country
    for (const rule of rules) {
      if (rule.pattern.test(identification)) {
        // If there's a custom validation function, use it
        if (rule.validate && !rule.validate(identification)) {
          continue;
        }

        return {
          isValid: true,
          type: rule.name,
          formattedId: rule.format ? rule.format(identification) : identification
        };
      }
    }

    // If no rule matched, return error with the first rule's message
    return {
      isValid: false,
      error: rules[0].errorMessage
    };
  }, [country]);

  const validateIdentificationField = useCallback((identification: string) => {
    const result = validateIdentification(identification);
    setValidationState(result);
    return result;
  }, [validateIdentification]);

  const formatIdentification = useCallback((identification: string): string => {
    if (!identification) return '';

    const result = validateIdentification(identification);
    return result.formattedId || identification;
  }, [validateIdentification]);

  const getIdentificationTypes = useCallback((): string[] => {
    const rules = identificationRules[country];
    return rules ? rules.map(rule => rule.name) : [];
  }, [country]);

  return {
    validationState,
    validateIdentification,
    validateIdentificationField,
    formatIdentification,
    getIdentificationTypes
  };
};