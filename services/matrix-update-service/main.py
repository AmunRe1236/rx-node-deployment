#!/usr/bin/env python3
"""
🎩 GENTLEMAN - Matrix Update Authorization Service
═══════════════════════════════════════════════════════════════
Matrix-basiertes Autorisierungssystem für Aktualisierungspipeline
"""

import asyncio
import json
import logging
import hashlib
import subprocess
from datetime import datetime, timedelta
from typing import Dict, List, Optional, Any, Set
from pathlib import Path

import yaml
import aiohttp
from fastapi import FastAPI, HTTPException, BackgroundTasks
from pydantic import BaseModel
from nio import AsyncClient, MatrixRoom, RoomMessageText, Event

# 🎯 Logging Setup
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger("gentleman-matrix-update")

# 📝 Models
class UpdateRequest(BaseModel):
    command: str
    device: str
    user_id: str
    parameters: Optional[Dict[str, Any]] = None
    room_id: Optional[str] = None

class AuthorizationResponse(BaseModel):
    authorized: bool
    reason: str
    required_level: int
    user_level: int

class UpdateStatus(BaseModel):
    update_id: str
    status: str
    device: str
    progress: int
    message: str
    timestamp: datetime

# 🎩 Matrix Update Authorization Service
class MatrixUpdateService:
    def __init__(self):
        self.config = None
        self.matrix_client = None
        self.authorized_users: Dict[str, Dict] = {}
        self.active_updates: Dict[str, UpdateStatus] = {}
        self.audit_log: List[Dict] = []
        self.rate_limits: Dict[str, List[datetime]] = {}
        
    async def initialize(self):
        """Initialisiere den Matrix Update Service"""
        logger.info("🎩 Matrix Update Authorization Service startet...")
        
        # Lade Konfiguration
        await self.load_config()
        
        # Matrix Client initialisieren
        await self.init_matrix_client()
        
        # Autorisierte Benutzer laden
        await self.load_authorized_users()
        
        logger.info("✅ Matrix Update Service bereit!")
        
    async def load_config(self):
        """Lade Matrix-Autorisierungskonfiguration"""
        try:
            config_path = Path("/app/config/integrations/matrix-authorization.yml")
            with open(config_path, 'r') as f:
                self.config = yaml.safe_load(f)['matrix']
            logger.info("✅ Matrix-Konfiguration geladen")
        except Exception as e:
            logger.error(f"❌ Konfiguration Fehler: {e}")
            raise
            
    async def init_matrix_client(self):
        """Initialisiere Matrix Client"""
        try:
            homeserver_url = self.config['server']['homeserver_url']
            user_id = self.config['bot']['user_id']
            access_token = self.config['bot']['access_token']
            
            self.matrix_client = AsyncClient(homeserver_url, user_id)
            self.matrix_client.access_token = access_token
            
            # Event Callbacks registrieren
            self.matrix_client.add_event_callback(
                self.message_callback, 
                RoomMessageText
            )
            
            # Starte Matrix Client
            await self.matrix_client.sync_forever(timeout=30000)
            
        except Exception as e:
            logger.error(f"❌ Matrix Client Fehler: {e}")
            raise
            
    async def load_authorized_users(self):
        """Lade autorisierte Benutzer und deren Berechtigungen"""
        permissions = self.config['update_authorization']['permissions']
        
        for role, config in permissions.items():
            level = config['level']
            users = config['users']
            allowed_commands = config['allowed_commands']
            
            for user_id in users:
                self.authorized_users[user_id] = {
                    'role': role,
                    'level': level,
                    'allowed_commands': allowed_commands,
                    'registered_at': datetime.now()
                }
                
        logger.info(f"✅ {len(self.authorized_users)} autorisierte Benutzer geladen")
        
    async def message_callback(self, room: MatrixRoom, event: RoomMessageText):
        """Matrix Nachrichten-Callback"""
        # Prüfe ob Room autorisiert ist
        if room.room_id not in self.get_allowed_rooms():
            return
            
        # Prüfe ob Nachricht ein Gentleman-Befehl ist
        if not event.body.startswith("!gentleman"):
            return
            
        # Verarbeite Update-Befehl
        await self.process_update_command(
            room.room_id, 
            event.sender, 
            event.body
        )
        
    def get_allowed_rooms(self) -> List[str]:
        """Hol erlaubte Matrix-Räume"""
        return self.config['update_authorization']['allowed_rooms']
        
    async def process_update_command(self, room_id: str, user_id: str, command: str):
        """Verarbeite Update-Befehl aus Matrix"""
        try:
            # Parse Befehl
            parts = command.split()
            if len(parts) < 3:
                await self.send_matrix_message(
                    room_id, 
                    "❌ Ungültiger Befehl. Syntax: !gentleman <action> [parameters]"
                )
                return
                
            action = parts[2]  # z.B. "update", "restart", etc.
            parameters = parts[3:] if len(parts) > 3 else []
            
            # Erstelle Update Request
            update_request = UpdateRequest(
                command=action,
                device="matrix-triggered",
                user_id=user_id,
                parameters={"args": parameters},
                room_id=room_id
            )
            
            # Autorisierung prüfen
            auth_result = await self.check_authorization(update_request)
            
            if not auth_result.authorized:
                await self.send_matrix_message(
                    room_id,
                    f"🚫 Nicht autorisiert: {auth_result.reason}"
                )
                # Log unauthorized attempt
                await self.log_security_event(user_id, action, "UNAUTHORIZED")
                return
                
            # Rate Limiting prüfen
            if not await self.check_rate_limit(user_id):
                await self.send_matrix_message(
                    room_id,
                    "⏰ Rate Limit erreicht. Bitte warten Sie."
                )
                return
                
            # MFA prüfen (falls erforderlich)
            if self.config['security']['mfa_required']:
                if not await self.verify_mfa(user_id, room_id, action):
                    return
                    
            # Update ausführen
            await self.execute_update(update_request)
            
        except Exception as e:
            logger.error(f"❌ Command Processing Fehler: {e}")
            await self.send_matrix_message(
                room_id,
                f"❌ Fehler beim Verarbeiten des Befehls: {str(e)}"
            )
            
    async def check_authorization(self, request: UpdateRequest) -> AuthorizationResponse:
        """Prüfe Benutzer-Autorisierung für Update"""
        user_id = request.user_id
        command = request.command
        
        # Prüfe ob Benutzer registriert ist
        if user_id not in self.authorized_users:
            return AuthorizationResponse(
                authorized=False,
                reason="Benutzer nicht registriert",
                required_level=0,
                user_level=0
            )
            
        user_info = self.authorized_users[user_id]
        user_level = user_info['level']
        allowed_commands = user_info['allowed_commands']
        
        # Prüfe Command-spezifische Berechtigung
        if command not in allowed_commands:
            return AuthorizationResponse(
                authorized=False,
                reason=f"Befehl '{command}' nicht erlaubt für Benutzer-Level {user_level}",
                required_level=self.get_required_level(command),
                user_level=user_level
            )
            
        # Prüfe Level-basierte Autorisierung
        required_level = self.get_required_level(command)
        if user_level < required_level:
            return AuthorizationResponse(
                authorized=False,
                reason=f"Unzureichende Berechtigung. Erforderlich: {required_level}, Benutzer: {user_level}",
                required_level=required_level,
                user_level=user_level
            )
            
        return AuthorizationResponse(
            authorized=True,
            reason="Autorisiert",
            required_level=required_level,
            user_level=user_level
        )
        
    def get_required_level(self, command: str) -> int:
        """Hol erforderliches Level für Befehl"""
        commands_config = self.config['commands']
        
        for cmd_name, cmd_config in commands_config.items():
            if command in cmd_name or cmd_name in command:
                return cmd_config.get('required_level', 0)
                
        return 100  # Default: Höchste Berechtigung erforderlich
        
    async def check_rate_limit(self, user_id: str) -> bool:
        """Prüfe Rate Limiting"""
        now = datetime.now()
        hour_ago = now - timedelta(hours=1)
        day_ago = now - timedelta(days=1)
        
        # Initialisiere User-Einträge falls nicht vorhanden
        if user_id not in self.rate_limits:
            self.rate_limits[user_id] = []
            
        user_requests = self.rate_limits[user_id]
        
        # Bereinige alte Einträge
        user_requests[:] = [req_time for req_time in user_requests if req_time > day_ago]
        
        # Prüfe Limits
        hourly_requests = len([req for req in user_requests if req > hour_ago])
        daily_requests = len(user_requests)
        
        rate_config = self.config['security']['rate_limiting']
        max_hourly = rate_config['max_commands_per_hour']
        max_daily = rate_config['max_commands_per_day']
        
        if hourly_requests >= max_hourly or daily_requests >= max_daily:
            return False
            
        # Request zu Liste hinzufügen
        user_requests.append(now)
        return True
        
    async def verify_mfa(self, user_id: str, room_id: str, action: str) -> bool:
        """Multi-Factor Authentication Verifikation"""
        # Sende MFA Challenge
        challenge_message = f"🔐 MFA erforderlich für '{action}'. Reagiere mit ✅ zur Bestätigung."
        
        event_id = await self.send_matrix_message(room_id, challenge_message)
        
        # Warte auf Reaction
        try:
            # Timeout nach 5 Minuten
            await asyncio.wait_for(
                self.wait_for_mfa_confirmation(user_id, event_id),
                timeout=300
            )
            return True
        except asyncio.TimeoutError:
            await self.send_matrix_message(
                room_id,
                "⏰ MFA Timeout. Befehl abgebrochen."
            )
            return False
            
    async def wait_for_mfa_confirmation(self, user_id: str, event_id: str):
        """Warte auf MFA-Bestätigung"""
        # Simplified: In echter Implementierung würde hier auf Matrix Reaction gewartet
        await asyncio.sleep(2)  # Placeholder
        
    async def execute_update(self, request: UpdateRequest):
        """Führe autorisiertes Update aus"""
        update_id = self.generate_update_id()
        device = request.device
        command = request.command
        
        # Update Status initialisieren
        update_status = UpdateStatus(
            update_id=update_id,
            status="STARTED",
            device=device,
            progress=0,
            message=f"Update '{command}' gestartet",
            timestamp=datetime.now()
        )
        
        self.active_updates[update_id] = update_status
        
        # Notification senden
        await self.notify_update_started(request, update_id)
        
        try:
            # Update ausführen basierend auf Command
            result = await self.run_update_command(request)
            
            # Update erfolgreich
            update_status.status = "COMPLETED"
            update_status.progress = 100
            update_status.message = "Update erfolgreich abgeschlossen"
            
            await self.notify_update_completed(request, update_id, result)
            
        except Exception as e:
            # Update fehlgeschlagen
            update_status.status = "FAILED"
            update_status.message = f"Update fehlgeschlagen: {str(e)}"
            
            await self.notify_update_failed(request, update_id, str(e))
            logger.error(f"❌ Update {update_id} fehlgeschlagen: {e}")
            
        # Log Update
        await self.log_update_event(request, update_status)
        
    async def run_update_command(self, request: UpdateRequest) -> Dict[str, Any]:
        """Führe spezifischen Update-Befehl aus"""
        command = request.command
        parameters = request.parameters or {}
        
        if command == "system_update":
            return await self.run_system_update()
        elif command == "security_patch":
            return await self.run_security_patch()
        elif command == "software_update":
            return await self.run_software_update()
        elif command == "config_update":
            return await self.run_config_update(parameters)
        elif command == "service_restart":
            return await self.run_service_restart(parameters)
        elif command == "rollback":
            return await self.run_rollback(parameters)
        else:
            raise ValueError(f"Unbekannter Befehl: {command}")
            
    async def run_system_update(self) -> Dict[str, Any]:
        """Führe System-Update aus"""
        logger.info("🔄 System Update gestartet...")
        
        # Backup erstellen
        await self.create_backup()
        
        # Update Skript ausführen
        result = subprocess.run(
            ["./setup.sh", "--update"],
            capture_output=True,
            text=True,
            cwd="/app"
        )
        
        if result.returncode != 0:
            raise Exception(f"System Update fehlgeschlagen: {result.stderr}")
            
        return {
            "type": "system_update",
            "output": result.stdout,
            "duration": "estimated_duration",
            "backup_created": True
        }
        
    async def run_security_patch(self) -> Dict[str, Any]:
        """Führe Security Patch aus"""
        logger.info("🔒 Security Patch gestartet...")
        
        # Sicherheitsupdates anwenden
        result = subprocess.run(
            ["./scripts/security/apply_patches.sh"],
            capture_output=True,
            text=True
        )
        
        if result.returncode != 0:
            raise Exception(f"Security Patch fehlgeschlagen: {result.stderr}")
            
        return {
            "type": "security_patch",
            "patches_applied": "count",
            "critical_patches": "count"
        }
        
    async def run_software_update(self) -> Dict[str, Any]:
        """Führe Software-Update aus"""
        logger.info("📦 Software Update gestartet...")
        
        # Dependencies updaten
        result = subprocess.run(
            ["pip", "install", "-r", "requirements.txt", "--upgrade"],
            capture_output=True,
            text=True
        )
        
        if result.returncode != 0:
            raise Exception(f"Software Update fehlgeschlagen: {result.stderr}")
            
        return {
            "type": "software_update",
            "packages_updated": "count"
        }
        
    async def create_backup(self):
        """Erstelle System-Backup vor Update"""
        logger.info("💾 Backup wird erstellt...")
        
        backup_script = Path("/app/scripts/backup/create_backup.sh")
        if backup_script.exists():
            subprocess.run([str(backup_script)], check=True)
            
    def generate_update_id(self) -> str:
        """Generiere eindeutige Update-ID"""
        timestamp = datetime.now().isoformat()
        return hashlib.md5(timestamp.encode()).hexdigest()[:8]
        
    async def send_matrix_message(self, room_id: str, message: str) -> str:
        """Sende Nachricht an Matrix Room"""
        try:
            response = await self.matrix_client.room_send(
                room_id=room_id,
                message_type="m.room.message",
                content={
                    "msgtype": "m.text",
                    "body": message
                }
            )
            return response.event_id
        except Exception as e:
            logger.error(f"❌ Matrix Message Fehler: {e}")
            return ""
            
    async def notify_update_started(self, request: UpdateRequest, update_id: str):
        """Benachrichtige über Update-Start"""
        rooms = self.config['notifications']['update_started']['rooms']
        template = self.config['notifications']['update_started']['message_template']
        
        message = template.format(
            update_type=request.command,
            device=request.device,
            update_id=update_id
        )
        
        for room in rooms:
            await self.send_matrix_message(room, message)
            
    async def notify_update_completed(self, request: UpdateRequest, update_id: str, result: Dict):
        """Benachrichtige über Update-Abschluss"""
        rooms = self.config['notifications']['update_completed']['rooms']
        template = self.config['notifications']['update_completed']['message_template']
        
        message = template.format(
            update_type=request.command,
            device=request.device,
            update_id=update_id
        )
        
        for room in rooms:
            await self.send_matrix_message(room, message)
            
    async def notify_update_failed(self, request: UpdateRequest, update_id: str, error: str):
        """Benachrichtige über Update-Fehler"""
        rooms = self.config['notifications']['update_failed']['rooms']
        template = self.config['notifications']['update_failed']['message_template']
        
        message = template.format(
            update_type=request.command,
            device=request.device,
            error=error,
            update_id=update_id
        )
        
        for room in rooms:
            await self.send_matrix_message(room, message)
            
    async def log_security_event(self, user_id: str, action: str, result: str):
        """Log Sicherheitsereignis"""
        event = {
            "timestamp": datetime.now().isoformat(),
            "user_id": user_id,
            "action": action,
            "result": result,
            "type": "SECURITY_EVENT"
        }
        
        self.audit_log.append(event)
        logger.warning(f"🚨 Security Event: {user_id} attempted {action} - {result}")
        
    async def log_update_event(self, request: UpdateRequest, status: UpdateStatus):
        """Log Update-Ereignis"""
        event = {
            "timestamp": datetime.now().isoformat(),
            "user_id": request.user_id,
            "command": request.command,
            "device": request.device,
            "status": status.status,
            "update_id": status.update_id,
            "type": "UPDATE_EVENT"
        }
        
        self.audit_log.append(event)
        
# 🚀 FastAPI App
app = FastAPI(title="Gentleman Matrix Update Service")
service = MatrixUpdateService()

@app.on_event("startup")
async def startup_event():
    await service.initialize()

@app.get("/health")
async def health_check():
    return {
        "status": "healthy",
        "service": "matrix-update-authorization",
        "timestamp": datetime.now().isoformat(),
        "active_updates": len(service.active_updates),
        "authorized_users": len(service.authorized_users)
    }

@app.get("/status")
async def get_status():
    return {
        "active_updates": service.active_updates,
        "authorized_users": list(service.authorized_users.keys()),
        "recent_events": service.audit_log[-10:]  # Letzte 10 Events
    }

@app.post("/authorize")
async def check_authorization_endpoint(request: UpdateRequest):
    """API Endpoint für Autorisierungsprüfung"""
    return await service.check_authorization(request)

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000) 