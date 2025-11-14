require('dotenv').config();
const express = require('express');
const session = require('express-session');
const bodyParser = require('body-parser');
const cors = require('cors');
const morgan = require('morgan');
const http = require('http');
const { Server } = require('socket.io');
const path = require('path');

// Import routes
const oidcRoutes = require('./routes/oidc');
const adminRoutes = require('./routes/admin');

// Import utilities
const { initializeKeys } = require('./utils/crypto');

const app = express();
const server = http.createServer(app);
const io = new Server(server, {
  cors: {
    origin: '*',
    methods: ['GET', 'POST']
  }
});

// Make io available globally
global.io = io;

// Middleware
app.use(morgan('dev'));
app.use(cors());
app.use(bodyParser.json());
app.use(bodyParser.urlencoded({ extended: true }));
app.use(express.static(path.join(__dirname, '../public')));

// Session configuration
app.use(session({
  secret: process.env.SESSION_SECRET || 'vc-authn-oidc-bridge-secret',
  resave: false,
  saveUninitialized: false,
  cookie: {
    secure: process.env.NODE_ENV === 'production',
    httpOnly: true,
    maxAge: 3600000 // 1 hour
  }
}));

// View engine setup
app.set('view engine', 'ejs');
app.set('views', path.join(__dirname, '../views'));

// Health check
app.get('/health', (req, res) => {
  res.json({
    status: 'healthy',
    service: 'vc-authn-oidc-bridge',
    timestamp: new Date().toISOString(),
    verifierServerUrl: process.env.VERIFIER_SERVER_URL
  });
});

// Mount routes
app.use('/', oidcRoutes);
app.use('/admin', adminRoutes);

// WebSocket connection handling
io.on('connection', (socket) => {
  console.log('Client connected:', socket.id);

  socket.on('join', (sessionId) => {
    socket.join(sessionId);
    console.log(`Socket ${socket.id} joined session ${sessionId}`);
  });

  socket.on('disconnect', () => {
    console.log('Client disconnected:', socket.id);
  });
});

// Error handling
app.use((err, req, res, next) => {
  console.error('Error:', err);
  res.status(err.status || 500).json({
    error: err.message || 'Internal Server Error'
  });
});

// 404 handler
app.use((req, res) => {
  res.status(404).json({ error: 'Not Found' });
});

// Start server
const PORT = process.env.PORT || 5000;

async function start() {
  try {
    // Initialize cryptographic keys
    await initializeKeys();
    console.log('Cryptographic keys initialized');

    // Start server
    server.listen(PORT, () => {
      console.log('');
      console.log('╔═══════════════════════════════════════════════════════════╗');
      console.log('║   VC-AuthN OIDC Bridge for Keycloak                      ║');
      console.log('╚═══════════════════════════════════════════════════════════╝');
      console.log('');
      console.log(`🚀 Server running on port ${PORT}`);
      console.log(`📍 OIDC Issuer: ${process.env.ISSUER_URL || `http://localhost:${PORT}`}`);
      console.log(`🔗 Verifier Server: ${process.env.VERIFIER_SERVER_URL || 'http://localhost:8080'}`);
      console.log('');
      console.log('📖 Documentation: /admin/docs');
      console.log('🔧 Health Check: /health');
      console.log('');
    });
  } catch (error) {
    console.error('Failed to start server:', error);
    process.exit(1);
  }
}

start();

// Graceful shutdown
process.on('SIGTERM', () => {
  console.log('SIGTERM received, shutting down gracefully');
  server.close(() => {
    console.log('Server closed');
    process.exit(0);
  });
});

module.exports = { app, io };
