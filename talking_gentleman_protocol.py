#!/usr/bin/env python3
"""
🎩 GENTLEMAN TalkingGentleman Protocol - I7 Node
Multi-Node AI Communication System
"""

import json
import sys
import argparse
import requests
import time
from datetime import datetime
import socket
import subprocess
import os

class TalkingGentlemanI7:
    def __init__(self, config_path="talking_gentleman_config.json"):
        self.config_path = config_path
        self.config = self.load_config()
        self.node_id = self.config.get("node_id", "i7-unknown")
        self.port = self.config.get("port", 8008)
        
    def load_config(self):
        """Lade Konfiguration"""
        try:
            with open(self.config_path, 'r') as f:
                return json.load(f)
        except FileNotFoundError:
            print(f"❌ Konfigurationsdatei {self.config_path} nicht gefunden")
            return {}
        except json.JSONDecodeError as e:
            print(f"❌ Fehler beim Laden der Konfiguration: {e}")
            return {}
    
    def get_system_info(self):
        """Sammle System-Informationen"""
        info = {
            "hostname": socket.gethostname(),
            "timestamp": datetime.now().isoformat(),
            "node_id": self.node_id,
            "port": self.port,
            "role": self.config.get("role", "client")
        }
        
        # IP-Adresse ermitteln
        try:
            result = subprocess.run(['ifconfig'], capture_output=True, text=True)
            for line in result.stdout.split('\n'):
                if '192.168.68.' in line and 'inet ' in line:
                    ip = line.split('inet ')[1].split(' ')[0]
                    info["ip_address"] = ip
                    break
        except:
            info["ip_address"] = "unknown"
            
        return info
    
    def test_node_connectivity(self, ip, port=8008):
        """Teste Verbindung zu einem Node"""
        try:
            # Ping Test
            ping_result = subprocess.run(['ping', '-c', '2', ip], 
                                       capture_output=True, text=True, timeout=10)
            ping_success = ping_result.returncode == 0
            
            # HTTP Test
            http_success = False
            try:
                response = requests.get(f"http://{ip}:{port}/status", timeout=5)
                http_success = response.status_code == 200
            except:
                pass
                
            return {
                "ip": ip,
                "ping": ping_success,
                "http": http_success,
                "status": "online" if (ping_success and http_success) else "offline"
            }
        except Exception as e:
            return {
                "ip": ip,
                "ping": False,
                "http": False,
                "status": "error",
                "error": str(e)
            }
    
    def status(self):
        """Zeige System-Status"""
        print("🎩 GENTLEMAN I7 Node Status")
        print("=" * 40)
        
        # System Info
        info = self.get_system_info()
        for key, value in info.items():
            print(f"{key}: {value}")
        
        print("\n🌐 Node Connectivity:")
        print("-" * 20)
        
        # Teste bekannte Nodes
        known_nodes = self.config.get("known_nodes", [])
        for node in known_nodes:
            if node["name"] != "i7-node":  # Nicht sich selbst testen
                result = self.test_node_connectivity(node["ip"], node.get("port", 8008))
                status_icon = "✅" if result["status"] == "online" else "❌"
                print(f"{status_icon} {node['name']} ({node['ip']}): {result['status']}")
                if result.get("error"):
                    print(f"   Error: {result['error']}")
    
    def start_service(self):
        """Starte TalkingGentleman Service (Mock)"""
        print("🚀 Starte TalkingGentleman Service auf I7 Node...")
        print(f"Node ID: {self.node_id}")
        print(f"Port: {self.port}")
        print(f"Role: {self.config.get('role', 'client')}")
        
        # Einfacher HTTP Server Mock
        try:
            from http.server import HTTPServer, BaseHTTPRequestHandler
            
            class GentlemanHandler(BaseHTTPRequestHandler):
                def do_GET(self):
                    if self.path == '/status':
                        self.send_response(200)
                        self.send_header('Content-type', 'application/json')
                        self.end_headers()
                        
                        status = {
                            "node_id": self.server.gentleman_instance.node_id,
                            "status": "running",
                            "timestamp": datetime.now().isoformat(),
                            "role": "client"
                        }
                        self.wfile.write(json.dumps(status).encode())
                    else:
                        self.send_response(404)
                        self.end_headers()
                        self.wfile.write(b'Not Found')
                
                def log_message(self, format, *args):
                    pass  # Suppress default logging
            
            server = HTTPServer(('0.0.0.0', self.port), GentlemanHandler)
            server.gentleman_instance = self
            
            print(f"✅ Service läuft auf http://0.0.0.0:{self.port}")
            print("Drücke Ctrl+C zum Beenden")
            
            server.serve_forever()
            
        except KeyboardInterrupt:
            print("\n🛑 Service gestoppt")
        except Exception as e:
            print(f"❌ Fehler beim Starten des Service: {e}")
    
    def test_llm_pipeline(self):
        """Teste LLM Pipeline zu anderen Nodes"""
        print("🧪 Teste LLM Pipeline...")
        
        # Teste M1 Mac Router
        m1_ip = "192.168.68.111"
        try:
            response = requests.post(f"http://{m1_ip}:8007/route_llm", 
                                   json={"prompt": "Hello from I7 Node", "model": "test"},
                                   timeout=10)
            if response.status_code == 200:
                print(f"✅ M1 Router erreichbar: {response.json()}")
            else:
                print(f"❌ M1 Router Fehler: {response.status_code}")
        except Exception as e:
            print(f"❌ M1 Router nicht erreichbar: {e}")
        
        # Teste RX Node direkt
        rx_ip = "192.168.68.117"
        try:
            response = requests.get(f"http://{rx_ip}:8008/status", timeout=5)
            if response.status_code == 200:
                print(f"✅ RX Node erreichbar: {response.json()}")
            else:
                print(f"❌ RX Node Fehler: {response.status_code}")
        except Exception as e:
            print(f"❌ RX Node nicht erreichbar: {e}")

def main():
    parser = argparse.ArgumentParser(description='GENTLEMAN TalkingGentleman Protocol - I7 Node')
    parser.add_argument('--status', action='store_true', help='Zeige System-Status')
    parser.add_argument('--start', action='store_true', help='Starte Service')
    parser.add_argument('--test', action='store_true', help='Teste LLM Pipeline')
    
    args = parser.parse_args()
    
    gentleman = TalkingGentlemanI7()
    
    if args.status:
        gentleman.status()
    elif args.start:
        gentleman.start_service()
    elif args.test:
        gentleman.test_llm_pipeline()
    else:
        print("🎩 GENTLEMAN I7 Node")
        print("Verwende --help für Optionen")
        gentleman.status()

if __name__ == "__main__":
    main() 