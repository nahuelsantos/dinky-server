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
	fmt.Println("Starting Dinky Monitor Service v7.0.0-phase7...")

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
	simulationHandlers := handlers.NewSimulationHandlers(loggingService, tracingService)
	alertingHandlers := handlers.NewAlertingHandlers(loggingService, alertingService)
	testingHandlers := handlers.NewTestingHandlers(loggingService, tracingService)

	// Create HTTP mux
	mux := http.NewServeMux()

	// Core monitoring test endpoints
	mux.HandleFunc("/health", basicHandlers.HealthHandler)
	mux.HandleFunc("/generate-metrics", basicHandlers.GenerateMetricsHandler)
	mux.HandleFunc("/generate-logs", basicHandlers.GenerateLogsHandler)
	mux.HandleFunc("/generate-error", basicHandlers.GenerateErrorHandler)
	mux.HandleFunc("/cpu-load", basicHandlers.CPULoadHandler)
	mux.HandleFunc("/memory-load", basicHandlers.MemoryLoadHandler)

	// Phase 6: Multi-Service Simulation endpoints
	mux.HandleFunc("/simulate/web-service", simulationHandlers.SimulateWebServiceHandler)
	mux.HandleFunc("/simulate/api-service", simulationHandlers.SimulateAPIServiceHandler)
	mux.HandleFunc("/simulate/database-service", simulationHandlers.SimulateDatabaseServiceHandler)
	mux.HandleFunc("/simulate/static-site", simulationHandlers.SimulateStaticSiteHandler)
	mux.HandleFunc("/simulate/microservice", simulationHandlers.SimulateMicroserviceHandler)

	// Phase 7: Test data variety endpoints
	mux.HandleFunc("/generate-logs/json", testingHandlers.GenerateJSONLogsHandler)
	mux.HandleFunc("/generate-logs/unstructured", testingHandlers.GenerateUnstructuredLogsHandler)
	mux.HandleFunc("/generate-logs/mixed", testingHandlers.GenerateMixedLogsHandler)
	mux.HandleFunc("/generate-logs/multiline", testingHandlers.GenerateMultilineLogsHandler)
	mux.HandleFunc("/simulate-service/wordpress", testingHandlers.SimulateWordPressServiceHandler)
	mux.HandleFunc("/simulate-service/nextjs", testingHandlers.SimulateNextJSServiceHandler)
	mux.HandleFunc("/simulate-trace/cross-service", testingHandlers.SimulateCrossServiceTracingHandler)

	// Phase 7: Integration testing endpoints
	mux.HandleFunc("/test-service-discovery", testingHandlers.TestServiceDiscoveryHandler)
	mux.HandleFunc("/test-reverse-proxy", testingHandlers.TestReverseProxyHandler)
	mux.HandleFunc("/test-ssl-monitoring", testingHandlers.TestSSLMonitoringHandler)
	mux.HandleFunc("/test-domain-health", testingHandlers.TestDomainHealthHandler)

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
			"health":                       "Service health check",
			"generate-metrics":             "Generate test metrics for Prometheus",
			"generate-logs":                "Generate test logs for Loki",
			"generate-error":               "Generate test errors for alerting",
			"cpu-load":                     "Simulate CPU load for testing",
			"memory-load":                  "Simulate memory load for testing",
			"simulate/web-service":         "Simulate web service traffic (WordPress, web apps)",
			"simulate/api-service":         "Simulate REST API service traffic",
			"simulate/database-service":    "Simulate database-heavy application",
			"simulate/static-site":         "Simulate static file serving (CDN-like)",
			"simulate/microservice":        "Simulate microservice communication patterns",
			"generate-logs/json":           "Phase 7: Generate structured JSON logs for Loki testing",
			"generate-logs/unstructured":   "Phase 7: Generate unstructured plain text logs",
			"generate-logs/mixed":          "Phase 7: Generate mixed format logs (JSON, key-value, text)",
			"generate-logs/multiline":      "Phase 7: Generate multi-line logs (stack traces)",
			"simulate-service/wordpress":   "Phase 7: Simulate WordPress-like service patterns",
			"simulate-service/nextjs":      "Phase 7: Simulate Next.js-like service patterns",
			"simulate-trace/cross-service": "Phase 7: Simulate cross-service tracing scenarios",
			"test-service-discovery":       "Phase 7: Test service discovery and health monitoring",
			"test-reverse-proxy":           "Phase 7: Test Traefik reverse proxy integration",
			"test-ssl-monitoring":          "Phase 7: Test SSL certificate monitoring",
			"test-domain-health":           "Phase 7: Test domain-specific health monitoring",
			"test-alert-rules":             "Test alert rules functionality",
			"test-fire-alert":              "Fire a test alert",
			"test-incident-management":     "Test incident management workflow",
			"test-notification-channels":   "Test notification channels",
			"active-alerts":                "View currently active alerts",
			"active-incidents":             "View currently active incidents",
			"metrics":                      "Prometheus metrics endpoint",
		}

		response := map[string]interface{}{
			"service":     serviceConfig.Name,
			"version":     "v7.0.0-phase7",
			"purpose":     "LGTM stack testing service with comprehensive data variety and integration testing",
			"description": "Testing Loki, Grafana, Tempo, and Prometheus with realistic service patterns and data formats",
			"features": []string{
				"test_metrics_generation",
				"test_logs_generation",
				"test_error_simulation",
				"system_load_simulation",
				"web_service_simulation",
				"api_service_simulation",
				"database_service_simulation",
				"static_site_simulation",
				"microservice_simulation",
				"json_log_testing",
				"unstructured_log_testing",
				"mixed_format_log_testing",
				"multiline_log_testing",
				"wordpress_service_testing",
				"nextjs_service_testing",
				"cross_service_tracing_testing",
				"service_discovery_testing",
				"reverse_proxy_testing",
				"ssl_monitoring_testing",
				"domain_health_testing",
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
	fmt.Println("🎯 Purpose: LGTM stack testing with comprehensive data variety and integration testing")
	fmt.Println("📊 Features enabled:")
	fmt.Println("  ✅ Test Metrics Generation (Prometheus)")
	fmt.Println("  ✅ Test Logs Generation (Loki)")
	fmt.Println("  ✅ Test Error Simulation")
	fmt.Println("  ✅ System Load Simulation")
	fmt.Println("  🌐 Web Service Simulation")
	fmt.Println("  🔗 API Service Simulation")
	fmt.Println("  🗄️  Database Service Simulation")
	fmt.Println("  📁 Static Site Simulation")
	fmt.Println("  ⚡ Microservice Communication Simulation")
	fmt.Println("  📝 JSON Log Format Testing (Phase 7)")
	fmt.Println("  📄 Unstructured Log Format Testing (Phase 7)")
	fmt.Println("  🔄 Mixed Log Format Testing (Phase 7)")
	fmt.Println("  📜 Multi-line Log Testing (Phase 7)")
	fmt.Println("  🏗️  WordPress Service Testing (Phase 7)")
	fmt.Println("  ⚛️  Next.js Service Testing (Phase 7)")
	fmt.Println("  🔗 Cross-Service Tracing Testing (Phase 7)")
	fmt.Println("  🔍 Service Discovery Testing (Phase 7)")
	fmt.Println("  🔀 Reverse Proxy Testing (Phase 7)")
	fmt.Println("  🔒 SSL Certificate Monitoring (Phase 7)")
	fmt.Println("  🌐 Domain Health Monitoring (Phase 7)")
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
	fmt.Println()
	fmt.Println("🎭 Service Simulations (Phase 6):")
	fmt.Println("  🌐 http://localhost:3001/simulate/web-service - Web service traffic")
	fmt.Println("  🔗 http://localhost:3001/simulate/api-service - REST API traffic")
	fmt.Println("  🗄️  http://localhost:3001/simulate/database-service - Database patterns")
	fmt.Println("  📁 http://localhost:3001/simulate/static-site - Static file serving")
	fmt.Println("  ⚡ http://localhost:3001/simulate/microservice - Microservice communication")
	fmt.Println()
	fmt.Println("🧪 LGTM Data Variety Testing (Phase 7):")
	fmt.Println("  📝 http://localhost:3001/generate-logs/json - JSON structured logs")
	fmt.Println("  📄 http://localhost:3001/generate-logs/unstructured - Plain text logs")
	fmt.Println("  🔄 http://localhost:3001/generate-logs/mixed - Mixed format logs")
	fmt.Println("  📜 http://localhost:3001/generate-logs/multiline - Multi-line logs (stack traces)")
	fmt.Println("  🏗️  http://localhost:3001/simulate-service/wordpress - WordPress service patterns")
	fmt.Println("  ⚛️  http://localhost:3001/simulate-service/nextjs - Next.js service patterns")
	fmt.Println("  🔗 http://localhost:3001/simulate-trace/cross-service - Cross-service tracing")
	fmt.Println()
	fmt.Println("🔧 Real-World Integration Testing (Phase 7):")
	fmt.Println("  🔍 http://localhost:3001/test-service-discovery - Service discovery testing")
	fmt.Println("  🔀 http://localhost:3001/test-reverse-proxy - Reverse proxy testing")
	fmt.Println("  🔒 http://localhost:3001/test-ssl-monitoring - SSL certificate monitoring")
	fmt.Println("  🌐 http://localhost:3001/test-domain-health - Domain health monitoring")
	fmt.Println()
	fmt.Println("🚨 Alert Testing:")
	fmt.Println("  🚨 http://localhost:3001/test-alert-rules - Test alert rules")
	fmt.Println("  🎯 http://localhost:3001/test-fire-alert - Fire test alert")
	fmt.Println("  🛠️  http://localhost:3001/test-incident-management - Test incidents")
	fmt.Println("  📬 http://localhost:3001/test-notification-channels - Test notifications")
	fmt.Println("  🔥 http://localhost:3001/active-alerts - View active alerts")
	fmt.Println("  📋 http://localhost:3001/active-incidents - View active incidents")
	fmt.Println()
	fmt.Println("🎯 Phase 7 Focus: Test Data Variety & Real-World Integration Testing for LGTM Stack!")

	log.Fatal(http.ListenAndServe(serviceConfig.Port, handler))
}

// encodeJSON is a helper function to encode JSON responses
func encodeJSON(w http.ResponseWriter, data interface{}) error {
	w.Header().Set("Content-Type", "application/json")
	return json.NewEncoder(w).Encode(data)
}
