package services

import (
	"context"
	"fmt"
	"mowesport/internal/database"
	"mowesport/internal/models"
	"strings"
	"time"

	"github.com/google/uuid"
)

type UserManagementService struct {
	db                *database.Database
	securityValidator *SecurityValidationService
	auditService      *SecurityAuditService
}

func NewUserManagementService(db *database.Database) *UserManagementService {
	return &UserManagementService{
		db:                db,
		securityValidator: NewSecurityValidationService(),
		auditService:      NewSecurityAuditService(db),
	}
}

// GetUserProfile retrieves a user profile by ID (admin only)
func (s *UserManagementService) GetUserProfile(ctx context.Context, userID uuid.UUID, requestedBy uuid.UUID) (*models.UserProfile, error) {
	// Validate requester has admin permissions
	if err := s.validateAdminPermissions(ctx, requestedBy); err != nil {
		return nil, err
	}

	var user models.UserProfile
	err := s.db.GetConnection().QueryRow(ctx, `
		SELECT user_id, email, first_name, last_name, phone, identification, 
		       photo_url, primary_role, is_active, account_status, last_login_at,
		       failed_login_attempts, locked_until, two_factor_enabled, 
		       created_at, updated_at
		FROM user_profiles 
		WHERE user_id = $1
	`, userID).Scan(
		&user.UserID, &user.Email, &user.FirstName, &user.LastName,
		&user.Phone, &user.Identification, &user.PhotoURL, &user.PrimaryRole,
		&user.IsActive, &user.AccountStatus, &user.LastLoginAt,
		&user.FailedLoginAttempts, &user.LockedUntil, &user.TwoFactorEnabled,
		&user.CreatedAt, &user.UpdatedAt,
	)

	if err != nil {
		return nil, fmt.Errorf("user not found: %w", err)
	}

	// Log access for audit
	s.auditService.LogSecurityEvent(ctx, SecurityEvent{
		EventType:   "USER_PROFILE_ACCESSED",
		Description: fmt.Sprintf("User profile accessed by admin %s", requestedBy),
		UserID:      &userID,
		IPAddress:   s.securityValidator.GetClientIP(ctx),
		Metadata: map[string]interface{}{
			"accessed_user_id": userID,
			"accessed_by":      requestedBy,
		},
		Timestamp: time.Now(),
	})

	return &user, nil
}

