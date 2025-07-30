package services

import (
	"context"
	"encoding/json"
	"fmt"
	"mowesport/internal/database"
	"time"

	"github.com/google/uuid"
)

// SecurityAuditService handles security audit logging
type SecurityAuditService struct {
	db *database.Database
}

// NewSecurityAuditService creates a new security audit service
func NewSecurityAuditService(db *database.Database) *SecurityAuditService {
	return &SecurityAuditService{
		db: db,
	}
}

// SecurityEvent represents a security event for auditing
type SecurityEvent struct {
	EventID     uuid.UUID              `json:"event_id"`
	EventType   string                 `json:"event_type"`
	Description string                 `json:"description"`
	UserID      *uuid.UUID             `json:"user_id,omitempty"`
	IPAddress   string                 `json:"ip_address"`
	UserAgent   string                 `json:"user_agent"`
	Metadata    map[string]interface{} `json:"metadata"`
	Timestamp   time.Time              `json:"timestamp"`
	Severity    string                 `json:"severity"`
}

// EventType constants
const (
	EventTypeLogin                   = "LOGIN"
	EventTypeLoginFailed             = "LOGIN_FAILED"
	EventTypeLogout                  = "LOGOUT"
	EventTypeAdminRegistration       = "ADMIN_REGISTRATION"
	EventTypeAdminRegistrationFailed = "ADMIN_REGISTRATION_FAILED"
	EventTypeRateLimitExceeded       = "RATE_LIMIT_EXCEEDED"
	EventTypeSuspiciousActivity      = "SUSPICIOUS_ACTIVITY"
	EventTypeUnauthorizedAccess      = "UNAUTHORIZED_ACCESS"
	EventTypeDataValidationFailed    = "DATA_VALIDATION_FAILED"
	EventTypeSecurityViolation       = "SECURITY_VIOLATION"
	EventTypePasswordReset           = "PASSWORD_RESET"
	EventTypeAccountLocked           = "ACCOUNT_LOCKED"
	EventTypeAccountUnlocked         = "ACCOUNT_UNLOCKED"
	EventTypePermissionDenied        = "PERMISSION_DENIED"
)

// Severity levels
const (
	SeverityLow      = "LOW"
	SeverityMedium   = "MEDIUM"
	SeverityHigh     = "HIGH"
	SeverityCritical = "CRITICAL"
)

// LogSecurityEvent logs a security event to the database
func (s *SecurityAuditService) LogSecurityEvent(ctx context.Context, event SecurityEvent) error {
	// Ensure event has required fields
	if event.EventID == uuid.Nil {
		event.EventID = uuid.New()
	}
	if event.Timestamp.IsZero() {
		event.Timestamp = time.Now()
	}
	if event.Severity == "" {
		event.Severity = s.determineSeverity(event.EventType)
	}

	// Convert metadata to JSON
	metadataJSON, err := json.Marshal(event.Metadata)
	if err != nil {
		return fmt.Errorf("failed to marshal metadata: %w", err)
	}

	// Insert into audit log table
	_, err = s.db.GetConnection().Exec(ctx, `
		INSERT INTO security_audit_log (
			event_id, event_type, description, user_id, ip_address, 
			user_agent, metadata, timestamp, severity
		) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9)
	`,
		event.EventID, event.EventType, event.Description, event.UserID,
		event.IPAddress, event.UserAgent, string(metadataJSON),
		event.Timestamp, event.Severity,
	)

	if err != nil {
		// If audit logging fails, at least log to console
		fmt.Printf("[AUDIT_ERROR] Failed to log security event: %v\n", err)
		fmt.Printf("[AUDIT_FALLBACK] %+v\n", event)
		return fmt.Errorf("failed to log security event: %w", err)
	}

	// For critical events, also log to console for immediate visibility
	if event.Severity == SeverityCritical {
		fmt.Printf("[CRITICAL_SECURITY_EVENT] %s: %s - %v\n",
			event.EventType, event.Description, event.Metadata)
	}

	return nil
}

