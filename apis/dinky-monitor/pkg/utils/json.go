package utils

import (
	"encoding/json"
	"net/http"
)

// WriteJSON writes a JSON response with the given status code
func WriteJSON(w http.ResponseWriter, status int, data interface{}) error {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)
	return json.NewEncoder(w).Encode(data)
}

// WriteJSONError writes a JSON error response
func WriteJSONError(w http.ResponseWriter, status int, message string) error {
	return WriteJSON(w, status, map[string]interface{}{
		"error":   true,
		"message": message,
		"status":  status,
	})
}
