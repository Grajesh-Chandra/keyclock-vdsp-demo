const crypto = require('crypto');
const { SignJWT, generateKeyPair, exportJWK, importJWK } = require('jose');
const fs = require('fs').promises;
const path = require('path');

let signingKey = null;
let publicJWK = null;
let verificationKey = null;

async function initializeKeys() {
  const keyPath = path.join(__dirname, '../../keys');
  const privateKeyFile = path.join(keyPath, 'private.jwk');
  const publicKeyFile = path.join(keyPath, 'public.jwk');

  try {
    // Create keys directory
    await fs.mkdir(keyPath, { recursive: true });

    // Try to load existing keys
    try {
      const privateJWKData = await fs.readFile(privateKeyFile, 'utf-8');
      const publicJWKData = await fs.readFile(publicKeyFile, 'utf-8');

      const privateJWKJson = JSON.parse(privateJWKData);
      const publicJWKJson = JSON.parse(publicJWKData);

      signingKey = await importJWK(privateJWKJson, 'RS256');
      verificationKey = await importJWK(publicJWKJson, 'RS256');
      publicJWK = publicJWKJson;

      console.log('✓ Loaded existing RSA keys');
      return;
    } catch {
      // Keys don't exist, generate new ones
      console.log('Generating new RSA key pair...');

      const { privateKey, publicKey } = await generateKeyPair('RS256');
      signingKey = privateKey;
      verificationKey = publicKey;

      // Export and save keys
      const privateJWKExport = await exportJWK(privateKey);
      const publicJWKExport = await exportJWK(publicKey);

      publicJWK = {
        ...publicJWKExport,
        use: 'sig',
        kid: '1',
        alg: 'RS256'
      };

      await fs.writeFile(privateKeyFile, JSON.stringify(privateJWKExport, null, 2));
      await fs.writeFile(publicKeyFile, JSON.stringify(publicJWK, null, 2));

      console.log('✓ Generated and saved new RSA keys');
    }
  } catch (error) {
    console.error('Error initializing keys:', error);
    throw error;
  }
}

async function signIDToken(claims, clientId) {
  if (!signingKey) {
    await initializeKeys();
  }

  const issuer = process.env.ISSUER_URL || 'http://localhost:5000';
  const now = Math.floor(Date.now() / 1000);

  const token = await new SignJWT(claims)
    .setProtectedHeader({ alg: 'RS256', typ: 'JWT', kid: '1' })
    .setIssuedAt(now)
    .setIssuer(issuer)
    .setAudience(clientId)
    .setExpirationTime(now + 3600) // 1 hour
    .sign(signingKey);

  return token;
}

async function getPublicJWK() {
  if (!publicJWK) {
    await initializeKeys();
  }
  return publicJWK;
}

function generateAuthCode() {
  return crypto.randomBytes(32).toString('hex');
}

function generateSubjectIdentifier(claims) {
  const hashSalt = process.env.SUBJECT_ID_HASH_SALT || 'default-salt';
  const subjectSource = claims.email || claims.sub || JSON.stringify(claims);
  return crypto
    .createHash('sha256')
    .update(subjectSource + hashSalt)
    .digest('hex');
}

function generateSessionId() {
  return crypto.randomBytes(16).toString('hex');
}

module.exports = {
  initializeKeys,
  signIDToken,
  getPublicJWK,
  generateAuthCode,
  generateSubjectIdentifier,
  generateSessionId
};
