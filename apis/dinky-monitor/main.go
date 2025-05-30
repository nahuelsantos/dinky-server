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

// Phase 3: Advanced Tracing & APM Structures
type ServiceDependency struct {
	ServiceName      string            `json:"service_name"`
	Operation        string            `json:"operation"`
	ResponseTime     time.Duration     `json:"response_time"`
	StatusCode       int               `json:"status_code"`
	ErrorRate        float64           `json:"error_rate"`
	RequestCount     int64             `json:"request_count"`
	Dependencies     []string          `json:"dependencies"`
	CustomAttributes map[string]string `json:"custom_attributes"`
}

type APMData struct {
	ServiceName   string              `json:"service_name"`
	TraceID       string              `json:"trace_id"`
	SpanID        string              `json:"span_id"`
	OperationName string              `json:"operation_name"`
	StartTime     time.Time           `json:"start_time"`
	Duration      time.Duration       `json:"duration"`
	StatusCode    int                 `json:"status_code"`
	ResourceUsage ResourceMetrics     `json:"resource_usage"`
	Dependencies  []ServiceDependency `json:"dependencies"`
	ErrorDetails  *APMError           `json:"error_details,omitempty"`
	CustomTags    map[string]string   `json:"custom_tags"`
}

type APMError struct {
	Type        string `json:"type"`
	Message     string `json:"message"`
	StackTrace  string `json:"stack_trace"`
	Impact      string `json:"impact"` // "low", "medium", "high", "critical"
	Recoverable bool   `json:"recoverable"`
}

type ResourceMetrics struct {
	CPUUsage       float64 `json:"cpu_usage_percent"`
	MemoryUsage    int64   `json:"memory_usage_bytes"`
	GoroutineCount int     `json:"goroutine_count"`
	HeapSize       int64   `json:"heap_size_bytes"`
	GCPause        float64 `json:"gc_pause_ms"`
	DiskIO         int64   `json:"disk_io_bytes"`
	NetworkIO      int64   `json:"network_io_bytes"`
}

type PerformanceProfile struct {
	Operation       string          `json:"operation"`
	P50ResponseTime float64         `json:"p50_response_time_ms"`
	P95ResponseTime float64         `json:"p95_response_time_ms"`
	P99ResponseTime float64         `json:"p99_response_time_ms"`
	ErrorRate       float64         `json:"error_rate_percent"`
	ThroughputRPS   float64         `json:"throughput_rps"`
	ResourceProfile ResourceMetrics `json:"resource_profile"`
	Bottlenecks     []string        `json:"bottlenecks"`
	Recommendations []string        `json:"recommendations"`
}

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
	serviceVersion = "4.0.0-phase4"
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

	// Phase 3: APM & Distributed Tracing Metrics
	traceDuration = prometheus.NewHistogramVec(
		prometheus.HistogramOpts{
			Name:    "trace_duration_seconds",
			Help:    "Distributed trace duration by operation and service",
			Buckets: []float64{0.001, 0.005, 0.01, 0.025, 0.05, 0.1, 0.25, 0.5, 1.0, 2.5, 5.0, 10.0},
		},
		[]string{"service", "operation", "status_code"},
	)

	spanDuration = prometheus.NewHistogramVec(
		prometheus.HistogramOpts{
			Name:    "span_duration_seconds",
			Help:    "Individual span duration by operation",
			Buckets: []float64{0.0001, 0.0005, 0.001, 0.005, 0.01, 0.025, 0.05, 0.1, 0.25, 0.5, 1.0},
		},
		[]string{"service", "operation", "span_kind"},
	)

	serviceDependencies = prometheus.NewCounterVec(
		prometheus.CounterOpts{
			Name: "service_dependencies_total",
			Help: "Service dependency call counts",
		},
		[]string{"source_service", "target_service", "operation", "status"},
	)

	apmResourceUsage = prometheus.NewGaugeVec(
		prometheus.GaugeOpts{
			Name: "apm_resource_usage",
			Help: "APM resource usage metrics",
		},
		[]string{"service", "resource_type", "operation"},
	)

	performanceAnomalies = prometheus.NewCounterVec(
		prometheus.CounterOpts{
			Name: "performance_anomalies_total",
			Help: "Detected performance anomalies",
		},
		[]string{"service", "anomaly_type", "severity"},
	)

	traceErrorRate = prometheus.NewGaugeVec(
		prometheus.GaugeOpts{
			Name: "trace_error_rate_percent",
			Help: "Error rate by service and operation",
		},
		[]string{"service", "operation"},
	)

	serviceThroughput = prometheus.NewGaugeVec(
		prometheus.GaugeOpts{
			Name: "service_throughput_rps",
			Help: "Service throughput in requests per second",
		},
		[]string{"service", "operation"},
	)

	// Phase 4: Alerting & Incident Management Metrics
	alertsTotal = prometheus.NewCounterVec(
		prometheus.CounterOpts{
			Name: "alerts_total",
			Help: "Total number of alerts fired",
		},
		[]string{"rule_name", "severity", "status"},
	)

	alertDuration = prometheus.NewHistogramVec(
		prometheus.HistogramOpts{
			Name:    "alert_duration_seconds",
			Help:    "Duration of alerts from firing to resolution",
			Buckets: []float64{60, 300, 900, 1800, 3600, 7200, 14400, 28800, 86400}, // 1m to 1d
		},
		[]string{"rule_name", "severity"},
	)

	incidentsTotal = prometheus.NewCounterVec(
		prometheus.CounterOpts{
			Name: "incidents_total",
			Help: "Total number of incidents",
		},
		[]string{"severity", "status", "affected_service"},
	)

	incidentDuration = prometheus.NewHistogramVec(
		prometheus.HistogramOpts{
			Name:    "incident_duration_seconds",
			Help:    "Duration of incidents from creation to resolution",
			Buckets: []float64{300, 900, 1800, 3600, 7200, 14400, 28800, 86400, 172800}, // 5m to 2d
		},
		[]string{"severity", "affected_service"},
	)

	mttrGauge = prometheus.NewGaugeVec(
		prometheus.GaugeOpts{
			Name: "mttr_seconds",
			Help: "Mean Time To Recovery in seconds",
		},
		[]string{"service", "severity"},
	)

	notificationsSent = prometheus.NewCounterVec(
		prometheus.CounterOpts{
			Name: "notifications_sent_total",
			Help: "Total notifications sent by channel",
		},
		[]string{"channel_type", "severity", "status"},
	)

	notificationLatency = prometheus.NewHistogramVec(
		prometheus.HistogramOpts{
			Name:    "notification_latency_seconds",
			Help:    "Latency of notification delivery",
			Buckets: []float64{0.1, 0.5, 1.0, 2.0, 5.0, 10.0, 30.0, 60.0},
		},
		[]string{"channel_type"},
	)

	alertRulesActive = prometheus.NewGauge(
		prometheus.GaugeOpts{
			Name: "alert_rules_active_total",
			Help: "Number of active alert rules",
		},
	)

	alertManagerHealth = prometheus.NewGaugeVec(
		prometheus.GaugeOpts{
			Name: "alert_manager_health",
			Help: "Health status of alert manager components",
		},
		[]string{"component"},
	)

	// Global logger and tracer
	logger       *zap.Logger
	tracer       oteltrace.Tracer
	alertManager *AlertManager
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
	prometheus.MustRegister(traceDuration)
	prometheus.MustRegister(spanDuration)
	prometheus.MustRegister(serviceDependencies)
	prometheus.MustRegister(apmResourceUsage)
	prometheus.MustRegister(performanceAnomalies)
	prometheus.MustRegister(traceErrorRate)
	prometheus.MustRegister(serviceThroughput)
	prometheus.MustRegister(alertsTotal)
	prometheus.MustRegister(alertDuration)
	prometheus.MustRegister(incidentsTotal)
	prometheus.MustRegister(incidentDuration)
	prometheus.MustRegister(mttrGauge)
	prometheus.MustRegister(notificationsSent)
	prometheus.MustRegister(notificationLatency)
	prometheus.MustRegister(alertRulesActive)
	prometheus.MustRegister(alertManagerHealth)
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

