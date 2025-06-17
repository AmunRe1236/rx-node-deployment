#!/usr/bin/env python3
"""
Gentleman AI System - Automated Key Rotation System
Rotiert SSH-Keys, Nebula-Zertifikate und API-Keys automatisch
"""

import os
import sys
import json
import time
import shutil
import logging
import subprocess
from datetime import datetime, timedelta
from pathlib import Path
from typing import Dict, List, Optional
import secrets
import string

class KeyRotationSystem:
    def __init__(self, config_path: str = "key_rotation_config.json"):
        self.config_path = config_path
        self.config = self.load_config()
        self.setup_logging()
        
    def setup_logging(self):
        """Setup logging für Key-Rotation"""
        log_dir = Path("logs")
        log_dir.mkdir(exist_ok=True)
        
        logging.basicConfig(
            level=logging.INFO,
            format='%(asctime)s - %(levelname)s - %(message)s',
            handlers=[
                logging.FileHandler(log_dir / "key_rotation.log"),
                logging.StreamHandler(sys.stdout)
            ]
        )
        self.logger = logging.getLogger(__name__)
        
    def load_config(self) -> Dict:
        """Lade Key-Rotation Konfiguration"""
        default_config = {
            "ssh_keys": {
                "rotation_interval_days": 30,
                "key_type": "rsa",
                "key_size": 4096,
                "backup_count": 5
            },
            "nebula_certs": {
                "rotation_interval_days": 90,
                "ca_name": "Gentleman-Mesh-CA",
                "backup_count": 3
            },
            "api_keys": {
                "rotation_interval_days": 7,
                "key_length": 64,
                "backup_count": 10
            },
            "nodes": {
                "rx_node": {
                    "ip": "192.168.100.10",
                    "ssh_user": "amo9n11"
                },
                "m1_mac": {
                    "ip": "192.168.100.1", 
                    "ssh_user": "amo9n11"
                }
            }
        }
        
        if os.path.exists(self.config_path):
            with open(self.config_path, 'r') as f:
                config = json.load(f)
                # Merge mit default config
                for key, value in default_config.items():
                    if key not in config:
                        config[key] = value
                return config
        else:
            with open(self.config_path, 'w') as f:
                json.dump(default_config, f, indent=2)
            return default_config
    
    def generate_ssh_keypair(self, key_name: str) -> tuple:
        """Generiere neues SSH-Keypair"""
        ssh_dir = Path.home() / ".ssh"
        ssh_dir.mkdir(mode=0o700, exist_ok=True)
        
        private_key_path = ssh_dir / f"{key_name}"
        public_key_path = ssh_dir / f"{key_name}.pub"
        
        # Backup alte Keys
        if private_key_path.exists():
            timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
            shutil.move(str(private_key_path), f"{private_key_path}.backup_{timestamp}")
            shutil.move(str(public_key_path), f"{public_key_path}.backup_{timestamp}")
        
        # Generiere neuen Key
        cmd = [
            "ssh-keygen",
            "-t", self.config["ssh_keys"]["key_type"],
            "-b", str(self.config["ssh_keys"]["key_size"]),
            "-f", str(private_key_path),
            "-N", "",  # Kein Passwort
            "-C", f"gentleman-{key_name}-{datetime.now().strftime('%Y%m%d')}"
        ]
        
        result = subprocess.run(cmd, capture_output=True, text=True)
        if result.returncode != 0:
            raise Exception(f"SSH-Key Generierung fehlgeschlagen: {result.stderr}")
        
        # Setze korrekte Berechtigungen
        private_key_path.chmod(0o600)
        public_key_path.chmod(0o644)
        
        with open(public_key_path, 'r') as f:
            public_key = f.read().strip()
            
        self.logger.info(f"Neuer SSH-Key generiert: {key_name}")
        return str(private_key_path), public_key
    
    def rotate_ssh_keys(self):
        """Rotiere SSH-Keys für alle Knoten"""
        self.logger.info("🔄 Starte SSH-Key Rotation...")
        
        # Generiere neue Keys für jeden Knoten
        new_keys = {}
        for node_name in self.config["nodes"].keys():
            key_name = f"id_rsa_{node_name}_rotated"
            private_key_path, public_key = self.generate_ssh_keypair(key_name)
            new_keys[node_name] = {
                "private_key_path": private_key_path,
                "public_key": public_key
            }
        
        # Verteile öffentliche Keys an alle Knoten
        for target_node, target_config in self.config["nodes"].items():
            self.logger.info(f"📤 Aktualisiere authorized_keys auf {target_node}")
            
            # Sammle alle öffentlichen Keys (außer dem eigenen)
            authorized_keys = []
            for source_node, key_info in new_keys.items():
                if source_node != target_node:
                    authorized_keys.append(key_info["public_key"])
            
            # Schreibe authorized_keys auf Zielknoten
            self.update_authorized_keys(target_config["ip"], authorized_keys)
        
        # Aktualisiere SSH-Config
        self.update_ssh_config(new_keys)
        
        self.logger.info("✅ SSH-Key Rotation abgeschlossen")
    
    def update_authorized_keys(self, target_ip: str, public_keys: List[str]):
        """Aktualisiere authorized_keys auf Zielknoten"""
        authorized_keys_content = "\n".join(public_keys) + "\n"
        
        # Schreibe temporäre Datei
        temp_file = "/tmp/new_authorized_keys"
        with open(temp_file, 'w') as f:
            f.write(authorized_keys_content)
        
        # Kopiere auf Zielknoten
        cmd = [
            "scp", "-o", "StrictHostKeyChecking=no",
            temp_file, f"amo9n11@{target_ip}:~/.ssh/authorized_keys"
        ]
        
        result = subprocess.run(cmd, capture_output=True, text=True)
        if result.returncode != 0:
            self.logger.error(f"Fehler beim Kopieren der authorized_keys: {result.stderr}")
        
        # Setze korrekte Berechtigungen
        ssh_cmd = [
            "ssh", "-o", "StrictHostKeyChecking=no",
            f"amo9n11@{target_ip}",
            "chmod 600 ~/.ssh/authorized_keys"
        ]
        subprocess.run(ssh_cmd)
        
        os.remove(temp_file)
    
    def update_ssh_config(self, new_keys: Dict):
        """Aktualisiere SSH-Config mit neuen Keys"""
        ssh_config_path = Path.home() / ".ssh" / "config"
        
        config_content = []
        
        # GitHub Config
        config_content.extend([
            "Host github.com",
            "    HostName github.com", 
            "    User git",
            "    IdentityFile ~/.ssh/id_rsa_gentleman",
            "    IdentitiesOnly yes",
            ""
        ])
        
        # Knoten-spezifische Configs
        for node_name, node_config in self.config["nodes"].items():
            if node_name in new_keys:
                key_path = new_keys[node_name]["private_key_path"]
                config_content.extend([
                    f"Host {node_name}",
                    f"    HostName {node_config['ip']}",
                    f"    User {node_config['ssh_user']}",
                    f"    IdentityFile {key_path}",
                    "    IdentitiesOnly yes",
                    "    StrictHostKeyChecking no",
                    ""
                ])
        
        with open(ssh_config_path, 'w') as f:
            f.write("\n".join(config_content))
        
        ssh_config_path.chmod(0o600)
        self.logger.info("SSH-Config aktualisiert")
    
    def generate_api_key(self, length: int = 64) -> str:
        """Generiere sicheren API-Key"""
        alphabet = string.ascii_letters + string.digits + "-_"
        return ''.join(secrets.choice(alphabet) for _ in range(length))
    
    def rotate_api_keys(self):
        """Rotiere API-Keys für Services"""
        self.logger.info("🔄 Starte API-Key Rotation...")
        
        api_keys = {
            "llm_server_key": self.generate_api_key(),
            "mesh_coordinator_key": self.generate_api_key(),
            "discovery_service_key": self.generate_api_key(),
            "monitoring_key": self.generate_api_key()
        }
        
        # Speichere neue API-Keys
        api_keys_file = Path("api_keys.json")
        
        # Backup alte Keys
        if api_keys_file.exists():
            timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
            shutil.copy(api_keys_file, f"api_keys.backup_{timestamp}.json")
        
        with open(api_keys_file, 'w') as f:
            json.dump(api_keys, f, indent=2)
        
        api_keys_file.chmod(0o600)
        
        self.logger.info("✅ API-Key Rotation abgeschlossen")
        return api_keys
    
    def rotate_nebula_certificates(self):
        """Rotiere Nebula-Zertifikate"""
        self.logger.info("🔄 Starte Nebula-Zertifikat Rotation...")
        
        nebula_dir = Path("/etc/nebula")
        if not nebula_dir.exists():
            self.logger.warning("Nebula-Verzeichnis nicht gefunden, überspringe Zertifikat-Rotation")
            return
        
        # Backup alte Zertifikate
        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        backup_dir = Path(f"nebula_backup_{timestamp}")
        backup_dir.mkdir(exist_ok=True)
        
        for cert_file in ["ca.crt", "rx.crt", "rx.key"]:
            cert_path = nebula_dir / cert_file
            if cert_path.exists():
                shutil.copy(cert_path, backup_dir / cert_file)
        
        # Hier würde die Nebula-Zertifikat Regenerierung stattfinden
        # Das ist komplex und erfordert CA-Management
        self.logger.info("⚠️  Nebula-Zertifikat Rotation erfordert manuelle CA-Verwaltung")
        
        self.logger.info("✅ Nebula-Zertifikat Rotation vorbereitet")
    
    def cleanup_old_backups(self):
        """Räume alte Backup-Dateien auf"""
        self.logger.info("🧹 Räume alte Backups auf...")
        
        # SSH-Key Backups
        ssh_dir = Path.home() / ".ssh"
        for backup_file in ssh_dir.glob("*.backup_*"):
            file_age = datetime.now() - datetime.fromtimestamp(backup_file.stat().st_mtime)
            if file_age.days > 90:  # Lösche Backups älter als 90 Tage
                backup_file.unlink()
                self.logger.info(f"Gelöscht: {backup_file}")
        
        # API-Key Backups
        for backup_file in Path(".").glob("api_keys.backup_*.json"):
            file_age = datetime.now() - datetime.fromtimestamp(backup_file.stat().st_mtime)
            if file_age.days > 30:  # Lösche API-Key Backups älter als 30 Tage
                backup_file.unlink()
                self.logger.info(f"Gelöscht: {backup_file}")
    
    def run_full_rotation(self):
        """Führe vollständige Key-Rotation durch"""
        self.logger.info("🚀 Starte vollständige Key-Rotation...")
        
        try:
            # 1. SSH-Keys rotieren
            self.rotate_ssh_keys()
            
            # 2. API-Keys rotieren
            api_keys = self.rotate_api_keys()
            
            # 3. Nebula-Zertifikate vorbereiten
            self.rotate_nebula_certificates()
            
            # 4. Alte Backups aufräumen
            self.cleanup_old_backups()
            
            # 5. Rotation-Status speichern
            self.save_rotation_status()
            
            self.logger.info("✅ Vollständige Key-Rotation erfolgreich abgeschlossen!")
            
            return {
                "status": "success",
                "timestamp": datetime.now().isoformat(),
                "rotated_keys": list(api_keys.keys())
            }
            
        except Exception as e:
            self.logger.error(f"❌ Key-Rotation fehlgeschlagen: {str(e)}")
            return {
                "status": "error",
                "timestamp": datetime.now().isoformat(),
                "error": str(e)
            }
    
    def save_rotation_status(self):
        """Speichere Rotation-Status"""
        status = {
            "last_rotation": datetime.now().isoformat(),
            "next_rotation": (datetime.now() + timedelta(days=7)).isoformat(),
            "rotation_count": self.get_rotation_count() + 1
        }
        
        with open("rotation_status.json", 'w') as f:
            json.dump(status, f, indent=2)
    
    def get_rotation_count(self) -> int:
        """Hole aktuelle Rotation-Anzahl"""
        try:
            with open("rotation_status.json", 'r') as f:
                status = json.load(f)
                return status.get("rotation_count", 0)
        except FileNotFoundError:
            return 0
    
    def check_rotation_needed(self) -> bool:
        """Prüfe ob Rotation benötigt wird"""
        try:
            with open("rotation_status.json", 'r') as f:
                status = json.load(f)
                next_rotation = datetime.fromisoformat(status["next_rotation"])
                return datetime.now() >= next_rotation
        except FileNotFoundError:
            return True  # Erste Rotation

def main():
    """Hauptfunktion für Key-Rotation"""
    if len(sys.argv) > 1 and sys.argv[1] == "--check":
        # Nur prüfen ob Rotation benötigt wird
        rotation_system = KeyRotationSystem()
        if rotation_system.check_rotation_needed():
            print("Key-Rotation benötigt")
            sys.exit(1)
        else:
            print("Keine Key-Rotation benötigt")
            sys.exit(0)
    
    # Vollständige Rotation durchführen
    rotation_system = KeyRotationSystem()
    result = rotation_system.run_full_rotation()
    
    if result["status"] == "success":
        print("✅ Key-Rotation erfolgreich abgeschlossen!")
        sys.exit(0)
    else:
        print(f"❌ Key-Rotation fehlgeschlagen: {result['error']}")
        sys.exit(1)

if __name__ == "__main__":
    main() 