#!/usr/bin/env python3
# 🎩 GENTLEMAN i7-M1 Handshake Script
# Establishes secure connection between Intel i7 Mac and M1 Mac

import socket
import json
import time
import requests
import subprocess
import os
from datetime import datetime
import threading

class GentlemanHandshake:
    def __init__(self):
        # Load network configuration
        try:
            with open('network_config.json', 'r') as f:
                self.config = json.load(f)
        except FileNotFoundError:
            print("❌ network_config.json nicht gefunden!")
            exit(1)
        
        self.i7_node = self.config['i7_node']
        self.m1_mac = self.config['m1_mac']
        self.handshake_port = 9999
        self.health_check_interval = 30
        
    def ping_test(self, host):
        """Test if host is reachable via ping"""
        try:
            result = subprocess.run(['ping', '-c', '1', host], 
                                  capture_output=True, text=True, timeout=5)
            return result.returncode == 0
        except subprocess.TimeoutExpired:
            return False
    
    def check_m1_router_service(self):
        """Check if M1 Mac router service is available"""
        try:
            response = requests.get(f"http://{self.m1_mac['lan_ip']}:{self.m1_mac['router_port']}/health", 
                                  timeout=5)
            return response.status_code == 200
        except:
            return False
    
    def send_handshake_request(self):
        """Send handshake request to M1 Mac"""
        handshake_data = {
            "node_type": "i7_intel",
            "hostname": self.i7_node['hostname'],
            "lan_ip": self.i7_node['lan_ip'],
            "nebula_ip": self.i7_node['nebula_ip'],
            "timestamp": datetime.now().isoformat(),
            "mac_type": self.i7_node['mac_type'],
            "system_info": {
                "cpu": subprocess.getoutput("sysctl -n machdep.cpu.brand_string"),
                "cores": subprocess.getoutput("sysctl -n hw.ncpu"),
                "memory_gb": int(subprocess.getoutput("sysctl -n hw.memsize")) // (1024**3)
            },
            "services": {
                "ssh": True,
                "python_env": os.path.exists("gentleman_env"),
                "nebula_ready": os.path.exists("nebula/i7-node/config.yml")
            }
        }
        
        try:
            # Try router service first
            response = requests.post(f"http://{self.m1_mac['lan_ip']}:{self.m1_mac['router_port']}/handshake",
                                   json=handshake_data, timeout=10)
            if response.status_code == 200:
                return response.json()
        except:
            pass
        
        # Fallback: Direct socket connection
        try:
            sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
            sock.settimeout(10)
            sock.connect((self.m1_mac['lan_ip'], self.handshake_port))
            
            message = json.dumps(handshake_data).encode('utf-8')
            sock.send(len(message).to_bytes(4, byteorder='big'))
            sock.send(message)
            
            response_len = int.from_bytes(sock.recv(4), byteorder='big')
            response_data = sock.recv(response_len).decode('utf-8')
            sock.close()
            
            return json.loads(response_data)
        except Exception as e:
            print(f"❌ Handshake fehlgeschlagen: {e}")
            return None
    
    def establish_ssh_trust(self):
        """Establish SSH trust with M1 Mac"""
        print("🔐 Richte SSH-Vertrauen mit M1 Mac ein...")
        
        # Copy SSH public key to M1 Mac
        try:
            with open(os.path.expanduser('~/.ssh/id_rsa.pub'), 'r') as f:
                public_key = f.read().strip()
            
            # Try to add key via SSH (if password auth is available)
            ssh_copy_cmd = f"ssh-copy-id -i ~/.ssh/id_rsa.pub amonbaumgartner@{self.m1_mac['lan_ip']}"
            result = subprocess.run(ssh_copy_cmd, shell=True, capture_output=True, text=True)
            
            if result.returncode == 0:
                print("✅ SSH-Schlüssel erfolgreich kopiert")
                return True
            else:
                print("⚠️  SSH-Schlüssel konnte nicht automatisch kopiert werden")
                print(f"💡 Führe manuell aus: {ssh_copy_cmd}")
                return False
        except Exception as e:
            print(f"❌ SSH-Setup Fehler: {e}")
            return False
    
    def test_ssh_connection(self):
        """Test SSH connection to M1 Mac"""
        try:
            result = subprocess.run(['ssh', '-o', 'ConnectTimeout=5', 
                                   f"amonbaumgartner@{self.m1_mac['lan_ip']}", 
                                   'echo "SSH connection successful"'], 
                                  capture_output=True, text=True)
            return result.returncode == 0
        except:
            return False
    
    def start_health_monitor(self):
        """Start continuous health monitoring"""
        def monitor():
            while True:
                print("\n🔍 Health Check...")
                
                # Check M1 Mac connectivity
                if self.ping_test(self.m1_mac['lan_ip']):
                    print("✅ M1 Mac: Online")
                    
                    if self.check_m1_router_service():
                        print("✅ M1 Router Service: Online")
                    else:
                        print("⚠️  M1 Router Service: Offline")
                        
                    if self.test_ssh_connection():
                        print("✅ SSH Verbindung: Aktiv")
                    else:
                        print("⚠️  SSH Verbindung: Inaktiv")
                else:
                    print("❌ M1 Mac: Offline")
                
                # Check Nebula mesh
                if self.ping_test(self.m1_mac['nebula_ip']):
                    print("✅ Nebula Mesh: Aktiv")
                else:
                    print("⚠️  Nebula Mesh: Offline")
                
                time.sleep(self.health_check_interval)
        
        monitor_thread = threading.Thread(target=monitor, daemon=True)
        monitor_thread.start()
        return monitor_thread
    
    def run_handshake(self):
        """Execute complete handshake process"""
        print("🎩 GENTLEMAN i7-M1 Handshake gestartet")
        print(f"📅 {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
        print("")
        
        # Step 1: Network connectivity check
        print("🌐 Teste Netzwerk-Konnektivität...")
        m1_reachable = self.ping_test(self.m1_mac['lan_ip'])
        
        if m1_reachable:
            print(f"✅ M1 Mac ({self.m1_mac['lan_ip']}): Erreichbar")
        else:
            print(f"❌ M1 Mac ({self.m1_mac['lan_ip']}): Nicht erreichbar")
            print("💡 Prüfe ob M1 Mac online ist und gleiche Netzwerk verwendet")
            return False
        
        # Step 2: Service check
        print("\n🔍 Prüfe M1 Services...")
        router_online = self.check_m1_router_service()
        
        if router_online:
            print("✅ M1 Router Service: Online")
        else:
            print("⚠️  M1 Router Service: Offline")
        
        # Step 3: SSH setup
        print("\n🔐 SSH-Konfiguration...")
        ssh_works = self.test_ssh_connection()
        
        if not ssh_works:
            print("⚠️  SSH-Verbindung noch nicht konfiguriert")
            if input("Soll SSH-Vertrauen eingerichtet werden? (j/n): ").lower() == 'j':
                self.establish_ssh_trust()
        else:
            print("✅ SSH-Verbindung: Bereits konfiguriert")
        
        # Step 4: Handshake
        print("\n🤝 Sende Handshake-Request...")
        handshake_response = self.send_handshake_request()
        
        if handshake_response:
            print("✅ Handshake erfolgreich!")
            print(f"📊 M1 Response: {json.dumps(handshake_response, indent=2)}")
            
            # Save handshake result
            with open('handshake_result.json', 'w') as f:
                json.dump({
                    'timestamp': datetime.now().isoformat(),
                    'success': True,
                    'response': handshake_response
                }, f, indent=2)
            
            print("\n💾 Handshake-Ergebnis in handshake_result.json gespeichert")
        else:
            print("❌ Handshake fehlgeschlagen")
            return False
        
        # Step 5: Start monitoring
        print("\n📊 Starte Health Monitoring...")
        monitor_thread = self.start_health_monitor()
        
        print("✅ Handshake abgeschlossen!")
        print("🔍 Health Monitor läuft im Hintergrund")
        print("📋 Drücke Ctrl+C zum Beenden")
        
        try:
            while True:
                time.sleep(1)
        except KeyboardInterrupt:
            print("\n👋 Handshake beendet")
            return True

if __name__ == "__main__":
    handshake = GentlemanHandshake()
    handshake.run_handshake() 