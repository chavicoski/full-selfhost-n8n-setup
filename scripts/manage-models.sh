#!/bin/bash

# ==============================================================================
# N8N AI STACK OLLAMA MODEL MANAGEMENT SCRIPT
# ==============================================================================
#
# PURPOSE:
#   Manages Ollama AI models for the n8n workflow automation stack. Provides
#   commands to install, remove, test, and configure AI models for use in n8n.
#
# REQUIREMENTS:
#   - Docker and Docker Compose running
#   - Ollama container must be healthy and accessible
#   - Sufficient disk space for model downloads (1GB-40GB per model)
#
# CONFIGURATION:
#   Environment variables (from .env file):
#   - COMPOSE_PROJECT_NAME: Container name prefix (default: n8n-ai-stack)
#   - Ollama container accessible at: ${COMPOSE_PROJECT_NAME}_ollama
#
# USAGE:
#   ./scripts/manage-models.sh COMMAND [ARGUMENTS]
#
# COMMANDS:
#   list                    List all installed models
#   pull MODEL              Download and install a specific model
#   remove MODEL            Remove an installed model
#   show MODEL              Display model information and specifications
#   test MODEL [PROMPT]     Test model with optional custom prompt
#   recommended             Install curated models for n8n workflows
#   available               Show popular models available for download
#   cleanup                 Clean up unused model data and check disk usage
#   help                    Display detailed usage information
#
# EXAMPLES:
#   # Install recommended models for n8n workflows
#   ./scripts/manage-models.sh recommended
#
#   # List all installed models
#   ./scripts/manage-models.sh list
#
#   # Install specific models
#   ./scripts/manage-models.sh pull llama2
#   ./scripts/manage-models.sh pull codellama:13b
#   ./scripts/manage-models.sh pull mistral
#
#   # Test a model with custom prompt
#   ./scripts/manage-models.sh test llama2 "Explain quantum computing"
#
#   # Show model information
#   ./scripts/manage-models.sh show mistral
#
#   # Remove unused models
#   ./scripts/manage-models.sh remove phi
#
# RECOMMENDED MODELS:
#   The script includes curated models for different n8n use cases:
#   - llama2: General purpose text generation and conversation
#   - codellama: Code generation and programming assistance
#   - mistral: High-quality instruction following and reasoning
#   - phi: Small, fast model for quick responses
#
# N8N INTEGRATION:
#   To use installed models in n8n workflows:
#   1. Add LLM/AI Agent node to your workflow
#   2. Select "Custom OpenAI-compatible API"
#   3. Configure connection:
#      - Base URL: http://ollama:11434/v1
#      - Model: [model name from list command]
#      - API Key: leave empty (not required for local Ollama)
#
# MODEL STORAGE:
#   Models are stored in Docker volume: ${COMPOSE_PROJECT_NAME}_ollama_data
#   Disk usage varies by model size (1GB-40GB each)
#
# EXIT CODES:
#   0: Success
#   1: Error (container not running, model not found, etc.)
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
OLLAMA_CONTAINER="${COMPOSE_PROJECT_NAME}_ollama"

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

# Function to check if Ollama container is running
check_ollama_container() {
    if ! docker ps --format "table {{.Names}}" | grep -q "^${OLLAMA_CONTAINER}$"; then
        print_error "Ollama container '${OLLAMA_CONTAINER}' is not running."
        print_warning "Start the stack first with: ./scripts/start.sh"
        exit 1
    fi
}

# Function to execute Ollama commands
ollama_exec() {
    docker exec "$OLLAMA_CONTAINER" ollama "$@"
}

# Function to list all available models
list_models() {
    print_status "Listing installed Ollama models..."
    echo

    if ! ollama_exec list; then
        print_error "Failed to list models"
        return 1
    fi

    echo
    print_status "To use these models in n8n, configure LLM nodes with:"
    print_status "  Base URL: http://ollama:11434/v1"
    print_status "  Model: [model name from above list]"
}

# Function to pull a model
pull_model() {
    local model="$1"

    if [ -z "$model" ]; then
        print_error "Model name is required"
        return 1
    fi

    print_status "Pulling model: $model"
    print_warning "This may take several minutes depending on model size..."

    if ollama_exec pull "$model"; then
        print_success "Model '$model' pulled successfully"

        # Show model info
        print_status "Model information:"
        ollama_exec show "$model" 2>/dev/null || true
    else
        print_error "Failed to pull model '$model'"
        return 1
    fi
}

# Function to remove a model
remove_model() {
    local model="$1"

    if [ -z "$model" ]; then
        print_error "Model name is required"
        return 1
    fi

    print_warning "Are you sure you want to remove model '$model'? (y/N)"
    read -r response

    if [[ "$response" =~ ^[Yy]$ ]]; then
        if ollama_exec rm "$model"; then
            print_success "Model '$model' removed successfully"
        else
            print_error "Failed to remove model '$model'"
            return 1
        fi
    else
        print_status "Operation cancelled"
    fi
}

