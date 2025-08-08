import React, { useState, useEffect } from 'react';
import { Modal, ModalContent, ModalHeader, ModalBody, ModalFooter, useDisclosure } from '@heroui/modal';
import { Button } from '@heroui/button';
import { Input } from '@heroui/input';
import { Select, SelectItem } from '@heroui/select';
import { Textarea } from '@heroui/input';
import { Card, CardBody } from '@heroui/card';
import { Chip } from '@heroui/chip';
import { Divider } from '@heroui/divider';
import { Icon } from '@iconify/react';
import { useAuth } from '@/hooks/useAuth';
import { useNotification } from '@/hooks/useNotification';
import { useFormValidation } from '@/hooks/useFormValidation';
import { useEmailValidation } from '@/hooks/useEmailValidation';
import { usePhoneValidation } from '@/hooks/usePhoneValidation';
import { useIdentificationValidation } from '@/hooks/useIdentificationValidation';
import {
  userRegistrationService,
  type BaseUserRegistrationData,
  type CityAdminRegistrationData,
  type OwnerRegistrationData,
  type RefereeRegistrationData,
  type PlayerRegistrationData,
  type CoachRegistrationData,
  type UserRegistrationResponse
} from '@/services/userRegistrationService';
import { citiesService, sportsService } from '@/services';
import type { UserRole, City, Sport, AccountStatus } from '@/services/types';
import { ValidationHelp } from './ValidationHelp';
import { FormValidationProgress } from './FormValidationProgress';

interface UserRegistrationModalProps {
  isOpen: boolean;
  onOpenChange: (open: boolean) => void;
  userType: UserRole;
  onSuccess?: (userData: UserRegistrationResponse) => void;
}

interface FormData extends BaseUserRegistrationData {
  city_id?: string;
  sport_id?: string;
  date_of_birth?: string;
  blood_type?: string;
  emergency_contact_name?: string;
  emergency_contact_phone?: string;
  emergency_contact_relationship?: string;
  medical_allergies?: string;
  medical_medications?: string;
  medical_conditions?: string;
  position?: string;
  jersey_number?: string;
  certification_level?: string;
  experience_years?: string;
  specialization?: string;
}

const USER_TYPE_CONFIG = {
  city_admin: {
    title: 'Registrar Administrador de Ciudad',
    description: 'Crear un nuevo administrador para gestionar una ciudad y deporte específico',
    icon: 'mdi:shield-account',
    color: 'warning' as const,
    requiresCityAndSport: true,
    fields: ['basic', 'location']
  },
  owner: {
    title: 'Registrar Propietario de Equipo',
    description: 'Crear un nuevo propietario que podrá gestionar equipos y jugadores',
    icon: 'mdi:account-tie',
    color: 'primary' as const,
    requiresCityAndSport: true,
    fields: ['basic', 'location']
  },
  referee: {
    title: 'Registrar Árbitro',
    description: 'Crear un nuevo árbitro para dirigir partidos',
    icon: 'mdi:whistle',
    color: 'secondary' as const,
    requiresCityAndSport: true,
    fields: ['basic', 'location', 'referee']
  },
  player: {
    title: 'Registrar Jugador',
    description: 'Crear un nuevo jugador para el equipo',
    icon: 'mdi:account-group',
    color: 'success' as const,
    requiresCityAndSport: false,
    fields: ['basic', 'player', 'medical']
  },
  coach: {
    title: 'Registrar Entrenador',
    description: 'Crear un nuevo entrenador para el equipo',
    icon: 'mdi:account-supervisor',
    color: 'info' as const,
    requiresCityAndSport: false,
    fields: ['basic', 'coach']
  }
} as const;