// Phase 4: Initialize Alert Manager
func initAlertManager() {
	alertManager = &AlertManager{
		Rules:                make(map[string]*AlertRule),
		ActiveAlerts:         make(map[string]*Alert),
		AlertHistory:         make([]*Alert, 0),
		NotificationChannels: make(map[string]*NotificationChannel),
		Incidents:            make(map[string]*Incident),
		SilencedRules:        make(map[string]time.Time),
	}

	// Initialize default alert rules
	initDefaultAlertRules()

	// Initialize default notification channels
	initDefaultNotificationChannels()

	// Set health indicators
	alertManagerHealth.WithLabelValues("rule_engine").Set(1)
	alertManagerHealth.WithLabelValues("notification_engine").Set(1)
	alertManagerHealth.WithLabelValues("incident_manager").Set(1)

	// Start alert evaluation engine
	go alertEvaluationEngine()

	// Start notification processor
	go notificationProcessor()

	logger.Info("Alert Manager initialized",
		zap.Int("default_rules", len(alertManager.Rules)),
		zap.Int("notification_channels", len(alertManager.NotificationChannels)),
	)
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

// Phase 3: Advanced APM & Tracing Functions

// Generate comprehensive resource metrics
func getResourceMetrics() ResourceMetrics {
	var m runtime.MemStats
	runtime.ReadMemStats(&m)

	return ResourceMetrics{
		CPUUsage:       float64(rand.Intn(80) + 10), // Simulated 10-90%
		MemoryUsage:    int64(m.Alloc),
		GoroutineCount: runtime.NumGoroutine(),
		HeapSize:       int64(m.HeapAlloc),
		GCPause:        float64(m.PauseNs[(m.NumGC+255)%256]) / 1e6, // Convert to ms
		DiskIO:         int64(rand.Intn(1000000)),                   // Simulated disk I/O
		NetworkIO:      int64(rand.Intn(500000)),                    // Simulated network I/O
	}
}

// Create APM data with tracing context
func createAPMData(ctx context.Context, operationName string, statusCode int, duration time.Duration) APMData {
	span := oteltrace.SpanFromContext(ctx)
	var traceID, spanID string

	if span != nil && span.SpanContext().IsValid() {
		traceID = span.SpanContext().TraceID().String()
		spanID = span.SpanContext().SpanID().String()
	}

	return APMData{
		ServiceName:   serviceName,
		TraceID:       traceID,
		SpanID:        spanID,
		OperationName: operationName,
		StartTime:     time.Now().Add(-duration),
		Duration:      duration,
		StatusCode:    statusCode,
		ResourceUsage: getResourceMetrics(),
		Dependencies:  generateDependencies(operationName),
		CustomTags: map[string]string{
			"version":     serviceVersion,
			"environment": environment,
			"node_id":     generateNodeID(),
		},
	}
}

// Generate simulated service dependencies
func generateDependencies(operation string) []ServiceDependency {
	dependencies := []ServiceDependency{}

	// Simulate different dependency patterns based on operation
	switch {
	case strings.Contains(operation, "user"):
		dependencies = append(dependencies, ServiceDependency{
			ServiceName:  "user-database",
			Operation:    "query_user",
			ResponseTime: time.Duration(rand.Intn(50)+10) * time.Millisecond,
			StatusCode:   200,
			ErrorRate:    float64(rand.Intn(5)),
			RequestCount: int64(rand.Intn(1000) + 100),
			Dependencies: []string{"auth-service", "cache-redis"},
			CustomAttributes: map[string]string{
				"database_type":   "postgresql",
				"connection_pool": "primary",
			},
		})
	case strings.Contains(operation, "order"):
		dependencies = append(dependencies,
			ServiceDependency{
				ServiceName:  "payment-gateway",
				Operation:    "process_payment",
				ResponseTime: time.Duration(rand.Intn(200)+50) * time.Millisecond,
				StatusCode:   200,
				ErrorRate:    float64(rand.Intn(3)),
				RequestCount: int64(rand.Intn(500) + 50),
				Dependencies: []string{"fraud-detection", "bank-api"},
			},
			ServiceDependency{
				ServiceName:  "inventory-service",
				Operation:    "reserve_items",
				ResponseTime: time.Duration(rand.Intn(30)+5) * time.Millisecond,
				StatusCode:   200,
				ErrorRate:    float64(rand.Intn(2)),
				RequestCount: int64(rand.Intn(800) + 200),
				Dependencies: []string{"warehouse-db", "cache-redis"},
			})
	}

	return dependencies
}

// Log APM data with enhanced metrics
func LogAPMData(apmData APMData) {
	// Update APM metrics
	traceDuration.WithLabelValues(
		apmData.ServiceName,
		apmData.OperationName,
		strconv.Itoa(apmData.StatusCode),
	).Observe(apmData.Duration.Seconds())

	spanDuration.WithLabelValues(
		apmData.ServiceName,
		apmData.OperationName,
		"server", // span kind
	).Observe(apmData.Duration.Seconds())

	// Update resource usage metrics
	apmResourceUsage.WithLabelValues(apmData.ServiceName, "cpu", apmData.OperationName).Set(apmData.ResourceUsage.CPUUsage)
	apmResourceUsage.WithLabelValues(apmData.ServiceName, "memory", apmData.OperationName).Set(float64(apmData.ResourceUsage.MemoryUsage))
	apmResourceUsage.WithLabelValues(apmData.ServiceName, "goroutines", apmData.OperationName).Set(float64(apmData.ResourceUsage.GoroutineCount))

	// Update service dependencies
	for _, dep := range apmData.Dependencies {
		status := "success"
		if dep.StatusCode >= 400 {
			status = "error"
		}
		serviceDependencies.WithLabelValues(
			apmData.ServiceName,
			dep.ServiceName,
			dep.Operation,
			status,
		).Inc()
	}

	// Calculate and update throughput
	serviceThroughput.WithLabelValues(apmData.ServiceName, apmData.OperationName).Set(
		float64(rand.Intn(100) + 10), // Simulated RPS
	)

	// Log structured APM data
	logger.Info("APM trace data",
		zap.String("trace_id", apmData.TraceID),
		zap.String("span_id", apmData.SpanID),
		zap.String("operation", apmData.OperationName),
		zap.Duration("duration", apmData.Duration),
		zap.Int("status_code", apmData.StatusCode),
		zap.Float64("cpu_usage", apmData.ResourceUsage.CPUUsage),
		zap.Int64("memory_usage", apmData.ResourceUsage.MemoryUsage),
		zap.Int("dependencies_count", len(apmData.Dependencies)),
		zap.String("category", "apm"),
	)
}

// Detect and log performance anomalies
func detectPerformanceAnomalies(operation string, duration time.Duration, resourceUsage ResourceMetrics) {
	// Define thresholds for anomaly detection
	var anomalies []string

	// High latency detection
	if duration > 2*time.Second {
		anomalies = append(anomalies, "high_latency")
		performanceAnomalies.WithLabelValues(serviceName, "high_latency", "critical").Inc()
	} else if duration > 1*time.Second {
		anomalies = append(anomalies, "elevated_latency")
		performanceAnomalies.WithLabelValues(serviceName, "elevated_latency", "warning").Inc()
	}

	// High CPU usage detection
	if resourceUsage.CPUUsage > 90 {
		anomalies = append(anomalies, "high_cpu")
		performanceAnomalies.WithLabelValues(serviceName, "high_cpu", "critical").Inc()
	} else if resourceUsage.CPUUsage > 70 {
		anomalies = append(anomalies, "elevated_cpu")
		performanceAnomalies.WithLabelValues(serviceName, "elevated_cpu", "warning").Inc()
	}

	// Memory usage detection
	if resourceUsage.MemoryUsage > 1e9 { // > 1GB
		anomalies = append(anomalies, "high_memory")
		performanceAnomalies.WithLabelValues(serviceName, "high_memory", "warning").Inc()
	}

	// Too many goroutines
	if resourceUsage.GoroutineCount > 1000 {
		anomalies = append(anomalies, "goroutine_leak")
		performanceAnomalies.WithLabelValues(serviceName, "goroutine_leak", "critical").Inc()
	}

	// Log anomalies if detected
	if len(anomalies) > 0 {
		logger.Warn("Performance anomalies detected",
			zap.String("operation", operation),
			zap.Strings("anomalies", anomalies),
			zap.Duration("duration", duration),
			zap.Float64("cpu_usage", resourceUsage.CPUUsage),
			zap.Int64("memory_usage", resourceUsage.MemoryUsage),
			zap.Int("goroutine_count", resourceUsage.GoroutineCount),
			zap.String("category", "performance_anomaly"),
		)
	}
}

// Enhanced tracing middleware
func enhancedTracingMiddleware(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		start := time.Now()

		// Create enhanced span with custom attributes
		ctx, span := tracer.Start(r.Context(), fmt.Sprintf("%s %s", r.Method, r.URL.Path))
		defer span.End()

		// Add custom span attributes
		span.SetAttributes(
			attribute.String("http.method", r.Method),
			attribute.String("http.url", r.URL.String()),
			attribute.String("http.scheme", r.URL.Scheme),
			attribute.String("http.host", r.Host),
			attribute.String("user_agent", r.UserAgent()),
			attribute.String("service.name", serviceName),
			attribute.String("service.version", serviceVersion),
			attribute.String("environment", environment),
		)

		// Create enhanced response writer
		wrapped := &enhancedResponseWriter{
			ResponseWriter: w,
			statusCode:     200,
			bytesWritten:   0,
			startTime:      start,
		}

		// Process request
		next.ServeHTTP(wrapped, r.WithContext(ctx))

		duration := time.Since(start)

		// Add response attributes to span
		span.SetAttributes(
			attribute.Int("http.status_code", wrapped.statusCode),
			attribute.Int64("http.response_size", wrapped.bytesWritten),
			attribute.String("http.response_time_ms", fmt.Sprintf("%.2f", float64(duration.Nanoseconds())/1e6)),
		)

		// Set span status based on HTTP status code
		if wrapped.statusCode >= 400 {
			span.SetAttributes(attribute.Bool("error", true))
		}

		// Create and log APM data
		apmData := createAPMData(ctx, fmt.Sprintf("%s %s", r.Method, r.URL.Path), wrapped.statusCode, duration)
		LogAPMData(apmData)

		// Detect performance anomalies
		detectPerformanceAnomalies(apmData.OperationName, duration, apmData.ResourceUsage)
	})
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
	initAlertManager()

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

	// Phase 4: Alerting & Incident Management test endpoints
	r.HandleFunc("/test/alert_rules", testAlertRulesHandler).Methods("POST", "OPTIONS")
	r.HandleFunc("/test/fire_alert", testFireAlertHandler).Methods("POST", "OPTIONS")
	r.HandleFunc("/test/incident_management", testIncidentManagementHandler).Methods("POST", "OPTIONS")
	r.HandleFunc("/test/notification_channels", testNotificationChannelsHandler).Methods("POST", "OPTIONS")
	r.HandleFunc("/alerts/active", getActiveAlertsHandler).Methods("GET", "OPTIONS")
	r.HandleFunc("/incidents/active", getActiveIncidentsHandler).Methods("GET", "OPTIONS")

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

	// Phase 3: APM & Distributed Tracing test endpoints
	r.HandleFunc("/test/apm_trace", generateAPMTraceHandler).Methods("POST", "OPTIONS")
	r.HandleFunc("/test/service_dependency", testServiceDependencyHandler).Methods("POST", "OPTIONS")
	r.HandleFunc("/test/performance_analysis", testPerformanceAnalysisHandler).Methods("POST", "OPTIONS")
	r.HandleFunc("/test/anomaly_detection", testAnomalyDetectionHandler).Methods("POST", "OPTIONS")
	r.HandleFunc("/apm/service_map", serviceMapHandler).Methods("GET", "OPTIONS")

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

