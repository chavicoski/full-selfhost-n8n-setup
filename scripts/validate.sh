#!/bin/bash

# ==============================================================================
# N8N AI STACK CONFIGURATION VALIDATOR
# ==============================================================================
#
# PURPOSE:
#   Comprehensive validation of system requirements, configuration, and setup
#   for the n8n AI workflow automation stack. Performs pre-flight checks to
#   ensure successful deployment and operation.
#
# REQUIREMENTS:
#   - Basic system utilities (df, free, ping, curl)
#   - Docker and Docker Compose access
#   - Read access to project files and configuration
#
# CONFIGURATION:
#   Environment variables (from .env file):
#   - All variables are validated for completeness and security
#   - No external configuration required - uses project structure
#
# USAGE:
#   ./scripts/validate.sh
#
# VALIDATION CHECKS:
#   System Requirements:
#   - Docker installation and daemon status
#   - Docker Compose availability and version
#   - System memory (minimum 2GB, recommended 4GB+)
#   - Available disk space (minimum 5GB, recommended 10GB+)
#   - NVIDIA GPU availability and Docker runtime configuration
#
#   Configuration Validation:
#   - .env file existence and completeness
#   - Required environment variables and security settings
#   - Encryption key length validation (32+ characters)
#   - Port availability and conflict detection
#   - Placeholder value detection and warnings
#
#   File System Checks:
#   - Project file existence and readability
#   - Script executability permissions
#   - Required and optional directory structure
#   - Docker Compose file syntax validation
#
#   Network Connectivity:
#   - Internet connectivity for image downloads
#   - Docker Hub accessibility for base images
#   - DNS resolution functionality
#
# EXAMPLES:
#   # Run complete validation (recommended before first start)
#   ./scripts/validate.sh
#
#   # Typical workflow
#   ./scripts/generate-env.sh    # Generate secure configuration
#   ./scripts/validate.sh        # Validate setup
#   ./scripts/start.sh           # Start stack if validation passes
#
# OUTPUT INFORMATION:
#   - Detailed check results with visual indicators (✓/⚠/✗)
#   - System resource information and recommendations
#   - Configuration issues and solutions
#   - Security warnings and best practices
#   - Next steps and command suggestions
#
# VALIDATION CATEGORIES:
#   ✅ Pass: Requirement met, no action needed
#   ⚠️  Warning: Non-critical issue, may impact performance
#   ❌ Error: Critical issue, must be fixed before deployment
#
# COMMON ISSUES AND SOLUTIONS:
#   Missing .env file:
#   - Run: cp .env.example .env
#   - Or: ./scripts/generate-env.sh
#
#   Placeholder values in configuration:
#   - Edit .env file with real values
#   - Or: ./scripts/generate-env.sh -u
#
#   Port conflicts:
#   - Change port numbers in .env file
#   - Stop conflicting services
#
#   Insufficient resources:
#   - Close unnecessary applications
#   - Consider upgrading hardware
#
#   Permission issues:
#   - Run: chmod +x scripts/*.sh
#   - Check file ownership and permissions
#
# EXIT CODES:
#   0: All validation checks passed
#   1: One or more critical checks failed
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

# Counters
CHECKS_PASSED=0
CHECKS_FAILED=0
WARNINGS=0

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[✓]${NC} $1"
    ((CHECKS_PASSED++))
}

print_warning() {
    echo -e "${YELLOW}[⚠]${NC} $1"
    ((WARNINGS++))
}

print_error() {
    echo -e "${RED}[✗]${NC} $1"
    ((CHECKS_FAILED++))
}

print_check() {
    echo -e "${BLUE}[?]${NC} $1"
}

# Function to check if command exists
check_command() {
    if command -v "$1" &> /dev/null; then
        print_success "$1 is installed"
        return 0
    else
        print_error "$1 is not installed"
        return 1
    fi
}

# Function to check Docker requirements
check_docker() {
    print_status "Checking Docker installation..."

    check_command "docker"

    if docker info &> /dev/null; then
        print_success "Docker daemon is running"

        # Check Docker version
        local docker_version=$(docker --version | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)
        print_status "Docker version: $docker_version"

        # Check if version is recent enough (20.10+)
        if [[ "$(echo -e "20.10.0\n$docker_version" | sort -V | head -n1)" == "20.10.0" ]]; then
            print_success "Docker version is supported"
        else
            print_warning "Docker version may be too old (recommend 20.10+)"
        fi
    else
        print_error "Docker daemon is not running"
    fi

    # Check Docker Compose
    if docker compose version &> /dev/null; then
        print_success "Docker Compose (v2) is available"
        local compose_version=$(docker compose version --short)
        print_status "Docker Compose version: $compose_version"
    elif command -v docker-compose &> /dev/null; then
        print_success "Docker Compose (v1) is available"
        local compose_version=$(docker-compose --version | grep -oE '[0-9]+\.[0-9]+\.[0-9]+')
        print_status "Docker Compose version: $compose_version"
    else
        print_error "Docker Compose is not available"
    fi
}

