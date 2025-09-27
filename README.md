# N8N AI Workflow Stack

Professional Docker Compose setup for n8n with local AI capabilities using Ollama and PostgreSQL.

## 🚀 TLDR - Quick Development Setup

**Need to start immediately? Run these commands:**

**CPU-only (works everywhere):**
```bash
./scripts/generate-env.sh         # Creates secure .env file
./scripts/start.sh                # Starts development stack (CPU)
./scripts/start.sh -m             # Starts and installs recommended AI models
```

**With GPU acceleration (recommended for AI workloads):**
```bash
./scripts/generate-env.sh         # Creates secure .env file
./scripts/start.sh -g             # Starts development stack with GPU
./scripts/start.sh -g -m          # Starts with GPU and installs AI models
```

**Access your services:**
- **n8n**: http://localhost:5678 (create admin account on first visit)
- **PgAdmin**: http://localhost:5050 (admin@example.com / see .env PGADMIN_PASSWORD)
- **Ollama API**: http://localhost:11434

**Configure AI in n8n:**
1. Add LLM/AI Agent node
2. Select "Custom OpenAI-compatible API"
3. Base URL: `http://ollama:11434/v1`
4. Model: any installed model (use `./scripts/manage-models.sh list` to see available)
5. API Key: leave empty

---

## 📋 Prerequisites

- Docker & Docker Compose
- 4GB+ RAM (8GB+ recommended)
- Optional: NVIDIA GPU + Docker with GPU support for faster AI

## 🔧 Basic Usage

### Start Development Environment
```bash
./scripts/start.sh                # Full dev stack with PgAdmin (CPU)
./scripts/start.sh -g             # Full dev stack with GPU acceleration
./scripts/start.sh -m             # + auto-install AI models
./scripts/start.sh -g -m          # GPU + auto-install AI models
```

### Manage AI Models
```bash
./scripts/manage-models.sh list           # Show installed models
./scripts/manage-models.sh pull mistral   # Install specific model
./scripts/manage-models.sh test llama2    # Test a model
./scripts/manage-models.sh recommended    # Install recommended models
```

### Check Status & Logs
```bash
./scripts/status.sh              # Comprehensive health check
./scripts/validate.sh            # Diagnose configuration issues
docker-compose ps                # Service status
docker-compose logs -f n8n       # Follow n8n logs
```

### Stop Everything
```bash
docker-compose down              # Stop services
docker-compose down -v           # Stop + remove data
```

### Reset When Having Issues
```bash
# If environment changed (encryption key mismatch):
./scripts/start.sh --reset-data     # Reset n8n data only (keeps database/AI models)

# Complete fresh start:
./scripts/start.sh --reset-all      # Remove all data

# Manual reset (alternative):
docker-compose down -v              # Remove all data
rm .env                             # Remove configuration
./scripts/generate-env.sh           # Generate new environment
./scripts/start.sh                  # Start fresh
```

**💡 Having issues?** Run `./scripts/validate.sh` to diagnose problems, or `./scripts/status.sh` for health checks.

### ⚠️ Common Issues & Solutions

**Encryption Key Mismatch Error:**
```
Error: Mismatching encryption keys. The encryption key in the settings file...
```
**Solution:** `./scripts/start.sh --reset-data` (resets n8n config while keeping your workflows)

**Database Authentication Failed:**
```
password authentication failed for user "postgres"
```
**Solution:** `./scripts/start.sh --reset-all` (complete fresh start with new passwords)

**Container Name Conflicts:**
- Always use the same compose file combination for up/down
- Use `docker-compose -f docker-compose.yml -f docker-compose.dev.yml down` for development

## 🏗️ What's Included

| Service | Purpose | Development | Production |
|---------|---------|-------------|------------|
| **n8n** | Workflow automation | http://localhost:5678 | Via Traefik SSL |
| **PostgreSQL** | Database | Exposed port + PgAdmin | Internal only |
| **Ollama** | Local AI models | CPU/GPU flexible | CPU/GPU flexible |
| **PgAdmin** | Database admin | ✅ Included | ❌ Not included |
| **Traefik** | Reverse proxy | ❌ Not used | ✅ SSL termination |

## 🔧 Configuration

