# Authentication System Documentation

## Overview

The Mowe Sport platform implements a comprehensive authentication system with the following features:

- JWT-based authentication with access and refresh tokens
- Two-Factor Authentication (2FA) using TOTP
- Password recovery system
- Progressive account locking for failed login attempts
- Role-based access control (RBAC)
- Account status management

## Authentication Endpoints

### Public Endpoints

#### POST /api/auth/login
Authenticates a user and returns JWT tokens.

**Request Body:**
```json
{
  "email": "user@example.com",
  "password": "userpassword",
  "two_factor_code": "123456" // Optional, required if 2FA is enabled
}
```

**Response:**
```json
{
  "success": true,
  "data": {
    "user_id": "uuid",
    "email": "user@example.com",
    "first_name": "John",
    "last_name": "Doe",
    "primary_role": "city_admin",
    "token": "jwt_access_token",
    "refresh_token": "jwt_refresh_token",
    "expires_in": 3600
  }
}
```

**Error Responses:**
- `USER_NOT_FOUND`: User doesn't exist
- `INVALID_CREDENTIALS`: Wrong password
- `ACCOUNT_INACTIVE`: Account is deactivated
- `ACCOUNT_LOCKED`: Account locked due to failed attempts
- `ACCOUNT_SUSPENDED`: Account is suspended
- `TWO_FACTOR_REQUIRED`: 2FA code needed
- `INVALID_TWO_FACTOR_CODE`: Wrong 2FA code

#### POST /api/auth/refresh
Generates a new access token using a refresh token.

**Request Body:**
```json
{
  "refresh_token": "jwt_refresh_token"
}
```

**Response:**
```json
{
  "success": true,
  "data": {
    "user_id": "uuid",
    "email": "user@example.com",
    "first_name": "John",
    "last_name": "Doe",
    "primary_role": "city_admin",
    "token": "new_jwt_access_token",
    "expires_in": 3600
  }
}
```

#### POST /api/auth/forgot-password
Initiates password recovery process.

**Request Body:**
```json
{
  "email": "user@example.com"
}
```

**Response:**
```json
{
  "success": true,
  "message": "If the email exists, a recovery link has been sent"
}
```

#### POST /api/auth/reset-password
Resets password using recovery token.

**Request Body:**
```json
{
  "token": "recovery_token",
  "new_password": "newpassword123"
}
```

**Response:**
```json
{
  "success": true,
  "message": "Password reset successfully"
}
```

### Protected Endpoints (Require Authentication)

#### POST /api/auth/logout
Logs out the current user.

**Headers:**
```
Authorization: Bearer jwt_access_token
```

**Response:**
```json
{
  "success": true,
  "message": "Logged out successfully"
}
```

#### POST /api/auth/2fa/setup
Sets up 2FA for the current user.

**Headers:**
```
Authorization: Bearer jwt_access_token
```

**Response:**
```json
{
  "success": true,
  "data": {
    "secret": "base32_secret",
    "qr_code": "otpauth://totp/MoweSport:user@example.com?secret=SECRET&issuer=MoweSport"
  }
}
```

#### POST /api/auth/2fa/verify
Verifies 2FA code and enables 2FA.

**Headers:**
```
Authorization: Bearer jwt_access_token
```

**Request Body:**
```json
{
  "code": "123456"
}
```

**Response:**
```json
{
  "success": true,
  "message": "2FA enabled successfully"
}
```

#### POST /api/auth/2fa/disable
Disables 2FA for the current user.

**Headers:**
```
Authorization: Bearer jwt_access_token
```

**Request Body:**
```json
{
  "code": "123456"
}
```

**Response:**
```json
{
  "success": true,
  "message": "2FA disabled successfully"
}
```

## JWT Token Structure

### Access Token
- **Type**: `access`
- **Expiration**: 1 hour (configurable)
- **Claims**:
  - `user_id`: User UUID
  - `email`: User email
  - `first_name`: User first name
  - `last_name`: User last name
  - `primary_role`: User's primary role
  - `type`: Token type ("access")
  - `exp`: Expiration timestamp
  - `iat`: Issued at timestamp

### Refresh Token
- **Type**: `refresh`
- **Expiration**: 7 days (configurable)
- **Claims**:
  - `user_id`: User UUID
  - `type`: Token type ("refresh")
  - `exp`: Expiration timestamp
  - `iat`: Issued at timestamp

