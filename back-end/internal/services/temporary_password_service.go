package services

import (
	"context"
	"fmt"
	"mowesport/internal/database"
	"time"

	"github.com/google/uuid"
	"golang.org/x/crypto/bcrypt"
)

type TemporaryPasswordService struct {
	db           *database.Database
	auditService *SecurityAuditService
}

type TemporaryPasswordData struct {
	UserID         uuid.UUID  `json:"user_id"`
	TempPassword   string     `json:"temp_password"`
	ExpirationDate time.Time  `json:"expiration_date"`
	IsUsed         bool       `json:"is_used"`
	CreatedAt      time.Time  `json:"created_at"`
	UsedAt         *time.Time `json:"used_at,omitempty"`
}

func NewTemporaryPasswordService(db *database.Database) *TemporaryPasswordService {
	return &TemporaryPasswordService{
		db:           db,
		auditService: NewSecurityAuditService(db),
	}
}

// CreateTemporaryPassword creates a new temporary password for a user
func (s *TemporaryPasswordService) CreateTemporaryPassword(ctx context.Context, userID uuid.UUID, expirationHours int) (string, error) {
	// Generate secure temporary password
	tempPassword, err := s.generateSecurePassword()
	if err != nil {
		return "", fmt.Errorf("failed to generate temporary password: %w", err)
	}

	// Hash the temporary password
	hashedPassword, err := bcrypt.GenerateFromPassword([]byte(tempPassword), bcrypt.DefaultCost)
	if err != nil {
		return "", fmt.Errorf("failed to hash temporary password: %w", err)
	}

	// Calculate expiration date
	expirationDate := time.Now().Add(time.Duration(expirationHours) * time.Hour)

	// Start transaction
	tx, err := s.db.GetConnection().Begin(ctx)
	if err != nil {
		return "", fmt.Errorf("failed to start transaction: %w", err)
	}
	defer tx.Rollback(ctx)

	// Update user's password with temporary password and set expiration
	_, err = tx.Exec(ctx, `
		UPDATE user_profiles 
		SET password_hash = $1, 
		    token_expiration_date = $2,
		    updated_at = NOW()
		WHERE user_id = $3
	`, string(hashedPassword), expirationDate, userID)
	if err != nil {
		return "", fmt.Errorf("failed to update user password: %w", err)
	}

	// Log the temporary password creation
	_, err = tx.Exec(ctx, `
		INSERT INTO audit_logs (
			user_id, action, table_name, record_id, 
			new_values, ip_address, user_agent
		) VALUES (
			$1, 'TEMP_PASSWORD_CREATED', 'user_profiles', $2,
			$3, '127.0.0.1', 'System'
		)
	`, userID, userID.String(), fmt.Sprintf(`{"expiration_date": "%s"}`, expirationDate.Format(time.RFC3339)))
	if err != nil {
		return "", fmt.Errorf("failed to log temporary password creation: %w", err)
	}

	// Commit transaction
	if err := tx.Commit(ctx); err != nil {
		return "", fmt.Errorf("failed to commit transaction: %w", err)
	}

	// Log security event
	s.auditService.LogSecurityEvent(ctx, SecurityEvent{
		EventType:   "TEMPORARY_PASSWORD_CREATED",
		Description: "Temporary password created for user",
		UserID:      &userID,
		IPAddress:   "127.0.0.1",
		UserAgent:   "System",
		Metadata: map[string]interface{}{
			"user_id":          userID,
			"expiration_date":  expirationDate,
			"expires_in_hours": expirationHours,
		},
	})

	return tempPassword, nil
}

// ValidateTemporaryPassword validates if a password is temporary and not expired
func (s *TemporaryPasswordService) ValidateTemporaryPassword(ctx context.Context, userID uuid.UUID) (bool, error) {
	var expirationDate *time.Time
	err := s.db.GetConnection().QueryRow(ctx, `
		SELECT token_expiration_date 
		FROM user_profiles 
		WHERE user_id = $1
	`, userID).Scan(&expirationDate)

	if err != nil {
		return false, fmt.Errorf("failed to check temporary password: %w", err)
	}

	// If no expiration date, it's not a temporary password
	if expirationDate == nil {
		return false, nil
	}

	// Check if password has expired
	if time.Now().After(*expirationDate) {
		// Mark as expired and require password reset
		s.auditService.LogSecurityEvent(ctx, SecurityEvent{
			EventType:   "TEMPORARY_PASSWORD_EXPIRED",
			Description: "Temporary password expired",
			UserID:      &userID,
			IPAddress:   "127.0.0.1",
			UserAgent:   "System",
			Metadata: map[string]interface{}{
				"user_id":         userID,
				"expiration_date": expirationDate,
			},
		})
		return false, fmt.Errorf("temporary password has expired")
	}

	return true, nil
}

// MarkTemporaryPasswordAsUsed marks a temporary password as used and clears expiration
func (s *TemporaryPasswordService) MarkTemporaryPasswordAsUsed(ctx context.Context, userID uuid.UUID) error {
	// Clear the expiration date to indicate the temporary password has been changed
	_, err := s.db.GetConnection().Exec(ctx, `
		UPDATE user_profiles 
		SET token_expiration_date = NULL,
		    updated_at = NOW()
		WHERE user_id = $1
	`, userID)

	if err != nil {
		return fmt.Errorf("failed to mark temporary password as used: %w", err)
	}

	// Log the event
	s.auditService.LogSecurityEvent(ctx, SecurityEvent{
		EventType:   "TEMPORARY_PASSWORD_USED",
		Description: "Temporary password was changed by user",
		UserID:      &userID,
		IPAddress:   "127.0.0.1",
		UserAgent:   "System",
		Metadata: map[string]interface{}{
			"user_id": userID,
		},
	})

	return nil
}

