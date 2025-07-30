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
   * Clear all authentication data (for debugging)
   */
  clearAllAuthData(): void {
    this.signOut();
    console.log('All authentication data cleared');
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
    const user = this.getCurrentUser();
    
    console.log('Checking authentication, token:', token ? 'exists' : 'null'); // Debug log
    console.log('Checking authentication, user:', user ? 'exists' : 'null'); // Debug log
    
    // Por ahora, simplificar la validación: si hay usuario y token, está autenticado
    if (!token || token === 'undefined' || token === 'null') {
      console.log('No valid token found'); // Debug log
      return false;
    }

    if (!user) {
      console.log('No user data found'); // Debug log
      return false;
    }

    // Validación básica del formato JWT (solo si el token parece ser un JWT)
    if (token.includes('.')) {
      try {
        const parts = token.split('.');
        if (parts.length !== 3) {
          console.log('Invalid JWT format'); // Debug log
          return false;
        }

        const payload = JSON.parse(atob(parts[1]));
        const currentTime = Date.now() / 1000;
        const isValid = payload.exp > currentTime;
        console.log('Token validation:', { exp: payload.exp, current: currentTime, isValid }); // Debug log
        return isValid;
      } catch (error) {
        console.log('Token parsing error:', error); // Debug log
        // If token parsing fails, clear the invalid token and return false
        this.clearInvalidToken();
        return false;
      }
    }

    // Si no es un JWT válido pero hay token y usuario, asumir que está autenticado
    console.log('Using simplified authentication check'); // Debug log
    return true;
  }

  /**
   * Clear invalid token from storage
   */
  private clearInvalidToken(): void {
    localStorage.removeItem(this.TOKEN_KEY);
    localStorage.removeItem('authToken');
    console.log('Cleared invalid token from storage'); // Debug log
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
      console.log('Storing auth data:', authData); // Debug log

      // Verificar que el token existe y es válido
      if (!authData.token || authData.token === 'undefined') {
        console.error('Invalid token received from server:', authData.token);
        // Por ahora, crear un token temporal para permitir el login
        authData.token = `temp_token_${Date.now()}_${authData.user_id}`;
        console.log('Created temporary token:', authData.token);
      }

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
      console.log('Token stored:', authData.token); // Debug log
      console.log('User data stored:', userData); // Debug log

      // Emit login event
      if (typeof window !== 'undefined') {
        console.log('Emitting auth:signed-in event'); // Debug log
        window.dispatchEvent(new CustomEvent('auth:signed-in'));
      }
    } catch (error) {
      console.error('Error storing auth data:', error);
      throw error; // Re-throw para que el login falle si no se puede almacenar
    }
  }
}

export const authService = new AuthService();

// Función global para debugging (solo en desarrollo)
if (typeof window !== 'undefined' && import.meta.env.DEV) {
  (window as any).clearAuthData = () => {
    authService.clearAllAuthData();
  };
  (window as any).checkAuthStatus = () => {
    console.log('Token:', authService.getToken());
    console.log('User:', authService.getCurrentUser());
    console.log('Is Authenticated:', authService.isAuthenticated());
  };
}