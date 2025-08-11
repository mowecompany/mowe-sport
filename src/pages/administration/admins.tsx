import { title } from "@/components/primitives";
import DefaultLayout from "@/layouts/default";
import { Dropdown, DropdownTrigger, DropdownMenu, DropdownItem } from "@heroui/dropdown";
import { Pagination } from "@heroui/pagination";
import { Select, SelectItem } from "@heroui/select";
import { Chip } from "@heroui/chip";
import { Avatar } from "@heroui/avatar";
import { Card, CardBody, CardHeader } from "@heroui/card";
import { Input } from "@heroui/input";
import { Button } from "@heroui/button";
import { Modal, ModalContent, ModalHeader, ModalBody, ModalFooter } from "@heroui/modal";
import { useDisclosure } from "@heroui/modal";
import { Icon } from "@iconify/react";
import React, { useState, useRef, useCallback } from "react";
import { useEmailValidation } from "@/hooks/useEmailValidation";
import { useNotification } from "@/hooks/useNotification";
import { useFormValidation } from "@/hooks/useFormValidation";
import { usePhoneValidation } from "@/hooks/usePhoneValidation";
import { useIdentificationValidation } from "@/hooks/useIdentificationValidation";
import {
  adminService,
  citiesService,
  sportsService,
  userRegistrationService,
  type AdminRegistrationData,
  type City,
  type Sport,
  type AccountStatus
} from "@/services";
import type { UserSummary, UserListRequest } from '@/services/userRegistrationService';
import { Notification } from "@/components/Notification";
import { ValidationHelp } from "@/components/ValidationHelp";
import { FormValidationProgress } from "@/components/FormValidationProgress";

