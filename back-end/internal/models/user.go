package models

import (
	"time"

	"github.com/google/uuid"
)

type UserProfile struct {
	UserID              uuid.UUID  `json:"user_id" db:"user_id"`
	Email               string     `json:"email" db:"email"`
	PasswordHash        string     `json:"-" db:"password_hash"` // Never expose in JSON
	FirstName           string     `json:"first_name" db:"first_name"`
	LastName            string     `json:"last_name" db:"last_name"`
	Phone               *string    `json:"phone" db:"phone"`
	Identification      *string    `json:"identification" db:"identification"`
	PhotoURL            *string    `json:"photo_url" db:"photo_url"`
	PrimaryRole         string     `json:"primary_role" db:"primary_role"`
	IsActive            bool       `json:"is_active" db:"is_active"`
	AccountStatus       string     `json:"account_status" db:"account_status"`
	LastLoginAt         *time.Time `json:"last_login_at" db:"last_login_at"`
	FailedLoginAttempts int        `json:"failed_login_attempts" db:"failed_login_attempts"`
	LockedUntil         *time.Time `json:"locked_until" db:"locked_until"`
	TokenRecovery       *string    `json:"-" db:"token_recovery"`        // Never expose in JSON
	TokenExpirationDate *time.Time `json:"-" db:"token_expiration_date"` // Never expose in JSON
	TwoFactorSecret     *string    `json:"-" db:"two_factor_secret"`     // Never expose in JSON
	TwoFactorEnabled    bool       `json:"two_factor_enabled" db:"two_factor_enabled"`
	CreatedAt           time.Time  `json:"created_at" db:"created_at"`
	UpdatedAt           time.Time  `json:"updated_at" db:"updated_at"`
}

// UserRoleByCitySport represents granular role assignments
type UserRoleByCitySport struct {
	RoleAssignmentID uuid.UUID  `json:"role_assignment_id" db:"role_assignment_id"`
	UserID           uuid.UUID  `json:"user_id" db:"user_id"`
	CityID           *uuid.UUID `json:"city_id" db:"city_id"`
	SportID          *uuid.UUID `json:"sport_id" db:"sport_id"`
	RoleName         string     `json:"role_name" db:"role_name"`
	AssignedByUserID *uuid.UUID `json:"assigned_by_user_id" db:"assigned_by_user_id"`
	IsActive         bool       `json:"is_active" db:"is_active"`
	CreatedAt        time.Time  `json:"created_at" db:"created_at"`
}

// UserViewPermission represents view-level permissions
type UserViewPermission struct {
	PermissionID       uuid.UUID  `json:"permission_id" db:"permission_id"`
	UserID             *uuid.UUID `json:"user_id" db:"user_id"`
	RoleName           *string    `json:"role_name" db:"role_name"`
	ViewName           string     `json:"view_name" db:"view_name"`
	IsAllowed          bool       `json:"is_allowed" db:"is_allowed"`
	ConfiguredByUserID uuid.UUID  `json:"configured_by_user_id" db:"configured_by_user_id"`
	CreatedAt          time.Time  `json:"created_at" db:"created_at"`
	UpdatedAt          time.Time  `json:"updated_at" db:"updated_at"`
}

// Legacy User struct for backward compatibility (can be removed later)
type User struct {
	ID           int       `json:"id"`
	Name         string    `json:"name"`
	LastName     string    `json:"last_name,omitempty"`
	Email        string    `json:"email"`
	Password     string    `json:"password,omitempty"`
	PasswordHash string    `json:"password_hash,omitempty"`
	Phone        string    `json:"phone,omitempty"`
	Document     string    `json:"document,omitempty"`
	DocumentType string    `json:"document_type,omitempty"`
	Role         string    `json:"role,omitempty"`
	Status       bool      `json:"status"`
	CreatedAt    time.Time `json:"created_at"`
	UpdatedAt    time.Time `json:"updated_at"`
}

// Authentication request/response structs
type SignupRequest struct {
	FirstName string `json:"first_name" validate:"required"`
	LastName  string `json:"last_name" validate:"required"`
	Email     string `json:"email" validate:"required,email"`
	Password  string `json:"password" validate:"required,min=8"`
	Phone     string `json:"phone,omitempty"`
}

type SignupResponse struct {
	UserID    uuid.UUID `json:"user_id"`
	FirstName string    `json:"first_name"`
	LastName  string    `json:"last_name"`
	Email     string    `json:"email"`
	Message   string    `json:"message"`
}

type LoginRequest struct {
	Email         string `json:"email" validate:"required,email"`
	Password      string `json:"password" validate:"required"`
	TwoFactorCode string `json:"two_factor_code,omitempty"`
}

