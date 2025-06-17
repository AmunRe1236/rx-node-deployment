#!/usr/bin/env python3
"""
🎩 GENTLEMAN - Home Assistant Bridge
═══════════════════════════════════════════════════════════════
Bridge Service zwischen Gentleman AI und Home Assistant
"""

import asyncio
import json
import logging
from datetime import datetime
from typing import Dict, Any, Optional

from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
import uvicorn

# 🎯 Logging Setup
logging.basicConfig(
    level=logging.INFO,
    format='🎩 %(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger("gentleman-ha-bridge")

# 📝 Models
class VoiceCommand(BaseModel):
    text: str
    confidence: float = 0.9
    source: str = "voice"

class HACommand(BaseModel):
    entity_id: str
    action: str
    parameters: Optional[Dict[str, Any]] = None

# 🎩 Gentleman HA Bridge
class GentlemanHABridge:
    def __init__(self):
        self.ha_endpoint = "http://homeassistant:8123"
        self.llm_endpoint = "http://192.168.100.10:8001"
        
    async def process_voice_command(self, text: str) -> Dict[str, Any]:
        """Verarbeite Voice Command"""
        try:
            # Simuliere LLM Response für Demo
            response = await self.simulate_llm_response(text)
            
            # Analysiere für HA Actions
            ha_action = self.extract_ha_action(text)
            
            result = {
                "response": response,
                "ha_action": ha_action,
                "processed_at": datetime.now().isoformat()
            }
            
            logger.info(f"✅ Voice Command verarbeitet: {text[:50]}...")
            return result
            
        except Exception as e:
            logger.error(f"❌ Voice Command Fehler: {e}")
            raise HTTPException(status_code=500, detail=str(e))
            
    async def simulate_llm_response(self, text: str) -> str:
        """Simuliere LLM Response"""
        text_lower = text.lower()
        
        if "licht" in text_lower:
            if "an" in text_lower:
                return "Gerne! Ich schalte das Licht für Sie an."
            elif "aus" in text_lower:
                return "Das Licht wird ausgeschaltet."
        elif "heizung" in text_lower:
            return "Ich stelle die Heizung für Sie ein."
        elif "musik" in text_lower:
            return "Ich starte die Musik für Sie."
        elif "wetter" in text_lower:
            return "Das aktuelle Wetter: 22°C, sonnig mit leichten Wolken."
        else:
            return f"Ich habe verstanden: '{text}'. Wie kann ich Ihnen helfen?"
            
    def extract_ha_action(self, text: str) -> Optional[Dict[str, Any]]:
        """Extrahiere Home Assistant Action"""
        text_lower = text.lower()
        
        # Licht-Steuerung
        if "licht" in text_lower:
            if "an" in text_lower:
                return {
                    "entity_id": "light.wohnzimmer",
                    "action": "turn_on"
                }
            elif "aus" in text_lower:
                return {
                    "entity_id": "light.wohnzimmer",
                    "action": "turn_off"
                }
                
        # Heizung
        elif "heizung" in text_lower:
            return {
                "entity_id": "climate.wohnzimmer",
                "action": "set_temperature",
                "parameters": {"temperature": 22}
            }
            
        # Musik
        elif "musik" in text_lower:
            if "an" in text_lower or "start" in text_lower:
                return {
                    "entity_id": "media_player.wohnzimmer",
                    "action": "media_play"
                }
            elif "aus" in text_lower or "stopp" in text_lower:
                return {
                    "entity_id": "media_player.wohnzimmer", 
                    "action": "media_pause"
                }
                
        return None

# 🚀 FastAPI App
app = FastAPI(
    title="🎩 Gentleman HA Bridge",
    description="Bridge zwischen Gentleman AI und Home Assistant",
    version="1.0.0"
)

# Global Bridge Instance
bridge = GentlemanHABridge()

@app.on_event("startup")
async def startup_event():
    logger.info("🎩 Gentleman HA Bridge startet...")
    logger.info("✅ Bridge bereit!")

@app.post("/voice_command")
async def voice_command(command: VoiceCommand):
    """Empfange Voice Command"""
    result = await bridge.process_voice_command(command.text)
    return result

@app.post("/process_ha_command")
async def process_ha_command(data: Dict[str, Any]):
    """Verarbeite HA Command"""
    command = data.get("command", "")
    result = await bridge.process_voice_command(command)
    return result

@app.get("/health")
async def health_check():
    """Health Check"""
    return {
        "status": "healthy",
        "service": "gentleman-ha-bridge",
        "timestamp": datetime.now().isoformat(),
        "endpoints": {
            "voice_command": "/voice_command",
            "process_ha_command": "/process_ha_command",
            "health": "/health"
        }
    }

@app.get("/")
async def root():
    """Root Endpoint"""
    return {
        "service": "🎩 Gentleman HA Bridge",
        "version": "1.0.0",
        "status": "running",
        "description": "Bridge zwischen Gentleman AI und Home Assistant"
    }

if __name__ == "__main__":
    print("🎩 Gentleman HA Bridge")
    print("═══════════════════════════════════════════════════════════════")
    print("🚀 Server startet auf http://0.0.0.0:8000")
    print("═══════════════════════════════════════════════════════════════")
    
    uvicorn.run(app, host="0.0.0.0", port=8000, log_level="info") 