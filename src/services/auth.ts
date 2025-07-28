import { BaseApiService } from './baseApiService';
import type {
  SignupRequest,
  SignupResponse,
  LoginRequest,
  LoginResponse,
  UserProfile
} from './types';

// Legacy interfaces for backward compatibility
export interface SignUpData {
  name: string;
  email: string;
  password: string;
}

export interface SignInData {
  email: string;
  password: string;
}

export interface AuthResponse {
  success: boolean;
  message: string;
  error?: string;
  data?: {
    id: number;
    name?: string;
    email: string;
    token?: string;
  };
}

class AuthService extends BaseApiService {
  private readonly TOKEN_KEY = 'auth_token';
  private readonly USER_KEY = 'current_user';
  private readonly REFRESH_TOKEN_KEY = 'refresh_token';

  constructor() {
    super();

    // Listen for auth logout events
    if (typeof window !== 'undefined') {
      window.addEventListener('auth:logout', () => {
        this.signOut();
      });
    }
  }

  /**
   * Sign up new user (legacy method for backward compatibility)
   */
  async signUp(data: SignUpData): Promise<AuthResponse> {
    try {
      const signupData: SignupRequest = {
        first_name: data.name.split(' ')[0] || data.name,
        last_name: data.name.split(' ').slice(1).join(' ') || '',
        email: data.email,
        password: data.password
      };

      const result = await this.post<SignupResponse>('/auth/signup', signupData);

      return {
        success: true,
        message: 'Usuario creado exitosamente',
        data: {
          id: parseInt(result.user_id),
          name: `${result.first_name} ${result.last_name}`,
          email: result.email
        }
      };
    } catch (error) {
      console.error('Sign up error:', error);

      let errorMessage = 'Error al crear usuario';
      if (error instanceof Error) {
        if (error.message.includes('email')) {
          errorMessage = 'El email ya está registrado';
        } else if (error.message.includes('password')) {
          errorMessage = 'La contraseña no cumple con los requisitos';
        } else if (error.message.includes('Network')) {
          errorMessage = 'Error de conexión. Verifica que el servidor esté ejecutándose.';
        }
      }

      return {
        success: false,
        message: errorMessage,
        error: error instanceof Error ? error.message : 'Unknown error'
      };
    }
  }

  /**
   * Sign in user (legacy method for backward compatibility)
   */
  async signIn(email: string, password: string): Promise<AuthResponse> {
    try {
      const loginData: LoginRequest = { email, password };
      const result = await this.post<LoginResponse>('/auth/login', loginData);

      // Store authentication data
      this.storeAuthData(result);

      return {
        success: true,
        message: 'Inicio de sesión exitoso',
        data: {
          id: parseInt(result.user_id),
          email: result.email,
          token: result.token
        }
      };
    } catch (error) {
      console.error('Sign in error:', error);

      let errorMessage = 'Error al iniciar sesión';
      if (error instanceof Error) {
        if (error.message.includes('404') || error.message.includes('not found')) {
          errorMessage = 'El usuario no se encuentra registrado';
        } else if (error.message.includes('401') || error.message.includes('credentials')) {
          errorMessage = 'Las credenciales son incorrectas';
        } else if (error.message.includes('locked')) {
          errorMessage = 'Cuenta bloqueada por múltiples intentos fallidos';
        } else if (error.message.includes('Network')) {
          errorMessage = 'Error de conexión. Verifica que el servidor esté ejecutándose.';
        }
      }

      return {
        success: false,
        message: errorMessage,
        error: error instanceof Error ? error.message : 'Unknown error'
      };
    }
  }

  /**
   * Modern login method with full type support
   */
  async login(data: LoginRequest): Promise<LoginResponse> {
    try {
      const result = await this.post<LoginResponse>('/auth/login', data);
      this.storeAuthData(result);
      return result;
    } catch (error) {
      console.error('Login error:', error);
      throw error;
    }
  }

  /**
   * Modern signup method with full type support
   */
  async signup(data: SignupRequest): Promise<SignupResponse> {
    try {
      const result = await this.post<SignupResponse>('/auth/signup', data);
      return result;
    } catch (error) {
      console.error('Signup error:', error);
      throw error;
    }
  }