type LoginResponse struct {
	UserID       uuid.UUID `json:"user_id"`
	Email        string    `json:"email"`
	FirstName    string    `json:"first_name"`
	LastName     string    `json:"last_name"`
	PrimaryRole  string    `json:"primary_role"`
	Token        string    `json:"token"`
	RefreshToken string    `json:"refresh_token"`
	ExpiresIn    int       `json:"expires_in"`
}

// Password recovery structs
type PasswordRecoveryRequest struct {
	Email string `json:"email" validate:"required,email"`
}

type PasswordResetRequest struct {
	Token       string `json:"token" validate:"required"`
	NewPassword string `json:"new_password" validate:"required,min=8"`
}

// 2FA structs
type Setup2FAResponse struct {
	Secret string `json:"secret"`
	QRCode string `json:"qr_code"`
}

type Verify2FARequest struct {
	Code string `json:"code" validate:"required,len=6"`
}

// Admin registration structs
type AdminRegistrationRequest struct {
	FirstName      string `json:"first_name" validate:"required,min=2,max=100"`
	LastName       string `json:"last_name" validate:"required,min=2,max=100"`
	Email          string `json:"email" validate:"required,email"`
	Phone          string `json:"phone,omitempty" validate:"omitempty,min=10,max=20"`
	Identification string `json:"identification,omitempty" validate:"omitempty,min=5,max=50"`
	CityID         string `json:"city_id" validate:"required,uuid"`
	SportID        string `json:"sport_id" validate:"required,uuid"`
	AccountStatus  string `json:"account_status,omitempty" validate:"omitempty,oneof=active suspended payment_pending disabled"`
	PhotoURL       string `json:"photo_url,omitempty" validate:"omitempty,url"`
}

type AdminRegistrationResponse struct {
	UserID            uuid.UUID `json:"user_id"`
	FirstName         string    `json:"first_name"`
	LastName          string    `json:"last_name"`
	Email             string    `json:"email"`
	Phone             *string   `json:"phone,omitempty"`
	Identification    *string   `json:"identification,omitempty"`
	CityID            uuid.UUID `json:"city_id"`
	SportID           uuid.UUID `json:"sport_id"`
	AccountStatus     string    `json:"account_status"`
	PhotoURL          *string   `json:"photo_url,omitempty"`
	RoleAssignmentID  uuid.UUID `json:"role_assignment_id"`
	TemporaryPassword string    `json:"temporary_password,omitempty"` // Only for development/testing
	Message           string    `json:"message"`
}

// Email validation response
type EmailValidationResponse struct {
	IsValid  bool   `json:"is_valid"`
	IsUnique bool   `json:"is_unique"`
	Message  string `json:"message,omitempty"`
}

// Admin list structs
type AdminListRequest struct {
	Page      int    `query:"page" validate:"omitempty,min=1"`
	Limit     int    `query:"limit" validate:"omitempty,min=1,max=100"`
	Search    string `query:"search" validate:"omitempty,max=100"`
	CityID    string `query:"city_id" validate:"omitempty,uuid"`
	SportID   string `query:"sport_id" validate:"omitempty,uuid"`
	Status    string `query:"status" validate:"omitempty,oneof=active suspended payment_pending disabled"`
	SortBy    string `query:"sort_by" validate:"omitempty,oneof=first_name last_name email created_at last_login_at"`
	SortOrder string `query:"sort_order" validate:"omitempty,oneof=asc desc"`
}

type AdminSummary struct {
	UserID        uuid.UUID  `json:"user_id"`
	Email         string     `json:"email"`
	FirstName     string     `json:"first_name"`
	LastName      string     `json:"last_name"`
	Phone         *string    `json:"phone"`
	PhotoURL      *string    `json:"photo_url"`
	AccountStatus string     `json:"account_status"`
	IsActive      bool       `json:"is_active"`
	CityName      *string    `json:"city_name"`
	SportName     *string    `json:"sport_name"`
	LastLoginAt   *time.Time `json:"last_login_at"`
	CreatedAt     time.Time  `json:"created_at"`
}

type AdminListResponse struct {
	Admins     []AdminSummary `json:"admins"`
	Total      int            `json:"total"`
	Page       int            `json:"page"`
	Limit      int            `json:"limit"`
	TotalPages int            `json:"total_pages"`
	HasNext    bool           `json:"has_next"`
	HasPrev    bool           `json:"has_prev"`
}

// User role constants
const (
	RoleSuperAdmin      = "super_admin"
	RoleCityAdmin       = "city_admin"
	RoleTournamentAdmin = "tournament_admin"
	RoleOwner           = "owner"
	RoleCoach           = "coach"
	RoleReferee         = "referee"
	RolePlayer          = "player"
	RoleClient          = "client"
)

// Account status constants
const (
	AccountStatusActive         = "active"
	AccountStatusSuspended      = "suspended"
	AccountStatusPaymentPending = "payment_pending"
	AccountStatusDisabled       = "disabled"
)

