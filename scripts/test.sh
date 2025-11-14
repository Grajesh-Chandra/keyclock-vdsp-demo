#!/bin/bash

##############################################################################
# Test Script - VDSP Federated VC Login Demo
#
# This script tests the entire setup:
# 1. Check all services are running
# 2. Test service endpoints
# 3. Verify configurations
# 4. Test authentication flow (partial)
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

# Test results
TESTS_PASSED=0
TESTS_FAILED=0
TESTS_TOTAL=0

echo -e "${BLUE}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║   VDSP Federated VC Login - System Test                   ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════════╝${NC}"
echo ""

##############################################################################
# Test helper functions
##############################################################################
test_start() {
    local test_name=$1
    TESTS_TOTAL=$((TESTS_TOTAL + 1))
    echo -e "${BLUE}[TEST $TESTS_TOTAL] $test_name${NC}"
}

test_pass() {
    TESTS_PASSED=$((TESTS_PASSED + 1))
    echo -e "${GREEN}  ✓ PASS${NC}"
    echo ""
}

test_fail() {
    local reason=$1
    TESTS_FAILED=$((TESTS_FAILED + 1))
    echo -e "${RED}  ✗ FAIL: $reason${NC}"
    echo ""
}

test_warning() {
    local message=$1
    echo -e "${YELLOW}  ⚠ WARNING: $message${NC}"
    echo ""
}

##############################################################################
# Test: PostgreSQL
##############################################################################
test_postgres() {
    test_start "PostgreSQL Running"

    if docker ps | grep -q "vdsp-postgres"; then
        echo -e "${GREEN}  → Container running${NC}"

        # Test connection
        if docker exec vdsp-postgres pg_isready -U keycloak > /dev/null 2>&1; then
            echo -e "${GREEN}  → Database accepting connections${NC}"
            test_pass
        else
            test_fail "Database not accepting connections"
        fi
    else
        test_fail "Container not running"
    fi
}

##############################################################################
# Test: Keycloak
##############################################################################
test_keycloak() {
    test_start "Keycloak Service"

    if ! docker ps | grep -q "vdsp-keycloak"; then
        test_fail "Container not running"
        return
    fi

    echo -e "${GREEN}  → Container running${NC}"

    # Test health endpoint
    if curl -s -f "http://localhost:8880/health/ready" > /dev/null 2>&1; then
        echo -e "${GREEN}  → Health endpoint responding${NC}"
    else
        test_fail "Health endpoint not responding"
        return
    fi

    # Test realm endpoint
    if curl -s -f "http://localhost:8880/realms/vdsp-demo" > /dev/null 2>&1; then
        echo -e "${GREEN}  → Realm 'vdsp-demo' accessible${NC}"
        test_pass
    else
        test_fail "Realm 'vdsp-demo' not found"
    fi
}

##############################################################################
# Test: Keycloak Realm Configuration
##############################################################################
test_keycloak_config() {
    test_start "Keycloak Realm Configuration"

    # Get admin token
    local token=$(curl -s -X POST "http://localhost:8880/realms/master/protocol/openid-connect/token" \
        -H "Content-Type: application/x-www-form-urlencoded" \
        -d "username=admin" \
        -d "password=admin" \
        -d "grant_type=password" \
        -d "client_id=admin-cli" | jq -r '.access_token' 2>/dev/null || true)

    if [ -z "$token" ] || [ "$token" = "null" ]; then
        test_fail "Could not authenticate as admin"
        return
    fi

    echo -e "${GREEN}  → Admin authentication successful${NC}"

    # Check Identity Provider
    local idp_check=$(curl -s -H "Authorization: Bearer $token" \
        "http://localhost:8880/admin/realms/vdsp-demo/identity-provider/instances/vc-authn" 2>/dev/null || true)

    if echo "$idp_check" | grep -q "vc-authn"; then
        echo -e "${GREEN}  → Identity Provider 'vc-authn' configured${NC}"

        # Check authorization URL
        if echo "$idp_check" | grep -q "localhost:5001/authorize"; then
            echo -e "${GREEN}  → Authorization URL correct${NC}"
        else
            test_warning "Authorization URL may be incorrect"
        fi

        test_pass
    else
        test_fail "Identity Provider 'vc-authn' not found"
    fi
}

