#!/bin/bash

# ==============================================================================
# N8N AI STACK STARTUP SCRIPT
# ==============================================================================
#
# PURPOSE:
#   Validates configuration and starts the n8n AI workflow automation stack
#   with PostgreSQL and Ollama. Supports both development and production
#   environments with automatic GPU detection and model management.
#
# REQUIREMENTS:
#   - Docker and Docker Compose installed and running
#   - Valid .env file with required configuration
#   - Sufficient system resources (4GB+ RAM recommended)
#   - Optional: NVIDIA GPU and drivers for GPU acceleration
#
# CONFIGURATION:
#   Environment variables (from .env file):
#   - POSTGRES_PASSWORD: PostgreSQL admin password
#   - POSTGRES_NON_ROOT_PASSWORD: n8n database user password
#   - N8N_ENCRYPTION_KEY: 32+ character encryption key
#   - N8N_JWT_SECRET: JWT signing secret
#   - COMPOSE_PROJECT_NAME: Container name prefix
#
# USAGE:
#   ./scripts/start.sh [OPTIONS]
#
# OPTIONS:
#   -e, --env ENV          Environment mode (development|production)
#   -m, --models           Install default AI models after startup
#   -g, --gpu              Force enable GPU acceleration
#   -h, --help             Show help message
#
# EXAMPLES:
#   # Start development environment (default)
#   ./scripts/start.sh
#
#   # Start development with AI models auto-installation
#   ./scripts/start.sh -m
#
#   # Start with GPU acceleration (auto-detected if available)
#   ./scripts/start.sh -g
#
#   # Start production environment with SSL and security hardening
#   ./scripts/start.sh -e production
#
#   # Production with GPU and model installation
#   ./scripts/start.sh -e production -g -m
#
# ENVIRONMENTS:
#   Development:
#   - Includes PgAdmin for database management
#   - Exposed PostgreSQL port for direct access
#   - Debug logging and relaxed security
#   - Lower resource limits for local development
#
#   Production:
#   - Traefik reverse proxy with SSL termination
#   - Enhanced security with read-only filesystems
#   - Higher resource limits and health monitoring
#   - No direct database access or debugging tools
#
# ACCESS URLS:
#   Development:
#   - n8n: http://localhost:5678
#   - PgAdmin: http://localhost:5050 (admin@n8n.local / admin123)
#   - Ollama API: http://localhost:11434
#
#   Production:
#   - n8n: https://[your-domain] (via Traefik SSL)
#   - Ollama API: http://localhost:11434 (internal)
#
# AUTOMATIC FEATURES:
#   - Prerequisites validation (Docker, Compose)
#   - Environment configuration validation
#   - Required directory creation
#   - GPU detection and configuration
#   - Service health monitoring
#   - Optional AI model installation
#
# EXIT CODES:
#   0: Success
#   1: Error (missing prerequisites, invalid config, startup failure)
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

# Default values
ENVIRONMENT="development"
PROFILES=""
PULL_MODELS=false
GPU_ENABLED=false

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to check if required tools are installed
check_prerequisites() {
    print_status "Checking prerequisites..."

    if ! command -v docker &> /dev/null; then
        print_error "Docker is not installed. Please install Docker first."
        exit 1
    fi

    if ! command -v docker-compose &> /dev/null && ! docker compose version &> /dev/null; then
        print_error "Docker Compose is not installed. Please install Docker Compose first."
        exit 1
    fi

    # Check Docker daemon
    if ! docker info &> /dev/null; then
        print_error "Docker daemon is not running. Please start Docker first."
        exit 1
    fi

    print_success "Prerequisites check passed"
}

