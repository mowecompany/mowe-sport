package services

import (
	"context"
	"crypto/rand"
	"encoding/base32"
	"fmt"
	"mowesport/internal/database"
	"mowesport/internal/models"
	"time"

	"github.com/golang-jwt/jwt/v5"
	"github.com/google/uuid"
	"github.com/pquerna/otp"
	"github.com/pquerna/otp/totp"
	"golang.org/x/crypto/bcrypt"
)

type AuthService struct {
	db        *database.Database
	jwtSecret []byte
}

func NewAuthService(db *database.Database, jwtSecret string) *AuthService {
	return &AuthService{
		db:        db,
		jwtSecret: []byte(jwtSecret),
	}
}

// Login authenticates a user and returns JWT tokens
func (s *AuthService) Login(ctx context.Context, req *models.LoginRequest) (*models.LoginResponse, error) {
	// Get user from database
	var userProfile models.UserProfile
	err := s.db.GetConnection().QueryRow(ctx,
		`SELECT user_id, email, password_hash, first_name, last_name, primary_role, 
		 is_active, account_status, failed_login_attempts, locked_until, two_factor_enabled, two_factor_secret
		 FROM user_profiles WHERE email = $1`,
		req.Email,
	).Scan(&userProfile.UserID, &userProfile.Email, &userProfile.PasswordHash,
		&userProfile.FirstName, &userProfile.LastName, &userProfile.PrimaryRole,
		&userProfile.IsActive, &userProfile.AccountStatus,
		&userProfile.FailedLoginAttempts, &userProfile.LockedUntil,
		&userProfile.TwoFactorEnabled, &userProfile.TwoFactorSecret)

	if err != nil {
		return nil, fmt.Errorf("user not found")
	}

	// Check account status and locks
	if err := s.validateAccountStatus(&userProfile); err != nil {
		return nil, err
	}

	// Verify password
	if err := bcrypt.CompareHashAndPassword([]byte(userProfile.PasswordHash), []byte(req.Password)); err != nil {
		// Increment failed login attempts
		s.incrementFailedAttempts(ctx, userProfile.UserID)
		return nil, fmt.Errorf("invalid credentials")
	}

	// Check 2FA if enabled
	if userProfile.TwoFactorEnabled {
		if req.TwoFactorCode == "" {
			return nil, fmt.Errorf("two_factor_required")
		}

		if !s.verify2FACode(*userProfile.TwoFactorSecret, req.TwoFactorCode) {
			s.incrementFailedAttempts(ctx, userProfile.UserID)
			return nil, fmt.Errorf("invalid_two_factor_code")
		}
	}

	// Reset failed attempts and update last login
	s.resetFailedAttempts(ctx, userProfile.UserID)

	// Generate tokens
	accessToken, err := s.generateAccessToken(&userProfile)
	if err != nil {
		return nil, fmt.Errorf("failed to generate access token: %w", err)
	}

	refreshToken, err := s.generateRefreshToken(&userProfile)
	if err != nil {
		return nil, fmt.Errorf("failed to generate refresh token: %w", err)
	}

	return &models.LoginResponse{
		UserID:       userProfile.UserID,
		Email:        userProfile.Email,
		FirstName:    userProfile.FirstName,
		LastName:     userProfile.LastName,
		PrimaryRole:  userProfile.PrimaryRole,
		Token:        accessToken,
		RefreshToken: refreshToken,
		ExpiresIn:    3600, // 1 hour
	}, nil
}

