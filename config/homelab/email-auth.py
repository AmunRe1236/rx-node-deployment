#!/usr/bin/env python3
"""
🎩 GENTLEMAN E-Mail Authentication Service
═══════════════════════════════════════════════════════════════
ProtonMail-basierte Authentifizierung wie Google Account
"""

import os
import time
import uuid
import hashlib
import smtplib
import logging
from datetime import datetime, timedelta
from typing import Dict, List, Optional, Any
from email.mime.text import MIMEText
from email.mime.multipart import MIMEMultipart

import requests
from fastapi import FastAPI, HTTPException, Request, Form
from fastapi.responses import HTMLResponse, RedirectResponse
from pydantic import BaseModel, EmailStr
import uvicorn

# 🎯 Logging Setup
logging.basicConfig(
    level=logging.INFO,
    format='🎩 %(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger("gentleman-email-auth")

# 📝 Models
class EmailAuthRequest(BaseModel):
    email: EmailStr
    service: Optional[str] = "homelab"
    redirect_url: Optional[str] = None

class MagicLinkRequest(BaseModel):
    email: EmailStr
    action: str = "login"  # login, register, reset_password

class EmailVerificationRequest(BaseModel):
    email: EmailStr
    verification_code: str

# 🎩 GENTLEMAN E-Mail Authentication Service
class GentlemanEmailAuth:
    def __init__(self):
        self.keycloak_url = os.getenv('KEYCLOAK_URL', 'http://keycloak:8080')
        self.keycloak_admin_password = os.getenv('KEYCLOAK_ADMIN_PASSWORD')
        
        # ProtonMail SMTP Configuration
        self.smtp_host = os.getenv('PROTONMAIL_SMTP_HOST', '127.0.0.1')
        self.smtp_port = int(os.getenv('PROTONMAIL_SMTP_PORT', '1025'))
        self.smtp_user = os.getenv('PROTONMAIL_SMTP_USER')
        self.smtp_password = os.getenv('PROTONMAIL_SMTP_PASSWORD')
        
        # E-Mail Settings
        self.email_verification_enabled = os.getenv('EMAIL_VERIFICATION_ENABLED', 'true').lower() == 'true'
        self.magic_link_enabled = os.getenv('EMAIL_MAGIC_LINK_ENABLED', 'true').lower() == 'true'
        self.magic_link_expiry = int(os.getenv('EMAIL_MAGIC_LINK_EXPIRY', '3600'))
        self.domain_whitelist = os.getenv('EMAIL_DOMAIN_WHITELIST', '').split(',')
        
        # In-Memory Storage (in production use Redis/Database)
        self.magic_links = {}
        self.verification_codes = {}
        self.user_sessions = {}
        
        logger.info("🎩 GENTLEMAN E-Mail Auth Service initialisiert")
        logger.info(f"📧 SMTP: {self.smtp_host}:{self.smtp_port}")
        logger.info(f"🔗 Magic Links: {'✅' if self.magic_link_enabled else '❌'}")
        logger.info(f"✉️  Verification: {'✅' if self.email_verification_enabled else '❌'}")

    def get_keycloak_admin_token(self) -> Optional[str]:
        """Keycloak Admin Token abrufen"""
        try:
            url = f"{self.keycloak_url}/realms/master/protocol/openid-connect/token"
            data = {
                'client_id': 'admin-cli',
                'username': 'admin',
                'password': self.keycloak_admin_password,
                'grant_type': 'password'
            }
            response = requests.post(url, data=data)
            if response.status_code == 200:
                return response.json()['access_token']
        except Exception as e:
            logger.error(f"❌ Keycloak Token Fehler: {e}")
        return None

    def is_email_allowed(self, email: str) -> bool:
        """Prüfe ob E-Mail-Domain erlaubt ist"""
        if not self.domain_whitelist or not self.domain_whitelist[0]:
            return True
        
        domain = email.split('@')[1].lower()
        return domain in [d.strip().lower() for d in self.domain_whitelist if d.strip()]

    def send_email(self, to_email: str, subject: str, body: str, html_body: str = None) -> bool:
        """E-Mail über ProtonMail Bridge senden"""
        try:
            msg = MIMEMultipart('alternative')
            msg['From'] = self.smtp_user
            msg['To'] = to_email
            msg['Subject'] = f"🎩 GENTLEMAN - {subject}"
            
            # Text Teil
            text_part = MIMEText(body, 'plain', 'utf-8')
            msg.attach(text_part)
            
            # HTML Teil
            if html_body:
                html_part = MIMEText(html_body, 'html', 'utf-8')
                msg.attach(html_part)
            
            # SMTP Verbindung
            with smtplib.SMTP(self.smtp_host, self.smtp_port) as server:
                if self.smtp_port == 587:
                    server.starttls()
                server.login(self.smtp_user, self.smtp_password)
                server.send_message(msg)
            
            logger.info(f"📧 E-Mail gesendet an {to_email}")
            return True
            
        except Exception as e:
            logger.error(f"❌ E-Mail Fehler: {e}")
            return False

    def generate_magic_link(self, email: str, action: str = "login") -> str:
        """Magic Link generieren"""
        token = str(uuid.uuid4())
        expires_at = datetime.now() + timedelta(seconds=self.magic_link_expiry)
        
        self.magic_links[token] = {
            'email': email,
            'action': action,
            'expires_at': expires_at,
            'used': False
        }
        
        # Magic Link URL
        base_url = "http://auth.gentleman.local:8092"
        magic_url = f"{base_url}/auth/magic/{token}"
        
        logger.info(f"🔗 Magic Link generiert für {email}: {action}")
        return magic_url

    def generate_verification_code(self, email: str) -> str:
        """6-stelligen Verification Code generieren"""
        code = str(uuid.uuid4().int)[:6]
        expires_at = datetime.now() + timedelta(seconds=self.magic_link_expiry)
        
        self.verification_codes[email] = {
            'code': code,
            'expires_at': expires_at,
            'attempts': 0
        }
        
        logger.info(f"🔢 Verification Code generiert für {email}")
        return code

    def send_magic_link_email(self, email: str, action: str = "login") -> bool:
        """Magic Link E-Mail senden"""
        magic_url = self.generate_magic_link(email, action)
        
        subject = {
            'login': 'Anmeldung bei GENTLEMAN Homelab',
            'register': 'Registrierung bei GENTLEMAN Homelab',
            'reset_password': 'Passwort zurücksetzen'
        }.get(action, 'GENTLEMAN Homelab Zugang')
        
        text_body = f"""
🎩 GENTLEMAN Homelab

Hallo,

klicken Sie auf den folgenden Link, um sich anzumelden:

{magic_url}

Dieser Link ist {self.magic_link_expiry // 60} Minuten gültig.

Mit freundlichen Grüßen,
Ihr GENTLEMAN System

---
🎩 Wo Eleganz auf Funktionalität trifft
        """
        
        html_body = f"""
<!DOCTYPE html>
<html>
<head>
    <meta charset="utf-8">
    <title>🎩 GENTLEMAN Homelab</title>
    <style>
        body {{ font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; }}
        .container {{ max-width: 600px; margin: 0 auto; padding: 20px; }}
        .header {{ text-align: center; margin-bottom: 30px; }}
        .button {{ 
            display: inline-block; 
            padding: 12px 24px; 
            background: #007bff; 
            color: white; 
            text-decoration: none; 
            border-radius: 6px; 
            margin: 20px 0;
        }}
        .footer {{ margin-top: 30px; font-size: 12px; color: #666; }}
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>🎩 GENTLEMAN Homelab</h1>
        </div>
        
        <p>Hallo,</p>
        
        <p>klicken Sie auf den folgenden Button, um sich anzumelden:</p>
        
        <p style="text-align: center;">
            <a href="{magic_url}" class="button">🎩 Bei GENTLEMAN anmelden</a>
        </p>
        
        <p>Oder kopieren Sie diesen Link in Ihren Browser:</p>
        <p style="word-break: break-all; background: #f5f5f5; padding: 10px; border-radius: 4px;">
            {magic_url}
        </p>
        
        <p>Dieser Link ist {self.magic_link_expiry // 60} Minuten gültig.</p>
        
        <div class="footer">
            <p>Mit freundlichen Grüßen,<br>
            Ihr GENTLEMAN System</p>
            <p>🎩 Wo Eleganz auf Funktionalität trifft</p>
        </div>
    </div>
</body>
</html>
        """
        
        return self.send_email(email, subject, text_body, html_body)

    def send_verification_code_email(self, email: str) -> bool:
        """Verification Code E-Mail senden"""
        code = self.generate_verification_code(email)
        
        subject = "Ihr GENTLEMAN Verification Code"
        
        text_body = f"""
🎩 GENTLEMAN Homelab

Ihr Verification Code: {code}

Geben Sie diesen Code ein, um Ihre E-Mail-Adresse zu bestätigen.

Der Code ist {self.magic_link_expiry // 60} Minuten gültig.

Mit freundlichen Grüßen,
Ihr GENTLEMAN System
        """
        
        html_body = f"""
<!DOCTYPE html>
<html>
<head>
    <meta charset="utf-8">
    <title>🎩 GENTLEMAN Verification</title>
    <style>
        body {{ font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; }}
        .container {{ max-width: 600px; margin: 0 auto; padding: 20px; }}
        .code {{ 
            font-size: 32px; 
            font-weight: bold; 
            text-align: center; 
            background: #f8f9fa; 
            padding: 20px; 
            border-radius: 8px; 
            letter-spacing: 4px;
            margin: 20px 0;
        }}
    </style>
</head>
<body>
    <div class="container">
        <h1>🎩 GENTLEMAN Homelab</h1>
        
        <p>Ihr Verification Code:</p>
        
        <div class="code">{code}</div>
        
        <p>Geben Sie diesen Code ein, um Ihre E-Mail-Adresse zu bestätigen.</p>
        <p>Der Code ist {self.magic_link_expiry // 60} Minuten gültig.</p>
        
        <p>Mit freundlichen Grüßen,<br>
        Ihr GENTLEMAN System</p>
    </div>
</body>
</html>
        """
        
        return self.send_email(email, subject, text_body, html_body)

    def verify_magic_link(self, token: str) -> Optional[Dict]:
        """Magic Link verifizieren"""
        if token not in self.magic_links:
            return None
        
        link_data = self.magic_links[token]
        
        if link_data['used']:
            return None
        
        if datetime.now() > link_data['expires_at']:
            return None
        
        # Link als verwendet markieren
        self.magic_links[token]['used'] = True
        
        return link_data

    def create_keycloak_user(self, email: str) -> bool:
        """Benutzer in Keycloak erstellen"""
        token = self.get_keycloak_admin_token()
        if not token:
            return False
        
        try:
            url = f"{self.keycloak_url}/admin/realms/gentleman-homelab/users"
            headers = {
                'Authorization': f'Bearer {token}',
                'Content-Type': 'application/json'
            }
            
            user_data = {
                'username': email.split('@')[0],
                'email': email,
                'firstName': 'GENTLEMAN',
                'lastName': 'User',
                'enabled': True,
                'emailVerified': True,
                'groups': ['homelab-users']
            }
            
            response = requests.post(url, headers=headers, json=user_data)
            
            if response.status_code in [201, 409]:  # Created or Conflict (already exists)
                logger.info(f"✅ Keycloak Benutzer erstellt: {email}")
                return True
            else:
                logger.error(f"❌ Keycloak Benutzer Fehler: {response.status_code}")
                return False
                
        except Exception as e:
            logger.error(f"❌ Keycloak API Fehler: {e}")
            return False

# 🚀 FastAPI App
app = FastAPI(title="🎩 GENTLEMAN E-Mail Auth", version="1.0.0")
email_auth = GentlemanEmailAuth()

@app.get("/")
async def root():
    return {"message": "🎩 GENTLEMAN E-Mail Authentication Service", "status": "active"}

@app.get("/health")
async def health():
    return {
        "status": "healthy",
        "timestamp": datetime.now().isoformat(),
        "services": {
            "smtp": "connected" if email_auth.smtp_user else "not_configured",
            "keycloak": "connected" if email_auth.get_keycloak_admin_token() else "disconnected"
        }
    }

@app.post("/auth/send-magic-link")
async def send_magic_link(request: MagicLinkRequest):
    """Magic Link senden (wie Google 'Sign in with email'"""
    
    if not email_auth.is_email_allowed(request.email):
        raise HTTPException(status_code=403, detail="E-Mail-Domain nicht erlaubt")
    
    if not email_auth.magic_link_enabled:
        raise HTTPException(status_code=503, detail="Magic Links deaktiviert")
    
    success = email_auth.send_magic_link_email(request.email, request.action)
    
    if success:
        return {
            "message": "Magic Link gesendet",
            "email": request.email,
            "expires_in": email_auth.magic_link_expiry
        }
    else:
        raise HTTPException(status_code=500, detail="E-Mail konnte nicht gesendet werden")

@app.post("/auth/send-verification-code")
async def send_verification_code(request: EmailAuthRequest):
    """Verification Code senden"""
    
    if not email_auth.is_email_allowed(request.email):
        raise HTTPException(status_code=403, detail="E-Mail-Domain nicht erlaubt")
    
    success = email_auth.send_verification_code_email(request.email)
    
    if success:
        return {
            "message": "Verification Code gesendet",
            "email": request.email,
            "expires_in": email_auth.magic_link_expiry
        }
    else:
        raise HTTPException(status_code=500, detail="E-Mail konnte nicht gesendet werden")

@app.get("/auth/magic/{token}")
async def handle_magic_link(token: str):
    """Magic Link verarbeiten"""
    
    link_data = email_auth.verify_magic_link(token)
    
    if not link_data:
        return HTMLResponse("""
        <!DOCTYPE html>
        <html>
        <head><title>🎩 GENTLEMAN - Ungültiger Link</title></head>
        <body style="font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; text-align: center; padding: 50px;">
            <h1>🎩 GENTLEMAN Homelab</h1>
            <h2>❌ Ungültiger oder abgelaufener Link</h2>
            <p>Bitte fordern Sie einen neuen Magic Link an.</p>
        </body>
        </html>
        """, status_code=400)
    
    email = link_data['email']
    action = link_data['action']
    
    # Benutzer in Keycloak erstellen falls nicht vorhanden
    if action in ['login', 'register']:
        email_auth.create_keycloak_user(email)
    
    # Session erstellen
    session_token = str(uuid.uuid4())
    email_auth.user_sessions[session_token] = {
        'email': email,
        'authenticated': True,
        'created_at': datetime.now()
    }
    
    # Erfolgreiche Anmeldung
    success_html = f"""
    <!DOCTYPE html>
    <html>
    <head>
        <title>🎩 GENTLEMAN - Erfolgreich angemeldet</title>
        <meta http-equiv="refresh" content="3;url=http://auth.gentleman.local:8085/realms/gentleman-homelab/account">
    </head>
    <body style="font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; text-align: center; padding: 50px;">
        <h1>🎩 GENTLEMAN Homelab</h1>
        <h2>✅ Erfolgreich angemeldet!</h2>
        <p>Willkommen, {email}</p>
        <p>Sie werden automatisch weitergeleitet...</p>
        <p><a href="http://auth.gentleman.local:8085/realms/gentleman-homelab/account">Zum Account Dashboard</a></p>
        
        <script>
        setTimeout(function() {{
            window.location.href = 'http://auth.gentleman.local:8085/realms/gentleman-homelab/account';
        }}, 3000);
        </script>
    </body>
    </html>
    """
    
    return HTMLResponse(success_html)

@app.post("/auth/verify-code")
async def verify_code(request: EmailVerificationRequest):
    """Verification Code prüfen"""
    
    email = request.email
    code = request.verification_code
    
    if email not in email_auth.verification_codes:
        raise HTTPException(status_code=404, detail="Kein Code für diese E-Mail gefunden")
    
    code_data = email_auth.verification_codes[email]
    
    if datetime.now() > code_data['expires_at']:
        raise HTTPException(status_code=410, detail="Code abgelaufen")
    
    if code_data['attempts'] >= 3:
        raise HTTPException(status_code=429, detail="Zu viele Versuche")
    
    if code_data['code'] != code:
        code_data['attempts'] += 1
        raise HTTPException(status_code=400, detail="Ungültiger Code")
    
    # Code erfolgreich verifiziert
    del email_auth.verification_codes[email]
    
    # Benutzer in Keycloak erstellen
    email_auth.create_keycloak_user(email)
    
    return {
        "message": "E-Mail erfolgreich verifiziert",
        "email": email,
        "redirect_url": "http://auth.gentleman.local:8085/realms/gentleman-homelab/account"
    }

@app.get("/auth/login-form")
async def login_form():
    """Login-Formular (wie Google Sign-In)"""
    
    html = """
    <!DOCTYPE html>
    <html>
    <head>
        <title>🎩 GENTLEMAN - Anmeldung</title>
        <meta charset="utf-8">
        <style>
            body { 
                font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; 
                background: #f5f5f5; 
                display: flex; 
                justify-content: center; 
                align-items: center; 
                min-height: 100vh; 
                margin: 0; 
            }
            .login-container { 
                background: white; 
                padding: 40px; 
                border-radius: 12px; 
                box-shadow: 0 4px 12px rgba(0,0,0,0.1); 
                max-width: 400px; 
                width: 100%; 
            }
            .logo { text-align: center; margin-bottom: 30px; font-size: 48px; }
            .title { text-align: center; margin-bottom: 30px; color: #333; }
            .form-group { margin-bottom: 20px; }
            .form-control { 
                width: 100%; 
                padding: 12px; 
                border: 1px solid #ddd; 
                border-radius: 6px; 
                font-size: 16px; 
                box-sizing: border-box;
            }
            .btn { 
                width: 100%; 
                padding: 12px; 
                background: #007bff; 
                color: white; 
                border: none; 
                border-radius: 6px; 
                font-size: 16px; 
                cursor: pointer; 
                margin-bottom: 10px;
            }
            .btn:hover { background: #0056b3; }
            .btn-secondary { background: #6c757d; }
            .btn-secondary:hover { background: #545b62; }
            .divider { text-align: center; margin: 20px 0; color: #666; }
            .footer { text-align: center; margin-top: 30px; font-size: 12px; color: #666; }
        </style>
    </head>
    <body>
        <div class="login-container">
            <div class="logo">🎩</div>
            <h1 class="title">GENTLEMAN Homelab</h1>
            
            <form id="emailForm">
                <div class="form-group">
                    <input type="email" id="email" class="form-control" placeholder="E-Mail-Adresse" required>
                </div>
                
                <button type="button" class="btn" onclick="sendMagicLink()">
                    🔗 Magic Link senden
                </button>
                
                <button type="button" class="btn btn-secondary" onclick="sendVerificationCode()">
                    🔢 Verification Code senden
                </button>
            </form>
            
            <div class="divider">oder</div>
            
            <div id="codeForm" style="display: none;">
                <div class="form-group">
                    <input type="text" id="verificationCode" class="form-control" placeholder="6-stelliger Code" maxlength="6">
                </div>
                <button type="button" class="btn" onclick="verifyCode()">
                    ✅ Code bestätigen
                </button>
            </div>
            
            <div class="footer">
                <p>🎩 Wo Eleganz auf Funktionalität trifft</p>
            </div>
        </div>
        
        <script>
        async function sendMagicLink() {
            const email = document.getElementById('email').value;
            if (!email) return alert('Bitte E-Mail eingeben');
            
            try {
                const response = await fetch('/auth/send-magic-link', {
                    method: 'POST',
                    headers: { 'Content-Type': 'application/json' },
                    body: JSON.stringify({ email: email, action: 'login' })
                });
                
                if (response.ok) {
                    alert('Magic Link wurde an ' + email + ' gesendet!');
                } else {
                    const error = await response.json();
                    alert('Fehler: ' + error.detail);
                }
            } catch (e) {
                alert('Fehler beim Senden: ' + e.message);
            }
        }
        
        async function sendVerificationCode() {
            const email = document.getElementById('email').value;
            if (!email) return alert('Bitte E-Mail eingeben');
            
            try {
                const response = await fetch('/auth/send-verification-code', {
                    method: 'POST',
                    headers: { 'Content-Type': 'application/json' },
                    body: JSON.stringify({ email: email })
                });
                
                if (response.ok) {
                    alert('Verification Code wurde an ' + email + ' gesendet!');
                    document.getElementById('codeForm').style.display = 'block';
                } else {
                    const error = await response.json();
                    alert('Fehler: ' + error.detail);
                }
            } catch (e) {
                alert('Fehler beim Senden: ' + e.message);
            }
        }
        
        async function verifyCode() {
            const email = document.getElementById('email').value;
            const code = document.getElementById('verificationCode').value;
            
            if (!email || !code) return alert('Bitte E-Mail und Code eingeben');
            
            try {
                const response = await fetch('/auth/verify-code', {
                    method: 'POST',
                    headers: { 'Content-Type': 'application/json' },
                    body: JSON.stringify({ email: email, verification_code: code })
                });
                
                if (response.ok) {
                    const result = await response.json();
                    alert('Erfolgreich verifiziert!');
                    window.location.href = result.redirect_url;
                } else {
                    const error = await response.json();
                    alert('Fehler: ' + error.detail);
                }
            } catch (e) {
                alert('Fehler bei Verifikation: ' + e.message);
            }
        }
        </script>
    </body>
    </html>
    """
    
    return HTMLResponse(html)

if __name__ == "__main__":
    logger.info("🎩 GENTLEMAN E-Mail Auth Service startet...")
    uvicorn.run(app, host="0.0.0.0", port=8000) 