// LogAdminRegistrationAttempt logs admin registration attempts
func (s *SecurityAuditService) LogAdminRegistrationAttempt(ctx context.Context, success bool, adminEmail string, registeredBy *uuid.UUID, ipAddress, userAgent string, errorMsg string) error {
	eventType := EventTypeAdminRegistration
	description := "Admin registration successful"
	severity := SeverityMedium

	if !success {
		eventType = EventTypeAdminRegistrationFailed
		description = "Admin registration failed"
		severity = SeverityHigh
	}

	metadata := map[string]interface{}{
		"admin_email":   adminEmail,
		"registered_by": registeredBy,
		"success":       success,
	}

	if errorMsg != "" {
		metadata["error"] = errorMsg
	}

	event := SecurityEvent{
		EventType:   eventType,
		Description: description,
		UserID:      registeredBy,
		IPAddress:   ipAddress,
		UserAgent:   userAgent,
		Metadata:    metadata,
		Severity:    severity,
	}

	return s.LogSecurityEvent(ctx, event)
}

// LogSuspiciousActivity logs suspicious activity
func (s *SecurityAuditService) LogSuspiciousActivity(ctx context.Context, activityType, description string, userID *uuid.UUID, ipAddress, userAgent string, metadata map[string]interface{}) error {
	event := SecurityEvent{
		EventType:   EventTypeSuspiciousActivity,
		Description: fmt.Sprintf("%s: %s", activityType, description),
		UserID:      userID,
		IPAddress:   ipAddress,
		UserAgent:   userAgent,
		Metadata:    metadata,
		Severity:    SeverityHigh,
	}

	return s.LogSecurityEvent(ctx, event)
}

// LogRateLimitExceeded logs rate limit violations
func (s *SecurityAuditService) LogRateLimitExceeded(ctx context.Context, endpoint, ipAddress, userAgent string, metadata map[string]interface{}) error {
	event := SecurityEvent{
		EventType:   EventTypeRateLimitExceeded,
		Description: fmt.Sprintf("Rate limit exceeded for endpoint: %s", endpoint),
		IPAddress:   ipAddress,
		UserAgent:   userAgent,
		Metadata:    metadata,
		Severity:    SeverityMedium,
	}

	return s.LogSecurityEvent(ctx, event)
}

// LogUnauthorizedAccess logs unauthorized access attempts
func (s *SecurityAuditService) LogUnauthorizedAccess(ctx context.Context, resource string, userID *uuid.UUID, ipAddress, userAgent string, metadata map[string]interface{}) error {
	event := SecurityEvent{
		EventType:   EventTypeUnauthorizedAccess,
		Description: fmt.Sprintf("Unauthorized access attempt to: %s", resource),
		UserID:      userID,
		IPAddress:   ipAddress,
		UserAgent:   userAgent,
		Metadata:    metadata,
		Severity:    SeverityHigh,
	}

	return s.LogSecurityEvent(ctx, event)
}