## Security Features

### Progressive Account Locking
- **5 failed attempts**: Account locked for 15 minutes
- **10 failed attempts**: Account locked for 24 hours
- Successful login resets failed attempt counter

### Account Status Management
- `active`: Normal account status
- `suspended`: Account suspended by admin
- `payment_pending`: Account requires payment
- `disabled`: Account disabled

### Two-Factor Authentication
- Uses TOTP (Time-based One-Time Password)
- Compatible with Google Authenticator, Authy, etc.
- Required for Super Admin and City Admin roles
- Optional for other roles

### Password Recovery
- Recovery tokens expire in 10 minutes
- Tokens are single-use
- Secure random token generation

## Role-Based Access Control

### Roles
- `super_admin`: Full system access
- `city_admin`: City-specific administration
- `tournament_admin`: Tournament management
- `owner`: Team ownership
- `coach`: Team coaching
- `referee`: Match officiating
- `player`: Player access
- `client`: Public user access

### Middleware
- `RequireSuperAdminRole()`: Super admin only
- `RequireAdminRole()`: Super admin or city admin
- `RequireOwnerRole()`: Super admin, city admin, or owner
- `RequireRole(roles...)`: Custom role requirements

## Configuration

### Environment Variables
```bash
# JWT Configuration
JWT_SECRET=your-secret-key-here
JWT_ACCESS_EXPIRATION=1h
JWT_REFRESH_EXPIRATION=168h

# Server Configuration
SERVER_PORT=8080

# Database Configuration
DATABASE_URL=postgresql://user:password@localhost/mowesport
```

### Security Configuration
The system includes comprehensive security validation:
- Email format validation (RFC 5322)
- International phone number validation
- Identification format validation
- Input sanitization
- Suspicious pattern detection
- Rate limiting
- Audit logging

## Usage Examples

### Basic Login Flow
```javascript
// 1. Login
const loginResponse = await fetch('/api/auth/login', {
  method: 'POST',
  headers: { 'Content-Type': 'application/json' },
  body: JSON.stringify({
    email: 'admin@example.com',
    password: 'password123'
  })
});

const { data } = await loginResponse.json();
const { token, refresh_token } = data;

// 2. Use access token for protected requests
const protectedResponse = await fetch('/api/admin/list', {
  headers: { 'Authorization': `Bearer ${token}` }
});

// 3. Refresh token when access token expires
const refreshResponse = await fetch('/api/auth/refresh', {
  method: 'POST',
  headers: { 'Content-Type': 'application/json' },
  body: JSON.stringify({ refresh_token })
});
```

### 2FA Setup Flow
```javascript
// 1. Setup 2FA
const setupResponse = await fetch('/api/auth/2fa/setup', {
  method: 'POST',
  headers: { 'Authorization': `Bearer ${token}` }
});

const { secret, qr_code } = await setupResponse.json();

// 2. Show QR code to user, get code from authenticator app
const userCode = '123456'; // From authenticator app

// 3. Verify and enable 2FA
const verifyResponse = await fetch('/api/auth/2fa/verify', {
  method: 'POST',
  headers: { 
    'Authorization': `Bearer ${token}`,
    'Content-Type': 'application/json'
  },
  body: JSON.stringify({ code: userCode })
});
```

## Error Handling

All authentication endpoints return consistent error responses:

```json
{
  "success": false,
  "error": {
    "code": "ERROR_CODE",
    "message": "Human readable error message",
    "details": {} // Optional additional details
  }
}
```

Common error codes:
- `INVALID_REQUEST_BODY`: Malformed request
- `VALIDATION_ERROR`: Input validation failed
- `AUTHENTICATION_ERROR`: General auth failure
- `INSUFFICIENT_PERMISSIONS`: Role-based access denied
- `RATE_LIMIT_EXCEEDED`: Too many requests

## Testing

The authentication system can be tested using the provided endpoints. Ensure you have:

1. A valid database connection
2. Proper environment variables set
3. Test user accounts created

Example test sequence:
1. Create test user via admin registration
2. Test login with valid/invalid credentials
3. Test 2FA setup and verification
4. Test password recovery flow
5. Test token refresh mechanism
6. Test role-based access control