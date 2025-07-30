package services

import (
	"context"
	"crypto/rand"
	"fmt"
	"math/big"
	"mowesport/internal/database"
	"mowesport/internal/models"
	"strings"
	"time"

	"github.com/google/uuid"
	"golang.org/x/crypto/bcrypt"
)

type AdminService struct {
	db                *database.Database
	securityValidator *SecurityValidationService
}

func NewAdminService(db *database.Database) *AdminService {
	return &AdminService{
		db:                db,
		securityValidator: NewSecurityValidationService(),
	}
}

// RegisterAdmin creates a new admin user with role assignment
func (s *AdminService) RegisterAdmin(ctx context.Context, req *models.AdminRegistrationRequest, registeredByUserID uuid.UUID) (*models.AdminRegistrationResponse, error) {
	// Rate limiting check
	clientIP := s.securityValidator.GetClientIP(ctx)
	if err := s.securityValidator.CheckRateLimit(ctx, clientIP, 5, 15*time.Minute); err != nil {
		s.securityValidator.LogSecurityEvent(ctx, "RATE_LIMIT_EXCEEDED", "Admin registration rate limit exceeded", map[string]interface{}{
			"ip":    clientIP,
			"email": req.Email,
		})
		return nil, fmt.Errorf("rate limit exceeded: %w", err)
	}

	// Comprehensive security validation
	if err := s.validateSecurityRequirements(ctx, req); err != nil {
		s.securityValidator.LogSecurityEvent(ctx, "SECURITY_VALIDATION_FAILED", "Security validation failed for admin registration", map[string]interface{}{
			"email": req.Email,
			"error": err.Error(),
		})
		return nil, err
	}

	// Start transaction
	tx, err := s.db.GetConnection().Begin(ctx)
	if err != nil {
		return nil, fmt.Errorf("failed to start transaction: %w", err)
	}
	defer tx.Rollback(ctx)

	// Validate email uniqueness
	if err := s.validateEmailUniqueness(ctx, req.Email); err != nil {
		return nil, err
	}

	// Validate city and sport existence
	if err := s.validateCityAndSport(ctx, req.CityID, req.SportID); err != nil {
		return nil, err
	}

	// Validate no duplicate admin for city/sport combination
	if err := s.validateNoDuplicateAdmin(ctx, req.CityID, req.SportID); err != nil {
		return nil, err
	}

	// Generate secure temporary password
	tempPassword, err := s.generateTemporaryPassword()
	if err != nil {
		return nil, fmt.Errorf("failed to generate temporary password: %w", err)
	}

	// Hash the temporary password
	hashedPassword, err := bcrypt.GenerateFromPassword([]byte(tempPassword), bcrypt.DefaultCost)
	if err != nil {
		return nil, fmt.Errorf("failed to hash password: %w", err)
	}

	// Set default account status if not provided
	accountStatus := req.AccountStatus
	if accountStatus == "" {
		accountStatus = models.AccountStatusActive
	}

	// Create user profile
	userID := uuid.New()
	var phone, identification, photoURL *string
	if req.Phone != "" {
		phone = &req.Phone
	}
	if req.Identification != "" {
		identification = &req.Identification
	}
	if req.PhotoURL != "" {
		photoURL = &req.PhotoURL
	}

	_, err = tx.Exec(ctx, `
		INSERT INTO user_profiles (
			user_id, email, password_hash, first_name, last_name, phone, 
			identification, photo_url, primary_role, is_active, account_status,
			failed_login_attempts, two_factor_enabled, created_at, updated_at
		) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, NOW(), NOW())
	`,
		userID, req.Email, string(hashedPassword), req.FirstName, req.LastName,
		phone, identification, photoURL, models.RoleCityAdmin, true, accountStatus,
		0, false,
	)
	if err != nil {
		if strings.Contains(err.Error(), "unique constraint") || strings.Contains(err.Error(), "duplicate key") {
			return nil, fmt.Errorf("email already exists: %s", req.Email)
		}
		return nil, fmt.Errorf("failed to create user profile: %w", err)
	}

	// Parse UUIDs for city and sport
	cityUUID, err := uuid.Parse(req.CityID)
	if err != nil {
		return nil, fmt.Errorf("invalid city ID format: %w", err)
	}

	sportUUID, err := uuid.Parse(req.SportID)
	if err != nil {
		return nil, fmt.Errorf("invalid sport ID format: %w", err)
	}

	// Create role assignment
	roleAssignmentID := uuid.New()
	_, err = tx.Exec(ctx, `
		INSERT INTO user_roles_by_city_sport (
			role_assignment_id, user_id, city_id, sport_id, role_name,
			assigned_by_user_id, is_active, created_at
		) VALUES ($1, $2, $3, $4, $5, $6, $7, NOW())
	`,
		roleAssignmentID, userID, cityUUID, sportUUID, models.RoleCityAdmin,
		registeredByUserID, true,
	)
	if err != nil {
		return nil, fmt.Errorf("failed to create role assignment: %w", err)
	}

	// Commit transaction
	if err := tx.Commit(ctx); err != nil {
		return nil, fmt.Errorf("failed to commit transaction: %w", err)
	}

	// Prepare response
	response := &models.AdminRegistrationResponse{
		UserID:            userID,
		FirstName:         req.FirstName,
		LastName:          req.LastName,
		Email:             req.Email,
		Phone:             phone,
		Identification:    identification,
		CityID:            cityUUID,
		SportID:           sportUUID,
		AccountStatus:     accountStatus,
		PhotoURL:          photoURL,
		RoleAssignmentID:  roleAssignmentID,
		TemporaryPassword: tempPassword, // Only for development - remove in production
		Message:           "Admin registered successfully. Temporary password sent via email.",
	}

	// Log successful registration
	s.securityValidator.LogSecurityEvent(ctx, "ADMIN_REGISTERED", "New admin successfully registered", map[string]interface{}{
		"admin_id":           userID,
		"admin_email":        req.Email,
		"registered_by":      registeredByUserID,
		"city_id":            cityUUID,
		"sport_id":           sportUUID,
		"role_assignment_id": roleAssignmentID,
	})

	// TODO: Send welcome email with temporary password
	// This will be implemented in task 9

	return response, nil
}

