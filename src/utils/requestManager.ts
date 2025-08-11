// Singleton para manejar peticiones y evitar duplicados
class RequestManager {
  private static instance: RequestManager;
  private pendingRequests: Map<string, Promise<any>> = new Map();
  private cache: Map<string, { data: any; timestamp: number; ttl: number }> = new Map();

  private constructor() {}

  static getInstance(): RequestManager {
    if (!RequestManager.instance) {
      RequestManager.instance = new RequestManager();
    }
    return RequestManager.instance;
  }

  // Genera una clave única para la petición
  private generateKey(url: string, params?: any): string {
    const paramString = params ? JSON.stringify(params) : '';
    return `${url}${paramString}`;
  }

  // Verifica si el caché es válido
  private isCacheValid(key: string): boolean {
    const cached = this.cache.get(key);
    if (!cached) return false;
    return Date.now() - cached.timestamp < cached.ttl;
  }

  // Obtiene datos del caché
  private getCachedData(key: string): any {
    const cached = this.cache.get(key);
    return cached ? cached.data : null;
  }

  // Guarda datos en caché
  private setCachedData(key: string, data: any, ttl: number = 5 * 60 * 1000): void {
    this.cache.set(key, {
      data,
      timestamp: Date.now(),
      ttl
    });
  }

  // Método principal para hacer peticiones
  async request<T>(
    url: string, 
    requestFn: () => Promise<T>, 
    params?: any,
    options: { ttl?: number; forceRefresh?: boolean } = {}
  ): Promise<T> {
    const { ttl = 5 * 60 * 1000, forceRefresh = false } = options;
    const key = this.generateKey(url, params);

    // Verificar caché primero
    if (!forceRefresh && this.isCacheValid(key)) {
      console.log(`[RequestManager] Using cached data for: ${url}`);
      return this.getCachedData(key);
    }

    // Verificar si ya hay una petición pendiente
    if (this.pendingRequests.has(key)) {
      console.log(`[RequestManager] Request already pending for: ${url}`);
      return this.pendingRequests.get(key)!;
    }

    // Crear nueva petición
    console.log(`[RequestManager] Making new request for: ${url}`);
    const requestPromise = requestFn()
      .then((data) => {
        // Guardar en caché
        this.setCachedData(key, data, ttl);
        // Remover de pendientes
        this.pendingRequests.delete(key);
        return data;
      })
      .catch((error) => {
        // Remover de pendientes en caso de error
        this.pendingRequests.delete(key);
        throw error;
      });

    // Guardar como pendiente
    this.pendingRequests.set(key, requestPromise);
    
    return requestPromise;
  }

  // Limpiar caché
  clearCache(pattern?: string): void {
    if (pattern) {
      for (const key of this.cache.keys()) {
        if (key.includes(pattern)) {
          this.cache.delete(key);
        }
      }
    } else {
      this.cache.clear();
    }
  }

  // Limpiar peticiones pendientes
  clearPendingRequests(): void {
    this.pendingRequests.clear();
  }

  // Obtener estadísticas
  getStats(): { cacheSize: number; pendingRequests: number } {
    return {
      cacheSize: this.cache.size,
      pendingRequests: this.pendingRequests.size
    };
  }
}

export const requestManager = RequestManager.getInstance();