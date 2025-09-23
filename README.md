# N8N AI Workflow Stack

Professional Docker Compose setup for n8n with local AI capabilities using Ollama and PostgreSQL.

## 🚀 TLDR - Quick Development Setup

**Need to start immediately? Run these commands:**

**CPU-only (works everywhere):**
```bash
./scripts/generate-env.sh    # Creates secure .env file
./scripts/start.sh           # Starts development stack (CPU)
./scripts/manage-models.sh recommended  # Installs AI models
```

**With GPU acceleration (if available):**
```bash
./scripts/generate-env.sh    # Creates secure .env file
./scripts/start.sh -g        # Starts with GPU acceleration
./scripts/manage-models.sh recommended  # Installs AI models
```

**Access your services:**
- **n8n**: http://localhost:5678 (create admin account on first visit)
- **PgAdmin**: http://localhost:5050 (admin@n8n.local / admin123)
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
- Optional: NVIDIA GPU for faster AI

## 🔧 Basic Usage

### Start Development Environment
```bash
./scripts/start.sh                # Full dev stack with PgAdmin
./scripts/start.sh -m             # + auto-install AI models
./scripts/start.sh -g             # + GPU acceleration
```

### Manage AI Models
```bash
./scripts/manage-models.sh list           # Show installed models
./scripts/manage-models.sh pull mistral   # Install specific model
./scripts/manage-models.sh test llama2    # Test a model
```

### Check Status & Logs
```bash
./scripts/status.sh              # System health check
./scripts/validate.sh            # Diagnose configuration issues
docker-compose logs -f n8n       # Follow n8n logs
docker-compose ps                # Service status
```

### Stop Everything
```bash
docker-compose down              # Stop services
docker-compose down -v           # Stop + remove data
```

### Reset Everything
```bash
docker-compose down -v       # Remove all data
rm .env                      # Remove configuration
./scripts/generate-env.sh    # Start fresh
./scripts/start.sh
```

**💡 Having issues?** Run `./scripts/validate.sh` to diagnose problems, or `./scripts/status.sh` for health checks.

## 🏗️ What's Included

| Service | Purpose | Development | Production |
|---------|---------|-------------|------------|
| **n8n** | Workflow automation | http://localhost:5678 | Via Traefik SSL |
| **PostgreSQL** | Database | Exposed port + PgAdmin | Internal only |
| **Ollama** | Local AI models | CPU/GPU flexible | GPU-optimized |
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
./scripts/start.sh -e production # Starts with SSL, security hardening
```

**Production requirements:**
- Set `DOMAIN` and `ACME_EMAIL` in .env
- Uncomment Traefik variables
- Use `./scripts/validate.sh` to check config

### Custom Configuration
Edit `.env` file to customize:
- **Ports**: Change if default ports conflict
- **Resources**: Adjust memory/CPU limits
- **Paths**: Customize data directories
- **Security**: Set encryption keys and passwords

## 📁 Project Structure

```
n8n-ai-stack/
├── docker-compose.yml          # Base configuration
├── docker-compose.dev.yml      # Development overrides
├── docker-compose.prod.yml     # Production overrides
├── .env.example               # Configuration template
├── scripts/                   # Management scripts
│   ├── start.sh              # Start stack
│   ├── validate.sh           # Validate config
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
- `N8N_ENCRYPTION_KEY`: Must be 32+ characters
- `POSTGRES_PASSWORD`: Database admin password
- `COMPOSE_PROJECT_NAME`: Prefix for container names

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