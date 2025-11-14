# Quick Start Guide

Get the Federated VC Login demo running in 5 minutes!

## Prerequisites

- Docker and Docker Compose installed
- Node.js 18+ installed
- Ports 3000, 5001, 8081, 8880 available
- Dart Verifier server ready

## Steps

### 1. Start Keycloak and PostgreSQL

```bash
# Start Docker services
docker compose up -d keycloak postgres

# Wait for services (about 30 seconds)
docker compose logs -f keycloak
# Look for "Keycloak ... started"
```

### 2. Start Dart Verifier

```bash
cd /path/to/dart-verifier-server
dart run bin/server.dart
# Should run on http://localhost:8081
```

Verify it's running:
```bash
curl http://localhost:8081/api/oob/clients | grep federatedlogin
```

### 3. Start OIDC Bridge

```bash
cd vc-authn-oidc-bridge
npm install
npm start
# Runs on http://localhost:5001
```

Verify it's running:
```bash
curl http://localhost:5001/health
```

### 4. Start Demo App

```bash
cd demo-app
npm install
npm start
# Runs on http://localhost:3000
```

### 5. Test VC Authentication

Open your browser to: **http://localhost:3000**

#### Test Flow:
1. Click **"Login with Verifiable Credentials"** button
2. You'll be redirected to Keycloak
3. Click **"Login with Verifiable Credentials"** on Keycloak page
4. QR code appears with real-time status
5. Scan QR code with your wallet app
6. Share your Ayra Business Card credential
7. Automatic redirect back to demo app
8. You're logged in! 🎉

### 6. Verify User Creation

1. Open Keycloak Admin: **http://localhost:8880/admin**
2. Login: `admin` / `admin`
3. Go to **Users**
4. Find newly created user from VC
5. Verify attributes populated (email, name, company)

## Service Endpoints

| Service | URL | Purpose |
|---------|-----|---------|
| Demo App | http://localhost:3000 | Main application |
| OIDC Bridge | http://localhost:5001 | VC authentication provider |
| Dart Verifier | http://localhost:8081 | DIDComm and VC verification |
| Keycloak | http://localhost:8880 | Identity and Access Management |
| Keycloak Admin | http://localhost:8880/admin | Admin console (admin/admin) |

## Configuration Files

### OIDC Bridge (.env)
```bash
PORT=5001
ISSUER_URL=http://localhost:5001
VERIFIER_SERVER_URL=http://localhost:8081
VERIFIER_CLIENT_ID=federatedlogin
KEYCLOAK_CLIENT_ID=vc-authn
KEYCLOAK_CLIENT_SECRET=vc-authn-secret-change-me
```

### Keycloak Realm
Pre-configured in `keycloak-config/vdsp-demo-realm.json`:
- Realm: `vdsp-demo`
- Identity Provider: `vc-authn`
- Client: `vdsp-demo-app`
- Mappers: email, given_name, family_name, company

## Common Commands

```bash
# Stop all services
docker compose down
# Stop local services: Ctrl+C

# View logs
docker compose logs -f keycloak
tail -f vc-authn-oidc-bridge/oidc-bridge.log
tail -f demo-app/demo-app.log

# Restart OIDC Bridge
cd vc-authn-oidc-bridge
kill $(cat oidc-bridge.pid)
npm start

# Restart Demo App
cd demo-app
kill $(cat demo-app.pid)
npm start

# Clean and restart
docker compose down -v
docker compose up -d
```

## Troubleshooting

### Port Already in Use

**Port 5001 (macOS AirPlay Receiver)**
```bash
# Disable in System Preferences > Sharing > AirPlay Receiver
# Or change PORT in vc-authn-oidc-bridge/.env
```

**Port 8880**
```bash
lsof -i :8880
kill <PID>
```

### Services Not Starting

```bash
# Check Docker is running
docker info

# View detailed logs
docker compose logs keycloak
docker compose logs postgres

# Check service health
curl http://localhost:5001/health
curl http://localhost:8081/api/oob/clients
curl http://localhost:8880/realms/vdsp-demo
```

### QR Code Not Displaying

1. Verify Dart Verifier is running:
   ```bash
   curl http://localhost:8081/api/oob/clients | grep federatedlogin
   ```

2. Check OIDC Bridge logs:
   ```bash
   tail -f vc-authn-oidc-bridge/oidc-bridge.log
   ```

3. Verify WebSocket connection in browser console

### Authentication Errors

**"Invalid client" error**
- Check `KEYCLOAK_CLIENT_SECRET` matches in:
  - `vc-authn-oidc-bridge/.env`
  - `keycloak-config/vdsp-demo-realm.json`

**"Session not found" error**
- Clear browser cookies
- Restart OIDC Bridge

**"Keycloak redirect error" **
- Verify `KEYCLOAK_REDIRECT_URI` in .env matches Keycloak IdP settings
- Check Keycloak can reach `host.docker.internal:5001`

### Keycloak Can't Reach OIDC Bridge

When Keycloak runs in Docker:
- Token URL should use: `http://host.docker.internal:5001/token`
- JWKS URL should use: `http://host.docker.internal:5001/.well-known/jwks`
- Authorization URL (browser) uses: `http://localhost:5001/authorize`

## Next Steps

- **Architecture**: Read [FEDERATED_VC_LOGIN_ARCHITECTURE.md](./FEDERATED_VC_LOGIN_ARCHITECTURE.md)
- **Keycloak Setup**: Read [VC_AUTHN_SETUP.md](./VC_AUTHN_SETUP.md)
- **QR Code Flow**: Read [QR_CODE_FLOW_INTEGRATION.md](./QR_CODE_FLOW_INTEGRATION.md)
- **Implementation**: Read [IMPLEMENTATION_GUIDE.md](./IMPLEMENTATION_GUIDE.md)

## Test Scenarios

### Scenario 1: First-Time VC Login
1. User has never logged in before
2. Shares VC via wallet
3. Keycloak creates new user
4. User attributes populated from VC claims
5. User logged in automatically

### Scenario 2: Returning VC User
1. User has logged in before with VC
2. Shares VC via wallet
3. Keycloak finds existing user by email
4. User attributes optionally updated
5. User logged in automatically

### Scenario 3: Different Credentials
1. Configure different credential type in Dart Verifier
2. Update mappers in Keycloak
3. Test with different VC schema
4. Verify claim extraction works

## Success Criteria

✅ All services start without errors
✅ QR code displays on authorize endpoint
✅ Wallet can scan and share credentials
✅ Real-time WebSocket updates work
✅ User automatically logged in after sharing VC
✅ New user created in Keycloak with correct attributes
✅ Session persists across page refreshes

## Need Help?

- **Check logs first**: `tail -f *//*.log`
- **Verify all services**: `curl http://localhost:{PORT}/health`
- **Review architecture**: `docs/FEDERATED_VC_LOGIN_ARCHITECTURE.md`
- **Test setup**: Run `./test-setup.sh`
- **Open issue**: GitHub repository

---

**Welcome to the future of authentication! 🚀**
