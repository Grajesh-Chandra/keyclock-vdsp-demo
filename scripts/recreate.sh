#!/bin/bash

##############################################################################
# Recreate Script - VDSP Federated VC Login Demo
#
# This script performs a complete recreation:
# 1. Stop all services
# 2. Clean up resources
# 3. Reinstall dependencies
# 4. Start services fresh
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

# Configuration
RECREATE_DOCKER=false
RECREATE_KEYS=false
DART_VERIFIER_PATH="${DART_VERIFIER_PATH:-}"

echo -e "${BLUE}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║   VDSP Federated VC Login - Recreate Environment          ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════════╝${NC}"
echo ""

##############################################################################
# Step 1: Cleanup
##############################################################################
cleanup_environment() {
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}Step 1: Cleaning Up Existing Environment${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

    local cleanup_args="--logs --node-modules --force"

    if [ "$RECREATE_DOCKER" = true ]; then
        cleanup_args="$cleanup_args --docker"
    fi

    if [ "$RECREATE_KEYS" = true ]; then
        cleanup_args="$cleanup_args --keys"
    fi

    "$SCRIPT_DIR/cleanup.sh" $cleanup_args
    echo ""
}

##############################################################################
# Step 2: Install dependencies
##############################################################################
install_dependencies() {
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}Step 2: Installing Dependencies${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

    # Install OIDC Bridge dependencies
    echo -e "${GREEN}→ Installing OIDC Bridge dependencies...${NC}"
    cd "$PROJECT_DIR/vc-authn-oidc-bridge"
    npm install
    echo -e "${GREEN}✓ OIDC Bridge dependencies installed${NC}"
    echo ""

    # Install Demo App dependencies
    echo -e "${GREEN}→ Installing Demo App dependencies...${NC}"
    cd "$PROJECT_DIR/demo-app"
    npm install
    echo -e "${GREEN}✓ Demo App dependencies installed${NC}"
    echo ""
}

##############################################################################
# Step 3: Setup Docker services
##############################################################################
setup_docker_services() {
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}Step 3: Setting Up Docker Services${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

    cd "$PROJECT_DIR"

    if [ "$RECREATE_DOCKER" = true ]; then
        echo -e "${GREEN}→ Pulling latest Docker images...${NC}"
        docker compose pull postgres keycloak
        echo ""
    fi

    echo -e "${GREEN}→ Starting PostgreSQL and Keycloak...${NC}"
    docker compose up -d postgres keycloak

    echo -e "${BLUE}⏳ Waiting for services to be ready...${NC}"
    sleep 5

    # Wait for Keycloak
    local max_attempts=60
    local attempt=0

    while [ $attempt -lt $max_attempts ]; do
        if curl -s -f "http://localhost:8880/health/ready" > /dev/null 2>&1; then
            echo -e "${GREEN}✓ Keycloak is ready!${NC}"
            break
        fi
        attempt=$((attempt + 1))
        echo -n "."
        sleep 2
    done
    echo ""

    if [ $attempt -eq $max_attempts ]; then
        echo -e "${RED}✗ Keycloak failed to start${NC}"
        exit 1
    fi

    echo ""
}

##############################################################################
# Step 4: Verify realm configuration
##############################################################################
verify_realm_config() {
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}Step 4: Verifying Realm Configuration${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

    echo -e "${BLUE}→ Checking if realm exists...${NC}"

    # Get admin token
    local token=$(curl -s -X POST "http://localhost:8880/realms/master/protocol/openid-connect/token" \
        -H "Content-Type: application/x-www-form-urlencoded" \
        -d "username=admin" \
        -d "password=admin" \
        -d "grant_type=password" \
        -d "client_id=admin-cli" | jq -r '.access_token' 2>/dev/null || true)

    if [ -n "$token" ] && [ "$token" != "null" ]; then
        local realm_check=$(curl -s -H "Authorization: Bearer $token" \
            "http://localhost:8880/admin/realms/vdsp-demo" 2>/dev/null || true)

        if echo "$realm_check" | grep -q "vdsp-demo"; then
            echo -e "${GREEN}✓ Realm 'vdsp-demo' found${NC}"
        else
            echo -e "${YELLOW}⚠ Realm 'vdsp-demo' not found${NC}"
            echo -e "${YELLOW}  The realm should be auto-imported from keycloak-config/vdsp-demo-realm.json${NC}"
            echo -e "${YELLOW}  If not, manually import it via Keycloak Admin Console${NC}"
        fi
    else
        echo -e "${YELLOW}⚠ Could not verify realm (authentication failed)${NC}"
        echo -e "${YELLOW}  Verify manually at: http://localhost:8880${NC}"
    fi

    echo ""
}