// GetSecurityEvents retrieves security events with filtering
func (s *SecurityAuditService) GetSecurityEvents(ctx context.Context, filters SecurityEventFilters) ([]SecurityEvent, error) {
	query := `
		SELECT event_id, event_type, description, user_id, ip_address, 
		       user_agent, metadata, timestamp, severity
		FROM security_audit_log
		WHERE 1=1
	`
	args := []interface{}{}
	argCount := 0

	// Apply filters
	if filters.EventType != "" {
		argCount++
		query += fmt.Sprintf(" AND event_type = $%d", argCount)
		args = append(args, filters.EventType)
	}

	if filters.UserID != nil {
		argCount++
		query += fmt.Sprintf(" AND user_id = $%d", argCount)
		args = append(args, *filters.UserID)
	}

	if filters.IPAddress != "" {
		argCount++
		query += fmt.Sprintf(" AND ip_address = $%d", argCount)
		args = append(args, filters.IPAddress)
	}

	if filters.Severity != "" {
		argCount++
		query += fmt.Sprintf(" AND severity = $%d", argCount)
		args = append(args, filters.Severity)
	}

	if !filters.StartTime.IsZero() {
		argCount++
		query += fmt.Sprintf(" AND timestamp >= $%d", argCount)
		args = append(args, filters.StartTime)
	}

	if !filters.EndTime.IsZero() {
		argCount++
		query += fmt.Sprintf(" AND timestamp <= $%d", argCount)
		args = append(args, filters.EndTime)
	}

	// Add ordering and limit
	query += " ORDER BY timestamp DESC"
	if filters.Limit > 0 {
		argCount++
		query += fmt.Sprintf(" LIMIT $%d", argCount)
		args = append(args, filters.Limit)
	}

	rows, err := s.db.GetConnection().Query(ctx, query, args...)
	if err != nil {
		return nil, fmt.Errorf("failed to query security events: %w", err)
	}
	defer rows.Close()

	var events []SecurityEvent
	for rows.Next() {
		var event SecurityEvent
		var metadataJSON string

		err := rows.Scan(
			&event.EventID, &event.EventType, &event.Description,
			&event.UserID, &event.IPAddress, &event.UserAgent,
			&metadataJSON, &event.Timestamp, &event.Severity,
		)
		if err != nil {
			return nil, fmt.Errorf("failed to scan security event: %w", err)
		}

		// Parse metadata JSON
		if metadataJSON != "" {
			if err := json.Unmarshal([]byte(metadataJSON), &event.Metadata); err != nil {
				// If JSON parsing fails, store as string
				event.Metadata = map[string]interface{}{"raw": metadataJSON}
			}
		}

		events = append(events, event)
	}

	return events, nil
}

// SecurityEventFilters for filtering security events
type SecurityEventFilters struct {
	EventType string
	UserID    *uuid.UUID
	IPAddress string
	Severity  string
	StartTime time.Time
	EndTime   time.Time
	Limit     int
}

// determineSeverity determines the severity level based on event type
func (s *SecurityAuditService) determineSeverity(eventType string) string {
	switch eventType {
	case EventTypeLogin, EventTypeLogout:
		return SeverityLow
	case EventTypeAdminRegistration, EventTypePasswordReset:
		return SeverityMedium
	case EventTypeLoginFailed, EventTypeRateLimitExceeded, EventTypeDataValidationFailed:
		return SeverityMedium
	case EventTypeSuspiciousActivity, EventTypeUnauthorizedAccess, EventTypePermissionDenied:
		return SeverityHigh
	case EventTypeSecurityViolation, EventTypeAdminRegistrationFailed:
		return SeverityHigh
	case EventTypeAccountLocked:
		return SeverityCritical
	default:
		return SeverityMedium
	}
}

// CreateAuditLogTable creates the security audit log table if it doesn't exist
func (s *SecurityAuditService) CreateAuditLogTable(ctx context.Context) error {
	query := `
		CREATE TABLE IF NOT EXISTS security_audit_log (
			event_id UUID PRIMARY KEY,
			event_type VARCHAR(50) NOT NULL,
			description TEXT NOT NULL,
			user_id UUID REFERENCES user_profiles(user_id),
			ip_address INET,
			user_agent TEXT,
			metadata JSONB,
			timestamp TIMESTAMP WITH TIME ZONE NOT NULL,
			severity VARCHAR(20) NOT NULL,
			created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
		);

		-- Create indexes for better query performance
		CREATE INDEX IF NOT EXISTS idx_security_audit_event_type ON security_audit_log(event_type);
		CREATE INDEX IF NOT EXISTS idx_security_audit_user_id ON security_audit_log(user_id);
		CREATE INDEX IF NOT EXISTS idx_security_audit_timestamp ON security_audit_log(timestamp);
		CREATE INDEX IF NOT EXISTS idx_security_audit_severity ON security_audit_log(severity);
		CREATE INDEX IF NOT EXISTS idx_security_audit_ip_address ON security_audit_log(ip_address);
	`

	_, err := s.db.GetConnection().Exec(ctx, query)
	if err != nil {
		return fmt.Errorf("failed to create audit log table: %w", err)
	}

	return nil
}
