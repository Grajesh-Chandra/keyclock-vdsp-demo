# VDSP Federated VC Login - Management Scripts

This directory contains comprehensive management scripts for the VDSP Federated VC Login demo environment.

## 📋 Available Scripts

### 🚀 `start.sh` - Start Services

Starts all services required for the demo environment.

**Usage:**
```bash
./scripts/start.sh [OPTIONS]
```

**Options:**
- `--dart-path PATH` - Path to Dart verifier project
- `--skip-docker` - Skip starting Docker services
- `--skip-oidc` - Skip starting OIDC Bridge
- `--skip-demo` - Skip starting Demo App
- `--only-docker` - Only start Docker services
- `--help` - Show help message

**Examples:**
```bash
# Start all services (except Dart verifier)
./scripts/start.sh

# Start all services including Dart verifier
./scripts/start.sh --dart-path ~/vdsp-verifier-server

# Only start Docker services
./scripts/start.sh --only-docker

# Start without Docker (if already running)
./scripts/start.sh --skip-docker
```

**What it does:**
1. Starts PostgreSQL and Keycloak (Docker)
2. Starts OIDC Bridge on port 5001
3. Starts Demo App on port 3000
4. Starts Dart Verifier on port 8081 (if path provided)
5. Waits for all services to be ready
6. Displays service URLs and status

---

### 🛑 `stop.sh` - Stop Services

Stops all running services gracefully.

**Usage:**
```bash
./scripts/stop.sh [OPTIONS]
```

**Options:**
- `--docker` - Also stop Docker services (PostgreSQL, Keycloak)
- `--force` - Kill any orphaned processes on ports 5001, 3000
- `--help` - Show help message

**Examples:**
```bash
# Stop Node.js services only (keep Docker running)
./scripts/stop.sh

# Stop all services including Docker
./scripts/stop.sh --docker

# Force kill orphaned processes
./scripts/stop.sh --force
```

**What it does:**
1. Stops OIDC Bridge and Demo App (graceful shutdown with fallback to force kill)
2. Stops Dart Verifier (if running)
3. Stops Docker services (if `--docker` flag used)
4. Removes PID files
5. Optionally kills orphaned processes on relevant ports

---

### 🧹 `cleanup.sh` - Cleanup Environment

Performs various cleanup operations on the environment.

**Usage:**
```bash
./scripts/cleanup.sh [OPTIONS]
```

**Options:**
- `--docker` - Remove Docker containers and volumes
- `--logs` - Remove log files and PID files (default)
- `--node-modules` - Remove node_modules directories
- `--keys` - Remove RSA private/public keys
- `--all` - Perform full cleanup (all of the above)
- `--force` - Skip confirmation prompts
- `--help` - Show help message

**Examples:**
```bash
# Clean logs only (default)
./scripts/cleanup.sh

# Clean Docker containers and volumes
./scripts/cleanup.sh --docker

# Full cleanup (removes everything)
./scripts/cleanup.sh --all

# Full cleanup without prompts
./scripts/cleanup.sh --all --force

# Clean multiple specific items
./scripts/cleanup.sh --docker --node-modules
```

**What it does:**
- Stops all services
- Removes logs and PID files
- Removes Docker containers and volumes (optional)
- Removes node_modules directories (optional)
- Removes RSA keys (optional)
- Confirms each action unless `--force` is used

**⚠️ Warning:** Using `--all` will remove all data, containers, and require full reinstall.

---

### 🔄 `recreate.sh` - Recreate Environment

Performs a complete recreation of the development environment.

**Usage:**
```bash
./scripts/recreate.sh [OPTIONS]
```

**Options:**
- `--with-docker` - Also recreate Docker containers and volumes
- `--with-keys` - Also regenerate RSA keys
- `--dart-path PATH` - Path to Dart verifier project
- `--help` - Show help message

**Examples:**
```bash
# Recreate services (keep Docker and keys)
./scripts/recreate.sh

# Full recreation including Docker
./scripts/recreate.sh --with-docker

# Complete reset (Docker + keys)
./scripts/recreate.sh --with-docker --with-keys

# Recreate with Dart verifier
./scripts/recreate.sh --dart-path ~/vdsp-verifier-server
```

**What it does:**
1. Stops all services
2. Cleans up logs and node_modules
3. Optionally removes Docker containers/volumes
4. Optionally regenerates RSA keys
5. Reinstalls npm dependencies
6. Starts PostgreSQL and Keycloak
7. Verifies realm configuration
8. Starts all services
9. Displays service URLs

**Use cases:**
- Fresh start after configuration changes
- Recover from corrupted state
- Test clean installation
- Reset to known good state

---

### ✅ `test.sh` - Test System

Runs comprehensive tests on all components.

**Usage:**
```bash
./scripts/test.sh
```

**What it tests:**
1. **PostgreSQL** - Container running, database accepting connections
2. **Keycloak** - Container running, health endpoint, realm accessibility
3. **Keycloak Configuration** - Admin auth, Identity Provider setup, URLs
4. **OIDC Bridge** - Process running, health endpoint, discovery endpoint, JWKS
5. **Demo App** - Process running, home page responding
6. **Dart Verifier** - Process running (optional), API endpoint, client configuration
7. **RSA Keys** - Files exist, valid JSON, required parameters present
8. **Environment** - .env file exists, required variables present
9. **Network** - All ports open and accessible
10. **Integration** - OIDC discovery working, authorize endpoint accessible

**Output:**
- Displays detailed test results with pass/fail status
- Shows summary of tests run, passed, and failed
- Provides troubleshooting tips if tests fail
- Exits with code 0 (success) or 1 (failure)