// Phase 3: APM & Distributed Tracing Test Handlers

// Generate comprehensive APM trace data
func generateAPMTraceHandler(w http.ResponseWriter, r *http.Request) {
	ctx, span := tracer.Start(r.Context(), "generate_apm_trace")
	defer span.End()

	start := time.Now()

	// Simulate complex multi-service operation
	operationName := "complex_business_operation"

	// Create child spans for different operations
	userServiceSpan := createChildSpan(ctx, "user-service-call", 150*time.Millisecond)
	orderServiceSpan := createChildSpan(ctx, "order-service-call", 300*time.Millisecond)
	paymentServiceSpan := createChildSpan(ctx, "payment-service-call", 500*time.Millisecond)

	duration := time.Since(start)

	// Create comprehensive APM data
	apmData := createAPMData(ctx, operationName, 200, duration)
	LogAPMData(apmData)

	// Generate detailed performance profile
	profile := PerformanceProfile{
		Operation:       operationName,
		P50ResponseTime: 250.0,
		P95ResponseTime: 800.0,
		P99ResponseTime: 1200.0,
		ErrorRate:       2.5,
		ThroughputRPS:   45.0,
		ResourceProfile: apmData.ResourceUsage,
		Bottlenecks:     []string{"database_connection_pool", "external_api_latency"},
		Recommendations: []string{"increase_connection_pool_size", "implement_caching", "optimize_database_queries"},
	}

	span.SetAttributes(
		attribute.String("apm.operation", operationName),
		attribute.Float64("apm.p95_latency", profile.P95ResponseTime),
		attribute.Float64("apm.error_rate", profile.ErrorRate),
		attribute.Int("apm.child_spans", 3),
	)

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(map[string]interface{}{
		"message":             "APM trace data generated successfully",
		"status":              "success",
		"trace_id":            apmData.TraceID,
		"span_id":             apmData.SpanID,
		"operation":           operationName,
		"duration_ms":         float64(duration.Nanoseconds()) / 1e6,
		"child_spans":         []string{userServiceSpan, orderServiceSpan, paymentServiceSpan},
		"performance_profile": profile,
		"dependencies_count":  len(apmData.Dependencies),
		"anomalies_detected":  checkForAnomalies(profile),
	})
}

// Test service dependency mapping
func testServiceDependencyHandler(w http.ResponseWriter, r *http.Request) {
	ctx, span := tracer.Start(r.Context(), "test_service_dependency")
	defer span.End()

	// Generate service dependency map
	serviceDeps := map[string][]ServiceDependency{
		"dinky-monitor": {
			{
				ServiceName:      "user-database",
				Operation:        "user_lookup",
				ResponseTime:     time.Duration(rand.Intn(100)+20) * time.Millisecond,
				StatusCode:       200,
				ErrorRate:        float64(rand.Intn(5)),
				RequestCount:     int64(rand.Intn(1000) + 500),
				Dependencies:     []string{"auth-service", "cache-redis"},
				CustomAttributes: map[string]string{"database_type": "postgresql", "region": "us-east-1"},
			},
			{
				ServiceName:      "payment-gateway",
				Operation:        "process_payment",
				ResponseTime:     time.Duration(rand.Intn(300)+100) * time.Millisecond,
				StatusCode:       200,
				ErrorRate:        float64(rand.Intn(3)),
				RequestCount:     int64(rand.Intn(500) + 200),
				Dependencies:     []string{"fraud-detection", "bank-api", "audit-service"},
				CustomAttributes: map[string]string{"provider": "stripe", "region": "us-east-1"},
			},
			{
				ServiceName:      "notification-service",
				Operation:        "send_notification",
				ResponseTime:     time.Duration(rand.Intn(50)+10) * time.Millisecond,
				StatusCode:       200,
				ErrorRate:        float64(rand.Intn(2)),
				RequestCount:     int64(rand.Intn(2000) + 1000),
				Dependencies:     []string{"email-provider", "sms-provider", "push-service"},
				CustomAttributes: map[string]string{"provider": "sendgrid", "batch_size": "100"},
			},
		},
	}

	// Update service dependency metrics
	for sourceSvc, deps := range serviceDeps {
		for _, dep := range deps {
			status := "success"
			if dep.StatusCode >= 400 {
				status = "error"
			}
			serviceDependencies.WithLabelValues(sourceSvc, dep.ServiceName, dep.Operation, status).Add(float64(dep.RequestCount))

			// Update error rates
			traceErrorRate.WithLabelValues(dep.ServiceName, dep.Operation).Set(dep.ErrorRate)
		}
	}

	span.SetAttributes(
		attribute.Int("dependencies.total", len(serviceDeps["dinky-monitor"])),
		attribute.String("test.type", "service_dependency_mapping"),
	)

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(map[string]interface{}{
		"message":            "Service dependency mapping completed",
		"status":             "success",
		"service_map":        serviceDeps,
		"total_dependencies": len(serviceDeps["dinky-monitor"]),
		"trace_id":           extractTraceID(ctx),
		"analysis": map[string]interface{}{
			"high_latency_services": []string{"payment-gateway"},
			"high_volume_services":  []string{"notification-service"},
			"critical_path":         []string{"user-database", "payment-gateway"},
		},
	})
}