// RefreshToken generates new access token from refresh token
func (s *AuthService) RefreshToken(ctx context.Context, refreshToken string) (*models.LoginResponse, error) {
	// Parse and validate refresh token
	token, err := jwt.Parse(refreshToken, func(token *jwt.Token) (interface{}, error) {
		if _, ok := token.Method.(*jwt.SigningMethodHMAC); !ok {
			return nil, fmt.Errorf("unexpected signing method: %v", token.Header["alg"])
		}
		return s.jwtSecret, nil
	})

	if err != nil || !token.Valid {
		return nil, fmt.Errorf("invalid refresh token")
	}

	claims, ok := token.Claims.(jwt.MapClaims)
	if !ok {
		return nil, fmt.Errorf("invalid token claims")
	}

	// Check if it's a refresh token
	tokenType, ok := claims["type"].(string)
	if !ok || tokenType != "refresh" {
		return nil, fmt.Errorf("invalid token type")
	}

	// Get user ID
	userIDStr, ok := claims["user_id"].(string)
	if !ok {
		return nil, fmt.Errorf("invalid user ID in token")
	}

	userID, err := uuid.Parse(userIDStr)
	if err != nil {
		return nil, fmt.Errorf("invalid user ID format")
	}

	// Get fresh user data
	var userProfile models.UserProfile
	err = s.db.GetConnection().QueryRow(ctx,
		`SELECT user_id, email, first_name, last_name, primary_role, 
		 is_active, account_status FROM user_profiles WHERE user_id = $1`,
		userID,
	).Scan(&userProfile.UserID, &userProfile.Email, &userProfile.FirstName,
		&userProfile.LastName, &userProfile.PrimaryRole, &userProfile.IsActive,
		&userProfile.AccountStatus)

	if err != nil {
		return nil, fmt.Errorf("user not found")
	}

	// Check account status
	if err := s.validateAccountStatus(&userProfile); err != nil {
		return nil, err
	}

	// Generate new access token
	accessToken, err := s.generateAccessToken(&userProfile)
	if err != nil {
		return nil, fmt.Errorf("failed to generate access token: %w", err)
	}

	return &models.LoginResponse{
		UserID:      userProfile.UserID,
		Email:       userProfile.Email,
		FirstName:   userProfile.FirstName,
		LastName:    userProfile.LastName,
		PrimaryRole: userProfile.PrimaryRole,
		Token:       accessToken,
		ExpiresIn:   3600, // 1 hour
	}, nil
}

// RequestPasswordRecovery initiates password recovery process
func (s *AuthService) RequestPasswordRecovery(ctx context.Context, req *models.PasswordRecoveryRequest) error {
	// Check if user exists
	var userID uuid.UUID
	err := s.db.GetConnection().QueryRow(ctx,
		"SELECT user_id FROM user_profiles WHERE email = $1 AND is_active = true",
		req.Email,
	).Scan(&userID)

	if err != nil {
		// Don't reveal if email exists or not for security
		return nil
	}

	// Generate recovery token
	recoveryToken, err := s.generateRecoveryToken()
	if err != nil {
		return fmt.Errorf("failed to generate recovery token: %w", err)
	}

	// Store recovery token with expiration (10 minutes)
	expirationTime := time.Now().Add(10 * time.Minute)
	_, err = s.db.GetConnection().Exec(ctx,
		`UPDATE user_profiles 
		 SET token_recovery = $1, token_expiration_date = $2, updated_at = NOW()
		 WHERE user_id = $3`,
		recoveryToken, expirationTime, userID,
	)

	if err != nil {
		return fmt.Errorf("failed to store recovery token: %w", err)
	}

	// TODO: Send recovery email
	// This would be implemented with an email service

	return nil
}

