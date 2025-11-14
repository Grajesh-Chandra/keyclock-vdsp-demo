const express = require("express");
const router = express.Router();
const qrcode = require("qrcode");
const rateLimit = require("express-rate-limit");
const {
  signIDToken,
  getPublicJWK,
  generateAuthCode,
  generateSubjectIdentifier,
  generateSessionId,
} = require("../utils/crypto");
const SessionStore = require("../utils/session-store");
const verifierClient = require("../utils/verifier-client");
const { json } = require("body-parser");

const sessionStore = new SessionStore();

// Rate limiter for authorize endpoint (expensive QR code generation)
const authorizeRateLimiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 minutes
  max: 10, // Limit each IP to 10 requests per windowMs
  message: {
    error: "too_many_requests",
    error_description: "Too many authorization requests, please try again later."
  },
  standardHeaders: true, // Return rate limit info in the `RateLimit-*` headers
  legacyHeaders: false, // Disable the `X-RateLimit-*` headers
});

/**
 * Root endpoint - Welcome page
 */
router.get("/", (req, res) => {
  const issuer =
    process.env.ISSUER_URL || `http://localhost:${process.env.PORT || 5001}`;
  res.json({
    service: "VC-AuthN OIDC Bridge",
    description:
      "OpenID Connect Provider for Verifiable Credential Authentication",
    version: "1.0.0",
    endpoints: {
      discovery: `${issuer}/.well-known/openid-configuration`,
      authorization: `${issuer}/authorize`,
      token: `${issuer}/token`,
      jwks: `${issuer}/.well-known/jwks`,
      health: `${issuer}/health`,
      documentation: `${issuer}/admin/docs`,
    },
    status: "ready",
  });
});

/**
 * OIDC Discovery Endpoint
 * Keycloak uses this to discover our capabilities
 */
router.get("/.well-known/openid-configuration", async (req, res) => {
  const issuer =
    process.env.ISSUER_URL || `http://localhost:${process.env.PORT || 5000}`;

  res.json({
    issuer,
    authorization_endpoint: `${issuer}/authorize`,
    token_endpoint: `${issuer}/token`,
    jwks_uri: `${issuer}/.well-known/jwks`,
    response_types_supported: ["code"],
    subject_types_supported: ["public"],
    id_token_signing_alg_values_supported: ["RS256"],
    token_endpoint_auth_methods_supported: [
      "client_secret_post",
      "client_secret_basic",
    ],
    claims_supported: [
      "sub",
      "email",
      "name",
      "given_name",
      "family_name",
      "employeeId",
      "company",
    ],
    scopes_supported: ["openid", "profile", "email"],
  });
});

/**
 * JWKS Endpoint
 * Keycloak uses this to verify our ID tokens
 */
router.get("/.well-known/jwks", async (req, res) => {
  const jwk = await getPublicJWK();
  res.json({ keys: [jwk] });
});

/**
 * Authorization Endpoint
 * This is where Keycloak redirects users when they choose "Login with VC"
 */
