package main

import (
	"encoding/json"
	"fmt"
	"log"
	"net/http"
	"net/smtp"
	"os"
	"time"
)

// Config holds the mail server configuration
type Config struct {
	SMTPHost     string   `json:"smtp_host"`
	SMTPPort     string   `json:"smtp_port"`
	DefaultFrom  string   `json:"default_from"`
	MaxBodySize  int64    `json:"max_body_size"`
	AllowedHosts []string `json:"allowed_hosts"`
}

// EmailRequest represents an incoming request to send an email
type EmailRequest struct {
	From    string `json:"from"`
	To      string `json:"to"`
	Subject string `json:"subject"`
	Body    string `json:"body"`
	HTML    bool   `json:"html"`
}

// Response represents the API response
type Response struct {
	Success bool   `json:"success"`
	Message string `json:"message"`
}

var config Config

func loadConfig() error {
	// Default configuration
	config = Config{
		SMTPHost:     os.Getenv("SMTP_HOST"),
		SMTPPort:     os.Getenv("SMTP_PORT"),
		DefaultFrom:  os.Getenv("DEFAULT_FROM"),
		MaxBodySize:  1024 * 1024, // 1MB
		AllowedHosts: []string{},
	}

	// If no environment variables, use defaults
	if config.SMTPHost == "" {
		config.SMTPHost = "mail-server"
	}
	if config.SMTPPort == "" {
		config.SMTPPort = "25"
	}
	if config.DefaultFrom == "" {
		config.DefaultFrom = "noreply@dinky.local"
	}

	// Load allowed hosts from environment variable
	if allowedHosts := os.Getenv("ALLOWED_HOSTS"); allowedHosts != "" {
		config.AllowedHosts = append(config.AllowedHosts, allowedHosts)
	}

	return nil
}

func sendEmail(req EmailRequest) error {
	// If From field is empty, use default
	if req.From == "" {
		req.From = config.DefaultFrom
	}

	// Set headers
	headers := make(map[string]string)
	headers["From"] = req.From
	headers["To"] = req.To
	headers["Subject"] = req.Subject
	headers["Date"] = time.Now().Format(time.RFC1123Z)

	var contentType string
	if req.HTML {
		contentType = "text/html; charset=UTF-8"
	} else {
		contentType = "text/plain; charset=UTF-8"
	}
	headers["Content-Type"] = contentType

	// Compose the message
	message := ""
	for key, value := range headers {
		message += fmt.Sprintf("%s: %s\r\n", key, value)
	}
	message += "\r\n" + req.Body

	// Connect to the SMTP server
	addr := fmt.Sprintf("%s:%s", config.SMTPHost, config.SMTPPort)
	return smtp.SendMail(
		addr,
		nil, // No authentication
		req.From,
		[]string{req.To},
		[]byte(message),
	)
}

func emailHandler(w http.ResponseWriter, r *http.Request) {
	// Set response content type
	w.Header().Set("Content-Type", "application/json")

	// Check if method is POST
	if r.Method != http.MethodPost {
		w.WriteHeader(http.StatusMethodNotAllowed)
		json.NewEncoder(w).Encode(Response{
			Success: false,
			Message: "Only POST method is allowed",
		})
		return
	}

	// Limit the size of the request body
	r.Body = http.MaxBytesReader(w, r.Body, config.MaxBodySize)

	// Decode the request body
	var emailReq EmailRequest
	err := json.NewDecoder(r.Body).Decode(&emailReq)
	if err != nil {
		w.WriteHeader(http.StatusBadRequest)
		json.NewEncoder(w).Encode(Response{
			Success: false,
			Message: "Invalid request format: " + err.Error(),
		})
		return
	}

	// Validate required fields
	if emailReq.To == "" {
		w.WriteHeader(http.StatusBadRequest)
		json.NewEncoder(w).Encode(Response{
			Success: false,
			Message: "Recipient (to) is required",
		})
		return
	}

	if emailReq.Subject == "" {
		w.WriteHeader(http.StatusBadRequest)
		json.NewEncoder(w).Encode(Response{
			Success: false,
			Message: "Subject is required",
		})
		return
	}

	if emailReq.Body == "" {
		w.WriteHeader(http.StatusBadRequest)
		json.NewEncoder(w).Encode(Response{
			Success: false,
			Message: "Email body is required",
		})
		return
	}

	// Send the email
	err = sendEmail(emailReq)
	if err != nil {
		log.Printf("Error sending email: %v", err)
		w.WriteHeader(http.StatusInternalServerError)
		json.NewEncoder(w).Encode(Response{
			Success: false,
			Message: "Failed to send email: " + err.Error(),
		})
		return
	}

	// Return success response
	json.NewEncoder(w).Encode(Response{
		Success: true,
		Message: "Email sent successfully",
	})
}

func healthCheck(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(Response{
		Success: true,
		Message: "Mail API service is running",
	})
}

func main() {
	// Load configuration
	err := loadConfig()
	if err != nil {
		log.Fatalf("Failed to load configuration: %v", err)
	}

	// Set up routes
	http.HandleFunc("/health", healthCheck)
	http.HandleFunc("/send", emailHandler)

	// Get port from environment variable or use default
	port := os.Getenv("PORT")
	if port == "" {
		port = "8080"
	}

	// Start the server
	log.Printf("Starting mail API server on port %s", port)
	log.Printf("Configured to use SMTP server at %s:%s", config.SMTPHost, config.SMTPPort)
	log.Fatal(http.ListenAndServe(":"+port, nil))
}
