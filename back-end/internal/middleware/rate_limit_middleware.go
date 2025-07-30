package middleware

import (
	"fmt"
	"net/http"
	"sync"
	"time"

	"github.com/labstack/echo/v4"
)

// RateLimiter implements a simple in-memory rate limiter
type RateLimiter struct {
	requests map[string][]time.Time
	mutex    sync.RWMutex
}

// NewRateLimiter creates a new rate limiter
func NewRateLimiter() *RateLimiter {
	return &RateLimiter{
		requests: make(map[string][]time.Time),
	}
}

// RateLimit middleware for rate limiting requests
func (rl *RateLimiter) RateLimit(maxRequests int, window time.Duration) echo.MiddlewareFunc {
	return func(next echo.HandlerFunc) echo.HandlerFunc {
		return func(c echo.Context) error {
			// Get client identifier (IP address)
			clientIP := c.RealIP()
			if clientIP == "" {
				clientIP = c.Request().RemoteAddr
			}

			// Check rate limit
			if err := rl.checkRateLimit(clientIP, maxRequests, window); err != nil {
				return c.JSON(http.StatusTooManyRequests, map[string]interface{}{
					"success": false,
					"error": map[string]interface{}{
						"code":    "RATE_LIMIT_EXCEEDED",
						"message": err.Error(),
					},
				})
			}

			return next(c)
		}
	}
}

// checkRateLimit checks if the client has exceeded the rate limit
func (rl *RateLimiter) checkRateLimit(identifier string, maxRequests int, window time.Duration) error {
	rl.mutex.Lock()
	defer rl.mutex.Unlock()

	now := time.Now()

	// Clean old entries
	if requests, exists := rl.requests[identifier]; exists {
		var validRequests []time.Time
		for _, reqTime := range requests {
			if now.Sub(reqTime) < window {
				validRequests = append(validRequests, reqTime)
			}
		}
		rl.requests[identifier] = validRequests
	}

	// Check current request count
	currentRequests := len(rl.requests[identifier])
	if currentRequests >= maxRequests {
		return fmt.Errorf("rate limit exceeded: maximum %d requests per %v", maxRequests, window)
	}

	// Add current request
	rl.requests[identifier] = append(rl.requests[identifier], now)

	return nil
}

// AdminRegistrationRateLimit applies rate limiting specifically for admin registration
func AdminRegistrationRateLimit() echo.MiddlewareFunc {
	limiter := NewRateLimiter()
	// Allow 3 admin registration attempts per 15 minutes per IP
	return limiter.RateLimit(3, 15*time.Minute)
}

// EmailValidationRateLimit applies rate limiting for email validation
func EmailValidationRateLimit() echo.MiddlewareFunc {
	limiter := NewRateLimiter()
	// Allow 20 email validation requests per minute per IP
	return limiter.RateLimit(20, 1*time.Minute)
}

// GeneralAPIRateLimit applies general rate limiting for API endpoints
func GeneralAPIRateLimit() echo.MiddlewareFunc {
	limiter := NewRateLimiter()
	// Allow 100 requests per minute per IP
	return limiter.RateLimit(100, 1*time.Minute)
}
