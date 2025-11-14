# Keycloak Setup Guide

This guide explains how to set up and configure Keycloak for the demo application.

## Architecture Overview

```
User → Demo App (Node.js) → Keycloak (IAM) ← PostgreSQL (Database)
```

The authentication flow uses:
- **OAuth 2.0 Authorization Code Flow** between Demo App and Keycloak
- **OpenID Connect** for authentication
- **PostgreSQL** for Keycloak data persistence

## Quick Start

### Option 1: Using Docker Compose (Recommended)

1. **Start all services:**
   ```bash
   docker-compose up -d
   ```

2. **Verify services are running:**
   ```bash
   docker-compose ps
   ```

3. **Access the services:**
   - Demo App: http://localhost:3000
   - Keycloak Admin: http://localhost:8880/admin (admin/admin)
   - PostgreSQL: localhost:5432 (keycloak/keycloak)

### Option 2: Manual Setup

#### Step 1: Start Keycloak

```bash
# Start PostgreSQL first
docker run -d \
  --name vdsp-postgres \
  -p 5432:5432 \
  -e POSTGRES_DB=keycloak \
  -e POSTGRES_USER=keycloak \
  -e POSTGRES_PASSWORD=keycloak \
  postgres:15-alpine

# Then start Keycloak
docker run -d \
  --name vdsp-keycloak \
  -p 8880:8080 \
  --link vdsp-postgres:postgres \
  -e KEYCLOAK_ADMIN=admin \
  -e KEYCLOAK_ADMIN_PASSWORD=admin \
  -e KC_HTTP_ENABLED=true \
  -e KC_HOSTNAME_STRICT=false \
  -e KC_DB=postgres \
  -e KC_DB_URL=jdbc:postgresql://postgres:5432/keycloak \
  -e KC_DB_USERNAME=keycloak \
  -e KC_DB_PASSWORD=keycloak \
  -v $(pwd)/keycloak-config:/opt/keycloak/data/import \
  quay.io/keycloak/keycloak:23.0 \
  start-dev --import-realm
```

#### Step 2: Configure Environment Variables

Copy the example environment file and update values:

```bash
cp .env.example .env
```

Edit `.env` with your specific configuration:

```bash
# Update these values
SESSION_SECRET=your-random-secret-here
KEYCLOAK_CLIENT_SECRET=your-client-secret-here
```

#### Step 3: Start Demo Application

```bash
cd demo-app
npm install
npm start
```

## Manual Keycloak Configuration

If you prefer to configure Keycloak manually instead of using the realm import:

### 1. Create Realm

1. Login to Keycloak Admin Console: http://localhost:8880/admin
2. Username: `admin`, Password: `admin`
3. Click **"Create Realm"** button
4. Enter Realm name: `vdsp-demo`
5. Click **"Create"**

### 2. Configure Realm Settings

Navigate to **Realm Settings**:

- **General Tab:**
  - Display name: `VDSP Demo Realm`
  - Enabled: `ON`

- **Login Tab:**
  - User registration: `OFF`
  - Forgot password: `ON`
  - Remember me: `ON`
  - Login with email: `ON`

- **Keys Tab:**
  - Ensure RSA keys are active

- **Tokens Tab:**
  - Access Token Lifespan: `5 Minutes` (300 seconds)
  - SSO Session Idle: `30 Minutes`
  - SSO Session Max: `10 Hours`

### 3. Create Client for Demo App

Navigate to **Clients** → **Create Client**:

#### General Settings:
- **Client Type:** `OpenID Connect`
- **Client ID:** `vdsp-demo-app`
- Click **Next**

#### Capability Config:
- **Client authentication:** `ON`
- **Authorization:** `OFF`
- **Authentication flow:**
  - ✅ Standard flow
  - ✅ Direct access grants
  - ❌ Implicit flow
  - ❌ Service accounts roles
- Click **Next**

#### Login Settings:
- **Root URL:** `http://localhost:3000`
- **Home URL:** `http://localhost:3000`
- **Valid redirect URIs:**
  - `http://localhost:3000/*`
  - `http://localhost:3000/callback`
  - `http://127.0.0.1:3000/*`
  - `http://127.0.0.1:3000/callback`
- **Valid post logout redirect URIs:** `http://localhost:3000/*`
- **Web origins:**
  - `http://localhost:3000`
  - `http://127.0.0.1:3000`
- Click **Save**

#### Get Client Secret:
1. Go to **Clients** → `vdsp-demo-app` → **Credentials** tab
2. Copy the **Client Secret**
3. Update `.env` file: `KEYCLOAK_CLIENT_SECRET=<your-secret-here>`

### 4. Create Test Users

Navigate to **Users** → **Add user**:

#### Test User 1:
- **Username:** `testuser`
- **Email:** `testuser@example.com`
- **First Name:** `Test`
- **Last Name:** `User`
- **Email Verified:** `ON`
- Click **Create**
- Go to **Credentials** tab → **Set password**
- Password: `password`
- **Temporary:** `OFF`
- Click **Save**

#### Test User 2 (Admin):
- **Username:** `admin`
- **Email:** `admin@example.com`
- **First Name:** `Admin`
- **Last Name:** `User`
- **Email Verified:** `ON`
- Click **Create**
- Go to **Credentials** tab → **Set password**
- Password: `admin`
- **Temporary:** `OFF`
- Click **Save**
- Go to **Role mappings** tab
- Assign role: `admin`

## Configuration Files

### Environment Variables (`.env`)

