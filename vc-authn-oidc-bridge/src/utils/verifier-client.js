const axios = require('axios');
const WebSocket = require('ws');

const VERIFIER_SERVER_URL = process.env.VERIFIER_SERVER_URL || 'http://localhost:8080';
const VERIFIER_AUTH_TOKEN = process.env.VERIFIER_AUTH_TOKEN || 'my_secure_token';

class VerifierClient {
  /**
   * Get OOB URL from the Dart verifier server for a specific client
   */
  async getOobUrl(clientId) {
    try {
      const response = await axios.get(`${VERIFIER_SERVER_URL}/api/oob/clients`, {
        headers: {
          'Authorization': `Bearer ${VERIFIER_AUTH_TOKEN}`
        }
      });

      const clients = response.data;
      const client = clients.find(c => c.id === clientId);

      if (!client || !client.oob_url) {
        throw new Error(`Client ${clientId} not found or OOB URL not available`);
      }

      return client;
    } catch (error) {
      console.error('Error fetching OOB URL:', error.message);
      throw new Error(`Failed to get OOB URL from verifier server: ${error.message}`);
    }
  }

  /**
   * Subscribe to WebSocket updates from the Dart verifier server
   */
  subscribeToVerificationUpdates(clientId, onMessage, onError) {
    const wsUrl = VERIFIER_SERVER_URL.replace('http://', 'ws://').replace('https://', 'wss://');
    const ws = new WebSocket(`${wsUrl}/ws/${clientId}`);

    ws.on('open', () => {
      console.log(`WebSocket connected to verifier server for client ${clientId}`);
    });

    ws.on('message', (data) => {
      try {
        const message = JSON.parse(data.toString());
        console.log(`Received from verifier server:`, message);
        onMessage(message);
      } catch (error) {
        console.error('Error parsing WebSocket message:', error);
      }
    });

    ws.on('error', (error) => {
      console.error('WebSocket error:', error);
      if (onError) onError(error);
    });

    ws.on('close', () => {
      console.log(`WebSocket closed for client ${clientId}`);
    });

    return ws;
  }

  /**
   * Get list of available verification clients from Dart server
   */
  async getClients() {
    try {
      const response = await axios.get(`${VERIFIER_SERVER_URL}/api/oob/clients`, {
        headers: {
          'Authorization': `Bearer ${VERIFIER_AUTH_TOKEN}`
        }
      });

      return response.data;
    } catch (error) {
      console.error('Error fetching clients:', error.message);
      throw new Error(`Failed to get clients from verifier server: ${error.message}`);
    }
  }
}

module.exports = new VerifierClient();