# Function to check system resources
check_system_resources() {
    print_status "Checking system resources..."

    # Check available memory
    if command -v free &> /dev/null; then
        local total_mem=$(free -m | awk '/^Mem:/{print $2}')
        if [ "$total_mem" -ge 4096 ]; then
            print_success "Sufficient memory available (${total_mem}MB)"
        elif [ "$total_mem" -ge 2048 ]; then
            print_warning "Limited memory available (${total_mem}MB) - consider upgrading for better performance"
        else
            print_error "Insufficient memory (${total_mem}MB) - minimum 2GB recommended"
        fi
    else
        print_warning "Cannot check memory availability"
    fi

    # Check available disk space
    local available_space=$(df -m "$PROJECT_ROOT" | awk 'NR==2 {print $4}')
    if [ "$available_space" -ge 10240 ]; then
        print_success "Sufficient disk space available (${available_space}MB)"
    elif [ "$available_space" -ge 5120 ]; then
        print_warning "Limited disk space available (${available_space}MB) - monitor usage"
    else
        print_error "Insufficient disk space (${available_space}MB) - minimum 5GB recommended"
    fi
}

# Function to check GPU availability
check_gpu() {
    print_status "Checking GPU availability..."

    if command -v nvidia-smi &> /dev/null; then
        if nvidia-smi &> /dev/null; then
            print_success "NVIDIA GPU detected and accessible"

            # Check NVIDIA Docker runtime
            if docker info 2>/dev/null | grep -q nvidia; then
                print_success "NVIDIA Docker runtime is configured"
            else
                print_warning "NVIDIA Docker runtime not found - GPU acceleration unavailable"
            fi
        else
            print_warning "NVIDIA drivers not properly configured"
        fi
    else
        print_warning "No NVIDIA GPU detected (CPU-only mode)"
    fi
}

