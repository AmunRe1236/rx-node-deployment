# 🎩 GENTLEMAN LLM Server - ROCm Optimized Dockerfile
# ═══════════════════════════════════════════════════════════════

FROM rocm/pytorch:rocm5.7_ubuntu20.04_py3.9_pytorch_2.0.1

# 🏷️ Metadata
LABEL maintainer="Gentleman AI Team"
LABEL description="GPU-optimized LLM server for AMD RX 6700 XT"
LABEL version="1.0.0"

# 🔧 Environment Variables
ENV DEBIAN_FRONTEND=noninteractive
ENV PYTHONUNBUFFERED=1
ENV PYTHONDONTWRITEBYTECODE=1
ENV ROCM_VERSION=5.7
ENV HSA_OVERRIDE_GFX_VERSION=10.3.0
ENV HIP_VISIBLE_DEVICES=0
ENV PYTORCH_HIP_ALLOC_CONF=max_split_size_mb:128

# 📦 System Dependencies
RUN apt-get update && apt-get install -y \
    curl \
    wget \
    git \
    build-essential \
    cmake \
    pkg-config \
    libssl-dev \
    libffi-dev \
    libbz2-dev \
    libreadline-dev \
    libsqlite3-dev \
    libncurses5-dev \
    libncursesw5-dev \
    xz-utils \
    tk-dev \
    libxml2-dev \
    libxmlsec1-dev \
    libffi-dev \
    liblzma-dev \
    && rm -rf /var/lib/apt/lists/*

# 🐍 Python Environment
WORKDIR /app

# 📋 Copy Requirements
COPY requirements.txt .

# 📦 Install Python Dependencies
RUN pip install --no-cache-dir --upgrade pip && \
    pip install --no-cache-dir -r requirements.txt

# 🧠 Install ROCm-compatible AI Libraries (ohne CUDA-spezifische Pakete)
RUN pip install --no-cache-dir \
    torchaudio \
    transformers[torch] \
    accelerate \
    datasets \
    tokenizers \
    sentencepiece \
    protobuf \
    safetensors \
    huggingface-hub

# 📁 Create Directories
RUN mkdir -p /app/models /app/logs /app/config /app/temp

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
EXPOSE 8000

# 🏥 Health Check
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
    CMD curl -f http://localhost:8000/health || exit 1

# 🚀 Start Command
CMD ["python", "main.py"] 