##############################################################################
# Step 5: Start services
##############################################################################
start_services() {
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}Step 5: Starting Services${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

    local start_args="--skip-docker"

    if [ -n "$DART_VERIFIER_PATH" ]; then
        start_args="$start_args --dart-path $DART_VERIFIER_PATH"
    fi

    "$SCRIPT_DIR/start.sh" $start_args
}

##############################################################################
# Display summary
##############################################################################
show_summary() {
    echo -e "${BLUE}╔════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║   Environment Recreation Complete!                        ║${NC}"
    echo -e "${BLUE}╚════════════════════════════════════════════════════════════╝${NC}"
    echo ""

    echo -e "${GREEN}✓ All services recreated and started${NC}"
    echo ""

    echo -e "${YELLOW}Service URLs:${NC}"
    echo "  Keycloak:      http://localhost:8880 (admin/admin)"
    echo "  Demo App:      http://localhost:3000"
    echo "  OIDC Bridge:   http://localhost:5001"

    if [ -n "$DART_VERIFIER_PATH" ]; then
        echo "  Dart Verifier: http://localhost:8081"
    fi

    echo ""

    if [ "$RECREATE_KEYS" = true ]; then
        echo -e "${YELLOW}⚠ RSA keys were regenerated${NC}"
        echo -e "${YELLOW}  You may need to:${NC}"
        echo -e "${YELLOW}  1. Export new JWKS from http://localhost:5001/.well-known/jwks${NC}"
        echo -e "${YELLOW}  2. Update Keycloak Identity Provider if JWKS URL is not used${NC}"
        echo ""
    fi

    echo -e "${GREEN}Test the setup:${NC} $SCRIPT_DIR/test.sh"
    echo ""
}

##############################################################################
# Main execution
##############################################################################
main() {
    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --with-docker)
                RECREATE_DOCKER=true
                shift
                ;;
            --with-keys)
                RECREATE_KEYS=true
                shift
                ;;
            --dart-path)
                DART_VERIFIER_PATH="$2"
                shift 2
                ;;
            --help)
                echo "Usage: $0 [OPTIONS]"
                echo ""
                echo "Options:"
                echo "  --with-docker        Also recreate Docker containers and volumes"
                echo "  --with-keys          Also regenerate RSA keys"
                echo "  --dart-path PATH     Path to Dart verifier project"
                echo "  --help               Show this help message"
                echo ""
                echo "Examples:"
                echo "  $0                                    # Recreate services (keep Docker)"
                echo "  $0 --with-docker                     # Full recreation"
                echo "  $0 --with-docker --with-keys         # Complete reset"
                echo "  $0 --dart-path ~/vdsp-verifier       # Include Dart verifier"
                exit 0
                ;;
            *)
                echo -e "${RED}Unknown option: $1${NC}"
                echo "Use --help for usage information"
                exit 1
                ;;
        esac
    done

    # Confirm action
    echo -e "${YELLOW}This will recreate the development environment:${NC}"
    echo "  - Stop all services"
    echo "  - Clean logs and node_modules"

    if [ "$RECREATE_DOCKER" = true ]; then
        echo "  - Remove and recreate Docker containers"
    fi

    if [ "$RECREATE_KEYS" = true ]; then
        echo "  - Regenerate RSA keys"
    fi

    echo "  - Reinstall npm dependencies"
    echo "  - Start all services"
    echo ""

    read -p "Continue? (y/N): " -n 1 -r
    echo ""
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo -e "${BLUE}Recreation cancelled${NC}"
        exit 0
    fi

    # Execute recreation steps
    cleanup_environment
    install_dependencies
    setup_docker_services
    verify_realm_config
    start_services
    show_summary
}

# Run main function
main "$@"