// RegenerateTemporaryPassword regenerates a temporary password for a user
func (s *TemporaryPasswordService) RegenerateTemporaryPassword(ctx context.Context, userID uuid.UUID, expirationHours int) (string, error) {
	// Log the regeneration attempt
	s.auditService.LogSecurityEvent(ctx, SecurityEvent{
		EventType:   "TEMPORARY_PASSWORD_REGENERATION_REQUESTED",
		Description: "Temporary password regeneration requested",
		UserID:      &userID,
		IPAddress:   "127.0.0.1",
		UserAgent:   "System",
		Metadata: map[string]interface{}{
			"user_id": userID,
		},
	})

	// Create new temporary password (this will overwrite the old one)
	return s.CreateTemporaryPassword(ctx, userID, expirationHours)
}

// CleanupExpiredTemporaryPasswords removes expired temporary password markers
func (s *TemporaryPasswordService) CleanupExpiredTemporaryPasswords(ctx context.Context) (int, error) {
	result, err := s.db.GetConnection().Exec(ctx, `
		UPDATE user_profiles 
		SET token_expiration_date = NULL,
		    updated_at = NOW()
		WHERE token_expiration_date IS NOT NULL 
		AND token_expiration_date < NOW()
	`)

	if err != nil {
		return 0, fmt.Errorf("failed to cleanup expired temporary passwords: %w", err)
	}

	rowsAffected := result.RowsAffected()

	if rowsAffected > 0 {
		s.auditService.LogSecurityEvent(ctx, SecurityEvent{
			EventType:   "EXPIRED_TEMP_PASSWORDS_CLEANED",
			Description: "Expired temporary passwords cleaned up",
			IPAddress:   "127.0.0.1",
			UserAgent:   "System",
			Metadata: map[string]interface{}{
				"count": rowsAffected,
			},
		})
	}

	return int(rowsAffected), nil
}

// GetTemporaryPasswordInfo gets information about a user's temporary password
func (s *TemporaryPasswordService) GetTemporaryPasswordInfo(ctx context.Context, userID uuid.UUID) (*TemporaryPasswordData, error) {
	var data TemporaryPasswordData
	var expirationDate *time.Time

	err := s.db.GetConnection().QueryRow(ctx, `
		SELECT user_id, token_expiration_date, created_at, updated_at
		FROM user_profiles 
		WHERE user_id = $1
	`, userID).Scan(&data.UserID, &expirationDate, &data.CreatedAt, &data.UsedAt)

	if err != nil {
		return nil, fmt.Errorf("failed to get temporary password info: %w", err)
	}

	if expirationDate != nil {
		data.ExpirationDate = *expirationDate
		data.IsUsed = false

		// Check if expired
		if time.Now().After(*expirationDate) {
			data.IsUsed = true
		}
	} else {
		data.IsUsed = true
	}

	return &data, nil
}

// generateSecurePassword generates a secure temporary password
func (s *TemporaryPasswordService) generateSecurePassword() (string, error) {
	// Use the same logic as AdminService for consistency
	adminService := &AdminService{}
	return adminService.generateTemporaryPassword()
}

// IsPasswordTemporary checks if a user currently has a temporary password
func (s *TemporaryPasswordService) IsPasswordTemporary(ctx context.Context, userID uuid.UUID) (bool, *time.Time, error) {
	var expirationDate *time.Time
	err := s.db.GetConnection().QueryRow(ctx, `
		SELECT token_expiration_date 
		FROM user_profiles 
		WHERE user_id = $1
	`, userID).Scan(&expirationDate)

	if err != nil {
		return false, nil, fmt.Errorf("failed to check if password is temporary: %w", err)
	}

	// If no expiration date, it's not temporary
	if expirationDate == nil {
		return false, nil, nil
	}

	// If expired, it's no longer valid
	if time.Now().After(*expirationDate) {
		return false, expirationDate, nil
	}

	return true, expirationDate, nil
}

// ForcePasswordChange forces a user to change their password on next login
func (s *TemporaryPasswordService) ForcePasswordChange(ctx context.Context, userID uuid.UUID) error {
	// Set expiration to now to force immediate password change
	_, err := s.db.GetConnection().Exec(ctx, `
		UPDATE user_profiles 
		SET token_expiration_date = NOW(),
		    updated_at = NOW()
		WHERE user_id = $1
	`, userID)

	if err != nil {
		return fmt.Errorf("failed to force password change: %w", err)
	}

	// Log the event
	s.auditService.LogSecurityEvent(ctx, SecurityEvent{
		EventType:   "PASSWORD_CHANGE_FORCED",
		Description: "Password change forced for user",
		UserID:      &userID,
		IPAddress:   "127.0.0.1",
		UserAgent:   "System",
		Metadata: map[string]interface{}{
			"user_id": userID,
		},
	})

	return nil
}
