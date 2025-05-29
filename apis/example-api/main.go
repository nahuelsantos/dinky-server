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
	"time"

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

var (
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

	// Global logger and tracer
	logger *zap.Logger
	tracer oteltrace.Tracer
)

func init() {
	// Register Prometheus metrics
	prometheus.MustRegister(httpRequestsTotal)
	prometheus.MustRegister(httpRequestDuration)
	prometheus.MustRegister(customMetric)
	prometheus.MustRegister(errorCounter)
}

func initLogger() {
	config := zap.NewProductionConfig()
	config.OutputPaths = []string{"stdout"}
	config.ErrorOutputPaths = []string{"stderr"}
	config.EncoderConfig.TimeKey = "timestamp"
	config.EncoderConfig.EncodeTime = zapcore.ISO8601TimeEncoder

	var err error
	logger, err = config.Build()
	if err != nil {
		log.Fatal("Failed to initialize logger:", err)
	}
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

func corsMiddleware(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		// Set CORS headers
		w.Header().Set("Access-Control-Allow-Origin", "*")
		w.Header().Set("Access-Control-Allow-Methods", "GET, POST, PUT, DELETE, OPTIONS")
		w.Header().Set("Access-Control-Allow-Headers", "Content-Type, Authorization")
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

var startTime = time.Now()

func main() {
	initLogger()
	defer logger.Sync()

	initTracer()

	logger.Info("Starting Example API server",
		zap.String("version", "1.0.0"),
		zap.Time("start_time", startTime),
	)

	r := mux.NewRouter()

	// Add CORS middleware first
	r.Use(corsMiddleware)
	// Add Prometheus middleware
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

	// Prometheus metrics endpoint
	r.Handle("/metrics", promhttp.Handler())

	// Serve static files for the web UI
	r.PathPrefix("/static/").Handler(http.StripPrefix("/static/", http.FileServer(http.Dir("./static/"))))
	r.HandleFunc("/ui", func(w http.ResponseWriter, r *http.Request) {
		http.ServeFile(w, r, "./static/index.html")
	})

	logger.Info("Server starting on port 8080")
	log.Fatal(http.ListenAndServe(":8080", r))
}