// UpdateUserProfile updates a user profile (admin only)
func (s *UserManagementService) UpdateUserProfile(ctx context.Context, userID uuid.UUID, req *models.UserUpdateRequest, updatedBy uuid.UUID) (*models.UserProfile, error) {
	// Validate requester has admin permissions
	if err := s.validateAdminPermissions(ctx, updatedBy); err != nil {
		return nil, err
	}

	// Validate and sanitize input
	if err := s.validateUserUpdateRequest(req); err != nil {
		return nil, err
	}

	// Start transaction
	tx, err := s.db.GetConnection().Begin(ctx)
	if err != nil {
		return nil, fmt.Errorf("failed to start transaction: %w", err)
	}
	defer tx.Rollback(ctx)

	// Build dynamic update query
	setParts := []string{"updated_at = NOW()"}
	args := []interface{}{}
	argIndex := 1

	if req.FirstName != nil {
		setParts = append(setParts, fmt.Sprintf("first_name = $%d", argIndex))
		args = append(args, s.securityValidator.SanitizeInput(*req.FirstName))
		argIndex++
	}

	if req.LastName != nil {
		setParts = append(setParts, fmt.Sprintf("last_name = $%d", argIndex))
		args = append(args, s.securityValidator.SanitizeInput(*req.LastName))
		argIndex++
	}

	if req.Phone != nil {
		if err := s.securityValidator.ValidateInternationalPhone(*req.Phone); err != nil {
			return nil, fmt.Errorf("invalid phone format: %w", err)
		}
		setParts = append(setParts, fmt.Sprintf("phone = $%d", argIndex))
		args = append(args, req.Phone)
		argIndex++
	}

	if req.Identification != nil {
		if err := s.securityValidator.ValidateIdentificationFormat(*req.Identification, "CO"); err != nil {
			return nil, fmt.Errorf("invalid identification format: %w", err)
		}
		setParts = append(setParts, fmt.Sprintf("identification = $%d", argIndex))
		args = append(args, req.Identification)
		argIndex++
	}

	if req.PhotoURL != nil {
		setParts = append(setParts, fmt.Sprintf("photo_url = $%d", argIndex))
		args = append(args, req.PhotoURL)
		argIndex++
	}

	if req.IsActive != nil {
		setParts = append(setParts, fmt.Sprintf("is_active = $%d", argIndex))
		args = append(args, *req.IsActive)
		argIndex++
	}

	if req.AccountStatus != nil {
		setParts = append(setParts, fmt.Sprintf("account_status = $%d", argIndex))
		args = append(args, *req.AccountStatus)
		argIndex++
	}

	// Add userID as the last parameter for WHERE clause
	args = append(args, userID)
	whereIndex := argIndex

	query := fmt.Sprintf(`
		UPDATE user_profiles 
		SET %s 
		WHERE user_id = $%d
		RETURNING user_id, email, first_name, last_name, phone, identification,
		          photo_url, primary_role, is_active, account_status, last_login_at,
		          failed_login_attempts, locked_until, two_factor_enabled,
		          created_at, updated_at
	`, strings.Join(setParts, ", "), whereIndex)

	var updatedUser models.UserProfile
	err = tx.QueryRow(ctx, query, args...).Scan(
		&updatedUser.UserID, &updatedUser.Email, &updatedUser.FirstName, &updatedUser.LastName,
		&updatedUser.Phone, &updatedUser.Identification, &updatedUser.PhotoURL, &updatedUser.PrimaryRole,
		&updatedUser.IsActive, &updatedUser.AccountStatus, &updatedUser.LastLoginAt,
		&updatedUser.FailedLoginAttempts, &updatedUser.LockedUntil, &updatedUser.TwoFactorEnabled,
		&updatedUser.CreatedAt, &updatedUser.UpdatedAt,
	)

	if err != nil {
		return nil, fmt.Errorf("failed to update user profile: %w", err)
	}

	// Commit transaction
	if err := tx.Commit(ctx); err != nil {
		return nil, fmt.Errorf("failed to commit transaction: %w", err)
	}

	// Log update for audit
	s.auditService.LogSecurityEvent(ctx, SecurityEvent{
		EventType:   "USER_PROFILE_UPDATED",
		Description: fmt.Sprintf("User profile updated by admin %s", updatedBy),
		UserID:      &userID,
		IPAddress:   s.securityValidator.GetClientIP(ctx),
		Metadata: map[string]interface{}{
			"updated_user_id": userID,
			"updated_by":      updatedBy,
			"changes":         req,
		},
		Timestamp: time.Now(),
	})

	return &updatedUser, nil
}

