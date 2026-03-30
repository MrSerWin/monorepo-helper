#!/usr/bin/env bash
set -euo pipefail
source "$(cd "$(dirname "$0")/../.." && pwd)/lib/utils.sh"

parse_args "my-docker-stack" "$@"
header "Docker Compose + Nginx + PostgreSQL + Redis"

create_project_dir

# ── docker-compose.yml ───────────────────────────────────────
section "Docker Compose configuration"
write_file_heredoc docker-compose.yml << 'EOF'
services:
  nginx:
    image: nginx:1.27-alpine
    restart: unless-stopped
    ports:
      - "${NGINX_PORT:-80}:80"
      - "${NGINX_SSL_PORT:-443}:443"
    volumes:
      - ./nginx/nginx.conf:/etc/nginx/nginx.conf:ro
      - ./nginx/conf.d:/etc/nginx/conf.d:ro
    depends_on:
      app:
        condition: service_started
    networks:
      - frontend
      - backend

  app:
    build:
      context: ./app
      dockerfile: Dockerfile
    restart: unless-stopped
    env_file: .env
    environment:
      DATABASE_URL: "postgresql://${POSTGRES_USER:-postgres}:${POSTGRES_PASSWORD:-postgres}@postgres:5432/${POSTGRES_DB:-app}?sslmode=disable"
      REDIS_URL: "redis://redis:6379"
    depends_on:
      postgres:
        condition: service_healthy
      redis:
        condition: service_healthy
    networks:
      - backend

  postgres:
    image: postgres:17-alpine
    restart: unless-stopped
    ports:
      - "${POSTGRES_PORT:-5432}:5432"
    environment:
      POSTGRES_USER: ${POSTGRES_USER:-postgres}
      POSTGRES_PASSWORD: ${POSTGRES_PASSWORD:-postgres}
      POSTGRES_DB: ${POSTGRES_DB:-app}
    volumes:
      - pgdata:/var/lib/postgresql/data
      - ./postgres/init.sql:/docker-entrypoint-initdb.d/init.sql:ro
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U ${POSTGRES_USER:-postgres}"]
      interval: 5s
      timeout: 5s
      retries: 5
    networks:
      - backend

  redis:
    image: redis:7-alpine
    restart: unless-stopped
    ports:
      - "${REDIS_PORT:-6379}:6379"
    command: redis-server --appendonly yes --requirepass ${REDIS_PASSWORD:-redis}
    volumes:
      - redisdata:/data
    healthcheck:
      test: ["CMD", "redis-cli", "-a", "${REDIS_PASSWORD:-redis}", "ping"]
      interval: 5s
      timeout: 5s
      retries: 5
    networks:
      - backend

volumes:
  pgdata:
  redisdata:

networks:
  frontend:
    driver: bridge
  backend:
    driver: bridge
EOF
success "Created docker-compose.yml"

# ── Nginx configuration ─────────────────────────────────────
section "Nginx configuration"
mkdir -p nginx/conf.d

write_file_heredoc nginx/nginx.conf << 'EOF'
user  nginx;
worker_processes  auto;
error_log  /var/log/nginx/error.log warn;
pid        /var/run/nginx.pid;

events {
    worker_connections  1024;
    multi_accept on;
}