// ValidateEmailUniqueness checks if email is unique
func (s *AdminService) ValidateEmailUniqueness(ctx context.Context, email string) (*models.EmailValidationResponse, error) {
	// Validate email format
	if !s.isValidEmailFormat(email) {
		return &models.EmailValidationResponse{
			IsValid:  false,
			IsUnique: false,
			Message:  "Invalid email format",
		}, nil
	}

	// Check uniqueness
	var count int
	err := s.db.GetConnection().QueryRow(ctx,
		"SELECT COUNT(*) FROM user_profiles WHERE email = $1",
		email,
	).Scan(&count)
	if err != nil {
		return nil, fmt.Errorf("failed to check email uniqueness: %w", err)
	}

	isUnique := count == 0
	message := "Email is available"
	if !isUnique {
		message = "Email already exists"
	}

	return &models.EmailValidationResponse{
		IsValid:  true,
		IsUnique: isUnique,
		Message:  message,
	}, nil
}

// validateEmailUniqueness internal validation
func (s *AdminService) validateEmailUniqueness(ctx context.Context, email string) error {
	var count int
	err := s.db.GetConnection().QueryRow(ctx,
		"SELECT COUNT(*) FROM user_profiles WHERE email = $1",
		email,
	).Scan(&count)
	if err != nil {
		return fmt.Errorf("failed to check email uniqueness: %w", err)
	}

	if count > 0 {
		return fmt.Errorf("email already exists: %s", email)
	}

	return nil
}

// validateCityAndSport checks if city and sport exist
func (s *AdminService) validateCityAndSport(ctx context.Context, cityID, sportID string) error {
	// Validate city exists
	var cityCount int
	err := s.db.GetConnection().QueryRow(ctx,
		"SELECT COUNT(*) FROM cities WHERE city_id = $1",
		cityID,
	).Scan(&cityCount)
	if err != nil {
		return fmt.Errorf("failed to validate city: %w", err)
	}
	if cityCount == 0 {
		return fmt.Errorf("city not found: %s", cityID)
	}

	// Validate sport exists
	var sportCount int
	err = s.db.GetConnection().QueryRow(ctx,
		"SELECT COUNT(*) FROM sports WHERE sport_id = $1",
		sportID,
	).Scan(&sportCount)
	if err != nil {
		return fmt.Errorf("failed to validate sport: %w", err)
	}
	if sportCount == 0 {
		return fmt.Errorf("sport not found: %s", sportID)
	}

	return nil
}

