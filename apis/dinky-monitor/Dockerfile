# Build stage
FROM golang:1.21-alpine AS builder

WORKDIR /app

# Install dependencies
RUN apk add --no-cache git

# Copy go mod files
COPY go.mod go.sum ./

# Download dependencies
RUN go mod download

# Copy source code (with new refactored structure)
COPY . .

# Build the application
RUN CGO_ENABLED=0 GOOS=linux go build -a -installsuffix cgo -o dinky-monitor .

# Final stage
FROM alpine:latest

# Install ca-certificates for HTTPS requests
RUN apk --no-cache add ca-certificates

WORKDIR /root/

# Copy the binary from builder stage
COPY --from=builder /app/dinky-monitor .

# Copy static files if they exist
RUN mkdir -p static html
COPY --from=builder /app/static/ ./static/ 
COPY --from=builder /app/html/ ./html/

# Expose port 3001 (updated from 8080)
EXPOSE 3001

# Add labels for Phase 5
LABEL version="5.0.0-phase5"
LABEL description="Dinky Monitor - Phase 5: Intelligence & Analytics with ML"

# Run the binary
CMD ["./dinky-monitor"] 