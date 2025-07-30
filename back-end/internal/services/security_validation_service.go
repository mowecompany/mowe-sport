package services

import (
	"context"
	"fmt"
	"regexp"
	"strings"
	"time"
	"unicode"

	"github.com/google/uuid"
)

// SecurityValidationService handles all security-related validations
type SecurityValidationService struct {
	// Rate limiting storage (in production, use Redis)
	rateLimitStore map[string][]time.Time
	// Suspicious pattern detection
	suspiciousPatterns []string
}

// NewSecurityValidationService creates a new security validation service
func NewSecurityValidationService() *SecurityValidationService {
	return &SecurityValidationService{
		rateLimitStore: make(map[string][]time.Time),
		suspiciousPatterns: []string{
			"<script",
			"javascript:",
			"onload=",
			"onerror=",
			"eval(",
			"document.cookie",
			"window.location",
			"alert(",
			"confirm(",
			"prompt(",
			"<iframe",
			"<object",
			"<embed",
			"<link",
			"<meta",
			"<style",
			"vbscript:",
			"data:",
			"base64",
			"expression(",
			"@import",
			"binding:",
			"behaviour:",
			"moz-binding:",
		},
	}
}

// ValidateEmailRFC5322 validates email format according to RFC 5322 standard
func (s *SecurityValidationService) ValidateEmailRFC5322(email string) error {
	if email == "" {
		return fmt.Errorf("email is required")
	}

	if len(email) > 254 {
		return fmt.Errorf("email exceeds maximum length of 254 characters")
	}

	// RFC 5322 compliant email regex (more comprehensive)
	emailRegex := regexp.MustCompile(`^[a-zA-Z0-9!#$%&'*+/=?^_` + "`" + `{|}~-]+(?:\.[a-zA-Z0-9!#$%&'*+/=?^_` + "`" + `{|}~-]+)*@(?:[a-zA-Z0-9](?:[a-zA-Z0-9-]*[a-zA-Z0-9])?\.)+[a-zA-Z0-9](?:[a-zA-Z0-9-]*[a-zA-Z0-9])?$`)

	if !emailRegex.MatchString(email) {
		return fmt.Errorf("invalid email format according to RFC 5322")
	}

	// Additional domain validation
	parts := strings.Split(email, "@")
	if len(parts) != 2 {
		return fmt.Errorf("invalid email format: missing @ symbol")
	}

	localPart := parts[0]
	domain := parts[1]

	// Validate local part length
	if len(localPart) > 64 {
		return fmt.Errorf("email local part exceeds maximum length of 64 characters")
	}

	// Validate domain
	if err := s.validateEmailDomain(domain); err != nil {
		return fmt.Errorf("invalid email domain: %w", err)
	}

	return nil
}

// validateEmailDomain validates the domain part of an email
func (s *SecurityValidationService) validateEmailDomain(domain string) error {
	if domain == "" {
		return fmt.Errorf("domain is empty")
	}

	if len(domain) > 253 {
		return fmt.Errorf("domain exceeds maximum length of 253 characters")
	}

	// Check if domain has valid format
	domainRegex := regexp.MustCompile(`^[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(\.[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)*$`)
	if !domainRegex.MatchString(domain) {
		return fmt.Errorf("invalid domain format")
	}

	// Check for valid TLD
	parts := strings.Split(domain, ".")
	if len(parts) < 2 {
		return fmt.Errorf("domain must have at least one dot")
	}

	tld := parts[len(parts)-1]
	if len(tld) < 2 {
		return fmt.Errorf("top-level domain must be at least 2 characters")
	}

	// Optional: DNS lookup to verify domain exists (can be expensive)
	// _, err := net.LookupMX(domain)
	// if err != nil {
	//     return fmt.Errorf("domain does not exist or has no MX record")
	// }

	return nil
}

// ValidateInternationalPhone validates international phone number format
func (s *SecurityValidationService) ValidateInternationalPhone(phone string) error {
	if phone == "" {
		return nil // Phone is optional
	}

	// Remove all non-digit characters except + at the beginning
	cleanPhone := strings.TrimSpace(phone)

	// International phone regex (E.164 format)
	phoneRegex := regexp.MustCompile(`^\+[1-9]\d{1,14}$`)

	if !phoneRegex.MatchString(cleanPhone) {
		// Try alternative formats
		alternativeRegex := regexp.MustCompile(`^(\+\d{1,3}[\s\-]?)?\(?\d{1,4}\)?[\s\-]?\d{1,4}[\s\-]?\d{1,9}$`)
		if !alternativeRegex.MatchString(cleanPhone) {
			return fmt.Errorf("invalid international phone format. Use format: +[country code][number] (e.g., +57 300 123 4567)")
		}
	}

	// Validate length
	digitsOnly := regexp.MustCompile(`\D`).ReplaceAllString(cleanPhone, "")
	if len(digitsOnly) < 7 || len(digitsOnly) > 15 {
		return fmt.Errorf("phone number must be between 7 and 15 digits")
	}

	return nil
}

