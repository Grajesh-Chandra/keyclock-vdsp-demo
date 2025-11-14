#!/bin/bash

# Keycloak Demo Startup Script
# This script helps you start the Keycloak demo environment

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_info() {
    echo -e "${BLUE}ℹ ${1}${NC}"
}

print_success() {
    echo -e "${GREEN}✓ ${1}${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠ ${1}${NC}"
}

print_error() {
    echo -e "${RED}✗ ${1}${NC}"
}

# Function to check if Docker is running
check_docker() {
    print_info "Checking Docker..."
    if ! docker info > /dev/null 2>&1; then
        print_error "Docker is not running. Please start Docker Desktop and try again."
        exit 1
    fi
    print_success "Docker is running"
}

# Function to check if required ports are available
check_ports() {
    print_info "Checking if required ports are available..."

    local ports_in_use=false
    local port_details=""

    if lsof -Pi :3000 -sTCP:LISTEN -t >/dev/null 2>&1 ; then
        local pid=$(lsof -ti :3000 2>/dev/null)
        print_warning "Port 3000 is already in use (Demo App) - PID: $pid"
        port_details="${port_details}3000 "
        ports_in_use=true
    fi

    if lsof -Pi :5432 -sTCP:LISTEN -t >/dev/null 2>&1 ; then
        local pid=$(lsof -ti :5432 2>/dev/null)
        print_warning "Port 5432 is already in use (PostgreSQL) - PID: $pid"
        port_details="${port_details}5432 "
        ports_in_use=true
    fi

    if lsof -Pi :8880 -sTCP:LISTEN -t >/dev/null 2>&1 ; then
        local pid=$(lsof -ti :8880 2>/dev/null)
        print_warning "Port 8880 is already in use (Keycloak) - PID: $pid"
        port_details="${port_details}8880 "
        ports_in_use=true
    fi

    if [ "$ports_in_use" = true ]; then
        echo ""
        print_warning "Some required ports are in use. This might be from a previous run."
        echo ""
        read -p "Try to free up ports automatically? (y/n) " -n 1 -r
        echo ""

        if [[ $REPLY =~ ^[Yy]$ ]]; then
            print_info "Attempting to stop Docker containers and free ports..."
            docker compose down 2>/dev/null || true
            sleep 2

            # Kill remaining processes on ports
            for port in $port_details; do
                local pid=$(lsof -ti :$port 2>/dev/null)
                if [ ! -z "$pid" ]; then
                    print_info "Killing process on port $port (PID: $pid)..."
                    kill -9 $pid 2>/dev/null || true
                fi
            done

            sleep 1

            # Check again
            ports_in_use=false
            for port in $port_details; do
                if lsof -Pi :$port -sTCP:LISTEN -t >/dev/null 2>&1 ; then
                    ports_in_use=true
                    break
                fi
            done

            if [ "$ports_in_use" = false ]; then
                print_success "All ports are now available"
            else
                print_error "Failed to free all ports. Please manually stop the processes."
                echo ""
                echo "Use these commands:"
                echo "  lsof -i :3000    # Find process on port 3000"
                echo "  lsof -i :5432    # Find process on port 5432"
                echo "  lsof -i :8880    # Find process on port 8880"
                echo "  kill -9 <PID>    # Stop the process"
                echo ""
                echo "Or run: ./clean.sh"
                exit 1
            fi
        else
            print_error "Cannot start with ports in use."
            echo ""
            echo "Run './clean.sh' to clean up, or manually free the ports:"
            echo "  lsof -i :3000    # Find process on port 3000"
            echo "  lsof -i :5432    # Find process on port 5432"
            echo "  lsof -i :8880    # Find process on port 8880"
            echo "  kill -9 <PID>    # Stop the process"
            exit 1
        fi
    else
        print_success "All required ports are available"
    fi
}

# Function to check if .env file exists
check_env() {
    print_info "Checking environment configuration..."

    if [ ! -f ".env" ]; then
        print_warning ".env file not found. Creating from .env.example..."
        cp .env.example .env
        print_success "Created .env file"
        print_warning "Please review and update .env file with your configuration"
    else
        print_success "Found .env file"
    fi
}

