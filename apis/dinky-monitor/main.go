package main

import (
	"context"
	"encoding/json"
	"fmt"
	"log"
	"math/rand"
	"net/http"
	"runtime"
	"strconv"
	"strings"
	"time"

	"github.com/google/uuid"
	"github.com/gorilla/mux"
	"github.com/prometheus/client_golang/prometheus"
	"github.com/prometheus/client_golang/prometheus/promhttp"
	"go.opentelemetry.io/otel"
	"go.opentelemetry.io/otel/attribute"
	"go.opentelemetry.io/otel/exporters/otlp/otlptrace/otlptracehttp"
	"go.opentelemetry.io/otel/propagation"
	"go.opentelemetry.io/otel/sdk/resource"
	"go.opentelemetry.io/otel/sdk/trace"
	semconv "go.opentelemetry.io/otel/semconv/v1.4.0"
	oteltrace "go.opentelemetry.io/otel/trace"
	"go.uber.org/zap"
	"go.uber.org/zap/zapcore"
)

// Phase 2: Enhanced logging context and correlation
type LogContext struct {
	RequestID   string `json:"request_id"`
	TraceID     string `json:"trace_id"`
	SpanID      string `json:"span_id"`
	UserID      string `json:"user_id,omitempty"`
	SessionID   string `json:"session_id,omitempty"`
	ServiceName string `json:"service_name"`
	Version     string `json:"version"`
	Environment string `json:"environment"`
}

type LogEntry struct {
	Level       string                 `json:"level"`
	Timestamp   time.Time              `json:"timestamp"`
	Message     string                 `json:"message"`
	Context     LogContext             `json:"context"`
	Data        map[string]interface{} `json:"data,omitempty"`
	Error       *LogErrorData          `json:"error,omitempty"`
	Performance *PerformanceData       `json:"performance,omitempty"`
	Business    *BusinessData          `json:"business,omitempty"`
}

type LogErrorData struct {
	Type       string `json:"type"`
	Code       string `json:"code"`
	Message    string `json:"message"`
	StackTrace string `json:"stack_trace,omitempty"`
}

type PerformanceData struct {
	Duration       float64 `json:"duration_ms"`
	MemoryUsage    int64   `json:"memory_usage_bytes"`
	GoroutineCount int     `json:"goroutine_count"`
	CPUPercent     float64 `json:"cpu_percent,omitempty"`
}

type BusinessData struct {
	EventType  string                 `json:"event_type"`
	EntityID   string                 `json:"entity_id,omitempty"`
	EntityType string                 `json:"entity_type,omitempty"`
	Action     string                 `json:"action"`
	Metadata   map[string]interface{} `json:"metadata,omitempty"`
	Metrics    map[string]float64     `json:"metrics,omitempty"`
}

// Context keys for request correlation
type contextKey string

const (
	RequestIDKey contextKey = "request_id"
	TraceIDKey   contextKey = "trace_id"
	UserIDKey    contextKey = "user_id"
	SessionIDKey contextKey = "session_id"
	StartTimeKey contextKey = "start_time"
)

var (
	// Service information
	serviceName    = "dinky-monitor"
	serviceVersion = "2.0.0-phase2"
	environment    = "development"
	startTime      = time.Now()

	// Prometheus metrics
	httpRequestsTotal = prometheus.NewCounterVec(
		prometheus.CounterOpts{
			Name: "http_requests_total",
			Help: "Total number of HTTP requests",
		},
		[]string{"method", "endpoint", "status"},
	)

	httpRequestDuration = prometheus.NewHistogramVec(
		prometheus.HistogramOpts{
			Name:    "http_request_duration_seconds",
			Help:    "HTTP request duration in seconds",
			Buckets: prometheus.DefBuckets,
		},
		[]string{"method", "endpoint"},
	)

	// Phase 2: Enhanced log-based metrics
	logEntriesTotal = prometheus.NewCounterVec(
		prometheus.CounterOpts{
			Name: "log_entries_total",
			Help: "Total number of log entries by level and service",
		},
		[]string{"level", "service", "error_type"},
	)

	logProcessingDuration = prometheus.NewHistogramVec(
		prometheus.HistogramOpts{
			Name:    "log_processing_duration_seconds",
			Help:    "Time spent processing log entries",
			Buckets: []float64{0.001, 0.005, 0.01, 0.025, 0.05, 0.1, 0.25, 0.5, 1.0},
		},
		[]string{"operation", "log_level"},
	)

	errorsByCategory = prometheus.NewCounterVec(
		prometheus.CounterOpts{
			Name: "errors_by_category_total",
			Help: "Total errors categorized by type and severity",
		},
		[]string{"category", "severity", "source"},
	)

	customMetric = prometheus.NewGaugeVec(
		prometheus.GaugeOpts{
			Name: "custom_business_metric",
			Help: "Custom business metric for testing",
		},
		[]string{"type", "category"},
	)

	errorCounter = prometheus.NewCounterVec(
		prometheus.CounterOpts{
			Name: "application_errors_total",
			Help: "Total number of application errors",
		},
		[]string{"error_type", "severity"},
	)

	// Phase 1: Enhanced Metrics for Testing
	// Business Metrics
	userRegistrations = prometheus.NewCounterVec(
		prometheus.CounterOpts{
			Name: "user_registrations_total",
			Help: "Total number of user registrations",
		},
		[]string{"source", "plan_type"},
	)

	orderMetrics = prometheus.NewCounterVec(
		prometheus.CounterOpts{
			Name: "orders_total",
			Help: "Total number of orders",
		},
		[]string{"status", "payment_method", "region"},
	)

	revenueGauge = prometheus.NewGaugeVec(
		prometheus.GaugeOpts{
			Name: "revenue_current",
			Help: "Current revenue amount",
		},
		[]string{"currency", "product_category"},
	)

	responseTimeHistogram = prometheus.NewHistogramVec(
		prometheus.HistogramOpts{
			Name:    "service_response_time_seconds",
			Help:    "Service response time distribution",
			Buckets: []float64{0.1, 0.25, 0.5, 1.0, 2.5, 5.0, 10.0},
		},
		[]string{"service", "endpoint", "method"},
	)

	// System Resource Metrics
	cpuUsageGauge = prometheus.NewGauge(
		prometheus.GaugeOpts{
			Name: "simulated_cpu_usage_percent",
			Help: "Simulated CPU usage percentage",
		},
	)

	memoryUsageGauge = prometheus.NewGauge(
		prometheus.GaugeOpts{
			Name: "simulated_memory_usage_bytes",
			Help: "Simulated memory usage in bytes",
		},
	)

	// Load Testing Metrics
	activeUsersGauge = prometheus.NewGauge(
		prometheus.GaugeOpts{
			Name: "active_users_current",
			Help: "Current number of active users",
		},
	)

	requestRateGauge = prometheus.NewGauge(
		prometheus.GaugeOpts{
			Name: "request_rate_per_second",
			Help: "Current request rate per second",
		},
	)

	// Error Rate Metrics
	errorRateGauge = prometheus.NewGaugeVec(
		prometheus.GaugeOpts{
			Name: "error_rate_percent",
			Help: "Current error rate percentage",
		},
		[]string{"service", "error_type"},
	)

	// Global logger and tracer
	logger *zap.Logger
	tracer oteltrace.Tracer
)