// Test performance analysis and profiling
func testPerformanceAnalysisHandler(w http.ResponseWriter, r *http.Request) {
	ctx, span := tracer.Start(r.Context(), "test_performance_analysis")
	defer span.End()

	// Generate performance profiles for different operations
	operations := []string{"user_registration", "order_processing", "payment_verification", "inventory_update"}
	profiles := make(map[string]PerformanceProfile)

	for _, op := range operations {
		profile := PerformanceProfile{
			Operation:       op,
			P50ResponseTime: float64(rand.Intn(200) + 50),
			P95ResponseTime: float64(rand.Intn(800) + 200),
			P99ResponseTime: float64(rand.Intn(2000) + 800),
			ErrorRate:       float64(rand.Intn(10)),
			ThroughputRPS:   float64(rand.Intn(100) + 10),
			ResourceProfile: getResourceMetrics(),
			Bottlenecks:     generateBottlenecks(),
			Recommendations: generateRecommendations(),
		}
		profiles[op] = profile

		// Update performance metrics
		traceDuration.WithLabelValues(serviceName, op, "200").Observe(profile.P95ResponseTime / 1000)
		serviceThroughput.WithLabelValues(serviceName, op).Set(profile.ThroughputRPS)
		traceErrorRate.WithLabelValues(serviceName, op).Set(profile.ErrorRate)
	}

	// Analyze overall system performance
	systemAnalysis := analyzeSystemPerformance(profiles)

	span.SetAttributes(
		attribute.Int("operations.analyzed", len(operations)),
		attribute.Float64("system.avg_latency", systemAnalysis["avg_p95_latency"].(float64)),
		attribute.Float64("system.total_throughput", systemAnalysis["total_throughput"].(float64)),
	)

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(map[string]interface{}{
		"message":            "Performance analysis completed",
		"status":             "success",
		"operation_profiles": profiles,
		"system_analysis":    systemAnalysis,
		"trace_id":           extractTraceID(ctx),
		"recommendations":    systemAnalysis["recommendations"],
	})
}

// Test anomaly detection
func testAnomalyDetectionHandler(w http.ResponseWriter, r *http.Request) {
	ctx, span := tracer.Start(r.Context(), "test_anomaly_detection")
	defer span.End()

	// Simulate various performance anomalies
	anomalies := []map[string]interface{}{}

	// Generate high latency anomaly
	if rand.Float32() < 0.3 {
		detectPerformanceAnomalies("slow_database_query", 3*time.Second, ResourceMetrics{
			CPUUsage:       95.0,
			MemoryUsage:    2e9,
			GoroutineCount: 500,
		})
		anomalies = append(anomalies, map[string]interface{}{
			"type":        "high_latency",
			"operation":   "slow_database_query",
			"severity":    "critical",
			"duration_ms": 3000,
			"threshold":   1000,
		})
	}

	// Generate memory leak anomaly
	if rand.Float32() < 0.2 {
		detectPerformanceAnomalies("memory_intensive_operation", 500*time.Millisecond, ResourceMetrics{
			CPUUsage:       45.0,
			MemoryUsage:    2e9, // 2GB
			GoroutineCount: 200,
		})
		anomalies = append(anomalies, map[string]interface{}{
			"type":         "high_memory_usage",
			"operation":    "memory_intensive_operation",
			"severity":     "warning",
			"memory_usage": "2GB",
			"threshold":    "1GB",
		})
	}

	// Generate goroutine leak anomaly
	if rand.Float32() < 0.15 {
		detectPerformanceAnomalies("goroutine_leak_operation", 200*time.Millisecond, ResourceMetrics{
			CPUUsage:       60.0,
			MemoryUsage:    500e6,
			GoroutineCount: 1500, // High goroutine count
		})
		anomalies = append(anomalies, map[string]interface{}{
			"type":            "goroutine_leak",
			"operation":       "goroutine_leak_operation",
			"severity":        "critical",
			"goroutine_count": 1500,
			"threshold":       1000,
		})
	}

	span.SetAttributes(
		attribute.Int("anomalies.detected", len(anomalies)),
		attribute.String("test.type", "anomaly_detection"),
	)

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(map[string]interface{}{
		"message":            "Anomaly detection test completed",
		"status":             "success",
		"anomalies_detected": len(anomalies),
		"anomalies":          anomalies,
		"trace_id":           extractTraceID(ctx),
		"detection_rules": map[string]interface{}{
			"latency_threshold_ms":  1000,
			"memory_threshold_gb":   1.0,
			"goroutine_threshold":   1000,
			"cpu_threshold_percent": 90,
			"error_rate_threshold":  10.0,
		},
	})
}

// Service map visualization endpoint
func serviceMapHandler(w http.ResponseWriter, r *http.Request) {
	ctx, span := tracer.Start(r.Context(), "service_map")
	defer span.End()

	// Generate comprehensive service map
	serviceMap := map[string]interface{}{
		"nodes": []map[string]interface{}{
			{
				"id":                  "dinky-monitor",
				"name":                "Dinky Monitor",
				"type":                "application",
				"health":              "healthy",
				"version":             serviceVersion,
				"requests_per_minute": rand.Intn(1000) + 500,
				"error_rate":          float64(rand.Intn(5)),
				"avg_response_time":   float64(rand.Intn(200) + 50),
			},
			{
				"id":                  "user-database",
				"name":                "User Database",
				"type":                "database",
				"health":              "healthy",
				"version":             "postgresql-14",
				"requests_per_minute": rand.Intn(2000) + 1000,
				"error_rate":          float64(rand.Intn(2)),
				"avg_response_time":   float64(rand.Intn(100) + 20),
			},
			{
				"id":                  "payment-gateway",
				"name":                "Payment Gateway",
				"type":                "external_service",
				"health":              "degraded",
				"version":             "stripe-v3",
				"requests_per_minute": rand.Intn(500) + 200,
				"error_rate":          float64(rand.Intn(8) + 2),
				"avg_response_time":   float64(rand.Intn(400) + 100),
			},
			{
				"id":                  "notification-service",
				"name":                "Notification Service",
				"type":                "microservice",
				"health":              "healthy",
				"version":             "v2.1.0",
				"requests_per_minute": rand.Intn(3000) + 1500,
				"error_rate":          float64(rand.Intn(3)),
				"avg_response_time":   float64(rand.Intn(80) + 20),
			},
		},
		"edges": []map[string]interface{}{
			{
				"source":        "dinky-monitor",
				"target":        "user-database",
				"operation":     "user_lookup",
				"request_count": rand.Intn(1000) + 500,
				"avg_latency":   float64(rand.Intn(50) + 20),
				"error_rate":    float64(rand.Intn(3)),
			},
			{
				"source":        "dinky-monitor",
				"target":        "payment-gateway",
				"operation":     "process_payment",
				"request_count": rand.Intn(500) + 200,
				"avg_latency":   float64(rand.Intn(300) + 100),
				"error_rate":    float64(rand.Intn(5) + 2),
			},
			{
				"source":        "dinky-monitor",
				"target":        "notification-service",
				"operation":     "send_notification",
				"request_count": rand.Intn(2000) + 1000,
				"avg_latency":   float64(rand.Intn(50) + 10),
				"error_rate":    float64(rand.Intn(2)),
			},
		},
		"metrics": map[string]interface{}{
			"total_services":    4,
			"healthy_services":  3,
			"degraded_services": 1,
			"total_requests":    calculateTotalRequests(),
			"avg_error_rate":    calculateAvgErrorRate(),
		},
	}

	span.SetAttributes(
		attribute.Int("service_map.nodes", len(serviceMap["nodes"].([]map[string]interface{}))),
		attribute.Int("service_map.edges", len(serviceMap["edges"].([]map[string]interface{}))),
	)

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(map[string]interface{}{
		"message":      "Service map generated successfully",
		"status":       "success",
		"service_map":  serviceMap,
		"trace_id":     extractTraceID(ctx),
		"generated_at": time.Now(),
	})
}

