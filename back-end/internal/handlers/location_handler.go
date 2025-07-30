package handlers

import (
	"context"
	"mowesport/internal/database"
	"net/http"
	"time"

	"github.com/google/uuid"
	"github.com/labstack/echo/v4"
)

type LocationHandler struct {
	db *database.Database
}

type City struct {
	CityID  uuid.UUID `json:"city_id" db:"city_id"`
	Name    string    `json:"name" db:"name"`
	Region  string    `json:"region" db:"region"`
	Country string    `json:"country" db:"country"`
}

type Sport struct {
	SportID     uuid.UUID `json:"sport_id" db:"sport_id"`
	Name        string    `json:"name" db:"name"`
	Description *string   `json:"description" db:"description"`
}

func NewLocationHandler(db *database.Database) *LocationHandler {
	return &LocationHandler{
		db: db,
	}
}

// GetCities handles GET /api/cities
func (h *LocationHandler) GetCities(c echo.Context) error {
	// Create context with timeout
	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()

	// Query cities from database
	rows, err := h.db.GetConnection().Query(ctx, `
		SELECT city_id, name, region, country 
		FROM cities 
		ORDER BY name ASC
	`)
	if err != nil {
		return c.JSON(http.StatusInternalServerError, map[string]interface{}{
			"success": false,
			"error": map[string]interface{}{
				"code":    "DATABASE_ERROR",
				"message": "Failed to fetch cities",
				"details": err.Error(),
			},
		})
	}
	defer rows.Close()

	var cities []City
	for rows.Next() {
		var city City
		err := rows.Scan(&city.CityID, &city.Name, &city.Region, &city.Country)
		if err != nil {
			return c.JSON(http.StatusInternalServerError, map[string]interface{}{
				"success": false,
				"error": map[string]interface{}{
					"code":    "SCAN_ERROR",
					"message": "Failed to scan city data",
					"details": err.Error(),
				},
			})
		}
		cities = append(cities, city)
	}

	if err := rows.Err(); err != nil {
		return c.JSON(http.StatusInternalServerError, map[string]interface{}{
			"success": false,
			"error": map[string]interface{}{
				"code":    "ROWS_ERROR",
				"message": "Error iterating over cities",
				"details": err.Error(),
			},
		})
	}

	return c.JSON(http.StatusOK, map[string]interface{}{
		"success": true,
		"data":    cities,
	})
}

// GetSports handles GET /api/sports
func (h *LocationHandler) GetSports(c echo.Context) error {
	// Create context with timeout
	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()

	// Query sports from database
	rows, err := h.db.GetConnection().Query(ctx, `
		SELECT sport_id, name, description 
		FROM sports 
		ORDER BY name ASC
	`)
	if err != nil {
		return c.JSON(http.StatusInternalServerError, map[string]interface{}{
			"success": false,
			"error": map[string]interface{}{
				"code":    "DATABASE_ERROR",
				"message": "Failed to fetch sports",
				"details": err.Error(),
			},
		})
	}
	defer rows.Close()

	var sports []Sport
	for rows.Next() {
		var sport Sport
		err := rows.Scan(&sport.SportID, &sport.Name, &sport.Description)
		if err != nil {
			return c.JSON(http.StatusInternalServerError, map[string]interface{}{
				"success": false,
				"error": map[string]interface{}{
					"code":    "SCAN_ERROR",
					"message": "Failed to scan sport data",
					"details": err.Error(),
				},
			})
		}
		sports = append(sports, sport)
	}

	if err := rows.Err(); err != nil {
		return c.JSON(http.StatusInternalServerError, map[string]interface{}{
			"success": false,
			"error": map[string]interface{}{
				"code":    "ROWS_ERROR",
				"message": "Error iterating over sports",
				"details": err.Error(),
			},
		})
	}

	return c.JSON(http.StatusOK, map[string]interface{}{
		"success": true,
		"data":    sports,
	})
}
