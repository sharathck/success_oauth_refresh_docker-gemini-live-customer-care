FROM nginx:alpine

# install Python 3, pip, curl, and other dependencies
RUN apk add --no-cache python3 py3-pip supervisor curl bash

# Install Google Cloud SDK
RUN curl -sSL https://sdk.cloud.google.com | bash
ENV PATH="$PATH:/root/google-cloud-sdk/bin"

# copy the front end 
COPY frontend/. /usr/share/nginx/html

# copy backend (excluding auth.py)
COPY backend/main.py /app/main.py
COPY backend/auth.py /app/auth.py
COPY backend/requirements.txt /app/requirements.txt

# Copy service account file
COPY backend/reviewtext-ad5c6-vertex-ai.json /app/reviewtext-ad5c6-vertex-ai.json

# Upgrade pip and install dependencies
RUN pip3 install --upgrade pip && \
    pip3 install --no-cache-dir --break-system-packages -r /app/requirements.txt

# Configure gcloud and generate access token
RUN gcloud components update && \
    gcloud components install beta && \
    gcloud config set project reviewtext-ad5c6 && \
    gcloud auth activate-service-account --key-file=/app/reviewtext-ad5c6-vertex-ai.json

COPY supervisord.conf /etc/supervisor/supervisord.conf
COPY nginx.conf /etc/nginx/nginx.conf

EXPOSE 8000

CMD ["/usr/bin/supervisord", "-c", "/etc/supervisor/supervisord.conf"]