# 🌐 GENTLEMAN Web Interface
# ═══════════════════════════════════════════════════════════════

FROM python:3.9-slim

# 🏷️ Metadata
LABEL maintainer="Gentleman AI Team"
LABEL description="Web interface for Gentleman AI system"
LABEL version="1.0.0"

# 🔧 Environment Variables
ENV DEBIAN_FRONTEND=noninteractive
ENV PYTHONUNBUFFERED=1
ENV PYTHONDONTWRITEBYTECODE=1
ENV FLASK_ENV=production

# 📦 System Dependencies
RUN apt-get update && apt-get install -y \
    curl \
    wget \
    git \
    && rm -rf /var/lib/apt/lists/*

# 🐍 Python Environment
WORKDIR /app

# 📋 Copy Requirements
COPY requirements.txt .

# 📦 Install Python Dependencies
RUN pip install --no-cache-dir --upgrade pip && \
    pip install --no-cache-dir -r requirements.txt

# 📁 Create Directories
RUN mkdir -p /app/logs /app/config /app/static /app/templates

# 📋 Copy Application Code
COPY . .

# 🔧 Set Permissions
RUN chmod +x *.py && \
    chown -R 1000:1000 /app

# 👤 Use existing user
USER 1000

# 🌐 Expose Port
EXPOSE 8000

# 🏥 Health Check
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
    CMD curl -f http://localhost:8000/health || exit 1

# 🚀 Start Command
CMD ["python", "main.py"] 