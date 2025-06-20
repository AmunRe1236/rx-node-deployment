#!/usr/bin/env python3
"""
GENTLEMAN I7 Handshake Client
Automatischer Handshake Client für den i7 Node
Kommuniziert mit dem M1 Handshake Server
"""

import requests
import json
import time
import socket
import logging
import threading
from datetime import datetime
import subprocess
import os
import sys
from pathlib import Path

# Logging Setup
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler('/tmp/i7_handshake_client.log'),
        logging.StreamHandler()
    ]
)

class I7HandshakeClient:
    def __init__(self):
        # M1 Handshake Server Konfiguration - mit Cloudflare Tunnel Fallback
        self.m1_host = "192.168.68.111"  # M1 Mac IP im Heimnetzwerk
        self.m1_tunnel_url = "https://century-pam-every-trouble.trycloudflare.com"  # Cloudflare Tunnel
        self.handshake_port = 8765
        self.git_port = 9418
        self.use_tunnel = False  # Wird automatisch auf True gesetzt bei Verbindungsproblemen
        
        # i7 Node Information
        self.node_id = "i7-development-node"
        self.node_type = "development"
        self.capabilities = ["development", "git-client", "python", "nodejs", "docker"]
        
        # Netzwerk-Konfiguration
        self.local_ip = self._get_local_ip()
        self.vpn_ip = "10.0.0.4"  # WireGuard VPN IP für i7
        
        # Handshake-Konfiguration
        self.handshake_interval = 30  # Sekunden zwischen Handshakes
        self.max_retries = 3
        self.timeout = 30
        
        # Status
        self.is_running = False
        self.last_successful_handshake = None
        self.failed_attempts = 0
        
        logging.info(f"🚀 I7 Handshake Client initialisiert")
        logging.info(f"   Node ID: {self.node_id}")
        logging.info(f"   Lokale IP: {self.local_ip}")
        logging.info(f"   M1 Server: {self.m1_host}:{self.handshake_port}")
    
    def _get_local_ip(self):
        """Ermittle die lokale IP-Adresse"""
        try:
            # Verbinde zu einem externen Host um lokale IP zu ermitteln
            with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as s:
                s.connect(("8.8.8.8", 80))
                return s.getsockname()[0]
        except Exception:
            return "127.0.0.1"
    
    def _get_system_info(self):
        """Sammle System-Informationen"""
        try:
            return {
                "hostname": socket.gethostname(),
                "platform": sys.platform,
                "python_version": sys.version.split()[0],
                "cpu_count": os.cpu_count(),
                "uptime": self._get_uptime(),
                "load_average": self._get_load_average(),
                "memory_usage": self._get_memory_usage(),
                "disk_usage": self._get_disk_usage()
            }
        except Exception as e:
            logging.warning(f"Fehler beim Sammeln der Systeminformationen: {e}")
            return {}
    
    def _get_uptime(self):
        """Ermittle System-Uptime"""
        try:
            if sys.platform == "darwin":  # macOS
                result = subprocess.run(['uptime'], capture_output=True, text=True)
                return result.stdout.strip()
            return "Unknown"
        except:
            return "Unknown"
    
    def _get_load_average(self):
        """Ermittle Load Average"""
        try:
            return os.getloadavg()
        except:
            return [0.0, 0.0, 0.0]
    
    def _get_memory_usage(self):
        """Ermittle Speicher-Nutzung"""
        try:
            if sys.platform == "darwin":
                result = subprocess.run(['vm_stat'], capture_output=True, text=True)
                return result.stdout[:200] + "..." if len(result.stdout) > 200 else result.stdout
            return "Unknown"
        except:
            return "Unknown"
    
    def _get_disk_usage(self):
        """Ermittle Festplatten-Nutzung"""
        try:
            import shutil
            total, used, free = shutil.disk_usage("/")
            return {
                "total_gb": round(total / (1024**3), 2),
                "used_gb": round(used / (1024**3), 2),
                "free_gb": round(free / (1024**3), 2),
                "usage_percent": round((used / total) * 100, 1)
            }
        except:
            return {}
    
    def test_connectivity(self):
        """Teste Verbindung zum M1 Server"""
        # Teste zuerst lokale Verbindung
        try:
            response = requests.get(
                f"http://{self.m1_host}:{self.handshake_port}/health",
                timeout=5
            )
            if response.status_code == 200:
                self.use_tunnel = False
                return True
        except:
            pass
        
        # Fallback: Teste Cloudflare Tunnel
        try:
            response = requests.get(
                f"{self.m1_tunnel_url}/health",
                timeout=5
            )
            if response.status_code == 200:
                self.use_tunnel = True
                logging.info("🌐 Verwende Cloudflare Tunnel für M1 Server Verbindung")
                return True
        except:
            pass
        
        return False
    
    def send_handshake(self):
        """Sende Handshake zum M1 Server"""
        try:
            handshake_data = {
                "node_id": self.node_id,
                "node_type": self.node_type,
                "ip": self.local_ip,
                "vpn_ip": self.vpn_ip,
                "status": "active",
                "timestamp": int(time.time()),
                "capabilities": self.capabilities,
                "system_info": self._get_system_info(),
                "services": {
                    "ssh": True,
                    "git": self._test_git_availability(),
                    "python": True,
                    "docker": self._test_docker_availability()
                }
            }
            
            # Wähle URL basierend auf Verbindungsmodus
            if self.use_tunnel:
                url = f"{self.m1_tunnel_url}/handshake"
                logging.info("🌐 Sende Handshake über Cloudflare Tunnel")
            else:
                url = f"http://{self.m1_host}:{self.handshake_port}/handshake"
                logging.info("🏠 Sende Handshake über lokales Netzwerk")
            
            response = requests.post(
                url,
                json=handshake_data,
                timeout=self.timeout
            )
            
            if response.status_code == 200:
                result = response.json()
                self.last_successful_handshake = datetime.now()
                self.failed_attempts = 0
                
                logging.info("✅ Handshake erfolgreich")
                logging.info(f"   Server Response: {result.get('message', 'OK')}")
                
                if 'cluster_info' in result:
                    cluster_info = result['cluster_info']
                    logging.info(f"   Aktive Nodes: {cluster_info.get('active_nodes', 0)}")
                    logging.info(f"   Cluster Status: {cluster_info.get('status', 'unknown')}")
                
                return True
            else:
                logging.error(f"Handshake fehlgeschlagen: HTTP {response.status_code}")
                logging.error(f"Response: {response.text}")
                return False
                
        except Exception as e:
            logging.error(f"Fehler beim Handshake: {e}")
            return False
    
    def _test_git_availability(self):
        """Teste Git-Verfügbarkeit"""
        try:
            result = subprocess.run(['git', '--version'], capture_output=True, text=True, timeout=3)
            return result.returncode == 0
        except:
            return False
    
    def _test_docker_availability(self):
        """Teste Docker-Verfügbarkeit"""
        try:
            result = subprocess.run(['docker', '--version'], capture_output=True, text=True, timeout=3)
            return result.returncode == 0
        except:
            return False
    
    def get_cluster_status(self):
        """Hole Cluster-Status vom M1 Server"""
        try:
            response = requests.get(
                f"http://{self.m1_host}:{self.handshake_port}/status",
                timeout=5
            )
            
            if response.status_code == 200:
                return response.json()
            else:
                logging.warning(f"Status-Abfrage fehlgeschlagen: HTTP {response.status_code}")
                return None
                
        except Exception as e:
            logging.warning(f"Fehler bei Status-Abfrage: {e}")
            return None
    
    def get_active_nodes(self):
        """Hole Liste der aktiven Nodes"""
        try:
            response = requests.get(
                f"http://{self.m1_host}:{self.handshake_port}/nodes",
                timeout=5
            )
            
            if response.status_code == 200:
                return response.json()
            else:
                logging.warning(f"Node-Abfrage fehlgeschlagen: HTTP {response.status_code}")
                return None
                
        except Exception as e:
            logging.warning(f"Fehler bei Node-Abfrage: {e}")
            return None
    
    def handshake_loop(self):
        """Kontinuierlicher Handshake-Loop"""
        logging.info(f"🔄 Starte kontinuierlichen Handshake-Loop")
        self.is_running = True
        
        while self.is_running:
            try:
                if self.test_connectivity():
                    self.send_handshake()
                else:
                    logging.warning("M1 Server nicht erreichbar")
                
                time.sleep(self.handshake_interval)
                
            except KeyboardInterrupt:
                break
            except Exception as e:
                logging.error(f"Fehler im Handshake-Loop: {e}")
                time.sleep(self.handshake_interval)
        
        self.is_running = False
        logging.info("🛑 Handshake-Loop beendet")
    
    def start_daemon(self):
        """Starte Handshake-Client als Daemon"""
        logging.info("🚀 Starte I7 Handshake Client als Daemon")
        self.handshake_loop()
    
    def stop(self):
        """Stoppe Handshake-Client"""
        logging.info("🛑 Stoppe I7 Handshake Client")
        self.is_running = False
    
    def run_once(self):
        """Führe einen einzelnen Handshake durch"""
        logging.info("🤝 Führe einmaligen Handshake durch")
        
        if self.test_connectivity():
            return self.send_handshake()
        else:
            logging.error("Konnektivitätstest fehlgeschlagen")
            return False
    
    def show_status(self):
        """Zeige aktuellen Status"""
        print("🤝 GENTLEMAN I7 Handshake Client Status")
        print("=====================================")
        print(f"Node ID: {self.node_id}")
        print(f"Lokale IP: {self.local_ip}")
        print(f"VPN IP: {self.vpn_ip}")
        print(f"M1 Server: {self.m1_host}:{self.handshake_port}")
        print(f"Status: {'🟢 AKTIV' if self.is_running else '🔴 INAKTIV'}")
        
        if self.last_successful_handshake:
            print(f"Letzter erfolgreicher Handshake: {self.last_successful_handshake}")
        else:
            print("Letzter erfolgreicher Handshake: Noch keiner")
        
        print(f"Fehlgeschlagene Versuche: {self.failed_attempts}")
        
        # Cluster-Status abrufen
        print("\n📊 Cluster-Status:")
        cluster_status = self.get_cluster_status()
        if cluster_status:
            print(f"   Status: {cluster_status.get('status', 'unknown')}")
            print(f"   Aktive Nodes: {cluster_status.get('active_nodes', 0)}")
            print(f"   Server Uptime: {cluster_status.get('uptime', 'unknown')}")
        else:
            print("   ❌ Cluster-Status nicht verfügbar")
        
        # Aktive Nodes anzeigen
        print("\n👥 Aktive Nodes:")
        nodes = self.get_active_nodes()
        if nodes and 'nodes' in nodes:
            for node_id, node_info in nodes['nodes'].items():
                status_icon = "🟢" if node_info.get('status') == 'active' else "🔴"
                print(f"   {status_icon} {node_id} ({node_info.get('ip', 'unknown')})")
        else:
            print("   ❌ Node-Liste nicht verfügbar")