// AssignUserRole assigns a role to a user for a specific city/sport
func (s *UserManagementService) AssignUserRole(ctx context.Context, req *models.RoleAssignmentRequest, assignedBy uuid.UUID) (*models.UserRoleByCitySport, error) {
	// Validate requester has admin permissions
	if err := s.validateAdminPermissions(ctx, assignedBy); err != nil {
		return nil, err
	}

	// Validate request
	if err := s.validateRoleAssignmentRequest(req); err != nil {
		return nil, err
	}

	// Start transaction
	tx, err := s.db.GetConnection().Begin(ctx)
	if err != nil {
		return nil, fmt.Errorf("failed to start transaction: %w", err)
	}
	defer tx.Rollback(ctx)

	// Check if user exists
	var userExists bool
	err = tx.QueryRow(ctx, "SELECT EXISTS(SELECT 1 FROM user_profiles WHERE user_id = $1)", req.UserID).Scan(&userExists)
	if err != nil {
		return nil, fmt.Errorf("failed to check user existence: %w", err)
	}
	if !userExists {
		return nil, fmt.Errorf("user not found")
	}

	// Check if city and sport exist (if provided)
	if req.CityID != nil {
		var cityExists bool
		err = tx.QueryRow(ctx, "SELECT EXISTS(SELECT 1 FROM cities WHERE city_id = $1)", *req.CityID).Scan(&cityExists)
		if err != nil {
			return nil, fmt.Errorf("failed to check city existence: %w", err)
		}
		if !cityExists {
			return nil, fmt.Errorf("city not found")
		}
	}

	if req.SportID != nil {
		var sportExists bool
		err = tx.QueryRow(ctx, "SELECT EXISTS(SELECT 1 FROM sports WHERE sport_id = $1)", *req.SportID).Scan(&sportExists)
		if err != nil {
			return nil, fmt.Errorf("failed to check sport existence: %w", err)
		}
		if !sportExists {
			return nil, fmt.Errorf("sport not found")
		}
	}

	// Check for existing role assignment
	var existingCount int
	err = tx.QueryRow(ctx, `
		SELECT COUNT(*) FROM user_roles_by_city_sport 
		WHERE user_id = $1 AND city_id = $2 AND sport_id = $3 AND role_name = $4 AND is_active = true
	`, req.UserID, req.CityID, req.SportID, req.RoleName).Scan(&existingCount)

	if err != nil {
		return nil, fmt.Errorf("failed to check existing role: %w", err)
	}
	if existingCount > 0 {
		return nil, fmt.Errorf("user already has this role for the specified city/sport")
	}

	// Create role assignment
	roleAssignmentID := uuid.New()
	var roleAssignment models.UserRoleByCitySport

	err = tx.QueryRow(ctx, `
		INSERT INTO user_roles_by_city_sport (
			role_assignment_id, user_id, city_id, sport_id, role_name,
			assigned_by_user_id, is_active, created_at
		) VALUES ($1, $2, $3, $4, $5, $6, $7, NOW())
		RETURNING role_assignment_id, user_id, city_id, sport_id, role_name,
		          assigned_by_user_id, is_active, created_at
	`, roleAssignmentID, req.UserID, req.CityID, req.SportID, req.RoleName, assignedBy, true).Scan(
		&roleAssignment.RoleAssignmentID, &roleAssignment.UserID, &roleAssignment.CityID,
		&roleAssignment.SportID, &roleAssignment.RoleName, &roleAssignment.AssignedByUserID,
		&roleAssignment.IsActive, &roleAssignment.CreatedAt,
	)

	if err != nil {
		return nil, fmt.Errorf("failed to create role assignment: %w", err)
	}

	// Commit transaction
	if err := tx.Commit(ctx); err != nil {
		return nil, fmt.Errorf("failed to commit transaction: %w", err)
	}

	// Log role assignment for audit
	s.auditService.LogSecurityEvent(ctx, SecurityEvent{
		EventType:   "ROLE_ASSIGNED",
		Description: fmt.Sprintf("Role %s assigned to user %s by admin %s", req.RoleName, req.UserID, assignedBy),
		UserID:      &req.UserID,
		IPAddress:   s.securityValidator.GetClientIP(ctx),
		Metadata: map[string]interface{}{
			"role_assignment_id": roleAssignmentID,
			"assigned_user_id":   req.UserID,
			"assigned_by":        assignedBy,
			"role_name":          req.RoleName,
			"city_id":            req.CityID,
			"sport_id":           req.SportID,
		},
		Timestamp: time.Now(),
	})

	return &roleAssignment, nil
}

