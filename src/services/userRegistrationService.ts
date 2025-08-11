import { BaseApiService } from './baseApiService';
import { requestManager } from '../utils/requestManager';
import type { 
  ApiResponse, 
  UserRole, 
  AccountStatus, 
  City, 
  Sport,
  UserProfile 
} from './types';

// Registration data interfaces for different user types
export interface BaseUserRegistrationData {
  first_name: string;
  last_name: string;
  email: string;
  phone?: string;
  identification?: string;
  photo_url?: string;
  account_status?: AccountStatus;
}

export interface CityAdminRegistrationData extends BaseUserRegistrationData {
  city_id: string;
  sport_id: string;
}

export interface OwnerRegistrationData extends BaseUserRegistrationData {
  city_id: string;
  sport_id: string;
}

export interface RefereeRegistrationData extends BaseUserRegistrationData {
  city_id: string;
  sport_id: string;
  certification_level?: string;
  experience_years?: number;
}

export interface PlayerRegistrationData extends BaseUserRegistrationData {
  date_of_birth: string;
  blood_type?: string;
  emergency_contact?: {
    name: string;
    phone: string;
    relationship: string;
  };
  medical_info?: {
    allergies?: string;
    medications?: string;
    medical_conditions?: string;
  };
  position?: string;
  jersey_number?: number;
}

export interface CoachRegistrationData extends BaseUserRegistrationData {
  certification_level?: string;
  experience_years?: number;
  specialization?: string;
}

// Registration response interfaces
export interface UserRegistrationResponse {
  user_id: string;
  email: string;
  first_name: string;
  last_name: string;
  primary_role: UserRole;
  role_assignment_id?: string;
  temporary_password: string;
  message: string;
  login_url?: string;
}

// Email validation interface
export interface EmailValidationResponse {
  is_valid: boolean;
  is_unique: boolean;
  message?: string;
}

// User list interfaces
export interface UserListRequest {
  page?: number;
  limit?: number;
  search?: string;
  role?: UserRole;
  account_status?: AccountStatus;
  city_id?: string;
  sport_id?: string;
  sort_by?: string;
  sort_order?: 'asc' | 'desc';
}

export interface UserSummary {
  user_id: string;
  email: string;
  first_name: string;
  last_name: string;
  phone?: string;
  photo_url?: string;
  primary_role: UserRole;
  account_status: AccountStatus;
  city_name?: string;
  sport_name?: string;
  last_login_at?: string;
  created_at: string;
  is_active: boolean;
}

export interface UserListResponse {
  users: UserSummary[];
  total: number;
  page: number;
  limit: number;
  total_pages: number;
  has_next: boolean;
  has_prev: boolean;
}

class UserRegistrationService extends BaseApiService {
  constructor() {
    super(); // Use default /api prefix
  }

  // Email validation
  async validateEmailUniqueness(email: string): Promise<EmailValidationResponse> {
    try {
      const response = await this.get(`/users/validate-email?email=${encodeURIComponent(email)}`);
      return response.data;
    } catch (error) {
      console.error('Error validating email:', error);
      throw new Error('Error validating email uniqueness');
    }
  }

  // City Admin Registration (Super Admin only)
  async registerCityAdmin(data: CityAdminRegistrationData): Promise<UserRegistrationResponse> {
    try {
      const response = await this.post('/users/register/city-admin', data);
      return response.data;
    } catch (error) {
      console.error('Error registering city admin:', error);
      throw this.handleRegistrationError(error);
    }
  }

  // Owner Registration (City Admin only)
  async registerOwner(data: OwnerRegistrationData): Promise<UserRegistrationResponse> {
    try {
      const response = await this.post('/users/register/owner', data);
      return response.data;
    } catch (error) {
      console.error('Error registering owner:', error);
      throw this.handleRegistrationError(error);
    }
  }

  // Referee Registration (City Admin only)
  async registerReferee(data: RefereeRegistrationData): Promise<UserRegistrationResponse> {
    try {
      const response = await this.post('/users/register/referee', data);
      return response.data;
    } catch (error) {
      console.error('Error registering referee:', error);
      throw this.handleRegistrationError(error);
    }
  }

  // Player Registration (Owner only)
  async registerPlayer(data: PlayerRegistrationData): Promise<UserRegistrationResponse> {
    try {
      const response = await this.post('/users/register/player', data);
      return response.data;
    } catch (error) {
      console.error('Error registering player:', error);
      throw this.handleRegistrationError(error);
    }
  }

  // Coach Registration (Owner only)
  async registerCoach(data: CoachRegistrationData): Promise<UserRegistrationResponse> {
    try {
      const response = await this.post('/users/register/coach', data);
      return response.data;
    } catch (error) {
      console.error('Error registering coach:', error);
      throw this.handleRegistrationError(error);
    }
  }

