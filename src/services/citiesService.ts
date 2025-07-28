import { BaseApiService } from './baseApiService';
import type { City, CacheEntry } from './types';

class CitiesService extends BaseApiService {
  private cache: CacheEntry<City[]> | null = null;
  private readonly CACHE_DURATION = 10 * 60 * 1000; // 10 minutes
  private readonly CACHE_KEY = 'cities_cache';

  constructor() {
    super();
    this.loadCacheFromStorage();
  }

  /**
   * Get all cities with intelligent caching
   */
  async getCities(forceRefresh = false): Promise<City[]> {
    // Check cache first (unless force refresh)
    if (!forceRefresh && this.isCacheValid()) {
      console.debug('Returning cities from cache');
      return this.cache!.data;
    }

    try {
      console.debug('Fetching cities from API');
      const cities = await this.get<City[]>('/cities');
      
      // Validate response data
      if (!Array.isArray(cities)) {
        throw new Error('Invalid response format from cities API');
      }

      // Update cache
      this.updateCache(cities);
      
      console.info(`Loaded ${cities.length} cities from API`);
      return cities;
    } catch (error) {
      console.error('Error in getCities:', error);
      
      // Try to return stale cache data if available
      if (this.cache?.data) {
        console.warn('API failed, returning stale cache data');
        return this.cache.data;
      }
      
      // Fallback to mock data
      console.warn('API failed and no cache available, returning mock data');
      return this.getMockCities();
    }
  }

  /**
   * Get city by ID
   */
  async getCityById(cityId: string): Promise<City | null> {
    try {
      const cities = await this.getCities();
      return cities.find(city => city.city_id === cityId) || null;
    } catch (error) {
      console.error('Error in getCityById:', error);
      return null;
    }
  }

  /**
   * Search cities by name or region
   */
  async searchCities(query: string): Promise<City[]> {
    try {
      const cities = await this.getCities();
      const lowercaseQuery = query.toLowerCase();
      
      return cities.filter(city => 
        city.name.toLowerCase().includes(lowercaseQuery) ||
        city.region?.toLowerCase().includes(lowercaseQuery) ||
        city.country.toLowerCase().includes(lowercaseQuery)
      );
    } catch (error) {
      console.error('Error in searchCities:', error);
      return [];
    }
  }

  /**
   * Get cities by country
   */
  async getCitiesByCountry(country: string): Promise<City[]> {
    try {
      const cities = await this.getCities();
      return cities.filter(city => 
        city.country.toLowerCase() === country.toLowerCase()
      );
    } catch (error) {
      console.error('Error in getCitiesByCountry:', error);
      return [];
    }
  }

  /**
   * Clear cache and force refresh
   */
  clearCache(): void {
    this.cache = null;
    this.removeCacheFromStorage();
    console.debug('Cities cache cleared');
  }

  /**
   * Get cache status information
   */
  getCacheInfo(): { isValid: boolean; expiry: Date | null; size: number } {
    return {
      isValid: this.isCacheValid(),
      expiry: this.cache ? new Date(this.cache.expiry) : null,
      size: this.cache?.data.length || 0
    };
  }

  /**
   * Check if cache is valid
   */
  private isCacheValid(): boolean {
    return this.cache !== null && Date.now() < this.cache.expiry;
  }

  /**
   * Update cache with new data
   */
  private updateCache(cities: City[]): void {
    this.cache = {
      data: cities,
      expiry: Date.now() + this.CACHE_DURATION,
      key: this.CACHE_KEY
    };
    
    this.saveCacheToStorage();
  }

  /**
   * Save cache to localStorage
   */
  private saveCacheToStorage(): void {
    try {
      if (this.cache) {
        localStorage.setItem(this.CACHE_KEY, JSON.stringify(this.cache));
      }
    } catch (error) {
      console.warn('Failed to save cities cache to localStorage:', error);
    }
  }

  /**
   * Load cache from localStorage
   */
  private loadCacheFromStorage(): void {
    try {
      const cached = localStorage.getItem(this.CACHE_KEY);
      if (cached) {
        const parsedCache = JSON.parse(cached) as CacheEntry<City[]>;
        
        // Validate cache structure and expiry
        if (parsedCache.data && parsedCache.expiry && Date.now() < parsedCache.expiry) {
          this.cache = parsedCache;
          console.debug('Cities cache loaded from localStorage');
        } else {
          this.removeCacheFromStorage();
        }
      }
    } catch (error) {
      console.warn('Failed to load cities cache from localStorage:', error);
      this.removeCacheFromStorage();
    }
  }

  /**
   * Remove cache from localStorage
   */
  private removeCacheFromStorage(): void {
    try {
      localStorage.removeItem(this.CACHE_KEY);
    } catch (error) {
      console.warn('Failed to remove cities cache from localStorage:', error);
    }
  }

  /**
   * Get mock cities data for fallback
   */
  private getMockCities(): City[] {
    return [
      { city_id: "1", name: "Medellín", region: "Antioquia", country: "Colombia" },
      { city_id: "2", name: "Bogotá", region: "Cundinamarca", country: "Colombia" },
      { city_id: "3", name: "Cali", region: "Valle del Cauca", country: "Colombia" },
      { city_id: "4", name: "Barranquilla", region: "Atlántico", country: "Colombia" },
      { city_id: "5", name: "Cartagena", region: "Bolívar", country: "Colombia" },
      { city_id: "6", name: "Bucaramanga", region: "Santander", country: "Colombia" },
      { city_id: "7", name: "Pereira", region: "Risaralda", country: "Colombia" },
      { city_id: "8", name: "Manizales", region: "Caldas", country: "Colombia" },
      { city_id: "9", name: "Ibagué", region: "Tolima", country: "Colombia" },
      { city_id: "10", name: "Pasto", region: "Nariño", country: "Colombia" },
      { city_id: "11", name: "Santa Marta", region: "Magdalena", country: "Colombia" },
      { city_id: "12", name: "Villavicencio", region: "Meta", country: "Colombia" }
    ];
  }
}

export const citiesService = new CitiesService();
export type { City };