# Quick Start Guide

Get the Keycloak demo running in 5 minutes!

## Prerequisites

- Docker and Docker Compose installed
- Ports 3000, 5432, and 8880 available

## Steps

### 1. Start the Services

```bash
# Using the startup script (recommended)
./start.sh

# OR manually with docker-compose
docker-compose up -d
```

### 2. Wait for Services to Start

The services need about 30-60 seconds to fully start. You can monitor with:

```bash
# Watch the logs
docker-compose logs -f

# Check service status
docker-compose ps
```

### 3. Access the Application

Open your browser to: **http://localhost:3000**

### 4. Login

Click "Login" button and use these test credentials:

- **Username**: `testuser`
- **Password**: `password`

You'll be redirected to Keycloak, then back to the app after successful login.

### 5. Explore

- View your profile at `/profile`
- Try protected routes like `/employee-portal`
- Check the Keycloak Admin Console at http://localhost:8880/admin (admin/admin)

## Test Users

Two users are pre-configured:

| Username | Password | Role  |
|----------|----------|-------|
| testuser | password | user  |
| admin    | admin    | admin |

## Common Commands

```bash
# Stop services
docker-compose down

# View logs
docker-compose logs -f demo-app
docker-compose logs -f keycloak

# Restart services
docker-compose restart

# Clean everything and start fresh
docker-compose down -v
docker-compose up -d
```

## Troubleshooting

### Port Already in Use

```bash
# Check what's using the ports
lsof -i :3000
lsof -i :8880

# Stop the conflicting process or change ports in docker-compose.yml
```

### Services Not Starting

```bash
# Check Docker is running
docker info

# View detailed logs
docker-compose logs
```

### Authentication Not Working

1. Wait a bit longer - Keycloak takes time to start (especially PostgreSQL initialization)
2. Check Keycloak is accessible: http://localhost:8880
3. Verify realm imported: http://localhost:8880/realms/vdsp-demo

## Next Steps

- Read [KEYCLOAK_SETUP.md](./KEYCLOAK_SETUP.md) for detailed configuration
- Explore the code in `demo-app/server.js`
- Customize the realm in Keycloak Admin Console
- Add your own users and roles

## Need Help?

- Check the logs: `docker-compose logs -f`
- Review [KEYCLOAK_SETUP.md](./KEYCLOAK_SETUP.md) for detailed troubleshooting
- Open an issue on GitHub