  // Get users list with filtering and pagination
  async getUsersList(params: UserListRequest = {}): Promise<UserListResponse> {
    const queryParams = new URLSearchParams();
    
    if (params.page) queryParams.append('page', params.page.toString());
    if (params.limit) queryParams.append('limit', params.limit.toString());
    if (params.search) queryParams.append('search', params.search);
    if (params.role) queryParams.append('role', params.role);
    if (params.account_status) queryParams.append('account_status', params.account_status);
    if (params.city_id) queryParams.append('city_id', params.city_id);
    if (params.sport_id) queryParams.append('sport_id', params.sport_id);
    if (params.sort_by) queryParams.append('sort_by', params.sort_by);
    if (params.sort_order) queryParams.append('sort_order', params.sort_order);

    const url = `/users?${queryParams.toString()}`;
    
    return requestManager.request(
      url,
      async () => {
        try {
          const response = await this.get(url);
          return response.data;
        } catch (error) {
          console.error('Error fetching users list:', error);
          throw new Error('Error fetching users list');
        }
      },
      params,
      { 
        ttl: 30 * 1000, // 30 seconds cache for user lists (more dynamic data)
        forceRefresh: false 
      }
    );
  }

  // Get user details by ID
  async getUserById(userId: string): Promise<UserProfile> {
    try {
      const response = await this.get(`/users/${userId}`);
      return response.data;
    } catch (error) {
      console.error('Error fetching user details:', error);
      throw new Error('Error fetching user details');
    }
  }

  // Update user account status
  async updateUserStatus(userId: string, status: AccountStatus, reason?: string): Promise<void> {
    try {
      await this.patch(`/users/${userId}/status`, {
        account_status: status,
        reason
      });
    } catch (error) {
      console.error('Error updating user status:', error);
      throw new Error('Error updating user status');
    }
  }

  // Regenerate temporary password
  async regenerateTemporaryPassword(userId: string): Promise<{ temporary_password: string }> {
    try {
      const response = await this.post(`/users/${userId}/regenerate-password`);
      return response.data;
    } catch (error) {
      console.error('Error regenerating password:', error);
      throw new Error('Error regenerating temporary password');
    }
  }

  // Get available cities and sports for current user context
  async getAvailableCitiesAndSports(): Promise<{ cities: City[]; sports: Sport[] }> {
    try {
      const [citiesResponse, sportsResponse] = await Promise.all([
        this.get('/cities'),
        this.get('/sports')
      ]);

      return {
        cities: citiesResponse.data,
        sports: sportsResponse.data
      };
    } catch (error) {
      console.error('Error fetching cities and sports:', error);
      throw new Error('Error fetching available cities and sports');
    }
  }

  // Validation helpers
  isValidEmailFormat(email: string): boolean {
    const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
    return emailRegex.test(email);
  }

  isValidPhoneFormat(phone: string): boolean {
    const phoneRegex = /^(\+\d{1,3})?[\s\-]?\d{3}[\s\-]?\d{3}[\s\-]?\d{4}$/;
    return phoneRegex.test(phone);
  }

  validateRegistrationData(data: BaseUserRegistrationData): string[] {
    const errors: string[] = [];

    if (!data.first_name?.trim()) {
      errors.push('First name is required');
    } else if (data.first_name.trim().length < 2) {
      errors.push('First name must be at least 2 characters');
    }

    if (!data.last_name?.trim()) {
      errors.push('Last name is required');
    } else if (data.last_name.trim().length < 2) {
      errors.push('Last name must be at least 2 characters');
    }

    if (!data.email?.trim()) {
      errors.push('Email is required');
    } else if (!this.isValidEmailFormat(data.email)) {
      errors.push('Invalid email format');
    }

    if (data.phone && !this.isValidPhoneFormat(data.phone)) {
      errors.push('Invalid phone format');
    }

    if (data.identification && data.identification.length < 5) {
      errors.push('Identification must be at least 5 characters');
    }

    return errors;
  }

  // Error handling helper
  private handleRegistrationError(error: any): Error {
    if (error?.response?.data?.error) {
      const apiError = error.response.data.error;
      if (apiError.code === 'VALIDATION_ERROR') {
        return new Error(apiError.message);
      } else if (apiError.code === 'EMAIL_EXISTS') {
        return new Error('Email address is already registered');
      } else if (apiError.code === 'PERMISSION_DENIED') {
        return new Error('You do not have permission to register this type of user');
      } else {
        return new Error(apiError.message || 'Registration failed');
      }
    }
    return new Error('Registration failed due to server error');
  }
}

export const userRegistrationService = new UserRegistrationService();