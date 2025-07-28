interface AdminRegistrationData {
  first_name: string;
  last_name: string;
  email: string;
  phone?: string;
  identification?: string;
  city_id: string;
  sport_id: string;
  account_status: string;
  photo_url?: string;
}

interface AdminRegistrationResponse {
  user_id: string;
  email: string;
  first_name: string;
  last_name: string;
  role_assignment_id: string;
  message: string;
}

interface ApiError {
  code: string;
  message: string;
  details?: any;
}

class AdminService {
  private baseUrl = '/api';

  async registerAdmin(data: AdminRegistrationData): Promise<AdminRegistrationResponse> {
    try {
      const response = await fetch(`${this.baseUrl}/admin/register`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${this.getAuthToken()}`
        },
        body: JSON.stringify(data)
      });

      if (!response.ok) {
        const errorData = await response.json();
        throw new Error(errorData.message || 'Error registrando administrador');
      }

      return await response.json();
    } catch (error) {
      console.error('Error in registerAdmin:', error);
      throw error;
    }
  }

  async validateEmailUniqueness(email: string): Promise<{ isUnique: boolean; message?: string }> {
    try {
      const response = await fetch(`${this.baseUrl}/admin/validate-email?email=${encodeURIComponent(email)}`, {
        method: 'GET',
        headers: {
          'Authorization': `Bearer ${this.getAuthToken()}`
        }
      });

      if (!response.ok) {
        throw new Error('Error validating email');
      }

      return await response.json();
    } catch (error) {
      console.error('Error in validateEmailUniqueness:', error);
      // Return true on error to not block the user
      return { isUnique: true };
    }
  }

  async getAdmins(page = 1, limit = 10, search?: string): Promise<{
    admins: any[];
    total: number;
    page: number;
    totalPages: number;
  }> {
    try {
      const params = new URLSearchParams({
        page: page.toString(),
        limit: limit.toString(),
        ...(search && { search })
      });

      const response = await fetch(`${this.baseUrl}/admin/list?${params}`, {
        method: 'GET',
        headers: {
          'Authorization': `Bearer ${this.getAuthToken()}`
        }
      });

      if (!response.ok) {
        throw new Error('Error loading administrators');
      }

      return await response.json();
    } catch (error) {
      console.error('Error in getAdmins:', error);
      throw error;
    }
  }

  async updateAdminStatus(adminId: string, status: string): Promise<void> {
    try {
      const response = await fetch(`${this.baseUrl}/admin/${adminId}/status`, {
        method: 'PUT',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${this.getAuthToken()}`
        },
        body: JSON.stringify({ account_status: status })
      });

      if (!response.ok) {
        const errorData = await response.json();
        throw new Error(errorData.message || 'Error updating admin status');
      }
    } catch (error) {
      console.error('Error in updateAdminStatus:', error);
      throw error;
    }
  }

  private getAuthToken(): string {
    // TODO: Implement proper token management
    return localStorage.getItem('auth_token') || '';
  }
}

export const adminService = new AdminService();
export type { AdminRegistrationData, AdminRegistrationResponse, ApiError };