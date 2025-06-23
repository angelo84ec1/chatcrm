# PowerChat Plus - Production Docker Image (Node.js 20.19.1)
# Uses pre-compiled, obfuscated application build

FROM node:20.19.1-alpine

# Set working directory
WORKDIR /app

# Install system dependencies
RUN apk add --no-cache \
    postgresql-client \
    curl \
    bash \
    git \
    python3 \
    make \
    g++ \
    && rm -rf /var/cache/apk/*

# Create app user for security
RUN addgroup -g 1001 -S nodejs && \
    adduser -S powerchat -u 1001

# Copy package.json and node_modules
COPY package.json ./

# Copy node_modules if it exists, otherwise install dependencies
COPY node_modules* ./node_modules/

# Install dependencies only if node_modules is empty or doesn't exist
RUN if [ ! -d "node_modules" ] || [ -z "$(ls -A node_modules 2>/dev/null)" ]; then \
        echo "Installing dependencies in container..." && \
        npm config set registry https://registry.npmjs.org/ && \
        npm config set fetch-retry-mintimeout 20000 && \
        npm config set fetch-retry-maxtimeout 120000 && \
        npm config set fetch-retries 3 && \
        npm install --production --no-audit --no-fund && \
        npm cache clean --force; \
    else \
        echo "Using existing node_modules from host"; \
    fi

# Copy pre-built application
COPY dist/ ./dist/
COPY migrations/ ./migrations/
COPY scripts/ ./scripts/
COPY public/ ./public/
COPY uploads/ ./uploads/

# Copy additional files
COPY start.js ./

# Create necessary directories and set permissions
RUN mkdir -p /app/uploads/flow-media /app/public/media /app/logs /app/backups /app/backups/updates && \
    chown -R powerchat:nodejs /app && \
    chmod +x /app/start.js /app/scripts/migrate.js 2>/dev/null || true

# Switch to non-root user
USER powerchat

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
    CMD curl -f http://localhost:9000/api/health || exit 1

# Expose port
EXPOSE 9000

# Start command
CMD ["node", "start.js"]
