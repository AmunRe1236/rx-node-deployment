# 🎩 GENTLEMAN - Proton Mail Service Dockerfile
# ═══════════════════════════════════════════════════════════════

FROM python:3.11-slim

# 📦 System Dependencies
RUN apt-get update && apt-get install -y \
    curl \
    && rm -rf /var/lib/apt/lists/*

# 📁 Working Directory
WORKDIR /app

# 📋 Python Dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# 📧 Application Code
COPY app.py .

# 🔧 Configuration
RUN mkdir -p /app/config /app/data /app/logs

# 🚀 Startup
EXPOSE 8000

# 👤 Non-root User
RUN useradd -m -u 1000 gentleman && \
    chown -R gentleman:gentleman /app
USER gentleman

# 🎯 Health Check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:8000/health || exit 1

# 🚀 Start Command
CMD ["python", "app.py"] 