# Keycloak Configuration Files

This directory contains Keycloak realm configuration files that can be imported to quickly set up the VDSP demo environment.

## Files

- `vdsp-demo-realm.json` - Complete realm configuration including:
  - Client configuration for the demo app
  - VC-AuthN identity provider setup
  - Protocol mappers for VC attributes
  - Identity provider mappers
  - Security settings

## Import Instructions

### Automatic Import (Docker)

The Docker Compose setup automatically imports the realm configuration on first startup:

```bash
docker-compose up -d
```

### Manual Import via Admin Console

1. Access Keycloak Admin Console: http://localhost:8880/auth/admin
2. Login with credentials (admin/admin)
3. Click the realm dropdown (top left) → **"Create Realm"**
4. Click **"Browse"** button
5. Select `vdsp-demo-realm.json`
6. Click **"Create"**

### Manual Import via CLI

```bash
docker exec -it vdsp-keycloak /opt/keycloak/bin/kc.sh import \
  --file /opt/keycloak/data/import/vdsp-demo-realm.json \
  --override true
```

## Configuration Details

### Realm Settings
- **Realm Name:** `vdsp-demo`
- **SSL Required:** None (development mode)
- **User Registration:** Disabled
- **Login with Email:** Enabled

### Client: vdsp-demo-app
- **Client ID:** `vdsp-demo-app`
- **Client Secret:** `demo-secret-change-in-production` (⚠️ Change in production!)
- **Protocol:** OpenID Connect
- **Access Type:** Confidential
- **Valid Redirect URIs:** `http://localhost:3000/*`, `http://localhost:3000/callback`
- **Web Origins:** `http://localhost:3000`

### Identity Provider: vc-authn
- **Provider:** OpenID Connect
- **Alias:** `vc-authn`
- **Display Name:** Verifiable Credential Authentication
- **Client ID:** `keycloak-client`
- **Client Secret:** `vc-authn-secret`
- **Authorization URL:** `http://localhost:5001/authorize`
- **Token URL:** `http://vc-authn-oidc:5000/token`
- **User Info URL:** `http://vc-authn-oidc:5000/userinfo`

### Protocol Mappers
1. **vc-presented-attributes** - Maps VC attributes to token claims
2. **pres-req-conf-id** - Maps presentation request config ID

### Identity Provider Mappers
1. **vc-attributes-mapper** - Imports VC attributes from VC-AuthN
2. **pres-req-conf-id-mapper** - Imports presentation config ID
3. **email-mapper** - Imports email from VC-AuthN token
4. **username-mapper** - Generates username from VC-AuthN claims

## Customization

To modify the configuration:

1. Make changes in Keycloak Admin Console
2. Export the realm:
   ```bash
   docker exec -it vdsp-keycloak /opt/keycloak/bin/kc.sh export \
     --dir /tmp/export \
     --realm vdsp-demo
   ```
3. Copy exported file:
   ```bash
   docker cp vdsp-keycloak:/tmp/export/vdsp-demo-realm.json ./keycloak-config/
   ```

## Security Notes

⚠️ **Important:** The included configuration is for development only!

Before deploying to production:
- Change client secret: `demo-secret-change-in-production`
- Enable SSL/TLS (`sslRequired: "external"` or `"all"`)
- Update redirect URIs to production URLs
- Review and restrict CORS settings
- Enable event logging
- Configure proper session timeouts
- Use external database (PostgreSQL)
- Set strong admin password

## Verification

After import, verify the configuration:

```bash
# Test Keycloak realm endpoint
curl http://localhost:8880/auth/realms/vdsp-demo/.well-known/openid-configuration

# Test demo app health (after starting the app)
curl http://localhost:3000/health
```

Expected health response:
```json
{
  "status": "healthy",
  "timestamp": "2025-11-14T...",
  "keycloak": {
    "realm": "vdsp-demo",
    "serverUrl": "http://localhost:8880/auth"
  }
}
```

## Troubleshooting

### Import Fails
- Ensure Keycloak is fully started before importing
- Check for syntax errors in JSON file
- Verify file permissions allow reading

### Client Secret Not Working
- Verify you're using the correct secret from `.env` file
- In Keycloak Admin, go to: Clients → vdsp-demo-app → Credentials
- Copy the actual secret and update your `.env` file

### Identity Provider Not Working
- Ensure VC-AuthN OIDC Bridge is running
- Check network connectivity between services
- Verify URLs in identity provider configuration
- For Docker: ensure services are on the same network
