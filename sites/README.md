# Sites Directory

This directory contains website and web application services that are **automatically discovered** and can be deployed by the Dinky Server deployment system.

## 🚀 New Two-Script Architecture

Dinky Server now uses a **two-script system** for efficient deployment:

1. **`setup.sh`** - System preparation (run once)
2. **`deploy.sh`** - Service deployment and management

## How Auto-Discovery Works

The `deploy.sh` script automatically scans this directory for:
- Subdirectories containing `docker-compose.yml` or `docker-compose.yaml` files
- Each discovered site can be deployed individually or as part of a full deployment

## 🎯 Deployment Options

### **Full Deployment with Discovery**
```bash
sudo ./deploy.sh
# Will discover and offer to deploy all sites
```

### **Individual Site Deployment**
```bash
sudo ./deploy.sh --add-site my-blog
# Deploy specific site by name
```

### **Discovery Only**
```bash
sudo ./deploy.sh --discover
# Find and deploy only new/stopped sites
```

### **List All Sites**
```bash
sudo ./deploy.sh --list
# Show all sites with running status
```

## Example Structure

```
sites/
├── blog/
│   ├── docker-compose.yml
│   ├── .env (optional)
│   ├── nginx.conf
│   └── content/ (your blog content)
├── portfolio/
│   ├── docker-compose.yml
│   ├── Dockerfile
│   └── public/
├── company-website/
│   ├── docker-compose.yaml
│   ├── Dockerfile
│   └── src/
├── documentation/
│   ├── docker-compose.yml
│   └── docs/
└── example-site/              # Included example
    ├── docker-compose.yml
    ├── index.html
    └── README.md
```

## Requirements for Auto-Discovery

Each site service should:

1. **Have a docker-compose file** in its root directory (`docker-compose.yml` or `docker-compose.yaml`)
2. **Use unique ports** to avoid conflicts (recommended: 8000+)
3. **Include `traefik_network`** for reverse proxy integration (if needed)
4. **Proper Traefik labels** for routing (if using external access)

## Example docker-compose.yml Templates

### **Static Site (Basic)**
```yaml
version: '3.8'

services:
  my-website:
    image: nginx:alpine
    container_name: my-website
    restart: unless-stopped
    ports:
      - "8001:80"
    volumes:
      - ./public:/usr/share/nginx/html:ro
    networks:
      - traefik_network

networks:
  traefik_network:
    external: true
```

### **Static Site with Traefik Integration**
```yaml
version: '3.8'

services:
  my-website:
    image: nginx:alpine
    container_name: my-website
    restart: unless-stopped
    ports:
      - "8001:80"
    volumes:
      - ./public:/usr/share/nginx/html:ro
      - ./nginx.conf:/etc/nginx/nginx.conf:ro
    networks:
      - traefik_network
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.my-website.rule=Host(`${DOMAIN_NAME}`) || Host(`www.${DOMAIN_NAME}`)"
      - "traefik.http.services.my-website.loadbalancer.server.port=80"
      - "traefik.http.routers.my-website.tls=true"

networks:
  traefik_network:
    external: true
```

### **Node.js Application**
```yaml
version: '3.8'

services:
  node-app:
    image: node:18-alpine
    container_name: my-node-app
    restart: unless-stopped
    ports:
      - "8002:3000"
    working_dir: /app
    volumes:
      - ./:/app
      - /app/node_modules
    command: npm start
    environment:
      - NODE_ENV=production
      - PORT=3000
    networks:
      - traefik_network
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.node-app.rule=Host(`app.${DOMAIN_NAME}`)"
      - "traefik.http.services.node-app.loadbalancer.server.port=3000"

networks:
  traefik_network:
    external: true
```

### **WordPress Site**
```yaml
version: '3.8'

services:
  wordpress:
    image: wordpress:latest
    container_name: my-wordpress
    restart: unless-stopped
    ports:
      - "8003:80"
    depends_on:
      - wordpress-db
    environment:
      WORDPRESS_DB_HOST: wordpress-db
      WORDPRESS_DB_USER: wordpress
      WORDPRESS_DB_PASSWORD: ${WORDPRESS_DB_PASSWORD}
      WORDPRESS_DB_NAME: wordpress
    volumes:
      - wordpress-data:/var/www/html
    networks:
      - traefik_network
      - wordpress-network
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.wordpress.rule=Host(`blog.${DOMAIN_NAME}`)"
      - "traefik.http.services.wordpress.loadbalancer.server.port=80"

  wordpress-db:
    image: mysql:8.0
    container_name: my-wordpress-db
    restart: unless-stopped
    environment:
      MYSQL_DATABASE: wordpress
      MYSQL_USER: wordpress
      MYSQL_PASSWORD: ${WORDPRESS_DB_PASSWORD}
      MYSQL_ROOT_PASSWORD: ${WORDPRESS_ROOT_PASSWORD}
    volumes:
      - wordpress-db-data:/var/lib/mysql
    networks:
      - wordpress-network

volumes:
  wordpress-data:
  wordpress-db-data:

networks:
  traefik_network:
    external: true
  wordpress-network:
    driver: bridge
```