// ResetPassword resets user password using recovery token
func (s *AuthService) ResetPassword(ctx context.Context, req *models.PasswordResetRequest) error {
	// Find user by recovery token
	var userID uuid.UUID
	var expirationDate time.Time
	err := s.db.GetConnection().QueryRow(ctx,
		`SELECT user_id, token_expiration_date 
		 FROM user_profiles 
		 WHERE token_recovery = $1 AND is_active = true`,
		req.Token,
	).Scan(&userID, &expirationDate)

	if err != nil {
		return fmt.Errorf("invalid or expired recovery token")
	}

	// Check if token is expired
	if time.Now().After(expirationDate) {
		return fmt.Errorf("recovery token has expired")
	}

	// Hash new password
	hashedPassword, err := bcrypt.GenerateFromPassword([]byte(req.NewPassword), bcrypt.DefaultCost)
	if err != nil {
		return fmt.Errorf("failed to hash password: %w", err)
	}

	// Update password and clear recovery token
	_, err = s.db.GetConnection().Exec(ctx,
		`UPDATE user_profiles 
		 SET password_hash = $1, token_recovery = NULL, token_expiration_date = NULL,
		     failed_login_attempts = 0, locked_until = NULL, updated_at = NOW()
		 WHERE user_id = $2`,
		string(hashedPassword), userID,
	)

	if err != nil {
		return fmt.Errorf("failed to update password: %w", err)
	}

	return nil
}

// Setup2FA generates 2FA secret and QR code for user
func (s *AuthService) Setup2FA(ctx context.Context, userID uuid.UUID) (*models.Setup2FAResponse, error) {
	// Get user info
	var email, firstName, lastName string
	err := s.db.GetConnection().QueryRow(ctx,
		"SELECT email, first_name, last_name FROM user_profiles WHERE user_id = $1",
		userID,
	).Scan(&email, &firstName, &lastName)

	if err != nil {
		return nil, fmt.Errorf("user not found")
	}

	// Generate secret
	secret := make([]byte, 20)
	_, err = rand.Read(secret)
	if err != nil {
		return nil, fmt.Errorf("failed to generate secret: %w", err)
	}

	secretBase32 := base32.StdEncoding.EncodeToString(secret)

	// Generate QR code URL
	key, err := otp.NewKeyFromURL(fmt.Sprintf(
		"otpauth://totp/MoweSport:%s?secret=%s&issuer=MoweSport",
		email, secretBase32,
	))
	if err != nil {
		return nil, fmt.Errorf("failed to generate OTP key: %w", err)
	}

	// Store secret (but don't enable 2FA yet)
	_, err = s.db.GetConnection().Exec(ctx,
		"UPDATE user_profiles SET two_factor_secret = $1, updated_at = NOW() WHERE user_id = $2",
		secretBase32, userID,
	)

	if err != nil {
		return nil, fmt.Errorf("failed to store 2FA secret: %w", err)
	}

	return &models.Setup2FAResponse{
		Secret: secretBase32,
		QRCode: key.URL(),
	}, nil
}

// Verify2FA verifies 2FA code and enables 2FA for user
func (s *AuthService) Verify2FA(ctx context.Context, userID uuid.UUID, req *models.Verify2FARequest) error {
	// Get user's 2FA secret
	var secret string
	err := s.db.GetConnection().QueryRow(ctx,
		"SELECT two_factor_secret FROM user_profiles WHERE user_id = $1",
		userID,
	).Scan(&secret)

	if err != nil {
		return fmt.Errorf("user not found or 2FA not set up")
	}

	// Verify code
	if !s.verify2FACode(secret, req.Code) {
		return fmt.Errorf("invalid 2FA code")
	}

	// Enable 2FA
	_, err = s.db.GetConnection().Exec(ctx,
		"UPDATE user_profiles SET two_factor_enabled = true, updated_at = NOW() WHERE user_id = $1",
		userID,
	)

	if err != nil {
		return fmt.Errorf("failed to enable 2FA: %w", err)
	}

	return nil
}

