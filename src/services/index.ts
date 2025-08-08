// Export all services
export { adminService } from './adminService';
export { citiesService } from './citiesService';
export { sportsService } from './sportsService';
export { authService } from './auth';
export { userRegistrationService } from './userRegistrationService';
export { BaseApiService } from './baseApiService';

// Export interceptors and initialization
export { apiInterceptors } from './apiInterceptors';
export { initializeServices, cleanupServices } from './init';

// Export all types
export type {
  // Admin types
  AdminRegistrationData,
  AdminRegistrationResponse,
  EmailValidationResponse,
  AdminListResponse,
  AdminSummary,
  AdminStatusUpdateRequest,
  
  // Location types
  City,
  Sport,
  
  // Auth types
  UserProfile,
  UserRole,
  AccountStatus,
  LoginRequest,
  LoginResponse,
  SignupRequest,
  SignupResponse,
  
  // API types
  ApiResponse,
  ApiError,
  PaginationParams,
  PaginatedResponse,
  
  // Cache types
  CacheEntry,
  
  // Service config types
  ServiceConfig,
  RequestConfig,
  
  // Validation types
  ValidationError,
  ValidationErrorResponse,
  
  // Notification types
  NotificationData
} from './types';

// Export user registration types
export type {
  BaseUserRegistrationData,
  CityAdminRegistrationData,
  OwnerRegistrationData,
  RefereeRegistrationData,
  PlayerRegistrationData,
  CoachRegistrationData,
  UserRegistrationResponse,
  UserListRequest,
  UserSummary,
  UserListResponse
} from './userRegistrationService';

// Legacy exports for backward compatibility
export type { SignUpData, SignInData, AuthResponse } from './auth';