export default function AdmisPage() {
  const { isOpen, onOpen, onOpenChange } = useDisclosure();
  const [formData, setFormData] = useState({
    first_name: "",
    last_name: "",
    email: "",
    phone: "",
    identification: "",
    city_id: "",
    sport_id: "",
    account_status: "active" as AccountStatus,
    photo_url: ""
  });

  const [cities, setCities] = useState<City[]>([]);
  const [sports, setSports] = useState<Sport[]>([]);
  const [loadingData, setLoadingData] = useState(false);

  // Cache hooks for cities and sports
  const [isSubmitting, setIsSubmitting] = useState(false);
  const [showConfirmModal, setShowConfirmModal] = useState(false);
  const [registrationSuccess, setRegistrationSuccess] = useState<{
    show: boolean;
    adminData?: any;
  }>({ show: false });
  const [formDraft, setFormDraft] = useState<any>(null);

  // Validation hooks
  const { validationState: emailValidation, validateEmailUniqueness, isValidEmailFormat } = useEmailValidation();
  const { notifications, removeNotification, showSuccess, showError } = useNotification();

  // Form validation rules
  const validationRules = {
    first_name: {
      required: true,
      minLength: 2,
      maxLength: 100,
      pattern: /^[a-zA-ZáéíóúÁÉÍÓÚñÑ\s]+$/,
      custom: (value: string) => {
        if (value && value.trim().length < 2) {
          return "Debe tener al menos 2 caracteres";
        }
        return null;
      }
    },
    last_name: {
      required: true,
      minLength: 2,
      maxLength: 100,
      pattern: /^[a-zA-ZáéíóúÁÉÍÓÚñÑ\s]+$/,
      custom: (value: string) => {
        if (value && value.trim().length < 2) {
          return "Debe tener al menos 2 caracteres";
        }
        return null;
      }
    },
    email: {
      required: true,
      pattern: /^[^\s@]+@[^\s@]+\.[^\s@]+$/,
      custom: (value: string) => {
        if (value && !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(value)) {
          return "Formato de email inválido";
        }
        return null;
      }
    },
    phone: {
      required: false,
      pattern: /^(\+\d{1,3})?[\s\-]?\d{3}[\s\-]?\d{3}[\s\-]?\d{4}$/,
      custom: (value: string) => {
        if (value) {
          // Remove spaces and check if it's a valid phone format
          const cleanPhone = value.replace(/[\s\-]/g, '');
          const phoneRegex = /^(\+\d{1,3})?\d{7,15}$/;
          if (!phoneRegex.test(cleanPhone)) {
            return "Formato de teléfono inválido. Use formato: +57 300 123 4567";
          }
        }
        return null;
      }
    },
    identification: {
      required: false,
      minLength: 5,
      maxLength: 50,
      custom: (value: string) => {
        if (value && value.length < 5) {
          return "Debe tener al menos 5 caracteres";
        }
        return null;
      }
    },
    city_id: { required: true },
    sport_id: { required: true },
    photo_url: {
      required: false,
      custom: (value: string) => {
        if (value && !value.match(/^https?:\/\/.+/)) {
          return "URL inválida. Debe incluir http:// o https://";
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

  const { validatePhoneField, formatPhoneNumber } = usePhoneValidation('CO');
  const { validateIdentificationField, formatIdentification } = useIdentificationValidation('CO');

  // Estado para la lista de administradores
  const [admins, setAdmins] = useState<UserSummary[]>([]);
  const [loadingAdmins, setLoadingAdmins] = useState(false);
  const isLoadingRef = useRef(false);
  const lastLoadTimeRef = useRef<number>(0);
  const hasInitialLoadRef = useRef(false);
  const dataLoadedRef = useRef(false);
  const mountedRef = useRef(false);
  const [pagination, setPagination] = useState({
    total: 0,
    totalPages: 0,
    hasNext: false,
    hasPrev: false,
    page: 1,
    limit: 12
  });

  // Only show city administrators
  const [filters, setFilters] = useState<UserListRequest>({
    page: 1,
    limit: 12,
    search: '',
    role: 'city_admin',
    account_status: undefined,
    sort_by: 'created_at',
    sort_order: 'desc'
  });

  const getStatusColor = (status: string) => {
    const statusColors = {
      active: 'success',
      suspended: 'danger',
      payment_pending: 'warning',
      disabled: 'default'
    } as const;
    return statusColors[status as keyof typeof statusColors] || 'default';
  };

  const getStatusLabel = (status: string) => {
    const statusLabels = {
      active: 'Activo',
      suspended: 'Suspendido',
      payment_pending: 'Pago Pendiente',
      disabled: 'Deshabilitado'
    };
    return statusLabels[status as keyof typeof statusLabels] || status;
  };

  const handleInputChange = (field: string, value: string) => {
    // Sanitize input
    const sanitizedValue = sanitizeInput(value);
    const newFormData = {
      ...formData,
      [field]: sanitizedValue
    };
    setFormData(newFormData);

    // Auto-save draft to localStorage
    localStorage.setItem('admin_registration_draft', JSON.stringify(newFormData));

    // Clear field error when user starts typing
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
    handleInputChange("email", email);

    // Validate email format and uniqueness
    if (email && isValidEmailFormat(email)) {
      validateEmailUniqueness(email);
    }

    // Real-time form validation
    validateSingleField("email", email);
  };

  const validateFormData = () => {
    // Validate form using the validation hook
    const isFormValid = validateForm(formData);

    // Additional email validation check
    if (formData.email && !emailValidation.isValid) {
      return false;
    }

    // Check if email validation is still in progress
    if (emailValidation.isChecking) {
      return false;
    }

    return isFormValid;
  };

  // Single initialization effect
  React.useEffect(() => {
    let isMounted = true;

    const initializeData = async () => {
      // Prevent multiple executions
      if (mountedRef.current) {
        console.log('[AdminsPage] Component already initialized, skipping...');
        return;
      }
      mountedRef.current = true;

      console.log('[AdminsPage] Initializing component data...');

      try {
        setLoadingData(true);

        // Load cities and sports in parallel using RequestManager
        console.log('[AdminsPage] Loading cities and sports...');
        const [citiesData, sportsData] = await Promise.all([
          citiesService.getCities(),
          sportsService.getSports()
        ]);

        if (isMounted) {
          setCities(citiesData);
          setSports(sportsData);
          dataLoadedRef.current = true;

          // Now load admins
          if (!hasInitialLoadRef.current) {
            console.log('[AdminsPage] Loading initial admins...');
            await loadAdmins(0, true);
          }
        }

      } catch (error) {
        console.error('[AdminsPage] Error initializing data:', error);
        if (isMounted) {
          showError('Error de Inicialización', 'Error cargando datos iniciales');
        }
      } finally {
        if (isMounted) {
          setLoadingData(false);
        }
      }
    };

    initializeData();

    return () => {
      isMounted = false;
    };
  }, []); // Only run once

  // Handle filter changes with debounce
  React.useEffect(() => {
    // Skip if this is the initial load
    if (!hasInitialLoadRef.current) {
      return;
    }

    const timeoutId = setTimeout(() => {
      // Only load if filters actually changed from defaults
      const hasNonDefaultFilters =
        filters.page !== 1 ||
        filters.search !== '' ||
        filters.account_status !== undefined;

      if (hasNonDefaultFilters) {
        console.log('Filters changed, loading admins...');
        loadAdmins(0, true); // Force reload for filter changes
      }
    }, filters.search ? 500 : 100); // 500ms debounce for search, 100ms for other filters

    return () => clearTimeout(timeoutId);
  }, [filters.page, filters.limit, filters.search, filters.account_status, filters.sort_by, filters.sort_order]);

  // Función para cargar administradores
  const loadAdmins = useCallback(async (retryCount = 0, forceReload = false) => {
    // Prevent multiple simultaneous loads
    if (isLoadingRef.current) {
      console.log('Already loading admins, skipping...');
      return;
    }

    // Check if we need to reload (avoid unnecessary requests)
    const now = Date.now();
    const timeSinceLastLoad = now - lastLoadTimeRef.current;
    const minTimeBetweenLoads = 2000; // 2 seconds minimum between loads

    if (!forceReload && hasInitialLoadRef.current && timeSinceLastLoad < minTimeBetweenLoads) {
      console.log('Too soon since last load, skipping...');
      return;
    }

    // Check if user is authenticated
    const token = localStorage.getItem('auth_token') || localStorage.getItem('authToken');
    if (!token) {
      console.error('No auth token found');
      showError('Error de Autenticación', 'No se encontró token de autenticación');
      return;
    }

    isLoadingRef.current = true;
    setLoadingAdmins(true);
    lastLoadTimeRef.current = now;

    try {
      console.log('Loading admins with filters:', filters);
      const response = await userRegistrationService.getUsersList(filters);
      console.log('Admins response:', response);

      setAdmins(response.users || []);
      setPagination(prev => ({
        ...prev,
        total: response.total || 0,
        totalPages: response.total_pages || 0,
        hasNext: response.has_next || false,
        hasPrev: response.has_prev || false
      }));

      hasInitialLoadRef.current = true;
    } catch (error) {
      console.error("Error loading admins:", error);
      console.error("Error details:", error.message);

      // Check if it's an authentication error
      if (error.message.includes('Authentication') || error.message.includes('401')) {
        showError('Error de Autenticación', 'Su sesión ha expirado. Por favor, inicie sesión nuevamente.');
        return;
      }

      // Retry once if it's a network error and we haven't retried yet
      if (retryCount === 0 && (error.message.includes('fetch') || error.message.includes('Network') || error.message.includes('500'))) {
        console.log('Retrying admin load...');
        isLoadingRef.current = false;
        setTimeout(() => loadAdmins(1, true), 2000);
        return;
      }

      showError('Error', `No se pudieron cargar los administradores: ${error.message}`);
      // Set empty state on error
      setAdmins([]);
      setPagination(prev => ({
        ...prev,
        total: 0,
        totalPages: 0,
        hasNext: false,
        hasPrev: false
      }));
    } finally {
      setLoadingAdmins(false);
      isLoadingRef.current = false;
    }
  }, [filters, showError, userRegistrationService]);

  // Función para manejar cambios de estado
  const handleStatusChange = async (userId: string, newStatus: AccountStatus) => {
    try {
      await userRegistrationService.updateUserStatus(userId, newStatus);
      showSuccess('Estado Actualizado', 'El estado del administrador ha sido actualizado');
      loadAdmins(0, true); // Force reload after status change
    } catch (error) {
      console.error('Error updating status:', error);
      showError('Error', 'No se pudo actualizar el estado del administrador');
    }
  };

  // Función para regenerar contraseña
  const handleRegeneratePassword = async (userId: string) => {
    try {
      await userRegistrationService.regenerateTemporaryPassword(userId);
      showSuccess('Contraseña Regenerada', 'Se ha generado una nueva contraseña temporal');
    } catch (error) {
      console.error('Error regenerating password:', error);
      showError('Error', 'No se pudo regenerar la contraseña');
    }
  };

  // Load draft when modal opens
  React.useEffect(() => {
    if (isOpen) {
      const savedDraft = localStorage.getItem('admin_registration_draft');
      if (savedDraft) {
        try {
          const draftData = JSON.parse(savedDraft);
          setFormDraft(draftData);
        } catch (error) {
          console.error('Error loading draft:', error);
        }
      }
    }
  }, [isOpen]);

  // Function to load draft data
  const loadDraft = () => {
    if (formDraft) {
      setFormData(formDraft);
      setFormDraft(null);
      showSuccess('Borrador cargado', 'Se ha restaurado el borrador guardado automáticamente');
    }
  };

  // Function to clear draft
  const clearDraft = () => {
    localStorage.removeItem('admin_registration_draft');
    setFormDraft(null);
  };

  const handleSubmitClick = () => {
    if (!validateFormData()) {
      showError('Errores de validación', 'Por favor corrija los errores en el formulario');
      return;
    }
    setShowConfirmModal(true);
  };

  const handleConfirmedSubmit = async () => {
    setShowConfirmModal(false);
    setIsSubmitting(true);
    try {
      const registrationData: AdminRegistrationData = {
        first_name: formData.first_name.trim(),
        last_name: formData.last_name.trim(),
        email: formData.email.trim(),
        phone: formData.phone?.trim() || undefined,
        identification: formData.identification?.trim() || undefined,
        city_id: formData.city_id,
        sport_id: formData.sport_id,
        account_status: formData.account_status as AccountStatus,
        photo_url: formData.photo_url?.trim() || undefined
      };

      const result = await adminService.registerAdmin(registrationData);

      // Clear draft on successful registration
      clearDraft();

      // Show success modal with details
      setRegistrationSuccess({
        show: true,
        adminData: result
      });

      // Reset form
      setFormData({
        first_name: "",
        last_name: "",
        email: "",
        phone: "",
        identification: "",
        city_id: "",
        sport_id: "",
        account_status: "active" as AccountStatus,
        photo_url: ""
      });

      // Reset all validation states
      validationState.errors = {};
      validationState.touched = {};

      // Reload admins list
      loadAdmins(0, true); // Force reload after registration

    } catch (error) {
      console.error("Error registrando admin:", error);

      // Handle specific API errors
      if (error instanceof Error) {
        if (error.message.includes('email')) {
          // Set email field error using validation state
          validationState.errors.email = error.message;
        } else if (error.message.includes('permission')) {
          showError('Sin permisos', 'No tienes permisos para registrar administradores');
        } else {
          showError('Error de registro', error.message);
        }
      } else {
        showError('Error interno', 'Error interno del servidor');
      }
    } finally {
      setIsSubmitting(false);
    }
  };

  return (
    <DefaultLayout>
      <section className="flex flex-col gap-6 px-4">
        {/* Header */}
        <div className="flex flex-col gap-4">
          <div className="flex flex-col sm:flex-row gap-4 justify-between items-start sm:items-center">
            <div className="flex gap-2 sm:items-center">
              <h1 className={title()}>Admin</h1>
              <div className="p-2 bg-orange-100 rounded-lg">
                <Icon icon="mdi:shield-account" className="w-6 h-6 text-orange-500" />
              </div>
            </div>

            {/* Registration Buttons */}
            <Button
              color="primary"
              startContent={<Icon icon="mdi:plus" className="w-4 h-4" />}
              onPress={onOpen}
            >
              New Admin
            </Button>
          </div>

          <div className="">

            <div className="flex flex-col gap-1">
              <h2 className="text-xl font-semibold">Gestión de Administradores</h2>
              <p className="text-gray-600">Administra los usuarios con permisos administrativos de ciudad en el sistema</p>
            </div>

            {/* Actions Bar */}
            <div className="flex flex-col py-4 sm:flex-row gap-4 justify-between items-start sm:items-center">
              <div className="flex gap-2 flex-wrap">
                <Input
                  placeholder="Buscar administradores de ciudad..."
                  startContent={<Icon icon="mdi:magnify" className="w-4 h-4 text-gray-400" />}
                  className="max-w-xs"
                  variant="bordered"
                  value={filters.search}
                  onValueChange={(value) => setFilters(prev => ({ ...prev, search: value, page: 1 }))}
                />
                <Select
                  placeholder="Filtrar por estado"
                  className="max-w-xs"
                  variant="bordered"
                  selectedKeys={filters.account_status ? [filters.account_status] : []}
                  onSelectionChange={(keys) => {
                    const status = Array.from(keys)[0] as AccountStatus;
                    setFilters(prev => ({ ...prev, account_status: status || undefined, page: 1 }));
                  }}
                >
                  <SelectItem key="active">Activo</SelectItem>
                  <SelectItem key="suspended">Suspendido</SelectItem>
                  <SelectItem key="payment_pending">Pago Pendiente</SelectItem>
                  <SelectItem key="disabled">Deshabilitado</SelectItem>
                </Select>
              </div>
              <div className="flex gap-2">
                <Button
                  variant="bordered"
                  startContent={<Icon icon="mdi:refresh" className="w-4 h-4" />}
                  onPress={() => loadAdmins(0, true)} // Force reload
                  isLoading={loadingAdmins}
                >
                  Actualizar
                </Button>
                <Button
                  variant="bordered"
                  startContent={<Icon icon="mdi:export" className="w-4 h-4" />}
                >
                  Exportar
                </Button>
              </div>
            </div>

            {/* Cards Grid */}
            {loadingAdmins ? (
              <div className="flex justify-center items-center py-12">
                <div className="flex flex-col items-center gap-4">
                  <div className="animate-spin rounded-full h-12 w-12 border-b-2 border-primary"></div>
                  <p className="text-gray-600">Cargando administradores de ciudad...</p>
                </div>
              </div>
            ) : admins.length === 0 ? (
              <Card className="py-12">
                <CardBody className="text-center">
                  <Icon icon="mdi:account-off" className="w-16 h-16 text-gray-400 mx-auto mb-4" />
                  <h3 className="text-lg font-semibold text-gray-600 mb-2">No hay administradores de ciudad</h3>
                  <p className="text-gray-500 mb-4">
                    {filters.search ? 'No se encontraron administradores de ciudad con los filtros aplicados' : 'Comienza registrando tu primer administrador de ciudad'}
                  </p>
                  {!filters.search && (
                    <Button
                      color="primary"
                      startContent={<Icon icon="mdi:plus" className="w-4 h-4" />}
                      onPress={onOpen}
                    >
                      Registrar Primer Admin de Ciudad
                    </Button>
                  )}
                </CardBody>
              </Card>
            ) : (
              <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4 gap-4">
                {admins.map((admin) => (
                  <Card key={admin.user_id} className="p-4">
                    <CardHeader className="flex justify-between items-start p-0 pb-3">
                      <div className="flex items-center gap-3">
                        <Avatar
                          src={admin.photo_url}
                          name={`${admin.first_name} ${admin.last_name}`}
                          size="md"
                        />
                        <div>
                          <h3 className="font-semibold text-sm">{admin.first_name} {admin.last_name}</h3>
                          {admin.city_name && (
                            <p className="text-xs text-gray-500">{admin.city_name}</p>
                          )}
                        </div>
                      </div>
                      <Dropdown>
                        <DropdownTrigger>
                          <Button
                            isIconOnly
                            variant="light"
                            size="sm"
                          >
                            <Icon icon="mdi:dots-vertical" className="w-4 h-4" />
                          </Button>
                        </DropdownTrigger>
                        <DropdownMenu>
                          <DropdownItem key="view">Ver Detalles</DropdownItem>
                          <DropdownItem key="edit">Editar</DropdownItem>
                          <DropdownItem
                            key="regenerate"
                            onPress={() => handleRegeneratePassword(admin.user_id)}
                          >
                            Regenerar Contraseña
                          </DropdownItem>
                          <DropdownItem
                            key="suspend"
                            className="text-warning"
                            onPress={() => handleStatusChange(
                              admin.user_id,
                              admin.account_status === 'active' ? 'suspended' : 'active'
                            )}
                          >
                            {admin.account_status === 'active' ? 'Suspender' : 'Activar'}
                          </DropdownItem>
                          <DropdownItem
                            key="delete"
                            className="text-danger"
                            onPress={() => handleStatusChange(admin.user_id, 'disabled')}
                          >
                            Eliminar
                          </DropdownItem>
                        </DropdownMenu>
                      </Dropdown>
                    </CardHeader>

                    <CardBody className="p-0 gap-3">
                      <div className="flex flex-col gap-2 text-sm">
                        <div className="flex items-center gap-2">
                          <Icon icon="mdi:email-outline" className="w-4 h-4 text-gray-500" />
                          <span className="text-gray-700 truncate">{admin.email}</span>
                        </div>
                        {admin.phone && (
                          <div className="flex items-center gap-2">
                            <Icon icon="mdi:phone-outline" className="w-4 h-4 text-gray-500" />
                            <span className="text-gray-700">{admin.phone}</span>
                          </div>
                        )}
                        <div className="flex items-center gap-2">
                          <Icon icon="mdi:calendar-outline" className="w-4 h-4 text-gray-500" />
                          <span className="text-gray-700">
                            {new Date(admin.created_at).toLocaleDateString()}
                          </span>
                        </div>
                        {admin.sport_name && (
                          <div className="flex items-center gap-2">
                            <Icon icon="mdi:soccer" className="w-4 h-4 text-gray-500" />
                            <span className="text-gray-700 truncate">{admin.sport_name}</span>
                          </div>
                        )}
                      </div>
                      <div className="flex justify-between items-center pt-2">
                        {admin.last_login_at ? (
                          <span className="text-xs text-gray-500">
                            Último acceso: {new Date(admin.last_login_at).toLocaleDateString()}
                          </span>
                        ) : (
                          <span className="text-xs text-gray-500">Sin accesos</span>
                        )}
                        <Chip
                          size="sm"
                          color={getStatusColor(admin.account_status)}
                          variant="flat"
                        >
                          {getStatusLabel(admin.account_status)}
                        </Chip>
                      </div>
                    </CardBody>
                  </Card>
                ))}
              </div>
            )}

            {/* Footer with Pagination */}
            {pagination.totalPages > 1 && (
              <div className="flex flex-col sm:flex-row gap-4 justify-between items-center pt-4">
                <div className="flex items-center gap-4">
                  <span className="text-sm text-gray-600">
                    {pagination.total} administradores encontrados
                  </span>
                  <div className="flex items-center gap-2">
                    <span className="text-sm">Admins por página</span>
                    <Select
                      size="sm"
                      className="w-20"
                      selectedKeys={[filters.limit?.toString() || '12']}
                      onSelectionChange={(keys) => {
                        const limit = parseInt(Array.from(keys)[0] as string);
                        setFilters(prev => ({ ...prev, limit, page: 1 }));
                      }}
                    >
                      <SelectItem key="12">12</SelectItem>
                      <SelectItem key="24">24</SelectItem>
                      <SelectItem key="48">48</SelectItem>
                    </Select>
                  </div>
                </div>
                <div className="flex items-center gap-4">
                  <span className="text-sm text-gray-600">
                    Página {filters.page || 1} de {pagination.totalPages}
                  </span>
                  <Pagination
                    total={pagination.totalPages}
                    page={filters.page || 1}
                    onChange={(page) => setFilters(prev => ({ ...prev, page }))}
                    size="sm"
                    showControls
                  />
                </div>
              </div>
            )}
          </div>
        </div>

        {/* Modal para crear nuevo admin */}
        <Modal
          isOpen={isOpen}
          onOpenChange={onOpenChange}
          placement="center"
          size="2xl"
          scrollBehavior="inside"
        >
          <ModalContent>
            {(onClose) => (
              <>
                <ModalHeader className="flex flex-col gap-1">
                  <h3 className="text-lg font-semibold">Crear Nuevo Admin</h3>
                  <p className="text-sm text-gray-600 font-normal">
                    Complete la información del nuevo Admin. Haga clic en guardar cuando termine.
                  </p>
                </ModalHeader>
                <ModalBody>
                  <div className="flex flex-col gap-4">
                    {/* Draft notification */}
                    {formDraft && (
                      <div className="bg-blue-50 border border-blue-200 rounded-lg p-3">
                        <div className="flex items-center justify-between">
                          <div className="flex items-center gap-2">
                            <Icon icon="mdi:content-save-outline" className="w-4 h-4 text-blue-600" />
                            <span className="text-sm text-blue-800 font-medium">
                              Borrador guardado automáticamente
                            </span>
                          </div>
                          <div className="flex gap-2">
                            <Button
                              size="sm"
                              variant="light"
                              color="primary"
                              onPress={loadDraft}
                            >
                              Cargar
                            </Button>
                            <Button
                              size="sm"
                              variant="light"
                              color="danger"
                              onPress={clearDraft}
                            >
                              Descartar
                            </Button>
                          </div>
                        </div>
                      </div>
                    )}
                    {/* Form validation progress */}
                    <FormValidationProgress
                      validationState={validationState}
                      requiredFields={['first_name', 'last_name', 'email', 'city_id', 'sport_id']}
                      formData={formData}
                    />
                    {/* Información Personal */}
                    <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
                      <Input
                        label="Nombre *"
                        placeholder="Nombre del administrador"
                        value={formData.first_name}
                        onValueChange={(value) => handleInputChange("first_name", value)}
                        variant="bordered"
                        isInvalid={!!validationState.errors.first_name}
                        errorMessage={validationState.errors.first_name}
                        isRequired
                        color={validationState.touched.first_name && !validationState.errors.first_name ? "success" : "default"}
                      />

                      <Input
                        label="Apellido *"
                        placeholder="Apellido del administrador"
                        value={formData.last_name}
                        onValueChange={(value) => handleInputChange("last_name", value)}
                        variant="bordered"
                        isInvalid={!!validationState.errors.last_name}
                        errorMessage={validationState.errors.last_name}
                        isRequired
                        color={validationState.touched.last_name && !validationState.errors.last_name ? "success" : "default"}
                      />
                    </div>

                    <Input
                      label="Correo Electrónico *"
                      placeholder="admin@ejemplo.com"
                      type="email"
                      value={formData.email}
                      onValueChange={handleEmailChange}
                      variant="bordered"
                      isInvalid={!!validationState.errors.email || !!emailValidation.error}
                      errorMessage={validationState.errors.email || emailValidation.error}
                      isRequired
                      color={
                        emailValidation.isChecking ? "default" :
                          formData.email && isValidEmailFormat(formData.email) && emailValidation.isValid ? "success" :
                            "default"
                      }
                      startContent={
                        <div className="flex items-center gap-1">
                          <Icon icon="mdi:email-outline" className="w-4 h-4 text-gray-400" />
                          <ValidationHelp type="email" />
                        </div>
                      }
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
                          handleInputChange("phone", value);
                          // Format phone number as user types
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
                        color={validationState.touched.phone && !validationState.errors.phone && formData.phone ? "success" : "default"}
                        startContent={
                          <div className="flex items-center gap-1">
                            <Icon icon="mdi:phone-outline" className="w-4 h-4 text-gray-400" />
                            <ValidationHelp type="phone" />
                          </div>
                        }
                        endContent={
                          formData.phone && !validationState.errors.phone ? (
                            <Icon icon="mdi:check-circle" className="w-4 h-4 text-green-500" />
                          ) : formData.phone && validationState.errors.phone ? (
                            <Icon icon="mdi:alert-circle" className="w-4 h-4 text-red-500" />
                          ) : null
                        }
                      />

                      <Input
                        label="Identificación"
                        placeholder="Cédula o documento"
                        value={formData.identification}
                        onValueChange={(value) => {
                          handleInputChange("identification", value);
                          // Format identification as user types
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
                        color={validationState.touched.identification && !validationState.errors.identification && formData.identification ? "success" : "default"}
                        startContent={
                          <div className="flex items-center gap-1">
                            <Icon icon="mdi:card-account-details-outline" className="w-4 h-4 text-gray-400" />
                            <ValidationHelp type="identification" />
                          </div>
                        }
                        endContent={
                          formData.identification && !validationState.errors.identification ? (
                            <Icon icon="mdi:check-circle" className="w-4 h-4 text-green-500" />
                          ) : formData.identification && validationState.errors.identification ? (
                            <Icon icon="mdi:alert-circle" className="w-4 h-4 text-red-500" />
                          ) : null
                        }
                      />
                    </div>

                    {/* Asignación de Jurisdicción */}
                    <div className="border-t pt-4">
                      <h4 className="text-sm font-medium text-gray-700 mb-3">Asignación de Jurisdicción</h4>
                      <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
                        <Select
                          label="Ciudad *"
                          placeholder="Seleccionar ciudad"
                          selectedKeys={formData.city_id ? [formData.city_id] : []}
                          onSelectionChange={(keys) => {
                            const selectedKey = Array.from(keys)[0] as string;
                            handleInputChange("city_id", selectedKey || "");
                            validateSingleField("city_id", selectedKey || "");
                          }}
                          variant="bordered"
                          isInvalid={!!validationState.errors.city_id}
                          errorMessage={validationState.errors.city_id}
                          isRequired
                          isLoading={loadingData}
                          color={validationState.touched.city_id && !validationState.errors.city_id && formData.city_id ? "success" : "default"}
                          startContent={
                            <Icon icon="mdi:map-marker-outline" className="w-4 h-4 text-gray-400" />
                          }
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
                            handleInputChange("sport_id", selectedKey || "");
                            validateSingleField("sport_id", selectedKey || "");
                          }}
                          variant="bordered"
                          isInvalid={!!validationState.errors.sport_id}
                          errorMessage={validationState.errors.sport_id}
                          isRequired
                          isLoading={loadingData}
                          color={validationState.touched.sport_id && !validationState.errors.sport_id && formData.sport_id ? "success" : "default"}
                          startContent={
                            <Icon icon="mdi:soccer" className="w-4 h-4 text-gray-400" />
                          }
                        >
                          {sports.map((sport) => (
                            <SelectItem key={sport.sport_id}>
                              {sport.name}
                            </SelectItem>
                          ))}
                        </Select>
                      </div>
                    </div>

                    {/* Configuración de Cuenta */}
                    <div className="border-t pt-4">
                      <h4 className="text-sm font-medium text-gray-700 mb-3">Configuración de Cuenta</h4>
                      <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
                        <Select
                          label="Estado de Cuenta"
                          selectedKeys={[formData.account_status]}
                          onSelectionChange={(keys) => {
                            const selectedKey = Array.from(keys)[0] as string;
                            handleInputChange("account_status", selectedKey || "active");
                          }}
                          variant="bordered"
                          startContent={
                            <Icon icon="mdi:account-check-outline" className="w-4 h-4 text-gray-400" />
                          }
                        >
                          <SelectItem key="active">Activo</SelectItem>
                          <SelectItem key="suspended">Suspendido</SelectItem>
                          <SelectItem key="payment_pending">Pago Pendiente</SelectItem>
                          <SelectItem key="disabled">Deshabilitado</SelectItem>
                        </Select>

                        <Input
                          label="URL de Foto"
                          placeholder="https://ejemplo.com/foto.jpg"
                          value={formData.photo_url}
                          onValueChange={(value) => handleInputChange("photo_url", value)}
                          variant="bordered"
                          isInvalid={!!validationState.errors.photo_url}
                          errorMessage={validationState.errors.photo_url}
                          color={validationState.touched.photo_url && !validationState.errors.photo_url && formData.photo_url ? "success" : "default"}
                          startContent={
                            <div className="flex items-center gap-1">
                              <Icon icon="mdi:image-outline" className="w-4 h-4 text-gray-400" />
                              <ValidationHelp type="url" />
                            </div>
                          }
                          endContent={
                            formData.photo_url && !validationState.errors.photo_url ? (
                              <Icon icon="mdi:check-circle" className="w-4 h-4 text-green-500" />
                            ) : formData.photo_url && validationState.errors.photo_url ? (
                              <Icon icon="mdi:alert-circle" className="w-4 h-4 text-red-500" />
                            ) : null
                          }
                        />
                      </div>
                    </div>

                    {/* Preview de Avatar si hay URL */}
                    {formData.photo_url && (
                      <div className="flex items-center gap-3 p-3 bg-gray-50 rounded-lg">
                        <Avatar
                          src={formData.photo_url}
                          name={`${formData.first_name} ${formData.last_name}`}
                          size="md"
                        />
                        <div className="text-sm text-gray-600">
                          Vista previa del avatar
                        </div>
                      </div>
                    )}

                    {/* Validation summary */}
                    {!validationState.isValid && Object.keys(validationState.errors).length > 0 && (
                      <div className="bg-red-50 p-3 rounded-lg">
                        <div className="flex items-start gap-2">
                          <Icon icon="mdi:alert-circle-outline" className="w-4 h-4 text-red-500 mt-0.5" />
                          <div className="text-sm text-red-700">
                            <p className="font-medium">Por favor corrija los siguientes errores:</p>
                            <ul className="mt-1 space-y-1">
                              {Object.entries(validationState.errors).map(([field, error]) =>
                                error && (
                                  <li key={field}>• {error}</li>
                                )
                              )}
                            </ul>
                          </div>
                        </div>
                      </div>
                    )}

                    {/* Información adicional */}
                    <div className="bg-blue-50 p-3 rounded-lg">
                      <div className="flex items-start gap-2">
                        <Icon icon="mdi:information-outline" className="w-4 h-4 text-blue-500 mt-0.5" />
                        <div className="text-sm text-blue-700">
                          <p className="font-medium">Información importante:</p>
                          <ul className="mt-1 space-y-1 text-xs">
                            <li>• Se generará una contraseña temporal que será enviada por email</li>
                            <li>• El administrador deberá cambiar la contraseña en su primer acceso</li>
                            <li>• Tendrá permisos para gestionar torneos en la ciudad y deporte asignados</li>
                          </ul>
                        </div>
                      </div>
                    </div>
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
                    onPress={handleSubmitClick}
                    isLoading={isSubmitting || emailValidation.isChecking}
                    isDisabled={!validationState.isValid || emailValidation.isChecking || !emailValidation.isValid}
                    startContent={!isSubmitting && !emailValidation.isChecking ? <Icon icon="mdi:account-plus" className="w-4 h-4" /> : null}
                  >
                    {isSubmitting ? "Registrando..." :
                      emailValidation.isChecking ? "Validando email..." :
                        "Registrar Admin"}
                  </Button>
                </ModalFooter>
              </>
            )}
          </ModalContent>
        </Modal>

        {/* Confirmation Modal */}
        <Modal
          isOpen={showConfirmModal}
          onOpenChange={setShowConfirmModal}
          placement="center"
          size="md"
        >
          <ModalContent>
            {(onClose) => (
              <>
                <ModalHeader className="flex flex-col gap-1">
                  <div className="flex items-center gap-2">
                    <Icon icon="mdi:help-circle-outline" className="w-5 h-5 text-warning" />
                    <h3 className="text-lg font-semibold">Confirmar Registro</h3>
                  </div>
                </ModalHeader>
                <ModalBody>
                  <div className="flex flex-col gap-4">
                    <p className="text-gray-700">
                      ¿Está seguro de que desea registrar al siguiente administrador?
                    </p>
                    <div className="bg-gray-50 rounded-lg p-4 space-y-2">
                      <div className="flex justify-between">
                        <span className="font-medium text-gray-600">Nombre:</span>
                        <span>{formData.first_name} {formData.last_name}</span>
                      </div>
                      <div className="flex justify-between">
                        <span className="font-medium text-gray-600">Email:</span>
                        <span>{formData.email}</span>
                      </div>
                      <div className="flex justify-between">
                        <span className="font-medium text-gray-600">Ciudad:</span>
                        <span>{cities.find(c => c.city_id === formData.city_id)?.name || 'N/A'}</span>
                      </div>
                      <div className="flex justify-between">
                        <span className="font-medium text-gray-600">Deporte:</span>
                        <span>{sports.find(s => s.sport_id === formData.sport_id)?.name || 'N/A'}</span>
                      </div>
                    </div>
                    <div className="bg-yellow-50 border border-yellow-200 rounded-lg p-3">
                      <div className="flex items-start gap-2">
                        <Icon icon="mdi:information-outline" className="w-4 h-4 text-yellow-600 mt-0.5" />
                        <div className="text-sm text-yellow-800">
                          <p className="font-medium">Importante:</p>
                          <p>Se generará una contraseña temporal y se enviará por email al administrador.</p>
                        </div>
                      </div>
                    </div>
                  </div>
                </ModalBody>
                <ModalFooter>
                  <Button
                    color="danger"
                    variant="light"
                    onPress={onClose}
                  >
                    Cancelar
                  </Button>
                  <Button
                    color="primary"
                    onPress={handleConfirmedSubmit}
                    isLoading={isSubmitting}
                    startContent={!isSubmitting ? <Icon icon="mdi:check" className="w-4 h-4" /> : null}
                  >
                    {isSubmitting ? "Registrando..." : "Confirmar Registro"}
                  </Button>
                </ModalFooter>
              </>
            )}
          </ModalContent>
        </Modal>

        {/* Success Modal */}
        <Modal
          isOpen={registrationSuccess.show}
          onOpenChange={(open) => {
            if (!open) {
              setRegistrationSuccess({ show: false });
              onOpenChange(); // Close the main modal too
            }
          }}
          placement="center"
          size="lg"
          isDismissable={false}
          hideCloseButton={false}
        >
          <ModalContent>
            {(onClose) => (
              <>
                <ModalHeader className="flex flex-col gap-1">
                  <div className="flex items-center gap-2">
                    <div className="p-2 bg-green-100 rounded-full">
                      <Icon icon="mdi:check-circle" className="w-6 h-6 text-green-600" />
                    </div>
                    <h3 className="text-lg font-semibold text-green-800">¡Registro Exitoso!</h3>
                  </div>
                </ModalHeader>
                <ModalBody>
                  <div className="flex flex-col gap-4">
                    <p className="text-gray-700">
                      El administrador ha sido registrado exitosamente en el sistema.
                    </p>
                    {registrationSuccess.adminData && (
                      <div className="bg-green-50 border border-green-200 rounded-lg p-4">
                        <h4 className="font-semibold text-green-800 mb-3">Detalles del Registro:</h4>
                        <div className="space-y-2 text-sm">
                          <div className="flex justify-between">
                            <span className="font-medium text-gray-600">ID de Usuario:</span>
                            <span className="font-mono text-xs bg-gray-100 px-2 py-1 rounded">
                              {registrationSuccess.adminData.user_id}
                            </span>
                          </div>
                          <div className="flex justify-between">
                            <span className="font-medium text-gray-600">Nombre:</span>
                            <span>
                              {registrationSuccess.adminData.first_name} {registrationSuccess.adminData.last_name}
                            </span>
                          </div>
                          <div className="flex justify-between">
                            <span className="font-medium text-gray-600">Email:</span>
                            <span>{registrationSuccess.adminData.email}</span>
                          </div>
                          <div className="flex justify-between">
                            <span className="font-medium text-gray-600">ID de Asignación:</span>
                            <span className="font-mono text-xs bg-gray-100 px-2 py-1 rounded">
                              {registrationSuccess.adminData.role_assignment_id}
                            </span>
                          </div>
                        </div>
                      </div>
                    )}
                    <div className="bg-blue-50 border border-blue-200 rounded-lg p-4">
                      <div className="flex items-start gap-2">
                        <Icon icon="mdi:email-outline" className="w-5 h-5 text-blue-600 mt-0.5" />
                        <div className="text-sm text-blue-800">
                          <p className="font-medium mb-1">Email de Bienvenida Enviado</p>
                          <p>
                            Se ha enviado un email con las credenciales temporales y las instrucciones
                            de acceso al administrador registrado.
                          </p>
                        </div>
                      </div>
                    </div>
                    <div className="bg-yellow-50 border border-yellow-200 rounded-lg p-4">
                      <div className="flex items-start gap-2">
                        <Icon icon="mdi:clock-outline" className="w-5 h-5 text-yellow-600 mt-0.5" />
                        <div className="text-sm text-yellow-800">
                          <p className="font-medium mb-1">Próximos Pasos</p>
                          <ul className="list-disc list-inside space-y-1">
                            <li>El administrador debe revisar su email</li>
                            <li>Debe cambiar la contraseña temporal en el primer acceso</li>
                            <li>Tendrá acceso a las funciones de su ciudad y deporte asignados</li>
                          </ul>
                        </div>
                      </div>
                    </div>
                  </div>
                </ModalBody>
                <ModalFooter>
                  <Button
                    color="primary"
                    onPress={onClose}
                    startContent={<Icon icon="mdi:check" className="w-4 h-4" />}
                  >
                    Entendido
                  </Button>
                  <Button
                    color="secondary"
                    variant="light"
                    onPress={() => {
                      // Reset and open new registration
                      onClose();
                      setTimeout(() => onOpen(), 100);
                    }}
                    startContent={<Icon icon="mdi:plus" className="w-4 h-4" />}
                  >
                    Registrar Otro
                  </Button>
                </ModalFooter>
              </>
            )}
          </ModalContent>
        </Modal>

        {/* Notifications */}
        {notifications.map((notification) => (
          <Notification
            key={notification.id}
            type={notification.type}
            title={notification.title}
            message={notification.message}
            duration={notification.duration}
            onClose={() => removeNotification(notification.id)}
          />
        ))}
      </section>
    </DefaultLayout>
  );
}