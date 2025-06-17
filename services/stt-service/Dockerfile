# 🎩 GENTLEMAN STT Service - Standard Linux Dockerfile
# ═══════════════════════════════════════════════════════════════

FROM python:3.9-slim

# 🏷️ Metadata
LABEL maintainer="Gentleman AI Team"
LABEL description="Speech-to-Text service for Gentleman AI"
LABEL version="1.0.0"

# 🔧 Environment Variables
ENV DEBIAN_FRONTEND=noninteractive
ENV PYTHONUNBUFFERED=1
ENV PYTHONDONTWRITEBYTECODE=1

# 📦 System Dependencies
RUN apt-get update && apt-get install -y \
    curl \
    wget \
    git \
    build-essential \
    ffmpeg \
    portaudio19-dev \
    python3-pyaudio \
    && rm -rf /var/lib/apt/lists/*

# 🐍 Python Environment
WORKDIR /app

# 📋 Copy Requirements
COPY requirements.txt .

# 📦 Install Python Dependencies
RUN pip install --no-cache-dir --upgrade pip && \
    pip install --no-cache-dir -r requirements.txt

# 🎤 Install Speech Recognition Libraries
RUN pip install --no-cache-dir \
    openai-whisper \
    SpeechRecognition \
    pyaudio \
    pydub \
    librosa \
    soundfile

# 📁 Create Directories
RUN mkdir -p /app/models /app/logs /app/temp /app/uploads

# 📋 Copy Application Code
COPY . .

# 🔧 Set Permissions
RUN chmod +x *.py && \
    chown -R 1000:1000 /app

# 👤 Use existing user or create new one
RUN id -u 1000 >/dev/null 2>&1 || useradd -m -u 1000 gentleman && \
    chown -R $(id -un 1000):$(id -gn 1000) /app

USER 1000

# 🌐 Expose Port
EXPOSE 8001

# 🏥 Health Check
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
    CMD curl -f http://localhost:8001/health || exit 1

# 🚀 Start Command
CMD ["python", "main.py"] 