func init() {
	// Register Prometheus metrics
	prometheus.MustRegister(httpRequestsTotal)
	prometheus.MustRegister(httpRequestDuration)
	prometheus.MustRegister(logEntriesTotal)
	prometheus.MustRegister(logProcessingDuration)
	prometheus.MustRegister(errorsByCategory)
	prometheus.MustRegister(customMetric)
	prometheus.MustRegister(errorCounter)
	prometheus.MustRegister(userRegistrations)
	prometheus.MustRegister(orderMetrics)
	prometheus.MustRegister(revenueGauge)
	prometheus.MustRegister(responseTimeHistogram)
	prometheus.MustRegister(cpuUsageGauge)
	prometheus.MustRegister(memoryUsageGauge)
	prometheus.MustRegister(activeUsersGauge)
	prometheus.MustRegister(requestRateGauge)
	prometheus.MustRegister(errorRateGauge)
}

// Phase 2: Enhanced structured logging initialization
func initLogger() {
	config := zap.NewProductionConfig()
	config.OutputPaths = []string{"stdout"}
	config.ErrorOutputPaths = []string{"stderr"}
	config.EncoderConfig.TimeKey = "timestamp"
	config.EncoderConfig.EncodeTime = zapcore.RFC3339NanoTimeEncoder
	config.EncoderConfig.MessageKey = "message"
	config.EncoderConfig.LevelKey = "level"
	config.EncoderConfig.CallerKey = "caller"
	config.EncoderConfig.StacktraceKey = "stacktrace"
	config.EncoderConfig.EncodeCaller = zapcore.ShortCallerEncoder

	// Enhanced field configuration for better log correlation
	config.InitialFields = map[string]interface{}{
		"service_name": serviceName,
		"version":      serviceVersion,
		"environment":  environment,
		"node_id":      generateNodeID(),
	}

	var err error
	logger, err = config.Build(
		zap.AddCaller(),
		zap.AddStacktrace(zapcore.ErrorLevel),
	)
	if err != nil {
		log.Fatal("Failed to initialize logger:", err)
	}

	// Log startup information
	LogBusinessEvent("service_startup", map[string]interface{}{
		"startup_time": startTime,
		"go_version":   runtime.Version(),
		"num_cpu":      runtime.NumCPU(),
	})
}

// Generate unique node identifier for service instance correlation
func generateNodeID() string {
	return fmt.Sprintf("%s-%d", serviceName, time.Now().Unix())
}

func initTracer() {
	ctx := context.Background()

	// Create OTLP HTTP exporter
	exporter, err := otlptracehttp.New(ctx,
		otlptracehttp.WithEndpoint("http://otel-collector:4318"),
		otlptracehttp.WithInsecure(),
	)
	if err != nil {
		log.Printf("Failed to create OTLP exporter: %v", err)
		return
	}

	// Create resource
	res, err := resource.New(ctx,
		resource.WithAttributes(
			semconv.ServiceNameKey.String("example-api"),
			semconv.ServiceVersionKey.String("1.0.0"),
			semconv.DeploymentEnvironmentKey.String("development"),
		),
	)
	if err != nil {
		log.Printf("Failed to create resource: %v", err)
		return
	}

	// Create trace provider
	tp := trace.NewTracerProvider(
		trace.WithBatcher(exporter),
		trace.WithResource(res),
	)

	otel.SetTracerProvider(tp)
	otel.SetTextMapPropagator(propagation.TraceContext{})

	tracer = otel.Tracer("example-api")

	// Start continuous background metrics generation
	startContinuousMetrics()
}

func corsMiddleware(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		// Set CORS headers
		w.Header().Set("Access-Control-Allow-Origin", "*")
		w.Header().Set("Access-Control-Allow-Methods", "GET, POST, PUT, DELETE, OPTIONS")
		w.Header().Set("Access-Control-Allow-Headers", "Content-Type, Authorization, hx-request, hx-target, hx-current-url, hx-trigger, hx-trigger-name, hx-prompt, hx-boosted")
		w.Header().Set("Access-Control-Max-Age", "86400")

		// Handle preflight requests
		if r.Method == "OPTIONS" {
			w.WriteHeader(http.StatusOK)
			return
		}

		next.ServeHTTP(w, r)
	})
}

type responseWriter struct {
	http.ResponseWriter
	statusCode int
}

func (rw *responseWriter) WriteHeader(code int) {
	rw.statusCode = code
	rw.ResponseWriter.WriteHeader(code)
}

