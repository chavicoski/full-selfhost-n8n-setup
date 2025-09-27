#!/bin/bash

# ==============================================================================
# N8N AI STACK ENVIRONMENT GENERATOR
# ==============================================================================
#
# PURPOSE:
#   Automatically generates a secure .env file with random passwords, encryption
#   keys, and JWT secrets. Provides interactive and automated modes for setup.
#
# REQUIREMENTS:
#   - .env.example file in project root
#   - openssl (preferred) or /dev/urandom for secure random generation
#   - Write permissions to project directory
#
# CONFIGURATION:
#   No external configuration required - uses .env.example as template
#
# USAGE:
#   ./scripts/generate-env.sh [OPTIONS]
#
# OPTIONS:
#   -f, --force         Force overwrite existing .env file
#   -u, --update-only   Only update placeholder values in existing .env
#   -v, --validate      Validate environment after generation
#   -h, --help          Show help message
#
# EXAMPLES:
#   # Interactive mode (recommended for first-time setup)
#   ./scripts/generate-env.sh
#
#   # Force create new .env (overwrites existing)
#   ./scripts/generate-env.sh -f
#
#   # Update existing .env with secure values for placeholders
#   ./scripts/generate-env.sh -u
#
#   # Generate and validate configuration
#   ./scripts/generate-env.sh -v
#
# GENERATED VALUES:
#   - POSTGRES_PASSWORD: 32-character random password
#   - POSTGRES_NON_ROOT_PASSWORD: 32-character random password
#   - N8N_ENCRYPTION_KEY: 32-character base64 encryption key
#   - N8N_JWT_SECRET: 64-character base64 JWT secret
#   - PGADMIN_PASSWORD: 16-character random password
#
# SECURITY FEATURES:
#   - Uses openssl for cryptographically secure random generation
#   - Replaces all placeholder values (your_*_here)
#   - Validates key lengths (32+ chars for encryption key)
#   - Creates backups of existing .env files
#
# EXIT CODES:
#   0: Success
#   1: Error (missing template, validation failed, etc.)
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
ENV_EXAMPLE="$PROJECT_ROOT/.env.example"

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

# Function to generate secure password
generate_password() {
    local length=${1:-32}

    if command -v openssl &> /dev/null; then
        openssl rand -base64 $length | tr -d "=+/" | cut -c1-$length
    elif command -v head &> /dev/null && [ -r /dev/urandom ]; then
        head -c $length /dev/urandom | base64 | tr -d "=+/" | cut -c1-$length
    else
        # Fallback method
        date +%s | sha256sum | base64 | head -c $length
    fi
}

# Function to generate encryption key
generate_encryption_key() {
    if command -v openssl &> /dev/null; then
        openssl rand -base64 32
    else
        generate_password 32
    fi
}

# Function to generate JWT secret
generate_jwt_secret() {
    if command -v openssl &> /dev/null; then
        openssl rand -base64 64
    else
        generate_password 64
    fi
}

# Function to check if .env exists
check_existing_env() {
    if [ -f "$ENV_FILE" ]; then
        print_warning ".env file already exists"
        echo
        echo "Options:"
        echo "  1) Backup existing and create new"
        echo "  2) Update only missing/placeholder values"
        echo "  3) Exit without changes"
        echo
        read -p "Choose option (1-3): " choice

        case $choice in
            1)
                mv "$ENV_FILE" "${ENV_FILE}.backup.$(date +%Y%m%d_%H%M%S)"
                print_status "Existing .env backed up"
                return 0
                ;;
            2)
                return 1  # Update mode
                ;;
            3)
                print_status "Operation cancelled"
                exit 0
                ;;
            *)
                print_error "Invalid choice"
                exit 1
                ;;
        esac
    fi
    return 0  # New file mode
}

