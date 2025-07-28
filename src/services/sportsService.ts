import { BaseApiService } from './baseApiService';
import type { Sport, CacheEntry } from './types';

class SportsService extends BaseApiService {
  private cache: CacheEntry<Sport[]> | null = null;
  private readonly CACHE_DURATION = 15 * 60 * 1000; // 15 minutes (sports change less frequently)
  private readonly CACHE_KEY = 'sports_cache';

  constructor() {
    super();
    this.loadCacheFromStorage();
  }

  /**
   * Get all sports with intelligent caching
   */
  async getSports(forceRefresh = false): Promise<Sport[]> {
    // Check cache first (unless force refresh)
    if (!forceRefresh && this.isCacheValid()) {
      console.debug('Returning sports from cache');
      return this.cache!.data;
    }

    try {
      console.debug('Fetching sports from API');
      const sports = await this.get<Sport[]>('/sports');
      
      // Validate response data
      if (!Array.isArray(sports)) {
        throw new Error('Invalid response format from sports API');
      }

      // Update cache
      this.updateCache(sports);
      
      console.info(`Loaded ${sports.length} sports from API`);
      return sports;
    } catch (error) {
      console.error('Error in getSports:', error);
      
      // Try to return stale cache data if available
      if (this.cache?.data) {
        console.warn('API failed, returning stale cache data');
        return this.cache.data;
      }
      
      // Fallback to mock data
      console.warn('API failed and no cache available, returning mock data');
      return this.getMockSports();
    }
  }

  /**
   * Get sport by ID
   */
  async getSportById(sportId: string): Promise<Sport | null> {
    try {
      const sports = await this.getSports();
      return sports.find(sport => sport.sport_id === sportId) || null;
    } catch (error) {
      console.error('Error in getSportById:', error);
      return null;
    }
  }

  /**
   * Search sports by name or description
   */
  async searchSports(query: string): Promise<Sport[]> {
    try {
      const sports = await this.getSports();
      const lowercaseQuery = query.toLowerCase();
      
      return sports.filter(sport => 
        sport.name.toLowerCase().includes(lowercaseQuery) ||
        sport.description?.toLowerCase().includes(lowercaseQuery)
      );
    } catch (error) {
      console.error('Error in searchSports:', error);
      return [];
    }
  }

  /**
   * Get popular sports (based on predefined list)
   */
  async getPopularSports(): Promise<Sport[]> {
    try {
      const sports = await this.getSports();
      const popularSportNames = ['Fútbol', 'Baloncesto', 'Voleibol', 'Tenis', 'Fútbol Sala'];
      
      return sports.filter(sport => 
        popularSportNames.some(name => 
          sport.name.toLowerCase().includes(name.toLowerCase())
        )
      );
    } catch (error) {
      console.error('Error in getPopularSports:', error);
      return [];
    }
  }

  /**
   * Clear cache and force refresh
   */
  clearCache(): void {
    this.cache = null;
    this.removeCacheFromStorage();
    console.debug('Sports cache cleared');
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
  private updateCache(sports: Sport[]): void {
    this.cache = {
      data: sports,
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
      console.warn('Failed to save sports cache to localStorage:', error);
    }
  }

  /**
   * Load cache from localStorage
   */
  private loadCacheFromStorage(): void {
    try {
      const cached = localStorage.getItem(this.CACHE_KEY);
      if (cached) {
        const parsedCache = JSON.parse(cached) as CacheEntry<Sport[]>;
        
        // Validate cache structure and expiry
        if (parsedCache.data && parsedCache.expiry && Date.now() < parsedCache.expiry) {
          this.cache = parsedCache;
          console.debug('Sports cache loaded from localStorage');
        } else {
          this.removeCacheFromStorage();
        }
      }
    } catch (error) {
      console.warn('Failed to load sports cache from localStorage:', error);
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
      console.warn('Failed to remove sports cache from localStorage:', error);
    }
  }

  /**
   * Get mock sports data for fallback
   */
  private getMockSports(): Sport[] {
    return [
      { sport_id: "1", name: "Fútbol", description: "Fútbol asociación - El deporte más popular del mundo" },
      { sport_id: "2", name: "Baloncesto", description: "Básquetbol - Deporte de equipo jugado en cancha cubierta" },
      { sport_id: "3", name: "Voleibol", description: "Voleibol - Deporte de equipo con red divisoria" },
      { sport_id: "4", name: "Tenis", description: "Tenis de campo - Deporte de raqueta individual o dobles" },
      { sport_id: "5", name: "Natación", description: "Natación deportiva - Deporte acuático individual" },
      { sport_id: "6", name: "Atletismo", description: "Atletismo y campo - Conjunto de disciplinas deportivas" },
      { sport_id: "7", name: "Ciclismo", description: "Ciclismo deportivo - Deporte sobre bicicleta" },
      { sport_id: "8", name: "Fútbol Sala", description: "Fútbol de salón - Variante del fútbol en espacios reducidos" },
      { sport_id: "9", name: "Béisbol", description: "Béisbol - Deporte de equipo con bate y pelota" },
      { sport_id: "10", name: "Softball", description: "Softball - Variante del béisbol con pelota más grande" },
      { sport_id: "11", name: "Ping Pong", description: "Tenis de mesa - Deporte de raqueta sobre mesa" },
      { sport_id: "12", name: "Bádminton", description: "Bádminton - Deporte de raqueta con volante" }
    ];
  }
}

export const sportsService = new SportsService();
export type { Sport };