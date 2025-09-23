# N8N AI Workflow Stack

A professional Docker Compose setup for running n8n with local AI capabilities using Ollama and PostgreSQL database.

## 🏗️ Architecture

This stack includes:

- **n8n**: Workflow automation platform with AI integration
- **PostgreSQL**: Persistent database for n8n data
- **Ollama**: Local AI model inference server
- **Traefik**: Optional reverse proxy for production deployments

## 🚀 Quick Start

### Prerequisites

- Docker Engine 20.10+
- Docker Compose 2.0+
- At least 4GB RAM (8GB+ recommended for AI models)
- GPU support (optional, for faster AI inference)

### Setup

1. **Clone or download this setup**
   ```bash
   git clone <your-repo> n8n-ai-stack
   cd n8n-ai-stack
   ```

2. **Configure environment variables**
   ```bash
   cp .env.example .env
   ```

3. **Edit the `.env` file**
   ```bash
   nano .env
   ```

   **Required changes:**
   - Set secure passwords for `POSTGRES_PASSWORD` and `POSTGRES_NON_ROOT_PASSWORD`
   - Generate secure keys for `N8N_ENCRYPTION_KEY` and `N8N_JWT_SECRET`

   **Generate secure keys:**
   ```bash
   # For N8N_ENCRYPTION_KEY (32 characters)
   openssl rand -base64 32

   # For N8N_JWT_SECRET (64 characters)
   openssl rand -base64 64
   ```

4. **Create required directories**
   ```bash
   mkdir -p custom-nodes backups init-scripts
   ```

5. **Start the stack**
   ```bash
   docker-compose up -d
   ```

6. **Verify services are running**
   ```bash
   docker-compose ps
   ```

## 🔧 Service Configuration

### N8N Access
- Web interface: http://localhost:5678
- Create your admin account on first visit
- Configure AI nodes to use: http://ollama:11434

### Ollama Management
```bash
# List installed models
docker exec n8n-ai-stack_ollama ollama list

# Install popular models for n8n workflows
docker exec n8n-ai-stack_ollama ollama pull llama2
docker exec n8n-ai-stack_ollama ollama pull codellama
docker exec n8n-ai-stack_ollama ollama pull mistral
docker exec n8n-ai-stack_ollama ollama pull phi

# Check Ollama status
curl http://localhost:11434/api/version
```

### PostgreSQL Access
```bash
# Connect to database
docker exec -it n8n-ai-stack_postgres psql -U n8n -d n8n

# Backup database
docker exec n8n-ai-stack_postgres pg_dump -U n8n n8n > backups/n8n_backup_$(date +%Y%m%d_%H%M%S).sql
```

## 🎯 Using AI in N8N Workflows

### Configuring Ollama in N8N

1. In n8n, add an **AI Agent** or **LLM** node
2. Select **Custom/Generic OpenAI-compatible API**
3. Configure:
   - **Base URL**: `http://ollama:11434/v1`
   - **Model**: Use any model you've pulled (e.g., `llama2`, `mistral`)
   - **API Key**: Leave empty (not required for local Ollama)

### Recommended Models for Different Tasks

| Task | Recommended Model | Size | Use Case |
|------|------------------|------|----------|
| Text Generation | `llama2` | 3.8GB | General purpose text tasks |
| Code Generation | `codellama` | 3.8GB | Programming and code analysis |
| Fast Responses | `phi` | 1.6GB | Quick text processing |
| Instruction Following | `mistral` | 4.1GB | Complex task execution |

## 📁 Directory Structure

```
n8n-ai-stack/
├── docker-compose.yml      # Main orchestration file
├── .env.example           # Environment template
├── .env                   # Your configuration (create this)
├── README.md              # This file
├── custom-nodes/          # Custom n8n nodes
├── backups/              # Database backups
└── init-scripts/         # PostgreSQL init scripts
```

## 🔐 Security Considerations

### For Development
- Change default passwords in `.env`
- Use generated encryption keys
- Keep `.env` file secure and don't commit it

### For Production
- Use Docker secrets instead of environment variables
- Enable SSL/TLS with proper certificates
- Configure firewall rules (expose only necessary ports)
- Set up regular automated backups
- Enable Traefik profile for reverse proxy

## 🚀 Production Deployment

### Enable Traefik Reverse Proxy
```bash
# Configure domain and email in .env
DOMAIN=yourdomain.com
ACME_EMAIL=your-email@yourdomain.com

# Start with production profile
docker-compose --profile production up -d
```

### SSL/TLS Configuration
The Traefik service automatically handles Let's Encrypt certificates when properly configured.

## 🛠️ Maintenance

### Updates
```bash
# Pull latest images
docker-compose pull

# Restart with new images
docker-compose up -d
```

### Backups
```bash
# Automated backup script
./scripts/backup.sh
```

### Logs
```bash
# View all logs
docker-compose logs -f

# View specific service logs
docker-compose logs -f n8n
docker-compose logs -f ollama
docker-compose logs -f postgres
```

## 🔧 Troubleshooting

### Common Issues

**n8n won't start**
- Check PostgreSQL is healthy: `docker-compose ps`
- Verify database credentials in `.env`
- Check logs: `docker-compose logs n8n`

**Ollama models not working**
- Ensure models are pulled: `docker exec n8n-ai-stack_ollama ollama list`
- Check Ollama is accessible: `curl http://localhost:11434/api/version`
- Verify n8n can reach ollama: `docker exec n8n-ai-stack_n8n ping ollama`

**Performance issues**
- Increase Docker memory allocation
- For GPU acceleration, ensure NVIDIA Docker runtime is installed
- Consider using smaller models (phi, mistral-7b)

### Reset Everything
```bash
# Stop and remove all containers and volumes
docker-compose down -v

# Remove all data (⚠️ This deletes everything!)
docker volume prune -f

# Start fresh
docker-compose up -d
```

## 📚 Useful Resources

- [n8n Documentation](https://docs.n8n.io/)
- [Ollama Model Library](https://ollama.ai/library)
- [PostgreSQL Documentation](https://www.postgresql.org/docs/)
- [Docker Compose Reference](https://docs.docker.com/compose/)

## 🤝 Contributing

Feel free to submit issues and enhancement requests!

## 📄 License

This configuration is provided as-is under the MIT License.