// RevokeUserRole revokes a role from a user
func (s *UserManagementService) RevokeUserRole(ctx context.Context, roleAssignmentID uuid.UUID, revokedBy uuid.UUID) error {
	// Validate requester has admin permissions
	if err := s.validateAdminPermissions(ctx, revokedBy); err != nil {
		return err
	}

	// Start transaction
	tx, err := s.db.GetConnection().Begin(ctx)
	if err != nil {
		return fmt.Errorf("failed to start transaction: %w", err)
	}
	defer tx.Rollback(ctx)

	// Get role assignment details for audit
	var roleAssignment models.UserRoleByCitySport
	err = tx.QueryRow(ctx, `
		SELECT role_assignment_id, user_id, city_id, sport_id, role_name, is_active
		FROM user_roles_by_city_sport 
		WHERE role_assignment_id = $1
	`, roleAssignmentID).Scan(
		&roleAssignment.RoleAssignmentID, &roleAssignment.UserID, &roleAssignment.CityID,
		&roleAssignment.SportID, &roleAssignment.RoleName, &roleAssignment.IsActive,
	)

	if err != nil {
		return fmt.Errorf("role assignment not found: %w", err)
	}

	if !roleAssignment.IsActive {
		return fmt.Errorf("role assignment is already inactive")
	}

	// Deactivate role assignment
	_, err = tx.Exec(ctx, `
		UPDATE user_roles_by_city_sport 
		SET is_active = false 
		WHERE role_assignment_id = $1
	`, roleAssignmentID)

	if err != nil {
		return fmt.Errorf("failed to revoke role: %w", err)
	}

	// Commit transaction
	if err := tx.Commit(ctx); err != nil {
		return fmt.Errorf("failed to commit transaction: %w", err)
	}

	// Log role revocation for audit
	s.auditService.LogSecurityEvent(ctx, SecurityEvent{
		EventType:   "ROLE_REVOKED",
		Description: fmt.Sprintf("Role %s revoked from user %s by admin %s", roleAssignment.RoleName, roleAssignment.UserID, revokedBy),
		UserID:      &roleAssignment.UserID,
		IPAddress:   s.securityValidator.GetClientIP(ctx),
		Metadata: map[string]interface{}{
			"role_assignment_id": roleAssignmentID,
			"revoked_user_id":    roleAssignment.UserID,
			"revoked_by":         revokedBy,
			"role_name":          roleAssignment.RoleName,
			"city_id":            roleAssignment.CityID,
			"sport_id":           roleAssignment.SportID,
		},
		Timestamp: time.Now(),
	})

	return nil
}

// GetUserRoles retrieves all roles for a user
func (s *UserManagementService) GetUserRoles(ctx context.Context, userID uuid.UUID, requestedBy uuid.UUID) ([]models.UserRoleByCitySport, error) {
	// Validate requester has admin permissions
	if err := s.validateAdminPermissions(ctx, requestedBy); err != nil {
		return nil, err
	}

	rows, err := s.db.GetConnection().Query(ctx, `
		SELECT ur.role_assignment_id, ur.user_id, ur.city_id, ur.sport_id, 
		       ur.role_name, ur.assigned_by_user_id, ur.is_active, ur.created_at
		FROM user_roles_by_city_sport ur
		WHERE ur.user_id = $1
		ORDER BY ur.created_at DESC
	`, userID)

	if err != nil {
		return nil, fmt.Errorf("failed to query user roles: %w", err)
	}
	defer rows.Close()

	var roles []models.UserRoleByCitySport
	for rows.Next() {
		var role models.UserRoleByCitySport
		err := rows.Scan(
			&role.RoleAssignmentID, &role.UserID, &role.CityID, &role.SportID,
			&role.RoleName, &role.AssignedByUserID, &role.IsActive, &role.CreatedAt,
		)
		if err != nil {
			return nil, fmt.Errorf("failed to scan role: %w", err)
		}
		roles = append(roles, role)
	}

	if err := rows.Err(); err != nil {
		return nil, fmt.Errorf("error iterating over roles: %w", err)
	}

	return roles, nil
}

