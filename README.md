# Keycloak Demo Application

A demonstration application showcasing OAuth 2.0 / OpenID Connect authentication using Keycloak.

## Overview

This demo demonstrates how to integrate Keycloak authentication into a Node.js web application using:

- **Keycloak 23.0** - Identity and Access Management
- **OAuth 2.0 Authorization Code Flow** - Secure authentication flow
- **OpenID Connect** - Identity layer on top of OAuth 2.0
- **Express.js** - Node.js web application framework
- **keycloak-connect** - Official Keycloak adapter for Node.js

## Architecture

```
┌─────────────┐     ┌─────────────┐     ┌─────────────┐
│   Browser   │────▶│  Demo App   │────▶│  Keycloak   │
│             │     │  (Node.js)  │     │    (IAM)    │
└─────────────┘     └─────────────┘     └─────────────┘
      ▲                    │                    │
      └────────────────────┴────────────────────┘
                  OAuth 2.0 / OIDC Flow
```

## Quick Start

### Using Docker Compose (Recommended)

```bash
# Start all services
./start.sh

# Or manually:
docker-compose up -d
```

### Access
- **Demo App**: http://localhost:3000
- **Keycloak Admin**: http://localhost:8880/admin (admin/admin)

### Test Users
- **Username**: \`testuser\` / **Password**: \`password\`
- **Username**: \`admin\` / **Password**: \`admin\`

## Features

✅ OAuth 2.0 Authorization Code Flow
✅ OpenID Connect authentication
✅ PostgreSQL database for Keycloak
✅ Protected routes with session management
✅ Pre-configured test users
✅ Docker Compose deployment

## Documentation

- [Quick Start Guide](./docs/QUICKSTART.md) - Get started in 5 minutes
- [Keycloak Setup Guide](./docs/KEYCLOAK_SETUP.md) - Detailed configuration
- [Environment Variables](./.env.example) - Configuration options

## License

Apache 2.0 License - see [LICENSE](LICENSE) file.
