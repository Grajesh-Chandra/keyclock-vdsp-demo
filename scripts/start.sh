#!/bin/bash

##############################################################################
# Start Script - VDSP Federated VC Login Demo
#
# This script starts all services required for the demo:
# 1. Docker services (PostgreSQL, Keycloak)
# 2. OIDC Bridge (Node.js)
# 3. Demo App (Node.js)
# 4. Dart Verifier (optional - if path provided)
##############################################################################

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Script directory
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

# PID files
OIDC_BRIDGE_PID="$PROJECT_DIR/vc-authn-oidc-bridge/oidc-bridge.pid"
DEMO_APP_PID="$PROJECT_DIR/demo-app/demo-app.pid"
DART_VERIFIER_PID="$PROJECT_DIR/dart-verifier.pid"

# Log files
LOG_DIR="$PROJECT_DIR/logs"
mkdir -p "$LOG_DIR"
OIDC_BRIDGE_LOG="$LOG_DIR/oidc-bridge.log"
DEMO_APP_LOG="$LOG_DIR/demo-app.log"
DART_VERIFIER_LOG="$LOG_DIR/dart-verifier.log"

# Configuration
DART_VERIFIER_PATH="${DART_VERIFIER_PATH:-}"
START_DOCKER="${START_DOCKER:-true}"
START_OIDC="${START_OIDC:-true}"
START_DEMO="${START_DEMO:-true}"
START_DART="${START_DART:-false}"

echo -e "${BLUE}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║   VDSP Federated VC Login - Service Startup               ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════════╝${NC}"
echo ""

##############################################################################
# Check if service is already running
##############################################################################
check_running() {
    local pid_file=$1
    local service_name=$2

    if [ -f "$pid_file" ]; then
        local pid=$(cat "$pid_file")
        if ps -p "$pid" > /dev/null 2>&1; then
            echo -e "${YELLOW}⚠ $service_name is already running (PID: $pid)${NC}"
            return 0
        else
            echo -e "${YELLOW}⚠ Stale PID file found for $service_name, removing...${NC}"
            rm -f "$pid_file"
        fi
    fi
    return 1
}

##############################################################################
# Wait for service to be ready
##############################################################################
wait_for_service() {
    local url=$1
    local service_name=$2
    local max_attempts=${3:-30}
    local attempt=0

    echo -e "${BLUE}⏳ Waiting for $service_name to be ready...${NC}"

    while [ $attempt -lt $max_attempts ]; do
        if curl -s -f "$url" > /dev/null 2>&1; then
            echo -e "${GREEN}✓ $service_name is ready!${NC}"
            return 0
        fi
        attempt=$((attempt + 1))
        echo -n "."
        sleep 2
    done

    echo ""
    echo -e "${RED}✗ $service_name failed to start within $((max_attempts * 2)) seconds${NC}"
    return 1
}

##############################################################################
# Start Docker Services
##############################################################################
start_docker_services() {
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}1. Starting Docker Services (PostgreSQL, Keycloak)${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

    cd "$PROJECT_DIR"

    # Check if services are already running
    if docker ps | grep -q "vdsp-postgres\|vdsp-keycloak"; then
        echo -e "${YELLOW}⚠ Docker services already running${NC}"
        docker ps | grep "vdsp-postgres\|vdsp-keycloak"
    else
        echo -e "${GREEN}→ Starting PostgreSQL and Keycloak...${NC}"
        docker compose up -d postgres keycloak
    fi

    # Wait for PostgreSQL
    wait_for_service "http://localhost:5432" "PostgreSQL" 15 || true

    # Wait for Keycloak
    wait_for_service "http://localhost:8880/health/ready" "Keycloak" 60

    echo -e "${GREEN}✓ Docker services started${NC}"
    echo ""
}

##############################################################################
# Start OIDC Bridge
##############################################################################
start_oidc_bridge() {
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}2. Starting VC-AuthN OIDC Bridge${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

    if check_running "$OIDC_BRIDGE_PID" "OIDC Bridge"; then
        return 0
    fi

    cd "$PROJECT_DIR/vc-authn-oidc-bridge"

    # Check if node_modules exists
    if [ ! -d "node_modules" ]; then
        echo -e "${YELLOW}⚠ node_modules not found, running npm install...${NC}"
        npm install
    fi

    echo -e "${GREEN}→ Starting OIDC Bridge on port 5001...${NC}"

    # Start in background and capture PID
    PORT=5001 npm start > "$OIDC_BRIDGE_LOG" 2>&1 &
    local pid=$!
    echo $pid > "$OIDC_BRIDGE_PID"

    echo -e "${GREEN}→ OIDC Bridge started (PID: $pid)${NC}"
    echo -e "${BLUE}  Logs: $OIDC_BRIDGE_LOG${NC}"

    # Wait for it to be ready
    wait_for_service "http://localhost:5001/health" "OIDC Bridge" 15

    echo -e "${GREEN}✓ OIDC Bridge ready${NC}"
    echo ""
}

##############################################################################
# Start Demo App
##############################################################################
start_demo_app() {
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}3. Starting Demo Application${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

    if check_running "$DEMO_APP_PID" "Demo App"; then
        return 0
    fi

    cd "$PROJECT_DIR/demo-app"

    # Check if node_modules exists
    if [ ! -d "node_modules" ]; then
        echo -e "${YELLOW}⚠ node_modules not found, running npm install...${NC}"
        npm install
    fi

    echo -e "${GREEN}→ Starting Demo App on port 3000...${NC}"

    # Start in background and capture PID
    PORT=3000 npm start > "$DEMO_APP_LOG" 2>&1 &
    local pid=$!
    echo $pid > "$DEMO_APP_PID"

    echo -e "${GREEN}→ Demo App started (PID: $pid)${NC}"
    echo -e "${BLUE}  Logs: $DEMO_APP_LOG${NC}"

    # Wait for it to be ready
    wait_for_service "http://localhost:3000" "Demo App" 15

    echo -e "${GREEN}✓ Demo App ready${NC}"
    echo ""
}

