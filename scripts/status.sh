#!/bin/bash

# ==============================================================================
# N8N AI STACK STATUS AND HEALTH CHECK SCRIPT
# ==============================================================================
#
# PURPOSE:
#   Comprehensive health monitoring and status reporting for the n8n AI workflow
#   automation stack. Checks service health, connectivity, resource usage, and
#   provides management command shortcuts.
#
# REQUIREMENTS:
#   - Docker and Docker Compose running
#   - Stack must be started with ./scripts/start.sh
#   - Optional: curl and netcat for connectivity tests
#
# CONFIGURATION:
#   Environment variables (from .env file):
#   - COMPOSE_PROJECT_NAME: Container name prefix (default: n8n-ai-stack)
#   - N8N_EXTERNAL_PORT: n8n web interface port (default: 5678)
#   - OLLAMA_EXTERNAL_PORT: Ollama API port (default: 11434)
#   - POSTGRES_EXTERNAL_PORT: PostgreSQL port (default: 5432)
#
# USAGE:
#   ./scripts/status.sh [OPTIONS]
#
# OPTIONS:
#   -s, --services         Show service health status only
#   -r, --resources        Show resource usage and statistics only
#   -m, --models           Show installed Ollama models only
#   -n, --network          Show Docker network information only
#   -c, --config           Show configuration summary only
#   -l, --logs [SERVICE]   Show recent logs (optionally for specific service)
#   -q, --quick            Show quick management commands only
#   -h, --help             Show help message
#
# EXAMPLES:
#   # Complete health check (default)
#   ./scripts/status.sh
#
#   # Check only service health
#   ./scripts/status.sh -s
#
#   # Show resource usage and container statistics
#   ./scripts/status.sh -r
#
#   # List installed AI models
#   ./scripts/status.sh -m
#
#   # Show recent logs for specific service
#   ./scripts/status.sh -l n8n
#   ./scripts/status.sh -l postgres
#
#   # Show configuration summary
#   ./scripts/status.sh -c
#
#   # Quick management commands reference
#   ./scripts/status.sh -q
#
# HEALTH CHECKS:
#   Service Status:
#   - Container running state
#   - Docker health check status (healthy/unhealthy/starting)
#   - Service-specific connectivity tests
#
#   Connectivity Tests:
#   - n8n web interface accessibility (HTTP /healthz endpoint)
#   - Ollama API accessibility (HTTP /api/version endpoint)
#   - PostgreSQL port accessibility (if externally exposed)
#
#   Resource Monitoring:
#   - Container CPU and memory usage
#   - Disk usage for data directories
#   - Docker volume information
#
# OUTPUT INFORMATION:
#   - Service health status with visual indicators (✓/⚠/✗)
#   - Container resource usage statistics
#   - Installed Ollama models and sizes
#   - Network configuration and container IPs
#   - Access URLs for all services
#   - Quick command reference for common tasks
#
# EXIT CODES:
#   0: Success (all checks completed)
#   1: Error (invalid options, Docker not accessible)
#
# ==============================================================================

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
ENV_FILE="$PROJECT_ROOT/.env"

# Load environment variables
if [ -f "$ENV_FILE" ]; then
    source "$ENV_FILE"
fi

COMPOSE_PROJECT_NAME=${COMPOSE_PROJECT_NAME:-n8n-ai-stack}

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[✓]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[⚠]${NC} $1"
}

print_error() {
    echo -e "${RED}[✗]${NC} $1"
}

# Function to check service health
check_service_health() {
    local service=$1
    local container="${COMPOSE_PROJECT_NAME}_${service}"

    if docker ps --format "table {{.Names}}" | grep -q "^${container}$"; then
        local health=$(docker inspect --format='{{.State.Health.Status}}' "$container" 2>/dev/null)
        local status=$(docker inspect --format='{{.State.Status}}' "$container" 2>/dev/null)

        if [ "$status" = "running" ]; then
            if [ "$health" = "healthy" ]; then
                print_success "$service is running and healthy"
                return 0
            elif [ "$health" = "unhealthy" ]; then
                print_error "$service is running but unhealthy"
                return 1
            elif [ "$health" = "starting" ]; then
                print_warning "$service is starting (health check in progress)"
                return 2
            else
                print_success "$service is running (no health check configured)"
                return 0
            fi
        else
            print_error "$service container exists but is not running (status: $status)"
            return 1
        fi
    else
        print_error "$service container not found"
        return 1
    fi
}

