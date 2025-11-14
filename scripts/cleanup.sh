#!/bin/bash

##############################################################################
# Cleanup Script - VDSP Federated VC Login Demo
#
# This script performs cleanup operations:
# 1. Stop all services
# 2. Remove Docker containers and volumes
# 3. Clean PID files and logs
# 4. Clean node_modules (optional)
# 5. Clean RSA keys (optional)
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
CLEAN_DOCKER=false
CLEAN_LOGS=false
CLEAN_NODE_MODULES=false
CLEAN_KEYS=false
CLEAN_ALL=false
FORCE=false

echo -e "${BLUE}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║   VDSP Federated VC Login - Cleanup                        ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════════╝${NC}"
echo ""

##############################################################################
# Confirm action
##############################################################################
confirm() {
    local message=$1

    if [ "$FORCE" = true ]; then
        return 0
    fi

    echo -e "${YELLOW}$message${NC}"
    read -p "Continue? (y/N): " -n 1 -r
    echo ""
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo -e "${BLUE}Skipped${NC}"
        return 1
    fi
    return 0
}

##############################################################################
# Stop all services
##############################################################################
stop_all_services() {
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}1. Stopping All Services${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

    "$SCRIPT_DIR/stop.sh" --docker --force || true
    echo ""
}

##############################################################################
# Clean Docker resources
##############################################################################
clean_docker() {
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}2. Cleaning Docker Resources${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

    cd "$PROJECT_DIR"

    if confirm "⚠ This will remove all containers, volumes, and data"; then
        echo -e "${BLUE}→ Removing Docker containers...${NC}"
        docker compose down -v 2>/dev/null || true

        echo -e "${BLUE}→ Removing dangling images...${NC}"
        docker image prune -f 2>/dev/null || true

        echo -e "${GREEN}✓ Docker resources cleaned${NC}"
    fi

    echo ""
}

##############################################################################
# Clean logs and PID files
##############################################################################
clean_logs_and_pids() {
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}3. Cleaning Logs and PID Files${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

    # Clean PID files
    echo -e "${BLUE}→ Removing PID files...${NC}"
    rm -f "$PROJECT_DIR/vc-authn-oidc-bridge/oidc-bridge.pid"
    rm -f "$PROJECT_DIR/demo-app/demo-app.pid"
    rm -f "$PROJECT_DIR/dart-verifier.pid"

    # Clean logs
    if [ -d "$PROJECT_DIR/logs" ]; then
        echo -e "${BLUE}→ Removing log files...${NC}"
        rm -rf "$PROJECT_DIR/logs"
    fi

    echo -e "${GREEN}✓ Logs and PID files cleaned${NC}"
    echo ""
}

##############################################################################
# Clean node_modules
##############################################################################
clean_node_modules() {
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}4. Cleaning Node Modules${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

    if confirm "⚠ This will remove all node_modules directories"; then
        echo -e "${BLUE}→ Removing OIDC Bridge node_modules...${NC}"
        rm -rf "$PROJECT_DIR/vc-authn-oidc-bridge/node_modules"
        rm -f "$PROJECT_DIR/vc-authn-oidc-bridge/package-lock.json"

        echo -e "${BLUE}→ Removing Demo App node_modules...${NC}"
        rm -rf "$PROJECT_DIR/demo-app/node_modules"
        rm -f "$PROJECT_DIR/demo-app/package-lock.json"

        echo -e "${GREEN}✓ Node modules cleaned${NC}"
        echo -e "${YELLOW}  Run 'npm install' in each directory before starting${NC}"
    fi

    echo ""
}

##############################################################################
# Clean RSA keys
##############################################################################
clean_keys() {
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}5. Cleaning RSA Keys${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

    if confirm "⚠ This will remove RSA private/public keys (new ones will be generated)"; then
        echo -e "${BLUE}→ Removing RSA keys...${NC}"
        rm -f "$PROJECT_DIR/vc-authn-oidc-bridge/keys/private.jwk"
        rm -f "$PROJECT_DIR/vc-authn-oidc-bridge/keys/public.jwk"

        echo -e "${GREEN}✓ RSA keys cleaned${NC}"
        echo -e "${YELLOW}  New keys will be generated on next start${NC}"
        echo -e "${YELLOW}  You will need to re-import the realm config in Keycloak${NC}"
    fi

    echo ""
}