### **Hugo/Jekyll Static Site Generator**
```yaml
version: '3.8'

services:
  hugo-site:
    image: nginx:alpine
    container_name: my-hugo-site
    restart: unless-stopped
    ports:
      - "8004:80"
    volumes:
      - ./public:/usr/share/nginx/html:ro
      - ./nginx.conf:/etc/nginx/conf.d/default.conf:ro
    networks:
      - traefik_network
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.hugo-site.rule=Host(`docs.${DOMAIN_NAME}`)"
      - "traefik.http.services.hugo-site.loadbalancer.server.port=80"
      - "traefik.http.routers.hugo-site.tls=true"

networks:
  traefik_network:
    external: true
```

## 🔧 Environment Variables

The deployment script handles environment variables automatically:

### **Automatic Environment Copy**
If your site uses environment variables (`${VARIABLE_NAME}` in docker-compose.yml), the deployment script will:
1. Check for a local `.env` file in the site directory
2. If not found, copy the main `.env` file from the root

### **Site-Specific Environment**
Create a `.env` file in your site directory for service-specific variables:

```bash
# sites/my-site/.env
WORDPRESS_DB_PASSWORD=secure-password
DATABASE_URL=mysql://user:pass@db:3306/mysite
API_KEY=your-api-key
```

### **Using Root Environment**
Your site can use variables from the root `.env` file:
- `SERVER_IP` - Server IP address
- `DOMAIN_NAME` - Domain for routing
- `TZ` - Timezone setting
- Custom variables you add

## 🎮 Usage Examples

### **Adding a New Site**

1. **Create site directory**:
```bash
mkdir -p sites/my-new-blog
cd sites/my-new-blog
```

2. **Create content structure**:
```bash
mkdir public
echo "<h1>Welcome to My Blog</h1>" > public/index.html
```

3. **Create docker-compose.yml**:
```yaml
version: '3.8'
services:
  my-blog:
    image: nginx:alpine
    container_name: my-blog
    restart: unless-stopped
    ports:
      - "8010:80"
    volumes:
      - ./public:/usr/share/nginx/html:ro
    networks:
      - traefik_network
networks:
  traefik_network:
    external: true
```

4. **Deploy the site**:
```bash
sudo ./deploy.sh --add-site my-new-blog
```

### **Managing Existing Sites**

```bash
# List all sites with status
sudo ./deploy.sh --list

# Deploy only new sites
sudo ./deploy.sh --discover

# Check site logs
docker compose logs -f my-site

# Restart specific site
docker compose restart my-site
```

## 🔍 Port Management

### **Recommended Port Ranges**
- **8000-8099**: Static sites and web applications
- **8100-8199**: CMS and dynamic sites
- **8200+**: Special applications

### **Port Conflict Resolution**
If you get port conflicts:
1. Check existing services: `docker compose ps`
2. Update your site's port mapping
3. Redeploy: `sudo ./deploy.sh --add-site your-site`

## 🌐 Domain Configuration

### **Internal Access**
Sites are accessible via:
- **Direct IP**: `http://[SERVER_IP]:8001`
- **Internal domain**: `http://my-site.dinky.local` (with Traefik)

### **External Access Options**

#### **Option 1: Cloudflare Tunnel (Recommended)**
```yaml
# Add to your docker-compose.yml labels
labels:
  - "traefik.enable=true"
  - "traefik.http.routers.my-site.rule=Host(`mysite.example.com`)"
  - "traefik.http.services.my-site.loadbalancer.server.port=80"
```

Benefits:
- No port forwarding required
- Automatic SSL certificates
- DDoS protection included
- Works behind NAT/firewalls

#### **Option 2: Traditional DNS + Port Forwarding**
1. Point your domain A record to your public IP
2. Forward ports 80 and 443 to your server
3. Configure SSL certificates with Let's Encrypt:

