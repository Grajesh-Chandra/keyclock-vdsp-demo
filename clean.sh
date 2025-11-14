#!/bin/bash

# Keycloak Demo Cleanup Script
# This script helps you clean up and reset the Keycloak demo environment

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

# Function to show cleanup options
show_menu() {
    echo ""
    echo "════════════════════════════════════════════════════════════════"
    echo -e "${GREEN}  Keycloak Demo - Cleanup Script${NC}"
    echo "════════════════════════════════════════════════════════════════"
    echo ""
    echo "Choose cleanup option:"
    echo ""
    echo "  1) Soft cleanup - Stop containers (keep data)"
    echo "  2) Full cleanup - Stop containers and remove volumes (reset everything)"
    echo "  3) Clean rebuild - Full cleanup + rebuild images"
    echo "  4) Cancel"
    echo ""
}

# Function to check and clean ports
check_and_clean_ports() {
    print_info "Checking for processes using demo ports..."

    local ports=(3000 5432 8880)
    local pids_found=false

    for port in "${ports[@]}"; do
        local pid=$(lsof -ti :$port 2>/dev/null)
        if [ ! -z "$pid" ]; then
            local process_name=$(ps -p $pid -o comm= 2>/dev/null || echo "unknown")
            print_warning "Port $port is in use by process $pid ($process_name)"
            pids_found=true
        fi
    done

    if [ "$pids_found" = false ]; then
        print_success "All ports are free"
    else
        echo ""
        read -p "Kill processes using these ports? (y/n) " -n 1 -r
        echo ""

        if [[ $REPLY =~ ^[Yy]$ ]]; then
            for port in "${ports[@]}"; do
                local pid=$(lsof -ti :$port 2>/dev/null)
                if [ ! -z "$pid" ]; then
                    kill -9 $pid 2>/dev/null && print_success "Killed process on port $port (PID: $pid)" || true
                fi
            done
        else
            print_info "Skipped killing processes"
        fi
    fi
}

# Function to stop containers
stop_containers() {
    print_info "Stopping containers..."
    docker compose down
    print_success "Containers stopped"

    # Check ports after stopping containers
    check_and_clean_ports
}

# Function to remove volumes
remove_volumes() {
    print_info "Removing volumes (this will delete all data)..."
    docker compose down -v
    print_success "Volumes removed"
}

# Function to remove images
remove_images() {
    print_info "Removing demo-app image..."
    docker rmi keyclock-vdsp-demo-demo-app 2>/dev/null || true
    print_success "Images cleaned"
}

# Function to rebuild
rebuild() {
    print_info "Rebuilding containers..."
    docker compose build --no-cache
    print_success "Containers rebuilt"
}

# Function to start services
start_services() {
    print_info "Starting services..."
    docker compose up -d
    print_success "Services started"
    echo ""
    print_info "Waiting for services to initialize (this may take 30-60 seconds)..."
    sleep 5
    echo ""
    print_success "Services are starting. Check status with: docker compose ps"
    echo ""
    echo -e "${BLUE}Access the demo:${NC}"
    echo "  🌐 Demo App: http://localhost:3000"
    echo "  🔐 Keycloak Admin: http://localhost:8880/admin (admin/admin)"
}

# Soft cleanup
soft_cleanup() {
    echo ""
    print_warning "This will stop all containers but keep the data."
    read -p "Continue? (y/n) " -n 1 -r
    echo ""

    if [[ $REPLY =~ ^[Yy]$ ]]; then
        stop_containers
        echo ""
        print_success "Soft cleanup completed"
        echo ""
        print_info "To start again, run: ./start.sh"
    else
        print_info "Cancelled"
    fi
}

# Full cleanup
full_cleanup() {
    echo ""
    print_warning "This will stop all containers and DELETE ALL DATA (PostgreSQL, Keycloak config, etc.)"
    print_warning "The demo will be reset to initial state."
    echo ""
    read -p "Are you sure? (y/n) " -n 1 -r
    echo ""

    if [[ $REPLY =~ ^[Yy]$ ]]; then
        remove_volumes
        check_and_clean_ports
        echo ""
        print_success "Full cleanup completed"
        echo ""
        print_info "To start fresh, run: ./start.sh"
    else
        print_info "Cancelled"
    fi
}

# Clean rebuild
clean_rebuild() {
    echo ""
    print_warning "This will:"
    echo "  - Stop all containers"
    echo "  - DELETE ALL DATA (PostgreSQL, Keycloak config, etc.)"
    echo "  - Remove and rebuild Docker images"
    echo "  - Start fresh containers"
    echo ""
    read -p "Are you sure? (y/n) " -n 1 -r
    echo ""

    if [[ $REPLY =~ ^[Yy]$ ]]; then
        remove_volumes
        check_and_clean_ports
        remove_images
        rebuild
        start_services
        echo ""
        print_success "Clean rebuild completed!"
    else
        print_info "Cancelled"
    fi
}

# Main script
main() {
    show_menu

    read -p "Enter choice [1-4]: " choice

    case $choice in
        1)
            soft_cleanup
            ;;
        2)
            full_cleanup
            ;;
        3)
            clean_rebuild
            ;;
        4)
            print_info "Cancelled"
            exit 0
            ;;
        *)
            print_error "Invalid option"
            exit 1
            ;;
    esac
}

# Run main function
main