// ValidateIdentificationFormat validates identification format based on country/region
func (s *SecurityValidationService) ValidateIdentificationFormat(identification, country string) error {
	if identification == "" {
		return nil // Identification is optional
	}

	identification = strings.TrimSpace(identification)

	if len(identification) < 5 || len(identification) > 50 {
		return fmt.Errorf("identification must be between 5 and 50 characters")
	}

	// Country-specific validation
	switch strings.ToUpper(country) {
	case "CO", "COLOMBIA":
		return s.validateColombianID(identification)
	case "US", "USA", "UNITED STATES":
		return s.validateUSSSN(identification)
	case "MX", "MEXICO":
		return s.validateMexicanCURP(identification)
	default:
		// Generic validation for other countries
		return s.validateGenericID(identification)
	}
}

// validateColombianID validates Colombian cédula format
func (s *SecurityValidationService) validateColombianID(id string) error {
	// Colombian cédula: 8-10 digits
	idRegex := regexp.MustCompile(`^\d{8,10}$`)
	if !idRegex.MatchString(id) {
		return fmt.Errorf("Colombian cédula must be 8-10 digits")
	}
	return nil
}

// validateUSSSN validates US Social Security Number format
func (s *SecurityValidationService) validateUSSSN(ssn string) error {
	// SSN format: XXX-XX-XXXX or XXXXXXXXX
	ssnRegex := regexp.MustCompile(`^\d{3}-?\d{2}-?\d{4}$`)
	if !ssnRegex.MatchString(ssn) {
		return fmt.Errorf("US SSN must be in format XXX-XX-XXXX or XXXXXXXXX")
	}
	return nil
}

// validateMexicanCURP validates Mexican CURP format
func (s *SecurityValidationService) validateMexicanCURP(curp string) error {
	// CURP format: 18 characters
	curpRegex := regexp.MustCompile(`^[A-Z]{4}\d{6}[HM][A-Z]{5}[A-Z0-9]\d$`)
	if !curpRegex.MatchString(strings.ToUpper(curp)) {
		return fmt.Errorf("Mexican CURP must be 18 characters in correct format")
	}
	return nil
}

// validateGenericID validates generic identification format
func (s *SecurityValidationService) validateGenericID(id string) error {
	// Generic validation: alphanumeric characters, hyphens, and spaces allowed
	idRegex := regexp.MustCompile(`^[a-zA-Z0-9\s\-]+$`)
	if !idRegex.MatchString(id) {
		return fmt.Errorf("identification can only contain letters, numbers, spaces, and hyphens")
	}
	return nil
}

// SanitizeInput sanitizes input against XSS and SQL injection
func (s *SecurityValidationService) SanitizeInput(input string) string {
	if input == "" {
		return input
	}

	// Trim whitespace
	sanitized := strings.TrimSpace(input)

	// Remove null bytes
	sanitized = strings.ReplaceAll(sanitized, "\x00", "")

	// Remove or escape HTML/XML tags
	htmlTagRegex := regexp.MustCompile(`<[^>]*>`)
	sanitized = htmlTagRegex.ReplaceAllString(sanitized, "")

	// Remove suspicious patterns
	for _, pattern := range s.suspiciousPatterns {
		sanitized = strings.ReplaceAll(strings.ToLower(sanitized), strings.ToLower(pattern), "")
	}

	// Remove SQL injection patterns
	sqlPatterns := []string{
		"'", "\"", ";", "--", "/*", "*/", "xp_", "sp_",
		"union", "select", "insert", "update", "delete", "drop",
		"create", "alter", "exec", "execute", "declare",
	}

	for _, pattern := range sqlPatterns {
		// Only remove if it appears to be part of SQL syntax
		if strings.Contains(strings.ToLower(sanitized), pattern) {
			// More sophisticated SQL injection detection
			sqlRegex := regexp.MustCompile(`(?i)\b` + regexp.QuoteMeta(pattern) + `\b`)
			sanitized = sqlRegex.ReplaceAllString(sanitized, "")
		}
	}

	// Limit length to prevent buffer overflow attacks
	if len(sanitized) > 1000 {
		sanitized = sanitized[:1000]
	}

	return sanitized
}

// CheckRateLimit implements rate limiting for registration endpoint
func (s *SecurityValidationService) CheckRateLimit(ctx context.Context, identifier string, maxRequests int, window time.Duration) error {
	now := time.Now()

	// Clean old entries
	if requests, exists := s.rateLimitStore[identifier]; exists {
		var validRequests []time.Time
		for _, reqTime := range requests {
			if now.Sub(reqTime) < window {
				validRequests = append(validRequests, reqTime)
			}
		}
		s.rateLimitStore[identifier] = validRequests
	}

	// Check current request count
	currentRequests := len(s.rateLimitStore[identifier])
	if currentRequests >= maxRequests {
		return fmt.Errorf("rate limit exceeded: maximum %d requests per %v", maxRequests, window)
	}

	// Add current request
	s.rateLimitStore[identifier] = append(s.rateLimitStore[identifier], now)

	return nil
}

