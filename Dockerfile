FROM nginx:alpine

# Install Python 3, pip, supervisor, curl, and bash
RUN apk add --no-cache python3 py3-pip supervisor curl bash

# Create app directory
WORKDIR /

# Copy backend requirements first for better Docker layer caching
COPY backend/requirements.txt /app/requirements.txt

# Install Python dependencies
RUN pip3 install --no-cache-dir --break-system-packages -r /app/requirements.txt

# Copy backend code
COPY backend/. /app

# Copy frontend files
COPY frontend/. /usr/share/nginx/html

# Copy configuration files
COPY supervisord.conf /etc/supervisor/supervisord.conf
COPY nginx.conf /etc/nginx/nginx.conf

# Create startup script for gcloud authentication and token injection
RUN cat > /start.sh << 'EOF'
#!/bin/bash
exec /usr/bin/supervisord -n -c /etc/supervisor/supervisord.conf
EOF

# Make startup script executable
RUN chmod +x /start.sh

# Expose port 8000 (frontend via nginx)
# Backend runs on 8080 internally and is proxied by nginx
EXPOSE 8000

# Create log directories
RUN mkdir -p /var/log/supervisor

# Start the application
CMD ["/start.sh"]