// Helper functions for Phase 3

func createChildSpan(ctx context.Context, operationName string, duration time.Duration) string {
	_, span := tracer.Start(ctx, operationName)
	defer span.End()

	// Simulate work
	time.Sleep(duration)

	span.SetAttributes(
		attribute.String("span.kind", "client"),
		attribute.String("operation.duration", duration.String()),
	)

	return span.SpanContext().SpanID().String()
}

func checkForAnomalies(profile PerformanceProfile) []string {
	var anomalies []string

	if profile.P95ResponseTime > 1000 {
		anomalies = append(anomalies, "high_p95_latency")
	}
	if profile.ErrorRate > 5.0 {
		anomalies = append(anomalies, "high_error_rate")
	}
	if profile.ThroughputRPS < 10 {
		anomalies = append(anomalies, "low_throughput")
	}

	return anomalies
}

func generateBottlenecks() []string {
	bottlenecks := [][]string{
		{"database_connection_pool", "slow_queries"},
		{"external_api_latency", "network_timeout"},
		{"memory_allocation", "garbage_collection"},
		{"cpu_intensive_operations", "thread_contention"},
		{"disk_io", "cache_misses"},
	}

	selected := bottlenecks[rand.Intn(len(bottlenecks))]
	return selected
}

func generateRecommendations() []string {
	recommendations := [][]string{
		{"increase_connection_pool_size", "optimize_database_queries"},
		{"implement_caching", "add_request_timeouts"},
		{"optimize_memory_usage", "tune_garbage_collector"},
		{"parallelize_operations", "reduce_lock_contention"},
		{"implement_circuit_breaker", "add_retry_logic"},
	}

	selected := recommendations[rand.Intn(len(recommendations))]
	return selected
}

func analyzeSystemPerformance(profiles map[string]PerformanceProfile) map[string]interface{} {
	var totalLatency, totalThroughput, totalErrorRate float64
	var criticalOperations []string

	for op, profile := range profiles {
		totalLatency += profile.P95ResponseTime
		totalThroughput += profile.ThroughputRPS
		totalErrorRate += profile.ErrorRate

		if profile.P95ResponseTime > 800 || profile.ErrorRate > 5 {
			criticalOperations = append(criticalOperations, op)
		}
	}

	avgLatency := totalLatency / float64(len(profiles))
	avgErrorRate := totalErrorRate / float64(len(profiles))

	return map[string]interface{}{
		"avg_p95_latency":     avgLatency,
		"total_throughput":    totalThroughput,
		"avg_error_rate":      avgErrorRate,
		"critical_operations": criticalOperations,
		"recommendations": []string{
			"Monitor critical operations closely",
			"Implement performance alerts",
			"Consider scaling critical services",
		},
	}
}

func calculateTotalRequests() int {
	return rand.Intn(10000) + 5000
}

func calculateAvgErrorRate() float64 {
	return float64(rand.Intn(5)) + rand.Float64()
}

// Phase 4: Alerting & Incident Management Structures
type AlertRule struct {
	ID          string            `json:"id"`
	Name        string            `json:"name"`
	Description string            `json:"description"`
	Query       string            `json:"query"`
	Threshold   AlertThreshold    `json:"threshold"`
	Severity    string            `json:"severity"` // "info", "warning", "critical"
	Duration    time.Duration     `json:"duration"`
	Labels      map[string]string `json:"labels"`
	Annotations map[string]string `json:"annotations"`
	Enabled     bool              `json:"enabled"`
	CreatedAt   time.Time         `json:"created_at"`
	UpdatedAt   time.Time         `json:"updated_at"`
}

type AlertThreshold struct {
	Operator string  `json:"operator"` // "gt", "lt", "eq", "gte", "lte"
	Value    float64 `json:"value"`
}

type Alert struct {
	ID           string            `json:"id"`
	RuleID       string            `json:"rule_id"`
	RuleName     string            `json:"rule_name"`
	Status       string            `json:"status"` // "firing", "resolved", "silenced"
	Severity     string            `json:"severity"`
	Message      string            `json:"message"`
	Description  string            `json:"description"`
	StartsAt     time.Time         `json:"starts_at"`
	EndsAt       *time.Time        `json:"ends_at,omitempty"`
	Duration     time.Duration     `json:"duration"`
	Labels       map[string]string `json:"labels"`
	Annotations  map[string]string `json:"annotations"`
	Value        float64           `json:"value"`
	Threshold    float64           `json:"threshold"`
	GeneratorURL string            `json:"generator_url"`
}

type Incident struct {
	ID              string           `json:"id"`
	Title           string           `json:"title"`
	Description     string           `json:"description"`
	Status          string           `json:"status"` // "open", "investigating", "resolved", "closed"
	Severity        string           `json:"severity"`
	Priority        string           `json:"priority"` // "low", "medium", "high", "critical"
	AssignedTo      string           `json:"assigned_to"`
	CreatedBy       string           `json:"created_by"`
	CreatedAt       time.Time        `json:"created_at"`
	UpdatedAt       time.Time        `json:"updated_at"`
	ResolvedAt      *time.Time       `json:"resolved_at,omitempty"`
	AffectedService string           `json:"affected_service"`
	RelatedAlerts   []string         `json:"related_alerts"`
	Tags            []string         `json:"tags"`
	Timeline        []IncidentUpdate `json:"timeline"`
	Metrics         IncidentMetrics  `json:"metrics"`
	PostMortem      *PostMortem      `json:"post_mortem,omitempty"`
}

type IncidentUpdate struct {
	ID        string    `json:"id"`
	Timestamp time.Time `json:"timestamp"`
	Author    string    `json:"author"`
	Type      string    `json:"type"` // "status_change", "comment", "escalation", "resolution"
	Message   string    `json:"message"`
	OldValue  string    `json:"old_value,omitempty"`
	NewValue  string    `json:"new_value,omitempty"`
}

type IncidentMetrics struct {
	TimeToDetection   time.Duration `json:"time_to_detection"`
	TimeToAcknowledge time.Duration `json:"time_to_acknowledge"`
	TimeToResolve     time.Duration `json:"time_to_resolve"`
	MTTR              time.Duration `json:"mttr"` // Mean Time To Recovery
	Downtime          time.Duration `json:"downtime"`
}

type PostMortem struct {
	ID             string    `json:"id"`
	IncidentID     string    `json:"incident_id"`
	Summary        string    `json:"summary"`
	RootCause      string    `json:"root_cause"`
	Timeline       string    `json:"timeline"`
	Impact         string    `json:"impact"`
	ActionItems    []string  `json:"action_items"`
	LessonsLearned []string  `json:"lessons_learned"`
	CreatedBy      string    `json:"created_by"`
	CreatedAt      time.Time `json:"created_at"`
}

type NotificationChannel struct {
	ID         string            `json:"id"`
	Name       string            `json:"name"`
	Type       string            `json:"type"` // "email", "slack", "webhook", "pagerduty"
	Config     map[string]string `json:"config"`
	Enabled    bool              `json:"enabled"`
	Conditions []string          `json:"conditions"` // severity levels or labels
	RateLimits RateLimit         `json:"rate_limits"`
	CreatedAt  time.Time         `json:"created_at"`
	UpdatedAt  time.Time         `json:"updated_at"`
}

