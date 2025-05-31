package config

import (
	"os"
	"time"
)

// ServiceConfig holds the service configuration
type ServiceConfig struct {
	Name        string
	Version     string
	Environment string
	StartTime   time.Time
	Port        string
}

// GetServiceConfig returns the current service configuration
func GetServiceConfig() *ServiceConfig {
	environment := os.Getenv("ENVIRONMENT")
	if environment == "" {
		environment = "development"
	}

	version := os.Getenv("SERVICE_VERSION")
	if version == "" {
		version = "v2.0.0"
	}

	return &ServiceConfig{
		Name:        "dinky-monitor",
		Version:     version,
		Environment: environment,
		StartTime:   time.Now(),
		Port:        ":3001",
	}
}

// GetAPIBaseURL returns the API base URL based on SERVER_IP environment variable
func (sc *ServiceConfig) GetAPIBaseURL() string {
	serverIP := os.Getenv("SERVER_IP")
	if serverIP == "" {
		// Default to container name for Docker network communication
		return "http://dinky-monitor:3001"
	}

	// Use SERVER_IP (could be localhost for dev, or actual IP for production)
	return "http://" + serverIP + ":3001"
}

// TracingConfig holds OpenTelemetry configuration
type TracingConfig struct {
	ServiceName    string
	ServiceVersion string
	JaegerEndpoint string
	SamplingRate   float64
}

// GetTracingConfig returns the tracing configuration
func GetTracingConfig() *TracingConfig {
	version := os.Getenv("SERVICE_VERSION")
	if version == "" {
		version = "v2.0.0"
	}

	return &TracingConfig{
		ServiceName:    "dinky-monitor",
		ServiceVersion: version,
		JaegerEndpoint: "http://localhost:14268/api/traces",
		SamplingRate:   1.0,
	}
}
