// In-memory session store (use Redis for production with multiple instances)
const sessions = new Map();

class SessionStore {
  create(sessionData) {
    const session = {
      id: sessionData.id,
      authCode: sessionData.authCode,
      userId: sessionData.userId,
      redirectUri: sessionData.redirectUri,
      clientId: sessionData.clientId,
      verifierClientId: sessionData.verifierClientId,
      state: sessionData.state,              // Original Keycloak state
      keycloakState: sessionData.keycloakState || sessionData.state,  // Preserve original state
      nonce: sessionData.nonce,              // Preserve nonce for ID token
      verificationState: 'PENDING',          // Internal verification status
      claims: null,
      oobUrl: sessionData.oobUrl,
      createdAt: new Date(),
      updatedAt: new Date()
    };

    sessions.set(session.id, session);
    return session;
  }

  findById(id) {
    return sessions.get(id);
  }

  findByAuthCode(authCode) {
    for (const [, session] of sessions) {
      if (session.authCode === authCode) {
        return session;
      }
    }
    return null;
  }

  update(id, updates) {
    const session = sessions.get(id);
    if (!session) return false;

    Object.assign(session, updates, { updatedAt: new Date() });
    sessions.set(id, session);
    return true;
  }

  updateState(id, verificationState, claims = null) {
    return this.update(id, {
      verificationState,
      ...(claims && { claims })
    });
  }

  delete(id) {
    return sessions.delete(id);
  }

  cleanup(maxAge = 3600000) { // Default: 1 hour
    const cutoff = Date.now() - maxAge;
    let cleaned = 0;

    for (const [id, session] of sessions) {
      if (session.createdAt.getTime() < cutoff) {
        sessions.delete(id);
        cleaned++;
      }
    }

    return cleaned;
  }

  getAll() {
    return Array.from(sessions.values());
  }
}

// Cleanup expired sessions every 10 minutes
setInterval(() => {
  const store = new SessionStore();
  const cleaned = store.cleanup();
  if (cleaned > 0) {
    console.log(`Cleaned up ${cleaned} expired sessions`);
  }
}, 600000);

module.exports = SessionStore;
