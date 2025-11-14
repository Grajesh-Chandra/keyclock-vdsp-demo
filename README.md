# Keycloak + Verifiable Credentials Demo

🚀 **Federated login with Verifiable Credentials - "Login with VC" like "Login with Google"**

Enable passwordless authentication using W3C Verifiable Credentials for any existing Keycloak setup - no code changes required!

## Overview

This demo implements federated identity login using Verifiable Credentials, providing two authentication methods:

1. **Traditional OAuth 2.0 / OpenID Connect** - Standard username/password
2. **Verifiable Credentials (VC)** - Scan QR code with wallet app 🆕

### Tech Stack

- **Keycloak 23.0** - Identity and Access Management (IAM)
- **VC-AuthN OIDC Bridge** - OpenID Connect provider for VC authentication
- **Dart Verifier** - Affinidi MPX SDK for DIDComm protocol
- **Wallet App** - Mobile wallet with Affinidi TDK + MPX SDK
- **Demo App** - Node.js/Express demonstration application

## Architecture

### Verifiable Credentials Authentication Flow 🆕
```
┌──────────┐  1.Click Login   ┌──────────┐  2.Redirect     ┌──────────┐
│ Browser  │─────────────────▶│ Demo App │────────────────▶│ Keycloak │
└──────────┘                   └──────────┘                 └────┬─────┘
     ▲                                                            │ 3.Federated IdP
     │                                                            ▼
     │                                                      ┌──────────┐
     │                                                      │  OIDC    │
     │                                                      │  Bridge  │
     │                                                      └────┬─────┘
     │                                                           │ 4.Get OOB
     │                                                           ▼
     │                                                      ┌──────────┐
     │                         8.Redirect with              │   Dart   │
     │                            ID Token                  │ Verifier │
     │◀──────────────────────────────────────              └────┬─────┘
     │                                                           │
     │ 5.Display QR                                             │ 6.DIDComm
     │◀──────────────────────────────────────────────────────┐  │
     │                                                        │  │
     │                                                        │  │
     │                                               7.Share  │  │
     │                                              Credential▼  ▼
     │                                                   ┌──────────┐
     └───────────────────────────────────────────────────│  Wallet  │
                                                         └──────────┘
```

**Flow Steps:**
1. User clicks "Login with Verifiable Credentials" in demo app
2. Demo app redirects to Keycloak authorization endpoint
3. Keycloak detects `vc-authn` Identity Provider and redirects
4. OIDC Bridge requests OOB invitation URL from Dart Verifier
5. QR code displayed to user with real-time WebSocket updates
6. User scans QR with wallet, DIDComm connection established
7. Wallet presents verifiable credential to Dart Verifier
8. Dart Verifier validates and notifies OIDC Bridge via WebSocket
9. OIDC Bridge extracts claims and issues ID Token to Keycloak
10. Keycloak creates/updates user and completes SSO flow
11. User authenticated and redirected to demo app ✅

## Quick Start

### Prerequisites

- Docker and Docker Compose
- Node.js 18+ (for local development)
- Dart Verifier running on port 8081
- Wallet app with Affinidi TDK + MPX SDK

### Start Services

```bash
# Start Keycloak and PostgreSQL in Docker
docker compose up -d keycloak postgres

# Start OIDC Bridge (locally for development)
cd vc-authn-oidc-bridge
npm install
cp .env.example .env
# Edit .env with your configuration
npm start

# Start Demo App (locally for development)
cd demo-app
npm install
npm start

# Start Dart Verifier (in separate terminal)
cd /path/to/dart-verifier
dart run bin/server.dart
```

### Access Points
- **Demo App**: http://localhost:3000
- **Keycloak Admin**: http://localhost:8880/admin (admin/admin)
- **OIDC Bridge**: http://localhost:5001
- **Dart Verifier**: http://localhost:8081

### Test VC Authentication
1. Go to http://localhost:3000
2. Click "Login with Verifiable Credentials"
3. Scan QR code with your wallet app
4. Share your Ayra Business Card credential
5. You're logged in! 🎉

## Configuration

### OIDC Bridge (.env)

```bash
# Server
PORT=5001
ISSUER_URL=http://localhost:5001

# Dart Verifier
VERIFIER_SERVER_URL=http://localhost:8081
VERIFIER_CLIENT_ID=federatedlogin

# Keycloak Client Credentials
KEYCLOAK_CLIENT_ID=vc-authn
KEYCLOAK_CLIENT_SECRET=vc-authn-secret-change-me
KEYCLOAK_REDIRECT_URI=http://localhost:8880/realms/vdsp-demo/broker/vc-authn/endpoint
```