### Environment Setup
```bash
cp .env.example .env             # Manual setup
./scripts/generate-env.sh        # Automated secure setup
```

### Production Deployment
```bash
./scripts/start.sh -e production      # Starts with SSL, security hardening (CPU)
./scripts/start.sh -e production -g   # Production with GPU acceleration
```

**Production requirements:**
- Set `DOMAIN`, `N8N_DOMAIN`, `TRAEFIK_DOMAIN` and `ACME_EMAIL` in .env
- For GPU: Install NVIDIA Container Toolkit
- Ensure all required variables are configured

### GPU Setup (Optional)
For GPU acceleration, you need:
1. **NVIDIA GPU** with recent drivers
2. **NVIDIA Container Toolkit** installed
3. **Docker with GPU support** enabled

```bash
# Install NVIDIA Container Toolkit (Ubuntu/Debian)
curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey | sudo gpg --dearmor -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg
curl -s -L https://nvidia.github.io/libnvidia-container/stable/deb/nvidia-container-toolkit.list | \
  sed 's#deb https://#deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://#g' | \
  sudo tee /etc/apt/sources.list.d/nvidia-container-toolkit.list
sudo apt-get update && sudo apt-get install -y nvidia-container-toolkit
sudo systemctl restart docker

# Test GPU support
docker run --rm --gpus all nvidia/cuda:11.0.3-base-ubuntu20.04 nvidia-smi
```

### Custom Configuration
Edit `.env` file to customize:
- **Ports**: Change if default ports conflict
- **Paths**: Customize data directories
- **Security**: Set encryption keys and passwords
- **Domains**: Configure for production SSL

## 📁 Project Structure

```
n8n-ai-stack/
├── docker-compose.yml          # Base configuration
├── docker-compose.dev.yml      # Development overrides
├── docker-compose.prod.yml     # Production overrides
├── docker-compose.gpu.yml      # GPU acceleration overrides
├── .env.example               # Configuration template
├── scripts/                   # Management scripts
│   ├── start.sh              # Start stack
│   ├── validate.sh           # Validate config
│   ├── status.sh             # Health monitoring
│   ├── manage-models.sh      # AI model management
│   ├── generate-env.sh       # Create secure .env
│   └── backup.sh             # Database backup
├── custom-nodes/             # n8n custom nodes
├── backups/                  # Database backups
└── logs/                     # Application logs
```

## 🛠️ Development Tips

### Useful Commands
```bash
# Backup database
./scripts/backup.sh

# Update to latest images
docker-compose pull && docker-compose up -d

# Access database directly
docker exec -it n8n-ai-stack_postgres psql -U postgres -d n8n

# Monitor resources
docker stats

# Follow all logs
docker-compose logs -f
```

### Custom Nodes Development
- Place custom nodes in `./custom-nodes/`
- They auto-mount to `/home/node/.n8n/custom` in development
- Restart n8n service to reload: `docker-compose restart n8n`

### Environment Variables
All settings in `.env.example` are documented with examples. Key ones:
- `N8N_ENCRYPTION_KEY`: Must be 32+ characters (auto-generated by generate-env.sh)
- `N8N_JWT_SECRET`: JWT signing secret (auto-generated by generate-env.sh)
- `POSTGRES_PASSWORD`: Database admin password (auto-generated by generate-env.sh)
- `COMPOSE_PROJECT_NAME`: Prefix for container names

**Path Customization:**
- `N8N_CUSTOM_NODES_PATH`: Custom nodes directory (default: ./custom-nodes)
- `N8N_BACKUPS_PATH`: Database backup directory (default: ./backups)
- `N8N_LOGS_PATH`: Application logs directory (default: ./logs)

**⚠️ Important:** After changing encryption keys or passwords, use `./scripts/start.sh --reset-data` to avoid conflicts.

## 📚 Resources

- [n8n Documentation](https://docs.n8n.io/)
- [Ollama Models](https://ollama.ai/library)
- [Docker Compose Reference](https://docs.docker.com/compose/)

## 🤝 Contributing

1. Test changes with `./scripts/validate.sh`
2. Update documentation as needed
3. Submit PRs with clear descriptions

## 📄 License

MIT License - see LICENSE file for details.