# Function to check service connectivity
check_connectivity() {
    print_status "Checking service connectivity..."

    # Check n8n
    if curl -s --connect-timeout 5 "http://localhost:${N8N_EXTERNAL_PORT:-5678}/healthz" >/dev/null; then
        print_success "n8n web interface is accessible"
    else
        print_error "n8n web interface is not accessible"
    fi

    # Check Ollama
    if curl -s --connect-timeout 5 "http://localhost:${OLLAMA_EXTERNAL_PORT:-11434}/api/version" >/dev/null; then
        print_success "Ollama API is accessible"
    else
        print_error "Ollama API is not accessible"
    fi

    # Check PostgreSQL (if exposed)
    if [ "${POSTGRES_EXTERNAL_PORT:-5432}" != "5432" ] || netstat -ln 2>/dev/null | grep -q ":${POSTGRES_EXTERNAL_PORT:-5432} "; then
        if nc -z localhost "${POSTGRES_EXTERNAL_PORT:-5432}" 2>/dev/null; then
            print_success "PostgreSQL is accessible"
        else
            print_warning "PostgreSQL is not accessible externally (this may be intentional)"
        fi
    fi
}

# Function to show resource usage
show_resource_usage() {
    print_status "Resource usage:"
    echo

    # Get container stats
    if command -v docker &> /dev/null; then
        echo "Container Resource Usage:"
        docker stats --no-stream --format "table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.MemPerc}}" \
            $(docker ps --filter "name=${COMPOSE_PROJECT_NAME}" --format "{{.Names}}") 2>/dev/null || \
            print_warning "Could not retrieve container stats"
        echo
    fi

    # Show disk usage
    echo "Disk Usage:"
    du -sh "${N8N_BACKUPS_PATH:-./backups}" "${N8N_LOGS_PATH:-./logs}" "${N8N_CUSTOM_NODES_PATH:-./custom-nodes}" 2>/dev/null | head -10 || true
    echo

    # Docker volumes
    echo "Docker Volumes:"
    docker volume ls --filter "name=${COMPOSE_PROJECT_NAME}" --format "table {{.Name}}\t{{.Driver}}" 2>/dev/null || true
}

# Function to show installed models
show_models() {
    print_status "Installed Ollama models:"
    echo

    if docker exec "${COMPOSE_PROJECT_NAME}_ollama" ollama list 2>/dev/null; then
        echo
    else
        print_warning "Could not retrieve model list (Ollama may not be running)"
    fi
}

# Function to show recent logs
show_recent_logs() {
    local service=${1:-}
    local lines=${2:-20}

    if [ -n "$service" ]; then
        print_status "Recent logs for $service (last $lines lines):"
        docker-compose logs --tail="$lines" "$service" 2>/dev/null || \
            print_error "Could not retrieve logs for $service"
    else
        print_status "Recent logs for all services (last $lines lines):"
        docker-compose logs --tail="$lines" 2>/dev/null || \
            print_error "Could not retrieve logs"
    fi
}

# Function to show network information
show_network_info() {
    print_status "Network information:"
    echo

    local network_name="${NETWORK_NAME:-n8n-network}"

    if docker network ls | grep -q "$network_name"; then
        print_success "Network '$network_name' exists"

        echo "Connected containers:"
        docker network inspect "$network_name" --format '{{range .Containers}}{{.Name}} ({{.IPv4Address}}){{"\n"}}{{end}}' 2>/dev/null || true
    else
        print_warning "Network '$network_name' not found"
    fi
    echo
}

# Function to show configuration summary
show_config_summary() {
    print_status "Configuration summary:"
    echo

    cat << EOF
Project Name: ${COMPOSE_PROJECT_NAME}
Environment File: $([ -f "$ENV_FILE" ] && echo "Found" || echo "Missing")
Network: ${NETWORK_NAME:-n8n-network}

Service Ports:
  n8n: ${N8N_EXTERNAL_PORT:-5678}
  Ollama: ${OLLAMA_EXTERNAL_PORT:-11434}
  PostgreSQL: ${POSTGRES_EXTERNAL_PORT:-5432}

Resource Limits:
  n8n Memory: ${N8N_MEMORY_LIMIT:-2G}
  Ollama Memory: ${OLLAMA_MEMORY_LIMIT:-8G}
  PostgreSQL Memory: ${POSTGRES_MEMORY_LIMIT:-1G}

Volume Paths:
  Custom Nodes: ${N8N_CUSTOM_NODES_PATH:-./custom-nodes}
  Backups: ${N8N_BACKUPS_PATH:-./backups}
  Logs: ${N8N_LOGS_PATH:-./logs}
EOF
    echo
}

# Function to show quick commands
show_quick_commands() {
    print_status "Quick management commands:"
    echo

    cat << EOF
🔧 Management:
  ./scripts/start.sh                    # Start development stack
  ./scripts/start.sh -e production      # Start production stack
  ./scripts/validate.sh                 # Validate configuration
  docker-compose ps                     # Check service status
  docker-compose logs -f                # Follow all logs
  docker-compose down                   # Stop all services

🤖 AI Models:
  ./scripts/manage-models.sh list       # List installed models
  ./scripts/manage-models.sh pull llama2    # Install a model
  ./scripts/manage-models.sh recommended     # Install recommended models

💾 Data Management:
  ./scripts/backup.sh                   # Create database backup
  docker-compose logs postgres          # Check database logs
  docker volume ls                      # List data volumes

📊 Monitoring:
  ./scripts/status.sh                   # This script
  ./scripts/status.sh -l n8n           # Show n8n logs
  docker stats                         # Real-time resource usage
EOF
}