// validateNoDuplicateAdmin checks if there's already an admin for this city/sport
func (s *AdminService) validateNoDuplicateAdmin(ctx context.Context, cityID, sportID string) error {
	var count int
	err := s.db.GetConnection().QueryRow(ctx, `
		SELECT COUNT(*) FROM user_roles_by_city_sport 
		WHERE city_id = $1 AND sport_id = $2 AND role_name = $3 AND is_active = true
	`, cityID, sportID, models.RoleCityAdmin).Scan(&count)

	if err != nil {
		return fmt.Errorf("failed to check duplicate admin: %w", err)
	}

	if count > 0 {
		return fmt.Errorf("admin already exists for this city and sport combination")
	}

	return nil
}

// generateTemporaryPassword creates a secure 12-character password
func (s *AdminService) generateTemporaryPassword() (string, error) {
	const (
		length  = 12
		upper   = "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
		lower   = "abcdefghijklmnopqrstuvwxyz"
		digits  = "0123456789"
		symbols = "!@#$%^&*"
	)

	// Ensure at least one character from each category
	password := make([]byte, 0, length)

	// Add one from each category
	categories := []string{upper, lower, digits, symbols}
	for _, category := range categories {
		char, err := s.randomChar(category)
		if err != nil {
			return "", err
		}
		password = append(password, char)
	}

	// Fill remaining positions with random characters from all categories
	allChars := upper + lower + digits + symbols
	for len(password) < length {
		char, err := s.randomChar(allChars)
		if err != nil {
			return "", err
		}
		password = append(password, char)
	}

	// Shuffle the password
	for i := len(password) - 1; i > 0; i-- {
		j, err := rand.Int(rand.Reader, big.NewInt(int64(i+1)))
		if err != nil {
			return "", err
		}
		password[i], password[j.Int64()] = password[j.Int64()], password[i]
	}

	return string(password), nil
}

// randomChar returns a random character from the given string
func (s *AdminService) randomChar(chars string) (byte, error) {
	n, err := rand.Int(rand.Reader, big.NewInt(int64(len(chars))))
	if err != nil {
		return 0, err
	}
	return chars[n.Int64()], nil
}

// isValidEmailFormat validates email format using RFC 5322 regex
func (s *AdminService) isValidEmailFormat(email string) bool {
	// Use the enhanced security validator
	return s.securityValidator.ValidateEmailRFC5322(email) == nil
}

// validateSecurityRequirements performs comprehensive security validation
func (s *AdminService) validateSecurityRequirements(ctx context.Context, req *models.AdminRegistrationRequest) error {
	// Validate email format (RFC 5322)
	if err := s.securityValidator.ValidateEmailRFC5322(req.Email); err != nil {
		return fmt.Errorf("email validation failed: %w", err)
	}

	// Validate international phone format
	if err := s.securityValidator.ValidateInternationalPhone(req.Phone); err != nil {
		return fmt.Errorf("phone validation failed: %w", err)
	}

	// Validate identification format (assuming Colombia as default)
	if err := s.securityValidator.ValidateIdentificationFormat(req.Identification, "CO"); err != nil {
		return fmt.Errorf("identification validation failed: %w", err)
	}

	// Validate UUID formats
	if err := s.securityValidator.IsValidUUID(req.CityID); err != nil {
		return fmt.Errorf("city ID validation failed: %w", err)
	}

	if err := s.securityValidator.IsValidUUID(req.SportID); err != nil {
		return fmt.Errorf("sport ID validation failed: %w", err)
	}

	// Sanitize all input fields
	req.FirstName = s.securityValidator.SanitizeInput(req.FirstName)
	req.LastName = s.securityValidator.SanitizeInput(req.LastName)
	req.Email = s.securityValidator.SanitizeInput(req.Email)
	req.Phone = s.securityValidator.SanitizeInput(req.Phone)
	req.Identification = s.securityValidator.SanitizeInput(req.Identification)
	req.PhotoURL = s.securityValidator.SanitizeInput(req.PhotoURL)

	// Detect suspicious patterns
	inputData := map[string]string{
		"first_name":     req.FirstName,
		"last_name":      req.LastName,
		"email":          req.Email,
		"phone":          req.Phone,
		"identification": req.Identification,
		"photo_url":      req.PhotoURL,
	}

	suspiciousFindings := s.securityValidator.DetectSuspiciousPatterns(inputData)
	if len(suspiciousFindings) > 0 {
		s.securityValidator.LogSecurityEvent(ctx, "SUSPICIOUS_PATTERNS_DETECTED", "Suspicious patterns detected in admin registration", map[string]interface{}{
			"email":    req.Email,
			"findings": suspiciousFindings,
		})
		return fmt.Errorf("suspicious patterns detected in input data")
	}

	// Validate allowed email domains (if configured)
	// In production, this could be loaded from configuration
	allowedDomains := []string{} // Empty means all domains allowed
	if err := s.securityValidator.ValidateAllowedEmailDomains(req.Email, allowedDomains); err != nil {
		return fmt.Errorf("email domain validation failed: %w", err)
	}

	return nil
}

