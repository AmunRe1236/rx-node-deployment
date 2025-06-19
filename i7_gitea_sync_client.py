#!/usr/bin/env python3
"""
GENTLEMAN Cluster - I7 Gitea Sync Client
Synchronisiert mit dem lokalen Git Server über VPN Tunnel
"""

import requests
import subprocess
import json
import time
import logging
from pathlib import Path

# Logging Setup
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler('/tmp/i7_gitea_sync.log'),
        logging.StreamHandler()
    ]
)

class GitSyncClient:
    def __init__(self):
        self.m1_host = "192.168.68.111"
        self.git_port = 9418
        self.handshake_port = 8765
        self.local_repo_path = Path.home() / "Gentleman"
        
    def test_connectivity(self):
        """Teste Verbindung zum M1 Mac"""
        try:
            # Test Git Daemon
            result = subprocess.run([
                "git", "ls-remote", f"git://{self.m1_host}:{self.git_port}/Gentleman"
            ], capture_output=True, text=True, timeout=10)
            
            if result.returncode == 0:
                logging.info("✅ Git Daemon Verbindung erfolgreich")
                return True
            else:
                logging.error(f"❌ Git Daemon Fehler: {result.stderr}")
                return False
                
        except Exception as e:
            logging.error(f"❌ Konnektivitätstest fehlgeschlagen: {e}")
            return False
    
    def sync_from_server(self):
        """Synchronisiere vom Git Server"""
        try:
            if not self.local_repo_path.exists():
                # Clone Repository
                logging.info("📥 Clone Repository vom Server...")
                result = subprocess.run([
                    "git", "clone", 
                    f"git://{self.m1_host}:{self.git_port}/Gentleman",
                    str(self.local_repo_path)
                ], capture_output=True, text=True)
                
                if result.returncode != 0:
                    logging.error(f"❌ Clone fehlgeschlagen: {result.stderr}")
                    return False
            else:
                # Pull Updates
                logging.info("🔄 Pull Updates vom Server...")
                subprocess.run(["git", "fetch", "origin"], 
                             cwd=self.local_repo_path, capture_output=True)
                subprocess.run(["git", "reset", "--hard", "origin/main"], 
                             cwd=self.local_repo_path, capture_output=True)
            
            logging.info("✅ Sync vom Server erfolgreich")
            return True
            
        except Exception as e:
            logging.error(f"❌ Sync fehlgeschlagen: {e}")
            return False
    
    def send_handshake(self):
        """Sende Handshake zum M1 Coordinator"""
        try:
            handshake_data = {
                "node_id": "i7",
                "timestamp": int(time.time()),
                "status": "online",
                "services": ["git_client", "development"]
            }
            
            response = requests.post(
                f"http://{self.m1_host}:{self.handshake_port}/handshake",
                json=handshake_data,
                timeout=5
            )
            
            if response.status_code == 200:
                logging.info("✅ Handshake erfolgreich gesendet")
                return True
            else:
                logging.warning(f"⚠️ Handshake Response: {response.status_code}")
                return False
                
        except Exception as e:
            logging.warning(f"⚠️ Handshake fehlgeschlagen: {e}")
            return False
    
    def run_sync_cycle(self):
        """Führe einen kompletten Sync-Zyklus durch"""
        logging.info("🚀 Starte I7 Gitea Sync Cycle")
        
        # Test Connectivity
        if not self.test_connectivity():
            logging.error("❌ Keine Verbindung zum Git Server")
            return False
        
        # Sync Repository
        if not self.sync_from_server():
            logging.error("❌ Repository Sync fehlgeschlagen")
            return False
        
        # Send Handshake
        self.send_handshake()
        
        logging.info("✅ Sync Cycle erfolgreich abgeschlossen")
        return True

def main():
    client = GitSyncClient()
    
    # Einmaliger Sync
    if "--once" in __import__('sys').argv:
        client.run_sync_cycle()
        return
    
    # Kontinuierlicher Sync
    logging.info("🔄 Starte kontinuierlichen Sync (alle 30 Sekunden)")
    
    while True:
        try:
            client.run_sync_cycle()
            time.sleep(30)
        except KeyboardInterrupt:
            logging.info("🛑 Sync Client gestoppt")
            break
        except Exception as e:
            logging.error(f"❌ Unerwarteter Fehler: {e}")
            time.sleep(60)

if __name__ == "__main__":
    main() 