# Function to create new .env file
create_new_env() {
    print_status "Creating new .env file with secure defaults..."

    # Generate secure values
    local postgres_password=$(generate_password 32)
    local postgres_n8n_password=$(generate_password 32)
    local n8n_encryption_key=$(generate_encryption_key)
    local n8n_jwt_secret=$(generate_jwt_secret)
    local pgadmin_password=$(generate_password 16)

    # Copy from example
    cp "$ENV_EXAMPLE" "$ENV_FILE"

    # Replace placeholder values using environment variables and envsubst-like approach
    # Create a temporary file with the replacements
    temp_file=$(mktemp)

    # Use a here document to avoid sed escaping issues
    while IFS= read -r line; do
        case "$line" in
            *"your_secure_postgres_password_here"*)
                echo "${line//your_secure_postgres_password_here/$postgres_password}"
                ;;
            *"your_secure_n8n_db_password_here"*)
                echo "${line//your_secure_n8n_db_password_here/$postgres_n8n_password}"
                ;;
            *"your_32_character_encryption_key_here"*)
                echo "${line//your_32_character_encryption_key_here/$n8n_encryption_key}"
                ;;
            *"your_jwt_secret_here"*)
                echo "${line//your_jwt_secret_here/$n8n_jwt_secret}"
                ;;
            *"admin123"*)
                echo "${line//admin123/$pgadmin_password}"
                ;;
            *)
                echo "$line"
                ;;
        esac
    done < "$ENV_FILE" > "$temp_file"

    # Move the temporary file to replace the original
    mv "$temp_file" "$ENV_FILE"

    print_success ".env file created with secure passwords"

    # Show generated credentials
    echo
    print_status "Generated credentials:"
    echo "  PostgreSQL Admin Password: $postgres_password"
    echo "  PostgreSQL n8n Password: $postgres_n8n_password"
    echo "  PgAdmin Password: $pgadmin_password"
    echo "  n8n Encryption Key: $n8n_encryption_key"
    echo "  n8n JWT Secret: $n8n_jwt_secret"
}

# Function to update existing .env file
update_existing_env() {
    print_status "Updating existing .env file..."

    # Source the existing file
    source "$ENV_FILE"

    local updated=false

    # Check and update placeholder passwords using safe string replacement
    temp_file=$(mktemp)

    while IFS= read -r line; do
        case "$line" in
            POSTGRES_PASSWORD=*)
                if [[ "$POSTGRES_PASSWORD" == *"your_"* ]] || [ -z "$POSTGRES_PASSWORD" ]; then
                    local new_password=$(generate_password 32)
                    echo "POSTGRES_PASSWORD=$new_password"
                    print_status "Updated PostgreSQL admin password"
                    echo "  New PostgreSQL Admin Password: $new_password"
                    updated=true
                else
                    echo "$line"
                fi
                ;;
            POSTGRES_NON_ROOT_PASSWORD=*)
                if [[ "$POSTGRES_NON_ROOT_PASSWORD" == *"your_"* ]] || [ -z "$POSTGRES_NON_ROOT_PASSWORD" ]; then
                    local new_password=$(generate_password 32)
                    echo "POSTGRES_NON_ROOT_PASSWORD=$new_password"
                    print_status "Updated PostgreSQL n8n user password"
                    echo "  New PostgreSQL n8n Password: $new_password"
                    updated=true
                else
                    echo "$line"
                fi
                ;;
            N8N_ENCRYPTION_KEY=*)
                if [[ "$N8N_ENCRYPTION_KEY" == *"your_"* ]] || [ -z "$N8N_ENCRYPTION_KEY" ] || [ ${#N8N_ENCRYPTION_KEY} -lt 32 ]; then
                    local new_key=$(generate_encryption_key)
                    echo "N8N_ENCRYPTION_KEY=$new_key"
                    print_status "Updated n8n encryption key"
                    echo "  New n8n Encryption Key: $new_key"
                    updated=true
                else
                    echo "$line"
                fi
                ;;
            N8N_JWT_SECRET=*)
                if [[ "$N8N_JWT_SECRET" == *"your_"* ]] || [ -z "$N8N_JWT_SECRET" ]; then
                    local new_secret=$(generate_jwt_secret)
                    echo "N8N_JWT_SECRET=$new_secret"
                    print_status "Updated n8n JWT secret"
                    echo "  New n8n JWT Secret: [64 characters]"
                    updated=true
                else
                    echo "$line"
                fi
                ;;
            *)
                echo "$line"
                ;;
        esac
    done < "$ENV_FILE" > "$temp_file"

    mv "$temp_file" "$ENV_FILE"

    if [ "$updated" = true ]; then
        print_success "Environment file updated with secure values"
    else
        print_success "No placeholder values found - environment file is already configured"
    fi
}

