# VC-AuthN OIDC Bridge

🚀 **Plug-and-play OpenID Connect bridge for enabling W3C Verifiable Credentials authentication in Keycloak (or any OIDC-compatible IdP).**

Enable VC-based authentication for your existing Keycloak setup in minutes without any code changes!

## 🎯 What Does This Do?

This OIDC bridge allows any organization with an existing Keycloak (or similar) Identity Provider to onboard W3C Verifiable Credentials as an authentication method in just a few minutes. No code changes required - just configuration!

### Architecture

```
┌──────────┐     ┌─────────────┐     ┌──────────────┐     ┌─────────┐
│ Keycloak │────▶│ OIDC Bridge │────▶│ Dart Verifier│────▶│ Wallet  │
│   IdP    │◀────│  (Node.js)  │◀────│   (MPX SDK)  │◀────│(Flutter)│
└──────────┘     └─────────────┘     └──────────────┘     └─────────┘
```

1. **Keycloak** redirects user to OIDC Bridge
2. **OIDC Bridge** fetches OOB invitation from Dart Verifier Server
3. **User** scans QR code with wallet app
4. **Wallet** presents credentials via DIDComm (MPX SDK)
5. **Dart Verifier** validates credentials and notifies OIDC Bridge
6. **OIDC Bridge** issues ID token to Keycloak
7. **User** is authenticated! 🎉

## 🚀 Quick Start

### Prerequisites

