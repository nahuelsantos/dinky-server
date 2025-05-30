package main

import (
	"encoding/json"
	"fmt"
	"log"
	"net/http"

	"github.com/prometheus/client_golang/prometheus/promhttp"
	"go.uber.org/zap"

	"dinky-monitor/internal/config"
	"dinky-monitor/internal/handlers"
	"dinky-monitor/internal/metrics"
	"dinky-monitor/internal/middleware"
	"dinky-monitor/internal/services"
)

func main() {
	fmt.Println("Starting Dinky Monitor Service v5.0.0-phase5...")

	// Initialize configuration
	serviceConfig := config.GetServiceConfig()

	// Initialize services
	loggingService := services.NewLoggingService()
	loggingService.InitLogger()

	tracingService := services.NewTracingService()
	tracingService.InitTracer()

	alertingService := services.NewAlertingService()
	alertingService.InitAlertManager()

	// Phase 5: Initialize Intelligence Service
	logger, _ := zap.NewProduction()
	defer logger.Sync()
	intelligenceService := services.NewIntelligenceService(logger)

	// Register Prometheus metrics (all phases)
	metrics.RegisterMetrics()
	metrics.RegisterIntelligenceMetrics() // Phase 5 metrics

	// Initialize handlers
	basicHandlers := handlers.NewBasicHandlers(loggingService, tracingService)
	alertingHandlers := handlers.NewAlertingHandlers(loggingService, alertingService)
	intelligenceHandler := handlers.NewIntelligenceHandler(logger, intelligenceService) // Phase 5

	// Create HTTP mux
	mux := http.NewServeMux()

	// Basic endpoints
	mux.HandleFunc("/health", basicHandlers.HealthHandler)
	mux.HandleFunc("/generate-metrics", basicHandlers.GenerateMetricsHandler)
	mux.HandleFunc("/generate-logs", basicHandlers.GenerateLogsHandler)
	mux.HandleFunc("/generate-error", basicHandlers.GenerateErrorHandler)
	mux.HandleFunc("/cpu-load", basicHandlers.CPULoadHandler)
	mux.HandleFunc("/memory-load", basicHandlers.MemoryLoadHandler)

	// Phase 4: Alerting endpoints
	mux.HandleFunc("/test-alert-rules", alertingHandlers.TestAlertRulesHandler)
	mux.HandleFunc("/test-fire-alert", alertingHandlers.TestFireAlertHandler)
	mux.HandleFunc("/test-incident-management", alertingHandlers.TestIncidentManagementHandler)
	mux.HandleFunc("/test-notification-channels", alertingHandlers.TestNotificationChannelsHandler)
	mux.HandleFunc("/active-alerts", alertingHandlers.GetActiveAlertsHandler)
	mux.HandleFunc("/active-incidents", alertingHandlers.GetActiveIncidentsHandler)

	// Phase 5: Intelligence & Analytics endpoints 🧠
	intelligenceHandler.RegisterRoutes(mux)

	// Prometheus metrics endpoint
	mux.Handle("/metrics", promhttp.Handler())

	// Root endpoint
	mux.HandleFunc("/", func(w http.ResponseWriter, r *http.Request) {
		endpoints := map[string]string{
			"health":                     "Service health check",
			"generate-metrics":           "Generate sample metrics",
			"generate-logs":              "Generate sample logs",
			"generate-error":             "Generate sample errors",
			"cpu-load":                   "Simulate CPU load",
			"memory-load":                "Simulate memory load",
			"test-alert-rules":           "Test alert rules functionality",
			"test-fire-alert":            "Fire a test alert",
			"test-incident-management":   "Test incident management",
			"test-notification-channels": "Test notification channels",
			"active-alerts":              "View active alerts",
			"active-incidents":           "View active incidents",
			// Phase 5: Intelligence & Analytics
			"test-anomaly-detection":    "Test ML anomaly detection",
			"test-predictive-alerts":    "Test predictive alerting",
			"test-root-cause-analysis":  "Test automated root cause analysis",
			"test-performance-insights": "Test performance insights",
			"test-capacity-planning":    "Test capacity planning",
			"anomaly-models":            "View ML models",
			"predictive-alerts":         "View predictive alerts",
			"recommendations":           "View recommendations",
			"intelligence-dashboard":    "Intelligence dashboard",
			"metrics":                   "Prometheus metrics",
		}

		response := map[string]interface{}{
			"service": serviceConfig.Name,
			"version": "v5.0.0-phase5",
			"phase":   "5",
			"features": []string{
				"comprehensive_logging",
				"prometheus_metrics",
				"opentelemetry_tracing",
				"alert_management",
				"incident_management",
				"notification_channels",
				// Phase 5 features
				"ml_anomaly_detection",
				"predictive_alerting",
				"root_cause_analysis",
				"performance_insights",
				"capacity_planning",
				"cost_optimization",
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
	fmt.Println("📊 Features enabled:")
	fmt.Println("  ✅ Comprehensive Logging (Zap)")
	fmt.Println("  ✅ Prometheus Metrics")
	fmt.Println("  ✅ OpenTelemetry Tracing")
	fmt.Println("  ✅ Alert Management")
	fmt.Println("  ✅ Incident Management")
	fmt.Println("  ✅ Notification Channels")
	fmt.Println("  🧠 ML-Powered Anomaly Detection")
	fmt.Println("  🔮 Predictive Alerting")
	fmt.Println("  🕵️ Automated Root Cause Analysis")
	fmt.Println("  📊 Performance Insights")
	fmt.Println("  📈 Capacity Planning")
	fmt.Println("  💰 Cost Optimization")
	fmt.Println()
	fmt.Println("📍 Available endpoints:")
	fmt.Println("  🔗 http://localhost:3001/ - Service information")
	fmt.Println("  🩺 http://localhost:3001/health - Health check")
	fmt.Println("  📈 http://localhost:3001/metrics - Prometheus metrics")
	fmt.Println("  🚨 http://localhost:3001/test-alert-rules - Test alerting")
	fmt.Println("  🎯 http://localhost:3001/test-fire-alert - Fire test alert")
	fmt.Println("  🛠️  http://localhost:3001/test-incident-management - Test incidents")
	fmt.Println("  📬 http://localhost:3001/test-notification-channels - Test notifications")
	fmt.Println("  🔥 http://localhost:3001/active-alerts - View active alerts")
	fmt.Println("  📋 http://localhost:3001/active-incidents - View active incidents")
	fmt.Println("  🧠 http://localhost:3001/test-anomaly-detection - Test ML anomaly detection")
	fmt.Println("  🔮 http://localhost:3001/test-predictive-alerts - Test predictive alerts")
	fmt.Println("  🕵️ http://localhost:3001/test-root-cause-analysis - Test root cause analysis")
	fmt.Println("  📊 http://localhost:3001/test-performance-insights - Test performance insights")
	fmt.Println("  📈 http://localhost:3001/test-capacity-planning - Test capacity planning")
	fmt.Println("  💡 http://localhost:3001/recommendations - View recommendations")
	fmt.Println("  🎛️  http://localhost:3001/intelligence-dashboard - Intelligence dashboard")
	fmt.Println()

	log.Fatal(http.ListenAndServe(serviceConfig.Port, handler))
}

// encodeJSON is a helper function to encode JSON responses
func encodeJSON(w http.ResponseWriter, data interface{}) error {
	w.Header().Set("Content-Type", "application/json")
	return json.NewEncoder(w).Encode(data)
}