### Keycloak Identity Provider

The realm configuration includes a pre-configured `vc-authn` Identity Provider:

- **Client ID**: `vc-authn`
- **Client Secret**: `vc-authn-secret-change-me`
- **Authorization URL**: `http://localhost:5001/authorize`
- **Token URL**: `http://host.docker.internal:5001/token`
- **JWKS URL**: `http://host.docker.internal:5001/.well-known/jwks`

Mappers configured:
- `email` → User email
- `given_name` → First name
- `family_name` → Last name
- `name` → Full name
- `company` → Custom attribute

## Features

### ✅ Implemented

- **Federated VC Login** - "Login with VC" button like "Login with Google"
- **QR Code Authentication** - Real-time WebSocket updates
- **Claim Extraction** - Maps VC claims to Keycloak user attributes
- **Session Management** - Secure session handling with nonce support
- **Rate Limiting** - Protection against abuse
- **Docker Support** - Production-ready containerization
- **Local Development** - Easy local testing without Docker routing

### 🎯 Key Capabilities

- ✅ W3C Verifiable Credentials support (AyraBusinessCard)
- ✅ DIDComm protocol via Affinidi MPX SDK
- ✅ Real-time verification status updates
- ✅ Automatic user provisioning from VC claims
- ✅ No code changes to Keycloak required
- ✅ OpenID Connect compliant
- ✅ Production-ready security features

## Documentation

- **[Quick Start](./QUICKSTART.md)** - Get started in 5 minutes
- **[Implementation Guide](./docs/IMPLEMENTATION_GUIDE.md)** - Complete step-by-step setup
- **[Architecture](./docs/FEDERATED_VC_LOGIN_ARCHITECTURE.md)** - System design and flow
- **[Keycloak Setup](./docs/VC_AUTHN_SETUP.md)** - Configure Keycloak Identity Provider
- **[QR Code Flow](./docs/QR_CODE_FLOW_INTEGRATION.md)** - WebSocket and real-time updates

## Project Structure

```
keyclock-vdsp-demo/
├── vc-authn-oidc-bridge/      # OIDC provider for VC authentication
│   ├── src/
│   │   ├── routes/
│   │   │   ├── oidc.js        # OIDC endpoints (.well-known, /authorize, /token)
│   │   │   └── admin.js       # Admin dashboard
│   │   ├── utils/
│   │   │   ├── crypto.js      # JWT/JWK signing
│   │   │   ├── session-store.js  # Session management
│   │   │   └── verifier-client.js # Dart verifier integration
│   │   └── server.js
│   └── views/
│       └── scan-credential.ejs  # QR code UI with WebSocket
├── demo-app/                  # Demo Node.js application
│   ├── server.js              # Express + keycloak-connect
│   ├── views/
│   │   ├── index.ejs          # Landing page with VDSP architecture
│   │   └── profile.ejs        # User profile after login
│   └── public/                # Static assets
├── keycloak-config/           # Keycloak realm configuration
│   └── vdsp-demo-realm.json  # Pre-configured realm with vc-authn IdP
├── docs/                      # Documentation
└── docker-compose.yml         # Service orchestration
```

## Development

### Run OIDC Bridge

## Development

### Run OIDC Bridge Locally

```bash
cd vc-authn-oidc-bridge
npm install
cp .env.example .env
# Edit .env with VERIFIER_SERVER_URL=http://localhost:8081
npm start  # Runs on port 5001
```

### Run Demo App Locally

```bash
cd demo-app
npm install
npm start  # Runs on port 3000
```

### Run with Docker (Keycloak + PostgreSQL only)

```bash
# Start just Keycloak and database
docker compose up -d keycloak postgres

# Run OIDC Bridge and Demo App locally (easier for development)
```

### Start Dart Verifier

```bash
cd /path/to/dart-verifier
dart run bin/server.dart  # Runs on port 8081
```

## Troubleshooting

### Common Issues

**Port 5001 already in use (macOS AirPlay)**
```bash
# Disable AirPlay Receiver in System Preferences
# Or change PORT in vc-authn-oidc-bridge/.env
```

**Keycloak can't reach OIDC Bridge**
- When Keycloak runs in Docker, use `host.docker.internal:5001` for token/JWKS URLs
- Authorization URL uses `localhost:5001` (browser-facing)

**QR code not displaying**
- Verify Dart Verifier is running: `curl http://localhost:8081/api/oob/clients`
- Check OIDC Bridge logs: `tail -f vc-authn-oidc-bridge/oidc-bridge.log`
- Verify `federatedlogin` client exists in Dart Verifier