```yaml
labels:
  - "traefik.http.routers.my-site.tls.certresolver=letsencrypt"
```

## 🔒 SSL/TLS Configuration

### **Automatic SSL with Let's Encrypt**
```yaml
labels:
  - "traefik.enable=true"
  - "traefik.http.routers.my-site.rule=Host(`example.com`)"
  - "traefik.http.routers.my-site.entrypoints=websecure"
  - "traefik.http.routers.my-site.tls.certresolver=letsencrypt"
  - "traefik.http.routers.my-site-redirect.rule=Host(`example.com`)"
  - "traefik.http.routers.my-site-redirect.entrypoints=web"
  - "traefik.http.routers.my-site-redirect.middlewares=redirect-to-https"
```

### **Custom SSL Certificates**
```yaml
labels:
  - "traefik.http.routers.my-site.tls=true"
volumes:
  - ./certs:/etc/ssl/certs:ro
```

## 🚨 Troubleshooting

### **Site Not Discovered**
```bash
# Check if docker-compose.yml exists
ls sites/my-site/docker-compose.yml

# Validate docker-compose syntax
cd sites/my-site && docker compose config
```

### **Deployment Fails**
```bash
# Check deployment logs
tail -f /var/log/dinky-deployment.log

# Check site-specific logs
cd sites/my-site && docker compose logs
```

### **Cannot Access Site**
```bash
# Check if service is running
docker compose ps

# Check port binding
netstat -tlnp | grep 8001

# Check Traefik routing
docker compose logs traefik
```

### **SSL/TLS Issues**
```bash
# Check certificate status
docker compose logs traefik | grep certificate

# Verify domain DNS
nslookup example.com

# Test SSL configuration
curl -vI https://example.com
```

## 🎯 Performance Optimization

### **Static Site Caching**
```nginx
# nginx.conf for static sites
server {
    listen 80;
    server_name _;
    root /usr/share/nginx/html;
    
    location ~* \.(js|css|png|jpg|jpeg|gif|ico|svg)$ {
        expires 1y;
        add_header Cache-Control "public, no-transform";
    }
    
    location / {
        try_files $uri $uri/ /index.html;
    }
}
```

### **Gzip Compression**
```yaml
# Add to your nginx service
volumes:
  - ./nginx.conf:/etc/nginx/nginx.conf:ro
```

### **CDN Integration**
For high-traffic sites, consider:
- Cloudflare CDN
- AWS CloudFront
- Custom CDN configuration

## 📊 Monitoring Integration

Sites are automatically integrated with the monitoring stack:

### **Nginx Metrics**
```yaml
# Add prometheus nginx exporter
nginx-exporter:
  image: nginx/nginx-prometheus-exporter:latest
  ports:
    - "9113:9113"
  command:
    - -nginx.scrape-uri=http://my-site:80/nginx_status
```

### **Uptime Monitoring**
Sites are automatically monitored for:
- HTTP response time
- Availability status
- SSL certificate expiry
- Resource usage

## 🔗 Integration with Other Services

### **Database Connections**
```yaml
# Connect to shared database
environment:
  - DATABASE_URL=postgresql://user:pass@postgres:5432/mysite

# Or use dedicated database (recommended)
services:
  site-db:
    image: postgres:15-alpine
    # ... database configuration
```

### **API Integration**
```yaml
# Connect to internal APIs
environment:
  - API_BASE_URL=http://my-api:3000
  - USER_SERVICE_URL=http://user-api:3000
```

## 📄 Example Site Templates

Check the `example-site/` directory for:
- Static HTML site with Nginx
- Proper Traefik configuration
- Environment variable usage examples
- Performance optimization examples

## 🎯 Best Practices

1. **Use semantic versioning** for custom images
2. **Include health checks** in your docker-compose
3. **Set proper restart policies** (`unless-stopped`)
4. **Use dedicated networks** for database connections
5. **Implement proper caching** strategies
6. **Configure appropriate security headers**
7. **Optimize images and assets** for web delivery
8. **Document your site** in the service directory README

## Notes

- **Port uniqueness**: Each site must use unique ports to avoid conflicts
- **Automatic discovery**: New sites are found on every deployment scan
- **Individual management**: Sites can be deployed, updated, or removed independently
- **Environment inheritance**: Sites inherit environment variables from the main `.env` file
- **Network integration**: All sites join the `traefik_network` for reverse proxy access
- **SSL automation**: Traefik can automatically provision SSL certificates with Let's Encrypt 