// Test endpoints
func healthHandler(w http.ResponseWriter, r *http.Request) {
	_, span := tracer.Start(r.Context(), "health_check")
	defer span.End()

	logger.Info("Health check requested",
		zap.String("method", r.Method),
		zap.String("path", r.URL.Path),
		zap.String("user_agent", r.UserAgent()),
	)

	span.SetAttributes(
		attribute.String("http.method", r.Method),
		attribute.String("http.path", r.URL.Path),
		attribute.Bool("health.status", true),
	)

	response := map[string]interface{}{
		"status":    "healthy",
		"timestamp": time.Now().UTC(),
		"version":   "1.0.0",
		"uptime":    time.Since(startTime).String(),
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(response)
}

func generateMetricsHandler(w http.ResponseWriter, r *http.Request) {
	_, span := tracer.Start(r.Context(), "generate_metrics")
	defer span.End()

	// Generate random metrics
	for i := 0; i < 10; i++ {
		customMetric.WithLabelValues(
			fmt.Sprintf("type_%d", rand.Intn(5)),
			fmt.Sprintf("category_%d", rand.Intn(3)),
		).Set(rand.Float64() * 100)
	}

	logger.Info("Generated custom metrics",
		zap.Int("count", 10),
		zap.String("action", "generate_metrics"),
	)

	span.SetAttributes(
		attribute.Int("metrics.generated", 10),
		attribute.String("metrics.type", "custom_business_metric"),
	)

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(map[string]string{
		"message": "Generated 10 custom metrics",
		"status":  "success",
	})
}

func generateLogsHandler(w http.ResponseWriter, r *http.Request) {
	_, span := tracer.Start(r.Context(), "generate_logs")
	defer span.End()

	logLevels := []zapcore.Level{
		zapcore.InfoLevel,
		zapcore.WarnLevel,
		zapcore.ErrorLevel,
		zapcore.DebugLevel,
	}

	// Generate various log levels
	for i := 0; i < 5; i++ {
		level := logLevels[rand.Intn(len(logLevels))]

		switch level {
		case zapcore.InfoLevel:
			logger.Info("Generated info log",
				zap.Int("iteration", i),
				zap.String("log_type", "info"),
				zap.Float64("random_value", rand.Float64()),
			)
		case zapcore.WarnLevel:
			logger.Warn("Generated warning log",
				zap.Int("iteration", i),
				zap.String("log_type", "warning"),
				zap.String("warning_reason", "test_scenario"),
			)
		case zapcore.ErrorLevel:
			logger.Error("Generated error log",
				zap.Int("iteration", i),
				zap.String("log_type", "error"),
				zap.String("error_code", fmt.Sprintf("ERR_%d", rand.Intn(1000))),
			)
		case zapcore.DebugLevel:
			logger.Debug("Generated debug log",
				zap.Int("iteration", i),
				zap.String("log_type", "debug"),
				zap.Any("debug_data", map[string]interface{}{
					"key1": "value1",
					"key2": rand.Intn(100),
				}),
			)
		}
	}

	span.SetAttributes(
		attribute.Int("logs.generated", 5),
		attribute.String("logs.levels", "info,warn,error,debug"),
	)

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(map[string]string{
		"message": "Generated 5 log entries with different levels",
		"status":  "success",
	})
}

func generateErrorHandler(w http.ResponseWriter, r *http.Request) {
	_, span := tracer.Start(r.Context(), "generate_error")
	defer span.End()

	errorTypes := []string{"validation", "database", "network", "timeout", "auth"}
	errorType := errorTypes[rand.Intn(len(errorTypes))]

	errorCounter.WithLabelValues(errorType, "high").Inc()

	logger.Error("Intentional error generated for testing",
		zap.String("error_type", errorType),
		zap.String("error_id", fmt.Sprintf("ERR_%d", rand.Intn(10000))),
		zap.Int("status_code", 500),
	)

	span.SetAttributes(
		attribute.String("error.type", errorType),
		attribute.Bool("error.intentional", true),
		attribute.Int("http.status_code", 500),
	)

	w.WriteHeader(http.StatusInternalServerError)
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(map[string]string{
		"error":      "Intentional error for testing",
		"error_type": errorType,
		"status":     "error",
	})
}

func cpuLoadHandler(w http.ResponseWriter, r *http.Request) {
	_, span := tracer.Start(r.Context(), "cpu_load_test")
	defer span.End()

	duration := 5 * time.Second
	if d := r.URL.Query().Get("duration"); d != "" {
		if parsed, err := time.ParseDuration(d); err == nil {
			duration = parsed
		}
	}

	logger.Info("Starting CPU load test",
		zap.Duration("duration", duration),
		zap.String("test_type", "cpu_intensive"),
	)

	// CPU intensive task
	start := time.Now()
	for time.Since(start) < duration {
		for i := 0; i < 1000000; i++ {
			_ = i * i
		}
		runtime.Gosched() // Allow other goroutines to run
	}

	span.SetAttributes(
		attribute.String("test.type", "cpu_load"),
		attribute.String("test.duration", duration.String()),
	)

	logger.Info("CPU load test completed",
		zap.Duration("actual_duration", time.Since(start)),
	)

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(map[string]string{
		"message":  "CPU load test completed",
		"duration": duration.String(),
		"status":   "success",
	})
}

func memoryLoadHandler(w http.ResponseWriter, r *http.Request) {
	_, span := tracer.Start(r.Context(), "memory_load_test")
	defer span.End()

	sizeMB := 50
	if s := r.URL.Query().Get("size"); s != "" {
		if parsed, err := strconv.Atoi(s); err == nil {
			sizeMB = parsed
		}
	}

	logger.Info("Starting memory allocation test",
		zap.Int("size_mb", sizeMB),
		zap.String("test_type", "memory_intensive"),
	)

	// Allocate memory
	data := make([][]byte, sizeMB)
	for i := 0; i < sizeMB; i++ {
		data[i] = make([]byte, 1024*1024) // 1MB chunks
		// Fill with random data to prevent optimization
		for j := range data[i] {
			data[i][j] = byte(rand.Intn(256))
		}
	}

	// Hold memory for a bit
	time.Sleep(2 * time.Second)

	span.SetAttributes(
		attribute.String("test.type", "memory_load"),
		attribute.Int("memory.allocated_mb", sizeMB),
	)

	logger.Info("Memory allocation test completed",
		zap.Int("allocated_mb", sizeMB),
	)

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(map[string]string{
		"message":      "Memory allocation test completed",
		"allocated_mb": strconv.Itoa(sizeMB),
		"status":       "success",
	})
}

func distributedTraceHandler(w http.ResponseWriter, r *http.Request) {
	ctx, span := tracer.Start(r.Context(), "distributed_trace_simulation")
	defer span.End()

	logger.Info("Starting distributed trace simulation")

	// Simulate multiple service calls
	simulateServiceCall(ctx, "user-service", 100*time.Millisecond)
	simulateServiceCall(ctx, "database-service", 200*time.Millisecond)
	simulateServiceCall(ctx, "cache-service", 50*time.Millisecond)
	simulateServiceCall(ctx, "notification-service", 150*time.Millisecond)

	span.SetAttributes(
		attribute.String("trace.type", "distributed"),
		attribute.Int("services.called", 4),
	)

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(map[string]string{
		"message":  "Distributed trace simulation completed",
		"services": "user-service, database-service, cache-service, notification-service",
		"status":   "success",
	})
}

func simulateServiceCall(ctx context.Context, serviceName string, duration time.Duration) {
	_, span := tracer.Start(ctx, fmt.Sprintf("call_%s", serviceName))
	defer span.End()

	span.SetAttributes(
		attribute.String("service.name", serviceName),
		attribute.String("service.operation", "process_request"),
	)

	logger.Info("Calling external service",
		zap.String("service", serviceName),
		zap.Duration("expected_duration", duration),
	)

	// Simulate work
	time.Sleep(duration)

	// Randomly add some errors
	if rand.Float32() < 0.1 { // 10% chance of error
		span.SetAttributes(attribute.Bool("error", true))
		logger.Warn("Service call failed",
			zap.String("service", serviceName),
			zap.String("error", "timeout"),
		)
	}
}

func docsHandler(w http.ResponseWriter, r *http.Request) {
	_, span := tracer.Start(r.Context(), "api_docs")
	defer span.End()

	logger.Info("API documentation requested",
		zap.String("method", r.Method),
		zap.String("path", r.URL.Path),
	)

	docs := map[string]interface{}{
		"api_name":    "Example API",
		"version":     "1.0.0",
		"description": "A comprehensive example API for testing monitoring, logging, and tracing",
		"base_url":    fmt.Sprintf("http://%s", r.Host),
		"endpoints": map[string]interface{}{
			"health": map[string]interface{}{
				"path":        "/health",
				"method":      "GET",
				"description": "Health check endpoint",
				"response":    "JSON with status and system info",
			},
			"root": map[string]interface{}{
				"path":        "/",
				"method":      "GET",
				"description": "Root endpoint (same as health)",
				"response":    "JSON with status and system info",
			},
			"docs": map[string]interface{}{
				"path":        "/docs",
				"method":      "GET",
				"description": "API documentation (this endpoint)",
				"response":    "JSON with API documentation",
			},
			"ui": map[string]interface{}{
				"path":        "/ui",
				"method":      "GET",
				"description": "Web UI for testing the API",
				"response":    "HTML interface",
			},
			"metrics": map[string]interface{}{
				"path":        "/metrics",
				"method":      "GET",
				"description": "Prometheus metrics endpoint",
				"response":    "Prometheus format metrics",
			},
			"test_metrics": map[string]interface{}{
				"path":        "/test/metrics",
				"method":      "POST",
				"description": "Generate test metrics data",
				"parameters":  "Optional: count, value, labels",
				"response":    "JSON confirmation",
			},
			"test_logs": map[string]interface{}{
				"path":        "/test/logs",
				"method":      "POST",
				"description": "Generate test log entries",
				"parameters":  "Optional: level, count, message",
				"response":    "JSON confirmation",
			},
			"test_error": map[string]interface{}{
				"path":        "/test/error",
				"method":      "POST",
				"description": "Generate intentional errors for testing",
				"parameters":  "Optional: error_type",
				"response":    "500 error with details",
			},
			"test_cpu": map[string]interface{}{
				"path":        "/test/cpu",
				"method":      "POST",
				"description": "CPU load test for performance monitoring",
				"parameters":  "Optional: duration (e.g. 5s, 1m)",
				"response":    "JSON with test results",
			},
			"test_memory": map[string]interface{}{
				"path":        "/test/memory",
				"method":      "POST",
				"description": "Memory allocation test",
				"parameters":  "Optional: size (MB)",
				"response":    "JSON with allocation details",
			},
			"test_trace": map[string]interface{}{
				"path":        "/test/trace",
				"method":      "POST",
				"description": "Distributed tracing simulation",
				"parameters":  "None",
				"response":    "JSON with trace details",
			},
		},
		"features": []string{
			"OpenTelemetry tracing",
			"Prometheus metrics",
			"Structured logging with Zap",
			"CORS support",
			"Health checks",
			"Performance testing endpoints",
		},
		"monitoring": map[string]string{
			"traces":  "Exported to OpenTelemetry Collector",
			"metrics": "Available at /metrics for Prometheus",
			"logs":    "Structured JSON logs to stdout",
		},
	}

	span.SetAttributes(
		attribute.String("http.method", r.Method),
		attribute.String("http.path", r.URL.Path),
	)

	// Check if HTML format is requested
	if r.URL.Query().Get("format") == "html" || r.Header.Get("Accept") == "text/html" {
		docsHTMLHandler(w, r, docs)
		return
	}

	// Return formatted JSON
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusOK)

	encoder := json.NewEncoder(w)
	encoder.SetIndent("", "  ") // Pretty print with 2-space indentation
	encoder.Encode(docs)
}