##############################################################################
# Test: OIDC Bridge
##############################################################################
test_oidc_bridge() {
    test_start "OIDC Bridge Service"

    # Check if process is running
    local pid_file="$PROJECT_DIR/vc-authn-oidc-bridge/oidc-bridge.pid"
    if [ ! -f "$pid_file" ]; then
        test_fail "PID file not found (service not started?)"
        return
    fi

    local pid=$(cat "$pid_file")
    if ! ps -p "$pid" > /dev/null 2>&1; then
        test_fail "Process not running (PID: $pid)"
        return
    fi

    echo -e "${GREEN}  → Process running (PID: $pid)${NC}"

    # Test health endpoint
    if curl -s -f "http://localhost:5001/health" > /dev/null 2>&1; then
        echo -e "${GREEN}  → Health endpoint responding${NC}"
    else
        test_fail "Health endpoint not responding"
        return
    fi

    # Test discovery endpoint
    if curl -s -f "http://localhost:5001/.well-known/openid-configuration" > /dev/null 2>&1; then
        echo -e "${GREEN}  → OpenID discovery endpoint responding${NC}"
    else
        test_warning "Discovery endpoint not responding"
    fi

    # Test JWKS endpoint
    local jwks=$(curl -s "http://localhost:5001/.well-known/jwks" 2>/dev/null || true)
    if echo "$jwks" | grep -q "keys"; then
        echo -e "${GREEN}  → JWKS endpoint responding${NC}"

        # Check if keys exist
        if echo "$jwks" | jq -e '.keys[0].n' > /dev/null 2>&1; then
            echo -e "${GREEN}  → RSA public key found${NC}"
        else
            test_warning "RSA public key not found in JWKS"
        fi
    else
        test_warning "JWKS endpoint not responding correctly"
    fi

    test_pass
}

##############################################################################
# Test: Demo App
##############################################################################
test_demo_app() {
    test_start "Demo Application"

    # Check if process is running
    local pid_file="$PROJECT_DIR/demo-app/demo-app.pid"
    if [ ! -f "$pid_file" ]; then
        test_fail "PID file not found (service not started?)"
        return
    fi

    local pid=$(cat "$pid_file")
    if ! ps -p "$pid" > /dev/null 2>&1; then
        test_fail "Process not running (PID: $pid)"
        return
    fi

    echo -e "${GREEN}  → Process running (PID: $pid)${NC}"

    # Test home page
    if curl -s -f "http://localhost:3000" > /dev/null 2>&1; then
        echo -e "${GREEN}  → Home page responding${NC}"
        test_pass
    else
        test_fail "Home page not responding"
    fi
}

##############################################################################
# Test: Dart Verifier (if running)
##############################################################################
test_dart_verifier() {
    test_start "Dart Verifier Service (Optional)"

    # Check if process is running
    local pid_file="$PROJECT_DIR/dart-verifier.pid"
    if [ ! -f "$pid_file" ]; then
        test_warning "Not running (optional service)"
        return
    fi

    local pid=$(cat "$pid_file")
    if ! ps -p "$pid" > /dev/null 2>&1; then
        test_warning "PID file exists but process not running"
        return
    fi

    echo -e "${GREEN}  → Process running (PID: $pid)${NC}"

    # Test API endpoint
    if curl -s -f "http://localhost:8081/api/oob/clients" > /dev/null 2>&1; then
        echo -e "${GREEN}  → API endpoint responding${NC}"

        # Check for federatedlogin client
        local clients=$(curl -s "http://localhost:8081/api/oob/clients" 2>/dev/null || true)
        if echo "$clients" | grep -q "federatedlogin"; then
            echo -e "${GREEN}  → Client 'federatedlogin' found${NC}"
        else
            test_warning "Client 'federatedlogin' not found"
        fi

        test_pass
    else
        test_fail "API endpoint not responding"
    fi
}

##############################################################################
# Test: RSA Keys
##############################################################################
test_rsa_keys() {
    test_start "RSA Key Pair"

    local private_key="$PROJECT_DIR/vc-authn-oidc-bridge/keys/private.jwk"
    local public_key="$PROJECT_DIR/vc-authn-oidc-bridge/keys/public.jwk"

    if [ ! -f "$private_key" ]; then
        test_fail "Private key not found"
        return
    fi

    if [ ! -f "$public_key" ]; then
        test_fail "Public key not found"
        return
    fi

    echo -e "${GREEN}  → Private key exists${NC}"
    echo -e "${GREEN}  → Public key exists${NC}"

    # Validate JSON structure
    if jq empty "$private_key" 2>/dev/null; then
        echo -e "${GREEN}  → Private key is valid JSON${NC}"
    else
        test_fail "Private key is not valid JSON"
        return
    fi

    if jq empty "$public_key" 2>/dev/null; then
        echo -e "${GREEN}  → Public key is valid JSON${NC}"
    else
        test_fail "Public key is not valid JSON"
        return
    fi

    # Check key parameters
    if jq -e '.n and .e and .d' "$private_key" > /dev/null 2>&1; then
        echo -e "${GREEN}  → Private key has required parameters${NC}"
    else
        test_fail "Private key missing required parameters"
        return
    fi

    if jq -e '.n and .e and .kid' "$public_key" > /dev/null 2>&1; then
        echo -e "${GREEN}  → Public key has required parameters${NC}"
    else
        test_fail "Public key missing required parameters"
        return
    fi

    test_pass
}

