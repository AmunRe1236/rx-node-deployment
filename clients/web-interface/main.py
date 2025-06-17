#!/usr/bin/env python3
"""
🌐 GENTLEMAN Web Interface
═══════════════════════════════════════════════════════════════
Web-Interface für das Gentleman AI System
"""

import os
import logging
from typing import Dict, Optional
from datetime import datetime

from fastapi import FastAPI, HTTPException, Request, Form
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import HTMLResponse
from fastapi.staticfiles import StaticFiles
from fastapi.templating import Jinja2Templates
from pydantic import BaseModel
import uvicorn
import httpx

# 🎯 Logging Setup
logging.basicConfig(
    level=logging.INFO,
    format='🌐 %(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger("gentleman-web")

# 🌐 FastAPI App
app = FastAPI(
    title="🌐 Gentleman Web Interface",
    description="Web interface for Gentleman AI system",
    version="1.0.0"
)

# 🌐 CORS Middleware
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# 📁 Static Files and Templates
app.mount("/static", StaticFiles(directory="static"), name="static")
templates = Jinja2Templates(directory="templates")

# 📝 Models
class ChatRequest(BaseModel):
    message: str

class HealthResponse(BaseModel):
    status: str
    services_status: Dict
    uptime: float

# 📊 Global State
class WebState:
    def __init__(self):
        self.is_ready = False
        self.start_time = datetime.now()
        self.services = {
            "llm-server": "http://172.20.1.10:8000",
            "stt-service": "http://172.20.1.20:8000",
            "tts-service": "http://172.20.1.30:8000",
            "mesh-coordinator": "http://172.20.1.40:8000"
        }
        self.stats = {
            "requests_total": 0,
            "chat_messages": 0,
            "successful_responses": 0
        }

state = WebState()

# 🚀 Startup Event
@app.on_event("startup")
async def startup_event():
    """Initialize Web Interface"""
    logger.info("🌐 Starting Gentleman Web Interface...")
    
    try:
        state.is_ready = True
        logger.info("✅ Gentleman Web Interface ready!")
        
    except Exception as e:
        logger.error(f"❌ Startup failed: {e}")
        state.is_ready = True

# 🏠 Main Pages
@app.get("/", response_class=HTMLResponse)
async def home(request: Request):
    """Main dashboard page"""
    return templates.TemplateResponse("index.html", {
        "request": request,
        "title": "🎩 Gentleman AI Dashboard",
        "services": state.services
    })

@app.get("/chat", response_class=HTMLResponse)
async def chat_page(request: Request):
    """Chat interface page"""
    return templates.TemplateResponse("chat.html", {
        "request": request,
        "title": "💬 Gentleman AI Chat"
    })

@app.get("/status", response_class=HTMLResponse)
async def status_page(request: Request):
    """System status page"""
    # Check service health
    services_status = {}
    async with httpx.AsyncClient(timeout=5.0) as client:
        for name, url in state.services.items():
            try:
                response = await client.get(f"{url}/health")
                services_status[name] = "healthy" if response.status_code == 200 else "unhealthy"
            except:
                services_status[name] = "unreachable"
    
    return templates.TemplateResponse("status.html", {
        "request": request,
        "title": "📊 System Status",
        "services_status": services_status,
        "stats": state.stats
    })

# 💬 Chat API
@app.post("/api/chat")
async def chat_api(request: ChatRequest):
    """Process chat message through LLM"""
    state.stats["requests_total"] += 1
    state.stats["chat_messages"] += 1
    
    try:
        # Send message to LLM server
        async with httpx.AsyncClient(timeout=30.0) as client:
            llm_response = await client.post(
                f"{state.services['llm-server']}/generate",
                json={
                    "prompt": request.message,
                    "max_tokens": 512,
                    "temperature": 0.7
                }
            )
            
            if llm_response.status_code == 200:
                result = llm_response.json()
                state.stats["successful_responses"] += 1
                return {
                    "success": True,
                    "response": result.get("text", "No response generated"),
                    "processing_time": result.get("processing_time", 0),
                    "tokens_used": result.get("tokens_used", 0)
                }
            else:
                return {
                    "success": False,
                    "error": f"LLM server error: {llm_response.status_code}"
                }
                
    except Exception as e:
        logger.error(f"❌ Chat API error: {e}")
        return {
            "success": False,
            "error": f"Chat processing failed: {str(e)}"
        }

# 🎤 STT API
@app.post("/api/transcribe")
async def transcribe_api():
    """Transcribe audio to text"""
    # Placeholder for STT integration
    return {
        "success": True,
        "text": "STT integration coming soon",
        "confidence": 0.0
    }

# 🗣️ TTS API
@app.post("/api/synthesize")
async def synthesize_api(text: str = Form(...)):
    """Convert text to speech"""
    try:
        async with httpx.AsyncClient(timeout=30.0) as client:
            tts_response = await client.post(
                f"{state.services['tts-service']}/synthesize",
                json={"text": text}
            )
            
            if tts_response.status_code == 200:
                return {
                    "success": True,
                    "message": "Audio generated successfully"
                }
            else:
                return {
                    "success": False,
                    "error": f"TTS server error: {tts_response.status_code}"
                }
                
    except Exception as e:
        logger.error(f"❌ TTS API error: {e}")
        return {
            "success": False,
            "error": f"TTS processing failed: {str(e)}"
        }

# 🏥 Health Check
@app.get("/health", response_model=HealthResponse)
async def health_check():
    """Health check endpoint"""
    services_status = {}
    
    async with httpx.AsyncClient(timeout=5.0) as client:
        for name, url in state.services.items():
            try:
                response = await client.get(f"{url}/health")
                services_status[name] = "healthy" if response.status_code == 200 else "unhealthy"
            except:
                services_status[name] = "unreachable"
    
    return HealthResponse(
        status="healthy" if state.is_ready else "starting",
        services_status=services_status,
        uptime=(datetime.now() - state.start_time).total_seconds()
    )

# 📊 Stats API
@app.get("/api/stats")
async def get_stats():
    """Get web interface statistics"""
    return state.stats

if __name__ == "__main__":
    uvicorn.run(app, host="0.0.0.0", port=8000) 