func docsHTMLHandler(w http.ResponseWriter, r *http.Request, docs map[string]interface{}) {
	w.Header().Set("Content-Type", "text/html")
	w.WriteHeader(http.StatusOK)

	html := `<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Example API Documentation</title>
    <style>
        body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif; line-height: 1.6; margin: 0; padding: 20px; background: #f5f5f5; }
        .container { max-width: 1200px; margin: 0 auto; background: white; padding: 30px; border-radius: 8px; box-shadow: 0 2px 10px rgba(0,0,0,0.1); }
        h1 { color: #2c3e50; border-bottom: 3px solid #3498db; padding-bottom: 10px; }
        h2 { color: #34495e; margin-top: 30px; }
        h3 { color: #7f8c8d; }
        .endpoint { background: #f8f9fa; padding: 15px; margin: 10px 0; border-radius: 5px; border-left: 4px solid #3498db; }
        .method { font-weight: bold; color: white; padding: 3px 8px; border-radius: 3px; font-size: 12px; }
        .get { background: #27ae60; }
        .post { background: #e74c3c; }
        .path { font-family: monospace; background: #ecf0f1; padding: 2px 6px; border-radius: 3px; }
        .feature { background: #e8f5e8; padding: 5px 10px; margin: 5px; border-radius: 3px; display: inline-block; }
        .monitoring { background: #fff3cd; padding: 10px; border-radius: 5px; margin: 10px 0; }
        .badge { background: #3498db; color: white; padding: 2px 8px; border-radius: 12px; font-size: 12px; }
        .usage { background: #f1f2f6; padding: 15px; border-radius: 5px; margin: 10px 0; }
        code { background: #f1f2f6; padding: 2px 4px; border-radius: 3px; font-family: monospace; }
        .example { background: #263238; color: #f8f8f2; padding: 15px; border-radius: 5px; overflow-x: auto; }
    </style>
</head>
<body>
    <div class="container">
        <h1>🚀 ` + docs["api_name"].(string) + `</h1>
        <p><strong>Version:</strong> <span class="badge">` + docs["version"].(string) + `</span></p>
        <p><strong>Base URL:</strong> <code>` + docs["base_url"].(string) + `</code></p>
        <p>` + docs["description"].(string) + `</p>
        
        <h2>📡 API Endpoints</h2>
        
        <h3>📖 Documentation & Health</h3>`

	// Add GET endpoints
	endpoints := docs["endpoints"].(map[string]interface{})
	getEndpoints := []string{"health", "root", "docs", "ui", "metrics"}
	for _, ep := range getEndpoints {
		if endpoint, ok := endpoints[ep].(map[string]interface{}); ok {
			html += fmt.Sprintf(`
        <div class="endpoint">
            <span class="method get">%s</span> 
            <span class="path">%s</span>
            <p>%s</p>
            <small><strong>Response:</strong> %s</small>
        </div>`,
				endpoint["method"].(string),
				endpoint["path"].(string),
				endpoint["description"].(string),
				endpoint["response"].(string))
		}
	}

	html += `
        <h3>🧪 Testing Endpoints</h3>`

	// Add POST endpoints
	postEndpoints := []string{"test_metrics", "test_logs", "test_error", "test_cpu", "test_memory", "test_trace"}
	for _, ep := range postEndpoints {
		if endpoint, ok := endpoints[ep].(map[string]interface{}); ok {
			params := ""
			if p, ok := endpoint["parameters"].(string); ok && p != "None" {
				params = fmt.Sprintf("<br><small><strong>Parameters:</strong> %s</small>", p)
			}
			html += fmt.Sprintf(`
        <div class="endpoint">
            <span class="method post">%s</span> 
            <span class="path">%s</span>
            <p>%s</p>%s
            <small><strong>Response:</strong> %s</small>
        </div>`,
				endpoint["method"].(string),
				endpoint["path"].(string),
				endpoint["description"].(string),
				params,
				endpoint["response"].(string))
		}
	}

	html += `
        <h2>🎯 Usage Examples</h2>
        <div class="usage">
            <h4>Get API Documentation (JSON)</h4>
            <div class="example">curl ` + docs["base_url"].(string) + `/docs | jq</div>
        </div>
        
        <div class="usage">
            <h4>Generate Test Data</h4>
            <div class="example"># Generate metrics<br>curl -X POST ` + docs["base_url"].(string) + `/test/metrics<br><br># Generate logs<br>curl -X POST ` + docs["base_url"].(string) + `/test/logs<br><br># Create error<br>curl -X POST ` + docs["base_url"].(string) + `/test/error</div>
        </div>
        
        <div class="usage">
            <h4>Load Testing</h4>
            <div class="example"># CPU test (10 seconds)<br>curl -X POST "` + docs["base_url"].(string) + `/test/cpu?duration=10s"<br><br># Memory test (200MB)<br>curl -X POST "` + docs["base_url"].(string) + `/test/memory?size=200"</div>
        </div>

        <h2>✨ Features</h2>
        <div>`

	features := docs["features"].([]string)
	for _, feature := range features {
		html += fmt.Sprintf(`<span class="feature">%s</span>`, feature)
	}

	html += `</div>
        
        <h2>📊 Monitoring Integration</h2>
        <div class="monitoring">`

	monitoring := docs["monitoring"].(map[string]string)
	for key, value := range monitoring {
		html += fmt.Sprintf(`<p><strong>%s:</strong> %s</p>`,
			strings.Title(key), value)
	}

	html += `</div>
        
        <h2>🔗 Quick Links</h2>
        <p>
            <a href="/">🏠 Home</a> | 
            <a href="/health">💓 Health</a> | 
            <a href="/ui">🎮 Interactive UI</a> | 
            <a href="/metrics">📊 Metrics</a> |
            <a href="/docs?format=html">📖 HTML Docs</a> |
            <a href="/docs">📋 JSON Docs</a>
        </p>
        
        <hr style="margin: 30px 0;">
        <p style="text-align: center; color: #7f8c8d;">
            <small>Perfect for testing your LGTM monitoring stack! 🚀</small>
        </p>
    </div>
</body>
</html>`

	w.Write([]byte(html))
}