router.get("/authorize", authorizeRateLimiter, async (req, res) => {
  try {
    const { client_id, redirect_uri, state, response_type, scope, nonce } = req.query;

    // Validate required parameters
    if (!client_id || !redirect_uri) {
      return res
        .status(400)
        .json({
          error: "invalid_request",
          error_description: "Missing required parameters",
        });
    }

    if (response_type !== "code") {
      return res.status(400).json({ error: "unsupported_response_type" });
    }

    // Get verifier client ID from query or use default
    const verifierClientId =
      req.query.pres_req_conf_id ||
      process.env.VERIFIER_CLIENT_ID ||
      "federatedlogin";

    // Generate auth code and session
    const authCode = generateAuthCode();
    const sessionId = generateSessionId();
    const userId = generateSessionId(); // Temporary user ID

    // Get OOB URL from Dart verifier server

    const verifierData = await verifierClient.getOobUrl(verifierClientId);

    console.log("verifierData:", verifierData);
    let oobUrl = verifierData.oob_url;

    // Create session - store original Keycloak state and nonce
    const session = sessionStore.create({
      id: sessionId,
      authCode,
      userId,
      redirectUri: redirect_uri,
      clientId: client_id,
      verifierClientId,
      state,                    // Original Keycloak state
      keycloakState: state,     // Store original state separately
      nonce,                    // Store nonce for ID token
      oobUrl,
    });

    // Generate QR code from verifierData object
    const qrCodeDataUrl = await qrcode.toDataURL(JSON.stringify(verifierData));

    console.log("QR Code Data URL:", qrCodeDataUrl);
    // Subscribe to verification updates from Dart server
    const ws = verifierClient.subscribeToVerificationUpdates(
      verifierClientId,
      (message) => {
        handleVerificationUpdate(sessionId, message);
      },
      (error) => {
        console.error(`WebSocket error for session ${sessionId}:`, error);
      }
    );

    // Store WebSocket reference in session
    session.ws = ws;

    // Render QR code page
    res.render("scan-credential", {
      sessionId,
      qrCodeDataUrl,
      oobUrl,
      callbackUrl: `${
        process.env.CONTROLLER_URL || process.env.ISSUER_URL
      }/callback?session=${sessionId}`,
      clientName: "Employment Verification",
      title: "Scan with Your Digital Wallet",
      instructions:
        "Open your digital wallet app and scan this QR code to share your verifiable credentials.",
    });
  } catch (error) {
    console.error("Error in authorize endpoint:", error);
    res
      .status(500)
      .json({ error: "server_error", error_description: error.message });
  }
});

/**
 * Handle verification updates from Dart server
 */
function handleVerificationUpdate(sessionId, message) {
  console.log(`[handleVerificationUpdate] Session: ${sessionId}, Message:`, JSON.stringify(message, null, 2));

  const { completed, status, verifiablePresentation } = message;

  if (completed && status === "success" && verifiablePresentation) {
    console.log(`[handleVerificationUpdate] Verification successful for session ${sessionId}`);

    // Extract claims from VP
    const claims = extractClaimsFromVP(verifiablePresentation);
    console.log(`[handleVerificationUpdate] Extracted claims:`, claims);

    // Update session
    sessionStore.updateState(sessionId, "VERIFIED", claims);
    console.log(`[handleVerificationUpdate] Session state updated to VERIFIED`);

    // Notify frontend via WebSocket
    if (global.io) {
      global.io.to(sessionId).emit("verified", {
        success: true,
        message: "Credentials verified successfully!",
      });
      console.log(`[handleVerificationUpdate] Emitted 'verified' event to room ${sessionId}`);
    } else {
      console.error(`[handleVerificationUpdate] global.io is not available!`);
    }
  } else if (completed && status === "failure") {
    console.log(`[handleVerificationUpdate] Verification failed for session ${sessionId}`);
    sessionStore.updateState(sessionId, "FAILED");

    if (global.io) {
      global.io.to(sessionId).emit("verified", {
        success: false,
        message: "Credential verification failed",
      });
      console.log(`[handleVerificationUpdate] Emitted 'verified' failure event to room ${sessionId}`);
    }
  } else {
    console.log(`[handleVerificationUpdate] Ignoring message - completed: ${completed}, status: ${status}`);
  }
}

/**
 * Extract claims from Verifiable Presentation
 */
function extractClaimsFromVP(vp) {
  try {
    // Navigate the VP structure to extract credential subject claims
    if (vp.verifiableCredential && vp.verifiableCredential.length > 0) {
      const vc = vp.verifiableCredential[0];
      const subject = vc.credentialSubject || {};

      // Extract name from display_name if available
      const displayName = subject.display_name || subject.name || subject.fullName;
      const nameParts = displayName ? displayName.split(' ') : [];
      const firstName = nameParts[0] || '';
      const lastName = nameParts.slice(1).join(' ') || '';

      // Extract company from issuer or credential
      let company = subject.company || subject.companyName || subject.organization;
      if (!company && vc.issuer && vc.issuer.id) {
        // Extract from issuer DID: did:web:issuers.sa.affinidi.io:bubba-bank -> bubba-bank
        const issuerParts = vc.issuer.id.split(':');
        company = issuerParts[issuerParts.length - 1];
      }

      return {
        email: subject.email || subject.id,
        name: displayName,
        given_name: subject.givenName || subject.given_name || firstName,
        family_name: subject.familyName || subject.family_name || lastName,
        employeeId: subject.employeeId,
        company: company,
      };
    }
  } catch (error) {
    console.error("Error extracting claims from VP:", error);
  }

  return { email: "verified_user@example.com" };
}