# Function to validate environment file
validate_environment() {
    print_status "Validating environment configuration..."

    if [ ! -f "$ENV_FILE" ]; then
        print_error ".env file not found"
        print_status "Run: cp .env.example .env"
        return 1
    fi

    source "$ENV_FILE"

    # Check required variables
    local required_vars=(
        "COMPOSE_PROJECT_NAME:Project name"
        "POSTGRES_PASSWORD:PostgreSQL password"
        "POSTGRES_NON_ROOT_PASSWORD:PostgreSQL n8n user password"
        "N8N_ENCRYPTION_KEY:n8n encryption key"
        "N8N_JWT_SECRET:n8n JWT secret"
    )

    for var_info in "${required_vars[@]}"; do
        IFS=':' read -r var_name var_desc <<< "$var_info"

        if [ -z "${!var_name}" ]; then
            print_error "$var_desc ($var_name) is not set"
        elif [[ "${!var_name}" == *"your_"* ]] || [[ "${!var_name}" == *"example"* ]]; then
            print_error "$var_desc ($var_name) has placeholder value"
        else
            print_success "$var_desc is configured"
        fi
    done

    # Validate encryption key length
    if [ -n "$N8N_ENCRYPTION_KEY" ] && [ ${#N8N_ENCRYPTION_KEY} -ge 32 ]; then
        print_success "N8N encryption key length is valid"
    else
        print_error "N8N encryption key must be at least 32 characters"
        print_status "Generate with: openssl rand -base64 32"
    fi

    # Check port conflicts
    local ports=(
        "${POSTGRES_EXTERNAL_PORT:-5432}:PostgreSQL"
        "${N8N_EXTERNAL_PORT:-5678}:n8n"
        "${OLLAMA_EXTERNAL_PORT:-11434}:Ollama"
    )

    for port_info in "${ports[@]}"; do
        IFS=':' read -r port service <<< "$port_info"

        if command -v netstat &> /dev/null; then
            if netstat -ln | grep -q ":$port "; then
                print_warning "Port $port ($service) may be in use"
            else
                print_success "Port $port ($service) is available"
            fi
        elif command -v ss &> /dev/null; then
            if ss -ln | grep -q ":$port "; then
                print_warning "Port $port ($service) may be in use"
            else
                print_success "Port $port ($service) is available"
            fi
        fi
    done
}

# Function to check file permissions
check_file_permissions() {
    print_status "Checking file permissions..."

    local files_to_check=(
        "$PROJECT_ROOT/docker-compose.yml"
        "$PROJECT_ROOT/.env.example"
        "$PROJECT_ROOT/scripts/start.sh"
        "$PROJECT_ROOT/scripts/backup.sh"
        "$PROJECT_ROOT/scripts/manage-models.sh"
    )

    for file in "${files_to_check[@]}"; do
        if [ -f "$file" ]; then
            if [ -r "$file" ]; then
                print_success "$(basename "$file") is readable"
            else
                print_error "$(basename "$file") is not readable"
            fi
        else
            print_error "$(basename "$file") not found"
        fi
    done

    # Check script executability
    local scripts=(
        "$PROJECT_ROOT/scripts/start.sh"
        "$PROJECT_ROOT/scripts/backup.sh"
        "$PROJECT_ROOT/scripts/manage-models.sh"
    )

    for script in "${scripts[@]}"; do
        if [ -f "$script" ]; then
            if [ -x "$script" ]; then
                print_success "$(basename "$script") is executable"
            else
                print_warning "$(basename "$script") is not executable"
                print_status "Run: chmod +x $script"
            fi
        fi
    done
}

# Function to validate Docker Compose configuration
validate_compose() {
    print_status "Validating Docker Compose configuration..."

    cd "$PROJECT_ROOT"

    # Test basic compose file
    if docker-compose config &> /dev/null; then
        print_success "docker-compose.yml is valid"
    else
        print_error "docker-compose.yml has syntax errors"
        return 1
    fi

    # Test with development override
    if docker-compose -f docker-compose.yml -f docker-compose.dev.yml config &> /dev/null; then
        print_success "Development configuration is valid"
    else
        print_error "Development configuration has errors"
    fi

    # Test with production override
    if docker-compose -f docker-compose.yml -f docker-compose.prod.yml config &> /dev/null; then
        print_success "Production configuration is valid"
    else
        print_error "Production configuration has errors"
    fi
}

# Function to check directory structure
check_directories() {
    print_status "Checking directory structure..."

    local required_dirs=(
        "scripts"
    )

    local optional_dirs=(
        "${N8N_CUSTOM_NODES_PATH:-./custom-nodes}"
        "${N8N_BACKUPS_PATH:-./backups}"
        "${N8N_LOGS_PATH:-./logs}"
        "data"
    )

    for dir in "${required_dirs[@]}"; do
        if [ -d "$PROJECT_ROOT/$dir" ]; then
            print_success "Required directory '$dir' exists"
        else
            print_error "Required directory '$dir' missing"
        fi
    done

    for dir in "${optional_dirs[@]}"; do
        if [ -d "$PROJECT_ROOT/$dir" ]; then
            print_success "Optional directory '$dir' exists"
        else
            print_warning "Optional directory '$dir' will be created automatically"
        fi
    done
}

# Function to check network connectivity
check_network() {
    print_status "Checking network connectivity..."

    # Check internet connectivity
    if ping -c 1 google.com &> /dev/null; then
        print_success "Internet connectivity available"
    elif ping -c 1 8.8.8.8 &> /dev/null; then
        print_success "Internet connectivity available (DNS may have issues)"
    else
        print_warning "Internet connectivity issues detected"
    fi

    # Check Docker Hub connectivity
    if curl -s --connect-timeout 5 https://index.docker.io/v1/ &> /dev/null; then
        print_success "Docker Hub is accessible"
    else
        print_warning "Docker Hub connectivity issues"
    fi
}

# Function to provide recommendations
provide_recommendations() {
    echo
    print_status "Recommendations and Next Steps:"
    echo

    if [ $CHECKS_FAILED -eq 0 ]; then
        echo "✅ Your configuration looks good!"
        echo
        echo "🚀 Ready to start:"
        echo "   ./scripts/start.sh                    # Development mode"
        echo "   ./scripts/start.sh -e production      # Production mode"
        echo "   ./scripts/start.sh -m                 # With model installation"
        echo
    else
        echo "❌ Please fix the issues above before starting the stack."
        echo
    fi

    if [ $WARNINGS -gt 0 ]; then
        echo "⚠️  Some warnings were found - review them for optimal performance."
        echo
    fi

    echo "📚 Additional resources:"
    echo "   ./scripts/manage-models.sh help        # Model management"
    echo "   ./scripts/backup.sh                    # Database backup"
    echo "   docker-compose logs -f                 # View logs"
    echo "   docker-compose ps                      # Check status"
}

# Main function
main() {
    echo "🔍 N8N AI Stack Configuration Validator"
    echo "========================================"
    echo

    check_docker
    echo

    check_system_resources
    echo

    check_gpu
    echo

    validate_environment
    echo

    check_file_permissions
    echo

    validate_compose
    echo

    check_directories
    echo

    check_network
    echo

    # Summary
    echo "📊 Validation Summary:"
    echo "====================="
    echo "✅ Checks passed: $CHECKS_PASSED"
    echo "❌ Checks failed: $CHECKS_FAILED"
    echo "⚠️  Warnings: $WARNINGS"

    provide_recommendations

    # Exit with appropriate code
    if [ $CHECKS_FAILED -gt 0 ]; then
        exit 1
    else
        exit 0
    fi
}

# Run main function
main "$@"