// SetViewPermission sets view permission for a user or role
func (s *UserManagementService) SetViewPermission(ctx context.Context, req *models.ViewPermissionRequest, configuredBy uuid.UUID) (*models.UserViewPermission, error) {
	// Validate requester has super admin permissions
	if err := s.validateSuperAdminPermissions(ctx, configuredBy); err != nil {
		return nil, err
	}

	// Validate request
	if err := s.validateViewPermissionRequest(req); err != nil {
		return nil, err
	}

	// Start transaction
	tx, err := s.db.GetConnection().Begin(ctx)
	if err != nil {
		return nil, fmt.Errorf("failed to start transaction: %w", err)
	}
	defer tx.Rollback(ctx)

	// Check for existing permission
	var existingPermissionID *uuid.UUID
	err = tx.QueryRow(ctx, `
		SELECT permission_id FROM user_view_permissions 
		WHERE (user_id = $1 OR role_name = $2) AND view_name = $3
	`, req.UserID, req.RoleName, req.ViewName).Scan(&existingPermissionID)

	var permission models.UserViewPermission
	permissionID := uuid.New()

	if existingPermissionID != nil {
		// Update existing permission
		err = tx.QueryRow(ctx, `
			UPDATE user_view_permissions 
			SET is_allowed = $1, configured_by_user_id = $2, updated_at = NOW()
			WHERE permission_id = $3
			RETURNING permission_id, user_id, role_name, view_name, is_allowed,
			          configured_by_user_id, created_at, updated_at
		`, req.IsAllowed, configuredBy, *existingPermissionID).Scan(
			&permission.PermissionID, &permission.UserID, &permission.RoleName,
			&permission.ViewName, &permission.IsAllowed, &permission.ConfiguredByUserID,
			&permission.CreatedAt, &permission.UpdatedAt,
		)
	} else {
		// Create new permission
		err = tx.QueryRow(ctx, `
			INSERT INTO user_view_permissions (
				permission_id, user_id, role_name, view_name, is_allowed,
				configured_by_user_id, created_at, updated_at
			) VALUES ($1, $2, $3, $4, $5, $6, NOW(), NOW())
			RETURNING permission_id, user_id, role_name, view_name, is_allowed,
			          configured_by_user_id, created_at, updated_at
		`, permissionID, req.UserID, req.RoleName, req.ViewName, req.IsAllowed, configuredBy).Scan(
			&permission.PermissionID, &permission.UserID, &permission.RoleName,
			&permission.ViewName, &permission.IsAllowed, &permission.ConfiguredByUserID,
			&permission.CreatedAt, &permission.UpdatedAt,
		)
	}

	if err != nil {
		return nil, fmt.Errorf("failed to set view permission: %w", err)
	}

	// Commit transaction
	if err := tx.Commit(ctx); err != nil {
		return nil, fmt.Errorf("failed to commit transaction: %w", err)
	}

	// Log permission change for audit
	s.auditService.LogSecurityEvent(ctx, SecurityEvent{
		EventType:   "VIEW_PERMISSION_SET",
		Description: fmt.Sprintf("View permission set for %s by super admin %s", req.ViewName, configuredBy),
		UserID:      req.UserID,
		IPAddress:   s.securityValidator.GetClientIP(ctx),
		Metadata: map[string]interface{}{
			"permission_id": permission.PermissionID,
			"configured_by": configuredBy,
			"user_id":       req.UserID,
			"role_name":     req.RoleName,
			"view_name":     req.ViewName,
			"is_allowed":    req.IsAllowed,
		},
		Timestamp: time.Now(),
	})

	return &permission, nil
}

// UpdateAccountStatus updates a user's account status
func (s *UserManagementService) UpdateAccountStatus(ctx context.Context, userID uuid.UUID, status string, reason string, updatedBy uuid.UUID) error {
	// Validate requester has admin permissions
	if err := s.validateAdminPermissions(ctx, updatedBy); err != nil {
		return err
	}

	// Validate status
	validStatuses := []string{
		models.AccountStatusActive,
		models.AccountStatusSuspended,
		models.AccountStatusPaymentPending,
		models.AccountStatusDisabled,
	}

	isValidStatus := false
	for _, validStatus := range validStatuses {
		if status == validStatus {
			isValidStatus = true
			break
		}
	}

	if !isValidStatus {
		return fmt.Errorf("invalid account status: %s", status)
	}

	// Update account status
	result, err := s.db.GetConnection().Exec(ctx, `
		UPDATE user_profiles 
		SET account_status = $1, updated_at = NOW()
		WHERE user_id = $2
	`, status, userID)

	if err != nil {
		return fmt.Errorf("failed to update account status: %w", err)
	}

	rowsAffected := result.RowsAffected()
	if rowsAffected == 0 {
		return fmt.Errorf("user not found")
	}

	// Log status change for audit
	s.auditService.LogSecurityEvent(ctx, SecurityEvent{
		EventType:   "ACCOUNT_STATUS_CHANGED",
		Description: fmt.Sprintf("Account status changed to %s by admin %s", status, updatedBy),
		UserID:      &userID,
		IPAddress:   s.securityValidator.GetClientIP(ctx),
		Metadata: map[string]interface{}{
			"updated_user_id": userID,
			"updated_by":      updatedBy,
			"new_status":      status,
			"reason":          reason,
		},
		Timestamp: time.Now(),
	})

	return nil
}

