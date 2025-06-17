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

import aiohttp
import paho.mqtt.client as mqtt
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
    confidence: float
    timestamp: datetime
    source: str = "voice"

class HACommand(BaseModel):
    entity_id: str
    action: str
    parameters: Optional[Dict[str, Any]] = None

class GentlemanResponse(BaseModel):
    response: str
    action: Optional[HACommand] = None
    tts_required: bool = True

# 🎩 Gentleman HA Bridge
class GentlemanHABridge:
    def __init__(self):
        self.ha_endpoint = "http://homeassistant:8123"
        self.ha_token = None
        self.llm_endpoint = "http://192.168.100.10:8001"
        self.mqtt_client = None
        self.session = None
        
    async def initialize(self):
        """Initialisiere die Bridge"""
        logger.info("🎩 Gentleman HA Bridge startet...")
        
        # HTTP Session
        self.session = aiohttp.ClientSession()
        
        # MQTT Client
        self.mqtt_client = mqtt.Client()
        self.mqtt_client.on_connect = self.on_mqtt_connect
        self.mqtt_client.on_message = self.on_mqtt_message
        
        try:
            self.mqtt_client.connect("mosquitto", 1883, 60)
            self.mqtt_client.loop_start()
            logger.info("✅ MQTT verbunden")
        except Exception as e:
            logger.error(f"❌ MQTT Verbindung fehlgeschlagen: {e}")
            
        logger.info("✅ Gentleman HA Bridge bereit!")
        
    def on_mqtt_connect(self, client, userdata, flags, rc):
        """MQTT Verbindung hergestellt"""
        logger.info(f"🔗 MQTT verbunden mit Code: {rc}")
        
        # Subscribe zu relevanten Topics
        topics = [
            "gentleman/voice/commands",
            "gentleman/intents/+",
            "homeassistant/status"
        ]
        
        for topic in topics:
            client.subscribe(topic)
            logger.info(f"📡 Subscribed zu: {topic}")
            
    def on_mqtt_message(self, client, userdata, msg):
        """MQTT Nachricht empfangen"""
        try:
            topic = msg.topic
            payload = json.loads(msg.payload.decode())
            
            logger.info(f"📨 MQTT: {topic} -> {payload}")
            
            # Verarbeite verschiedene Message Types
            if topic == "gentleman/voice/commands":
                asyncio.create_task(self.process_voice_command(payload))
            elif topic.startswith("gentleman/intents/"):
                intent = topic.split("/")[-1]
                asyncio.create_task(self.process_intent(intent, payload))
                
        except Exception as e:
            logger.error(f"❌ MQTT Message Fehler: {e}")
            
    async def process_voice_command(self, command_data: Dict[str, Any]):
        """Verarbeite Voice Command"""
        try:
            # Sende an Gentleman LLM
            response = await self.query_llm(command_data["text"])
            
            # Analysiere Response für HA Actions
            ha_action = await self.extract_ha_action(response)
            
            if ha_action:
                # Führe HA Action aus
                await self.execute_ha_action(ha_action)
                
            # Sende Response zurück
            await self.send_tts_response(response)
            
        except Exception as e:
            logger.error(f"❌ Voice Command Fehler: {e}")
            
    async def query_llm(self, text: str) -> str:
        """Query Gentleman LLM"""
        try:
            payload = {
                "text": text,
                "context": {
                    "source": "home_assistant",
                    "timestamp": datetime.now().isoformat()
                }
            }
            
            async with self.session.post(
                f"{self.llm_endpoint}/generate",
                json=payload
            ) as response:
                if response.status == 200:
                    data = await response.json()
                    return data["response"]
                else:
                    logger.error(f"❌ LLM Query Fehler: {response.status}")
                    return "Entschuldigung, ich konnte Ihre Anfrage nicht verarbeiten."
                    
        except Exception as e:
            logger.error(f"❌ LLM Query Exception: {e}")
            return "Es gab ein technisches Problem."
            
    async def extract_ha_action(self, response: str) -> Optional[HACommand]:
        """Extrahiere Home Assistant Action aus Response"""
        # Einfache Intent-Erkennung
        response_lower = response.lower()
        
        # Licht-Steuerung
        if "licht" in response_lower and "an" in response_lower:
            return HACommand(
                entity_id="light.wohnzimmer",
                action="turn_on"
            )
        elif "licht" in response_lower and "aus" in response_lower:
            return HACommand(
                entity_id="light.wohnzimmer", 
                action="turn_off"
            )
            
        # Heizung
        elif "heizung" in response_lower:
            if "höher" in response_lower or "wärmer" in response_lower:
                return HACommand(
                    entity_id="climate.wohnzimmer",
                    action="set_temperature",
                    parameters={"temperature": 22}
                )
                
        return None
        
    async def execute_ha_action(self, action: HACommand):
        """Führe Home Assistant Action aus"""
        try:
            headers = {
                "Authorization": f"Bearer {self.ha_token}",
                "Content-Type": "application/json"
            }
            
            # Baue HA Service Call
            service_parts = action.action.split("_")
            domain = action.entity_id.split(".")[0]
            service = "_".join(service_parts)
            
            payload = {
                "entity_id": action.entity_id
            }
            
            if action.parameters:
                payload.update(action.parameters)
                
            url = f"{self.ha_endpoint}/api/services/{domain}/{service}"
            
            async with self.session.post(url, json=payload, headers=headers) as response:
                if response.status == 200:
                    logger.info(f"✅ HA Action ausgeführt: {action.entity_id} -> {action.action}")
                else:
                    logger.error(f"❌ HA Action Fehler: {response.status}")
                    
        except Exception as e:
            logger.error(f"❌ HA Action Exception: {e}")
            
    async def send_tts_response(self, text: str):
        """Sende TTS Response"""
        try:
            # Publiziere zu TTS Topic
            tts_payload = {
                "text": text,
                "voice": "neural_german_female",
                "timestamp": datetime.now().isoformat()
            }
            
            self.mqtt_client.publish(
                "gentleman/tts/requests",
                json.dumps(tts_payload)
            )
            
            logger.info(f"🔊 TTS Request gesendet: {text[:50]}...")
            
        except Exception as e:
            logger.error(f"❌ TTS Response Fehler: {e}")
            
    async def process_intent(self, intent: str, data: Dict[str, Any]):
        """Verarbeite erkannten Intent"""
        logger.info(f"🎯 Intent erkannt: {intent}")
        
        if intent == "smart_home_control":
            await self.handle_smart_home_intent(data)
        elif intent == "information_request":
            await self.handle_information_intent(data)
        elif intent == "media_control":
            await self.handle_media_intent(data)
            
    async def handle_smart_home_intent(self, data: Dict[str, Any]):
        """Handle Smart Home Control Intent"""
        # Implementiere Smart Home Logik
        pass
        
    async def handle_information_intent(self, data: Dict[str, Any]):
        """Handle Information Request Intent"""
        # Implementiere Information Logik
        pass
        
    async def handle_media_intent(self, data: Dict[str, Any]):
        """Handle Media Control Intent"""
        # Implementiere Media Control Logik
        pass

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
    await bridge.initialize()

@app.post("/voice_command")
async def voice_command(command: VoiceCommand):
    """Empfange Voice Command von HA"""
    await bridge.process_voice_command(command.dict())
    return {"status": "processed"}

@app.get("/health")
async def health_check():
    """Health Check"""
    return {
        "status": "healthy",
        "service": "gentleman-ha-bridge",
        "timestamp": datetime.now().isoformat()
    }

@app.get("/")
async def root():
    """Root Endpoint"""
    return {
        "service": "🎩 Gentleman HA Bridge",
        "version": "1.0.0",
        "status": "running"
    }

if __name__ == "__main__":
    uvicorn.run(app, host="0.0.0.0", port=8000, log_level="info") 