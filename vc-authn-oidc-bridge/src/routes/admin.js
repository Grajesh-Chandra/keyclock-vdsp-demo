const express = require('express');
const router = express.Router();
const SessionStore = require('../utils/session-store');
const verifierClient = require('../utils/verifier-client');

const sessionStore = new SessionStore();

/**
 * Admin dashboard
 */
router.get('/', (req, res) => {
  const sessions = sessionStore.getAll();
  res.json({
    service: 'VC-AuthN OIDC Bridge',
    status: 'running',
    sessions: {
      active: sessions.length,
      details: sessions.map(s => ({
        id: s.id,
        state: s.state,
        createdAt: s.createdAt,
        clientId: s.clientId
      }))
    },
    config: {
      issuerUrl: process.env.ISSUER_URL,
      verifierServerUrl: process.env.VERIFIER_SERVER_URL,
      keycloakClientId: process.env.KEYCLOAK_CLIENT_ID
    }
  });
});

/**
 * Get available verifier clients
 */
router.get('/clients', async (req, res) => {
  try {
    const clients = await verifierClient.getClients();
    res.json(clients);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

/**
 * Documentation page
 */
router.get('/docs', (req, res) => {
  res.send(`
    <!DOCTYPE html>
    <html>
    <head>
        <title>VC-AuthN OIDC Bridge - Setup Guide</title>
        <style>
            body { font-family: Arial, sans-serif; max-width: 900px; margin: 40px auto; padding: 20px; line-height: 1.6; }
            h1 { color: #667eea; }
            h2 { color: #333; margin-top: 30px; }
            code { background: #f4f4f4; padding: 2px 6px; border-radius: 3px; }
            pre { background: #f4f4f4; padding: 15px; border-radius: 5px; overflow-x: auto; }
            .step { background: #e3f2fd; padding: 15px; margin: 15px 0; border-left: 4px solid #2196f3; }
        </style>
    </head>
    <body>
        <h1>🚀 VC-AuthN OIDC Bridge - Quick Setup Guide</h1>
        <p>Enable W3C Verifiable Credentials authentication for your Keycloak in minutes!</p>

        <h2>📋 Prerequisites</h2>
        <ul>
            <li>Keycloak running (any version)</li>
            <li>Dart Verifier Server running (on ${process.env.VERIFIER_SERVER_URL || 'http://localhost:8080'})</li>
            <li>This OIDC Bridge running (on ${process.env.ISSUER_URL || 'http://localhost:5000'})</li>
        </ul>

        <h2>🔧 Step 1: Configure Keycloak Identity Provider</h2>
        <div class="step">
            <p><strong>1.1</strong> Log into Keycloak Admin Console</p>
            <p><strong>1.2</strong> Navigate to: <code>Identity Providers</code> → <code>OpenID Connect v1.0</code></p>
            <p><strong>1.3</strong> Configure:</p>
            <pre>
Alias: vc-authn
Display Name: Login with Verifiable Credentials

Discovery URL: ${process.env.ISSUER_URL || 'http://localhost:5000'}/.well-known/openid-configuration

Client ID: vc-authn
Client Secret: your-secret-here
Client Authentication: Client secret sent as post

Default Scopes: openid profile email

Forwarded Query Parameters: pres_req_conf_id</pre>
        </div>

        <h2>🔑 Step 2: Configure This Bridge</h2>
        <div class="step">
            <p>Update your <code>.env</code> file:</p>
            <pre>
# Copy Client ID and Secret from Keycloak
KEYCLOAK_CLIENT_ID=vc-authn
KEYCLOAK_CLIENT_SECRET=<from-keycloak>

# Update redirect URI from Keycloak IdP settings
KEYCLOAK_REDIRECT_URI=http://localhost:8880/realms/vdsp-demo/broker/vc-authn/endpoint

# Ensure verifier server is accessible
VERIFIER_SERVER_URL=http://localhost:8080
VERIFIER_AUTH_TOKEN=my_secure_token</pre>
        </div>

        <h2>✅ Step 3: Test the Integration</h2>
        <div class="step">
            <p><strong>3.1</strong> Go to your application login page</p>
            <p><strong>3.2</strong> Click "Login with Verifiable Credentials"</p>
            <p><strong>3.3</strong> Scan QR code with your wallet app</p>
            <p><strong>3.4</strong> Share your credentials</p>
            <p><strong>3.5</strong> You're logged in! 🎉</p>
        </div>

        <h2>📡 Endpoints</h2>
        <ul>
            <li><strong>Discovery:</strong> <a href="/.well-known/openid-configuration">/.well-known/openid-configuration</a></li>
            <li><strong>JWKS:</strong> <a href="/.well-known/jwks">/.well-known/jwks</a></li>
            <li><strong>Authorize:</strong> /authorize</li>
            <li><strong>Token:</strong> /token</li>
            <li><strong>Health:</strong> <a href="/health">/health</a></li>
            <li><strong>Admin:</strong> <a href="/admin">/admin</a></li>
        </ul>

        <h2>🔍 Troubleshooting</h2>
        <ul>
            <li>Check verifier server is running: <code>curl ${process.env.VERIFIER_SERVER_URL || 'http://localhost:8080'}/health</code></li>
            <li>Verify Keycloak can reach this bridge: <code>curl ${process.env.ISSUER_URL || 'http://localhost:5000'}/health</code></li>
            <li>Check logs: <code>docker logs vc-authn-oidc-bridge</code></li>
            <li>View active sessions: <a href="/admin">/admin</a></li>
        </ul>

        <p style="margin-top: 40px; color: #666; font-size: 14px;">
            💡 <strong>Pro Tip:</strong> For production, use HTTPS and configure proper secrets!
        </p>
    </body>
    </html>
  `);
});

module.exports = router;