// Helper methods

func (s *UserManagementService) validateAdminPermissions(ctx context.Context, userID uuid.UUID) error {
	var role string
	err := s.db.GetConnection().QueryRow(ctx,
		"SELECT primary_role FROM user_profiles WHERE user_id = $1 AND is_active = true",
		userID,
	).Scan(&role)

	if err != nil {
		return fmt.Errorf("user not found or inactive: %w", err)
	}

	if role != models.RoleSuperAdmin && role != models.RoleCityAdmin {
		return fmt.Errorf("insufficient permissions: admin role required")
	}

	return nil
}

func (s *UserManagementService) validateSuperAdminPermissions(ctx context.Context, userID uuid.UUID) error {
	var role string
	err := s.db.GetConnection().QueryRow(ctx,
		"SELECT primary_role FROM user_profiles WHERE user_id = $1 AND is_active = true",
		userID,
	).Scan(&role)

	if err != nil {
		return fmt.Errorf("user not found or inactive: %w", err)
	}

	if role != models.RoleSuperAdmin {
		return fmt.Errorf("insufficient permissions: super admin role required")
	}

	return nil
}

func (s *UserManagementService) validateUserUpdateRequest(req *models.UserUpdateRequest) error {
	if req.FirstName != nil && strings.TrimSpace(*req.FirstName) == "" {
		return fmt.Errorf("first name cannot be empty")
	}

	if req.LastName != nil && strings.TrimSpace(*req.LastName) == "" {
		return fmt.Errorf("last name cannot be empty")
	}

	if req.AccountStatus != nil {
		validStatuses := []string{
			models.AccountStatusActive,
			models.AccountStatusSuspended,
			models.AccountStatusPaymentPending,
			models.AccountStatusDisabled,
		}

		isValid := false
		for _, status := range validStatuses {
			if *req.AccountStatus == status {
				isValid = true
				break
			}
		}

		if !isValid {
			return fmt.Errorf("invalid account status")
		}
	}

	return nil
}

func (s *UserManagementService) validateRoleAssignmentRequest(req *models.RoleAssignmentRequest) error {
	if req.UserID == uuid.Nil {
		return fmt.Errorf("user ID is required")
	}

	if req.RoleName == "" {
		return fmt.Errorf("role name is required")
	}

	// Validate role name
	validRoles := []string{
		models.RoleCityAdmin,
		models.RoleTournamentAdmin,
		models.RoleOwner,
		models.RoleCoach,
		models.RoleReferee,
		models.RolePlayer,
		models.RoleClient,
	}

	isValidRole := false
	for _, role := range validRoles {
		if req.RoleName == role {
			isValidRole = true
			break
		}
	}

	if !isValidRole {
		return fmt.Errorf("invalid role name: %s", req.RoleName)
	}

	return nil
}

func (s *UserManagementService) validateViewPermissionRequest(req *models.ViewPermissionRequest) error {
	if req.UserID == nil && req.RoleName == nil {
		return fmt.Errorf("either user_id or role_name must be provided")
	}

	if req.UserID != nil && req.RoleName != nil {
		return fmt.Errorf("cannot specify both user_id and role_name")
	}

	if req.ViewName == "" {
		return fmt.Errorf("view name is required")
	}

	return nil
}

