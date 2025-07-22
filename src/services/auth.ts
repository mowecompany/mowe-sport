const API_BASE_URL = 'http://localhost:8080/api';

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

class AuthService {
  async signUp(data: SignUpData): Promise<AuthResponse> {
    try {
      const response = await fetch(`${API_BASE_URL}/auth/signup`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
        },
        body: JSON.stringify(data),
      });

      const result = await response.json();

      if (response.ok) {
        return {
          success: true,
          message: 'Usuario creado exitosamente',
          data: result,
        };
      } else {
        return {
          success: false,
          message: result.error || 'Error al crear usuario',
          error: result.error,
        };
      }
    } catch (error) {
      console.error('Sign up error:', error);
      return {
        success: false,
        message: 'Error de conexión. Verifica que el servidor esté ejecutándose.',
        error: 'Network error',
      };
    }
  }

  async signIn(email: string, password: string): Promise<AuthResponse> {
    try {
      const response = await fetch(`${API_BASE_URL}/auth/login`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({ email, password }),
      });

      const result = await response.json();

      if (response.ok) {
        // Guardar token en localStorage
        if (result.token) {
          localStorage.setItem('authToken', result.token);
          localStorage.setItem('user', JSON.stringify({
            id: result.id,
            email: result.email,
          }));
        }

        return {
          success: true,
          message: 'Inicio de sesión exitoso',
          data: result,
        };
      } else {
        let errorMessage = result.message || 'Error al iniciar sesión';
        
        if (response.status === 404) {
          errorMessage = 'El usuario no se encuentra registrado';
        } else if (response.status === 401) {
          errorMessage = 'Las credenciales son incorrectas';
        }

        return {
          success: false,
          message: errorMessage,
          error: result.error,
        };
      }
    } catch (error) {
      console.error('Sign in error:', error);
      return {
        success: false,
        message: 'Error de conexión. Verifica que el servidor esté ejecutándose.',
        error: 'Network error',
      };
    }
  }

  signOut(): void {
    localStorage.removeItem('authToken');
    localStorage.removeItem('user');
  }

  getToken(): string | null {
    return localStorage.getItem('authToken');
  }

  getCurrentUser(): any {
    const user = localStorage.getItem('user');
    return user ? JSON.parse(user) : null;
  }

  isAuthenticated(): boolean {
    return !!this.getToken();
  }
}

export const authService = new AuthService();