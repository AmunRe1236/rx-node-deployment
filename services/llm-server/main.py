#!/usr/bin/env python3
"""
🎩 GENTLEMAN LLM Server - RX 6700 XT GPU-Optimized
═══════════════════════════════════════════════════════════════
FastAPI Server für GPU-beschleunigte LLM Inferenz
"""

import os
import sys
import asyncio
import logging
from typing import Dict, List, Optional, Any
from datetime import datetime
import json

import torch
from fastapi import FastAPI, HTTPException, BackgroundTasks
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
import uvicorn

# Gentleman Modules
from gpu_optimizer import RX6700XTOptimizer
from emotion_analyzer import EmotionAnalyzer

# 🎯 Logging Setup
logging.basicConfig(
    level=logging.INFO,
    format='🎩 %(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger("gentleman-llm")

# 🎩 FastAPI App
app = FastAPI(
    title="🎩 Gentleman LLM Server",
    description="GPU-optimized LLM service for distributed AI pipeline",
    version="1.0.0",
    docs_url="/docs",
    redoc_url="/redoc"
)

# 🌐 CORS Middleware
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# 📊 Global State
class GentlemanState:
    def __init__(self):
        self.gpu_optimizer: Optional[RX6700XTOptimizer] = None
        self.emotion_analyzer: Optional[EmotionAnalyzer] = None
        self.model = None
        self.tokenizer = None
        self.is_ready = False
        self.stats = {
            "requests_total": 0,
            "requests_successful": 0,
            "requests_failed": 0,
            "average_response_time": 0.0,
            "gpu_utilization": 0.0,
            "memory_usage": 0.0
        }

state = GentlemanState()

# 📝 Request/Response Models
class LLMRequest(BaseModel):
    prompt: str
    max_tokens: int = 512
    temperature: float = 0.7
    top_p: float = 0.9
    stream: bool = False
    system_prompt: Optional[str] = None
    emotion_context: Optional[Dict[str, Any]] = None

class LLMResponse(BaseModel):
    text: str
    tokens_used: int
    processing_time: float
    emotion_analysis: Optional[Dict[str, Any]] = None
    gpu_stats: Optional[Dict[str, Any]] = None

class HealthResponse(BaseModel):
    status: str
    gpu_available: bool
    model_loaded: bool
    uptime: float
    stats: Dict[str, Any]

# 🚀 Startup Event
@app.on_event("startup")
async def startup_event():
    """Initialize Gentleman LLM Server"""
    logger.info("🎩 Starting Gentleman LLM Server...")
    
    try:
        # Initialize GPU Optimizer
        logger.info("🔧 Initializing RX 6700 XT optimizer...")
        state.gpu_optimizer = RX6700XTOptimizer()
        await state.gpu_optimizer.initialize()
        
        # Initialize Emotion Analyzer
        logger.info("🎭 Initializing emotion analyzer...")
        state.emotion_analyzer = EmotionAnalyzer()
        await state.emotion_analyzer.initialize()
        
        # Load LLM Model
        logger.info("🧠 Loading LLM model...")
        await load_llm_model()
        
        state.is_ready = True
        logger.info("✅ Gentleman LLM Server ready!")
        
    except Exception as e:
        logger.error(f"❌ Startup failed: {e}")
        sys.exit(1)

async def load_llm_model():
    """Load and optimize LLM model for RX 6700 XT"""
    try:
        model_path = os.getenv("GENTLEMAN_MODEL_PATH", "/app/models")
        model_name = os.getenv("GENTLEMAN_MODEL_NAME", "microsoft/DialoGPT-large")
        
        # Check if GPU is available
        if torch.cuda.is_available():
            device = "cuda"
            logger.info("🚀 Using CUDA GPU acceleration")
        elif hasattr(torch.backends, 'mps') and torch.backends.mps.is_available():
            device = "mps"
            logger.info("🍎 Using MPS (Apple Silicon) acceleration")
        else:
            device = "cpu"
            logger.warning("⚠️ Using CPU - GPU not available")
        
        # Load model with optimizations
        from transformers import AutoTokenizer, AutoModelForCausalLM
        
        state.tokenizer = AutoTokenizer.from_pretrained(model_name)
        state.model = AutoModelForCausalLM.from_pretrained(
            model_name,
            torch_dtype=torch.float16 if device != "cpu" else torch.float32,
            device_map="auto" if device != "cpu" else None,
            trust_remote_code=True
        )
        
        if device != "cpu":
            state.model = state.model.to(device)
        
        # Apply GPU optimizations
        if state.gpu_optimizer and device == "cuda":
            state.model = await state.gpu_optimizer.optimize_model(state.model)
        
        logger.info(f"✅ Model loaded on {device}")
        
    except Exception as e:
        logger.error(f"❌ Model loading failed: {e}")
        raise

# 🎯 Main LLM Endpoint
@app.post("/generate", response_model=LLMResponse)
async def generate_text(request: LLMRequest, background_tasks: BackgroundTasks):
    """Generate text using optimized LLM"""
    if not state.is_ready:
        raise HTTPException(status_code=503, detail="Service not ready")
    
    start_time = datetime.now()
    state.stats["requests_total"] += 1
    
    try:
        # Prepare prompt
        full_prompt = request.prompt
        if request.system_prompt:
            full_prompt = f"{request.system_prompt}\n\nUser: {request.prompt}\nAssistant:"
        
        # Tokenize input
        inputs = state.tokenizer.encode(full_prompt, return_tensors="pt")
        if torch.cuda.is_available():
            inputs = inputs.cuda()
        
        # Generate response
        with torch.no_grad():
            outputs = state.model.generate(
                inputs,
                max_new_tokens=request.max_tokens,
                temperature=request.temperature,
                top_p=request.top_p,
                do_sample=True,
                pad_token_id=state.tokenizer.eos_token_id,
                attention_mask=torch.ones_like(inputs)
            )
        
        # Decode response
        generated_text = state.tokenizer.decode(
            outputs[0][inputs.shape[1]:], 
            skip_special_tokens=True
        )
        
        # Calculate processing time
        processing_time = (datetime.now() - start_time).total_seconds()
        
        # Emotion analysis (if enabled)
        emotion_analysis = None
        if state.emotion_analyzer and request.emotion_context:
            emotion_analysis = await state.emotion_analyzer.analyze_text(
                generated_text, 
                request.emotion_context
            )
        
        # GPU stats
        gpu_stats = None
        if state.gpu_optimizer:
            gpu_stats = await state.gpu_optimizer.get_stats()
        
        # Update stats
        state.stats["requests_successful"] += 1
        state.stats["average_response_time"] = (
            (state.stats["average_response_time"] * (state.stats["requests_successful"] - 1) + processing_time) 
            / state.stats["requests_successful"]
        )
        
        # Background task for cleanup
        background_tasks.add_task(cleanup_gpu_memory)
        
        return LLMResponse(
            text=generated_text.strip(),
            tokens_used=len(outputs[0]),
            processing_time=processing_time,
            emotion_analysis=emotion_analysis,
            gpu_stats=gpu_stats
        )
        
    except Exception as e:
        state.stats["requests_failed"] += 1
        logger.error(f"❌ Generation failed: {e}")
        raise HTTPException(status_code=500, detail=f"Generation failed: {str(e)}")

async def cleanup_gpu_memory():
    """Clean up GPU memory after generation"""
    if torch.cuda.is_available():
        torch.cuda.empty_cache()

# 🏥 Health Check
@app.get("/health", response_model=HealthResponse)
async def health_check():
    """Health check endpoint"""
    uptime = (datetime.now() - datetime.fromtimestamp(0)).total_seconds()  # Simplified
    
    gpu_available = torch.cuda.is_available()
    if gpu_available and state.gpu_optimizer:
        gpu_stats = await state.gpu_optimizer.get_stats()
        state.stats.update({
            "gpu_utilization": gpu_stats.get("utilization", 0.0),
            "memory_usage": gpu_stats.get("memory_usage", 0.0)
        })
    
    return HealthResponse(
        status="healthy" if state.is_ready else "starting",
        gpu_available=gpu_available,
        model_loaded=state.model is not None,
        uptime=uptime,
        stats=state.stats
    )

# 📊 Stats Endpoint
@app.get("/stats")
async def get_stats():
    """Get detailed server statistics"""
    stats = state.stats.copy()
    
    if state.gpu_optimizer:
        gpu_stats = await state.gpu_optimizer.get_stats()
        stats["gpu"] = gpu_stats
    
    if torch.cuda.is_available():
        stats["cuda"] = {
            "device_count": torch.cuda.device_count(),
            "current_device": torch.cuda.current_device(),
            "device_name": torch.cuda.get_device_name(),
            "memory_allocated": torch.cuda.memory_allocated(),
            "memory_reserved": torch.cuda.memory_reserved()
        }
    
    return stats

# 🔧 Configuration Endpoint
@app.get("/config")
async def get_config():
    """Get current server configuration"""
    return {
        "model_name": os.getenv("GENTLEMAN_MODEL_NAME", "microsoft/DialoGPT-large"),
        "model_path": os.getenv("GENTLEMAN_MODEL_PATH", "/app/models"),
        "gpu_enabled": os.getenv("GENTLEMAN_GPU_ENABLED", "false").lower() == "true",
        "rocm_version": os.getenv("ROCM_VERSION", "unknown"),
        "device": "cuda" if torch.cuda.is_available() else "cpu",
        "torch_version": torch.__version__
    }

# 🎭 Emotion Analysis Endpoint
@app.post("/analyze_emotion")
async def analyze_emotion(text: str, context: Optional[Dict[str, Any]] = None):
    """Analyze emotion in text"""
    if not state.emotion_analyzer:
        raise HTTPException(status_code=503, detail="Emotion analyzer not available")
    
    try:
        result = await state.emotion_analyzer.analyze_text(text, context)
        return result
    except Exception as e:
        logger.error(f"❌ Emotion analysis failed: {e}")
        raise HTTPException(status_code=500, detail=f"Analysis failed: {str(e)}")

# 🚀 Main Entry Point
if __name__ == "__main__":
    port = int(os.getenv("GENTLEMAN_PORT", 8000))
    host = os.getenv("GENTLEMAN_HOST", "0.0.0.0")
    
    logger.info(f"🎩 Starting Gentleman LLM Server on {host}:{port}")
    
    uvicorn.run(
        "main:app",
        host=host,
        port=port,
        reload=False,
        log_level="info",
        access_log=True
    ) 