```bash
# Application Configuration
NODE_ENV=development
PORT=3000
SESSION_SECRET=change-this-to-a-random-secure-string

# Keycloak Configuration
KEYCLOAK_URL=http://localhost:8880
KEYCLOAK_REALM=vdsp-demo
KEYCLOAK_CLIENT_ID=vdsp-demo-app
KEYCLOAK_CLIENT_SECRET=<your-client-secret-from-keycloak>

# Application URLs
APP_URL=http://localhost:3000
REDIRECT_URI=http://localhost:3000/callback
```

## Testing the Integration

### 1. Verify Keycloak is Running

```bash
curl http://localhost:8880/realms/vdsp-demo/.well-known/openid-configuration
```

### 2. Test Demo App Health

```bash
curl http://localhost:3000/health
```

Expected response:
```json
{
  "status": "healthy",
  "timestamp": "2025-11-14T...",
  "keycloak": {
    "realm": "vdsp-demo",
    "serverUrl": "http://localhost:8880"
  }
}
```

### 3. Test Authentication Flow

1. Open browser: http://localhost:3000
2. Click **"Login"** button
3. You should be redirected to Keycloak login page
4. Enter credentials: `testuser` / `password`
5. After successful authentication, you'll be redirected back to the demo app
6. View your profile at `/profile`

## Troubleshooting

### Issue: "Client secret not provided"

**Solution:** Ensure `KEYCLOAK_CLIENT_SECRET` is set in `.env` file:
```bash
KEYCLOAK_CLIENT_SECRET=your-actual-client-secret-here
```

### Issue: "Invalid redirect URI"

**Solution:** Verify redirect URIs in Keycloak client configuration include:
- `http://localhost:3000/*`
- `http://localhost:3000/callback`

### Issue: "Cannot connect to Keycloak"

**Solution:**
1. Verify Keycloak is running: `docker ps | grep keycloak`
2. Check port 8880 is not in use: `lsof -i :8880`
3. View Keycloak logs: `docker logs vdsp-keycloak`

## Security Considerations

### Production Deployment Checklist

- [ ] Change `KEYCLOAK_ADMIN_PASSWORD` to a strong password
- [ ] Update `KEYCLOAK_CLIENT_SECRET` to a cryptographically random string
- [ ] Set `SESSION_SECRET` to a random 32+ character string
- [ ] Enable SSL/TLS (`sslRequired: external` or `all`)
- [ ] Configure proper CORS policies
- [ ] Use production-grade PostgreSQL instance (already configured with PostgreSQL)
- [ ] Enable Keycloak event logging
- [ ] Configure backup strategy for Keycloak and PostgreSQL data
- [ ] Implement rate limiting
- [ ] Set appropriate token lifespans
- [ ] Enable brute force protection (already configured)
- [ ] Review and restrict client scopes
- [ ] Configure secure session cookies (`secure: true`)

### Network Security

For production, ensure:
1. Keycloak runs behind a reverse proxy (nginx/Apache)
2. Use HTTPS everywhere
3. PostgreSQL runs on private network, not exposed publicly
4. Demo app and Keycloak use secure service-to-service authentication
5. Implement proper firewall rules
6. Use private Docker networks for inter-container communication

## Advanced Configuration

### PostgreSQL Configuration

The demo already uses PostgreSQL. For production:

1. **Use External PostgreSQL:**
   - Use managed PostgreSQL service (AWS RDS, Azure Database, etc.)
   - Configure connection pooling
   - Enable automated backups
   - Set up read replicas for high availability

2. **Optimize PostgreSQL settings:**
   ```yaml
   postgres:
     environment:
       POSTGRES_MAX_CONNECTIONS: 200
       POSTGRES_SHARED_BUFFERS: 256MB
       POSTGRES_EFFECTIVE_CACHE_SIZE: 1GB
   ```

3. **Database Backup Strategy:**
   ```bash
   # Automated backup script
   docker exec vdsp-postgres pg_dump -U keycloak keycloak > backup_$(date +%Y%m%d).sql
   ```

### Custom Theme

1. Create theme directory: `keycloak-themes/vdsp-demo`
2. Mount in docker-compose:
   ```yaml
   volumes:
     - ./keycloak-themes:/opt/keycloak/themes
   ```

### High Availability Setup

For production HA deployment:
1. Use external PostgreSQL cluster
2. Enable Keycloak clustering with Infinispan
3. Use Redis for distributed session storage in demo app
4. Deploy behind load balancer
5. Configure sticky sessions

## Monitoring and Logging

### Enable Keycloak Events

In Realm Settings → Events:
- **Save Events:** `ON`
- **Event listeners:** `jboss-logging`
- **Saved Types:** Select relevant events

### Application Logging

The demo app uses Morgan for HTTP logging. View logs:
```bash
docker logs -f vdsp-demo-app
```

### Keycloak Admin Events

Navigate to **Events** → **Admin Events** to view configuration changes.

## Backup and Restore

### Export Realm Configuration

```bash
docker exec -it vdsp-keycloak /opt/keycloak/bin/kc.sh export \
  --dir /tmp/export \
  --realm vdsp-demo
```

### Import Realm Configuration

```bash
docker exec -it vdsp-keycloak /opt/keycloak/bin/kc.sh import \
  --dir /opt/keycloak/data/import \
  --override true
```

## Additional Resources

- [Keycloak Documentation](https://www.keycloak.org/documentation)
- [OpenID Connect Specification](https://openid.net/specs/openid-connect-core-1_0.html)
- [OAuth 2.0 RFC](https://tools.ietf.org/html/rfc6749)
- [Keycloak on Docker](https://www.keycloak.org/server/containers)
- [PostgreSQL Documentation](https://www.postgresql.org/docs/)

## Support

For issues or questions:
1. Check the troubleshooting section above
2. Review application logs: `docker logs vdsp-demo-app`
3. Review Keycloak logs: `docker logs vdsp-keycloak`
4. Open an issue on GitHub repository
