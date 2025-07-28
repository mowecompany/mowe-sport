import { apiInterceptors } from './apiInterceptors';

interface ApiResponse<T = any> {
  success: boolean;
  data?: T;
  error?: {
    code: string;
    message: string;
    details?: any;
  };
}

interface RequestConfig {
  method: 'GET' | 'POST' | 'PUT' | 'DELETE' | 'PATCH';
  headers?: Record<string, string>;
  body?: any;
  retries?: number;
  timeout?: number;
}

class BaseApiService {
  private baseUrl = '/api';
  private defaultTimeout = 10000; // 10 seconds
  private defaultRetries = 3;

  constructor(baseUrl?: string) {
    if (baseUrl) {
      this.baseUrl = baseUrl;
    }
  }

  async request<T = any>(
    endpoint: string, 
    config: RequestConfig
  ): Promise<T> {
    const { method, headers = {}, body, retries = this.defaultRetries, timeout = this.defaultTimeout } = config;
    
    // Add default headers
    const defaultHeaders: Record<string, string> = {
      'Content-Type': 'application/json',
    };

    // Add auth token if available
    const token = this.getAuthToken();
    if (token) {
      defaultHeaders['Authorization'] = `Bearer ${token}`;
    }

    let requestConfig: RequestInit = {
      method,
      headers: { ...defaultHeaders, ...headers },
      body: body ? JSON.stringify(body) : undefined,
    };

    // Process request through interceptors
    try {
      requestConfig = await apiInterceptors.processRequest(requestConfig);
    } catch (error) {
      console.error('Request interceptor error:', error);
      // Continue with original config if interceptor fails
    }
    
    let lastError: Error;
    
    for (let attempt = 0; attempt <= retries; attempt++) {
      try {
        const controller = new AbortController();
        const timeoutId = setTimeout(() => controller.abort(), timeout);

        let response = await fetch(`${this.baseUrl}${endpoint}`, {
          ...requestConfig,
          signal: controller.signal,
        });

        clearTimeout(timeoutId);

        // Process response through interceptors
        try {
          response = await apiInterceptors.processResponse(response);
        } catch (error) {
          console.error('Response interceptor error:', error);
          // Continue with original response if interceptor fails
        }

        // Handle authentication errors
        if (response.status === 401) {
          this.handleAuthError();
          throw new Error('Authentication required');
        }

        // Handle other HTTP errors
        if (!response.ok) {
          const errorData = await this.parseErrorResponse(response);
          throw new Error(errorData.message || `HTTP ${response.status}: ${response.statusText}`);
        }

        // Parse successful response
        const data = await response.json();
        return data;

      } catch (error) {
        lastError = error as Error;
        
        // Don't retry on authentication errors or client errors (4xx)
        if (error instanceof Error) {
          if (error.message.includes('Authentication required') || 
              error.message.includes('HTTP 4')) {
            throw error;
          }
        }

        // Wait before retrying (exponential backoff)
        if (attempt < retries) {
          await this.delay(Math.pow(2, attempt) * 1000);
        }
      }
    }

    throw lastError!;
  }

  async get<T = any>(endpoint: string, headers?: Record<string, string>): Promise<T> {
    return this.request<T>(endpoint, { method: 'GET', headers });
  }

  async post<T = any>(endpoint: string, body?: any, headers?: Record<string, string>): Promise<T> {
    return this.request<T>(endpoint, { method: 'POST', body, headers });
  }

  async put<T = any>(endpoint: string, body?: any, headers?: Record<string, string>): Promise<T> {
    return this.request<T>(endpoint, { method: 'PUT', body, headers });
  }

  async delete<T = any>(endpoint: string, headers?: Record<string, string>): Promise<T> {
    return this.request<T>(endpoint, { method: 'DELETE', headers });
  }

  async patch<T = any>(endpoint: string, body?: any, headers?: Record<string, string>): Promise<T> {
    return this.request<T>(endpoint, { method: 'PATCH', body, headers });
  }

  private async parseErrorResponse(response: Response): Promise<{ message: string; code?: string; details?: any }> {
    try {
      const errorData = await response.json();
      return {
        message: errorData.message || errorData.error || 'Unknown error',
        code: errorData.code,
        details: errorData.details
      };
    } catch {
      return {
        message: `HTTP ${response.status}: ${response.statusText}`,
        code: response.status.toString()
      };
    }
  }

  private handleAuthError(): void {
    // Clear stored auth data
    localStorage.removeItem('auth_token');
    localStorage.removeItem('authToken');
    localStorage.removeItem('user');
    
    // Redirect to login page or emit event
    if (typeof window !== 'undefined') {
      window.dispatchEvent(new CustomEvent('auth:logout'));
    }
  }

  private getAuthToken(): string | null {
    // Try both token keys for compatibility
    return localStorage.getItem('auth_token') || localStorage.getItem('authToken');
  }

  private delay(ms: number): Promise<void> {
    return new Promise(resolve => setTimeout(resolve, ms));
  }
}

export { BaseApiService };
export type { ApiResponse, RequestConfig };