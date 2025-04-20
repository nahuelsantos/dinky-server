# LGTM Observability Stack

This directory contains the configuration for the LGTM (Loki, Grafana, Tempo, Prometheus, and Pyroscope) observability stack with OpenTelemetry integration.

## Components

### Metrics
- **Prometheus**: Time-series database for storing and querying metrics
- **Cadvisor**: Container metrics collector
- **Node Exporter**: Host system metrics collector

### Logs
- **Loki**: Log aggregation system
- **Promtail**: Log collector for Loki

### Traces
- **Tempo**: Distributed tracing backend

### Profiles
- **Pyroscope**: Continuous profiling platform

### Visualization
- **Grafana**: Dashboard for metrics, logs, traces, and profiles

### Integration
- **OpenTelemetry Collector**: Collects telemetry data from applications and exports to various backends

## Directory Structure

```
monitoring/
├── prometheus/
│   └── prometheus.yml            # Prometheus configuration
├── loki/
│   └── loki-config.yml           # Loki configuration
├── promtail/
│   └── promtail-config.yml       # Promtail configuration
├── tempo/
│   └── tempo-config.yml          # Tempo configuration
├── pyroscope/
│   └── pyroscope-config.yml      # Pyroscope configuration
├── otel-collector/
│   └── otel-collector-config.yml # OpenTelemetry Collector configuration
├── grafana/
│   ├── dashboards/               # Grafana dashboards
│   └── provisioning/             # Grafana provisioning
│       ├── dashboards/           # Dashboard provisioning
│       └── datasources/          # Datasource provisioning
└── setup-monitoring.sh           # Setup script
```

## Getting Started

### Prerequisites

- Docker and Docker Compose installed
- Sufficient disk space for log and metric storage

### Installation

1. Run the setup script:
```bash
./monitoring/setup-monitoring.sh
```

2. Start the services:
```bash
docker compose up -d
```

### Accessing the Dashboards

- **Grafana**: http://192.168.3.2:3000 (Default login: admin / your_grafana_password_here)
- **Prometheus**: http://192.168.3.2:9090
- **Pyroscope**: http://192.168.3.2:4040

## Instrumenting Your Applications

### OpenTelemetry Endpoints

The OpenTelemetry Collector provides these endpoints:

- **OTLP gRPC**: 192.168.3.2:4317
- **OTLP HTTP**: 192.168.3.2:4318
- **OTLP gRPC (legacy)**: 192.168.3.2:4316
- **OTLP HTTP (legacy)**: 192.168.3.2:4319

### Instrumenting with OpenTelemetry

#### Node.js Example

```javascript
const { NodeSDK } = require('@opentelemetry/sdk-node');
const { OTLPTraceExporter } = require('@opentelemetry/exporter-trace-otlp-http');
const { Resource } = require('@opentelemetry/resources');
const { SemanticResourceAttributes } = require('@opentelemetry/semantic-conventions');

const sdk = new NodeSDK({
  resource: new Resource({
    [SemanticResourceAttributes.SERVICE_NAME]: 'your-service-name',
  }),
  traceExporter: new OTLPTraceExporter({
    url: 'http://192.168.3.2:4318/v1/traces',
  }),
});

sdk.start();
```

#### Python Example

```python
from opentelemetry import trace
from opentelemetry.exporter.otlp.proto.grpc.trace_exporter import OTLPSpanExporter
from opentelemetry.sdk.resources import SERVICE_NAME, Resource
from opentelemetry.sdk.trace import TracerProvider
from opentelemetry.sdk.trace.export import BatchSpanProcessor

resource = Resource(attributes={SERVICE_NAME: "your-service-name"})
provider = TracerProvider(resource=resource)
processor = BatchSpanProcessor(OTLPSpanExporter(endpoint="192.168.3.2:4317"))
provider.add_span_processor(processor)
trace.set_tracer_provider(provider)
```

#### Go Example