  /**
   * Sign out user and clear all stored data
   */
  signOut(): void {
    try {
      // Clear all auth-related data
      localStorage.removeItem(this.TOKEN_KEY);
      localStorage.removeItem('authToken'); // Legacy key
      localStorage.removeItem(this.USER_KEY);
      localStorage.removeItem('user'); // Legacy key
      localStorage.removeItem(this.REFRESH_TOKEN_KEY);

      // Clear service caches
      localStorage.removeItem('cities_cache');
      localStorage.removeItem('sports_cache');

      console.info('User signed out successfully');

      // Emit logout event
      if (typeof window !== 'undefined') {
        window.dispatchEvent(new CustomEvent('auth:signed-out'));
      }
    } catch (error) {
      console.error('Error during sign out:', error);
    }
  }

  /**
   * Get current authentication token
   */
  getToken(): string | null {
    return localStorage.getItem(this.TOKEN_KEY) || localStorage.getItem('authToken');
  }

  /**
   * Get current user data
   */
  getCurrentUser(): UserProfile | null {
    try {
      const user = localStorage.getItem(this.USER_KEY) || localStorage.getItem('user');
      return user ? JSON.parse(user) : null;
    } catch (error) {
      console.error('Error parsing user data:', error);
      return null;
    }
  }

  /**
   * Check if user is authenticated
   */
  isAuthenticated(): boolean {
    const token = this.getToken();
    if (!token) return false;

    // Check if token is expired (basic check)
    try {
      const payload = JSON.parse(atob(token.split('.')[1]));
      const currentTime = Date.now() / 1000;
      return payload.exp > currentTime;
    } catch {
      // If token parsing fails, assume it's invalid
      return false;
    }
  }

  /**
   * Refresh authentication token
   */
  async refreshToken(): Promise<LoginResponse> {
    try {
      const refreshToken = localStorage.getItem(this.REFRESH_TOKEN_KEY);
      if (!refreshToken) {
        throw new Error('No refresh token available');
      }

      const result = await this.post<LoginResponse>('/auth/refresh', {
        refresh_token: refreshToken
      });

      this.storeAuthData(result);
      return result;
    } catch (error) {
      console.error('Token refresh error:', error);
      this.signOut(); // Clear invalid tokens
      throw error;
    }
  }

  /**
   * Get user profile information
   */
  async getProfile(): Promise<UserProfile> {
    try {
      const profile = await this.get<UserProfile>('/auth/profile');

      // Update stored user data
      localStorage.setItem(this.USER_KEY, JSON.stringify(profile));

      return profile;
    } catch (error) {
      console.error('Error fetching profile:', error);
      throw error;
    }
  }

  /**
   * Store authentication data securely
   */
  private storeAuthData(authData: LoginResponse): void {
    try {
      // Store tokens
      localStorage.setItem(this.TOKEN_KEY, authData.token);
      if (authData.refresh_token) {
        localStorage.setItem(this.REFRESH_TOKEN_KEY, authData.refresh_token);
      }

      // Store user data
      const userData: UserProfile = {
        user_id: authData.user_id,
        email: authData.email,
        first_name: authData.first_name,
        last_name: authData.last_name,
        primary_role: authData.primary_role,
        phone: undefined,
        identification: undefined,
        photo_url: undefined,
        is_active: true,
        account_status: 'active',
        failed_login_attempts: 0,
        two_factor_enabled: false,
        created_at: new Date().toISOString(),
        updated_at: new Date().toISOString()
      };

      localStorage.setItem(this.USER_KEY, JSON.stringify(userData));

      // Legacy compatibility
      localStorage.setItem('authToken', authData.token);
      localStorage.setItem('user', JSON.stringify({
        id: parseInt(authData.user_id),
        email: authData.email
      }));

      console.info('Authentication data stored successfully');
    } catch (error) {
      console.error('Error storing auth data:', error);
    }
  }
}

export const authService = new AuthService();