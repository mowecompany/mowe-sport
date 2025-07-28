interface City {
  city_id: string;
  name: string;
  region?: string;
  country: string;
}

class CitiesService {
  private baseUrl = '/api';
  private cache: City[] | null = null;
  private cacheExpiry: number = 0;
  private readonly CACHE_DURATION = 5 * 60 * 1000; // 5 minutes

  async getCities(): Promise<City[]> {
    // Check cache first
    if (this.cache && Date.now() < this.cacheExpiry) {
      return this.cache;
    }

    try {
      const response = await fetch(`${this.baseUrl}/cities`, {
        method: 'GET',
        headers: {
          'Authorization': `Bearer ${this.getAuthToken()}`
        }
      });

      if (!response.ok) {
        throw new Error('Error loading cities');
      }

      const cities = await response.json();
      
      // Update cache
      this.cache = cities;
      this.cacheExpiry = Date.now() + this.CACHE_DURATION;
      
      return cities;
    } catch (error) {
      console.error('Error in getCities:', error);
      
      // Return mock data if API fails
      return this.getMockCities();
    }
  }

  private getMockCities(): City[] {
    return [
      { city_id: "1", name: "Medellín", region: "Antioquia", country: "Colombia" },
      { city_id: "2", name: "Bogotá", region: "Cundinamarca", country: "Colombia" },
      { city_id: "3", name: "Cali", region: "Valle del Cauca", country: "Colombia" },
      { city_id: "4", name: "Barranquilla", region: "Atlántico", country: "Colombia" },
      { city_id: "5", name: "Cartagena", region: "Bolívar", country: "Colombia" },
      { city_id: "6", name: "Bucaramanga", region: "Santander", country: "Colombia" },
      { city_id: "7", name: "Pereira", region: "Risaralda", country: "Colombia" },
      { city_id: "8", name: "Manizales", region: "Caldas", country: "Colombia" }
    ];
  }

  clearCache(): void {
    this.cache = null;
    this.cacheExpiry = 0;
  }

  private getAuthToken(): string {
    return localStorage.getItem('auth_token') || '';
  }
}

export const citiesService = new CitiesService();
export type { City };