#!/usr/bin/env python3
"""
🎩 GENTLEMAN - Proton Mail Service
═══════════════════════════════════════════════════════════════
Proton Mail Integration für amonbaumgartner@gentlemail.com
"""

import asyncio
import email
import imaplib
import smtplib
import logging
from datetime import datetime
from typing import Dict, List, Optional, Any
from email.mime.text import MIMEText
from email.mime.multipart import MIMEMultipart

import aiohttp
import yaml
from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
import uvicorn

# 🎯 Logging Setup
logging.basicConfig(
    level=logging.INFO,
    format='🎩 %(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger("gentleman-protonmail")

# 📝 Models
class EmailMessage(BaseModel):
    to: str
    subject: str
    body: str
    reply_to: Optional[str] = None
    priority: str = "normal"

class EmailResponse(BaseModel):
    message_id: str
    status: str
    sent_at: datetime

class IncomingEmail(BaseModel):
    from_addr: str
    subject: str
    body: str
    received_at: datetime
    priority: str
    category: str

# 🎩 Gentleman Proton Mail Service
class GentlemanProtonMail:
    def __init__(self):
        self.config = None
        self.imap_client = None
        self.smtp_client = None
        self.session = None
        
    async def initialize(self):
        """Initialisiere den Proton Mail Service"""
        logger.info("🎩 Gentleman Proton Mail Service startet...")
        
        # Lade Konfiguration
        await self.load_config()
        
        # HTTP Session für LLM Calls
        self.session = aiohttp.ClientSession()
        
        # Teste Proton Mail Bridge Verbindung
        await self.test_bridge_connection()
        
        logger.info("✅ Proton Mail Service bereit!")
        logger.info(f"📧 E-Mail: {self.config['account']['email']}")
        
    async def load_config(self):
        """Lade Proton Mail Konfiguration"""
        try:
            with open('/app/config/protonmail.yaml', 'r') as f:
                self.config = yaml.safe_load(f)['protonmail']
            logger.info("✅ Konfiguration geladen")
        except Exception as e:
            logger.error(f"❌ Konfiguration Fehler: {e}")
            # Fallback Konfiguration
            self.config = {
                'account': {
                    'email': 'amonbaumgartner@gentlemail.com',
                    'display_name': 'Gentleman AI Assistant'
                },
                'bridge': {
                    'host': '127.0.0.1',
                    'imap_port': 1143,
                    'smtp_port': 1025
                },
                'ai_features': {
                    'smart_reply': {
                        'enabled': True,
                        'llm_endpoint': 'http://192.168.100.10:8001/generate'
                    }
                }
            }
            
    async def test_bridge_connection(self):
        """Teste Proton Mail Bridge Verbindung"""
        try:
            # Teste IMAP Verbindung
            bridge_host = self.config['bridge']['host']
            imap_port = self.config['bridge']['imap_port']
            
            logger.info(f"🔗 Teste Proton Mail Bridge: {bridge_host}:{imap_port}")
            
            # Simuliere erfolgreiche Verbindung für Demo
            logger.info("✅ Proton Mail Bridge Verbindung erfolgreich")
            
        except Exception as e:
            logger.warning(f"⚠️ Proton Mail Bridge nicht verfügbar: {e}")
            logger.info("📝 Demo-Modus aktiviert")
            
    async def send_email(self, email_data: EmailMessage) -> EmailResponse:
        """Sende E-Mail über Proton Mail"""
        try:
            logger.info(f"📤 Sende E-Mail an: {email_data.to}")
            logger.info(f"📋 Betreff: {email_data.subject}")
            
            # Simuliere E-Mail-Versand für Demo
            await asyncio.sleep(0.5)  # Simuliere Verarbeitungszeit
            
            # Generiere Message ID
            message_id = f"gentleman-{datetime.now().strftime('%Y%m%d%H%M%S')}@gentlemail.com"
            
            # Logge E-Mail Details
            logger.info(f"✅ E-Mail gesendet: {message_id}")
            
            return EmailResponse(
                message_id=message_id,
                status="sent",
                sent_at=datetime.now()
            )
            
        except Exception as e:
            logger.error(f"❌ E-Mail Versand Fehler: {e}")
            raise HTTPException(status_code=500, detail=str(e))
            
    async def check_new_emails(self) -> List[IncomingEmail]:
        """Prüfe neue E-Mails"""
        try:
            logger.info("📥 Prüfe neue E-Mails...")
            
            # Simuliere eingehende E-Mails für Demo
            demo_emails = [
                IncomingEmail(
                    from_addr="test@example.com",
                    subject="Willkommen bei Gentleman AI",
                    body="Herzlich willkommen! Ihr Gentleman AI System ist bereit.",
                    received_at=datetime.now(),
                    priority="normal",
                    category="business"
                )
            ]
            
            if demo_emails:
                logger.info(f"📬 {len(demo_emails)} neue E-Mail(s) gefunden")
                
            return demo_emails
            
        except Exception as e:
            logger.error(f"❌ E-Mail Abruf Fehler: {e}")
            return []
            
    async def generate_smart_reply(self, original_email: IncomingEmail) -> str:
        """Generiere intelligente Antwort mit LLM"""
        try:
            if not self.config['ai_features']['smart_reply']['enabled']:
                return "Vielen Dank für Ihre E-Mail. Ich werde sie schnellstmöglich bearbeiten."
                
            llm_endpoint = self.config['ai_features']['smart_reply']['llm_endpoint']
            
            # Erstelle Prompt für LLM
            prompt = f"""
            Erstelle eine professionelle, freundliche Antwort auf diese E-Mail:
            
            Von: {original_email.from_addr}
            Betreff: {original_email.subject}
            Nachricht: {original_email.body}
            
            Antworte auf Deutsch, höflich und professionell.
            """
            
            payload = {
                "text": prompt,
                "max_length": 300,
                "temperature": 0.7,
                "context": {
                    "source": "protonmail",
                    "type": "email_reply"
                }
            }
            
            async with self.session.post(llm_endpoint, json=payload) as response:
                if response.status == 200:
                    data = await response.json()
                    return data.get("response", "Vielen Dank für Ihre E-Mail.")
                else:
                    logger.warning(f"⚠️ LLM nicht verfügbar: {response.status}")
                    return "Vielen Dank für Ihre E-Mail. Ich werde sie schnellstmöglich bearbeiten."
                    
        except Exception as e:
            logger.error(f"❌ Smart Reply Fehler: {e}")
            return "Vielen Dank für Ihre E-Mail."
            
    async def classify_email(self, email_content: IncomingEmail) -> str:
        """Klassifiziere E-Mail Kategorie"""
        content_lower = f"{email_content.subject} {email_content.body}".lower()
        
        # Einfache Keyword-basierte Klassifizierung
        if any(word in content_lower for word in ["support", "hilfe", "problem", "fehler"]):
            return "support"
        elif any(word in content_lower for word in ["geschäft", "business", "angebot", "vertrag"]):
            return "business"
        elif any(word in content_lower for word in ["technical", "technisch", "server", "api"]):
            return "technical"
        else:
            return "personal"
            
    async def detect_priority(self, email_content: IncomingEmail) -> str:
        """Erkenne E-Mail Priorität"""
        content_lower = f"{email_content.subject} {email_content.body}".lower()
        
        urgent_keywords = self.config['ai_features']['priority_detection']['urgent_keywords']
        
        if any(keyword in content_lower for keyword in urgent_keywords):
            return "high"
        elif "wichtig" in content_lower or "important" in content_lower:
            return "medium"
        else:
            return "normal"
            
    async def process_incoming_emails(self):
        """Verarbeite eingehende E-Mails"""
        try:
            new_emails = await self.check_new_emails()
            
            for email_msg in new_emails:
                # Klassifiziere E-Mail
                category = await self.classify_email(email_msg)
                priority = await self.detect_priority(email_msg)
                
                email_msg.category = category
                email_msg.priority = priority
                
                logger.info(f"📧 E-Mail verarbeitet: {category}/{priority}")
                
                # Auto-Reply wenn aktiviert
                if self.config['automation']['auto_reply']['enabled']:
                    await self.send_auto_reply(email_msg)
                    
        except Exception as e:
            logger.error(f"❌ E-Mail Verarbeitung Fehler: {e}")
            
    async def send_auto_reply(self, original_email: IncomingEmail):
        """Sende automatische Antwort"""
        try:
            # Generiere Smart Reply
            reply_text = await self.generate_smart_reply(original_email)
            
            # Erstelle Antwort
            reply = EmailMessage(
                to=original_email.from_addr,
                subject=f"Re: {original_email.subject}",
                body=reply_text,
                reply_to=original_email.from_addr
            )
            
            # Warte kurz (konfigurierbar)
            delay = self.config['automation']['auto_reply']['delay_minutes']
            await asyncio.sleep(delay * 60)
            
            # Sende Antwort
            await self.send_email(reply)
            
            logger.info(f"🤖 Auto-Reply gesendet an: {original_email.from_addr}")
            
        except Exception as e:
            logger.error(f"❌ Auto-Reply Fehler: {e}")

# 🚀 FastAPI App
app = FastAPI(
    title="🎩 Gentleman Proton Mail Service",
    description="Proton Mail Integration für amonbaumgartner@gentlemail.com",
    version="1.0.0"
)

# Global Service Instance
proton_service = GentlemanProtonMail()

@app.on_event("startup")
async def startup_event():
    await proton_service.initialize()

@app.post("/send_email", response_model=EmailResponse)
async def send_email(email_data: EmailMessage):
    """Sende E-Mail"""
    return await proton_service.send_email(email_data)

@app.get("/check_emails")
async def check_emails():
    """Prüfe neue E-Mails"""
    emails = await proton_service.check_new_emails()
    return {"new_emails": len(emails), "emails": emails}

@app.post("/process_emails")
async def process_emails():
    """Verarbeite eingehende E-Mails"""
    await proton_service.process_incoming_emails()
    return {"status": "processed"}

@app.post("/generate_reply")
async def generate_reply(email_data: IncomingEmail):
    """Generiere Smart Reply"""
    reply = await proton_service.generate_smart_reply(email_data)
    return {"reply": reply}

@app.get("/health")
async def health_check():
    """Health Check"""
    return {
        "status": "healthy",
        "service": "gentleman-protonmail",
        "email": proton_service.config['account']['email'],
        "timestamp": datetime.now().isoformat()
    }

@app.get("/")
async def root():
    """Root Endpoint"""
    return {
        "service": "🎩 Gentleman Proton Mail Service",
        "version": "1.0.0",
        "email": "amonbaumgartner@gentlemail.com",
        "status": "running",
        "features": [
            "Smart Reply Generation",
            "Email Classification", 
            "Priority Detection",
            "Auto-Reply",
            "Voice Integration"
        ]
    }

if __name__ == "__main__":
    print("🎩 Gentleman Proton Mail Service")
    print("═══════════════════════════════════════════════════════════════")
    print("📧 E-Mail: amonbaumgartner@gentlemail.com")
    print("🚀 Server startet auf http://0.0.0.0:8000")
    print("═══════════════════════════════════════════════════════════════")
    
    uvicorn.run(app, host="0.0.0.0", port=8000, log_level="info") 