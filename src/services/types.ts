// Base API Response Types
export interface ApiResponse<T = any> {
  success: boolean;
  data?: T;
  error?: ApiError;
}

export interface ApiError {
  code: string;
  message: string;
  details?: any;
}

// User and Authentication Types
export interface UserProfile {
  user_id: string;
  email: string;
  first_name: string;
  last_name: string;
  phone?: string;
  identification?: string;
  photo_url?: string;
  primary_role: UserRole;
  is_active: boolean;
  account_status: AccountStatus;
  last_login_at?: string;
  failed_login_attempts: number;
  locked_until?: string;
  two_factor_enabled: boolean;
  created_at: string;
  updated_at: string;
}

export type UserRole = 
  | 'super_admin' 
  | 'city_admin' 
  | 'tournament_admin' 
  | 'owner' 
  | 'coach' 
  | 'referee' 
  | 'player' 
  | 'client';

export type AccountStatus = 
  | 'active' 
  | 'suspended' 
  | 'payment_pending' 
  | 'disabled';

// Admin Registration Types
export interface AdminRegistrationData {
  first_name: string;
  last_name: string;
  email: string;
  phone?: string;
  identification?: string;
  city_id: string;
  sport_id: string;
  account_status: AccountStatus;
  photo_url?: string;
}

export interface AdminRegistrationResponse {
  user_id: string;
  email: string;
  first_name: string;
  last_name: string;
  role_assignment_id: string;
  temporary_password: string;
  message: string;
}

export interface EmailValidationResponse {
  isUnique: boolean;
  message?: string;
}

// Cities and Sports Types
export interface City {
  city_id: string;
  name: string;
  region?: string;
  country: string;
  created_at?: string;
}

export interface Sport {
  sport_id: string;
  name: string;
  description?: string;
  rules?: any;
  created_at?: string;
}

// Admin Management Types
export interface AdminListResponse {
  admins: AdminSummary[];
  total: number;
  page: number;
  totalPages: number;
  limit: number;
}

export interface AdminSummary {
  user_id: string;
  email: string;
  first_name: string;
  last_name: string;
  phone?: string;
  photo_url?: string;
  account_status: AccountStatus;
  city_name?: string;
  sport_name?: string;
  last_login_at?: string;
  created_at: string;
}

export interface AdminStatusUpdateRequest {
  account_status: AccountStatus;
  reason?: string;
}

// Role Assignment Types
export interface UserRoleByCitySport {
  role_assignment_id: string;
  user_id: string;
  city_id?: string;
  sport_id?: string;
  role_name: UserRole;
  assigned_by_user_id?: string;
  is_active: boolean;
  created_at: string;
}

// Pagination Types
export interface PaginationParams {
  page?: number;
  limit?: number;
  search?: string;
  sort_by?: string;
  sort_order?: 'asc' | 'desc';
}

export interface PaginatedResponse<T> {
  data: T[];
  total: number;
  page: number;
  totalPages: number;
  limit: number;
  hasNext: boolean;
  hasPrev: boolean;
}

// Authentication Types
export interface LoginRequest {
  email: string;
  password: string;
  two_factor_code?: string;
}

export interface LoginResponse {
  user_id: string;
  email: string;
  first_name: string;
  last_name: string;
  primary_role: UserRole;
  token: string;
  refresh_token: string;
  expires_in: number;
}

export interface SignupRequest {
  first_name: string;
  last_name: string;
  email: string;
  password: string;
  phone?: string;
}

export interface SignupResponse {
  user_id: string;
  first_name: string;
  last_name: string;
  email: string;
  message: string;
}

// Error Types
export interface ValidationError {
  field: string;
  message: string;
  code: string;
}

export interface ValidationErrorResponse {
  code: 'VALIDATION_ERROR';
  message: string;
  details: ValidationError[];
}

// Cache Types
export interface CacheEntry<T> {
  data: T;
  expiry: number;
  key: string;
}

// Request Configuration Types
export interface RequestConfig {
  method: 'GET' | 'POST' | 'PUT' | 'DELETE' | 'PATCH';
  headers?: Record<string, string>;
  body?: any;
  retries?: number;
  timeout?: number;
}

// Request/Response Interceptor Types
export interface RequestInterceptor {
  onRequest?: (config: RequestInit) => RequestInit | Promise<RequestInit>;
  onError?: (error: Error) => Error | Promise<Error>;
}

export interface ResponseInterceptor {
  onResponse?: (response: Response) => Response | Promise<Response>;
  onError?: (error: Error) => Error | Promise<Error>;
}

// Service Configuration Types
export interface ServiceConfig {
  baseUrl?: string;
  timeout?: number;
  retries?: number;
  cacheEnabled?: boolean;
  cacheDuration?: number;
}

// Notification Types (for UI feedback)
export interface NotificationData {
  id: string;
  type: 'success' | 'error' | 'warning' | 'info';
  title: string;
  message?: string;
  duration?: number;
}