##############################################################################
# Test: Environment Variables
##############################################################################
test_environment() {
    test_start "Environment Configuration"

    local env_file="$PROJECT_DIR/vc-authn-oidc-bridge/.env"

    if [ ! -f "$env_file" ]; then
        test_warning ".env file not found (using environment variables?)"
        return
    fi

    echo -e "${GREEN}  → .env file exists${NC}"

    # Check critical variables
    local required_vars=("PORT" "ISSUER_URL" "KEYCLOAK_CLIENT_SECRET" "VERIFIER_SERVER_URL")
    local missing_vars=()

    for var in "${required_vars[@]}"; do
        if ! grep -q "^${var}=" "$env_file"; then
            missing_vars+=("$var")
        fi
    done

    if [ ${#missing_vars[@]} -eq 0 ]; then
        echo -e "${GREEN}  → All required variables present${NC}"
        test_pass
    else
        test_fail "Missing variables: ${missing_vars[*]}"
    fi
}

##############################################################################
# Test: Network Connectivity
##############################################################################
test_network() {
    test_start "Network Connectivity"

    local all_ok=true

    # Test port availability
    local ports=(5432 8880 5001 3000)
    local port_names=("PostgreSQL" "Keycloak" "OIDC Bridge" "Demo App")

    for i in "${!ports[@]}"; do
        local port="${ports[$i]}"
        local name="${port_names[$i]}"

        if lsof -i tcp:$port > /dev/null 2>&1; then
            echo -e "${GREEN}  → Port $port ($name) is open${NC}"
        else
            echo -e "${RED}  → Port $port ($name) is not open${NC}"
            all_ok=false
        fi
    done

    if [ "$all_ok" = true ]; then
        test_pass
    else
        test_fail "Some ports are not open"
    fi
}

##############################################################################
# Test: Integration Flow (Basic)
##############################################################################
test_integration_flow() {
    test_start "Basic Integration Flow"

    echo -e "${BLUE}  → Testing OIDC discovery...${NC}"
    local discovery=$(curl -s "http://localhost:5001/.well-known/openid-configuration" 2>/dev/null || true)

    if ! echo "$discovery" | grep -q "authorization_endpoint"; then
        test_fail "OIDC discovery failed"
        return
    fi

    echo -e "${GREEN}  → OIDC discovery successful${NC}"

    echo -e "${BLUE}  → Testing Keycloak to OIDC Bridge connectivity...${NC}"

    # Simulate Keycloak hitting authorize endpoint (without full OAuth flow)
    local authorize_response=$(curl -s -w "%{http_code}" \
        "http://localhost:5001/authorize?client_id=vc-authn&redirect_uri=http://localhost:8880/test&response_type=code&state=test" \
        2>/dev/null | tail -n 1)

    if [ "$authorize_response" = "200" ] || [ "$authorize_response" = "302" ]; then
        echo -e "${GREEN}  → Authorize endpoint accessible${NC}"
        test_pass
    else
        test_fail "Authorize endpoint returned $authorize_response"
    fi
}

##############################################################################
# Display test summary
##############################################################################
show_summary() {
    echo -e "${BLUE}╔════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║   Test Summary                                             ║${NC}"
    echo -e "${BLUE}╚════════════════════════════════════════════════════════════╝${NC}"
    echo ""

    echo -e "${BLUE}Tests Run:    $TESTS_TOTAL${NC}"
    echo -e "${GREEN}Tests Passed: $TESTS_PASSED${NC}"

    if [ $TESTS_FAILED -gt 0 ]; then
        echo -e "${RED}Tests Failed: $TESTS_FAILED${NC}"
        echo ""
        echo -e "${RED}✗ Some tests failed${NC}"
        echo ""
        echo -e "${YELLOW}Troubleshooting:${NC}"
        echo "  1. Check service logs in $PROJECT_DIR/logs/"
        echo "  2. Verify all services are running: docker ps && ps aux | grep node"
        echo "  3. Check port conflicts: lsof -i tcp:5001,3000,8880,5432"
        echo "  4. Review configuration: cat vc-authn-oidc-bridge/.env"
        echo ""
        exit 1
    else
        echo ""
        echo -e "${GREEN}✓ All tests passed!${NC}"
        echo ""
        echo -e "${BLUE}Your environment is ready for testing${NC}"
        echo ""
        echo -e "${YELLOW}Next steps:${NC}"
        echo "  1. Access Demo App:  http://localhost:3000"
        echo "  2. Access Keycloak:  http://localhost:8880 (admin/admin)"
        echo "  3. Test VC login flow with your wallet app"
        echo ""
        exit 0
    fi
}

##############################################################################
# Main execution
##############################################################################
main() {
    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --help)
                echo "Usage: $0 [OPTIONS]"
                echo ""
                echo "This script tests all components of the VDSP demo"
                echo ""
                echo "Options:"
                echo "  --help    Show this help message"
                exit 0
                ;;
            *)
                echo -e "${RED}Unknown option: $1${NC}"
                echo "Use --help for usage information"
                exit 1
                ;;
        esac
    done

    # Run all tests
    echo -e "${BLUE}Running system tests...${NC}"
    echo ""

    test_postgres
    test_keycloak
    test_keycloak_config
    test_oidc_bridge
    test_demo_app
    test_dart_verifier
    test_rsa_keys
    test_environment
    test_network
    test_integration_flow

    # Show summary
    show_summary
}

# Run main function
main "$@"