##############################################################################
# Clean all
##############################################################################
clean_all_resources() {
    echo -e "${RED}╔════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${RED}║   WARNING: FULL CLEANUP                                    ║${NC}"
    echo -e "${RED}║   This will remove ALL data and containers!                ║${NC}"
    echo -e "${RED}╚════════════════════════════════════════════════════════════╝${NC}"
    echo ""

    if ! confirm "⚠ Perform FULL cleanup?"; then
        echo -e "${BLUE}Cleanup cancelled${NC}"
        exit 0
    fi

    stop_all_services
    clean_docker
    clean_logs_and_pids
    clean_node_modules
    clean_keys
}

##############################################################################
# Display cleanup summary
##############################################################################
show_summary() {
    echo -e "${BLUE}╔════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║   Cleanup Summary                                          ║${NC}"
    echo -e "${BLUE}╚════════════════════════════════════════════════════════════╝${NC}"
    echo ""

    echo -e "${GREEN}Cleaned:${NC}"
    echo -e "  ${GREEN}✓${NC} Services stopped"
    echo -e "  ${GREEN}✓${NC} Logs and PID files removed"

    if [ "$CLEAN_DOCKER" = true ] || [ "$CLEAN_ALL" = true ]; then
        echo -e "  ${GREEN}✓${NC} Docker containers and volumes removed"
    fi

    if [ "$CLEAN_NODE_MODULES" = true ] || [ "$CLEAN_ALL" = true ]; then
        echo -e "  ${GREEN}✓${NC} Node modules removed"
    fi

    if [ "$CLEAN_KEYS" = true ] || [ "$CLEAN_ALL" = true ]; then
        echo -e "  ${GREEN}✓${NC} RSA keys removed"
    fi

    echo ""
    echo -e "${YELLOW}Next steps:${NC}"

    if [ "$CLEAN_NODE_MODULES" = true ] || [ "$CLEAN_ALL" = true ]; then
        echo -e "  1. Run 'npm install' in vc-authn-oidc-bridge/"
        echo -e "  2. Run 'npm install' in demo-app/"
    fi

    if [ "$CLEAN_DOCKER" = true ] || [ "$CLEAN_ALL" = true ]; then
        echo -e "  3. Run '$SCRIPT_DIR/start.sh' to restart services"
    fi

    if [ "$CLEAN_KEYS" = true ] || [ "$CLEAN_ALL" = true ]; then
        echo -e "  4. Re-import Keycloak realm configuration"
    fi

    echo ""
}

##############################################################################
# Main execution
##############################################################################
main() {
    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --docker)
                CLEAN_DOCKER=true
                shift
                ;;
            --logs)
                CLEAN_LOGS=true
                shift
                ;;
            --node-modules)
                CLEAN_NODE_MODULES=true
                shift
                ;;
            --keys)
                CLEAN_KEYS=true
                shift
                ;;
            --all)
                CLEAN_ALL=true
                shift
                ;;
            --force)
                FORCE=true
                shift
                ;;
            --help)
                echo "Usage: $0 [OPTIONS]"
                echo ""
                echo "Options:"
                echo "  --docker         Remove Docker containers and volumes"
                echo "  --logs           Remove log files and PID files"
                echo "  --node-modules   Remove node_modules directories"
                echo "  --keys           Remove RSA private/public keys"
                echo "  --all            Perform full cleanup (all of the above)"
                echo "  --force          Skip confirmation prompts"
                echo "  --help           Show this help message"
                echo ""
                echo "Examples:"
                echo "  $0 --logs                    # Clean logs only"
                echo "  $0 --docker --node-modules   # Clean Docker and node_modules"
                echo "  $0 --all                     # Full cleanup"
                echo "  $0 --all --force             # Full cleanup without prompts"
                exit 0
                ;;
            *)
                echo -e "${RED}Unknown option: $1${NC}"
                echo "Use --help for usage information"
                exit 1
                ;;
        esac
    done

    # Default to cleaning logs if no options specified
    if [ "$CLEAN_DOCKER" = false ] && [ "$CLEAN_LOGS" = false ] && \
       [ "$CLEAN_NODE_MODULES" = false ] && [ "$CLEAN_KEYS" = false ] && \
       [ "$CLEAN_ALL" = false ]; then
        CLEAN_LOGS=true
    fi

    # Execute cleanup
    if [ "$CLEAN_ALL" = true ]; then
        clean_all_resources
    else
        stop_all_services

        if [ "$CLEAN_DOCKER" = true ]; then
            clean_docker
        fi

        if [ "$CLEAN_LOGS" = true ]; then
            clean_logs_and_pids
        fi

        if [ "$CLEAN_NODE_MODULES" = true ]; then
            clean_node_modules
        fi

        if [ "$CLEAN_KEYS" = true ]; then
            clean_keys
        fi
    fi

    show_summary
}

# Run main function
main "$@"