/**
 * Callback Endpoint
 * Frontend redirects here after verification completes
 */
router.get("/callback", (req, res) => {
  const sessionId = req.query.session;
  const session = sessionStore.findById(sessionId);

  if (!session) {
    return res.status(404).send("Session not found");
  }

  if (session.verificationState !== "VERIFIED") {
    return res.status(400).send("Verification not complete");
  }

  // Close WebSocket
  if (session.ws) {
    session.ws.close();
    session.ws = null;
  }

  // Redirect back to Keycloak with auth code and ORIGINAL state parameter
  const originalState = session.keycloakState || session.state;
  const redirectUrl = `${session.redirectUri}?code=${session.authCode}&state=${originalState}`;
  console.log(`[callback] Redirecting to Keycloak with original state: ${originalState}`);
  res.redirect(redirectUrl);
});

/**
 * Token Endpoint
 * Keycloak exchanges the auth code for an ID token here
 */
router.post("/token", async (req, res) => {
  try {
    const { code, client_id, client_secret, grant_type, redirect_uri } =
      req.body;

    console.log(`[token] Received request:`, {
      code: code?.substring(0, 20) + '...',
      client_id,
      client_secret: client_secret ? '***' + client_secret.substring(client_secret.length - 4) : 'none',
      grant_type,
      redirect_uri
    });

    // Validate grant type
    if (grant_type !== "authorization_code") {
      return res.status(400).json({ error: "unsupported_grant_type" });
    }

    // Validate client credentials - allow any client for now
    const expectedClientId = process.env.KEYCLOAK_CLIENT_ID || client_id;
    const expectedClientSecret = process.env.KEYCLOAK_CLIENT_SECRET;

    console.log(`[token] Expected credentials:`, {
      expectedClientId,
      expectedClientSecret: expectedClientSecret ? '***' + expectedClientSecret.substring(expectedClientSecret.length - 4) : 'none (allowing any)'
    });

    // Skip client secret validation if not configured
    if (expectedClientSecret && client_id !== expectedClientId) {
      console.log(`[token] Client ID mismatch: ${client_id} !== ${expectedClientId}`);
      return res.status(401).json({ error: "invalid_client" });
    }

    if (expectedClientSecret && client_secret !== expectedClientSecret) {
      console.log(`[token] Client secret mismatch`);
      return res.status(401).json({ error: "invalid_client" });
    }

    // Find session by auth code
    const session = sessionStore.findByAuthCode(code);

    if (!session) {
      console.log(`[token] Session not found for code: ${code?.substring(0, 20)}...`);
      return res
        .status(400)
        .json({
          error: "invalid_grant",
          error_description: "Authorization code not found",
        });
    }

    console.log(`[token] Found session:`, {
      id: session.id,
      verificationState: session.verificationState,
      hasClaims: !!session.claims
    });

    if (session.verificationState !== "VERIFIED") {
      console.log(`[token] Session not verified: ${session.verificationState}`);
      return res
        .status(400)
        .json({
          error: "invalid_grant",
          error_description: "Authorization not verified",
        });
    }

    // Generate subject identifier
    const sub = generateSubjectIdentifier(session.claims);

    // Create ID token claims
    const claims = {
      sub,
      ...session.claims,
      auth_time: Math.floor(session.createdAt.getTime() / 1000),
    };

    // Add nonce if it was provided in the authorization request
    if (session.nonce) {
      claims.nonce = session.nonce;
    }

    // Sign ID token
    const idToken = await signIDToken(claims, client_id);

    // Return tokens
    res.json({
      access_token: code, // Simple access token (same as code for now)
      token_type: "Bearer",
      expires_in: 3600,
      id_token: idToken,
    });

    // Clean up session
    sessionStore.delete(session.id);
  } catch (error) {
    console.error("Error in token endpoint:", error);
    res
      .status(500)
      .json({ error: "server_error", error_description: error.message });
  }
});

module.exports = router;