// GetUserList retrieves a paginated list of users (admin only)
func (s *UserManagementService) GetUserList(ctx context.Context, req *models.UserListRequest, requestedBy uuid.UUID) (*models.UserListResponse, error) {
	// Validate requester has admin permissions
	if err := s.validateAdminPermissions(ctx, requestedBy); err != nil {
		return nil, err
	}

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
	whereConditions := []string{"1=1"} // Always true condition to simplify building
	args := []interface{}{}
	argIndex := 1

	// Add search filter
	if req.Search != "" {
		searchPattern := "%" + strings.ToLower(req.Search) + "%"
		whereConditions = append(whereConditions, fmt.Sprintf("(LOWER(first_name) LIKE $%d OR LOWER(last_name) LIKE $%d OR LOWER(email) LIKE $%d)", argIndex, argIndex, argIndex))
		args = append(args, searchPattern)
		argIndex++
	}

	// Add role filter
	if req.Role != "" {
		whereConditions = append(whereConditions, fmt.Sprintf("primary_role = $%d", argIndex))
		args = append(args, req.Role)
		argIndex++
	}

	// Add account status filter
	if req.AccountStatus != "" {
		whereConditions = append(whereConditions, fmt.Sprintf("account_status = $%d", argIndex))
		args = append(args, req.AccountStatus)
		argIndex++
	}

	// Add is_active filter
	if req.IsActive != nil {
		whereConditions = append(whereConditions, fmt.Sprintf("is_active = $%d", argIndex))
		args = append(args, *req.IsActive)
		argIndex++
	}

	whereClause := strings.Join(whereConditions, " AND ")

	// Build ORDER BY clause
	validSortFields := map[string]string{
		"first_name":    "first_name",
		"last_name":     "last_name",
		"email":         "email",
		"primary_role":  "primary_role",
		"created_at":    "created_at",
		"last_login_at": "last_login_at",
	}

	sortField, exists := validSortFields[req.SortBy]
	if !exists {
		sortField = "created_at"
	}

	sortOrder := "DESC"
	if req.SortOrder == "asc" {
		sortOrder = "ASC"
	}

	// Count total records
	countQuery := fmt.Sprintf(`
		SELECT COUNT(*)
		FROM user_profiles
		WHERE %s
	`, whereClause)

	var total int
	err := s.db.GetConnection().QueryRow(ctx, countQuery, args...).Scan(&total)
	if err != nil {
		return nil, fmt.Errorf("failed to count users: %w", err)
	}

	// Get paginated results
	query := fmt.Sprintf(`
		SELECT user_id, email, first_name, last_name, phone, photo_url,
		       primary_role, account_status, is_active, last_login_at, created_at
		FROM user_profiles
		WHERE %s
		ORDER BY %s %s
		LIMIT $%d OFFSET $%d
	`, whereClause, sortField, sortOrder, argIndex, argIndex+1)

	args = append(args, req.Limit, offset)

	rows, err := s.db.GetConnection().Query(ctx, query, args...)
	if err != nil {
		return nil, fmt.Errorf("failed to query users: %w", err)
	}
	defer rows.Close()

	var users []models.UserSummary
	for rows.Next() {
		var user models.UserSummary
		err := rows.Scan(
			&user.UserID,
			&user.Email,
			&user.FirstName,
			&user.LastName,
			&user.Phone,
			&user.PhotoURL,
			&user.PrimaryRole,
			&user.AccountStatus,
			&user.IsActive,
			&user.LastLoginAt,
			&user.CreatedAt,
		)
		if err != nil {
			return nil, fmt.Errorf("failed to scan user: %w", err)
		}
		users = append(users, user)
	}

	if err := rows.Err(); err != nil {
		return nil, fmt.Errorf("error iterating over user rows: %w", err)
	}

	// Calculate pagination info
	totalPages := (total + req.Limit - 1) / req.Limit
	hasNext := req.Page < totalPages
	hasPrev := req.Page > 1

	return &models.UserListResponse{
		Users:      users,
		Total:      total,
		Page:       req.Page,
		Limit:      req.Limit,
		TotalPages: totalPages,
		HasNext:    hasNext,
		HasPrev:    hasPrev,
	}, nil
}

// GetDB returns the database connection for use in handlers
func (s *UserManagementService) GetDB() *database.Database {
	return s.db
}
