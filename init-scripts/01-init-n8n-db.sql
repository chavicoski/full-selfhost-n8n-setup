-- N8N Database Initialization Script
-- This script ensures proper database setup for n8n

-- Ensure the n8n database exists (it should be created by POSTGRES_DB)
-- This is mainly for documentation purposes

-- Create schema if it doesn't exist
CREATE SCHEMA IF NOT EXISTS public;

-- Grant privileges to the n8n user on the public schema
GRANT ALL PRIVILEGES ON SCHEMA public TO n8n;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO n8n;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO n8n;

-- Set default privileges for future objects
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL PRIVILEGES ON TABLES TO n8n;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL PRIVILEGES ON SEQUENCES TO n8n;

-- Enable required extensions for n8n (if needed)
-- CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
-- CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- Set timezone to UTC for consistency
SET timezone = 'UTC';