// Disable2FA disables 2FA for user
func (s *AuthService) Disable2FA(ctx context.Context, userID uuid.UUID, req *models.Verify2FARequest) error {
	// Get user's 2FA secret
	var secret string
	var enabled bool
	err := s.db.GetConnection().QueryRow(ctx,
		"SELECT two_factor_secret, two_factor_enabled FROM user_profiles WHERE user_id = $1",
		userID,
	).Scan(&secret, &enabled)

	if err != nil {
		return fmt.Errorf("user not found")
	}

	if !enabled {
		return fmt.Errorf("2FA is not enabled")
	}

	// Verify code before disabling
	if !s.verify2FACode(secret, req.Code) {
		return fmt.Errorf("invalid 2FA code")
	}

	// Disable 2FA and clear secret
	_, err = s.db.GetConnection().Exec(ctx,
		`UPDATE user_profiles 
		 SET two_factor_enabled = false, two_factor_secret = NULL, updated_at = NOW() 
		 WHERE user_id = $1`,
		userID,
	)

	if err != nil {
		return fmt.Errorf("failed to disable 2FA: %w", err)
	}

	return nil
}

// Helper methods

func (s *AuthService) validateAccountStatus(user *models.UserProfile) error {
	if !user.IsActive {
		return fmt.Errorf("account_inactive")
	}

	if user.AccountStatus != models.AccountStatusActive {
		return fmt.Errorf("account_%s", user.AccountStatus)
	}

	if user.LockedUntil != nil && time.Now().Before(*user.LockedUntil) {
		return fmt.Errorf("account_locked")
	}

	return nil
}

func (s *AuthService) incrementFailedAttempts(ctx context.Context, userID uuid.UUID) {
	// Get current failed attempts
	var attempts int
	s.db.GetConnection().QueryRow(ctx,
		"SELECT failed_login_attempts FROM user_profiles WHERE user_id = $1",
		userID,
	).Scan(&attempts)

	attempts++
	var lockUntil *time.Time

	// Progressive locking: 5 attempts = 15 min, 10 attempts = 24 hours
	if attempts >= 10 {
		lockTime := time.Now().Add(24 * time.Hour)
		lockUntil = &lockTime
	} else if attempts >= 5 {
		lockTime := time.Now().Add(15 * time.Minute)
		lockUntil = &lockTime
	}

	s.db.GetConnection().Exec(ctx,
		"UPDATE user_profiles SET failed_login_attempts = $1, locked_until = $2 WHERE user_id = $3",
		attempts, lockUntil, userID,
	)
}

func (s *AuthService) resetFailedAttempts(ctx context.Context, userID uuid.UUID) {
	s.db.GetConnection().Exec(ctx,
		`UPDATE user_profiles 
		 SET failed_login_attempts = 0, locked_until = NULL, last_login_at = NOW() 
		 WHERE user_id = $1`,
		userID,
	)
}

func (s *AuthService) generateAccessToken(user *models.UserProfile) (string, error) {
	claims := jwt.MapClaims{
		"user_id":      user.UserID.String(),
		"email":        user.Email,
		"first_name":   user.FirstName,
		"last_name":    user.LastName,
		"primary_role": user.PrimaryRole,
		"type":         "access",
		"exp":          time.Now().Add(time.Hour).Unix(),
		"iat":          time.Now().Unix(),
	}

	token := jwt.NewWithClaims(jwt.SigningMethodHS256, claims)
	return token.SignedString(s.jwtSecret)
}

func (s *AuthService) generateRefreshToken(user *models.UserProfile) (string, error) {
	claims := jwt.MapClaims{
		"user_id": user.UserID.String(),
		"type":    "refresh",
		"exp":     time.Now().Add(7 * 24 * time.Hour).Unix(), // 7 days
		"iat":     time.Now().Unix(),
	}

	token := jwt.NewWithClaims(jwt.SigningMethodHS256, claims)
	return token.SignedString(s.jwtSecret)
}

func (s *AuthService) generateRecoveryToken() (string, error) {
	bytes := make([]byte, 32)
	_, err := rand.Read(bytes)
	if err != nil {
		return "", err
	}
	return base32.StdEncoding.EncodeToString(bytes), nil
}

func (s *AuthService) verify2FACode(secret, code string) bool {
	return totp.Validate(code, secret)
}
