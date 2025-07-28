import { initializeDefaultInterceptors, setupGlobalErrorHandlers } from './apiInterceptors';

/**
 * Initialize all API services and interceptors
 * This should be called once when the application starts
 */
export function initializeServices(): void {
  try {
    // Initialize API interceptors
    initializeDefaultInterceptors();
    
    // Setup global error handlers
    setupGlobalErrorHandlers();
    
    console.info('API services initialized successfully');
  } catch (error) {
    console.error('Failed to initialize API services:', error);
  }
}

/**
 * Cleanup services (useful for testing or app shutdown)
 */
export function cleanupServices(): void {
  try {
    // Clear all caches
    localStorage.removeItem('cities_cache');
    localStorage.removeItem('sports_cache');
    
    console.info('API services cleaned up successfully');
  } catch (error) {
    console.error('Failed to cleanup API services:', error);
  }
}