**Example:**
```bash
./scripts/test.sh

# Expected output:
[TEST 1] PostgreSQL Running
  → Container running
  → Database accepting connections
  ✓ PASS

[TEST 2] Keycloak Service
  → Container running
  → Health endpoint responding
  → Realm 'vdsp-demo' accessible
  ✓ PASS

...

Test Summary:
Tests Run:    10
Tests Passed: 10

✓ All tests passed!
```

---

## 🔄 Common Workflows

### First Time Setup
```bash
# 1. Start all services
./scripts/start.sh --dart-path ~/vdsp-verifier-server

# 2. Test everything is working
./scripts/test.sh

# 3. Access demo app
open http://localhost:3000
```

### Daily Development
```bash
# Start services
./scripts/start.sh

# ... do your work ...

# Stop services (keep Docker running)
./scripts/stop.sh
```

### Full Reset
```bash
# Complete environment recreation
./scripts/recreate.sh --with-docker --with-keys

# Test after recreation
./scripts/test.sh
```

### Troubleshooting
```bash
# Stop everything including orphaned processes
./scripts/stop.sh --docker --force

# Clean everything
./scripts/cleanup.sh --all --force

# Recreate from scratch
./scripts/recreate.sh --with-docker

# Test to verify
./scripts/test.sh
```

---

## 📁 File Locations

### PID Files
- OIDC Bridge: `vc-authn-oidc-bridge/oidc-bridge.pid`
- Demo App: `demo-app/demo-app.pid`
- Dart Verifier: `dart-verifier.pid` (project root)

### Log Files
- Directory: `logs/` (project root)
- OIDC Bridge: `logs/oidc-bridge.log`
- Demo App: `logs/demo-app.log`
- Dart Verifier: `logs/dart-verifier.log`

### Configuration
- OIDC Bridge env: `vc-authn-oidc-bridge/.env`
- RSA Keys: `vc-authn-oidc-bridge/keys/`
- Keycloak realm: `keycloak-config/vdsp-demo-realm.json`

---

## 🔍 Service URLs

After starting services with `./scripts/start.sh`:

| Service | URL | Credentials |
|---------|-----|-------------|
| Demo App | http://localhost:3000 | - |
| Keycloak | http://localhost:8880 | admin / admin |
| OIDC Bridge | http://localhost:5001 | - |
| OIDC Discovery | http://localhost:5001/.well-known/openid-configuration | - |
| JWKS Endpoint | http://localhost:5001/.well-known/jwks | - |
| Dart Verifier | http://localhost:8081 | - |
| PostgreSQL | localhost:5432 | keycloak / keycloak |

---

## 🐛 Troubleshooting

### Services won't start
```bash
# Check for port conflicts
lsof -i tcp:3000,5001,8880,5432,8081

# Force kill orphaned processes
./scripts/stop.sh --force

# Try starting again
./scripts/start.sh
```

### Docker services not responding
```bash
# Check Docker status
docker ps

# Restart Docker services
./scripts/stop.sh --docker
./scripts/start.sh --only-docker
```

### Tests failing
```bash
# Check logs
tail -f logs/oidc-bridge.log
tail -f logs/demo-app.log

# Verify environment variables
cat vc-authn-oidc-bridge/.env

# Try full recreation
./scripts/recreate.sh --with-docker
```

### Keycloak realm not found
```bash
# Verify realm import
docker logs vdsp-keycloak | grep import

# Manually import realm
# 1. Access http://localhost:8880
# 2. Login as admin/admin
# 3. Import keycloak-config/vdsp-demo-realm.json
```

---

## 💡 Tips

1. **Keep Docker Running**: Use `./scripts/stop.sh` (without `--docker`) to stop only Node.js services while keeping Docker running. This is faster for development cycles.

2. **View Logs in Real-Time**:
   ```bash
   tail -f logs/oidc-bridge.log logs/demo-app.log
   ```

3. **Check Service Status**:
   ```bash
   # Check processes
   ps aux | grep node | grep -v grep

   # Check Docker
   docker ps

   # Check ports
   lsof -i tcp:3000,5001,8880
   ```

4. **Quick Restart**:
   ```bash
   ./scripts/stop.sh && ./scripts/start.sh
   ```

5. **Environment Variables**: Set `DART_VERIFIER_PATH` in your shell profile:
   ```bash
   export DART_VERIFIER_PATH=~/vdsp-verifier-server
   ./scripts/start.sh  # Will automatically include Dart verifier
   ```

---

## 🔐 Security Notes

- These scripts are for **development only**
- Default credentials are used (admin/admin)
- RSA keys should be regenerated for production
- .env files contain sensitive configuration
- Logs may contain sensitive information

---

## 📝 Script Maintenance

All scripts include:
- ✅ Colorized output for better readability
- ✅ Error handling with proper exit codes
- ✅ Progress indicators and status messages
- ✅ Help documentation (`--help`)
- ✅ Confirmation prompts for destructive operations
- ✅ Force flags to skip prompts (`--force`)

---

## 🆘 Getting Help

Run any script with `--help`:
```bash
./scripts/start.sh --help
./scripts/stop.sh --help
./scripts/cleanup.sh --help
./scripts/recreate.sh --help
./scripts/test.sh --help
```

For more information, see:
- Main README: `../README.md`
- Quick Start Guide: `../docs/QUICKSTART.md`
- Architecture Doc: `../docs/FEDERATED_VC_LOGIN_ARCHITECTURE.md`
