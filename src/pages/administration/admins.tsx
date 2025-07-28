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
import React, { useState } from "react";
import { useEmailValidation } from "@/hooks/useEmailValidation";
import { useNotification } from "@/hooks/useNotification";
import { useFormValidation, commonValidationRules } from "@/hooks/useFormValidation";
import { usePhoneValidation } from "@/hooks/usePhoneValidation";
import { useIdentificationValidation } from "@/hooks/useIdentificationValidation";
import {
  adminService,
  citiesService,
  sportsService,
  type AdminRegistrationData,
  type City,
  type Sport
} from "@/services";
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
    account_status: "active",
    photo_url: ""
  });

  const [cities, setCities] = useState<City[]>([]);
  const [sports, setSports] = useState<Sport[]>([]);
  const [loadingData, setLoadingData] = useState(false);
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
    first_name: commonValidationRules.name,
    last_name: commonValidationRules.name,
    email: commonValidationRules.email,
    phone: commonValidationRules.phone,
    identification: commonValidationRules.identification,
    city_id: { required: true },
    sport_id: { required: true },
    photo_url: commonValidationRules.url
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

  // Datos de ejemplo para los administradores
  const admins = [
    {
      id: 1,
      name: "Carlos Rodriguez",
      email: "carlos@example.com",
      phone: "+57 300 1234567",
      joinDate: "15 Enero, 2022",
      status: "Activo",
      avatar: "https://i.pinimg.com/736x/ec/ce/ae/ecceaee5b4c02ce2c5030da88e530169.jpg"
    },
    {
      id: 2,
      name: "Carlos Rodriguez",
      email: "carlos@example.com",
      phone: "+57 300 1234567",
      joinDate: "15 Enero, 2022",
      status: "Activo",
      avatar: "https://i.pinimg.com/736x/ec/ce/ae/ecceaee5b4c02ce2c5030da88e530169.jpg"
    },
    {
      id: 3,
      name: "Carlos Rodriguez",
      email: "carlos@example.com",
      phone: "+57 300 1234567",
      joinDate: "15 Enero, 2022",
      status: "Inactivo",
      avatar: "https://i.pinimg.com/736x/ec/ce/ae/ecceaee5b4c02ce2c5030da88e530169.jpg"
    },
    {
      id: 4,
      name: "Carlos Rodriguez",
      email: "carlos@example.com",
      phone: "+57 300 1234567",
      joinDate: "15 Enero, 2022",
      status: "Activo",
      avatar: "https://i.pinimg.com/736x/ec/ce/ae/ecceaee5b4c02ce2c5030da88e530169.jpg"
    },
    {
      id: 5,
      name: "Carlos Rodriguez",
      email: "carlos@example.com",
      phone: "+57 300 1234567",
      joinDate: "15 Enero, 2022",
      status: "Activo",
      avatar: "https://i.pinimg.com/736x/ec/ce/ae/ecceaee5b4c02ce2c5030da88e530169.jpg"
    },
    {
      id: 6,
      name: "Carlos Rodriguez",
      email: "carlos@example.com",
      phone: "+57 300 1234567",
      joinDate: "15 Enero, 2022",
      status: "Inactivo",
      avatar: "https://i.pinimg.com/736x/ec/ce/ae/ecceaee5b4c02ce2c5030da88e530169.jpg"
    }
  ];

  const getStatusColor = (status: string) => {
    return status === "Activo" ? "success" : "danger";
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

  // Load cities and sports on component mount
  React.useEffect(() => {
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
        console.error("Error loading cities and sports:", error);
        // Services will return mock data on error, so we can continue
      } finally {
        setLoadingData(false);
      }
    };

    loadCitiesAndSports();
  }, []);

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
        account_status: formData.account_status,
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
        account_status: "active",
        photo_url: ""
      });

      // Reset all validation states
      validationState.errors = {};
      validationState.touched = {};

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
              <p className="text-gray-600">Administra los usuarios con permisos administrativos en el sistema</p>
            </div>

            {/* Actions Bar */}
            <div className="flex flex-col py-4 sm:flex-row gap-4 justify-between items-start sm:items-center">
              <Input
                placeholder="Filter tasks..."
                startContent={<Icon icon="mdi:magnify" className="w-4 h-4 text-gray-400" />}
                className="max-w-xs"
                variant="bordered"
              />

              <div className="flex gap-2">
                <Button
                  variant="bordered"
                  startContent={<Icon icon="mdi:export" className="w-4 h-4" />}
                >
                  Exportar
                </Button>
              </div>
            </div>

            {/* Cards Grid */}
            <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4 gap-4">
              {admins.map((admin) => (
                <Card key={admin.id} className="p-4">
                  <CardHeader className="flex justify-between items-start p-0 pb-3">
                    <div className="flex items-center gap-3">
                      <Avatar
                        src={admin.avatar}
                        name={admin.name}
                        size="md"
                      />
                      <div>
                        <h3 className="font-semibold text-sm">{admin.name}</h3>
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
                        <DropdownItem key="edit">Editar</DropdownItem>
                        <DropdownItem key="delete" className="text-danger">
                          Eliminar
                        </DropdownItem>
                      </DropdownMenu>
                    </Dropdown>
                  </CardHeader>

                  <CardBody className="p-0 gap-3">
                    <div className="flex flex-col gap-2 text-sm">
                      <div className="flex items-center gap-2">
                        <Icon icon="mdi:email-outline" className="w-4 h-4 text-gray-500" />
                        <span className="text-gray-700">{admin.email}</span>
                      </div>
                      <div className="flex items-center gap-2">
                        <Icon icon="mdi:phone-outline" className="w-4 h-4 text-gray-500" />
                        <span className="text-gray-700">{admin.phone}</span>
                      </div>
                      <div className="flex items-center gap-2">
                        <Icon icon="mdi:calendar-outline" className="w-4 h-4 text-gray-500" />
                        <span className="text-gray-700">Ingreso: {admin.joinDate}</span>
                      </div>
                    </div>

                    <div className="flex justify-between items-center pt-2">
                      <span className="text-xs text-gray-500">Torneos</span>
                      <Chip
                        size="sm"
                        color={getStatusColor(admin.status)}
                        variant="flat"
                      >
                        {admin.status}
                      </Chip>
                    </div>
                  </CardBody>
                </Card>
              ))}
            </div>

            {/* Footer with Pagination */}
            <div className="flex flex-col sm:flex-row gap-4 justify-between items-center pt-4">
              <div className="flex items-center gap-4">
                <span className="text-sm text-gray-600">0 of 100 row(s) selected.</span>
                <div className="flex items-center gap-2">
                  <span className="text-sm">Rows per page</span>
                  <Select
                    size="sm"
                    className="w-20"
                    defaultSelectedKeys={["10"]}
                  >
                    <SelectItem key="10">10</SelectItem>
                    <SelectItem key="20">20</SelectItem>
                    <SelectItem key="50">50</SelectItem>
                  </Select>
                </div>
              </div>

              <div className="flex items-center gap-4">
                <span className="text-sm text-gray-600">Page 1 of 10</span>
                <Pagination
                  total={10}
                  initialPage={1}
                  size="sm"
                  showControls
                />
              </div>
            </div>
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
                            <SelectItem key={city.city_id} value={city.city_id}>
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
                            <SelectItem key={sport.sport_id} value={sport.sport_id}>
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