// ValidateEmailUniquenessWithSecurity validates email uniqueness with security checks
func (s *AdminService) ValidateEmailUniquenessWithSecurity(ctx context.Context, email string) (*models.EmailValidationResponse, error) {
	// Rate limiting for email validation
	clientIP := s.securityValidator.GetClientIP(ctx)
	if err := s.securityValidator.CheckRateLimit(ctx, clientIP+":email_validation", 10, 1*time.Minute); err != nil {
		s.securityValidator.LogSecurityEvent(ctx, "EMAIL_VALIDATION_RATE_LIMIT", "Email validation rate limit exceeded", map[string]interface{}{
			"ip":    clientIP,
			"email": email,
		})
		return nil, fmt.Errorf("email validation rate limit exceeded")
	}

	// Validate email format with enhanced security
	if err := s.securityValidator.ValidateEmailRFC5322(email); err != nil {
		return &models.EmailValidationResponse{
			IsValid:  false,
			IsUnique: false,
			Message:  err.Error(),
		}, nil
	}

	// Sanitize email
	sanitizedEmail := s.securityValidator.SanitizeInput(email)

	// Check for suspicious patterns
	suspiciousFindings := s.securityValidator.DetectSuspiciousPatterns(map[string]string{"email": sanitizedEmail})
	if len(suspiciousFindings) > 0 {
		s.securityValidator.LogSecurityEvent(ctx, "SUSPICIOUS_EMAIL_VALIDATION", "Suspicious email validation attempt", map[string]interface{}{
			"email":    sanitizedEmail,
			"findings": suspiciousFindings,
		})
		return &models.EmailValidationResponse{
			IsValid:  false,
			IsUnique: false,
			Message:  "Invalid email format",
		}, nil
	}

	// Check uniqueness
	var count int
	err := s.db.GetConnection().QueryRow(ctx,
		"SELECT COUNT(*) FROM user_profiles WHERE email = $1",
		sanitizedEmail,
	).Scan(&count)
	if err != nil {
		return nil, fmt.Errorf("failed to check email uniqueness: %w", err)
	}

	isUnique := count == 0
	message := "Email is available"
	if !isUnique {
		message = "Email already exists"
	}

	return &models.EmailValidationResponse{
		IsValid:  true,
		IsUnique: isUnique,
		Message:  message,
	}, nil
}

