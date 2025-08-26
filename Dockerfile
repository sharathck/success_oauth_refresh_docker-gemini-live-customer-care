FROM nginx:alpine

# Install Python 3, pip, supervisor, curl, and bash
RUN apk add --no-cache python3 py3-pip supervisor curl bash

# Install Google Cloud SDK
RUN curl -sSL https://sdk.cloud.google.com | bash
ENV PATH $PATH:/root/google-cloud-sdk/bin

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
echo "Initializing gcloud..."

# Update gcloud components
gcloud components update --quiet
gcloud components install beta --quiet

# Set project
gcloud config set project reviewtext-ad5c6

# Get access token
echo "Getting access token..."
ACCESS_TOKEN=$(gcloud auth print-access-token)

if [ -n "$ACCESS_TOKEN" ]; then
    echo "Access token obtained, updating frontend..."
    # Replace the access token in the index.html file
    sed -i "s/value=\"ya29[^\"]*\"/value=\"$ACCESS_TOKEN\"/g" /usr/share/nginx/html/index.html
    echo "Access token updated in frontend"
else
    echo "Warning: Could not obtain access token. Please ensure you're authenticated with gcloud."
fi

# Start supervisord
exec /usr/bin/supervisord -c /etc/supervisor/supervisord.conf
EOF

RUN chmod +x /start.sh

# Expose port 8000 (frontend via nginx)
# Backend runs on 8080 internally and is proxied by nginx
EXPOSE 8000

# Create log directories
RUN mkdir -p /var/log/supervisor

# Start with our custom script that handles gcloud auth
CMD ["/start.sh"]