// Phase 1: Enhanced Metrics Generation Handlers

// Business Metrics Generation
func generateBusinessMetricsHandler(w http.ResponseWriter, r *http.Request) {
	_, span := tracer.Start(r.Context(), "generate_business_metrics")
	defer span.End()

	// Simulate user registrations
	sources := []string{"web", "mobile", "api", "referral"}
	plans := []string{"free", "premium", "enterprise"}

	for i := 0; i < rand.Intn(10)+1; i++ {
		source := sources[rand.Intn(len(sources))]
		plan := plans[rand.Intn(len(plans))]
		userRegistrations.WithLabelValues(source, plan).Inc()
	}

	// Simulate orders
	statuses := []string{"pending", "completed", "failed", "cancelled"}
	payments := []string{"credit_card", "paypal", "bank_transfer", "crypto"}
	regions := []string{"us-east", "us-west", "eu-central", "asia-pacific"}

	for i := 0; i < rand.Intn(20)+1; i++ {
		status := statuses[rand.Intn(len(statuses))]
		payment := payments[rand.Intn(len(payments))]
		region := regions[rand.Intn(len(regions))]
		orderMetrics.WithLabelValues(status, payment, region).Inc()
	}

	// Simulate revenue
	currencies := []string{"USD", "EUR", "GBP", "JPY"}
	categories := []string{"electronics", "books", "clothing", "software"}

	for _, currency := range currencies {
		for _, category := range categories {
			revenue := rand.Float64()*10000 + 1000 // $1k - $11k
			revenueGauge.WithLabelValues(currency, category).Set(revenue)
		}
	}

	logger.Info("Generated business metrics",
		zap.String("type", "business_metrics"),
		zap.Int("registrations_generated", rand.Intn(10)+1),
		zap.Int("orders_generated", rand.Intn(20)+1),
	)

	span.SetAttributes(
		attribute.String("metrics.type", "business"),
		attribute.Int("metrics.registrations", rand.Intn(10)+1),
		attribute.Int("metrics.orders", rand.Intn(20)+1),
	)

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(map[string]interface{}{
		"status":  "success",
		"message": "Business metrics generated successfully",
		"metrics_generated": map[string]interface{}{
			"user_registrations": "Random registrations across sources and plans",
			"orders":             "Random orders with different statuses and payment methods",
			"revenue":            "Updated revenue across currencies and categories",
		},
		"timestamp": time.Now().Unix(),
	})
}

// System Metrics Generation
func generateSystemMetricsHandler(w http.ResponseWriter, r *http.Request) {
	_, span := tracer.Start(r.Context(), "generate_system_metrics")
	defer span.End()

	// Simulate CPU usage (0-100%)
	cpuUsage := rand.Float64() * 100
	cpuUsageGauge.Set(cpuUsage)

	// Simulate memory usage (100MB - 8GB)
	memoryUsage := rand.Float64()*8e9 + 1e8
	memoryUsageGauge.Set(memoryUsage)

	// Simulate active users (10-1000)
	activeUsers := rand.Float64()*990 + 10
	activeUsersGauge.Set(activeUsers)

	// Simulate request rate (1-500 req/s)
	requestRate := rand.Float64()*499 + 1
	requestRateGauge.Set(requestRate)

	// Simulate service response times
	services := []string{"auth-service", "user-service", "order-service", "payment-service"}
	endpoints := []string{"/login", "/profile", "/create", "/process"}
	methods := []string{"GET", "POST", "PUT", "DELETE"}

	for _, service := range services {
		for _, endpoint := range endpoints {
			for _, method := range methods {
				responseTime := rand.Float64()*2.0 + 0.1 // 0.1-2.1 seconds
				responseTimeHistogram.WithLabelValues(service, endpoint, method).Observe(responseTime)
			}
		}
	}

	// Simulate error rates
	errorTypes := []string{"timeout", "validation", "authentication", "server_error"}
	for _, service := range services {
		for _, errorType := range errorTypes {
			errorRate := rand.Float64() * 5 // 0-5% error rate
			errorRateGauge.WithLabelValues(service, errorType).Set(errorRate)
		}
	}

	logger.Info("Generated system metrics",
		zap.String("type", "system_metrics"),
		zap.Float64("cpu_usage", cpuUsage),
		zap.Float64("memory_usage_gb", memoryUsage/1e9),
		zap.Float64("active_users", activeUsers),
		zap.Float64("request_rate", requestRate),
	)

	span.SetAttributes(
		attribute.String("metrics.type", "system"),
		attribute.Float64("metrics.cpu_usage", cpuUsage),
		attribute.Float64("metrics.memory_usage", memoryUsage),
		attribute.Float64("metrics.active_users", activeUsers),
	)

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(map[string]interface{}{
		"status":  "success",
		"message": "System metrics generated successfully",
		"metrics_generated": map[string]interface{}{
			"cpu_usage_percent":       cpuUsage,
			"memory_usage_gb":         memoryUsage / 1e9,
			"active_users":            activeUsers,
			"request_rate_per_second": requestRate,
			"response_times":          "Generated for multiple services and endpoints",
			"error_rates":             "Generated for multiple services and error types",
		},
		"timestamp": time.Now().Unix(),
	})
}