// GetAdminList retrieves a paginated list of administrators with filtering and search
func (s *AdminService) GetAdminList(ctx context.Context, req *models.AdminListRequest) (*models.AdminListResponse, error) {
	// Set defaults
	if req.Page <= 0 {
		req.Page = 1
	}
	if req.Limit <= 0 {
		req.Limit = 20
	}
	if req.Limit > 100 {
		req.Limit = 100
	}
	if req.SortBy == "" {
		req.SortBy = "created_at"
	}
	if req.SortOrder == "" {
		req.SortOrder = "desc"
	}

	// Calculate offset
	offset := (req.Page - 1) * req.Limit

	// Build WHERE clause
	whereConditions := []string{"up.primary_role = $1"}
	args := []interface{}{models.RoleCityAdmin}
	argIndex := 2

	// Add search filter
	if req.Search != "" {
		searchPattern := "%" + strings.ToLower(req.Search) + "%"
		whereConditions = append(whereConditions, fmt.Sprintf("(LOWER(up.first_name) LIKE $%d OR LOWER(up.last_name) LIKE $%d OR LOWER(up.email) LIKE $%d)", argIndex, argIndex, argIndex))
		args = append(args, searchPattern)
		argIndex++
	}

	// Add city filter
	if req.CityID != "" {
		whereConditions = append(whereConditions, fmt.Sprintf("ur.city_id = $%d", argIndex))
		args = append(args, req.CityID)
		argIndex++
	}

	// Add sport filter
	if req.SportID != "" {
		whereConditions = append(whereConditions, fmt.Sprintf("ur.sport_id = $%d", argIndex))
		args = append(args, req.SportID)
		argIndex++
	}

	// Add status filter
	if req.Status != "" {
		whereConditions = append(whereConditions, fmt.Sprintf("up.account_status = $%d", argIndex))
		args = append(args, req.Status)
		argIndex++
	}

	whereClause := strings.Join(whereConditions, " AND ")

	// Build ORDER BY clause
	validSortFields := map[string]string{
		"first_name":    "up.first_name",
		"last_name":     "up.last_name",
		"email":         "up.email",
		"created_at":    "up.created_at",
		"last_login_at": "up.last_login_at",
	}

	sortField, exists := validSortFields[req.SortBy]
	if !exists {
		sortField = "up.created_at"
	}

	sortOrder := "DESC"
	if req.SortOrder == "asc" {
		sortOrder = "ASC"
	}

	// Count total records
	countQuery := fmt.Sprintf(`
		SELECT COUNT(DISTINCT up.user_id)
		FROM user_profiles up
		LEFT JOIN user_roles_by_city_sport ur ON up.user_id = ur.user_id AND ur.is_active = true
		WHERE %s
	`, whereClause)

	var total int
	err := s.db.GetConnection().QueryRow(ctx, countQuery, args...).Scan(&total)
	if err != nil {
		return nil, fmt.Errorf("failed to count admins: %w", err)
	}

	// Get paginated results
	query := fmt.Sprintf(`
		SELECT DISTINCT
			up.user_id,
			up.email,
			up.first_name,
			up.last_name,
			up.phone,
			up.photo_url,
			up.account_status,
			up.is_active,
			up.last_login_at,
			up.created_at,
			c.name as city_name,
			s.name as sport_name
		FROM user_profiles up
		LEFT JOIN user_roles_by_city_sport ur ON up.user_id = ur.user_id AND ur.is_active = true
		LEFT JOIN cities c ON ur.city_id = c.city_id
		LEFT JOIN sports s ON ur.sport_id = s.sport_id
		WHERE %s
		ORDER BY %s %s
		LIMIT $%d OFFSET $%d
	`, whereClause, sortField, sortOrder, argIndex, argIndex+1)

	args = append(args, req.Limit, offset)

	rows, err := s.db.GetConnection().Query(ctx, query, args...)
	if err != nil {
		return nil, fmt.Errorf("failed to query admins: %w", err)
	}
	defer rows.Close()

	var admins []models.AdminSummary
	for rows.Next() {
		var admin models.AdminSummary
		var cityName, sportName *string

		err := rows.Scan(
			&admin.UserID,
			&admin.Email,
			&admin.FirstName,
			&admin.LastName,
			&admin.Phone,
			&admin.PhotoURL,
			&admin.AccountStatus,
			&admin.IsActive,
			&admin.LastLoginAt,
			&admin.CreatedAt,
			&cityName,
			&sportName,
		)
		if err != nil {
			return nil, fmt.Errorf("failed to scan admin: %w", err)
		}

		admin.CityName = cityName
		admin.SportName = sportName
		admins = append(admins, admin)
	}

	if err := rows.Err(); err != nil {
		return nil, fmt.Errorf("error iterating over admin rows: %w", err)
	}

	// Calculate pagination info
	totalPages := (total + req.Limit - 1) / req.Limit
	hasNext := req.Page < totalPages
	hasPrev := req.Page > 1

	return &models.AdminListResponse{
		Admins:     admins,
		Total:      total,
		Page:       req.Page,
		Limit:      req.Limit,
		TotalPages: totalPages,
		HasNext:    hasNext,
		HasPrev:    hasPrev,
	}, nil
}