type RateLimit struct {
	MaxAlerts    int           `json:"max_alerts"`
	TimeWindow   time.Duration `json:"time_window"`
	GroupByLabel string        `json:"group_by_label"`
}

type AlertManager struct {
	Rules                map[string]*AlertRule
	ActiveAlerts         map[string]*Alert
	AlertHistory         []*Alert
	NotificationChannels map[string]*NotificationChannel
	Incidents            map[string]*Incident
	SilencedRules        map[string]time.Time // ruleID -> until when
}

// Phase 4: Alerting & Incident Management Implementation

// Initialize default alert rules
func initDefaultAlertRules() {
	rules := []*AlertRule{
		{
			ID:          "high-cpu-usage",
			Name:        "High CPU Usage",
			Description: "CPU usage is above 80% for more than 5 minutes",
			Query:       "simulated_cpu_usage_percent > 80",
			Threshold:   AlertThreshold{Operator: "gt", Value: 80},
			Severity:    "warning",
			Duration:    5 * time.Minute,
			Labels:      map[string]string{"team": "infrastructure", "component": "cpu"},
			Annotations: map[string]string{"runbook": "https://docs.company.com/runbooks/high-cpu"},
			Enabled:     true,
			CreatedAt:   time.Now(),
			UpdatedAt:   time.Now(),
		},
		{
			ID:          "high-memory-usage",
			Name:        "High Memory Usage",
			Description: "Memory usage is above 2GB for more than 3 minutes",
			Query:       "simulated_memory_usage_bytes > 2147483648",
			Threshold:   AlertThreshold{Operator: "gt", Value: 2147483648},
			Severity:    "critical",
			Duration:    3 * time.Minute,
			Labels:      map[string]string{"team": "infrastructure", "component": "memory"},
			Annotations: map[string]string{"runbook": "https://docs.company.com/runbooks/high-memory"},
			Enabled:     true,
			CreatedAt:   time.Now(),
			UpdatedAt:   time.Now(),
		},
		{
			ID:          "high-error-rate",
			Name:        "High Error Rate",
			Description: "Error rate is above 5% for more than 2 minutes",
			Query:       "error_rate_percent > 5",
			Threshold:   AlertThreshold{Operator: "gt", Value: 5},
			Severity:    "critical",
			Duration:    2 * time.Minute,
			Labels:      map[string]string{"team": "backend", "component": "api"},
			Annotations: map[string]string{"runbook": "https://docs.company.com/runbooks/high-error-rate"},
			Enabled:     true,
			CreatedAt:   time.Now(),
			UpdatedAt:   time.Now(),
		},
		{
			ID:          "low-throughput",
			Name:        "Low Service Throughput",
			Description: "Service throughput is below 10 RPS for more than 5 minutes",
			Query:       "service_throughput_rps < 10",
			Threshold:   AlertThreshold{Operator: "lt", Value: 10},
			Severity:    "warning",
			Duration:    5 * time.Minute,
			Labels:      map[string]string{"team": "backend", "component": "performance"},
			Annotations: map[string]string{"runbook": "https://docs.company.com/runbooks/low-throughput"},
			Enabled:     true,
			CreatedAt:   time.Now(),
			UpdatedAt:   time.Now(),
		},
	}

	for _, rule := range rules {
		alertManager.Rules[rule.ID] = rule
	}

	alertRulesActive.Set(float64(len(alertManager.Rules)))
}

// Initialize default notification channels
func initDefaultNotificationChannels() {
	channels := []*NotificationChannel{
		{
			ID:   "slack-critical",
			Name: "Slack Critical Alerts",
			Type: "slack",
			Config: map[string]string{
				"webhook_url": "https://hooks.slack.com/services/EXAMPLE/CRITICAL",
				"channel":     "#alerts-critical",
				"username":    "AlertBot",
			},
			Enabled:    true,
			Conditions: []string{"critical"},
			RateLimits: RateLimit{MaxAlerts: 10, TimeWindow: 5 * time.Minute, GroupByLabel: "severity"},
			CreatedAt:  time.Now(),
			UpdatedAt:  time.Now(),
		},
		{
			ID:   "email-infrastructure",
			Name: "Infrastructure Team Email",
			Type: "email",
			Config: map[string]string{
				"smtp_server": "smtp.company.com:587",
				"recipients":  "infrastructure@company.com,oncall@company.com",
				"from":        "alerts@company.com",
			},
			Enabled:    true,
			Conditions: []string{"critical", "warning"},
			RateLimits: RateLimit{MaxAlerts: 5, TimeWindow: 10 * time.Minute, GroupByLabel: "team"},
			CreatedAt:  time.Now(),
			UpdatedAt:  time.Now(),
		},
		{
			ID:   "webhook-incident",
			Name: "Incident Management Webhook",
			Type: "webhook",
			Config: map[string]string{
				"url":     "https://api.company.com/incidents/webhook",
				"method":  "POST",
				"headers": "Content-Type:application/json,Authorization:Bearer TOKEN",
			},
			Enabled:    true,
			Conditions: []string{"critical"},
			RateLimits: RateLimit{MaxAlerts: 20, TimeWindow: 1 * time.Minute, GroupByLabel: "rule_name"},
			CreatedAt:  time.Now(),
			UpdatedAt:  time.Now(),
		},
	}

	for _, channel := range channels {
		alertManager.NotificationChannels[channel.ID] = channel
	}
}

// Alert evaluation engine - runs continuously to check alert conditions
func alertEvaluationEngine() {
	ticker := time.NewTicker(30 * time.Second)
	defer ticker.Stop()

	logger.Info("Alert evaluation engine started", zap.Duration("interval", 30*time.Second))

	for {
		select {
		case <-ticker.C:
			evaluateAlertRules()
		}
	}
}

// Evaluate all active alert rules
func evaluateAlertRules() {
	for _, rule := range alertManager.Rules {
		if !rule.Enabled {
			continue
		}

		// Check if rule is silenced
		if silencedUntil, exists := alertManager.SilencedRules[rule.ID]; exists {
			if time.Now().Before(silencedUntil) {
				continue
			} else {
				// Remove expired silence
				delete(alertManager.SilencedRules, rule.ID)
			}
		}

		// Simulate alert evaluation (in real implementation, this would query metrics)
		shouldFire := evaluateRule(rule)

		if shouldFire {
			fireAlert(rule)
		} else {
			resolveAlert(rule.ID)
		}
	}
}

// Simulate rule evaluation based on current metrics
func evaluateRule(rule *AlertRule) bool {
	switch rule.ID {
	case "high-cpu-usage":
		// Simulate checking CPU usage
		return rand.Float64() < 0.2 // 20% chance of firing
	case "high-memory-usage":
		return rand.Float64() < 0.1 // 10% chance of firing
	case "high-error-rate":
		return rand.Float64() < 0.15 // 15% chance of firing
	case "low-throughput":
		return rand.Float64() < 0.05 // 5% chance of firing
	}
	return false
}

// Fire an alert
func fireAlert(rule *AlertRule) {
	alertID := fmt.Sprintf("%s-%d", rule.ID, time.Now().Unix())

	// Check if alert is already active
	if existingAlert, exists := alertManager.ActiveAlerts[rule.ID]; exists {
		// Update existing alert duration
		existingAlert.Duration = time.Since(existingAlert.StartsAt)
		return
	}

	alert := &Alert{
		ID:           alertID,
		RuleID:       rule.ID,
		RuleName:     rule.Name,
		Status:       "firing",
		Severity:     rule.Severity,
		Message:      fmt.Sprintf("%s: %s", rule.Name, rule.Description),
		Description:  rule.Description,
		StartsAt:     time.Now(),
		Duration:     0,
		Labels:       rule.Labels,
		Annotations:  rule.Annotations,
		Value:        rand.Float64() * 100, // Simulated current value
		Threshold:    rule.Threshold.Value,
		GeneratorURL: fmt.Sprintf("http://localhost:3001/alerts/%s", alertID),
	}

	alertManager.ActiveAlerts[rule.ID] = alert
	alertManager.AlertHistory = append(alertManager.AlertHistory, alert)

	// Update metrics
	alertsTotal.WithLabelValues(rule.Name, rule.Severity, "firing").Inc()

	// Send notifications
	sendNotification(alert)

	// Create incident for critical alerts
	if rule.Severity == "critical" {
		createIncident(alert)
	}

	logger.Warn("Alert fired",
		zap.String("alert_id", alertID),
		zap.String("rule_name", rule.Name),
		zap.String("severity", rule.Severity),
		zap.Float64("value", alert.Value),
		zap.Float64("threshold", alert.Threshold),
	)
}