# Function to show help
show_help() {
    echo "N8N AI Stack Status Check"
    echo
    echo "Usage: $0 [OPTIONS]"
    echo
    echo "Options:"
    echo "  -s, --services         Show service health only"
    echo "  -r, --resources        Show resource usage only"
    echo "  -m, --models           Show installed models only"
    echo "  -n, --network          Show network information only"
    echo "  -c, --config           Show configuration summary only"
    echo "  -l, --logs [SERVICE]   Show recent logs (optionally for specific service)"
    echo "  -q, --quick            Show quick commands only"
    echo "  -h, --help             Show this help message"
    echo
    echo "Examples:"
    echo "  $0                     # Full status check"
    echo "  $0 -s                  # Service health only"
    echo "  $0 -l n8n             # Recent n8n logs"
    echo "  $0 -r                  # Resource usage only"
}

# Main function
main() {
    echo "📊 N8N AI Stack Status"
    echo "====================="
    echo

    cd "$PROJECT_ROOT"

    local show_services=true
    local show_connectivity=true
    local show_resources=false
    local show_models=false
    local show_network=false
    local show_config=false
    local show_logs=""
    local show_quick=false

    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -s|--services)
                show_services=true
                show_connectivity=false
                show_resources=false
                show_models=false
                show_network=false
                show_config=false
                show_quick=false
                shift
                ;;
            -r|--resources)
                show_services=false
                show_connectivity=false
                show_resources=true
                show_models=false
                show_network=false
                show_config=false
                show_quick=false
                shift
                ;;
            -m|--models)
                show_services=false
                show_connectivity=false
                show_resources=false
                show_models=true
                show_network=false
                show_config=false
                show_quick=false
                shift
                ;;
            -n|--network)
                show_services=false
                show_connectivity=false
                show_resources=false
                show_models=false
                show_network=true
                show_config=false
                show_quick=false
                shift
                ;;
            -c|--config)
                show_services=false
                show_connectivity=false
                show_resources=false
                show_models=false
                show_network=false
                show_config=true
                show_quick=false
                shift
                ;;
            -l|--logs)
                show_services=false
                show_connectivity=false
                show_resources=false
                show_models=false
                show_network=false
                show_config=false
                show_quick=false
                show_logs="${2:-}"
                shift
                if [[ $# -gt 0 && ! $1 =~ ^- ]]; then
                    shift
                fi
                ;;
            -q|--quick)
                show_services=false
                show_connectivity=false
                show_resources=false
                show_models=false
                show_network=false
                show_config=false
                show_quick=true
                shift
                ;;
            -h|--help)
                show_help
                exit 0
                ;;
            *)
                print_error "Unknown option: $1"
                show_help
                exit 1
                ;;
        esac
    done

    # Show requested information
    if [ "$show_config" = true ]; then
        show_config_summary
    fi

    if [ "$show_services" = true ]; then
        print_status "Checking service health..."
        check_service_health "postgres"
        check_service_health "ollama"
        check_service_health "n8n"

        # Check optional services
        if docker ps --format "table {{.Names}}" | grep -q "${COMPOSE_PROJECT_NAME}_traefik"; then
            check_service_health "traefik"
        fi

        if docker ps --format "table {{.Names}}" | grep -q "${COMPOSE_PROJECT_NAME}_pgadmin"; then
            check_service_health "pgadmin"
        fi
        echo
    fi

    if [ "$show_connectivity" = true ]; then
        check_connectivity
        echo
    fi

    if [ "$show_resources" = true ]; then
        show_resource_usage
    fi

    if [ "$show_models" = true ]; then
        show_models
    fi

    if [ "$show_network" = true ]; then
        show_network_info
    fi

    if [ -n "$show_logs" ]; then
        show_recent_logs "$show_logs"
    fi

    if [ "$show_quick" = true ]; then
        show_quick_commands
    fi

    # Show default full status if no specific options
    if [ "$show_services" = true ] && [ "$show_connectivity" = true ]; then
        print_status "✅ Status check complete!"
        echo
        print_status "Access your services:"
        echo "  🌐 n8n: http://localhost:${N8N_EXTERNAL_PORT:-5678}"
        echo "  🤖 Ollama: http://localhost:${OLLAMA_EXTERNAL_PORT:-11434}"
        if docker ps --format "table {{.Names}}" | grep -q "${COMPOSE_PROJECT_NAME}_pgadmin"; then
            echo "  🗄️  PgAdmin: http://localhost:${PGADMIN_PORT:-5050}"
        fi
        echo
        print_status "For detailed information, use:"
        echo "  $0 -r    # Resource usage"
        echo "  $0 -m    # Installed models"
        echo "  $0 -q    # Quick commands"
    fi
}

# Run main function
main "$@"