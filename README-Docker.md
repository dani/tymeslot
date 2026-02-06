# Tymeslot - Docker Deployment Guide

**Enterprise-grade meeting scheduling platform built with Elixir/Phoenix LiveView**

> For a comprehensive overview of Tymeslot's features and capabilities, see the [Core README](README.md).

## Overview

Deploy Tymeslot using Docker with an embedded PostgreSQL database. This provides:

- **Single container** with embedded PostgreSQL
- **Volume persistence** for data and uploads
- **Easy deployment** on any Docker-compatible platform

---

## System Requirements

- **Docker** (version 20.10+ recommended)
- **500MB RAM** minimum (1GB+ recommended)
- **Domain name** (optional, for production use)

---

## Quick Start

### 1. Clone Repository

```bash
git clone https://github.com/tymeslot/tymeslot.git
cd tymeslot
```

### 2. Configure Environment

```bash
# Copy environment template
cp apps/tymeslot/.env.example .env

# Generate required secrets
openssl rand -base64 64 | tr -d '\n'  # For SECRET_KEY_BASE
openssl rand -base64 32 | tr -d '\n'  # For POSTGRES_PASSWORD

# Edit .env and fill in the required values
nano .env
```

**Required Configuration** (`.env` file):

```bash
# REQUIRED: Must be at least 64 characters
SECRET_KEY_BASE=<paste_generated_secret>

# REQUIRED: Your domain (or "localhost" for testing)
PHX_HOST=localhost

# REQUIRED: Database credentials
POSTGRES_DB=tymeslot
POSTGRES_USER=tymeslot
POSTGRES_PASSWORD=<paste_generated_password>

# OPTIONAL: Port (defaults to 4000)
PORT=4000
```

### 3. Build and Run

#### Option A: Using the Build Script (Recommended)

```bash
# Run from project root
./apps/tymeslot/build-docker.sh
```

The script will:
- Validate your `.env` configuration
- Build the Docker image
- Optionally start the container automatically

#### Option B: Using Docker Compose

```bash
# From apps/tymeslot directory
cd apps/tymeslot
docker compose up -d --build
```

#### Option C: Manual Docker Commands

```bash
# Build image (from project root)
source .env
docker build -f apps/tymeslot/Dockerfile.docker -t tymeslot .

# Run container
docker run -d \
  --name tymeslot \
  -p ${PORT:-4000}:4000 \
  --env-file .env \
  -v tymeslot_data:/app/data \
  -v postgres_data:/var/lib/postgresql/data \
  tymeslot
```

### 4. Access Your Installation

Wait 30-60 seconds for initialization, then visit:

- **URL**: `http://localhost:4000`

For production deployment with SSL/HTTPS, configure your reverse proxy (Nginx, Caddy, Traefik, etc.) separately.

---

## Understanding the Deployment Scripts

Tymeslot uses two scripts for Docker deployment:

### build-docker.sh (Host Machine)

Runs on your host machine to prepare and build the Docker image.

**Responsibilities**:
- Validates `.env` file exists
- Validates required environment variables
- Checks SECRET_KEY_BASE meets security requirements (64+ characters)
- Builds Docker image
- Optionally starts the container

**Usage**:
```bash
./apps/tymeslot/build-docker.sh
```

### start-docker.sh (Container Entrypoint)

Runs automatically inside the container when it starts.

**Responsibilities**:
- Initializes PostgreSQL database (first run only)
- Starts PostgreSQL service
- Creates database and user
- Runs database migrations
- Starts Phoenix web server

**Note**: This script runs automatically - you never call it directly.

---

## Configuration

### Required Environment Variables

```bash
SECRET_KEY_BASE=<64+ characters>
PHX_HOST=<your-domain-or-localhost>
POSTGRES_DB=tymeslot
POSTGRES_USER=tymeslot
POSTGRES_PASSWORD=<secure-password>
```

### Optional Environment Variables

```bash
# Application
PORT=4000                    # HTTP port (default: 4000)
DATABASE_POOL_SIZE=10        # DB pool size (default: 10)

# Email (defaults to test adapter - no external service needed)
EMAIL_ADAPTER=test           # Options: test, smtp, postmark
EMAIL_FROM_NAME="Tymeslot"
EMAIL_FROM_ADDRESS=hello@localhost

# SMTP (if EMAIL_ADAPTER=smtp)
SMTP_HOST=
SMTP_PORT=587
SMTP_USERNAME=
SMTP_PASSWORD=

# Postmark (if EMAIL_ADAPTER=postmark)
POSTMARK_API_KEY=

# OAuth Providers (configure through dashboard after setup)
GITHUB_CLIENT_ID=
GITHUB_CLIENT_SECRET=
GOOGLE_CLIENT_ID=
GOOGLE_CLIENT_SECRET=
ENABLE_GOOGLE_AUTH=false     # Enable Google login/signup
ENABLE_GITHUB_AUTH=false     # Enable GitHub login/signup
```