// Load Simulation
func simulateLoadHandler(w http.ResponseWriter, r *http.Request) {
	_, span := tracer.Start(r.Context(), "simulate_load")
	defer span.End()

	// Parse parameters
	durationStr := r.URL.Query().Get("duration")
	if durationStr == "" {
		durationStr = "30s"
	}

	intensity := r.URL.Query().Get("intensity")
	if intensity == "" {
		intensity = "medium"
	}

	duration, err := time.ParseDuration(durationStr)
	if err != nil {
		duration = 30 * time.Second
	}

	// Start load simulation in background
	go func() {
		endTime := time.Now().Add(duration)

		var baseUsers, baseRequests float64
		switch intensity {
		case "low":
			baseUsers, baseRequests = 50, 100
		case "medium":
			baseUsers, baseRequests = 200, 500
		case "high":
			baseUsers, baseRequests = 500, 1500
		default:
			baseUsers, baseRequests = 200, 500
		}

		logger.Info("Starting load simulation",
			zap.Duration("duration", duration),
			zap.String("intensity", intensity),
			zap.Float64("base_users", baseUsers),
			zap.Float64("base_requests", baseRequests),
		)

		for time.Now().Before(endTime) {
			// Simulate varying load with some randomness
			users := baseUsers + (rand.Float64()-0.5)*baseUsers*0.3
			requests := baseRequests + (rand.Float64()-0.5)*baseRequests*0.3

			activeUsersGauge.Set(users)
			requestRateGauge.Set(requests)

			// Generate some business metrics during load
			if rand.Float64() < 0.3 { // 30% chance each iteration
				userRegistrations.WithLabelValues("web", "free").Inc()
			}
			if rand.Float64() < 0.5 { // 50% chance each iteration
				orderMetrics.WithLabelValues("completed", "credit_card", "us-east").Inc()
			}

			time.Sleep(1 * time.Second)
		}

		// Reset to baseline after simulation
		activeUsersGauge.Set(baseUsers * 0.3)
		requestRateGauge.Set(baseRequests * 0.3)

		logger.Info("Load simulation completed",
			zap.Duration("duration", duration),
			zap.String("intensity", intensity),
		)
	}()

	span.SetAttributes(
		attribute.String("load.intensity", intensity),
		attribute.String("load.duration", durationStr),
	)

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(map[string]interface{}{
		"status":  "success",
		"message": "Load simulation started",
		"configuration": map[string]interface{}{
			"duration":  durationStr,
			"intensity": intensity,
			"estimated_peak_users": map[string]interface{}{
				"low":    50,
				"medium": 200,
				"high":   500,
			}[intensity],
		},
		"timestamp": time.Now().Unix(),
	})
}

// Continuous Metrics Generation (Background Process)
func startContinuousMetrics() {
	go func() {
		ticker := time.NewTicker(15 * time.Second)
		defer ticker.Stop()

		logger.Info("Starting continuous background metrics generation")

		for {
			select {
			case <-ticker.C:
				// Generate baseline metrics every 15 seconds

				// Baseline business metrics
				userRegistrations.WithLabelValues("web", "free").Inc()
				if rand.Float64() < 0.7 {
					orderMetrics.WithLabelValues("completed", "credit_card", "us-east").Inc()
				}

				// Baseline system metrics
				cpuUsage := 20 + rand.Float64()*30 // 20-50% baseline
				cpuUsageGauge.Set(cpuUsage)

				memoryUsage := 2e9 + rand.Float64()*1e9 // 2-3GB baseline
				memoryUsageGauge.Set(memoryUsage)

				activeUsers := 100 + rand.Float64()*50 // 100-150 baseline users
				activeUsersGauge.Set(activeUsers)

				requestRate := 50 + rand.Float64()*50 // 50-100 req/s baseline
				requestRateGauge.Set(requestRate)
			}
		}
	}()
}

// Phase 2: Enhanced Logging Helper Functions

// Create log context from HTTP request
func createLogContext(r *http.Request) LogContext {
	requestID := getOrCreateRequestID(r)
	traceID := extractTraceID(r.Context())

	return LogContext{
		RequestID:   requestID,
		TraceID:     traceID,
		SpanID:      extractSpanID(r.Context()),
		UserID:      extractUserID(r),
		SessionID:   extractSessionID(r),
		ServiceName: serviceName,
		Version:     serviceVersion,
		Environment: environment,
	}
}

// Get or create request ID
func getOrCreateRequestID(r *http.Request) string {
	// Check if request ID already exists in context
	if reqID := r.Context().Value(RequestIDKey); reqID != nil {
		if id, ok := reqID.(string); ok {
			return id
		}
	}

	// Check X-Request-ID header
	if reqID := r.Header.Get("X-Request-ID"); reqID != "" {
		return reqID
	}

	// Generate new request ID
	return uuid.New().String()
}

// Extract trace ID from OpenTelemetry context
func extractTraceID(ctx context.Context) string {
	span := oteltrace.SpanFromContext(ctx)
	if span != nil && span.SpanContext().IsValid() {
		return span.SpanContext().TraceID().String()
	}
	return ""
}

// Extract span ID from OpenTelemetry context
func extractSpanID(ctx context.Context) string {
	span := oteltrace.SpanFromContext(ctx)
	if span != nil && span.SpanContext().IsValid() {
		return span.SpanContext().SpanID().String()
	}
	return ""
}

// Extract user ID from request (headers, JWT, etc.)
func extractUserID(r *http.Request) string {
	// Check X-User-ID header
	if userID := r.Header.Get("X-User-ID"); userID != "" {
		return userID
	}

	// For demo purposes, simulate user ID extraction
	if userID := r.URL.Query().Get("user_id"); userID != "" {
		return userID
	}

	return ""
}

// Extract session ID from request
func extractSessionID(r *http.Request) string {
	// Check X-Session-ID header
	if sessionID := r.Header.Get("X-Session-ID"); sessionID != "" {
		return sessionID
	}

	// Check for session cookie
	if cookie, err := r.Cookie("session_id"); err == nil {
		return cookie.Value
	}

	return ""
}

// Enhanced structured logging functions
func LogWithContext(level zapcore.Level, ctx context.Context, message string, fields ...zap.Field) {
	start := time.Now()
	defer func() {
		logProcessingDuration.WithLabelValues("log_with_context", level.String()).Observe(time.Since(start).Seconds())
	}()

	// Extract correlation context
	var logCtx LogContext
	if r := ctx.Value("request"); r != nil {
		if req, ok := r.(*http.Request); ok {
			logCtx = createLogContext(req)
		}
	}

	// Increment log metrics
	errorType := "none"
	if level == zapcore.ErrorLevel {
		for _, field := range fields {
			if field.Key == "error_type" {
				errorType = field.String
				break
			}
		}
	}

	logEntriesTotal.WithLabelValues(level.String(), serviceName, errorType).Inc()

	// Add correlation fields
	allFields := append(fields,
		zap.String("request_id", logCtx.RequestID),
		zap.String("trace_id", logCtx.TraceID),
		zap.String("span_id", logCtx.SpanID),
		zap.String("user_id", logCtx.UserID),
		zap.String("session_id", logCtx.SessionID),
	)

	switch level {
	case zapcore.DebugLevel:
		logger.Debug(message, allFields...)
	case zapcore.InfoLevel:
		logger.Info(message, allFields...)
	case zapcore.WarnLevel:
		logger.Warn(message, allFields...)
	case zapcore.ErrorLevel:
		logger.Error(message, allFields...)
	}
}

// Business event logging
func LogBusinessEvent(eventType string, data map[string]interface{}) {
	start := time.Now()
	defer func() {
		logProcessingDuration.WithLabelValues("business_event", "info").Observe(time.Since(start).Seconds())
	}()

	logEntriesTotal.WithLabelValues("info", serviceName, "none").Inc()

	fields := []zap.Field{
		zap.String("event_type", eventType),
		zap.String("category", "business"),
		zap.Any("data", data),
		zap.Time("event_timestamp", time.Now()),
	}

	logger.Info("Business event", fields...)
}