def main():
    """Main Function"""
    import argparse
    
    parser = argparse.ArgumentParser(description='GENTLEMAN I7 Handshake Client')
    parser.add_argument('--daemon', action='store_true', help='Starte als Daemon')
    parser.add_argument('--once', action='store_true', help='Führe einen einzelnen Handshake durch')
    parser.add_argument('--status', action='store_true', help='Zeige Status')
    parser.add_argument('--test', action='store_true', help='Teste nur Konnektivität')
    
    args = parser.parse_args()
    
    # Erstelle Client
    client = I7HandshakeClient()
    
    try:
        if args.status:
            client.show_status()
        elif args.test:
            if client.test_connectivity():
                print("✅ Konnektivitätstest erfolgreich")
                sys.exit(0)
            else:
                print("❌ Konnektivitätstest fehlgeschlagen")
                sys.exit(1)
        elif args.once:
            if client.run_once():
                print("✅ Handshake erfolgreich")
                sys.exit(0)
            else:
                print("❌ Handshake fehlgeschlagen")
                sys.exit(1)
        elif args.daemon:
            client.start_daemon()
        else:
            # Interaktiver Modus
            print("🤝 GENTLEMAN I7 Handshake Client")
            print("==============================")
            print("Starte interaktiven Modus...")
            print("Drücke Ctrl+C zum Beenden")
            client.start_daemon()
            
    except KeyboardInterrupt:
        print("\nClient durch Benutzer beendet")
        client.stop()
    except Exception as e:
        logging.error(f"Unerwarteter Fehler: {e}")
        sys.exit(1)


if __name__ == "__main__":
    main() 