# Function to validate environment file
validate_env() {
    print_status "Validating environment configuration..."

    if [ ! -f "$ENV_FILE" ]; then
        print_error ".env file not found. Creating from template..."
        cp "$PROJECT_ROOT/.env.example" "$ENV_FILE"
        print_warning "Please edit .env file with your configuration before continuing."
        exit 1
    fi

    # Source the environment file
    source "$ENV_FILE"

    # Check required variables
    local required_vars=(
        "POSTGRES_PASSWORD"
        "POSTGRES_NON_ROOT_PASSWORD"
        "N8N_ENCRYPTION_KEY"
        "N8N_JWT_SECRET"
    )

    local missing_vars=()
    for var in "${required_vars[@]}"; do
        if [ -z "${!var}" ] || [[ "${!var}" == *"your_"* ]]; then
            missing_vars+=("$var")
        fi
    done

    if [ ${#missing_vars[@]} -ne 0 ]; then
        print_error "Missing or invalid required environment variables:"
        for var in "${missing_vars[@]}"; do
            echo "  - $var"
        done
        print_warning "Please update your .env file with secure values."
        exit 1
    fi

    # Validate encryption key length
    if [ ${#N8N_ENCRYPTION_KEY} -lt 32 ]; then
        print_error "N8N_ENCRYPTION_KEY must be at least 32 characters long."
        print_warning "Generate one with: openssl rand -base64 32"
        exit 1
    fi

    print_success "Environment validation passed"
}

# Function to create required directories
create_directories() {
    print_status "Creating required directories..."

    local dirs=(
        "${N8N_CUSTOM_NODES_PATH:-./custom-nodes}"
        "${N8N_BACKUPS_PATH:-./backups}"
        "${N8N_LOGS_PATH:-./logs}"
    )

    if [ "$ENVIRONMENT" = "production" ]; then
        dirs+=(
            "${POSTGRES_DATA_PATH:-./data/postgres}"
            "${OLLAMA_DATA_PATH:-./data/ollama}"
            "${N8N_DATA_PATH:-./data/n8n}"
        )
    fi

    for dir in "${dirs[@]}"; do
        mkdir -p "$dir"
        print_status "Created directory: $dir"
    done

    print_success "Directories created"
}

# Function to check GPU availability
check_gpu() {
    if command -v nvidia-smi &> /dev/null; then
        if nvidia-smi &> /dev/null; then
            print_success "NVIDIA GPU detected and available"
            GPU_ENABLED=true
            PROFILES="gpu"
        else
            print_warning "NVIDIA GPU detected but not accessible"
        fi
    else
        print_warning "No NVIDIA GPU detected"
    fi
}

# Function to start services
start_services() {
    print_status "Starting N8N AI Stack in $ENVIRONMENT mode..."

    cd "$PROJECT_ROOT"

    # Build compose command
    local compose_cmd="docker-compose -f docker-compose.yml"

    if [ "$ENVIRONMENT" = "development" ]; then
        compose_cmd="$compose_cmd -f docker-compose.dev.yml"
    elif [ "$ENVIRONMENT" = "production" ]; then
        compose_cmd="$compose_cmd -f docker-compose.prod.yml"
        PROFILES="production${PROFILES:+,$PROFILES}"
    fi

    if [ -n "$PROFILES" ]; then
        for profile in $(echo "$PROFILES" | tr ',' ' '); do
            compose_cmd="$compose_cmd --profile $profile"
        done
    fi

    compose_cmd="$compose_cmd up -d"

    print_status "Running: $compose_cmd"
    eval $compose_cmd

    print_success "Services started successfully!"
}

# Function to wait for services to be healthy
wait_for_services() {
    print_status "Waiting for services to be healthy..."

    local max_attempts=30
    local attempt=0

    while [ $attempt -lt $max_attempts ]; do
        if docker-compose ps | grep -q "healthy"; then
            if docker-compose ps | grep -q "unhealthy"; then
                print_warning "Some services are still starting..."
            else
                print_success "All services are healthy!"
                return 0
            fi
        fi

        sleep 10
        attempt=$((attempt + 1))
        echo -n "."
    done

    print_warning "Services may still be starting. Check with: docker-compose ps"
}

# Function to pull and setup Ollama models
setup_models() {
    if [ "$PULL_MODELS" = true ]; then
        print_status "Setting up Ollama models..."

        local models=("llama2" "codellama" "mistral" "phi")

        for model in "${models[@]}"; do
            print_status "Pulling model: $model"
            docker exec "${COMPOSE_PROJECT_NAME:-n8n-ai-stack}_ollama" ollama pull "$model" || true
        done

        print_success "Model setup completed"
    fi
}

# Function to display connection information
show_connection_info() {
    print_success "N8N AI Stack is running!"
    echo
    echo "🌐 Connection Information:"
    echo "  N8N Web Interface: http://localhost:${N8N_EXTERNAL_PORT:-5678}"

    if [ "$ENVIRONMENT" = "development" ]; then
        echo "  PgAdmin: http://localhost:${PGADMIN_PORT:-5050}"
        echo "    Email: ${PGADMIN_EMAIL:-admin@n8n.local}"
        echo "    Password: ${PGADMIN_PASSWORD:-admin123}"
    fi

    echo "  Ollama API: http://localhost:${OLLAMA_EXTERNAL_PORT:-11434}"
    echo
    echo "📊 Management Commands:"
    echo "  Check status: docker-compose ps"
    echo "  View logs: docker-compose logs -f"
    echo "  Stop stack: docker-compose down"
    echo
    echo "🤖 Ollama Management:"
    echo "  List models: docker exec ${COMPOSE_PROJECT_NAME:-n8n-ai-stack}_ollama ollama list"
    echo "  Pull model: docker exec ${COMPOSE_PROJECT_NAME:-n8n-ai-stack}_ollama ollama pull <model>"
}

# Function to show help
show_help() {
    echo "N8N AI Stack Startup Script"
    echo
    echo "Usage: $0 [OPTIONS]"
    echo
    echo "Options:"
    echo "  -e, --env ENV          Environment: development (default) or production"
    echo "  -m, --models           Pull default Ollama models after startup"
    echo "  -g, --gpu              Force enable GPU profile (auto-detected by default)"
    echo "  -h, --help             Show this help message"
    echo
    echo "Examples:"
    echo "  $0                     Start in development mode"
    echo "  $0 -e production       Start in production mode"
    echo "  $0 -m                  Start and pull Ollama models"
    echo "  $0 -e production -g    Start in production with GPU"
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -e|--env)
            ENVIRONMENT="$2"
            shift 2
            ;;
        -m|--models)
            PULL_MODELS=true
            shift
            ;;
        -g|--gpu)
            GPU_ENABLED=true
            PROFILES="gpu"
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

# Validate environment argument
if [ "$ENVIRONMENT" != "development" ] && [ "$ENVIRONMENT" != "production" ]; then
    print_error "Invalid environment: $ENVIRONMENT. Must be 'development' or 'production'"
    exit 1
fi

# Main execution
main() {
    echo "🚀 N8N AI Stack Startup"
    echo "======================="
    echo

    check_prerequisites
    validate_env
    create_directories

    if [ "$ENVIRONMENT" = "production" ] || [ "$GPU_ENABLED" = true ]; then
        check_gpu
    fi

    start_services
    wait_for_services
    setup_models
    show_connection_info
}

# Run main function
main "$@"