// Performance logging
func LogPerformance(operation string, duration time.Duration, additionalData map[string]interface{}) {
	start := time.Now()
	defer func() {
		logProcessingDuration.WithLabelValues("performance", "info").Observe(time.Since(start).Seconds())
	}()

	var m runtime.MemStats
	runtime.ReadMemStats(&m)

	logEntriesTotal.WithLabelValues("info", serviceName, "none").Inc()

	fields := []zap.Field{
		zap.String("operation", operation),
		zap.Duration("duration", duration),
		zap.Float64("duration_ms", float64(duration.Nanoseconds())/1e6),
		zap.Int64("memory_alloc", int64(m.Alloc)),
		zap.Int64("memory_sys", int64(m.Sys)),
		zap.Int("goroutines", runtime.NumGoroutine()),
		zap.String("category", "performance"),
	}

	if additionalData != nil {
		fields = append(fields, zap.Any("additional_data", additionalData))
	}

	logger.Info("Performance metric", fields...)
}

// Error logging with categorization
func LogError(ctx context.Context, errorType, errorCode, message string, err error, additionalData map[string]interface{}) {
	start := time.Now()
	defer func() {
		logProcessingDuration.WithLabelValues("error", "error").Observe(time.Since(start).Seconds())
	}()

	logEntriesTotal.WithLabelValues("error", serviceName, errorType).Inc()
	errorsByCategory.WithLabelValues(errorType, "high", serviceName).Inc()

	fields := []zap.Field{
		zap.String("error_type", errorType),
		zap.String("error_code", errorCode),
		zap.String("category", "error"),
	}

	if err != nil {
		fields = append(fields, zap.Error(err))
	}

	if additionalData != nil {
		fields = append(fields, zap.Any("additional_data", additionalData))
	}

	LogWithContext(zapcore.ErrorLevel, ctx, message, fields...)
}

// Phase 2: Enhanced request correlation middleware
func requestCorrelationMiddleware(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		start := time.Now()

		// Create or extract request ID
		requestID := getOrCreateRequestID(r)

		// Create enhanced context with correlation data
		ctx := context.WithValue(r.Context(), RequestIDKey, requestID)
		ctx = context.WithValue(ctx, StartTimeKey, start)
		ctx = context.WithValue(ctx, "request", r)

		// Add request ID to response headers for client correlation
		w.Header().Set("X-Request-ID", requestID)

		// Create new request with enriched context
		r = r.WithContext(ctx)

		// Log request start
		LogWithContext(zapcore.InfoLevel, ctx, "Request started",
			zap.String("method", r.Method),
			zap.String("path", r.URL.Path),
			zap.String("query", r.URL.RawQuery),
			zap.String("user_agent", r.UserAgent()),
			zap.String("remote_addr", r.RemoteAddr),
			zap.String("referer", r.Referer()),
		)

		// Wrap response writer to capture response data
		wrapped := &enhancedResponseWriter{
			ResponseWriter: w,
			statusCode:     200,
			bytesWritten:   0,
			startTime:      start,
		}

		// Process request
		next.ServeHTTP(wrapped, r)

		// Log request completion
		duration := time.Since(start)
		LogWithContext(zapcore.InfoLevel, ctx, "Request completed",
			zap.Int("status_code", wrapped.statusCode),
			zap.Duration("duration", duration),
			zap.Float64("duration_ms", float64(duration.Nanoseconds())/1e6),
			zap.Int64("response_size", wrapped.bytesWritten),
			zap.Float64("response_size_kb", float64(wrapped.bytesWritten)/1024),
		)

		// Log performance metrics
		LogPerformance("http_request", duration, map[string]interface{}{
			"method":        r.Method,
			"path":          r.URL.Path,
			"status_code":   wrapped.statusCode,
			"response_size": wrapped.bytesWritten,
		})
	})
}

// Enhanced response writer for better observability
type enhancedResponseWriter struct {
	http.ResponseWriter
	statusCode   int
	bytesWritten int64
	startTime    time.Time
}

func (rw *enhancedResponseWriter) WriteHeader(code int) {
	rw.statusCode = code
	rw.ResponseWriter.WriteHeader(code)
}

func (rw *enhancedResponseWriter) Write(data []byte) (int, error) {
	n, err := rw.ResponseWriter.Write(data)
	rw.bytesWritten += int64(n)
	return n, err
}

func prometheusMiddleware(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		start := time.Now()

		// Wrap response writer to capture status code
		wrapped := &responseWriter{ResponseWriter: w, statusCode: 200}

		next.ServeHTTP(wrapped, r)

		duration := time.Since(start).Seconds()

		httpRequestsTotal.WithLabelValues(
			r.Method,
			r.URL.Path,
			strconv.Itoa(wrapped.statusCode),
		).Inc()

		httpRequestDuration.WithLabelValues(
			r.Method,
			r.URL.Path,
		).Observe(duration)
	})
}

func main() {
	initLogger()
	defer logger.Sync()

	initTracer()

	// Start continuous background metrics generation
	startContinuousMetrics()

	logger.Info("Starting Example API server",
		zap.String("version", "1.0.0"),
		zap.Time("start_time", startTime),
	)

	r := mux.NewRouter()

	// Phase 2: Enhanced middleware stack
	// Add request correlation middleware first for enhanced logging
	r.Use(requestCorrelationMiddleware)
	// Add CORS middleware
	r.Use(corsMiddleware)
	// Add Prometheus middleware for metrics
	r.Use(prometheusMiddleware)

	// Health and info endpoints
	r.HandleFunc("/health", healthHandler).Methods("GET")
	r.HandleFunc("/", healthHandler).Methods("GET")

	// Monitoring test endpoints
	r.HandleFunc("/test/metrics", generateMetricsHandler).Methods("POST", "OPTIONS")
	r.HandleFunc("/test/logs", generateLogsHandler).Methods("POST", "OPTIONS")
	r.HandleFunc("/test/error", generateErrorHandler).Methods("POST", "OPTIONS")
	r.HandleFunc("/test/cpu", cpuLoadHandler).Methods("POST", "OPTIONS")
	r.HandleFunc("/test/memory", memoryLoadHandler).Methods("POST", "OPTIONS")
	r.HandleFunc("/test/trace", distributedTraceHandler).Methods("POST", "OPTIONS")

	// Phase 2: Enhanced logging test endpoints
	r.HandleFunc("/test/structured_logs", generateStructuredLogsHandler).Methods("POST", "OPTIONS")
	r.HandleFunc("/test/log_correlation", testLogCorrelationHandler).Methods("POST", "OPTIONS")
	r.HandleFunc("/test/error_categorization", testErrorCategorizationHandler).Methods("POST", "OPTIONS")

	// Prometheus metrics endpoint
	r.Handle("/metrics", promhttp.Handler())

	// Serve static files for the web UI
	r.PathPrefix("/static/").Handler(http.StripPrefix("/static/", http.FileServer(http.Dir("./static/"))))
	r.HandleFunc("/ui", func(w http.ResponseWriter, r *http.Request) {
		http.ServeFile(w, r, "./static/index.html")
	})

	// Add docs handler
	r.HandleFunc("/docs", docsHandler).Methods("GET")

	// Phase 1 endpoints
	r.HandleFunc("/test/business_metrics", generateBusinessMetricsHandler).Methods("POST", "OPTIONS")
	r.HandleFunc("/test/system_metrics", generateSystemMetricsHandler).Methods("POST", "OPTIONS")
	r.HandleFunc("/test/load_simulation", simulateLoadHandler).Methods("POST", "OPTIONS")

	LogBusinessEvent("server_ready", map[string]interface{}{
		"port":             "8080",
		"endpoints":        15,
		"middlewares":      []string{"requestCorrelation", "cors", "prometheus"},
		"ready_time":       time.Now(),
		"startup_duration": time.Since(startTime).String(),
	})

	logger.Info("Phase 2 Enhanced Server starting on port 8080",
		zap.String("service", serviceName),
		zap.String("version", serviceVersion),
		zap.Duration("startup_time", time.Since(startTime)),
	)
	log.Fatal(http.ListenAndServe(":8080", r))
}

