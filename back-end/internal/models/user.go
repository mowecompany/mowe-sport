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
