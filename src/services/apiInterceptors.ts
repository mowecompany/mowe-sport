import type { RequestInterceptor, ResponseInterceptor } from './types';

/**
 * Global API interceptors for handling common concerns
 */
class ApiInterceptors {
  private requestInterceptors: RequestInterceptor[] = [];
  private responseInterceptors: ResponseInterceptor[] = [];

  /**
   * Add request interceptor
   */
  addRequestInterceptor(interceptor: RequestInterceptor): void {
    this.requestInterceptors.push(interceptor);
  }

  /**
   * Add response interceptor
   */
  addResponseInterceptor(interceptor: ResponseInterceptor): void {
    this.responseInterceptors.push(interceptor);
  }

  /**
   * Process request through all interceptors
   */
  async processRequest(config: RequestInit): Promise<RequestInit> {
    let processedConfig = config;

    for (const interceptor of this.requestInterceptors) {
      if (interceptor.onRequest) {
        try {
          processedConfig = await interceptor.onRequest(processedConfig);
        } catch (error) {
          if (interceptor.onError) {
            await interceptor.onError(error as Error);
          }
          throw error;
        }
      }
    }

    return processedConfig;
  }

  /**
   * Process response through all interceptors
   */
  async processResponse(response: Response): Promise<Response> {
    let processedResponse = response;

    for (const interceptor of this.responseInterceptors) {
      if (interceptor.onResponse) {
        try {
          processedResponse = await interceptor.onResponse(processedResponse);
        } catch (error) {
          if (interceptor.onError) {
            await interceptor.onError(error as Error);
          }
          throw error;
        }
      }
    }

    return processedResponse;
  }

  /**
   * Clear all interceptors
   */
  clear(): void {
    this.requestInterceptors = [];
    this.responseInterceptors = [];
  }
}

// Global instance
export const apiInterceptors = new ApiInterceptors();

// Default interceptors

/**
 * Authentication interceptor - adds auth headers
 */
export const authInterceptor: RequestInterceptor = {
  onRequest: async (config: RequestInit) => {
    const token = localStorage.getItem('auth_token') || localStorage.getItem('authToken');
    
    if (token && config.headers) {
      (config.headers as Record<string, string>)['Authorization'] = `Bearer ${token}`;
    }
    
    return config;
  },
  onError: async (error: Error) => {
    console.error('Auth interceptor error:', error);
    return error;
  }
};

/**
 * Logging interceptor - logs all requests
 */
export const loggingInterceptor: RequestInterceptor = {
  onRequest: async (config: RequestInit) => {
    console.debug('API Request:', {
      method: config.method,
      headers: config.headers,
      timestamp: new Date().toISOString()
    });
    return config;
  }
};

/**
 * Error handling interceptor - handles common errors
 */
export const errorHandlingInterceptor: ResponseInterceptor = {
  onResponse: async (response: Response) => {
    // Log successful responses
    if (response.ok) {
      console.debug('API Response:', {
        status: response.status,
        url: response.url,
        timestamp: new Date().toISOString()
      });
    }
    
    return response;
  },
  onError: async (error: Error) => {
    // Handle common error scenarios
    if (error.message.includes('401')) {
      // Emit auth error event
      if (typeof window !== 'undefined') {
        window.dispatchEvent(new CustomEvent('auth:unauthorized'));
      }
    } else if (error.message.includes('403')) {
      // Emit permission error event
      if (typeof window !== 'undefined') {
        window.dispatchEvent(new CustomEvent('auth:forbidden'));
      }
    } else if (error.message.includes('Network')) {
      // Emit network error event
      if (typeof window !== 'undefined') {
        window.dispatchEvent(new CustomEvent('api:network-error'));
      }
    }
    
    console.error('API Error:', {
      message: error.message,
      timestamp: new Date().toISOString()
    });
    
    return error;
  }
};

/**
 * Rate limiting interceptor - handles rate limit responses
 */
export const rateLimitInterceptor: ResponseInterceptor = {
  onResponse: async (response: Response) => {
    if (response.status === 429) {
      const retryAfter = response.headers.get('Retry-After');
      const message = `Rate limit exceeded. ${retryAfter ? `Retry after ${retryAfter} seconds.` : 'Please try again later.'}`;
      
      // Emit rate limit event
      if (typeof window !== 'undefined') {
        window.dispatchEvent(new CustomEvent('api:rate-limit', {
          detail: { retryAfter: retryAfter ? parseInt(retryAfter) : null }
        }));
      }
      
      throw new Error(message);
    }
    
    return response;
  }
};

/**
 * Initialize default interceptors
 */
export function initializeDefaultInterceptors(): void {
  apiInterceptors.addRequestInterceptor(authInterceptor);
  apiInterceptors.addRequestInterceptor(loggingInterceptor);
  apiInterceptors.addResponseInterceptor(errorHandlingInterceptor);
  apiInterceptors.addResponseInterceptor(rateLimitInterceptor);
  
  console.info('Default API interceptors initialized');
}

/**
 * Setup global error event listeners
 */
export function setupGlobalErrorHandlers(): void {
  if (typeof window === 'undefined') return;

  // Handle auth errors
  window.addEventListener('auth:unauthorized', () => {
    console.warn('Unauthorized access detected');
    // Could redirect to login or show notification
  });

  window.addEventListener('auth:forbidden', () => {
    console.warn('Forbidden access detected');
    // Could show permission denied message
  });

  // Handle network errors
  window.addEventListener('api:network-error', () => {
    console.warn('Network error detected');
    // Could show offline notification
  });

  // Handle rate limiting
  window.addEventListener('api:rate-limit', ((event: CustomEvent) => {
    const { retryAfter } = event.detail;
    console.warn('Rate limit hit', { retryAfter });
    // Could show rate limit notification
  }) as EventListener);

  console.info('Global error handlers setup complete');
}