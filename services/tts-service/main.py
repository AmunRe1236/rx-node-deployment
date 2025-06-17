#!/usr/bin/env python3
"""
🗣️ GENTLEMAN TTS Service - Text-to-Speech
═══════════════════════════════════════════════════════════════
FastAPI Server für Text-to-Speech
"""

import os
import logging
from typing import Dict, Optional
from datetime import datetime
import tempfile
import io

from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import StreamingResponse
from pydantic import BaseModel
import uvicorn

# 🎯 Logging Setup
logging.basicConfig(
    level=logging.INFO,
    format='🗣️ %(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger("gentleman-tts")

# 🗣️ FastAPI App
app = FastAPI(
    title="🗣️ Gentleman TTS Service",
    description="Text-to-Speech service for distributed AI pipeline",
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

# 📝 Request/Response Models
class TTSRequest(BaseModel):
    text: str
    voice: str = "default"
    speed: float = 1.0
    emotion: Optional[str] = None

class TTSResponse(BaseModel):
    success: bool
    processing_time: float
    audio_length: float
    voice_used: str

class HealthResponse(BaseModel):
    status: str
    tts_engine_loaded: bool
    uptime: float

# 📊 Global State
class TTSState:
    def __init__(self):
        self.tts_engine = None
        self.is_ready = False
        self.stats = {
            "requests_total": 0,
            "requests_successful": 0,
            "requests_failed": 0,
            "average_processing_time": 0.0
        }

state = TTSState()

# 🚀 Startup Event
@app.on_event("startup")
async def startup_event():
    """Initialize TTS Service"""
    logger.info("🗣️ Starting Gentleman TTS Service...")
    
    try:
        # Try to import and initialize TTS engine
        try:
            import pyttsx3
            state.tts_engine = pyttsx3.init()
            logger.info("✅ pyttsx3 TTS engine loaded")
        except Exception as e:
            logger.warning(f"⚠️ pyttsx3 not available: {e}")
            state.tts_engine = None
        
        state.is_ready = True
        logger.info("✅ Gentleman TTS Service ready!")
        
    except Exception as e:
        logger.error(f"❌ Startup failed: {e}")
        state.is_ready = True  # Continue for testing

# 🗣️ Main TTS Endpoint
@app.post("/synthesize")
async def synthesize_speech(request: TTSRequest):
    """Convert text to speech"""
    if not state.is_ready:
        raise HTTPException(status_code=503, detail="Service not ready")
    
    start_time = datetime.now()
    state.stats["requests_total"] += 1
    
    try:
        # Generate speech audio
        if state.tts_engine:
            # Use pyttsx3 for local TTS
            with tempfile.NamedTemporaryFile(delete=False, suffix=".wav") as temp_file:
                state.tts_engine.save_to_file(request.text, temp_file.name)
                state.tts_engine.runAndWait()
                
                # Read the generated audio file
                with open(temp_file.name, "rb") as audio_file:
                    audio_data = audio_file.read()
                
                os.unlink(temp_file.name)
        else:
            # Fallback: Generate silence for testing
            import wave
            with tempfile.NamedTemporaryFile(delete=False, suffix=".wav") as temp_file:
                with wave.open(temp_file.name, 'wb') as wav_file:
                    wav_file.setnchannels(1)  # Mono
                    wav_file.setsampwidth(2)  # 16-bit
                    wav_file.setframerate(22050)  # Sample rate
                    # Generate 1 second of silence
                    silence = b'\x00\x00' * 22050
                    wav_file.writeframes(silence)
                
                with open(temp_file.name, "rb") as audio_file:
                    audio_data = audio_file.read()
                
                os.unlink(temp_file.name)
        
        # Calculate processing time
        processing_time = (datetime.now() - start_time).total_seconds()
        
        # Update stats
        state.stats["requests_successful"] += 1
        state.stats["average_processing_time"] = (
            (state.stats["average_processing_time"] * (state.stats["requests_successful"] - 1) + processing_time) 
            / state.stats["requests_successful"]
        )
        
        # Return audio as streaming response
        return StreamingResponse(
            io.BytesIO(audio_data),
            media_type="audio/wav",
            headers={
                "Content-Disposition": "attachment; filename=speech.wav",
                "X-Processing-Time": str(processing_time),
                "X-Voice-Used": request.voice
            }
        )
        
    except Exception as e:
        state.stats["requests_failed"] += 1
        logger.error(f"❌ Speech synthesis failed: {e}")
        raise HTTPException(status_code=500, detail=f"Speech synthesis failed: {str(e)}")

# 🏥 Health Check
@app.get("/health", response_model=HealthResponse)
async def health_check():
    """Health check endpoint"""
    return HealthResponse(
        status="healthy" if state.is_ready else "starting",
        tts_engine_loaded=state.tts_engine is not None,
        uptime=0.0  # Simplified
    )

# 📊 Stats Endpoint
@app.get("/stats")
async def get_stats():
    """Get service statistics"""
    return state.stats

# 🎵 Available Voices
@app.get("/voices")
async def get_voices():
    """Get available TTS voices"""
    if state.tts_engine:
        try:
            voices = state.tts_engine.getProperty('voices')
            return {
                "voices": [{"id": voice.id, "name": voice.name} for voice in voices] if voices else [],
                "default": "default"
            }
        except:
            pass
    
    return {
        "voices": [{"id": "default", "name": "Default Voice"}],
        "default": "default"
    }

if __name__ == "__main__":
    uvicorn.run(app, host="0.0.0.0", port=8000) 