# Function to show model information
show_model() {
    local model="$1"

    if [ -z "$model" ]; then
        print_error "Model name is required"
        return 1
    fi

    print_status "Model information for: $model"
    echo

    if ollama_exec show "$model"; then
        echo
        print_status "Model size and performance information:"
        docker exec "$OLLAMA_CONTAINER" du -sh /root/.ollama/models/blobs/* 2>/dev/null | head -10 || true
    else
        print_error "Model '$model' not found or failed to get information"
        return 1
    fi
}

# Function to install recommended models for n8n
install_recommended() {
    print_status "Installing recommended models for n8n workflows..."

    # Define recommended models with descriptions
    declare -A models=(
        ["llama2"]="General purpose text generation and conversation"
        ["codellama"]="Code generation and programming assistance"
        ["mistral"]="High-quality instruction following and reasoning"
        ["phi"]="Small, fast model for quick responses"
    )

    for model in "${!models[@]}"; do
        echo
        print_status "Installing $model: ${models[$model]}"

        if ollama_exec list | grep -q "^$model"; then
            print_warning "Model '$model' already installed, skipping..."
        else
            pull_model "$model"
        fi
    done

    echo
    print_success "Recommended models installation completed!"
    print_status "Total models installed:"
    list_models
}

# Function to check model performance
test_model() {
    local model="$1"
    local prompt="${2:-Hello, how are you?}"

    if [ -z "$model" ]; then
        print_error "Model name is required"
        return 1
    fi

    print_status "Testing model '$model' with prompt: '$prompt'"
    print_warning "This will generate a response (may take a moment)..."
    echo

    if ollama_exec run "$model" "$prompt"; then
        echo
        print_success "Model test completed"
    else
        print_error "Model test failed"
        return 1
    fi
}

# Function to show available models to download
show_available() {
    print_status "Popular models available for download:"
    echo

    cat << EOF
🤖 Text Generation Models:
  llama2          - Meta's Llama 2 (7B parameters) - General purpose
  llama2:13b      - Meta's Llama 2 (13B parameters) - Better quality
  mistral         - Mistral 7B - Excellent instruction following
  zephyr          - Zephyr 7B - Fine-tuned for helpful conversations

💻 Code Models:
  codellama       - Code Llama (7B) - Code generation and completion
  codellama:13b   - Code Llama (13B) - Better code understanding
  deepseek-coder  - DeepSeek Coder - Specialized for programming

⚡ Fast/Small Models:
  phi             - Microsoft Phi-2 (2.7B) - Fast responses
  tinyllama       - TinyLlama (1.1B) - Very fast, basic tasks

🧠 Specialized Models:
  llava           - Multimodal model (text + images)
  vicuna          - Vicuna 7B - Based on Llama, instruction-tuned
  orca-mini       - Orca Mini - Reasoning and explanation

Usage Examples:
  $0 pull llama2           # Pull Llama 2 7B
  $0 pull codellama:13b    # Pull Code Llama 13B
  $0 pull mistral          # Pull Mistral 7B
EOF
}

# Function to cleanup unused models
cleanup() {
    print_status "Checking for unused model data..."

    # This is a placeholder - Ollama doesn't have a built-in cleanup command yet
    print_warning "Manual cleanup: Remove unused model blobs from Ollama data directory"
    print_status "Current disk usage:"
    docker exec "$OLLAMA_CONTAINER" du -sh /root/.ollama/ 2>/dev/null || true
}

# Function to show help
show_help() {
    echo "Ollama Model Management for N8N AI Stack"
    echo
    echo "Usage: $0 COMMAND [ARGUMENTS]"
    echo
    echo "Commands:"
    echo "  list                    List installed models"
    echo "  pull MODEL              Pull/download a model"
    echo "  remove MODEL            Remove a model"
    echo "  show MODEL              Show model information"
    echo "  test MODEL [PROMPT]     Test a model with a prompt"
    echo "  recommended             Install recommended models for n8n"
    echo "  available               Show available models to download"
    echo "  cleanup                 Clean up unused model data"
    echo "  help                    Show this help message"
    echo
    echo "Examples:"
    echo "  $0 list                           # List all installed models"
    echo "  $0 pull llama2                    # Download Llama 2 model"
    echo "  $0 show mistral                   # Show Mistral model info"
    echo "  $0 test llama2 \"Explain AI\"       # Test model with prompt"
    echo "  $0 recommended                    # Install all recommended models"
    echo
    echo "For n8n integration:"
    echo "  Base URL: http://ollama:11434/v1"
    echo "  Model: [use model name from 'list' command]"
}

# Main function
main() {
    echo "🤖 Ollama Model Management"
    echo "=========================="
    echo

    # Check if Ollama container is running
    check_ollama_container

    # Parse command
    case "${1:-help}" in
        list|ls)
            list_models
            ;;
        pull|download)
            pull_model "$2"
            ;;
        remove|rm|delete)
            remove_model "$2"
            ;;
        show|info)
            show_model "$2"
            ;;
        test|run)
            test_model "$2" "$3"
            ;;
        recommended|install-recommended)
            install_recommended
            ;;
        available|browse)
            show_available
            ;;
        cleanup|clean)
            cleanup
            ;;
        help|--help|-h)
            show_help
            ;;
        *)
            print_error "Unknown command: $1"
            echo
            show_help
            exit 1
            ;;
    esac
}

# Run main function
main "$@"