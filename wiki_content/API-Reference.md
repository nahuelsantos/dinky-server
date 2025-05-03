Dinky Server provides several APIs for service interaction and management. This page documents the available endpoints and how to use them.

## Mail API

The Mail API allows programmatic sending of emails through your Dinky Server installation.

### Base URL

```
https://mail-api.yourdomain.com/api/v1
```

### Authentication

All API requests require an API key passed in the `X-API-KEY` header:

```
X-API-KEY: your-api-key-here
```

API keys can be generated and managed through the Dinky Server admin interface.

### Endpoints

#### Send Email

```
POST /email/send
```

**Request Body:**

```json
{
  "to": "recipient@example.com",
  "from": "sender@yourdomain.com",
  "subject": "Email Subject",
  "text": "Plain text content",
  "html": "<p>HTML content (optional)</p>",
  "attachments": [
    {
      "filename": "document.pdf",
      "content": "base64-encoded-content"
    }
  ]
}
```

**Response:**

```json
{
  "success": true,
  "message": "Email queued for delivery",
  "messageId": "message-id-12345"
}
```

#### Check Email Status

```
GET /email/status/:messageId
```

**Response:**

```json
{
  "status": "delivered",
  "timestamp": "2023-05-22T15:32:45Z",
  "details": {
    "to": "recipient@example.com",
    "from": "sender@yourdomain.com",
    "subject": "Email Subject"
  }
}
```

## Monitoring API

The Monitoring API provides access to server health and performance metrics.

### Base URL

```
https://monitoring.yourdomain.com/api/v1
```

### Endpoints

#### System Status

```
GET /status
```

**Response:**

```json
{
  "status": "healthy",
  "uptime": "5d 12h 32m",
  "services": {
    "traefik": "running",
    "mailserver": "running",
    "mailapi": "running",
    "pihole": "running"
  }
}
```

#### Resource Usage

```
GET /resources
```

**Response:**

```json
{
  "cpu": {
    "usage": 22.5,
    "cores": 4
  },
  "memory": {
    "total": 8192,
    "used": 3584,
    "free": 4608
  },
  "disk": {
    "total": 250000,
    "used": 98000,
    "free": 152000
  }
}
```

## Error Handling

All APIs use standard HTTP status codes:

- `200 OK`: Request succeeded
- `400 Bad Request`: Invalid request parameters
- `401 Unauthorized`: Invalid or missing API key
- `404 Not Found`: Resource not found
- `500 Internal Server Error`: Server error

Error responses include a JSON body:

```json
{
  "error": true,
  "message": "Error message details",
  "code": "ERROR_CODE"
}
```

## Rate Limiting

API requests are limited to 100 requests per minute per API key. Exceeding this limit will result in a `429 Too Many Requests` response.

## Need Help?

For additional help or to report issues with the API, please create a GitHub issue or reach out to the project maintainers. 