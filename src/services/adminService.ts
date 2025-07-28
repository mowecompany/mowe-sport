import { BaseApiService } from './baseApiService';
import type {
  AdminRegistrationData,
  AdminRegistrationResponse,
  EmailValidationResponse,
  AdminListResponse,
  AdminStatusUpdateRequest,
  PaginationParams,
  ApiError
} from './types';

class AdminService extends BaseApiService {
  constructor() {
    super();
  }

  /**
   * Register a new administrator with comprehensive error handling
   */
  async registerAdmin(data: AdminRegistrationData): Promise<AdminRegistrationResponse> {
    try {
      // Validate required fields before sending
      this.validateRegistrationData(data);

      const response = await this.post<AdminRegistrationResponse>('/admin/register', data);
      
      // Log successful registration for audit
      console.info('Admin registered successfully:', {
        email: data.email,
        city_id: data.city_id,
        sport_id: data.sport_id
      });

      return response;
    } catch (error) {
      // Enhanced error handling with specific error types
      if (error instanceof Error) {
        if (error.message.includes('email')) {
          throw new Error('El email ya está registrado en el sistema');
        } else if (error.message.includes('city_id')) {
          throw new Error('La ciudad seleccionada no es válida');
        } else if (error.message.includes('sport_id')) {
          throw new Error('El deporte seleccionado no es válido');
        } else if (error.message.includes('permission')) {
          throw new Error('No tienes permisos para registrar administradores');
        } else if (error.message.includes('Authentication required')) {
          throw new Error('Sesión expirada. Por favor inicia sesión nuevamente');
        }
      }
      
      console.error('Error in registerAdmin:', error);
      throw error;
    }
  }

  /**
   * Validate email uniqueness with debounced checking
   */
  async validateEmailUniqueness(email: string): Promise<EmailValidationResponse> {
    try {
      if (!email || !this.isValidEmailFormat(email)) {
        return { isUnique: false, message: 'Formato de email inválido' };
      }

      const response = await this.get<EmailValidationResponse>(
        `/admin/validate-email?email=${encodeURIComponent(email)}`
      );

      return response;
    } catch (error) {
      console.error('Error in validateEmailUniqueness:', error);
      
      // Return optimistic result on network error to not block user
      return { 
        isUnique: true, 
        message: 'No se pudo validar el email. Se verificará al enviar el formulario.' 
      };
    }
  }

  /**
   * Get paginated list of administrators with search and filtering
   */
  async getAdmins(params: PaginationParams = {}): Promise<AdminListResponse> {
    try {
      const {
        page = 1,
        limit = 10,
        search,
        sort_by = 'created_at',
        sort_order = 'desc'
      } = params;

      const queryParams = new URLSearchParams({
        page: page.toString(),
        limit: limit.toString(),
        sort_by,
        sort_order,
        ...(search && { search })
      });

      const response = await this.get<AdminListResponse>(`/admin/list?${queryParams}`);
      
      return response;
    } catch (error) {
      console.error('Error in getAdmins:', error);
      
      // Return empty result on error
      return {
        admins: [],
        total: 0,
        page: 1,
        totalPages: 0,
        limit: 10
      };
    }
  }

  /**
   * Update administrator account status
   */
  async updateAdminStatus(adminId: string, statusData: AdminStatusUpdateRequest): Promise<void> {
    try {
      if (!adminId) {
        throw new Error('ID de administrador requerido');
      }

      await this.put(`/admin/${adminId}/status`, statusData);
      
      console.info('Admin status updated:', { adminId, status: statusData.account_status });
    } catch (error) {
      console.error('Error in updateAdminStatus:', error);
      
      if (error instanceof Error) {
        if (error.message.includes('not found')) {
          throw new Error('Administrador no encontrado');
        } else if (error.message.includes('permission')) {
          throw new Error('No tienes permisos para cambiar el estado de este administrador');
        }
      }
      
      throw error;
    }
  }

  /**
   * Get administrator details by ID
   */
  async getAdminById(adminId: string): Promise<AdminRegistrationResponse> {
    try {
      if (!adminId) {
        throw new Error('ID de administrador requerido');
      }

      const response = await this.get<AdminRegistrationResponse>(`/admin/${adminId}`);
      return response;
    } catch (error) {
      console.error('Error in getAdminById:', error);
      throw error;
    }
  }

  /**
   * Regenerate temporary password for administrator
   */
  async regeneratePassword(adminId: string): Promise<{ temporary_password: string; message: string }> {
    try {
      if (!adminId) {
        throw new Error('ID de administrador requerido');
      }

      const response = await this.post<{ temporary_password: string; message: string }>(
        `/admin/${adminId}/regenerate-password`
      );
      
      console.info('Password regenerated for admin:', adminId);
      return response;
    } catch (error) {
      console.error('Error in regeneratePassword:', error);
      throw error;
    }
  }

  /**
   * Validate registration data before sending to server
   */
  private validateRegistrationData(data: AdminRegistrationData): void {
    const errors: string[] = [];

    if (!data.first_name?.trim()) {
      errors.push('Nombre es requerido');
    }

    if (!data.last_name?.trim()) {
      errors.push('Apellido es requerido');
    }

    if (!data.email?.trim()) {
      errors.push('Email es requerido');
    } else if (!this.isValidEmailFormat(data.email)) {
      errors.push('Formato de email inválido');
    }

    if (!data.city_id) {
      errors.push('Ciudad es requerida');
    }

    if (!data.sport_id) {
      errors.push('Deporte es requerido');
    }

    if (data.phone && !this.isValidPhoneFormat(data.phone)) {
      errors.push('Formato de teléfono inválido');
    }

    if (errors.length > 0) {
      throw new Error(`Errores de validación: ${errors.join(', ')}`);
    }
  }

  /**
   * Validate email format
   */
  private isValidEmailFormat(email: string): boolean {
    const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
    return emailRegex.test(email);
  }

  /**
   * Validate phone format (international)
   */
  private isValidPhoneFormat(phone: string): boolean {
    const phoneRegex = /^\+?[\d\s\-\(\)]{10,}$/;
    return phoneRegex.test(phone);
  }
}

export const adminService = new AdminService();
export type { AdminRegistrationData, AdminRegistrationResponse, ApiError, EmailValidationResponse };