**"Invalid client" error**
- Verify `KEYCLOAK_CLIENT_SECRET` matches between:
  - `vc-authn-oidc-bridge/.env`
  - Keycloak realm config (`vc-authn-secret-change-me`)

**WebSocket updates not working**
- Check browser console for Socket.io connection errors
- Verify WebSocket endpoint: `ws://localhost:8081/ws/{clientId}`
- Check Dart Verifier WebSocket implementation

### Health Checks

```bash
# OIDC Bridge
curl http://localhost:5001/health

# Dart Verifier
curl http://localhost:8081/api/oob/clients

# Keycloak
curl http://localhost:8880/realms/vdsp-demo/.well-known/openid-configuration

# Demo App
curl http://localhost:3000/health
```

### Logs

```bash
# OIDC Bridge (local)
tail -f vc-authn-oidc-bridge/oidc-bridge.log

# Demo App (local)
tail -f demo-app/demo-app.log

# Keycloak (Docker)
docker logs -f vdsp-keycloak

# PostgreSQL (Docker)
docker logs -f vdsp-postgres
```

## Production Deployment

### Security Checklist

- [ ] Use HTTPS for all URLs (`https://vc-authn.yourdomain.com`)
- [ ] Generate strong secrets (32+ bytes):
  - `SESSION_SECRET`
  - `KEYCLOAK_CLIENT_SECRET`
  - `VERIFIER_AUTH_TOKEN`
- [ ] Use Redis for session storage (not in-memory)
- [ ] Enable rate limiting (already configured)
- [ ] Rotate RSA keys periodically
- [ ] Configure CORS properly
- [ ] Use managed PostgreSQL (not Docker)
- [ ] Enable Keycloak event logging
- [ ] Set up monitoring and alerts
- [ ] Configure backup strategy
- [ ] Use environment-specific configs

### Environment Variables

Production `.env` example:

```bash
# OIDC Bridge
PORT=5001
NODE_ENV=production
ISSUER_URL=https://vc-authn.yourdomain.com
VERIFIER_SERVER_URL=https://verifier.yourdomain.com
KEYCLOAK_CLIENT_SECRET=<strong-random-secret>
SESSION_SECRET=<strong-random-secret>
SESSION_STORE=redis
REDIS_URL=redis://localhost:6379

# Demo App
KEYCLOAK_URL=https://keycloak.yourdomain.com
APP_URL=https://app.yourdomain.com
```

## Testing

### Manual Test Flow

1. **Start all services**
   ```bash
   docker compose up -d keycloak postgres
   cd vc-authn-oidc-bridge && npm start &
   cd demo-app && npm start &
   cd /path/to/dart-verifier && dart run bin/server.dart &
   ```

2. **Test traditional login**
   - Visit http://localhost:3000
   - Click "Login" (traditional)
   - Use testuser/password
   - Verify redirect to profile

3. **Test VC login**
   - Visit http://localhost:3000
   - Click "Login with Verifiable Credentials"
   - Verify QR code displays
   - Scan with wallet app
   - Share Ayra Business Card
   - Verify automatic login and redirect

4. **Verify user creation**
   - Open Keycloak Admin: http://localhost:8880/admin
   - Go to Users
   - Verify new user from VC with correct attributes

### Automated Tests

```bash
# Test OIDC endpoints
curl http://localhost:5001/.well-known/openid-configuration
curl http://localhost:5001/.well-known/jwks

# Test health endpoints
./test-setup.sh
```

## Architecture Decisions

### Why Separate OIDC Bridge?

- **No Keycloak modifications**: Works with any Keycloak instance
- **Pluggable**: Can connect to any verifier implementing the OOB API
- **Reusable**: Same bridge works for multiple use cases
- **Maintainable**: Clear separation of concerns

### Why Node.js?

- **Fast development**: Express + Socket.io for real-time updates
- **JWT libraries**: Excellent `jose` library for OIDC
- **Ecosystem**: Rich npm packages for OIDC/crypto

### Why WebSocket?

- **Real-time updates**: Show verification progress to user
- **User experience**: No polling, instant feedback
- **Scalable**: Socket.io handles reconnection automatically

## Contributing

Contributions welcome! Please:

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests if applicable
5. Submit a pull request

## License

Apache 2.0 License - see [LICENSE](LICENSE) file.

## Acknowledgments

- **Affinidi** - TDK and MPX SDK for verifiable credentials
- **Keycloak** - Open source IAM platform
- **W3C** - Verifiable Credentials standard

## Support

- **Documentation**: See `/docs` folder
- **Issues**: Open a GitHub issue
- **Questions**: Check troubleshooting section first

---

**Built with ❤️ for the decentralized identity community**