// Resolve an alert
func resolveAlert(ruleID string) {
	if alert, exists := alertManager.ActiveAlerts[ruleID]; exists {
		now := time.Now()
		alert.Status = "resolved"
		alert.EndsAt = &now
		alert.Duration = time.Since(alert.StartsAt)

		// Update metrics
		alertsTotal.WithLabelValues(alert.RuleName, alert.Severity, "resolved").Inc()
		alertDuration.WithLabelValues(alert.RuleName, alert.Severity).Observe(alert.Duration.Seconds())

		// Send resolution notification
		sendResolutionNotification(alert)

		// Remove from active alerts
		delete(alertManager.ActiveAlerts, ruleID)

		logger.Info("Alert resolved",
			zap.String("alert_id", alert.ID),
			zap.String("rule_name", alert.RuleName),
			zap.Duration("duration", alert.Duration),
		)
	}
}

// Notification processor - handles sending notifications
func notificationProcessor() {
	logger.Info("Notification processor started")
	// In a real implementation, this would process a notification queue
	// For now, notifications are sent synchronously in sendNotification()
}

// Send notification for a fired alert
func sendNotification(alert *Alert) {
	for _, channel := range alertManager.NotificationChannels {
		if !channel.Enabled {
			continue
		}

		// Check if channel should receive this alert based on conditions
		shouldSend := false
		for _, condition := range channel.Conditions {
			if condition == alert.Severity {
				shouldSend = true
				break
			}
		}

		if !shouldSend {
			continue
		}

		// Simulate sending notification
		start := time.Now()
		success := simulateNotificationSend(channel, alert)
		duration := time.Since(start)

		status := "success"
		if !success {
			status = "failed"
		}

		// Update metrics
		notificationsSent.WithLabelValues(channel.Type, alert.Severity, status).Inc()
		notificationLatency.WithLabelValues(channel.Type).Observe(duration.Seconds())

		logger.Info("Notification sent",
			zap.String("channel_id", channel.ID),
			zap.String("channel_type", channel.Type),
			zap.String("alert_id", alert.ID),
			zap.String("status", status),
			zap.Duration("latency", duration),
		)
	}
}

// Send resolution notification
func sendResolutionNotification(alert *Alert) {
	for _, channel := range alertManager.NotificationChannels {
		if !channel.Enabled {
			continue
		}

		simulateNotificationSend(channel, alert)
	}
}

// Simulate sending a notification
func simulateNotificationSend(channel *NotificationChannel, alert *Alert) bool {
	// Simulate network latency
	time.Sleep(time.Duration(rand.Intn(100)) * time.Millisecond)

	// 95% success rate
	return rand.Float64() < 0.95
}

// Create an incident from a critical alert
func createIncident(alert *Alert) {
	incidentID := uuid.New().String()

	incident := &Incident{
		ID:              incidentID,
		Title:           fmt.Sprintf("Critical Alert: %s", alert.RuleName),
		Description:     fmt.Sprintf("Auto-generated incident from critical alert: %s", alert.Description),
		Status:          "open",
		Severity:        alert.Severity,
		Priority:        "high",
		AssignedTo:      "oncall-engineer",
		CreatedBy:       "alert-manager",
		CreatedAt:       time.Now(),
		UpdatedAt:       time.Now(),
		AffectedService: serviceName,
		RelatedAlerts:   []string{alert.ID},
		Tags:            []string{"auto-generated", "critical-alert"},
		Timeline: []IncidentUpdate{
			{
				ID:        uuid.New().String(),
				Timestamp: time.Now(),
				Author:    "alert-manager",
				Type:      "status_change",
				Message:   "Incident created from critical alert",
				NewValue:  "open",
			},
		},
		Metrics: IncidentMetrics{
			TimeToDetection: time.Since(alert.StartsAt),
		},
	}

	alertManager.Incidents[incidentID] = incident

	// Update metrics
	incidentsTotal.WithLabelValues(incident.Severity, incident.Status, incident.AffectedService).Inc()

	logger.Warn("Incident created",
		zap.String("incident_id", incidentID),
		zap.String("alert_id", alert.ID),
		zap.String("severity", incident.Severity),
	)
}

// Phase 4: Alerting & Incident Management Test Handlers

// Test alert rules functionality
func testAlertRulesHandler(w http.ResponseWriter, r *http.Request) {
	ctx, span := tracer.Start(r.Context(), "test_alert_rules")
	defer span.End()

	// Get all current alert rules
	rules := make([]*AlertRule, 0, len(alertManager.Rules))
	for _, rule := range alertManager.Rules {
		rules = append(rules, rule)
	}

	// Get active alerts count
	activeAlertsCount := len(alertManager.ActiveAlerts)

	// Get alert history summary
	alertHistoryCount := len(alertManager.AlertHistory)

	// Calculate alert statistics
	var criticalCount, warningCount, infoCount int
	for _, alert := range alertManager.AlertHistory {
		switch alert.Severity {
		case "critical":
			criticalCount++
		case "warning":
			warningCount++
		case "info":
			infoCount++
		}
	}

	span.SetAttributes(
		attribute.Int("alert_rules.total", len(rules)),
		attribute.Int("alerts.active", activeAlertsCount),
		attribute.Int("alerts.history", alertHistoryCount),
	)

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(map[string]interface{}{
		"message":       "Alert rules test completed",
		"status":        "success",
		"alert_rules":   rules,
		"active_alerts": activeAlertsCount,
		"alert_history": alertHistoryCount,
		"alert_stats": map[string]int{
			"critical": criticalCount,
			"warning":  warningCount,
			"info":     infoCount,
		},
		"rules_enabled": len(alertManager.Rules),
		"trace_id":      extractTraceID(ctx),
	})
}

// Test firing alerts manually
func testFireAlertHandler(w http.ResponseWriter, r *http.Request) {
	ctx, span := tracer.Start(r.Context(), "test_fire_alert")
	defer span.End()

	// Parse request parameters
	alertType := r.URL.Query().Get("type")
	if alertType == "" {
		alertType = "high-cpu-usage" // default
	}

	severity := r.URL.Query().Get("severity")
	if severity == "" {
		severity = "warning" // default
	}

	// Find the rule to fire
	rule, exists := alertManager.Rules[alertType]
	if !exists {
		// Create a temporary test rule
		rule = &AlertRule{
			ID:          "test-alert-" + alertType,
			Name:        "Test Alert: " + strings.Title(strings.ReplaceAll(alertType, "-", " ")),
			Description: fmt.Sprintf("Manual test alert of type %s", alertType),
			Query:       fmt.Sprintf("test_metric_%s > 1", alertType),
			Threshold:   AlertThreshold{Operator: "gt", Value: 1},
			Severity:    severity,
			Duration:    1 * time.Minute,
			Labels:      map[string]string{"team": "test", "component": "manual"},
			Annotations: map[string]string{"runbook": "https://docs.company.com/test"},
			Enabled:     true,
			CreatedAt:   time.Now(),
			UpdatedAt:   time.Now(),
		}
	}

	// Force fire the alert
	fireAlert(rule)

	// Count current active alerts
	activeCount := len(alertManager.ActiveAlerts)

	span.SetAttributes(
		attribute.String("alert.type", alertType),
		attribute.String("alert.severity", severity),
		attribute.Int("alerts.active_total", activeCount),
	)

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(map[string]interface{}{
		"message":       "Test alert fired successfully",
		"status":        "success",
		"alert_type":    alertType,
		"severity":      severity,
		"rule_name":     rule.Name,
		"active_alerts": activeCount,
		"trace_id":      extractTraceID(ctx),
	})
}