http {
    include       /etc/nginx/mime.types;
    default_type  application/octet-stream;

    log_format main '$remote_addr - $remote_user [$time_local] "$request" '
                    '$status $body_bytes_sent "$http_referer" '
                    '"$http_user_agent" "$http_x_forwarded_for"';

    access_log  /var/log/nginx/access.log  main;

    sendfile        on;
    tcp_nopush      on;
    tcp_nodelay     on;
    keepalive_timeout  65;
    types_hash_max_size 2048;
    client_max_body_size 16M;

    gzip  on;
    gzip_vary on;
    gzip_proxied any;
    gzip_comp_level 6;
    gzip_types text/plain text/css application/json application/javascript text/xml application/xml application/xml+rss text/javascript;

    # Security headers
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header Referrer-Policy "strict-origin-when-cross-origin" always;

    include /etc/nginx/conf.d/*.conf;
}
EOF
success "Created nginx/nginx.conf"

write_file_heredoc nginx/conf.d/default.conf << 'EOF'
upstream app_backend {
    server app:3000;
    keepalive 32;
}

server {
    listen 80;
    server_name localhost;

    # Health check endpoint
    location /nginx-health {
        access_log off;
        return 200 "OK\n";
        add_header Content-Type text/plain;
    }

    # API proxy
    location /api/ {
        proxy_pass http://app_backend;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_cache_bypass $http_upgrade;
        proxy_read_timeout 90s;
        proxy_send_timeout 90s;
    }

    # Health check proxy
    location /health {
        proxy_pass http://app_backend;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }

    # Static files (if serving from nginx)
    location /static/ {
        alias /usr/share/nginx/html/static/;
        expires 30d;
        add_header Cache-Control "public, immutable";
    }

    # Default fallback
    location / {
        proxy_pass http://app_backend;
        proxy_http_version 1.1;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }

    # Deny access to hidden files
    location ~ /\. {
        deny all;
        access_log off;
        log_not_found off;
    }
}
EOF
success "Created nginx/conf.d/default.conf"

# ── PostgreSQL init ──────────────────────────────────────────
section "PostgreSQL initialization"
mkdir -p postgres

write_file_heredoc postgres/init.sql << 'EOF'
-- Enable extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- Create schemas
CREATE SCHEMA IF NOT EXISTS app;

-- Users table
CREATE TABLE IF NOT EXISTS app.users (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    email VARCHAR(255) UNIQUE NOT NULL,
    name VARCHAR(255),
    password_hash VARCHAR(255),
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Sessions table
CREATE TABLE IF NOT EXISTS app.sessions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES app.users(id) ON DELETE CASCADE,
    token VARCHAR(512) UNIQUE NOT NULL,
    expires_at TIMESTAMPTZ NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Create indexes
CREATE INDEX IF NOT EXISTS idx_users_email ON app.users(email);
CREATE INDEX IF NOT EXISTS idx_sessions_token ON app.sessions(token);
CREATE INDEX IF NOT EXISTS idx_sessions_user_id ON app.sessions(user_id);

-- Updated at trigger function
CREATE OR REPLACE FUNCTION app.update_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER users_updated_at
    BEFORE UPDATE ON app.users
    FOR EACH ROW
    EXECUTE FUNCTION app.update_updated_at();
EOF
success "Created postgres/init.sql"

# ── App placeholder ──────────────────────────────────────────
section "Application placeholder"
mkdir -p app

write_file_heredoc app/Dockerfile << 'EOF'
FROM node:22-alpine AS base
WORKDIR /app

COPY package*.json ./
RUN npm ci --production

COPY . .

EXPOSE 3000

HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD wget --no-verbose --tries=1 --spider http://localhost:3000/health || exit 1

CMD ["node", "index.js"]
EOF
success "Created app/Dockerfile"

write_file_heredoc app/index.js << 'EOF'
const http = require("http");

const PORT = process.env.PORT || 3000;

const server = http.createServer((req, res) => {
  if (req.url === "/health") {
    res.writeHead(200, { "Content-Type": "application/json" });
    res.end(JSON.stringify({ status: "ok", timestamp: new Date().toISOString() }));
    return;
  }

  if (req.url?.startsWith("/api/")) {
    res.writeHead(200, { "Content-Type": "application/json" });
    res.end(JSON.stringify({ message: "API is running", path: req.url }));
    return;
  }

  res.writeHead(200, { "Content-Type": "text/plain" });
  res.end("Replace this with your application\n");
});

server.listen(PORT, () => {
  console.log(`App listening on port ${PORT}`);
});
EOF
success "Created app/index.js"

write_file_heredoc app/package.json << 'EOF'
{
  "name": "app",
  "version": "1.0.0",
  "private": true,
  "main": "index.js"
}
EOF
success "Created app/package.json"

# ── .env.example ─────────────────────────────────────────────
section "Environment configuration"
write_file_heredoc .env.example << 'EOF'
# Nginx
NGINX_PORT=80
NGINX_SSL_PORT=443

# PostgreSQL
POSTGRES_USER=postgres
POSTGRES_PASSWORD=postgres
POSTGRES_DB=app
POSTGRES_PORT=5432

# Redis
REDIS_PASSWORD=redis
REDIS_PORT=6379

# Application
APP_PORT=3000
NODE_ENV=development
EOF
success "Created .env.example"

cp .env.example .env

# ── Makefile ─────────────────────────────────────────────────
section "Makefile"
write_file_heredoc Makefile << 'MAKEFILE'
.PHONY: help up down restart logs ps build clean db-shell redis-shell shell

help: ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-20s\033[0m %s\n", $$1, $$2}'

up: ## Start all services
	docker compose up -d

up-build: ## Start all services with build
	docker compose up -d --build

down: ## Stop all services
	docker compose down

restart: ## Restart all services
	docker compose restart

logs: ## Show logs (follow mode)
	docker compose logs -f

logs-app: ## Show app logs
	docker compose logs -f app

logs-nginx: ## Show nginx logs
	docker compose logs -f nginx

ps: ## List running services
	docker compose ps

build: ## Build all images
	docker compose build

clean: ## Stop and remove all containers, volumes, and images
	docker compose down -v --rmi local

db-shell: ## Open PostgreSQL shell
	docker compose exec postgres psql -U $${POSTGRES_USER:-postgres} -d $${POSTGRES_DB:-app}

redis-shell: ## Open Redis CLI
	docker compose exec redis redis-cli -a $${REDIS_PASSWORD:-redis}

shell: ## Open shell in app container
	docker compose exec app sh

status: ## Check health of all services
	@echo "=== Service Status ==="
	@docker compose ps
	@echo ""
	@echo "=== Nginx Health ==="
	@curl -sf http://localhost:$${NGINX_PORT:-80}/nginx-health || echo "Nginx is down"
	@echo ""
	@echo "=== App Health ==="
	@curl -sf http://localhost:$${NGINX_PORT:-80}/health || echo "App is down"
MAKEFILE
success "Created Makefile"

# ── Finalize ─────────────────────────────────────────────────
section "Finalizing"
write_gitignore ".env" "*.log"
write_editorconfig
init_git

write_readme "$PROJECT_NAME" \
  "Docker Compose stack with Nginx reverse proxy, PostgreSQL, and Redis." \
  "cp .env.example .env && make up" \
  "make logs" \
  "Run \`make help\` to see all available commands."

finish "make up-build" "make status"