// User management request/response structs

// UserUpdateRequest for updating user profiles
type UserUpdateRequest struct {
	FirstName      *string `json:"first_name,omitempty" validate:"omitempty,min=2,max=100"`
	LastName       *string `json:"last_name,omitempty" validate:"omitempty,min=2,max=100"`
	Phone          *string `json:"phone,omitempty" validate:"omitempty,min=10,max=20"`
	Identification *string `json:"identification,omitempty" validate:"omitempty,min=5,max=50"`
	PhotoURL       *string `json:"photo_url,omitempty" validate:"omitempty,url"`
	IsActive       *bool   `json:"is_active,omitempty"`
	AccountStatus  *string `json:"account_status,omitempty" validate:"omitempty,oneof=active suspended payment_pending disabled"`
}

// RoleAssignmentRequest for assigning roles to users
type RoleAssignmentRequest struct {
	UserID   uuid.UUID  `json:"user_id" validate:"required"`
	CityID   *uuid.UUID `json:"city_id,omitempty"`
	SportID  *uuid.UUID `json:"sport_id,omitempty"`
	RoleName string     `json:"role_name" validate:"required,oneof=city_admin tournament_admin owner coach referee player client"`
}

// ViewPermissionRequest for setting view permissions
type ViewPermissionRequest struct {
	UserID    *uuid.UUID `json:"user_id,omitempty"`
	RoleName  *string    `json:"role_name,omitempty"`
	ViewName  string     `json:"view_name" validate:"required"`
	IsAllowed bool       `json:"is_allowed"`
}

// AccountStatusUpdateRequest for updating account status
type AccountStatusUpdateRequest struct {
	Status string `json:"status" validate:"required,oneof=active suspended payment_pending disabled"`
	Reason string `json:"reason,omitempty"`
}

// UserListRequest for paginated user listing
type UserListRequest struct {
	Page          int    `query:"page" validate:"omitempty,min=1"`
	Limit         int    `query:"limit" validate:"omitempty,min=1,max=100"`
	Search        string `query:"search" validate:"omitempty,max=100"`
	Role          string `query:"role" validate:"omitempty,oneof=super_admin city_admin tournament_admin owner coach referee player client"`
	AccountStatus string `query:"account_status" validate:"omitempty,oneof=active suspended payment_pending disabled"`
	IsActive      *bool  `query:"is_active" validate:"omitempty"`
	SortBy        string `query:"sort_by" validate:"omitempty,oneof=first_name last_name email primary_role created_at last_login_at"`
	SortOrder     string `query:"sort_order" validate:"omitempty,oneof=asc desc"`
}

// UserSummary for user list responses
type UserSummary struct {
	UserID        uuid.UUID  `json:"user_id"`
	Email         string     `json:"email"`
	FirstName     string     `json:"first_name"`
	LastName      string     `json:"last_name"`
	Phone         *string    `json:"phone"`
	PhotoURL      *string    `json:"photo_url"`
	PrimaryRole   string     `json:"primary_role"`
	AccountStatus string     `json:"account_status"`
	IsActive      bool       `json:"is_active"`
	LastLoginAt   *time.Time `json:"last_login_at"`
	CreatedAt     time.Time  `json:"created_at"`
}

// UserListResponse for paginated user responses
type UserListResponse struct {
	Users      []UserSummary `json:"users"`
	Total      int           `json:"total"`
	Page       int           `json:"page"`
	Limit      int           `json:"limit"`
	TotalPages int           `json:"total_pages"`
	HasNext    bool          `json:"has_next"`
	HasPrev    bool          `json:"has_prev"`
}

// RoleAssignmentResponse for role assignment responses
type RoleAssignmentResponse struct {
	RoleAssignmentID uuid.UUID  `json:"role_assignment_id"`
	UserID           uuid.UUID  `json:"user_id"`
	CityID           *uuid.UUID `json:"city_id"`
	SportID          *uuid.UUID `json:"sport_id"`
	RoleName         string     `json:"role_name"`
	AssignedByUserID *uuid.UUID `json:"assigned_by_user_id"`
	IsActive         bool       `json:"is_active"`
	CreatedAt        time.Time  `json:"created_at"`
	Message          string     `json:"message"`
}

// ViewPermissionResponse for view permission responses
type ViewPermissionResponse struct {
	PermissionID       uuid.UUID  `json:"permission_id"`
	UserID             *uuid.UUID `json:"user_id"`
	RoleName           *string    `json:"role_name"`
	ViewName           string     `json:"view_name"`
	IsAllowed          bool       `json:"is_allowed"`
	ConfiguredByUserID uuid.UUID  `json:"configured_by_user_id"`
	CreatedAt          time.Time  `json:"created_at"`
	UpdatedAt          time.Time  `json:"updated_at"`
	Message            string     `json:"message"`
}