### Generate Secrets

```bash
# Generate SECRET_KEY_BASE (64+ characters)
openssl rand -base64 64 | tr -d '\n'

# Generate database password
openssl rand -base64 32 | tr -d '\n'

# Generate OAuth state secrets (if needed)
openssl rand -base64 32 | tr -d '\n'
```

---

## Common Commands

```bash
# View logs
docker logs -f tymeslot

# Stop container
docker stop tymeslot

# Start container
docker start tymeslot

# Restart container
docker restart tymeslot

# Remove container
docker stop tymeslot && docker rm tymeslot

# Shell access
docker exec -it tymeslot /bin/bash

# Access Elixir console
docker exec -it tymeslot bin/tymeslot remote
```

---

## Updates

### Update to Latest Version

```bash
# Pull latest code
git pull origin main

# Rebuild and restart
./apps/tymeslot/build-docker.sh
```

Or with Docker Compose:

```bash
git pull origin main
cd apps/tymeslot
docker compose down
docker compose up -d --build
```

---

## Troubleshooting

### Container Won't Start

```bash
# Check logs for errors
docker logs tymeslot

# Common causes:
# - Missing or invalid environment variables
# - SECRET_KEY_BASE too short (must be 64+ characters)
# - Port 4000 already in use
# - Insufficient disk space
```

**Verify configuration**:
```bash
source .env
echo "SECRET_KEY_BASE length: ${#SECRET_KEY_BASE}"  # Should be >= 64
echo "PHX_HOST: $PHX_HOST"
echo "POSTGRES_PASSWORD set: $([ -n "$POSTGRES_PASSWORD" ] && echo 'Yes' || echo 'No')"
```

### Container Starts But Can't Access Application

Wait 30-60 seconds for:
- PostgreSQL initialization
- Database migrations
- Phoenix server startup

Check startup progress:
```bash
docker logs -f tymeslot
```

Look for: `Running TymeslotWeb.Endpoint` message.

### Database Issues

```bash
# Check PostgreSQL is running
docker exec -it tymeslot ps aux | grep postgres

# Verify database connection
docker exec -it tymeslot su - postgres -c "psql -U $POSTGRES_USER -d $POSTGRES_DB -c 'SELECT version();'"

# Reset database (WARNING: Destroys all data)
docker volume rm postgres_data
```

### Port Already in Use

```bash
# Check what's using port 4000
sudo lsof -i :4000

# Either stop the conflicting service or change PORT in .env
PORT=8080  # Use a different port
```

### OAuth Not Working

- Verify redirect URLs exactly match: `https://your-domain.com/auth/provider/callback`
- Check PHX_HOST matches your domain
- Ensure credentials are correctly set in `.env`
- Configure OAuth apps through the Tymeslot dashboard after deployment

---

## Production Checklist

- [ ] **SSL/TLS certificate** configured (via reverse proxy)
- [ ] **Domain name** pointing to your server
- [ ] **Strong secrets** generated for all passwords and keys
- [ ] **Environment variables** validated and set correctly
- [ ] **Email service** configured (Postmark or SMTP)
- [ ] **OAuth providers** configured (if needed)
- [ ] **Firewall** configured appropriately
- [ ] **Backups** scheduled for Docker volumes

---

## Support

### Getting Help

- **Check logs first**: `docker logs tymeslot`
- **GitHub Issues**: Report bugs and feature requests
- **Documentation**: Review error messages and this guide

### Useful Commands

```bash
# Container information
docker inspect tymeslot

# Container resource usage
docker stats tymeslot --no-stream

# Copy files to/from container
docker cp file.txt tymeslot:/app/
docker cp tymeslot:/app/logs/ ./logs/

# Check health
curl http://localhost:4000/healthcheck
```

---

## Next Steps

1. Create your first user account
2. Configure your profile and availability
3. Connect calendar integrations (Google Calendar, Outlook)
4. Share your booking link: `http://your-domain.com/your-username`
5. Set up email notifications (optional)
6. Configure OAuth providers (optional)

---

**Congratulations!** 🎉 Tymeslot is now running in Docker.
