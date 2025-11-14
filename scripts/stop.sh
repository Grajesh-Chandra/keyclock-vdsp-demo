#!/bin/bash

##############################################################################
# Stop Script - VDSP Federated VC Login Demo
#
# This script stops all running services:
# 1. Node.js services (OIDC Bridge, Demo App)
# 2. Dart Verifier (if running)
# 3. Docker services (optional)
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

# Configuration
STOP_DOCKER="${STOP_DOCKER:-false}"

echo -e "${BLUE}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║   VDSP Federated VC Login - Service Shutdown              ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════════╝${NC}"
echo ""

##############################################################################
# Stop service by PID file
##############################################################################
stop_service() {
    local pid_file=$1
    local service_name=$2

    if [ ! -f "$pid_file" ]; then
        echo -e "${YELLOW}⚠ $service_name PID file not found${NC}"
        return 0
    fi

    local pid=$(cat "$pid_file")

    if ! ps -p "$pid" > /dev/null 2>&1; then
        echo -e "${YELLOW}⚠ $service_name (PID: $pid) is not running${NC}"
        rm -f "$pid_file"
        return 0
    fi

    echo -e "${BLUE}→ Stopping $service_name (PID: $pid)...${NC}"

    # Try graceful shutdown first
    kill "$pid" 2>/dev/null || true

    # Wait up to 10 seconds for graceful shutdown
    local wait_count=0
    while ps -p "$pid" > /dev/null 2>&1 && [ $wait_count -lt 10 ]; do
        sleep 1
        wait_count=$((wait_count + 1))
        echo -n "."
    done
    echo ""

    # Force kill if still running
    if ps -p "$pid" > /dev/null 2>&1; then
        echo -e "${YELLOW}→ Force killing $service_name...${NC}"
        kill -9 "$pid" 2>/dev/null || true
        sleep 1
    fi

    # Verify stopped
    if ! ps -p "$pid" > /dev/null 2>&1; then
        echo -e "${GREEN}✓ $service_name stopped${NC}"
        rm -f "$pid_file"
    else
        echo -e "${RED}✗ Failed to stop $service_name${NC}"
        return 1
    fi
}

##############################################################################
# Stop Node.js services
##############################################################################
stop_nodejs_services() {
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}1. Stopping Node.js Services${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

    stop_service "$OIDC_BRIDGE_PID" "OIDC Bridge"
    stop_service "$DEMO_APP_PID" "Demo App"

    echo ""
}

##############################################################################
# Stop Dart Verifier
##############################################################################
stop_dart_verifier() {
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}2. Stopping Dart Verifier${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

    if [ -f "$DART_VERIFIER_PID" ]; then
        stop_service "$DART_VERIFIER_PID" "Dart Verifier"
    else
        echo -e "${YELLOW}⚠ Dart Verifier not running${NC}"
    fi

    echo ""
}

##############################################################################
# Stop Docker services
##############################################################################
stop_docker_services() {
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}3. Stopping Docker Services${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

    cd "$PROJECT_DIR"

    if ! docker ps | grep -q "vdsp-"; then
        echo -e "${YELLOW}⚠ No Docker services running${NC}"
        echo ""
        return 0
    fi

    echo -e "${BLUE}→ Stopping Docker containers...${NC}"
    docker compose stop

    echo -e "${GREEN}✓ Docker services stopped${NC}"
    echo ""
}

##############################################################################
# Kill any orphaned processes
##############################################################################
kill_orphaned_processes() {
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}Checking for orphaned processes...${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

    # Check for orphaned Node.js processes on specific ports
    local ports=(5001 3000)
    local killed=false

    for port in "${ports[@]}"; do
        local pid=$(lsof -ti tcp:$port 2>/dev/null || true)
        if [ -n "$pid" ]; then
            echo -e "${YELLOW}⚠ Found orphaned process on port $port (PID: $pid)${NC}"
            echo -e "${BLUE}→ Killing process...${NC}"
            kill -9 "$pid" 2>/dev/null || true
            killed=true
        fi
    done

    if [ "$killed" = false ]; then
        echo -e "${GREEN}✓ No orphaned processes found${NC}"
    else
        echo -e "${GREEN}✓ Orphaned processes cleaned up${NC}"
    fi

    echo ""
}

##############################################################################
# Main execution
##############################################################################
main() {
    local STOP_OIDC_ONLY=false
    local STOP_DEMO_ONLY=false

    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --docker)
                STOP_DOCKER=true
                shift
                ;;
            --force)
                kill_orphaned_processes
                shift
                ;;
            --oidc-only)
                STOP_OIDC_ONLY=true
                shift
                ;;
            --demo-only)
                STOP_DEMO_ONLY=true
                shift
                ;;
            --help)
                echo "Usage: $0 [OPTIONS]"
                echo ""
                echo "Options:"
                echo "  --docker        Also stop Docker services (PostgreSQL, Keycloak)"
                echo "  --force         Kill any orphaned processes on ports 5001, 3000"
                echo "  --oidc-only     Stop OIDC Bridge only"
                echo "  --demo-only     Stop Demo App only"
                echo "  --help          Show this help message"
                echo ""
                echo "Examples:"
                echo "  $0                    # Stop Node.js services only"
                echo "  $0 --docker          # Stop all services including Docker"
                echo "  $0 --force           # Kill orphaned processes"
                echo "  $0 --oidc-only       # Stop OIDC Bridge only"
                echo "  $0 --demo-only       # Stop Demo App only"
                exit 0
                ;;
            *)
                echo -e "${RED}Unknown option: $1${NC}"
                echo "Use --help for usage information"
                exit 1
                ;;
        esac
    done

    # Stop services based on options
    if [ "$STOP_OIDC_ONLY" = true ]; then
        stop_service "$OIDC_BRIDGE_PID" "OIDC Bridge"
    elif [ "$STOP_DEMO_ONLY" = true ]; then
        stop_service "$DEMO_APP_PID" "Demo App"
    else
        stop_nodejs_services
        stop_dart_verifier
    fi

    if [ "$STOP_DOCKER" = true ]; then
        stop_docker_services
    fi

    # Summary
    echo -e "${BLUE}╔════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║   Services Stopped Successfully!                          ║${NC}"
    echo -e "${BLUE}╚════════════════════════════════════════════════════════════╝${NC}"
    echo ""

    if [ "$STOP_DOCKER" = false ]; then
        echo -e "${YELLOW}Note: Docker services (PostgreSQL, Keycloak) are still running${NC}"
        echo -e "      Use: $0 --docker to stop them${NC}"
        echo ""
    fi

    echo -e "${GREEN}Restart services:${NC} $SCRIPT_DIR/start.sh"
    echo ""
}

# Run main function
main "$@"
