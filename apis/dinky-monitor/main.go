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
	fmt.Println("Starting Dinky Monitor Service v2.0.0...")

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
	integrationHandlers := handlers.NewIntegrationHandlers(loggingService, tracingService)
	performanceHandlers := handlers.NewPerformanceHandlers(loggingService, tracingService)

	// Create HTTP mux
	mux := http.NewServeMux()

	// Core monitoring test endpoints
	mux.HandleFunc("/health", basicHandlers.HealthHandler)
	mux.HandleFunc("/generate-metrics", basicHandlers.GenerateMetricsHandler)
	mux.HandleFunc("/generate-logs", basicHandlers.GenerateLogsHandler)
	mux.HandleFunc("/generate-error", basicHandlers.GenerateErrorHandler)
	mux.HandleFunc("/cpu-load", basicHandlers.CPULoadHandler)
	mux.HandleFunc("/memory-load", basicHandlers.MemoryLoadHandler)

	// Multi-Service Simulation endpoints
	mux.HandleFunc("/simulate/web-service", simulationHandlers.SimulateWebServiceHandler)
	mux.HandleFunc("/simulate/api-service", simulationHandlers.SimulateAPIServiceHandler)
	mux.HandleFunc("/simulate/database-service", simulationHandlers.SimulateDatabaseServiceHandler)
	mux.HandleFunc("/simulate/static-site", simulationHandlers.SimulateStaticSiteHandler)
	mux.HandleFunc("/simulate/microservice", simulationHandlers.SimulateMicroserviceHandler)

	// Test data variety endpoints
	mux.HandleFunc("/generate-logs/json", testingHandlers.GenerateJSONLogsHandler)
	mux.HandleFunc("/generate-logs/unstructured", testingHandlers.GenerateUnstructuredLogsHandler)
	mux.HandleFunc("/generate-logs/mixed", testingHandlers.GenerateMixedLogsHandler)
	mux.HandleFunc("/generate-logs/multiline", testingHandlers.GenerateMultilineLogsHandler)
	mux.HandleFunc("/simulate-service/wordpress", testingHandlers.SimulateWordPressServiceHandler)
	mux.HandleFunc("/simulate-service/nextjs", testingHandlers.SimulateNextJSServiceHandler)
	mux.HandleFunc("/simulate-trace/cross-service", testingHandlers.SimulateCrossServiceTracingHandler)

	// Integration testing endpoints
	mux.HandleFunc("/test-service-discovery", testingHandlers.TestServiceDiscoveryHandler)
	mux.HandleFunc("/test-reverse-proxy", testingHandlers.TestReverseProxyHandler)
	mux.HandleFunc("/test-ssl-monitoring", testingHandlers.TestSSLMonitoringHandler)
	mux.HandleFunc("/test-domain-health", testingHandlers.TestDomainHealthHandler)

	// LGTM Stack Configuration & Integration endpoints
	mux.HandleFunc("/test-lgtm-integration", integrationHandlers.TestLGTMIntegration)
	mux.HandleFunc("/test-grafana-dashboards", integrationHandlers.TestGrafanaDashboards)
	mux.HandleFunc("/test-alert-rules", integrationHandlers.TestAlertRules)

	// LGTM Stack Performance & Scale Testing endpoints
	mux.HandleFunc("/test-metrics-scale", performanceHandlers.TestMetricsScale)
	mux.HandleFunc("/test-logs-scale", performanceHandlers.TestLogsScale)
	mux.HandleFunc("/test-traces-scale", performanceHandlers.TestTracesScale)
	mux.HandleFunc("/test-dashboard-load", performanceHandlers.TestDashboardLoad)
	mux.HandleFunc("/test-resource-usage", performanceHandlers.TestResourceUsage)
	mux.HandleFunc("/test-storage-limits", performanceHandlers.TestStorageLimits)

	// Alerting test endpoints
	mux.HandleFunc("/test-alert-rules-legacy", alertingHandlers.TestAlertRulesHandler)
	mux.HandleFunc("/test-fire-alert", alertingHandlers.TestFireAlertHandler)
	mux.HandleFunc("/test-incident-management", alertingHandlers.TestIncidentManagementHandler)
	mux.HandleFunc("/test-notification-channels", alertingHandlers.TestNotificationChannelsHandler)
	mux.HandleFunc("/active-alerts", alertingHandlers.GetActiveAlertsHandler)
	mux.HandleFunc("/active-incidents", alertingHandlers.GetActiveIncidentsHandler)

	// Prometheus metrics endpoint
	mux.Handle("/metrics", promhttp.Handler())

	// Simple test endpoint for HTMX debugging
	mux.HandleFunc("/test-simple", func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "text/html")
		w.Write([]byte("<p style='color: green;'>✅ HTMX connection working! Endpoint reached successfully.</p>"))
	})

	// Configuration endpoint for frontend
	mux.HandleFunc("/config", func(w http.ResponseWriter, r *http.Request) {
		config := map[string]interface{}{
			"api_base_url": serviceConfig.GetAPIBaseURL(),
			"version":      "v2.0.0",
			"environment":  serviceConfig.Environment,
		}

		w.Header().Set("Content-Type", "application/json")
		w.Header().Set("Cache-Control", "no-cache, no-store, must-revalidate")
		if err := encodeJSON(w, config); err != nil {
			http.Error(w, "Failed to encode config", http.StatusInternalServerError)
		}
	})

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
			"generate-logs/json":           "Generate structured JSON logs for Loki testing",
			"generate-logs/unstructured":   "Generate unstructured plain text logs",
			"generate-logs/mixed":          "Generate mixed format logs (JSON, key-value, text)",
			"generate-logs/multiline":      "Generate multi-line logs (stack traces)",
			"simulate-service/wordpress":   "Simulate WordPress-like service patterns",
			"simulate-service/nextjs":      "Simulate Next.js-like service patterns",
			"simulate-trace/cross-service": "Simulate cross-service tracing scenarios",
			"test-service-discovery":       "Test service discovery and health monitoring",
			"test-reverse-proxy":           "Test Traefik reverse proxy integration",
			"test-ssl-monitoring":          "Test SSL certificate monitoring",
			"test-domain-health":           "Test domain-specific health monitoring",
			"test-lgtm-integration":        "Test complete LGTM stack integration",
			"test-grafana-dashboards":      "Test Grafana dashboard availability",
			"test-alert-rules":             "Test Prometheus alert rules configuration",
			"test-metrics-scale":           "Test high-volume metrics generation and ingestion",
			"test-logs-scale":              "Test high-volume log generation and processing",
			"test-traces-scale":            "Test high-volume trace generation and storage",
			"test-dashboard-load":          "Test dashboard performance under load",
			"test-resource-usage":          "Monitor LGTM stack resource consumption",
			"test-storage-limits":          "Test storage and retention capabilities",
			"test-alert-rules-legacy":      "Test alert rules functionality (legacy)",
			"test-fire-alert":              "Fire a test alert",
			"test-incident-management":     "Test incident management workflow",
			"test-notification-channels":   "Test notification channels",
			"active-alerts":                "View currently active alerts",
			"active-incidents":             "View currently active incidents",
			"metrics":                      "Prometheus metrics endpoint",
		}

		response := map[string]interface{}{
			"service":     serviceConfig.Name,
			"version":     "v2.0.0",
			"purpose":     "LGTM stack performance & scale testing with production-grade load validation",
			"description": "Testing Loki, Grafana, Tempo, and Prometheus with high-volume data and production workloads",
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
				"lgtm_stack_integration_testing",
				"grafana_dashboards_testing",
				"prometheus_alert_rules_testing",
				"metrics_scale_testing",
				"logs_scale_testing",
				"traces_scale_testing",
				"dashboard_load_testing",
				"resource_usage_monitoring",
				"storage_limits_testing",
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
	fmt.Println("🎯 Purpose: LGTM stack configuration & integration testing with comprehensive monitoring validation")
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
	fmt.Println("\n📊 LGTM Stack Configuration & Integration Testing:")
	fmt.Println("   • /test-lgtm-integration - Comprehensive LGTM stack validation")
	fmt.Println("   • /test-grafana-dashboards - Dashboard availability testing")
	fmt.Println("   • /test-alert-rules - Prometheus alert rules validation")

	fmt.Println("\n🚀 LGTM Stack Performance & Scale Testing:")
	fmt.Println("   • /test-metrics-scale - High-volume metrics generation and ingestion")
	fmt.Println("   • /test-logs-scale - High-volume log generation and processing")
	fmt.Println("   • /test-traces-scale - High-volume trace generation and storage")
	fmt.Println("   • /test-dashboard-load - Dashboard performance under load")
	fmt.Println("   • /test-resource-usage - LGTM stack resource consumption monitoring")
	fmt.Println("   • /test-storage-limits - Storage and retention capabilities testing")
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
	fmt.Println("🔧 LGTM Stack Configuration & Integration (Phase 8):")
	fmt.Println("  🔧 http://localhost:3001/test-lgtm-integration - Complete LGTM stack integration test")
	fmt.Println("  📊 http://localhost:3001/test-grafana-dashboards - Grafana dashboards availability")
	fmt.Println("  🚨 http://localhost:3001/test-alert-rules - Prometheus alert rules configuration")
	fmt.Println()
	fmt.Println("🚨 Alert Testing:")
	fmt.Println("  🚨 http://localhost:3001/test-alert-rules-legacy - Test alert rules (legacy)")
	fmt.Println("  🎯 http://localhost:3001/test-fire-alert - Fire test alert")
	fmt.Println("  🛠️  http://localhost:3001/test-incident-management - Test incidents")
	fmt.Println("  📬 http://localhost:3001/test-notification-channels - Test notifications")
	fmt.Println("  🔥 http://localhost:3001/active-alerts - View active alerts")
	fmt.Println("  📋 http://localhost:3001/active-incidents - View active incidents")
	fmt.Println()
	fmt.Println("🎯 Phase 8 Focus: LGTM Stack Configuration & Integration Testing for Production Readiness!")

	log.Fatal(http.ListenAndServe(serviceConfig.Port, handler))
}

// encodeJSON is a helper function to encode JSON responses
func encodeJSON(w http.ResponseWriter, data interface{}) error {
	w.Header().Set("Content-Type", "application/json")
	return json.NewEncoder(w).Encode(data)
}
