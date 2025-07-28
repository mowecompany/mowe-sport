interface Sport {
  sport_id: string;
  name: string;
  description?: string;
}

class SportsService {
  private baseUrl = '/api';
  private cache: Sport[] | null = null;
  private cacheExpiry: number = 0;
  private readonly CACHE_DURATION = 5 * 60 * 1000; // 5 minutes

  async getSports(): Promise<Sport[]> {
    // Check cache first
    if (this.cache && Date.now() < this.cacheExpiry) {
      return this.cache;
    }

    try {
      const response = await fetch(`${this.baseUrl}/sports`, {
        method: 'GET',
        headers: {
          'Authorization': `Bearer ${this.getAuthToken()}`
        }
      });

      if (!response.ok) {
        throw new Error('Error loading sports');
      }

      const sports = await response.json();
      
      // Update cache
      this.cache = sports;
      this.cacheExpiry = Date.now() + this.CACHE_DURATION;
      
      return sports;
    } catch (error) {
      console.error('Error in getSports:', error);
      
      // Return mock data if API fails
      return this.getMockSports();
    }
  }

  private getMockSports(): Sport[] {
    return [
      { sport_id: "1", name: "Fútbol", description: "Fútbol asociación" },
      { sport_id: "2", name: "Baloncesto", description: "Básquetbol" },
      { sport_id: "3", name: "Voleibol", description: "Voleibol" },
      { sport_id: "4", name: "Tenis", description: "Tenis de campo" },
      { sport_id: "5", name: "Natación", description: "Natación deportiva" },
      { sport_id: "6", name: "Atletismo", description: "Atletismo y campo" },
      { sport_id: "7", name: "Ciclismo", description: "Ciclismo deportivo" },
      { sport_id: "8", name: "Fútbol Sala", description: "Fútbol de salón" }
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

export const sportsService = new SportsService();
export type { Sport };