# Function to validate generated environment
validate_env() {
    print_status "Validating generated environment..."

    if [ -f "$PROJECT_ROOT/scripts/validate.sh" ]; then
        if "$PROJECT_ROOT/scripts/validate.sh" >/dev/null 2>&1; then
            print_success "Environment validation passed"
        else
            print_warning "Some validation warnings exist - run './scripts/validate.sh' for details"
        fi
    else
        print_warning "Validation script not found - skipping validation"
    fi
}

# Function to provide next steps
show_next_steps() {
    echo
    print_status "Next steps:"
    echo
    echo "1. Review and customize .env file if needed:"
    echo "   nano .env"
    echo
    echo "2. Validate your configuration:"
    echo "   ./scripts/validate.sh"
    echo
    echo "3. Start the stack:"
    echo "   ./scripts/start.sh                    # Development mode"
    echo "   ./scripts/start.sh -e production      # Production mode"
    echo "   ./scripts/start.sh -m                 # With model installation"
    echo
    echo "4. Check status:"
    echo "   ./scripts/status.sh"
    echo
    echo "5. Manage AI models:"
    echo "   ./scripts/manage-models.sh recommended"
    echo
}

# Function to show help
show_help() {
    echo "N8N AI Stack Environment Generator"
    echo
    echo "Usage: $0 [OPTIONS]"
    echo
    echo "Options:"
    echo "  -f, --force            Force overwrite existing .env file"
    echo "  -u, --update-only      Only update placeholder values in existing .env"
    echo "  -v, --validate         Validate environment after generation"
    echo "  -h, --help             Show this help message"
    echo
    echo "Examples:"
    echo "  $0                     # Interactive mode"
    echo "  $0 -f                  # Force create new .env"
    echo "  $0 -u                  # Update existing .env only"
    echo "  $0 -v                  # Generate and validate"
    echo
    echo "This script generates secure passwords and encryption keys for:"
    echo "  - PostgreSQL database credentials"
    echo "  - n8n encryption key and JWT secret"
    echo "  - PgAdmin credentials"
    echo
    echo "Generated credentials are displayed once and saved to .env file."
}

# Main function
main() {
    echo "🔐 N8N AI Stack Environment Generator"
    echo "====================================="
    echo

    local force_mode=false
    local update_only=false
    local validate_after=false

    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -f|--force)
                force_mode=true
                shift
                ;;
            -u|--update-only)
                update_only=true
                shift
                ;;
            -v|--validate)
                validate_after=true
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

    # Check if .env.example exists
    if [ ! -f "$ENV_EXAMPLE" ]; then
        print_error ".env.example file not found"
        exit 1
    fi

    # Handle existing .env file
    if [ "$force_mode" = true ]; then
        if [ -f "$ENV_FILE" ]; then
            mv "$ENV_FILE" "${ENV_FILE}.backup.$(date +%Y%m%d_%H%M%S)"
            print_status "Existing .env backed up"
        fi
        create_new_env
    elif [ "$update_only" = true ]; then
        if [ ! -f "$ENV_FILE" ]; then
            print_error ".env file does not exist - cannot update"
            print_status "Run without -u flag to create new .env file"
            exit 1
        fi
        update_existing_env
    else
        # Interactive mode
        if check_existing_env; then
            create_new_env
        else
            update_existing_env
        fi
    fi

    # Validate if requested
    if [ "$validate_after" = true ]; then
        validate_env
    fi
}

# Run main function
main "$@"