##############################################################################
# Start Dart Verifier
##############################################################################
start_dart_verifier() {
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}4. Starting Dart Verifier Server${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

    if [ -z "$DART_VERIFIER_PATH" ]; then
        echo -e "${YELLOW}⚠ DART_VERIFIER_PATH not set, skipping Dart Verifier${NC}"
        echo -e "${BLUE}  Set DART_VERIFIER_PATH=/path/to/verifier to enable${NC}"
        echo ""
        return 0
    fi

    if [ ! -d "$DART_VERIFIER_PATH" ]; then
        echo -e "${RED}✗ Dart Verifier path not found: $DART_VERIFIER_PATH${NC}"
        echo ""
        return 1
    fi

    if check_running "$DART_VERIFIER_PID" "Dart Verifier"; then
        return 0
    fi

    cd "$DART_VERIFIER_PATH"

    echo -e "${GREEN}→ Starting Dart Verifier on port 8081...${NC}"

    # Start in background and capture PID
    dart run bin/server.dart > "$DART_VERIFIER_LOG" 2>&1 &
    local pid=$!
    echo $pid > "$DART_VERIFIER_PID"

    echo -e "${GREEN}→ Dart Verifier started (PID: $pid)${NC}"
    echo -e "${BLUE}  Logs: $DART_VERIFIER_LOG${NC}"

    # Wait for it to be ready
    wait_for_service "http://localhost:8081/api/oob/clients" "Dart Verifier" 15

    echo -e "${GREEN}✓ Dart Verifier ready${NC}"
    echo ""
}

##############################################################################
# Main execution
##############################################################################
main() {
    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --dart-path)
                DART_VERIFIER_PATH="$2"
                START_DART=true
                shift 2
                ;;
            --skip-docker)
                START_DOCKER=false
                shift
                ;;
            --skip-oidc)
                START_OIDC=false
                shift
                ;;
            --skip-demo)
                START_DEMO=false
                shift
                ;;
            --only-docker)
                START_DOCKER=true
                START_OIDC=false
                START_DEMO=false
                START_DART=false
                shift
                ;;
            --help)
                echo "Usage: $0 [OPTIONS]"
                echo ""
                echo "Options:"
                echo "  --dart-path PATH    Path to Dart verifier project"
                echo "  --skip-docker       Skip starting Docker services"
                echo "  --skip-oidc         Skip starting OIDC Bridge"
                echo "  --skip-demo         Skip starting Demo App"
                echo "  --only-docker       Only start Docker services"
                echo "  --help              Show this help message"
                echo ""
                echo "Examples:"
                echo "  $0                                    # Start all services except Dart"
                echo "  $0 --dart-path ~/vdsp-verifier       # Start all including Dart"
                echo "  $0 --only-docker                     # Only start Docker services"
                exit 0
                ;;
            *)
                echo -e "${RED}Unknown option: $1${NC}"
                echo "Use --help for usage information"
                exit 1
                ;;
        esac
    done

    # Start services
    if [ "$START_DOCKER" = true ]; then
        start_docker_services
    fi

    if [ "$START_OIDC" = true ]; then
        start_oidc_bridge
    fi

    if [ "$START_DEMO" = true ]; then
        start_demo_app
    fi

    if [ "$START_DART" = true ]; then
        start_dart_verifier
    fi

    # Summary
    echo -e "${BLUE}╔════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║   All Services Started Successfully!                       ║${NC}"
    echo -e "${BLUE}╚════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${GREEN}Service Status:${NC}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

    if [ "$START_DOCKER" = true ]; then
        echo -e "${GREEN}✓${NC} PostgreSQL:      http://localhost:5432"
        echo -e "${GREEN}✓${NC} Keycloak:        http://localhost:8880"
        echo -e "                     ${BLUE}Admin: admin / admin${NC}"
    fi

    if [ "$START_OIDC" = true ]; then
        echo -e "${GREEN}✓${NC} OIDC Bridge:     http://localhost:5001"
        echo -e "                     ${BLUE}Health: http://localhost:5001/health${NC}"
        echo -e "                     ${BLUE}JWKS: http://localhost:5001/.well-known/jwks${NC}"
    fi

    if [ "$START_DEMO" = true ]; then
        echo -e "${GREEN}✓${NC} Demo App:        http://localhost:3000"
    fi

    if [ "$START_DART" = true ] && [ -f "$DART_VERIFIER_PID" ]; then
        echo -e "${GREEN}✓${NC} Dart Verifier:   http://localhost:8081"
        echo -e "                     ${BLUE}API: http://localhost:8081/api/oob/clients${NC}"
    fi

    echo ""
    echo -e "${YELLOW}Logs:${NC}"
    echo "  OIDC Bridge:   tail -f $OIDC_BRIDGE_LOG"
    echo "  Demo App:      tail -f $DEMO_APP_LOG"
    if [ "$START_DART" = true ]; then
        echo "  Dart Verifier: tail -f $DART_VERIFIER_LOG"
    fi
    echo ""
    echo -e "${YELLOW}Stop services:${NC} $SCRIPT_DIR/stop.sh"
    echo ""
}

# Run main function
main "$@"