// Test incident management functionality
func testIncidentManagementHandler(w http.ResponseWriter, r *http.Request) {
	ctx, span := tracer.Start(r.Context(), "test_incident_management")
	defer span.End()

	// Create a test incident manually
	incidentID := uuid.New().String()

	testIncident := &Incident{
		ID:              incidentID,
		Title:           "Test Incident: Service Degradation",
		Description:     "Manual test incident to verify incident management functionality",
		Status:          "open",
		Severity:        "critical",
		Priority:        "high",
		AssignedTo:      "test-engineer",
		CreatedBy:       "test-system",
		CreatedAt:       time.Now(),
		UpdatedAt:       time.Now(),
		AffectedService: serviceName,
		RelatedAlerts:   []string{},
		Tags:            []string{"test", "manual", "service-degradation"},
		Timeline: []IncidentUpdate{
			{
				ID:        uuid.New().String(),
				Timestamp: time.Now(),
				Author:    "test-system",
				Type:      "status_change",
				Message:   "Test incident created for validation",
				NewValue:  "open",
			},
		},
		Metrics: IncidentMetrics{
			TimeToDetection: 30 * time.Second,
		},
	}

	alertManager.Incidents[incidentID] = testIncident

	// Update incident metrics
	incidentsTotal.WithLabelValues(testIncident.Severity, testIncident.Status, testIncident.AffectedService).Inc()

	// Get incident statistics
	totalIncidents := len(alertManager.Incidents)
	var openCount, resolvedCount int
	for _, incident := range alertManager.Incidents {
		switch incident.Status {
		case "open", "investigating":
			openCount++
		case "resolved", "closed":
			resolvedCount++
		}
	}

	span.SetAttributes(
		attribute.String("incident.id", incidentID),
		attribute.String("incident.severity", testIncident.Severity),
		attribute.Int("incidents.total", totalIncidents),
		attribute.Int("incidents.open", openCount),
	)

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(map[string]interface{}{
		"message":  "Test incident created successfully",
		"status":   "success",
		"incident": testIncident,
		"incident_stats": map[string]int{
			"total":    totalIncidents,
			"open":     openCount,
			"resolved": resolvedCount,
		},
		"trace_id": extractTraceID(ctx),
	})
}

// Test notification channels functionality
func testNotificationChannelsHandler(w http.ResponseWriter, r *http.Request) {
	ctx, span := tracer.Start(r.Context(), "test_notification_channels")
	defer span.End()

	// Get all notification channels
	channels := make([]*NotificationChannel, 0, len(alertManager.NotificationChannels))
	for _, channel := range alertManager.NotificationChannels {
		channels = append(channels, channel)
	}

	// Create a test alert to send notifications
	testAlert := &Alert{
		ID:           "test-notification-" + strconv.FormatInt(time.Now().Unix(), 10),
		RuleID:       "test-rule",
		RuleName:     "Test Notification Alert",
		Status:       "firing",
		Severity:     "warning",
		Message:      "Test notification to verify channel functionality",
		Description:  "This is a test alert for notification testing",
		StartsAt:     time.Now(),
		Duration:     0,
		Labels:       map[string]string{"test": "true", "component": "notification"},
		Annotations:  map[string]string{"test_purpose": "notification_validation"},
		Value:        85.5,
		Threshold:    80.0,
		GeneratorURL: "http://localhost:3001/test/notification",
	}

	// Test sending notifications through all channels
	var notificationResults []map[string]interface{}
	for _, channel := range channels {
		start := time.Now()
		success := simulateNotificationSend(channel, testAlert)
		duration := time.Since(start)

		status := "success"
		if !success {
			status = "failed"
		}

		result := map[string]interface{}{
			"channel_id":   channel.ID,
			"channel_name": channel.Name,
			"channel_type": channel.Type,
			"status":       status,
			"latency_ms":   float64(duration.Nanoseconds()) / 1e6,
			"enabled":      channel.Enabled,
		}
		notificationResults = append(notificationResults, result)
	}

	span.SetAttributes(
		attribute.Int("channels.total", len(channels)),
		attribute.String("test_alert.id", testAlert.ID),
		attribute.Int("notifications.sent", len(notificationResults)),
	)

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(map[string]interface{}{
		"message":              "Notification channels tested successfully",
		"status":               "success",
		"channels":             channels,
		"notification_results": notificationResults,
		"test_alert":           testAlert,
		"trace_id":             extractTraceID(ctx),
	})
}

// Get active alerts
func getActiveAlertsHandler(w http.ResponseWriter, r *http.Request) {
	ctx, span := tracer.Start(r.Context(), "get_active_alerts")
	defer span.End()

	// Convert map to slice for JSON response
	activeAlerts := make([]*Alert, 0, len(alertManager.ActiveAlerts))
	for _, alert := range alertManager.ActiveAlerts {
		// Update duration for active alerts
		alert.Duration = time.Since(alert.StartsAt)
		activeAlerts = append(activeAlerts, alert)
	}

	// Get recent alert history (last 10)
	recentHistory := alertManager.AlertHistory
	if len(recentHistory) > 10 {
		recentHistory = recentHistory[len(recentHistory)-10:]
	}

	span.SetAttributes(
		attribute.Int("alerts.active_count", len(activeAlerts)),
		attribute.Int("alerts.history_count", len(alertManager.AlertHistory)),
	)

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(map[string]interface{}{
		"message":        "Active alerts retrieved successfully",
		"status":         "success",
		"active_alerts":  activeAlerts,
		"recent_history": recentHistory,
		"total_active":   len(activeAlerts),
		"total_history":  len(alertManager.AlertHistory),
		"trace_id":       extractTraceID(ctx),
	})
}

// Get active incidents
func getActiveIncidentsHandler(w http.ResponseWriter, r *http.Request) {
	ctx, span := tracer.Start(r.Context(), "get_active_incidents")
	defer span.End()

	// Get all incidents
	allIncidents := make([]*Incident, 0, len(alertManager.Incidents))
	activeIncidents := make([]*Incident, 0)

	for _, incident := range alertManager.Incidents {
		allIncidents = append(allIncidents, incident)

		// Consider incidents as active if they're not resolved or closed
		if incident.Status == "open" || incident.Status == "investigating" {
			activeIncidents = append(activeIncidents, incident)
		}
	}

	// Calculate incident statistics
	var criticalCount, highCount, mediumCount, lowCount int
	var avgResolutionTime time.Duration
	var resolvedCount int

	for _, incident := range allIncidents {
		switch incident.Priority {
		case "critical":
			criticalCount++
		case "high":
			highCount++
		case "medium":
			mediumCount++
		case "low":
			lowCount++
		}

		if incident.Status == "resolved" && incident.ResolvedAt != nil {
			resolvedCount++
			avgResolutionTime += incident.Metrics.TimeToResolve
		}
	}

	if resolvedCount > 0 {
		avgResolutionTime = avgResolutionTime / time.Duration(resolvedCount)
	}

	span.SetAttributes(
		attribute.Int("incidents.active_count", len(activeIncidents)),
		attribute.Int("incidents.total_count", len(allIncidents)),
		attribute.Int("incidents.critical", criticalCount),
	)

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(map[string]interface{}{
		"message":          "Active incidents retrieved successfully",
		"status":           "success",
		"active_incidents": activeIncidents,
		"all_incidents":    allIncidents,
		"total_active":     len(activeIncidents),
		"total_incidents":  len(allIncidents),
		"incident_stats": map[string]interface{}{
			"by_priority": map[string]int{
				"critical": criticalCount,
				"high":     highCount,
				"medium":   mediumCount,
				"low":      lowCount,
			},
			"resolved_count":         resolvedCount,
			"avg_resolution_time":    avgResolutionTime.String(),
			"avg_resolution_minutes": avgResolutionTime.Minutes(),
		},
		"trace_id": extractTraceID(ctx),
	})
}