# Function to start services
start_services() {
    print_info "Starting services with Docker Compose..."
    echo ""

    docker compose up -d

    echo ""
    print_success "Services started successfully"
}

# Function to wait for services to be ready
wait_for_services() {
    print_info "Waiting for services to be ready..."

    # Wait for PostgreSQL
    print_info "Waiting for PostgreSQL..."
    local postgres_ready=false
    local attempts=0
    local max_attempts=30

    while [ $attempts -lt $max_attempts ]; do
        if docker compose exec -T postgres pg_isready -U keycloak > /dev/null 2>&1; then
            postgres_ready=true
            break
        fi
        sleep 2
        attempts=$((attempts + 1))
        echo -n "."
    done

    echo ""

    if [ "$postgres_ready" = true ]; then
        print_success "PostgreSQL is ready"
    else
        print_warning "PostgreSQL is taking longer than expected. Check logs with: docker compose logs postgres"
    fi

    # Wait for Keycloak
    print_info "Waiting for Keycloak (this may take 30-60 seconds)..."
    local keycloak_ready=false
    attempts=0
    max_attempts=60

    while [ $attempts -lt $max_attempts ]; do
        if curl -f -s http://localhost:8880/realms/vdsp-demo/.well-known/openid-configuration > /dev/null 2>&1; then
            keycloak_ready=true
            break
        fi
        sleep 2
        attempts=$((attempts + 1))
        echo -n "."
    done

    echo ""

    if [ "$keycloak_ready" = true ]; then
        print_success "Keycloak is ready"
    else
        print_warning "Keycloak is taking longer than expected. Check logs with: docker-compose logs keycloak"
    fi

    # Wait for Demo App
    print_info "Waiting for Demo App..."
    local app_ready=false
    attempts=0
    max_attempts=30

    while [ $attempts -lt $max_attempts ]; do
        if curl -f -s http://localhost:3000/health > /dev/null 2>&1; then
            app_ready=true
            break
        fi
        sleep 2
        attempts=$((attempts + 1))
        echo -n "."
    done

    echo ""

    if [ "$app_ready" = true ]; then
        print_success "Demo App is ready"
    else
        print_warning "Demo App is taking longer than expected. Check logs with: docker compose logs demo-app"
    fi
}

# Function to display service URLs
show_urls() {
    echo ""
    echo "═══════════════════════════════════════════════════════════════"
    echo -e "${GREEN}🚀 Keycloak Demo is ready!${NC}"
    echo "═══════════════════════════════════════════════════════════════"
    echo ""
    echo -e "${BLUE}Demo Application:${NC}"
    echo "  🌐 http://localhost:3000"
    echo ""
    echo -e "${BLUE}Keycloak Admin Console:${NC}"
    echo "  🔐 http://localhost:8880/admin"
    echo "     Username: admin"
    echo "     Password: admin"
    echo ""
    echo -e "${BLUE}Test Users:${NC}"
    echo "  👤 testuser / password"
    echo "  👤 admin / admin"
    echo ""
    echo -e "${BLUE}Useful Commands:${NC}"
    echo "  View logs:        docker compose logs -f"
    echo "  Stop services:    docker compose down"
    echo "  Clean & restart:  ./clean.sh"
    echo "  Restart services: docker compose restart"
    echo "  Service status:   docker compose ps"
    echo ""
    echo "═══════════════════════════════════════════════════════════════"
}

# Function to show status of services
show_status() {
    print_info "Service Status:"
    echo ""
    docker compose ps
}

# Main script
main() {
    echo ""
    echo "═══════════════════════════════════════════════════════════════"
    echo -e "${GREEN}  Keycloak Demo - Startup Script${NC}"
    echo "═══════════════════════════════════════════════════════════════"
    echo ""

    # Perform checks
    check_docker
    check_ports
    check_env

    echo ""
    read -p "Ready to start services? (y/n) " -n 1 -r
    echo ""

    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        print_info "Startup cancelled"
        exit 0
    fi

    # Start services
    start_services

    # Wait for services
    wait_for_services

    # Show status
    show_status

    # Display URLs
    show_urls
}

# Run main function
main
