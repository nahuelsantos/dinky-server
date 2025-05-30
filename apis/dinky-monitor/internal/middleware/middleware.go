package middleware

import (
	"context"
	"net/http"
	"strconv"
	"time"

	"github.com/google/uuid"
	"go.opentelemetry.io/otel"
	"go.opentelemetry.io/otel/attribute"
	"go.uber.org/zap/zapcore"

	"dinky-monitor/internal/metrics"
	"dinky-monitor/internal/models"
	"dinky-monitor/internal/services"
)

// ResponseWriter wraps http.ResponseWriter to capture status code
type ResponseWriter struct {
	http.ResponseWriter
	statusCode int
}

// WriteHeader captures the status code
func (rw *ResponseWriter) WriteHeader(code int) {
	rw.statusCode = code
	rw.ResponseWriter.WriteHeader(code)
}

// EnhancedResponseWriter wraps ResponseWriter with additional functionality
type EnhancedResponseWriter struct {
	http.ResponseWriter
	statusCode   int
	responseSize int
}

// WriteHeader captures the status code
func (rw *EnhancedResponseWriter) WriteHeader(code int) {
	rw.statusCode = code
	rw.ResponseWriter.WriteHeader(code)
}

// Write captures the response size
func (rw *EnhancedResponseWriter) Write(data []byte) (int, error) {
	size, err := rw.ResponseWriter.Write(data)
	rw.responseSize += size
	return size, err
}

// CORSMiddleware handles CORS headers
func CORSMiddleware(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Access-Control-Allow-Origin", "*")
		w.Header().Set("Access-Control-Allow-Methods", "GET, POST, PUT, DELETE, OPTIONS, PATCH, HEAD")

		// For development, allow any headers that are requested
		if requestedHeaders := r.Header.Get("Access-Control-Request-Headers"); requestedHeaders != "" {
			w.Header().Set("Access-Control-Allow-Headers", requestedHeaders)
		} else {
			// Fallback to comprehensive list including all HTMX headers
			w.Header().Set("Access-Control-Allow-Headers", "*")
		}

		w.Header().Set("Access-Control-Expose-Headers", "X-Request-ID, X-Trace-ID")
		w.Header().Set("Access-Control-Allow-Credentials", "true")
		w.Header().Set("Access-Control-Max-Age", "86400") // 24 hours

		if r.Method == "OPTIONS" {
			w.WriteHeader(http.StatusOK)
			return
		}

		next.ServeHTTP(w, r)
	})
}

// PrometheusMiddleware records HTTP metrics
func PrometheusMiddleware(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		start := time.Now()

		wrapped := &ResponseWriter{
			ResponseWriter: w,
			statusCode:     200,
		}

		next.ServeHTTP(wrapped, r)

		duration := time.Since(start)

		metrics.HTTPRequestsTotal.WithLabelValues(
			r.Method,
			r.URL.Path,
			strconv.Itoa(wrapped.statusCode),
		).Inc()

		metrics.HTTPRequestDuration.WithLabelValues(
			r.Method,
			r.URL.Path,
		).Observe(duration.Seconds())
	})
}

// EnhancedTracingMiddleware provides comprehensive tracing
func EnhancedTracingMiddleware(loggingService *services.LoggingService, tracingService *services.TracingService) func(http.Handler) http.Handler {
	return func(next http.Handler) http.Handler {
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			tracer := otel.Tracer("dinky-monitor")
			ctx, span := tracer.Start(r.Context(), r.URL.Path)
			defer span.End()

			// Add trace attributes
			span.SetAttributes(
				attribute.String("http.method", r.Method),
				attribute.String("http.url", r.URL.String()),
				attribute.String("http.scheme", r.URL.Scheme),
				attribute.String("http.host", r.Host),
				attribute.String("http.user_agent", r.UserAgent()),
				attribute.String("http.remote_addr", r.RemoteAddr),
			)

			// Create enhanced response writer
			wrapped := &EnhancedResponseWriter{
				ResponseWriter: w,
				statusCode:     200,
			}

			// Add request ID to context and headers
			requestID := loggingService.CreateLogContext(r).RequestID
			ctx = context.WithValue(ctx, models.RequestIDKey, requestID)
			wrapped.Header().Set("X-Request-ID", requestID)

			// Add trace ID to headers
			if span.SpanContext().IsValid() {
				traceID := span.SpanContext().TraceID().String()
				wrapped.Header().Set("X-Trace-ID", traceID)
			}

			start := time.Now()

			// Process request
			next.ServeHTTP(wrapped, r.WithContext(ctx))

			duration := time.Since(start)

			// Add response attributes
			span.SetAttributes(
				attribute.Int("http.status_code", wrapped.statusCode),
				attribute.Int("http.response_size", wrapped.responseSize),
				attribute.Int64("http.duration_ms", duration.Milliseconds()),
			)

			// Set span status based on HTTP status code
			if wrapped.statusCode >= 400 {
				span.SetAttributes(attribute.Bool("error", true))
			}

			// Create and log APM data
			apmData := tracingService.CreateAPMData(ctx, r.URL.Path, wrapped.statusCode, duration)
			tracingService.LogAPMData(apmData)

			// Log request with context
			loggingService.LogWithContext(
				getLogLevel(wrapped.statusCode),
				ctx,
				"HTTP request processed",
			)
		})
	}
}

// RequestCorrelationMiddleware adds correlation IDs to requests
func RequestCorrelationMiddleware(loggingService *services.LoggingService) func(http.Handler) http.Handler {
	return func(next http.Handler) http.Handler {
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			// Create or extract request ID
			requestID := r.Header.Get("X-Request-ID")
			if requestID == "" {
				requestID = uuid.New().String()
			}

			// Create or extract user ID
			userID := r.Header.Get("X-User-ID")
			if userID == "" {
				userID = "anonymous"
			}

			// Create or extract session ID
			sessionID := r.Header.Get("X-Session-ID")
			if sessionID == "" {
				sessionID = uuid.New().String()
			}

			// Add to context
			ctx := r.Context()
			ctx = context.WithValue(ctx, models.RequestIDKey, requestID)
			ctx = context.WithValue(ctx, models.UserIDKey, userID)
			ctx = context.WithValue(ctx, models.SessionIDKey, sessionID)
			ctx = context.WithValue(ctx, models.StartTimeKey, time.Now())

			// Add to response headers
			w.Header().Set("X-Request-ID", requestID)
			w.Header().Set("X-Session-ID", sessionID)

			// Process request with enhanced context
			next.ServeHTTP(w, r.WithContext(ctx))
		})
	}
}

// getLogLevel determines log level based on HTTP status code
func getLogLevel(statusCode int) zapcore.Level {
	switch {
	case statusCode >= 500:
		return zapcore.ErrorLevel
	case statusCode >= 400:
		return zapcore.WarnLevel
	default:
		return zapcore.InfoLevel
	}
}
