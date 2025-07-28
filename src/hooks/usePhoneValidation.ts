import { useState, useCallback } from 'react';
import { parsePhoneNumber, isValidPhoneNumber, CountryCode } from 'libphonenumber-js';

interface PhoneValidationResult {
  isValid: boolean;
  error?: string;
  formattedNumber?: string;
  country?: string;
}

export const usePhoneValidation = (defaultCountry: CountryCode = 'CO') => {
  const [validationState, setValidationState] = useState<PhoneValidationResult>({
    isValid: true
  });

  const validatePhone = useCallback((phoneNumber: string): PhoneValidationResult => {
    // If empty, it's valid (optional field)
    if (!phoneNumber?.trim()) {
      return { isValid: true };
    }

    try {
      // Try to parse the phone number
      const parsed = parsePhoneNumber(phoneNumber, defaultCountry);
      
      if (!parsed) {
        return {
          isValid: false,
          error: 'Número de teléfono inválido'
        };
      }

      // Check if the number is valid
      if (!parsed.isValid()) {
        return {
          isValid: false,
          error: 'Número de teléfono inválido para el país especificado'
        };
      }

      // Additional validation for mobile numbers (optional)
      const numberType = parsed.getType();
      if (numberType && !['MOBILE', 'FIXED_LINE_OR_MOBILE', 'FIXED_LINE'].includes(numberType)) {
        return {
          isValid: false,
          error: 'Por favor ingrese un número de teléfono válido'
        };
      }

      return {
        isValid: true,
        formattedNumber: parsed.formatInternational(),
        country: parsed.country
      };

    } catch (error) {
      return {
        isValid: false,
        error: 'Formato de teléfono inválido'
      };
    }
  }, [defaultCountry]);

  const validatePhoneField = useCallback((phoneNumber: string) => {
    const result = validatePhone(phoneNumber);
    setValidationState(result);
    return result;
  }, [validatePhone]);

  // Format phone number as user types
  const formatPhoneNumber = useCallback((phoneNumber: string): string => {
    if (!phoneNumber) return '';

    try {
      const parsed = parsePhoneNumber(phoneNumber, defaultCountry);
      if (parsed && parsed.isValid()) {
        return parsed.formatInternational();
      }
    } catch (error) {
      // If parsing fails, return original number
    }

    return phoneNumber;
  }, [defaultCountry]);

  // Get country from phone number
  const getCountryFromPhone = useCallback((phoneNumber: string): string | undefined => {
    if (!phoneNumber) return undefined;

    try {
      const parsed = parsePhoneNumber(phoneNumber, defaultCountry);
      return parsed?.country;
    } catch (error) {
      return undefined;
    }
  }, [defaultCountry]);

  // Check if phone number is mobile
  const isMobileNumber = useCallback((phoneNumber: string): boolean => {
    if (!phoneNumber) return false;

    try {
      const parsed = parsePhoneNumber(phoneNumber, defaultCountry);
      if (!parsed || !parsed.isValid()) return false;

      const numberType = parsed.getType();
      return numberType === 'MOBILE' || numberType === 'FIXED_LINE_OR_MOBILE';
    } catch (error) {
      return false;
    }
  }, [defaultCountry]);

  return {
    validationState,
    validatePhone,
    validatePhoneField,
    formatPhoneNumber,
    getCountryFromPhone,
    isMobileNumber
  };
};