package config

import (
	"time"
)

// SecurityConfig holds all security-related configuration
type SecurityConfig struct {
	// Rate limiting configuration
	RateLimit RateLimitConfig `json:"rate_limit"`

	// Password policy configuration
	PasswordPolicy PasswordPolicyConfig `json:"password_policy"`

	// Email validation configuration
	EmailValidation EmailValidationConfig `json:"email_validation"`

	// Phone validation configuration
	PhoneValidation PhoneValidationConfig `json:"phone_validation"`

	// Identification validation configuration
	IdentificationValidation IdentificationValidationConfig `json:"identification_validation"`

	// Audit logging configuration
	AuditLogging AuditLoggingConfig `json:"audit_logging"`

	// Suspicious activity detection
	SuspiciousActivityDetection SuspiciousActivityConfig `json:"suspicious_activity"`
}

// RateLimitConfig defines rate limiting settings
type RateLimitConfig struct {
	AdminRegistration RateLimitRule `json:"admin_registration"`
	EmailValidation   RateLimitRule `json:"email_validation"`
	GeneralAPI        RateLimitRule `json:"general_api"`
	Login             RateLimitRule `json:"login"`
}

// RateLimitRule defines a specific rate limit rule
type RateLimitRule struct {
	MaxRequests int           `json:"max_requests"`
	Window      time.Duration `json:"window"`
	Enabled     bool          `json:"enabled"`
}

// PasswordPolicyConfig defines password requirements
type PasswordPolicyConfig struct {
	MinLength        int  `json:"min_length"`
	MaxLength        int  `json:"max_length"`
	RequireUppercase bool `json:"require_uppercase"`
	RequireLowercase bool `json:"require_lowercase"`
	RequireNumbers   bool `json:"require_numbers"`
	RequireSpecial   bool `json:"require_special"`
	ExpirationDays   int  `json:"expiration_days"`
}

// EmailValidationConfig defines email validation settings
type EmailValidationConfig struct {
	EnableRFC5322Validation  bool     `json:"enable_rfc5322_validation"`
	AllowedDomains           []string `json:"allowed_domains"`
	BlockedDomains           []string `json:"blocked_domains"`
	MaxLength                int      `json:"max_length"`
	EnableDomainVerification bool     `json:"enable_domain_verification"`
}

// PhoneValidationConfig defines phone validation settings
type PhoneValidationConfig struct {
	EnableInternationalFormat bool     `json:"enable_international_format"`
	AllowedCountryCodes       []string `json:"allowed_country_codes"`
	MinLength                 int      `json:"min_length"`
	MaxLength                 int      `json:"max_length"`
}

// IdentificationValidationConfig defines identification validation settings
type IdentificationValidationConfig struct {
	DefaultCountry    string            `json:"default_country"`
	CountryValidators map[string]string `json:"country_validators"`
	MinLength         int               `json:"min_length"`
	MaxLength         int               `json:"max_length"`
}

// AuditLoggingConfig defines audit logging settings
type AuditLoggingConfig struct {
	Enabled                   bool   `json:"enabled"`
	LogLevel                  string `json:"log_level"`
	RetentionDays             int    `json:"retention_days"`
	EnableRealTimeAlerts      bool   `json:"enable_real_time_alerts"`
	CriticalEventNotification bool   `json:"critical_event_notification"`
}

// SuspiciousActivityConfig defines suspicious activity detection settings
type SuspiciousActivityConfig struct {
	Enabled                   bool     `json:"enabled"`
	MaxSpecialCharPercentage  float64  `json:"max_special_char_percentage"`
	SuspiciousPatterns        []string `json:"suspicious_patterns"`
	EnablePatternDetection    bool     `json:"enable_pattern_detection"`
	EnableBinaryDataDetection bool     `json:"enable_binary_data_detection"`
	MaxRepeatedPatternCount   int      `json:"max_repeated_pattern_count"`
}