```go
package main

import (
	"context"
	"log"
	"os"
	"time"

	"go.opentelemetry.io/otel"
	"go.opentelemetry.io/otel/attribute"
	"go.opentelemetry.io/otel/exporters/otlp/otlptrace/otlptracegrpc"
	"go.opentelemetry.io/otel/sdk/resource"
	sdktrace "go.opentelemetry.io/otel/sdk/trace"
	semconv "go.opentelemetry.io/otel/semconv/v1.17.0"
	"go.opentelemetry.io/otel/trace"
	"google.golang.org/grpc"
	"google.golang.org/grpc/credentials/insecure"
)

// Dependency setup (go.mod):
// require (
//   go.opentelemetry.io/otel v1.19.0
//   go.opentelemetry.io/otel/exporters/otlp/otlptrace/otlptracegrpc v1.19.0
//   go.opentelemetry.io/otel/sdk v1.19.0
//   go.opentelemetry.io/otel/trace v1.19.0
//   google.golang.org/grpc v1.58.2
// )

func initTracer() (*sdktrace.TracerProvider, error) {
	ctx := context.Background()

	// Create gRPC connection to collector
	conn, err := grpc.DialContext(ctx, "192.168.3.2:4317", 
		grpc.WithTransportCredentials(insecure.NewCredentials()), 
		grpc.WithBlock())
	if err != nil {
		return nil, err
	}

	// Create OTLP exporter
	exporter, err := otlptracegrpc.New(ctx, otlptracegrpc.WithGRPCConn(conn))
	if err != nil {
		return nil, err
	}

	// Create resource with service information
	res, err := resource.New(ctx,
		resource.WithAttributes(
			semconv.ServiceName("your-service-name"),
			semconv.ServiceVersion("1.0.0"),
		),
		resource.WithHost(),
		resource.WithOSType(),
	)
	if err != nil {
		return nil, err
	}

	// Create trace provider with the exporter
	tp := sdktrace.NewTracerProvider(
		sdktrace.WithSampler(sdktrace.AlwaysSample()),
		sdktrace.WithBatcher(exporter),
		sdktrace.WithResource(res),
	)

	// Set global trace provider
	otel.SetTracerProvider(tp)
	return tp, nil
}

func main() {
	// Initialize tracer
	tp, err := initTracer()
	if err != nil {
		log.Fatalf("Failed to initialize tracer: %v", err)
	}
	defer func() {
		// Shutdown tracer to flush any remaining spans
		if err := tp.Shutdown(context.Background()); err != nil {
			log.Fatalf("Error shutting down tracer provider: %v", err)
		}
	}()

	// Get a tracer
	tracer := tp.Tracer("example-tracer")

	// Create a span
	ctx, span := tracer.Start(
		context.Background(),
		"example-operation",
		trace.WithAttributes(attribute.String("example.key", "example-value")),
	)
	defer span.End()

	// Add events and perform work within the span
	span.AddEvent("Starting work")
	time.Sleep(100 * time.Millisecond) // Simulate work
	span.AddEvent("Work completed")
}
```

#### Java Example

```java
// Add to build.gradle
// implementation 'io.opentelemetry:opentelemetry-api:1.18.0'
// implementation 'io.opentelemetry:opentelemetry-sdk:1.18.0'
// implementation 'io.opentelemetry:opentelemetry-exporter-otlp:1.18.0'

SdkTracerProvider tracerProvider = SdkTracerProvider.builder()
    .setResource(Resource.getDefault().toBuilder()
        .put(ResourceAttributes.SERVICE_NAME, "your-service-name")
        .build())
    .addSpanProcessor(BatchSpanProcessor.builder(
        OtlpGrpcSpanExporter.builder()
            .setEndpoint("http://192.168.3.2:4317")
            .build())
        .build())
    .build();

OpenTelemetrySdk openTelemetry = OpenTelemetrySdk.builder()
    .setTracerProvider(tracerProvider)
    .build();
```

## Configuration Details

### Resource Usage

By default, the LGTM stack is configured with modest resource requirements. For production use, consider adjusting:

- **Retention periods**: Modify storage retention for logs and metrics
- **Memory limits**: Set appropriate memory limits in docker-compose.yml
- **Disk space**: Monitor disk usage of persistent volumes

### Ports

| Service | Port | Purpose |
|---------|------|---------|
| Grafana | 3000 | Web UI |
| Prometheus | 9090 | Metrics API & UI |
| Loki | 3100 | Logs API |
| Tempo | 3200 | Traces API |
| Tempo | 4317 | OTLP gRPC receiver |
| Tempo | 4318 | OTLP HTTP receiver |
| Pyroscope | 4040 | Profiling API & UI |
| OpenTelemetry | 4317 | OTLP gRPC receiver |
| OpenTelemetry | 4318 | OTLP HTTP receiver |
| Node Exporter | 9100 | System metrics |
| cAdvisor | 8084 | Container metrics |

## Maintenance

### Backups

Consider setting up regular backups of:

- Grafana data: `/var/lib/grafana`
- Prometheus data: `/prometheus`
- Loki data: `/loki`

### Monitoring the Monitoring

To monitor the health of the monitoring stack itself:

1. Check service status:
```bash
docker compose ps
```

2. View logs for specific services:
```bash
docker compose logs prometheus
docker compose logs loki
```

3. Check disk usage of volumes:
```bash
docker system df -v
```

## Troubleshooting

### Common Issues

1. **Grafana can't connect to datasources**:
- Verify network connectivity between containers
- Check if datasource services are running

2. **Missing metrics or logs**:
- Check Prometheus targets: http://192.168.3.2:9090/targets
- Verify Loki and Promtail configuration
- Check for permission issues with log access

3. **OpenTelemetry not collecting data**:
- Verify collector is running with `docker compose ps`
- Check collector logs with `docker compose logs otel-collector`
- Ensure your application's OTLP endpoint is correctly configured

## Resources

- [OpenTelemetry Documentation](https://opentelemetry.io/docs/)
- [Grafana Documentation](https://grafana.com/docs/)
- [Prometheus Documentation](https://prometheus.io/docs/introduction/overview/)
- [Loki Documentation](https://grafana.com/docs/loki/latest/)
- [Tempo Documentation](https://grafana.com/docs/tempo/latest/)
- [Pyroscope Documentation](https://grafana.com/docs/pyroscope/latest/) 