- Node.js 18+ (for OIDC bridge)
- Dart Verifier Server running ([vdsp-verifier-server](file:///Users/admin/Documents/vdsp-verifier-server))
- Keycloak instance
- Flutter wallet with Affinidi TDK + MPX SDK

### Installation

```bash
# Clone or navigate to this directory
cd vc-authn-oidc-bridge

# Install dependencies
npm install

# Copy environment template
cp .env.example .env

# Edit .env with your configuration
nano .env

# Generate RSA keys (automatic on first run)
node src/server.js
```

### Configuration

Edit `.env`:

```bash
# Server Configuration
PORT=5000
SESSION_SECRET=your-random-secret-here

# OIDC Configuration
ISSUER_URL=http://localhost:5000
CONTROLLER_URL=http://localhost:5000

# Keycloak Client Configuration (get from Keycloak IdP settings)
KEYCLOAK_CLIENT_ID=vc-authn
KEYCLOAK_CLIENT_SECRET=your-secret-from-keycloak
KEYCLOAK_REDIRECT_URI=http://localhost:8880/realms/vdsp-demo/broker/vc-authn/endpoint

# Dart Verifier Server Configuration
VERIFIER_SERVER_URL=http://localhost:8080
VERIFIER_CLIENT_ID=vdsp-verifier
VERIFIER_AUTH_TOKEN=my_secure_token

# JWT Configuration
JWT_ALGORITHM=RS256
HASH_SALT=random-salt-for-subject-ids
```

### Running

```bash
# Development
npm run dev

# Production
npm start
```

## 🔧 Keycloak Setup

### Step 1: Add Identity Provider

1. Log into **Keycloak Admin Console**
2. Navigate to **Identity Providers** → **OpenID Connect v1.0**
3. Configure:

```
Alias: vc-authn
Display Name: Login with Verifiable Credentials

Discovery URL: http://localhost:5000/.well-known/openid-configuration

Client ID: vc-authn
Client Secret: <generate-strong-secret>
Client Authentication: Client secret sent as post

Default Scopes: openid profile email

Forwarded Query Parameters: pres_req_conf_id
```

4. **Save** and note the **Redirect URI** (e.g., `http://localhost:8880/realms/vdsp-demo/broker/vc-authn/endpoint`)

### Step 2: Update Bridge Configuration

Copy the **Client ID**, **Client Secret**, and **Redirect URI** from Keycloak to your `.env` file.

### Step 3: Test

1. Go to your application login page
2. Click "**Login with Verifiable Credentials**"
3. Scan QR code with wallet
4. Share credentials
5. You're authenticated! ✅

## 📡 API Endpoints

### OIDC Endpoints

- `GET /.well-known/openid-configuration` - OIDC discovery
- `GET /.well-known/jwks` - Public keys (JWKS)
- `GET /authorize` - Authorization endpoint (shows QR code)
- `POST /token` - Token endpoint (exchanges auth code for ID token)
- `GET /callback` - Callback after verification

### Admin Endpoints

- `GET /health` - Health check
- `GET /admin` - Admin dashboard (sessions, config)
- `GET /admin/clients` - List verifier clients
- `GET /admin/docs` - Interactive setup guide

## 🐳 Docker Deployment

### Using Docker Compose

```bash
# Build and run
docker-compose up -d vc-authn-oidc-bridge

# View logs
docker-compose logs -f vc-authn-oidc-bridge

# Stop
docker-compose down
```

### Standalone Docker

```bash
# Build image
docker build -t vc-authn-oidc-bridge .

# Run container
docker run -d \
  --name vc-authn-oidc-bridge \
  -p 5000:5000 \
  --env-file .env \
  vc-authn-oidc-bridge

# View logs
docker logs -f vc-authn-oidc-bridge
```

## 🏗️ Project Structure

```
vc-authn-oidc-bridge/
├── src/
│   ├── server.js              # Express app entry point
│   ├── routes/
│   │   ├── oidc.js            # OIDC endpoints (discovery, authorize, token)
│   │   └── admin.js           # Admin dashboard and docs
│   └── utils/
│       ├── crypto.js          # RSA key generation, JWT signing
│       ├── session-store.js   # Session management
│       └── verifier-client.js # HTTP/WebSocket client for Dart server
├── views/
│   └── scan-credential.ejs    # QR code scanning UI
├── keys/                       # RSA keys (auto-generated)
├── .env                        # Configuration (do not commit!)
├── package.json
└── Dockerfile
```

## 🔍 How It Works

### 1. Authorization Flow

```javascript
// User clicks "Login with VC" in Keycloak
GET /authorize?response_type=code&client_id=vc-authn&redirect_uri=...&state=xyz

// Bridge fetches OOB invitation from Dart verifier
const oobUrl = await verifierClient.getOobUrl(clientId);

// Generate QR code and show to user
// User scans with wallet app

// Wallet presents credentials via DIDComm

// Dart verifier validates and sends WebSocket update
ws.send({ status: 'verified', claims: {...} })

// Bridge creates auth code and redirects
redirect_uri?code=abc123&state=xyz
```

### 2. Token Exchange

```javascript
// Keycloak exchanges auth code for tokens
POST /token
  grant_type=authorization_code
  code=abc123
  client_id=vc-authn
  client_secret=secret

// Bridge validates and issues ID token
{
  access_token: "...",
  id_token: "eyJhbGc..." (signed JWT with user claims),
  token_type: "Bearer"
}
```

### 3. Real-Time Updates

```javascript
// WebSocket connection to Dart verifier
verifierClient.subscribeToVerificationUpdates(sessionId, (update) => {
  if (update.status === 'verified') {
    // Store claims in session
    sessionStore.updateClaims(sessionId, update.claims);

    // Notify browser via Socket.io
    io.to(sessionId).emit('verification-complete', { success: true });
  }
});
```

## 🛠️ Development

### Prerequisites

```bash
npm install
```

### Running Tests

```bash
# Run all tests
npm test

# Run with coverage
npm run test:coverage

# Watch mode
npm run test:watch
```

### Environment Variables

| Variable | Description | Example |
|----------|-------------|---------|
| `PORT` | Server port | `5000` |
| `ISSUER_URL` | Public URL of this bridge | `http://localhost:5000` |
| `VERIFIER_SERVER_URL` | Dart verifier server URL | `http://localhost:8080` |
| `KEYCLOAK_CLIENT_ID` | Client ID from Keycloak IdP | `vc-authn` |
| `KEYCLOAK_CLIENT_SECRET` | Client secret from Keycloak | `your-secret` |
| `KEYCLOAK_REDIRECT_URI` | Redirect URI from Keycloak | `http://localhost:8880/...` |

## 🔐 Security Considerations

### Production Checklist

- [ ] Use HTTPS for all URLs (`ISSUER_URL`, `CONTROLLER_URL`)
- [ ] Generate strong `SESSION_SECRET` (32+ random bytes)
- [ ] Generate strong `KEYCLOAK_CLIENT_SECRET`
- [ ] Secure `VERIFIER_AUTH_TOKEN`
- [ ] Use Redis or database for session storage (not in-memory)
- [ ] Enable rate limiting on `/authorize` and `/token` endpoints
- [ ] Set proper CORS policies
- [ ] Rotate RSA keys periodically
- [ ] Monitor session lifetimes and cleanup
- [ ] Enable TLS for WebSocket connections

### Key Management

RSA keys are automatically generated on first run and stored in `keys/`:
- `keys/private-key.json` - Private key (keep secure!)
- `keys/public-key.json` - Public key (served at `/jwks`)

**Important:** Do not commit `keys/` directory to version control!

## 📊 Monitoring

### Health Check

```bash
curl http://localhost:5000/health
# {"status":"ok","timestamp":"2024-01-15T12:00:00.000Z"}
```

### Admin Dashboard

```bash
curl http://localhost:5000/admin
# {
#   "service": "VC-AuthN OIDC Bridge",
#   "status": "running",
#   "sessions": { "active": 3, "details": [...] },
#   "config": {...}
# }
```

### View Setup Guide

Open in browser: `http://localhost:5000/admin/docs`

## 🤝 Integration with Dart Verifier Server

This bridge depends on the Dart Verifier Server for credential verification:

### Expected Dart Server Endpoints

```dart
// GET /api/clients
// Returns: { clientId, oobUrl, status }

// WebSocket: ws://localhost:8080/ws/{clientId}
// Sends: { status: 'verified', claims: {...} }

// GET /health
// Returns: { status: 'ok' }
```

### Configuration

Ensure Dart verifier server is running and accessible:

```bash
# Check health
curl http://localhost:8080/health

# Test client creation
curl http://localhost:8080/api/clients \
  -H "Authorization: Bearer my_secure_token"
```

## 📝 License

MIT License - see LICENSE file

## 🆘 Troubleshooting

### Bridge can't connect to Dart verifier

```bash
# Check verifier is running
curl http://localhost:8080/health

# Check network connectivity
ping localhost

# Verify VERIFIER_SERVER_URL in .env
```

### Keycloak can't reach bridge

```bash
# Ensure bridge is accessible from Keycloak container
docker exec keycloak curl http://host.docker.internal:5000/health

# Update ISSUER_URL to use host.docker.internal if in Docker
```

### QR code doesn't appear

- Check browser console for errors
- Verify Socket.io is connected
- Check verifier server logs for OOB generation
- Ensure VERIFIER_CLIENT_ID exists in Dart server

### Token validation fails in Keycloak

- Verify JWKS endpoint is accessible: `http://localhost:5000/.well-known/jwks`
- Check RSA keys exist in `keys/` directory
- Ensure `ISSUER_URL` matches token issuer claim
- Verify client secret matches in Keycloak and `.env`

## 📚 Additional Resources

- [OpenID Connect Core Spec](https://openid.net/specs/openid-connect-core-1_0.html)
- [Keycloak Identity Brokering](https://www.keycloak.org/docs/latest/server_admin/#_identity_broker)
- [W3C Verifiable Credentials](https://www.w3.org/TR/vc-data-model/)
- [Affinidi TDK Documentation](https://docs.affinidi.com/)
- [MPX SDK Documentation](https://docs.affinidi.com/docs/sdk/meeting-place/)

---

**Made with ❤️ for enabling plug-and-play VC authentication**
