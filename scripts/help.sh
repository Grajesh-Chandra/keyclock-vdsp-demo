#!/bin/bash

##############################################################################
# Quick Reference - VDSP Federated VC Login Demo
#
# Displays a quick reference card for common operations
##############################################################################

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

clear

echo -e "${BLUE}╔══════════════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║                                                                          ║${NC}"
echo -e "${BLUE}║          ${CYAN}VDSP Federated VC Login - Quick Reference${BLUE}                      ║${NC}"
echo -e "${BLUE}║                                                                          ║${NC}"
echo -e "${BLUE}╚══════════════════════════════════════════════════════════════════════════╝${NC}"
echo ""

echo -e "${GREEN}📋 MANAGEMENT SCRIPTS${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo -e "${YELLOW}./scripts/start.sh${NC}              Start all services"
echo -e "${YELLOW}./scripts/stop.sh${NC}               Stop Node.js services"
echo -e "${YELLOW}./scripts/stop.sh --docker${NC}      Stop all services including Docker"
echo -e "${YELLOW}./scripts/cleanup.sh${NC}            Clean logs and PID files"
echo -e "${YELLOW}./scripts/cleanup.sh --all${NC}      Full cleanup (removes everything)"
echo -e "${YELLOW}./scripts/recreate.sh${NC}           Recreate environment fresh"
echo -e "${YELLOW}./scripts/test.sh${NC}               Run system tests"
echo ""

echo -e "${GREEN}🚀 COMMON WORKFLOWS${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo -e "${CYAN}First Time Setup:${NC}"
echo "  ./scripts/start.sh --dart-path ~/vdsp-verifier-server"
echo "  ./scripts/test.sh"
echo ""
echo -e "${CYAN}Daily Development:${NC}"
echo "  ./scripts/start.sh              # Start services"
echo "  ./scripts/stop.sh               # Stop (keep Docker running)"
echo ""
echo -e "${CYAN}Full Reset:${NC}"
echo "  ./scripts/cleanup.sh --all --force"
echo "  ./scripts/recreate.sh --with-docker"
echo ""
echo -e "${CYAN}Troubleshooting:${NC}"
echo "  ./scripts/stop.sh --force       # Kill orphaned processes"
echo "  ./scripts/test.sh               # Diagnose issues"
echo ""

echo -e "${GREEN}🌐 SERVICE URLS${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo -e "  ${YELLOW}Demo App:${NC}        http://localhost:3000"
echo -e "  ${YELLOW}Keycloak:${NC}        http://localhost:8880 ${CYAN}(admin/admin)${NC}"
echo -e "  ${YELLOW}OIDC Bridge:${NC}     http://localhost:5001"
echo -e "  ${YELLOW}Dart Verifier:${NC}   http://localhost:8081"
echo -e "  ${YELLOW}PostgreSQL:${NC}      localhost:5432 ${CYAN}(keycloak/keycloak)${NC}"
echo ""

echo -e "${GREEN}🔍 MONITORING${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo -e "${CYAN}View Logs:${NC}"
echo "  tail -f logs/oidc-bridge.log"
echo "  tail -f logs/demo-app.log"
echo "  docker logs -f vdsp-keycloak"
echo ""
echo -e "${CYAN}Check Status:${NC}"
echo "  docker ps"
echo "  ps aux | grep node | grep -v grep"
echo "  lsof -i tcp:3000,5001,8880,5432,8081"
echo ""

echo -e "${GREEN}🐛 TROUBLESHOOTING${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo -e "${CYAN}Port Already in Use:${NC}"
echo "  lsof -ti tcp:5001 | xargs kill -9"
echo "  ./scripts/stop.sh --force"
echo ""
echo -e "${CYAN}Docker Issues:${NC}"
echo "  docker compose down -v"
echo "  docker compose up -d postgres keycloak"
echo ""
echo -e "${CYAN}Keycloak Not Ready:${NC}"
echo "  docker logs vdsp-keycloak"
echo "  curl http://localhost:8880/health/ready"
echo ""
echo -e "${CYAN}Missing Realm:${NC}"
echo "  # Re-import keycloak-config/vdsp-demo-realm.json"
echo "  # via Keycloak Admin Console"
echo ""

echo -e "${GREEN}📚 DOCUMENTATION${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo "  README.md                               # Main project overview"
echo "  docs/QUICKSTART.md                      # Quick start guide"
echo "  docs/FEDERATED_VC_LOGIN_ARCHITECTURE.md # Complete flow (40 steps)"
echo "  scripts/README.md                       # This script's documentation"
echo ""

echo -e "${GREEN}💡 TIPS${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo "  • Keep Docker running between sessions (faster)"
echo "  • Use --help on any script for detailed options"
echo "  • Set DART_VERIFIER_PATH in ~/.zshrc or ~/.bashrc"
echo "  • Run ./scripts/test.sh after any changes"
echo "  • Check logs/ directory for debugging"
echo ""

echo -e "${YELLOW}For detailed help: ${CYAN}./scripts/[SCRIPT_NAME] --help${NC}"
echo ""
