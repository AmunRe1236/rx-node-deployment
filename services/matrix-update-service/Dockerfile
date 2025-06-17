FROM python:3.11-slim

# 🎩 Gentleman Matrix Update Service
LABEL maintainer="amonbaumgartner@gentlemail.com"
LABEL description="Matrix-basierte Update-Autorisierung für Gentleman Pipeline"

# 📦 System Dependencies
RUN apt-get update && apt-get install -y \
    curl \
    git \
    && rm -rf /var/lib/apt/lists/*

# 📁 Working Directory
WORKDIR /app

# 📋 Copy Requirements
COPY requirements.txt .

# 🔧 Install Python Dependencies
RUN pip install --no-cache-dir -r requirements.txt

# 📄 Copy Application
COPY . .

# 🔒 Create non-root user
RUN useradd -m -s /bin/bash gentleman && \
    chown -R gentleman:gentleman /app

USER gentleman

# 🚀 Start Command
CMD ["python", "main.py"] 