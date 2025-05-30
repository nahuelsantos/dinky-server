package main

import (
	"encoding/json"
	"fmt"
	"log"
	"net/http"

	"github.com/prometheus/client_golang/prometheus/promhttp"

	"dinky-monitor/internal/config"
	"dinky-monitor/internal/handlers"
	"dinky-monitor/internal/metrics"
	"dinky-monitor/internal/middleware"
	"dinky-monitor/internal/services"
)

func main() {
	fmt.Println("Starting Dinky Monitor Service v5.0.0-simplified...")

	// Initialize configuration
	serviceConfig := config.GetServiceConfig()

	// Initialize services
	loggingService := services.NewLoggingService()
	loggingService.InitLogger()

	tracingService := services.NewTracingService()
	tracingService.InitTracer()

	alertingService := services.NewAlertingService()
	alertingService.InitAlertManager()

	// Register Prometheus metrics
	metrics.RegisterMetrics()

	// Initialize handlers
	basicHandlers := handlers.NewBasicHandlers(loggingService, tracingService)
	alertingHandlers := handlers.NewAlertingHandlers(loggingService, alertingService)

	// Create HTTP mux
	mux := http.NewServeMux()

	// Core monitoring test endpoints
	mux.HandleFunc("/health", basicHandlers.HealthHandler)
	mux.HandleFunc("/generate-metrics", basicHandlers.GenerateMetricsHandler)
	mux.HandleFunc("/generate-logs", basicHandlers.GenerateLogsHandler)
	mux.HandleFunc("/generate-error", basicHandlers.GenerateErrorHandler)
	mux.HandleFunc("/cpu-load", basicHandlers.CPULoadHandler)
	mux.HandleFunc("/memory-load", basicHandlers.MemoryLoadHandler)

	// Alerting test endpoints
	mux.HandleFunc("/test-alert-rules", alertingHandlers.TestAlertRulesHandler)
	mux.HandleFunc("/test-fire-alert", alertingHandlers.TestFireAlertHandler)
	mux.HandleFunc("/test-incident-management", alertingHandlers.TestIncidentManagementHandler)
	mux.HandleFunc("/test-notification-channels", alertingHandlers.TestNotificationChannelsHandler)
	mux.HandleFunc("/active-alerts", alertingHandlers.GetActiveAlertsHandler)
	mux.HandleFunc("/active-incidents", alertingHandlers.GetActiveIncidentsHandler)

	// Prometheus metrics endpoint
	mux.Handle("/metrics", promhttp.Handler())

	// Root endpoint
	mux.HandleFunc("/", func(w http.ResponseWriter, r *http.Request) {
		endpoints := map[string]string{
			"health":                     "Service health check",
			"generate-metrics":           "Generate test metrics for Prometheus",
			"generate-logs":              "Generate test logs for Loki",
			"generate-error":             "Generate test errors for alerting",
			"cpu-load":                   "Simulate CPU load for testing",
			"memory-load":                "Simulate memory load for testing",
			"test-alert-rules":           "Test alert rules functionality",
			"test-fire-alert":            "Fire a test alert",
			"test-incident-management":   "Test incident management workflow",
			"test-notification-channels": "Test notification channels",
			"active-alerts":              "View currently active alerts",
			"active-incidents":           "View currently active incidents",
			"metrics":                    "Prometheus metrics endpoint",
		}

		response := map[string]interface{}{
			"service":     serviceConfig.Name,
			"version":     "v5.0.0-simplified",
			"purpose":     "Generate test data for LGTM monitoring stack",
			"description": "Focused on testing Loki, Grafana, Tempo, and Prometheus integration",
			"features": []string{
				"test_metrics_generation",
				"test_logs_generation",
				"test_error_simulation",
				"system_load_simulation",
				"alert_testing",
				"incident_testing",
				"notification_testing",
				"prometheus_metrics",
				"opentelemetry_tracing",
			},
			"endpoints": endpoints,
		}

		w.Header().Set("Content-Type", "application/json")
		if err := encodeJSON(w, response); err != nil {
			http.Error(w, "Failed to encode response", http.StatusInternalServerError)
		}
	})

	// Apply middleware chain
	handler := middleware.CORSMiddleware(
		middleware.PrometheusMiddleware(
			middleware.RequestCorrelationMiddleware(loggingService)(
				middleware.EnhancedTracingMiddleware(loggingService, tracingService)(mux),
			),
		),
	)

	fmt.Printf("🚀 Dinky Monitor Service started on port %s\n", serviceConfig.Port)
	fmt.Println("🎯 Purpose: Generate test data for LGTM monitoring stack")
	fmt.Println("📊 Features enabled:")
	fmt.Println("  ✅ Test Metrics Generation (Prometheus)")
	fmt.Println("  ✅ Test Logs Generation (Loki)")
	fmt.Println("  ✅ Test Error Simulation")
	fmt.Println("  ✅ System Load Simulation")
	fmt.Println("  ✅ Alert Testing")
	fmt.Println("  ✅ Incident Management Testing")
	fmt.Println("  ✅ Notification Testing")
	fmt.Println("  ✅ OpenTelemetry Tracing (Tempo)")
	fmt.Println()
	fmt.Println("📍 Test endpoints:")
	fmt.Println("  🔗 http://localhost:3001/ - Service information")
	fmt.Println("  🩺 http://localhost:3001/health - Health check")
	fmt.Println("  📈 http://localhost:3001/metrics - Prometheus metrics")
	fmt.Println("  📊 http://localhost:3001/generate-metrics - Generate test metrics")
	fmt.Println("  📝 http://localhost:3001/generate-logs - Generate test logs")
	fmt.Println("  ⚠️  http://localhost:3001/generate-error - Generate test errors")
	fmt.Println("  🔥 http://localhost:3001/cpu-load - Simulate CPU load")
	fmt.Println("  💾 http://localhost:3001/memory-load - Simulate memory load")
	fmt.Println("  🚨 http://localhost:3001/test-alert-rules - Test alert rules")
	fmt.Println("  🎯 http://localhost:3001/test-fire-alert - Fire test alert")
	fmt.Println("  🛠️  http://localhost:3001/test-incident-management - Test incidents")
	fmt.Println("  📬 http://localhost:3001/test-notification-channels - Test notifications")
	fmt.Println("  🔥 http://localhost:3001/active-alerts - View active alerts")
	fmt.Println("  📋 http://localhost:3001/active-incidents - View active incidents")
	fmt.Println()
	fmt.Println("🎯 Focus: Testing that your LGTM stack (Loki, Grafana, Tempo, Prometheus) works correctly!")

	log.Fatal(http.ListenAndServe(serviceConfig.Port, handler))
}

// encodeJSON is a helper function to encode JSON responses
func encodeJSON(w http.ResponseWriter, data interface{}) error {
	w.Header().Set("Content-Type", "application/json")
	return json.NewEncoder(w).Encode(data)
}
