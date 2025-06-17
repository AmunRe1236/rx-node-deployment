#!/usr/bin/env python3

# 🎩 GENTLEMAN Matrix Bot - Remote Update Commands
# ═══════════════════════════════════════════════════════════════
# Sichere Remote-Updates via Matrix Chat Commands

import asyncio
import json
import logging
import os
import subprocess
import time
from datetime import datetime, timedelta
from typing import Dict, List, Optional

import aiohttp
from nio import AsyncClient, MatrixRoom, RoomMessageText

# Configuration
HOMESERVER = os.getenv("MATRIX_HOMESERVER", "http://synapse:8008")
USER_ID = os.getenv("MATRIX_USER_ID", "@gentleman:matrix.gentleman.local")
ACCESS_TOKEN = os.getenv("MATRIX_ACCESS_TOKEN")
ADMIN_USERS = ["@amonbaumgartner:matrix.gentleman.local", "@gentleman:matrix.gentleman.local"]
UPDATE_ROOM = "#gentleman-updates:matrix.gentleman.local"

# Security settings
MAX_PENDING_UPDATES = 5
UPDATE_APPROVAL_TIMEOUT = 300  # 5 minutes
COMMAND_COOLDOWN = 30  # 30 seconds between commands

# Global state
pending_updates: Dict[str, dict] = {}
last_command_time: Dict[str, float] = {}

# Logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