// Phase 2: Enhanced Logging Test Handlers

// Generate structured logs with correlation
func generateStructuredLogsHandler(w http.ResponseWriter, r *http.Request) {
	ctx, span := tracer.Start(r.Context(), "generate_structured_logs")
	defer span.End()

	// Log various structured events with correlation
	LogWithContext(zapcore.InfoLevel, ctx, "User registration event",
		zap.String("event_type", "user_registration"),
		zap.String("user_email", "user@example.com"),
		zap.String("plan_type", "premium"),
		zap.String("source", "web"),
	)

	LogWithContext(zapcore.InfoLevel, ctx, "Order processing event",
		zap.String("event_type", "order_processing"),
		zap.String("order_id", "ORD-12345"),
		zap.Float64("amount", 99.99),
		zap.String("currency", "USD"),
		zap.String("status", "processing"),
	)

	LogWithContext(zapcore.WarnLevel, ctx, "Rate limit warning",
		zap.String("event_type", "rate_limit_warning"),
		zap.String("client_ip", r.RemoteAddr),
		zap.Int("current_requests", 85),
		zap.Int("limit", 100),
	)

	LogBusinessEvent("structured_logs_generated", map[string]interface{}{
		"log_count":    3,
		"log_types":    []string{"user_registration", "order_processing", "rate_limit_warning"},
		"generated_at": time.Now(),
	})

	span.SetAttributes(
		attribute.Int("logs.generated", 3),
		attribute.String("logs.type", "structured"),
	)

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(map[string]interface{}{
		"message":        "Generated 3 structured log entries with correlation",
		"status":         "success",
		"request_id":     r.Context().Value(RequestIDKey),
		"logs_generated": 3,
	})
}

// Test log correlation across multiple operations
func testLogCorrelationHandler(w http.ResponseWriter, r *http.Request) {
	ctx, span := tracer.Start(r.Context(), "test_log_correlation")
	defer span.End()

	// Simulate a complex business operation with multiple steps
	operationID := uuid.New().String()

	LogWithContext(zapcore.InfoLevel, ctx, "Starting complex operation",
		zap.String("operation_id", operationID),
		zap.String("operation_type", "order_fulfillment"),
		zap.String("phase", "initiation"),
	)

	// Simulate step 1: Validate order
	time.Sleep(50 * time.Millisecond)
	LogWithContext(zapcore.InfoLevel, ctx, "Order validation completed",
		zap.String("operation_id", operationID),
		zap.String("phase", "validation"),
		zap.Bool("validation_passed", true),
		zap.Duration("step_duration", 50*time.Millisecond),
	)

	// Simulate step 2: Process payment
	time.Sleep(100 * time.Millisecond)
	LogWithContext(zapcore.InfoLevel, ctx, "Payment processing completed",
		zap.String("operation_id", operationID),
		zap.String("phase", "payment"),
		zap.String("payment_gateway", "stripe"),
		zap.String("transaction_id", "txn_"+operationID[:8]),
		zap.Duration("step_duration", 100*time.Millisecond),
	)

	// Simulate step 3: Update inventory
	time.Sleep(30 * time.Millisecond)
	LogWithContext(zapcore.InfoLevel, ctx, "Inventory updated",
		zap.String("operation_id", operationID),
		zap.String("phase", "inventory"),
		zap.Int("items_updated", 3),
		zap.Duration("step_duration", 30*time.Millisecond),
	)

	LogWithContext(zapcore.InfoLevel, ctx, "Complex operation completed",
		zap.String("operation_id", operationID),
		zap.String("phase", "completion"),
		zap.Duration("total_duration", 180*time.Millisecond),
	)

	LogPerformance("order_fulfillment", 180*time.Millisecond, map[string]interface{}{
		"operation_id":      operationID,
		"steps_completed":   3,
		"total_duration_ms": 180,
	})

	span.SetAttributes(
		attribute.String("operation.id", operationID),
		attribute.String("operation.type", "order_fulfillment"),
		attribute.Int("operation.steps", 3),
	)

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(map[string]interface{}{
		"message":            "Log correlation test completed",
		"status":             "success",
		"operation_id":       operationID,
		"request_id":         r.Context().Value(RequestIDKey),
		"steps_logged":       4,
		"correlation_fields": []string{"operation_id", "request_id", "trace_id"},
	})
}

// Test error categorization and structured error logging
func testErrorCategorizationHandler(w http.ResponseWriter, r *http.Request) {
	ctx, span := tracer.Start(r.Context(), "test_error_categorization")
	defer span.End()

	// Generate different categories of errors
	errorCategories := []struct {
		category string
		code     string
		message  string
		severity string
	}{
		{"validation", "VAL001", "Invalid email format provided", "medium"},
		{"database", "DB002", "Connection timeout to user database", "high"},
		{"network", "NET003", "External API timeout", "medium"},
		{"security", "SEC004", "Invalid authentication token", "high"},
		{"business", "BIZ005", "Insufficient account balance", "low"},
	}

	for i, errInfo := range errorCategories {
		// Create a test error
		testErr := fmt.Errorf("simulated %s error: %s", errInfo.category, errInfo.message)

		LogError(ctx, errInfo.category, errInfo.code, errInfo.message, testErr, map[string]interface{}{
			"severity":    errInfo.severity,
			"error_index": i,
			"simulation":  true,
		})

		// Update error metrics
		errorsByCategory.WithLabelValues(errInfo.category, errInfo.severity, serviceName).Inc()

		// Small delay to spread out the logs
		time.Sleep(10 * time.Millisecond)
	}

	LogBusinessEvent("error_categorization_test", map[string]interface{}{
		"errors_generated":  len(errorCategories),
		"categories":        []string{"validation", "database", "network", "security", "business"},
		"test_completed_at": time.Now(),
	})

	span.SetAttributes(
		attribute.Int("errors.generated", len(errorCategories)),
		attribute.String("test.type", "error_categorization"),
	)

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(map[string]interface{}{
		"message":          "Error categorization test completed",
		"status":           "success",
		"errors_generated": len(errorCategories),
		"categories":       []string{"validation", "database", "network", "security", "business"},
		"request_id":       r.Context().Value(RequestIDKey),
	})
}