// DetectSuspiciousPatterns detects suspicious patterns in input data
func (s *SecurityValidationService) DetectSuspiciousPatterns(data map[string]string) []string {
	var suspiciousFindings []string

	for field, value := range data {
		lowerValue := strings.ToLower(value)

		// Check for suspicious patterns
		for _, pattern := range s.suspiciousPatterns {
			if strings.Contains(lowerValue, strings.ToLower(pattern)) {
				suspiciousFindings = append(suspiciousFindings,
					fmt.Sprintf("Suspicious pattern '%s' found in field '%s'", pattern, field))
			}
		}

		// Check for excessive special characters
		specialCharCount := 0
		for _, char := range value {
			if !unicode.IsLetter(char) && !unicode.IsDigit(char) && !unicode.IsSpace(char) {
				specialCharCount++
			}
		}

		if len(value) > 0 && float64(specialCharCount)/float64(len(value)) > 0.3 {
			suspiciousFindings = append(suspiciousFindings,
				fmt.Sprintf("Excessive special characters in field '%s'", field))
		}

		// Check for repeated patterns
		if len(value) > 10 {
			for i := 0; i < len(value)-5; i++ {
				substr := value[i : i+3]
				if strings.Count(value, substr) > 3 {
					suspiciousFindings = append(suspiciousFindings,
						fmt.Sprintf("Repeated pattern detected in field '%s'", field))
					break
				}
			}
		}

		// Check for binary data
		for _, char := range value {
			if char < 32 && char != 9 && char != 10 && char != 13 { // Allow tab, newline, carriage return
				suspiciousFindings = append(suspiciousFindings,
					fmt.Sprintf("Binary data detected in field '%s'", field))
				break
			}
		}
	}

	return suspiciousFindings
}

// ValidateAllowedEmailDomains validates if email domain is in allowed list
func (s *SecurityValidationService) ValidateAllowedEmailDomains(email string, allowedDomains []string) error {
	if len(allowedDomains) == 0 {
		return nil // No restrictions
	}

	parts := strings.Split(email, "@")
	if len(parts) != 2 {
		return fmt.Errorf("invalid email format")
	}

	domain := strings.ToLower(parts[1])

	for _, allowedDomain := range allowedDomains {
		if strings.ToLower(allowedDomain) == domain {
			return nil
		}
	}

	return fmt.Errorf("email domain '%s' is not allowed", domain)
}

// LogSecurityEvent logs security-related events for auditing
func (s *SecurityValidationService) LogSecurityEvent(ctx context.Context, eventType, description string, metadata map[string]interface{}) {
	// In production, this should write to a proper logging system
	// For now, we'll just print to console
	fmt.Printf("[SECURITY] %s: %s - %v\n", eventType, description, metadata)

	// TODO: Implement proper security logging to database or external service
	// This should include:
	// - Timestamp
	// - Event type
	// - User ID (if available)
	// - IP address
	// - User agent
	// - Description
	// - Metadata
}

// GetClientIP extracts client IP from request context
func (s *SecurityValidationService) GetClientIP(ctx context.Context) string {
	// This would typically extract IP from HTTP headers
	// For now, return a placeholder
	return "unknown"
}

// IsValidUUID validates UUID format
func (s *SecurityValidationService) IsValidUUID(uuidStr string) error {
	_, err := uuid.Parse(uuidStr)
	if err != nil {
		return fmt.Errorf("invalid UUID format: %w", err)
	}
	return nil
}

// ValidatePasswordStrength validates password strength
func (s *SecurityValidationService) ValidatePasswordStrength(password string) error {
	if len(password) < 8 {
		return fmt.Errorf("password must be at least 8 characters long")
	}

	if len(password) > 128 {
		return fmt.Errorf("password must not exceed 128 characters")
	}

	var (
		hasUpper   = false
		hasLower   = false
		hasNumber  = false
		hasSpecial = false
	)

	for _, char := range password {
		switch {
		case unicode.IsUpper(char):
			hasUpper = true
		case unicode.IsLower(char):
			hasLower = true
		case unicode.IsNumber(char):
			hasNumber = true
		case unicode.IsPunct(char) || unicode.IsSymbol(char):
			hasSpecial = true
		}
	}

	if !hasUpper {
		return fmt.Errorf("password must contain at least one uppercase letter")
	}
	if !hasLower {
		return fmt.Errorf("password must contain at least one lowercase letter")
	}
	if !hasNumber {
		return fmt.Errorf("password must contain at least one number")
	}
	if !hasSpecial {
		return fmt.Errorf("password must contain at least one special character")
	}

	return nil
}