export const UserRegistrationModal: React.FC<UserRegistrationModalProps> = ({
  isOpen,
  onOpenChange,
  userType,
  onSuccess
}) => {
  const { user } = useAuth();
  const { showSuccess, showError } = useNotification();
  const { validationState: emailValidation, validateEmailUniqueness, isValidEmailFormat } = useEmailValidation();
  const { validatePhoneField, formatPhoneNumber } = usePhoneValidation('CO');
  const { validateIdentificationField, formatIdentification } = useIdentificationValidation('CO');

  const [formData, setFormData] = useState<FormData>({
    first_name: '',
    last_name: '',
    email: '',
    phone: '',
    identification: '',
    photo_url: '',
    account_status: 'active'
  });

  const [cities, setCities] = useState<City[]>([]);
  const [sports, setSports] = useState<Sport[]>([]);
  const [isSubmitting, setIsSubmitting] = useState(false);
  const [loadingData, setLoadingData] = useState(false);
  const [showConfirmModal, setShowConfirmModal] = useState(false);

  const config = USER_TYPE_CONFIG[userType as keyof typeof USER_TYPE_CONFIG];

  // Form validation rules
  const validationRules = {
    first_name: {
      required: true,
      minLength: 2,
      maxLength: 100,
      pattern: /^[a-zA-ZáéíóúÁÉÍÓÚñÑ\s]+$/
    },
    last_name: {
      required: true,
      minLength: 2,
      maxLength: 100,
      pattern: /^[a-zA-ZáéíóúÁÉÍÓÚñÑ\s]+$/
    },
    email: {
      required: true,
      pattern: /^[^\s@]+@[^\s@]+\.[^\s@]+$/
    },
    phone: {
      required: false,
      pattern: /^(\+\d{1,3})?[\s\-]?\d{3}[\s\-]?\d{3}[\s\-]?\d{4}$/
    },
    identification: {
      required: false,
      minLength: 5,
      maxLength: 50
    },
    city_id: { 
      required: config?.requiresCityAndSport || false 
    },
    sport_id: { 
      required: config?.requiresCityAndSport || false 
    },
    date_of_birth: {
      required: userType === 'player',
      custom: (value: string) => {
        if (userType === 'player' && value) {
          const birthDate = new Date(value);
          const today = new Date();
          const age = today.getFullYear() - birthDate.getFullYear();
          if (age < 16 || age > 50) {
            return 'Player must be between 16 and 50 years old';
          }
        }
        return null;
      }
    },
    jersey_number: {
      required: false,
      custom: (value: string) => {
        if (value) {
          const num = parseInt(value);
          if (isNaN(num) || num < 1 || num > 99) {
            return 'Jersey number must be between 1 and 99';
          }
        }
        return null;
      }
    },
    experience_years: {
      required: false,
      custom: (value: string) => {
        if (value) {
          const years = parseInt(value);
          if (isNaN(years) || years < 0 || years > 50) {
            return 'Experience must be between 0 and 50 years';
          }
        }
        return null;
      }
    }
  };

  const {
    validationState,
    validateForm,
    validateSingleField,
    clearFieldError,
    sanitizeInput
  } = useFormValidation(validationRules);

  // Load cities and sports on component mount
  useEffect(() => {
    if (isOpen && config?.requiresCityAndSport) {
      loadCitiesAndSports();
    }
  }, [isOpen, config?.requiresCityAndSport]);

  const loadCitiesAndSports = async () => {
    setLoadingData(true);
    try {
      const [citiesData, sportsData] = await Promise.all([
        citiesService.getCities(),
        sportsService.getSports()
      ]);
      setCities(citiesData);
      setSports(sportsData);
    } catch (error) {
      console.error('Error loading cities and sports:', error);
      showError('Error', 'Failed to load cities and sports data');
    } finally {
      setLoadingData(false);
    }
  };

  const handleInputChange = (field: string, value: string) => {
    const sanitizedValue = sanitizeInput(value);
    setFormData(prev => ({ ...prev, [field]: sanitizedValue }));
    clearFieldError(field);

    // Real-time validation for specific fields
    if (field === 'phone' && sanitizedValue) {
      validatePhoneField(sanitizedValue);
    }
    if (field === 'identification' && sanitizedValue) {
      validateIdentificationField(sanitizedValue);
    }
  };

  const handleEmailChange = (email: string) => {
    handleInputChange('email', email);
    if (email && isValidEmailFormat(email)) {
      validateEmailUniqueness(email);
    }
    validateSingleField('email', email);
  };

  const validateFormData = () => {
    const isFormValid = validateForm(formData);
    if (formData.email && !emailValidation.isValid) {
      return false;
    }
    if (emailValidation.isChecking) {
      return false;
    }
    return isFormValid;
  };

  const handleSubmit = async () => {
    if (!validateFormData()) {
      showError('Validation Error', 'Please correct the errors in the form');
      return;
    }

    setIsSubmitting(true);
    try {
      let response: UserRegistrationResponse;

      switch (userType) {
        case 'city_admin':
          response = await userRegistrationService.registerCityAdmin({
            ...formData,
            city_id: formData.city_id!,
            sport_id: formData.sport_id!
          } as CityAdminRegistrationData);
          break;

        case 'owner':
          response = await userRegistrationService.registerOwner({
            ...formData,
            city_id: formData.city_id!,
            sport_id: formData.sport_id!
          } as OwnerRegistrationData);
          break;

        case 'referee':
          response = await userRegistrationService.registerReferee({
            ...formData,
            city_id: formData.city_id!,
            sport_id: formData.sport_id!,
            certification_level: formData.certification_level,
            experience_years: formData.experience_years ? parseInt(formData.experience_years) : undefined
          } as RefereeRegistrationData);
          break;

        case 'player':
          response = await userRegistrationService.registerPlayer({
            ...formData,
            date_of_birth: formData.date_of_birth!,
            blood_type: formData.blood_type,
            emergency_contact: formData.emergency_contact_name ? {
              name: formData.emergency_contact_name,
              phone: formData.emergency_contact_phone!,
              relationship: formData.emergency_contact_relationship!
            } : undefined,
            medical_info: {
              allergies: formData.medical_allergies,
              medications: formData.medical_medications,
              medical_conditions: formData.medical_conditions
            },
            position: formData.position,
            jersey_number: formData.jersey_number ? parseInt(formData.jersey_number) : undefined
          } as PlayerRegistrationData);
          break;

        case 'coach':
          response = await userRegistrationService.registerCoach({
            ...formData,
            certification_level: formData.certification_level,
            experience_years: formData.experience_years ? parseInt(formData.experience_years) : undefined,
            specialization: formData.specialization
          } as CoachRegistrationData);
          break;

        default:
          throw new Error('Invalid user type');
      }

      showSuccess('Registration Successful', `${config.title.split(' ')[1]} registered successfully`);
      onSuccess?.(response);
      onOpenChange(false);
      resetForm();

    } catch (error) {
      console.error('Registration error:', error);
      showError('Registration Failed', error instanceof Error ? error.message : 'Failed to register user');
    } finally {
      setIsSubmitting(false);
    }
  };

  const resetForm = () => {
    setFormData({
      first_name: '',
      last_name: '',
      email: '',
      phone: '',
      identification: '',
      photo_url: '',
      account_status: 'active'
    });
    validationState.errors = {};
    validationState.touched = {};
  };

  const renderBasicFields = () => (
    <>
      <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
        <Input
          label="Nombre *"
          placeholder="Nombre"
          value={formData.first_name}
          onValueChange={(value) => handleInputChange('first_name', value)}
          variant="bordered"
          isInvalid={!!validationState.errors.first_name}
          errorMessage={validationState.errors.first_name}
          isRequired
          color={validationState.touched.first_name && !validationState.errors.first_name ? 'success' : 'default'}
        />

        <Input
          label="Apellido *"
          placeholder="Apellido"
          value={formData.last_name}
          onValueChange={(value) => handleInputChange('last_name', value)}
          variant="bordered"
          isInvalid={!!validationState.errors.last_name}
          errorMessage={validationState.errors.last_name}
          isRequired
          color={validationState.touched.last_name && !validationState.errors.last_name ? 'success' : 'default'}
        />
      </div>

      <Input
        label="Correo Electrónico *"
        placeholder="usuario@ejemplo.com"
        type="email"
        value={formData.email}
        onValueChange={handleEmailChange}
        variant="bordered"
        isInvalid={!!validationState.errors.email || !!emailValidation.error}
        errorMessage={validationState.errors.email || emailValidation.error}
        isRequired
        color={
          emailValidation.isChecking ? 'default' :
            formData.email && isValidEmailFormat(formData.email) && emailValidation.isValid ? 'success' :
              'default'
        }
        startContent={<Icon icon="mdi:email-outline" className="w-4 h-4 text-gray-400" />}
        endContent={
          emailValidation.isChecking ? (
            <Icon icon="mdi:loading" className="w-4 h-4 text-gray-400 animate-spin" />
          ) : formData.email && isValidEmailFormat(formData.email) && emailValidation.isValid ? (
            <Icon icon="mdi:check-circle" className="w-4 h-4 text-green-500" />
          ) : formData.email && (validationState.errors.email || emailValidation.error) ? (
            <Icon icon="mdi:alert-circle" className="w-4 h-4 text-red-500" />
          ) : null
        }
      />

      <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
        <Input
          label="Teléfono"
          placeholder="+57 300 123 4567"
          value={formData.phone}
          onValueChange={(value) => {
            handleInputChange('phone', value);
            if (value) {
              const formatted = formatPhoneNumber(value);
              if (formatted !== value) {
                setFormData(prev => ({ ...prev, phone: formatted }));
              }
            }
          }}
          variant="bordered"
          isInvalid={!!validationState.errors.phone}
          errorMessage={validationState.errors.phone}
          color={validationState.touched.phone && !validationState.errors.phone && formData.phone ? 'success' : 'default'}
          startContent={<Icon icon="mdi:phone-outline" className="w-4 h-4 text-gray-400" />}
        />

        <Input
          label="Identificación"
          placeholder="Cédula o documento"
          value={formData.identification}
          onValueChange={(value) => {
            handleInputChange('identification', value);
            if (value) {
              const formatted = formatIdentification(value);
              if (formatted !== value) {
                setFormData(prev => ({ ...prev, identification: formatted }));
              }
            }
          }}
          variant="bordered"
          isInvalid={!!validationState.errors.identification}
          errorMessage={validationState.errors.identification}
          color={validationState.touched.identification && !validationState.errors.identification && formData.identification ? 'success' : 'default'}
          startContent={<Icon icon="mdi:card-account-details-outline" className="w-4 h-4 text-gray-400" />}
        />
      </div>

      <Input
        label="URL de Foto"
        placeholder="https://ejemplo.com/foto.jpg"
        value={formData.photo_url}
        onValueChange={(value) => handleInputChange('photo_url', value)}
        variant="bordered"
        startContent={<Icon icon="mdi:image-outline" className="w-4 h-4 text-gray-400" />}
      />
    </>
  );

  const renderLocationFields = () => (
    config?.requiresCityAndSport && (
      <>
        <Divider />
        <div className="space-y-4">
          <h4 className="text-sm font-medium text-gray-700">Asignación de Jurisdicción</h4>
          <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
            <Select
              label="Ciudad *"
              placeholder="Seleccionar ciudad"
              selectedKeys={formData.city_id ? [formData.city_id] : []}
              onSelectionChange={(keys) => {
                const selectedKey = Array.from(keys)[0] as string;
                handleInputChange('city_id', selectedKey || '');
                validateSingleField('city_id', selectedKey || '');
              }}
              variant="bordered"
              isInvalid={!!validationState.errors.city_id}
              errorMessage={validationState.errors.city_id}
              isRequired
              isLoading={loadingData}
              color={validationState.touched.city_id && !validationState.errors.city_id && formData.city_id ? 'success' : 'default'}
              startContent={<Icon icon="mdi:map-marker-outline" className="w-4 h-4 text-gray-400" />}
            >
              {cities.map((city) => (
                <SelectItem key={city.city_id}>
                  {city.name} - {city.region}
                </SelectItem>
              ))}
            </Select>

            <Select
              label="Deporte *"
              placeholder="Seleccionar deporte"
              selectedKeys={formData.sport_id ? [formData.sport_id] : []}
              onSelectionChange={(keys) => {
                const selectedKey = Array.from(keys)[0] as string;
                handleInputChange('sport_id', selectedKey || '');
                validateSingleField('sport_id', selectedKey || '');
              }}
              variant="bordered"
              isInvalid={!!validationState.errors.sport_id}
              errorMessage={validationState.errors.sport_id}
              isRequired
              isLoading={loadingData}
              color={validationState.touched.sport_id && !validationState.errors.sport_id && formData.sport_id ? 'success' : 'default'}
              startContent={<Icon icon="mdi:soccer" className="w-4 h-4 text-gray-400" />}
            >
              {sports.map((sport) => (
                <SelectItem key={sport.sport_id}>
                  {sport.name}
                </SelectItem>
              ))}
            </Select>
          </div>
        </div>
      </>
    )
  );

  const renderPlayerFields = () => (
    userType === 'player' && (
      <>
        <Divider />
        <div className="space-y-4">
          <h4 className="text-sm font-medium text-gray-700">Información del Jugador</h4>
          
          <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
            <Input
              label="Fecha de Nacimiento *"
              type="date"
              value={formData.date_of_birth}
              onValueChange={(value) => handleInputChange('date_of_birth', value)}
              variant="bordered"
              isInvalid={!!validationState.errors.date_of_birth}
              errorMessage={validationState.errors.date_of_birth}
              isRequired
            />

            <Select
              label="Tipo de Sangre"
              placeholder="Seleccionar"
              selectedKeys={formData.blood_type ? [formData.blood_type] : []}
              onSelectionChange={(keys) => {
                const selectedKey = Array.from(keys)[0] as string;
                handleInputChange('blood_type', selectedKey || '');
              }}
              variant="bordered"
            >
              <SelectItem key="A+">A+</SelectItem>
              <SelectItem key="A-">A-</SelectItem>
              <SelectItem key="B+">B+</SelectItem>
              <SelectItem key="B-">B-</SelectItem>
              <SelectItem key="AB+">AB+</SelectItem>
              <SelectItem key="AB-">AB-</SelectItem>
              <SelectItem key="O+">O+</SelectItem>
              <SelectItem key="O-">O-</SelectItem>
            </Select>

            <Input
              label="Número de Camiseta"
              placeholder="1-99"
              value={formData.jersey_number}
              onValueChange={(value) => handleInputChange('jersey_number', value)}
              variant="bordered"
              isInvalid={!!validationState.errors.jersey_number}
              errorMessage={validationState.errors.jersey_number}
            />
          </div>

          <Input
            label="Posición"
            placeholder="Delantero, Defensa, etc."
            value={formData.position}
            onValueChange={(value) => handleInputChange('position', value)}
            variant="bordered"
          />

          <div className="space-y-3">
            <h5 className="text-sm font-medium text-gray-600">Contacto de Emergencia</h5>
            <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
              <Input
                label="Nombre"
                placeholder="Nombre completo"
                value={formData.emergency_contact_name}
                onValueChange={(value) => handleInputChange('emergency_contact_name', value)}
                variant="bordered"
              />
              <Input
                label="Teléfono"
                placeholder="+57 300 123 4567"
                value={formData.emergency_contact_phone}
                onValueChange={(value) => handleInputChange('emergency_contact_phone', value)}
                variant="bordered"
              />
              <Input
                label="Parentesco"
                placeholder="Padre, Madre, etc."
                value={formData.emergency_contact_relationship}
                onValueChange={(value) => handleInputChange('emergency_contact_relationship', value)}
                variant="bordered"
              />
            </div>
          </div>
        </div>
      </>
    )
  );

  const renderMedicalFields = () => (
    userType === 'player' && (
      <>
        <div className="space-y-3">
          <h5 className="text-sm font-medium text-gray-600">Información Médica</h5>
          <div className="space-y-3">
            <Textarea
              label="Alergias"
              placeholder="Describir alergias conocidas"
              value={formData.medical_allergies}
              onValueChange={(value) => handleInputChange('medical_allergies', value)}
              variant="bordered"
              minRows={2}
            />
            <Textarea
              label="Medicamentos"
              placeholder="Medicamentos que toma regularmente"
              value={formData.medical_medications}
              onValueChange={(value) => handleInputChange('medical_medications', value)}
              variant="bordered"
              minRows={2}
            />
            <Textarea
              label="Condiciones Médicas"
              placeholder="Condiciones médicas relevantes"
              value={formData.medical_conditions}
              onValueChange={(value) => handleInputChange('medical_conditions', value)}
              variant="bordered"
              minRows={2}
            />
          </div>
        </div>
      </>
    )
  );

  const renderRefereeFields = () => (
    userType === 'referee' && (
      <>
        <Divider />
        <div className="space-y-4">
          <h4 className="text-sm font-medium text-gray-700">Información del Árbitro</h4>
          <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
            <Select
              label="Nivel de Certificación"
              placeholder="Seleccionar nivel"
              selectedKeys={formData.certification_level ? [formData.certification_level] : []}
              onSelectionChange={(keys) => {
                const selectedKey = Array.from(keys)[0] as string;
                handleInputChange('certification_level', selectedKey || '');
              }}
              variant="bordered"
            >
              <SelectItem key="regional">Regional</SelectItem>
              <SelectItem key="nacional">Nacional</SelectItem>
              <SelectItem key="internacional">Internacional</SelectItem>
            </Select>

            <Input
              label="Años de Experiencia"
              placeholder="0-50"
              value={formData.experience_years}
              onValueChange={(value) => handleInputChange('experience_years', value)}
              variant="bordered"
              isInvalid={!!validationState.errors.experience_years}
              errorMessage={validationState.errors.experience_years}
            />
          </div>
        </div>
      </>
    )
  );

  const renderCoachFields = () => (
    userType === 'coach' && (
      <>
        <Divider />
        <div className="space-y-4">
          <h4 className="text-sm font-medium text-gray-700">Información del Entrenador</h4>
          <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
            <Select
              label="Nivel de Certificación"
              placeholder="Seleccionar nivel"
              selectedKeys={formData.certification_level ? [formData.certification_level] : []}
              onSelectionChange={(keys) => {
                const selectedKey = Array.from(keys)[0] as string;
                handleInputChange('certification_level', selectedKey || '');
              }}
              variant="bordered"
            >
              <SelectItem key="basico">Básico</SelectItem>
              <SelectItem key="intermedio">Intermedio</SelectItem>
              <SelectItem key="avanzado">Avanzado</SelectItem>
              <SelectItem key="profesional">Profesional</SelectItem>
            </Select>

            <Input
              label="Años de Experiencia"
              placeholder="0-50"
              value={formData.experience_years}
              onValueChange={(value) => handleInputChange('experience_years', value)}
              variant="bordered"
              isInvalid={!!validationState.errors.experience_years}
              errorMessage={validationState.errors.experience_years}
            />
          </div>

          <Input
            label="Especialización"
            placeholder="Fútbol juvenil, Preparación física, etc."
            value={formData.specialization}
            onValueChange={(value) => handleInputChange('specialization', value)}
            variant="bordered"
          />
        </div>
      </>
    )
  );

  if (!config) {
    return null;
  }

  return (
    <Modal
      isOpen={isOpen}
      onOpenChange={onOpenChange}
      placement="center"
      size="3xl"
      scrollBehavior="inside"
      isDismissable={!isSubmitting}
      isKeyboardDismissDisabled={isSubmitting}
    >
      <ModalContent>
        {(onClose) => (
          <>
            <ModalHeader className="flex flex-col gap-1">
              <div className="flex items-center gap-3">
                <div className={`p-2 bg-${config.color}-100 rounded-lg`}>
                  <Icon icon={config.icon} className={`w-6 h-6 text-${config.color}-500`} />
                </div>
                <div>
                  <h3 className="text-lg font-semibold">{config.title}</h3>
                  <p className="text-sm text-gray-600 font-normal">{config.description}</p>
                </div>
              </div>
            </ModalHeader>

            <ModalBody>
              <div className="flex flex-col gap-4">
                {/* Form validation progress */}
                <FormValidationProgress
                  validationState={validationState}
                  requiredFields={[
                    'first_name', 
                    'last_name', 
                    'email',
                    ...(config.requiresCityAndSport ? ['city_id', 'sport_id'] : []),
                    ...(userType === 'player' ? ['date_of_birth'] : [])
                  ]}
                  formData={formData}
                />

                {/* Basic Information */}
                {renderBasicFields()}

                {/* Location Fields */}
                {renderLocationFields()}

                {/* Player-specific Fields */}
                {renderPlayerFields()}

                {/* Medical Fields */}
                {renderMedicalFields()}

                {/* Referee-specific Fields */}
                {renderRefereeFields()}

                {/* Coach-specific Fields */}
                {renderCoachFields()}
              </div>
            </ModalBody>

            <ModalFooter>
              <Button
                color="danger"
                variant="light"
                onPress={onClose}
                isDisabled={isSubmitting}
              >
                Cancelar
              </Button>
              <Button
                color="primary"
                onPress={handleSubmit}
                isLoading={isSubmitting}
                loadingText="Registrando..."
              >
                Registrar {config.title.split(' ')[1]}
              </Button>
            </ModalFooter>
          </>
        )}
      </ModalContent>
    </Modal>
  );
};