// GetDefaultSecurityConfig returns the default security configuration
func GetDefaultSecurityConfig() SecurityConfig {
	return SecurityConfig{
		RateLimit: RateLimitConfig{
			AdminRegistration: RateLimitRule{
				MaxRequests: 3,
				Window:      15 * time.Minute,
				Enabled:     true,
			},
			EmailValidation: RateLimitRule{
				MaxRequests: 20,
				Window:      1 * time.Minute,
				Enabled:     true,
			},
			GeneralAPI: RateLimitRule{
				MaxRequests: 100,
				Window:      1 * time.Minute,
				Enabled:     true,
			},
			Login: RateLimitRule{
				MaxRequests: 5,
				Window:      5 * time.Minute,
				Enabled:     true,
			},
		},
		PasswordPolicy: PasswordPolicyConfig{
			MinLength:        8,
			MaxLength:        128,
			RequireUppercase: true,
			RequireLowercase: true,
			RequireNumbers:   true,
			RequireSpecial:   true,
			ExpirationDays:   90,
		},
		EmailValidation: EmailValidationConfig{
			EnableRFC5322Validation:  true,
			AllowedDomains:           []string{}, // Empty means all domains allowed
			BlockedDomains:           []string{"tempmail.com", "10minutemail.com", "guerrillamail.com"},
			MaxLength:                254,
			EnableDomainVerification: false, // Can be expensive, enable in production if needed
		},
		PhoneValidation: PhoneValidationConfig{
			EnableInternationalFormat: true,
			AllowedCountryCodes:       []string{}, // Empty means all country codes allowed
			MinLength:                 7,
			MaxLength:                 15,
		},
		IdentificationValidation: IdentificationValidationConfig{
			DefaultCountry: "CO", // Colombia
			CountryValidators: map[string]string{
				"CO": "colombian_cedula",
				"US": "us_ssn",
				"MX": "mexican_curp",
			},
			MinLength: 5,
			MaxLength: 50,
		},
		AuditLogging: AuditLoggingConfig{
			Enabled:                   true,
			LogLevel:                  "INFO",
			RetentionDays:             365,
			EnableRealTimeAlerts:      true,
			CriticalEventNotification: true,
		},
		SuspiciousActivityDetection: SuspiciousActivityConfig{
			Enabled:                   true,
			MaxSpecialCharPercentage:  0.3,
			EnablePatternDetection:    true,
			EnableBinaryDataDetection: true,
			MaxRepeatedPatternCount:   3,
			SuspiciousPatterns: []string{
				"<script", "javascript:", "onload=", "onerror=", "eval(",
				"document.cookie", "window.location", "alert(", "confirm(",
				"prompt(", "<iframe", "<object", "<embed", "<link", "<meta",
				"<style", "vbscript:", "data:", "base64", "expression(",
				"@import", "binding:", "behaviour:", "moz-binding:",
				"union select", "drop table", "insert into", "update set",
				"delete from", "create table", "alter table", "exec(",
				"execute(", "xp_", "sp_", "/*", "*/", "--", ";",
			},
		},
	}
}

// ValidateSecurityConfig validates the security configuration
func (sc *SecurityConfig) ValidateSecurityConfig() error {
	// Validate rate limit configuration
	if sc.RateLimit.AdminRegistration.MaxRequests <= 0 {
		sc.RateLimit.AdminRegistration.MaxRequests = 3
	}
	if sc.RateLimit.AdminRegistration.Window <= 0 {
		sc.RateLimit.AdminRegistration.Window = 15 * time.Minute
	}

	// Validate password policy
	if sc.PasswordPolicy.MinLength < 8 {
		sc.PasswordPolicy.MinLength = 8
	}
	if sc.PasswordPolicy.MaxLength > 256 {
		sc.PasswordPolicy.MaxLength = 256
	}

	// Validate email configuration
	if sc.EmailValidation.MaxLength > 254 {
		sc.EmailValidation.MaxLength = 254
	}

	// Validate phone configuration
	if sc.PhoneValidation.MinLength < 7 {
		sc.PhoneValidation.MinLength = 7
	}
	if sc.PhoneValidation.MaxLength > 15 {
		sc.PhoneValidation.MaxLength = 15
	}

	// Validate identification configuration
	if sc.IdentificationValidation.MinLength < 5 {
		sc.IdentificationValidation.MinLength = 5
	}
	if sc.IdentificationValidation.MaxLength > 50 {
		sc.IdentificationValidation.MaxLength = 50
	}

	// Validate audit logging
	if sc.AuditLogging.RetentionDays <= 0 {
		sc.AuditLogging.RetentionDays = 365
	}

	// Validate suspicious activity detection
	if sc.SuspiciousActivityDetection.MaxSpecialCharPercentage <= 0 ||
		sc.SuspiciousActivityDetection.MaxSpecialCharPercentage > 1 {
		sc.SuspiciousActivityDetection.MaxSpecialCharPercentage = 0.3
	}

	return nil
}

// IsEmailDomainAllowed checks if an email domain is allowed
func (sc *SecurityConfig) IsEmailDomainAllowed(domain string) bool {
	// Check blocked domains first
	for _, blocked := range sc.EmailValidation.BlockedDomains {
		if domain == blocked {
			return false
		}
	}

	// If no allowed domains specified, all are allowed (except blocked)
	if len(sc.EmailValidation.AllowedDomains) == 0 {
		return true
	}

	// Check if domain is in allowed list
	for _, allowed := range sc.EmailValidation.AllowedDomains {
		if domain == allowed {
			return true
		}
	}

	return false
}

// IsCountryCodeAllowed checks if a phone country code is allowed
func (sc *SecurityConfig) IsCountryCodeAllowed(countryCode string) bool {
	// If no allowed country codes specified, all are allowed
	if len(sc.PhoneValidation.AllowedCountryCodes) == 0 {
		return true
	}

	for _, allowed := range sc.PhoneValidation.AllowedCountryCodes {
		if countryCode == allowed {
			return true
		}
	}

	return false
}
