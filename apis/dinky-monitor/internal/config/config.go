package config

import (
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
	return &ServiceConfig{
		Name:        "dinky-monitor",
		Version:     "5.0.0-simplified",
		Environment: "development",
		StartTime:   time.Now(),
		Port:        ":3001",
	}
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
	return &TracingConfig{
		ServiceName:    "dinky-monitor",
		ServiceVersion: "5.0.0-phase5",
		JaegerEndpoint: "http://localhost:14268/api/traces",
		SamplingRate:   1.0,
	}
}
