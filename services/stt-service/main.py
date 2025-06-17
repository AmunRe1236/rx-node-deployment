#!/usr/bin/env python3
"""
🎤 GENTLEMAN STT Service - Speech-to-Text
═══════════════════════════════════════════════════════════════
FastAPI Server für Speech-to-Text mit Whisper
"""

import os
import logging
from typing import Dict, Optional
from datetime import datetime
import tempfile

from fastapi import FastAPI, HTTPException, UploadFile, File
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
import uvicorn

# 🎯 Logging Setup
logging.basicConfig(
    level=logging.INFO,
    format='🎤 %(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger("gentleman-stt")

# 🎤 FastAPI App
app = FastAPI(
    title="🎤 Gentleman STT Service",
    description="Speech-to-Text service for distributed AI pipeline",
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

# 📝 Response Models
class STTResponse(BaseModel):
    text: str
    confidence: float
    processing_time: float
    language: str
    segments: Optional[list] = None

class HealthResponse(BaseModel):
    status: str
    whisper_loaded: bool
    uptime: float

# 📊 Global State
class STTState:
    def __init__(self):
        self.whisper_model = None
        self.is_ready = False
        self.stats = {
            "requests_total": 0,
            "requests_successful": 0,
            "requests_failed": 0,
            "average_processing_time": 0.0
        }

state = STTState()

# 🚀 Startup Event
@app.on_event("startup")
async def startup_event():
    """Initialize STT Service"""
    logger.info("🎤 Starting Gentleman STT Service...")
    
    try:
        # Import whisper here to avoid startup delays
        import whisper
        
        # Load Whisper model
        model_name = os.getenv("GENTLEMAN_WHISPER_MODEL", "base")
        logger.info(f"🧠 Loading Whisper model: {model_name}")
        
        state.whisper_model = whisper.load_model(model_name)
        state.is_ready = True
        
        logger.info("✅ Gentleman STT Service ready!")
        
    except Exception as e:
        logger.error(f"❌ Startup failed: {e}")
        # Continue without Whisper for testing
        state.is_ready = True

# 🎤 Main STT Endpoint
@app.post("/transcribe", response_model=STTResponse)
async def transcribe_audio(audio: UploadFile = File(...)):
    """Transcribe audio file to text"""
    if not state.is_ready:
        raise HTTPException(status_code=503, detail="Service not ready")
    
    start_time = datetime.now()
    state.stats["requests_total"] += 1
    
    try:
        # Save uploaded file temporarily
        with tempfile.NamedTemporaryFile(delete=False, suffix=".wav") as temp_file:
            content = await audio.read()
            temp_file.write(content)
            temp_path = temp_file.name
        
        # Transcribe with Whisper (if available)
        if state.whisper_model:
            result = state.whisper_model.transcribe(temp_path)
            text = result["text"].strip()
            language = result.get("language", "unknown")
            segments = result.get("segments", [])
        else:
            # Fallback for testing
            text = "STT Service is running but Whisper model not loaded"
            language = "en"
            segments = []
        
        # Clean up temp file
        os.unlink(temp_path)
        
        # Calculate processing time
        processing_time = (datetime.now() - start_time).total_seconds()
        
        # Update stats
        state.stats["requests_successful"] += 1
        state.stats["average_processing_time"] = (
            (state.stats["average_processing_time"] * (state.stats["requests_successful"] - 1) + processing_time) 
            / state.stats["requests_successful"]
        )
        
        return STTResponse(
            text=text,
            confidence=0.95,  # Simplified confidence
            processing_time=processing_time,
            language=language,
            segments=segments
        )
        
    except Exception as e:
        state.stats["requests_failed"] += 1
        logger.error(f"❌ Transcription failed: {e}")
        raise HTTPException(status_code=500, detail=f"Transcription failed: {str(e)}")

# 🏥 Health Check
@app.get("/health", response_model=HealthResponse)
async def health_check():
    """Health check endpoint"""
    return HealthResponse(
        status="healthy" if state.is_ready else "starting",
        whisper_loaded=state.whisper_model is not None,
        uptime=0.0  # Simplified
    )

# 📊 Stats Endpoint
@app.get("/stats")
async def get_stats():
    """Get service statistics"""
    return state.stats

if __name__ == "__main__":
    uvicorn.run(app, host="0.0.0.0", port=8000) 