class GentlemanBot:
    def __init__(self):
        self.client = AsyncClient(HOMESERVER, USER_ID)
        self.client.access_token = ACCESS_TOKEN
        
        # Add event callbacks
        self.client.add_event_callback(self.message_callback, RoomMessageText)
        
    async def message_callback(self, room: MatrixRoom, event: RoomMessageText):
        """Handle incoming messages"""
        
        # Ignore own messages
        if event.sender == USER_ID:
            return
            
        # Only process commands that start with !
        if not event.body.startswith("!"):
            return
            
        # Check if user is authorized
        if event.sender not in ADMIN_USERS:
            await self.send_message(room.room_id, f"❌ Unauthorized user: {event.sender}")
            return
            
        # Rate limiting
        now = time.time()
        if event.sender in last_command_time:
            if now - last_command_time[event.sender] < COMMAND_COOLDOWN:
                await self.send_message(room.room_id, f"⏳ Please wait {COMMAND_COOLDOWN}s between commands")
                return
        last_command_time[event.sender] = now
        
        # Parse command
        parts = event.body.split()
        command = parts[0][1:]  # Remove !
        args = parts[1:] if len(parts) > 1 else []
        
        await self.handle_command(room.room_id, event.sender, command, args)
        
    async def handle_command(self, room_id: str, sender: str, command: str, args: List[str]):
        """Handle bot commands"""
        
        try:
            if command == "help":
                await self.cmd_help(room_id)
                
            elif command == "status":
                await self.cmd_status(room_id, args)
                
            elif command == "update":
                await self.cmd_update(room_id, sender, args)
                
            elif command == "approve":
                await self.cmd_approve(room_id, sender, args)
                
            elif command == "cancel":
                await self.cmd_cancel(room_id, sender, args)
                
            elif command == "restart":
                await self.cmd_restart(room_id, sender, args)
                
            elif command == "logs":
                await self.cmd_logs(room_id, args)
                
            elif command == "deploy":
                await self.cmd_deploy(room_id, sender, args)
                
            else:
                await self.send_message(room_id, f"❌ Unknown command: {command}\nUse !help for available commands")
                
        except Exception as e:
            logger.error(f"Command error: {e}")
            await self.send_message(room_id, f"❌ Command failed: {str(e)}")
            
    async def cmd_help(self, room_id: str):
        """Show help message"""
        help_text = """
🎩 **GENTLEMAN Remote Update Commands**

**System Management:**
• `!status [service]` - Show system/service status
• `!restart <service>` - Restart specific service
• `!logs <service> [lines]` - Show service logs

**Updates:**
• `!update docker [services]` - Update Docker services
• `!update system` - Update system packages
• `!deploy <config-files>` - Deploy configuration

**Approval Workflow:**
• `!approve <update-id>` - Approve pending update
• `!cancel <update-id>` - Cancel pending update

**Examples:**
• `!status matrix` - Check Matrix service
• `!update docker synapse element` - Update Matrix services
• `!restart grafana` - Restart Grafana
• `!logs nginx 50` - Show last 50 nginx log lines
"""
        await self.send_message(room_id, help_text)
        
    async def cmd_status(self, room_id: str, args: List[str]):
        """Show system status"""
        service = args[0] if args else "all"
        
        await self.send_message(room_id, f"📊 Checking status: {service}")
        
        try:
            # Execute status check via secure remote script
            result = subprocess.run([
                "/Users/amonbaumgartner/Gentleman /scripts/remote/secure-remote-update.sh",
                "matrix", "status"
            ], capture_output=True, text=True, timeout=60)
            
            if result.returncode == 0:
                await self.send_message(room_id, f"✅ Status:\n```\n{result.stdout}\n```")
            else:
                await self.send_message(room_id, f"❌ Status check failed:\n```\n{result.stderr}\n```")
                
        except subprocess.TimeoutExpired:
            await self.send_message(room_id, "⏰ Status check timed out")
        except Exception as e:
            await self.send_message(room_id, f"❌ Status check error: {str(e)}")
            
    async def cmd_update(self, room_id: str, sender: str, args: List[str]):
        """Initiate update process"""
        if not args:
            await self.send_message(room_id, "❌ Usage: !update <docker|system> [services]")
            return
            
        update_type = args[0]
        services = " ".join(args[1:]) if len(args) > 1 else "all"
        
        # Check pending updates limit
        if len(pending_updates) >= MAX_PENDING_UPDATES:
            await self.send_message(room_id, "❌ Too many pending updates. Please approve or cancel existing ones.")
            return
            
        # Create update request
        update_id = f"update_{int(time.time())}"
        pending_updates[update_id] = {
            "type": update_type,
            "services": services,
            "requester": sender,
            "timestamp": datetime.now(),
            "room_id": room_id,
            "status": "pending"
        }
        
        # Send approval request
        approval_msg = f"""
🔄 **Update Request: {update_id}**

**Type:** {update_type}
**Services:** {services}
**Requested by:** {sender}
**Time:** {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}

**Actions:**
• `!approve {update_id}` - Approve and execute
• `!cancel {update_id}` - Cancel request

⏰ **Auto-expires in 5 minutes**
"""
        await self.send_message(room_id, approval_msg)
        
        # Schedule auto-cleanup
        asyncio.create_task(self.cleanup_expired_update(update_id))
        
    async def cmd_approve(self, room_id: str, sender: str, args: List[str]):
        """Approve pending update"""
        if not args:
            await self.send_message(room_id, "❌ Usage: !approve <update-id>")
            return
            
        update_id = args[0]
        
        if update_id not in pending_updates:
            await self.send_message(room_id, f"❌ Update {update_id} not found or already processed")
            return
            
        update = pending_updates[update_id]
        update["status"] = "approved"
        update["approver"] = sender
        
        await self.send_message(room_id, f"✅ Update {update_id} approved by {sender}")
        await self.send_message(room_id, f"🚀 Executing {update['type']} update...")
        
        # Execute update
        try:
            result = subprocess.run([
                "/Users/amonbaumgartner/Gentleman /scripts/remote/secure-remote-update.sh",
                update["type"],
                update["services"]
            ], capture_output=True, text=True, timeout=600)
            
            if result.returncode == 0:
                await self.send_message(room_id, f"✅ Update {update_id} completed successfully")
                if result.stdout:
                    await self.send_message(room_id, f"```\n{result.stdout}\n```")
            else:
                await self.send_message(room_id, f"❌ Update {update_id} failed")
                if result.stderr:
                    await self.send_message(room_id, f"```\n{result.stderr}\n```")
                    
        except subprocess.TimeoutExpired:
            await self.send_message(room_id, f"⏰ Update {update_id} timed out")
        except Exception as e:
            await self.send_message(room_id, f"❌ Update {update_id} error: {str(e)}")
        finally:
            # Clean up
            del pending_updates[update_id]
            
    async def cmd_cancel(self, room_id: str, sender: str, args: List[str]):
        """Cancel pending update"""
        if not args:
            await self.send_message(room_id, "❌ Usage: !cancel <update-id>")
            return
            
        update_id = args[0]
        
        if update_id not in pending_updates:
            await self.send_message(room_id, f"❌ Update {update_id} not found")
            return
            
        update = pending_updates[update_id]
        del pending_updates[update_id]
        
        await self.send_message(room_id, f"❌ Update {update_id} cancelled by {sender}")
        
    async def cmd_restart(self, room_id: str, sender: str, args: List[str]):
        """Restart service"""
        if not args:
            await self.send_message(room_id, "❌ Usage: !restart <service>")
            return
            
        service = args[0]
        await self.send_message(room_id, f"🔄 Restarting {service}...")
        
        try:
            # Use Matrix-triggered update for immediate restart
            result = subprocess.run([
                "/Users/amonbaumgartner/Gentleman /scripts/remote/secure-remote-update.sh",
                "matrix", f"restart-{service}"
            ], capture_output=True, text=True, timeout=120)
            
            if result.returncode == 0:
                await self.send_message(room_id, f"✅ {service} restarted successfully")
            else:
                await self.send_message(room_id, f"❌ Failed to restart {service}")
                
        except Exception as e:
            await self.send_message(room_id, f"❌ Restart error: {str(e)}")
            
    async def cmd_logs(self, room_id: str, args: List[str]):
        """Show service logs"""
        if not args:
            await self.send_message(room_id, "❌ Usage: !logs <service> [lines]")
            return
            
        service = args[0]
        lines = args[1] if len(args) > 1 else "20"
        
        await self.send_message(room_id, f"📋 Fetching {service} logs ({lines} lines)...")
        
        # This would need to be implemented in the secure remote script
        await self.send_message(room_id, f"📋 Log viewing via Matrix coming soon...")
        
    async def cmd_deploy(self, room_id: str, sender: str, args: List[str]):
        """Deploy configuration"""
        if not args:
            await self.send_message(room_id, "❌ Usage: !deploy <config-files>")
            return
            
        config_files = " ".join(args)
        
        # Create deployment request (similar to update)
        update_id = f"deploy_{int(time.time())}"
        pending_updates[update_id] = {
            "type": "config",
            "services": config_files,
            "requester": sender,
            "timestamp": datetime.now(),
            "room_id": room_id,
            "status": "pending"
        }
        
        approval_msg = f"""
⚙️ **Deployment Request: {update_id}**

**Files:** {config_files}
**Requested by:** {sender}

**Actions:**
• `!approve {update_id}` - Deploy configuration
• `!cancel {update_id}` - Cancel deployment
"""
        await self.send_message(room_id, approval_msg)
        
    async def cleanup_expired_update(self, update_id: str):
        """Clean up expired update requests"""
        await asyncio.sleep(UPDATE_APPROVAL_TIMEOUT)
        
        if update_id in pending_updates:
            update = pending_updates[update_id]
            if update["status"] == "pending":
                del pending_updates[update_id]
                await self.send_message(
                    update["room_id"], 
                    f"⏰ Update {update_id} expired (no approval within 5 minutes)"
                )
                
    async def send_message(self, room_id: str, message: str):
        """Send message to room"""
        try:
            await self.client.room_send(
                room_id=room_id,
                message_type="m.room.message",
                content={
                    "msgtype": "m.text",
                    "body": message,
                    "format": "org.matrix.custom.html",
                    "formatted_body": message.replace("**", "<strong>").replace("**", "</strong>")
                }
            )
        except Exception as e:
            logger.error(f"Failed to send message: {e}")
            
    async def start(self):
        """Start the bot"""
        logger.info("🎩 Starting GENTLEMAN Matrix Bot...")
        
        try:
            # Sync with server
            await self.client.sync_forever(timeout=30000)
        except Exception as e:
            logger.error(f"Bot error: {e}")
        finally:
            await self.client.close()

# Main execution
async def main():
    if not ACCESS_TOKEN:
        logger.error("MATRIX_ACCESS_TOKEN not set")
        return
        
    bot = GentlemanBot()
    await bot.start()

if __name__ == "__main__":
    asyncio.run(main()) 