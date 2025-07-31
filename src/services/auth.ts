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
      console.log('[AUTH] Attempting login with:', email);
      const loginData: LoginRequest = { email, password };
      const result = await this.post<LoginResponse>('/auth/login', loginData);

      console.log('[AUTH] Login response received:', result);
      console.log('[AUTH] Login response data:', result.data);
      console.log('[AUTH] Token from response:', result.data?.token);

      // Store authentication data - pass the data object, not the full response
      await this.storeAuthData(result.data);

      return {
        success: true,
        message: 'Inicio de sesión exitoso',
        data: {
          id: parseInt(result.data.user_id),
          email: result.data.email,
          token: result.data.token
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
      await this.storeAuthData(result);
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
      console.log('Starting sign out process...'); // Debug log

      // Clear all auth-related data
      localStorage.removeItem(this.TOKEN_KEY);
      localStorage.removeItem('authToken'); // Legacy key
      localStorage.removeItem(this.USER_KEY);
      localStorage.removeItem('user'); // Legacy key
      localStorage.removeItem(this.REFRESH_TOKEN_KEY);

      // Clear service caches
      localStorage.removeItem('cities_cache');
      localStorage.removeItem('sports_cache');

      // Clear any other potential auth-related keys
      const keysToRemove = [];
      for (let i = 0; i < localStorage.length; i++) {
        const key = localStorage.key(i);
        if (key && (key.includes('auth') || key.includes('token') || key.includes('user'))) {
          keysToRemove.push(key);
        }
      }
      
      keysToRemove.forEach(key => {
        localStorage.removeItem(key);
        console.log('Removed key:', key); // Debug log
      });

      console.info('User signed out successfully');

      // Emit logout event BEFORE clearing everything to ensure handlers can access current state
      if (typeof window !== 'undefined') {
        window.dispatchEvent(new CustomEvent('auth:signed-out'));
        
        // Also emit a storage event to trigger updates in other tabs/components
        window.dispatchEvent(new StorageEvent('storage', {
          key: this.TOKEN_KEY,
          oldValue: 'some_token',
          newValue: null,
          storageArea: localStorage
        }));
      }

      // Force a small delay to ensure all event handlers have processed
      setTimeout(() => {
        console.log('Sign out process completed'); // Debug log
      }, 50);

    } catch (error) {
      console.error('Error during sign out:', error);
    }
  }

  /**
   * Clear all authentication data (for debugging)
   */
  clearAllAuthData(): void {
    this.signOut();
    
    // Limpiar también sessionStorage por si acaso
    sessionStorage.clear();
    
    // Limpiar cualquier cookie relacionada con auth
    document.cookie.split(";").forEach((c) => {
      document.cookie = c
        .replace(/^ +/, "")
        .replace(/=.*/, "=;expires=" + new Date().toUTCString() + ";path=/");
    });
    
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

      await this.storeAuthData(result);
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
      const profileResponse = await this.get<UserProfile>('/auth/profile');
      
      // The backend returns {success: true, data: UserProfile}, so we need to access .data
      const profile = profileResponse.data || profileResponse;

      // Update stored user data
      localStorage.setItem(this.USER_KEY, JSON.stringify(profile));

      return profile;
    } catch (error) {
      console.error('Error fetching profile:', error);
      throw error;
    }
  }

  private profilePromise: Promise<UserProfile> | null = null;

  /**
   * Get current user data with fresh data from server
   */
  async getCurrentUserFresh(): Promise<UserProfile | null> {
    try {
      if (!this.isAuthenticated()) {
        console.log('User not authenticated, returning null');
        return null;
      }

      // If there's already a profile request in progress, wait for it
      if (this.profilePromise) {
        console.log('Profile request already in progress, waiting...');
        try {
          return await this.profilePromise;
        } catch (error) {
          // If the existing promise fails, clear it and try again
          this.profilePromise = null;
        }
      }

      console.log('Fetching fresh profile data from server...');
      this.profilePromise = this.getProfile();
      
      try {
        const profile = await this.profilePromise;
        console.log('Fresh profile data received:', profile);
        this.profilePromise = null; // Clear the promise after success
        return profile;
      } catch (error) {
        this.profilePromise = null; // Clear the promise after error
        throw error;
      }
    } catch (error) {
      console.error('Error fetching fresh user data:', error);
      console.log('Falling back to cached user data');
      // Return cached data if server request fails
      const cachedUser = this.getCurrentUser();
      console.log('Cached user data:', cachedUser);
      return cachedUser;
    }
  }

  /**
   * Store authentication data securely
   */
  private async storeAuthData(authData: LoginResponse): Promise<void> {
    try {
      console.log('[AUTH] Storing auth data:', authData);

      // Verificar que el token existe y es válido
      if (!authData.token || authData.token === 'undefined') {
        console.error('[AUTH] Invalid token received from server:', authData.token);
        throw new Error('Invalid token received from server');
      }

      console.log('[AUTH] Token received:', authData.token.substring(0, 50) + '...');

      // Store tokens first
      localStorage.setItem(this.TOKEN_KEY, authData.token);
      if (authData.refresh_token) {
        localStorage.setItem(this.REFRESH_TOKEN_KEY, authData.refresh_token);
      }

      // Store basic user data first (from login response)
      const basicUserData: UserProfile = {
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

      localStorage.setItem(this.USER_KEY, JSON.stringify(basicUserData));

      // Legacy compatibility
      localStorage.setItem('authToken', authData.token);
      localStorage.setItem('user', JSON.stringify({
        id: parseInt(authData.user_id),
        email: authData.email
      }));

      console.info('Basic authentication data stored successfully');
      console.log('Token stored:', authData.token); // Debug log
      console.log('Basic user data stored:', basicUserData); // Debug log

      // Try to get complete profile data from server
      try {
        const completeProfileResponse = await this.get<UserProfile>('/auth/profile');
        // The backend returns {success: true, data: UserProfile}, so we need to access .data
        const completeProfile = completeProfileResponse.data || completeProfileResponse;
        localStorage.setItem(this.USER_KEY, JSON.stringify(completeProfile));
        console.log('Complete profile data stored:', completeProfile); // Debug log
      } catch (profileError) {
        console.warn('Could not fetch complete profile, using basic data:', profileError);
        // Continue with basic data if profile fetch fails
      }

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