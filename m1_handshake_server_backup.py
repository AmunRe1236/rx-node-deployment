#!/usr/bin/env python3
"""
GENTLEMAN Cluster - M1 Handshake Server
Koordiniert Handshakes und Status-Updates der Cluster Nodes
"""

import json
import time
import logging
from http.server import HTTPServer, BaseHTTPRequestHandler
from urllib.parse import urlparse, parse_qs
import threading
from pathlib import Path

# Logging Setup
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler('/tmp/m1_handshake_server.log'),
        logging.StreamHandler()
    ]
)

class NodeRegistry:
    """Registry für alle Cluster Nodes"""
    
    def __init__(self):
        self.nodes = {}
        self.lock = threading.Lock()
        
    def register_node(self, node_data):
        """Registriere oder aktualisiere Node"""
        with self.lock:
            node_id = node_data.get('node_id')
            self.nodes[node_id] = {
                **node_data,
                'last_seen': time.time(),
                'registered_at': self.nodes.get(node_id, {}).get('registered_at', time.time())
            }
            logging.info(f"✅ Node '{node_id}' registriert/aktualisiert")
            
    def get_active_nodes(self, timeout=300):
        """Hole alle aktiven Nodes (last_seen < timeout seconds)"""
        with self.lock:
            current_time = time.time()
            active = {}
            for node_id, data in self.nodes.items():
                if current_time - data['last_seen'] < timeout:
                    active[node_id] = data
            return active
    
    def get_node_status(self, node_id):
        """Hole Status eines spezifischen Nodes"""
        with self.lock:
            return self.nodes.get(node_id)
    
    def get_cluster_summary(self):
        """Hole Cluster-Zusammenfassung"""
        with self.lock:
            active_nodes = self.get_active_nodes()
            return {
                'total_nodes': len(self.nodes),
                'active_nodes': len(active_nodes),
                'nodes': active_nodes,
                'timestamp': time.time()
            }

class HandshakeHandler(BaseHTTPRequestHandler):
    """HTTP Request Handler für Handshakes"""
    
    def do_POST(self):
        """Handle POST Requests"""
        try:
            # Parse URL
            parsed_url = urlparse(self.path)
            
            if parsed_url.path == '/handshake':
                self.handle_handshake()
            elif parsed_url.path == '/admin/shutdown':
                self.handle_shutdown_request()
            elif parsed_url.path == '/admin/bootup':
                self.handle_bootup_request()
            elif parsed_url.path == '/admin/rx-node/shutdown':
                self.handle_rx_node_shutdown()
            elif parsed_url.path == '/admin/rx-node/wakeup':
                self.handle_rx_node_wakeup()
            elif parsed_url.path == '/admin/rx-node/status':
                self.handle_rx_node_status()
            else:
                self.send_error(404, "Endpoint not found")
                
        except Exception as e:
            logging.error(f"❌ POST Handler Fehler: {e}")
            self.send_error(500, f"Server Error: {e}")
    
    def do_GET(self):
        """Handle GET Requests"""
        try:
            parsed_url = urlparse(self.path)
            
            if parsed_url.path == '/status':
                self.handle_status_request()
            elif parsed_url.path == '/nodes':
                self.handle_nodes_request()
            elif parsed_url.path == '/health':
                self.handle_health_check()
            elif parsed_url.path == '/admin/rx-node/status':
                self.handle_rx_node_status()
            else:
                self.send_error(404, "Endpoint not found")
                
        except Exception as e:
            logging.error(f"❌ GET Handler Fehler: {e}")
            self.send_error(500, f"Server Error: {e}")
    
    def handle_handshake(self):
        """Verarbeite Node Handshake"""
        try:
            # Lese Request Body
            content_length = int(self.headers.get('Content-Length', 0))
            post_data = self.rfile.read(content_length)
            
            # Parse JSON
            node_data = json.loads(post_data.decode('utf-8'))
            
            # Validiere Handshake Data
            required_fields = ['node_id', 'timestamp', 'status']
            if not all(field in node_data for field in required_fields):
                self.send_error(400, "Missing required fields")
                return
            
            # Registriere Node
            self.server.node_registry.register_node(node_data)
            
            # Sende Response
            response = {
                'status': 'success',
                'message': f"Node {node_data['node_id']} registered",
                'server_timestamp': time.time(),
                'cluster_nodes': len(self.server.node_registry.get_active_nodes())
            }
            
            self.send_response(200)
            self.send_header('Content-Type', 'application/json')
            self.end_headers()
            self.wfile.write(json.dumps(response).encode('utf-8'))
            
            logging.info(f"📡 Handshake von {node_data['node_id']} verarbeitet")
            
        except json.JSONDecodeError:
            self.send_error(400, "Invalid JSON")
        except Exception as e:
            logging.error(f"❌ Handshake Fehler: {e}")
            self.send_error(500, f"Handshake Error: {e}")
    
    def handle_status_request(self):
        """Sende Cluster Status"""
        try:
            status = self.server.node_registry.get_cluster_summary()
            
            self.send_response(200)
            self.send_header('Content-Type', 'application/json')
            self.end_headers()
            self.wfile.write(json.dumps(status, indent=2).encode('utf-8'))
            
        except Exception as e:
            logging.error(f"❌ Status Request Fehler: {e}")
            self.send_error(500, f"Status Error: {e}")
    
    def handle_nodes_request(self):
        """Sende Node Liste"""
        try:
            nodes = self.server.node_registry.get_active_nodes()
            
            self.send_response(200)
            self.send_header('Content-Type', 'application/json')
            self.end_headers()
            self.wfile.write(json.dumps(nodes, indent=2).encode('utf-8'))
            
        except Exception as e:
            logging.error(f"❌ Nodes Request Fehler: {e}")
            self.send_error(500, f"Nodes Error: {e}")
    
    def handle_health_check(self):
        """Health Check Endpoint"""
        try:
            health = {
                'status': 'healthy',
                'timestamp': time.time(),
                'server': 'M1 Handshake Server',
                'version': '1.0.0'
            }
            
            self.send_response(200)
            self.send_header('Content-Type', 'application/json')
            self.end_headers()
            self.wfile.write(json.dumps(health).encode('utf-8'))
            
        except Exception as e:
            logging.error(f"❌ Health Check Fehler: {e}")
            self.send_error(500, f"Health Error: {e}")
    
    def handle_shutdown_request(self):
        """Handle Remote Shutdown Request"""
        try:
            # Lese Request Body
            content_length = int(self.headers.get('Content-Length', 0))
            post_data = self.rfile.read(content_length)
            
            # Parse JSON
            request_data = json.loads(post_data.decode('utf-8')) if content_length > 0 else {}
            
            source = request_data.get('source', 'unknown')
            delay_minutes = request_data.get('delay_minutes', 1)
            
            logging.info(f"🔌 Shutdown-Anfrage von: {source}")
            
            # Importiere subprocess für System-Befehle
            import subprocess
            import os
            
            # Stoppe GENTLEMAN Services
            try:
                subprocess.run(['./m1_master_control.sh', 'stop'], 
                              capture_output=True, timeout=30, cwd='/Users/amonbaumgartner/Gentleman')
                logging.info("✅ GENTLEMAN Services gestoppt")
            except Exception as e:
                logging.warning(f"⚠️ Service-Stop Fehler: {e}")
            
            # Stoppe Handshake Server Prozesse
            try:
                subprocess.run(['pkill', '-f', 'python3.*handshake'], capture_output=True)
                logging.info("✅ Handshake Server Prozesse gestoppt")
            except Exception as e:
                logging.warning(f"⚠️ Handshake-Stop Fehler: {e}")
            
            # Stoppe Cloudflare Tunnel
            try:
                subprocess.run(['pkill', '-f', 'cloudflared'], capture_output=True)
                logging.info("✅ Cloudflare Tunnel gestoppt")
            except Exception as e:
                logging.warning(f"⚠️ Tunnel-Stop Fehler: {e}")
            
            # Plane System-Shutdown
            try:
                subprocess.Popen(['sudo', 'shutdown', '-h', f'+{delay_minutes}'])
                logging.info(f"⏰ System-Shutdown in {delay_minutes} Minute(n) geplant")
            except Exception as e:
                logging.error(f"❌ Shutdown-Planung Fehler: {e}")
                raise
            
            # Sende Erfolgs-Response
            response = {
                'status': 'success',
                'message': f'System-Shutdown in {delay_minutes} Minute(n) geplant',
                'source': source,
                'delay_minutes': delay_minutes,
                'timestamp': time.time()
            }
            
            self.send_response(200)
            self.send_header('Content-Type', 'application/json')
            self.end_headers()
            self.wfile.write(json.dumps(response).encode('utf-8'))
            
            logging.info(f"✅ Shutdown-Response gesendet an {source}")
            
        except json.JSONDecodeError:
            self.send_error(400, "Invalid JSON")
        except Exception as e:
            logging.error(f"❌ Shutdown Handler Fehler: {e}")
            self.send_error(500, f"Shutdown Error: {e}")
    
    def handle_bootup_request(self):
        """Handle Remote Bootup Request (Wake-on-LAN)"""
        try:
            # Lese Request Body
            content_length = int(self.headers.get('Content-Length', 0))
            post_data = self.rfile.read(content_length)
            
            # Parse JSON
            request_data = json.loads(post_data.decode('utf-8')) if content_length > 0 else {}
            
            target_mac = request_data.get('target_mac', 'auto')
            target_ip = request_data.get('target_ip', '192.168.68.111')
            source = request_data.get('source', 'unknown')
            
            logging.info(f"🔋 Bootup-Anfrage von: {source} für {target_ip}")
            
            # Importiere subprocess für System-Befehle
            import subprocess
            
            # Automatische MAC-Adresse ermitteln falls nicht angegeben
            if target_mac == 'auto':
                try:
                    # Versuche MAC-Adresse aus ARP-Tabelle zu holen
                    arp_result = subprocess.run(['arp', '-n', target_ip], 
                                              capture_output=True, text=True)
                    if arp_result.returncode == 0:
                        lines = arp_result.stdout.strip().split('\n')
                        for line in lines:
                            if target_ip in line:
                                parts = line.split()
                                if len(parts) >= 3:
                                    target_mac = parts[2]
                                    break
                except Exception as e:
                    logging.warning(f"⚠️ MAC-Adresse Auto-Ermittlung fehlgeschlagen: {e}")
            
            # Fallback MAC-Adresse für M1 Mac (falls bekannt)
            if target_mac == 'auto' or not target_mac:
                # Hier könntest du die bekannte MAC-Adresse des M1 Mac eintragen
                target_mac = "00:00:00:00:00:00"  # Placeholder
                logging.warning(f"⚠️ Verwende Fallback MAC-Adresse: {target_mac}")
            
            # Wake-on-LAN Magic Packet senden
            try:
                # Verwende wakeonlan Tool (falls installiert)
                wol_result = subprocess.run(['wakeonlan', target_mac], 
                                          capture_output=True, text=True)
                if wol_result.returncode == 0:
                    logging.info(f"✅ Wake-on-LAN Packet gesendet an {target_mac}")
                    wol_method = "wakeonlan"
                else:
                    raise Exception("wakeonlan nicht verfügbar")
            except:
                # Fallback: Python-basiertes Wake-on-LAN
                try:
                    import socket
                    
                    # MAC-Adresse formatieren
                    mac_bytes = bytes.fromhex(target_mac.replace(':', '').replace('-', ''))
                    
                    # Magic Packet erstellen (6 x 0xFF + 16 x MAC-Adresse)
                    magic_packet = b'\xff' * 6 + mac_bytes * 16
                    
                    # UDP-Socket erstellen und Packet senden
                    sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
                    sock.setsockopt(socket.SOL_SOCKET, socket.SO_BROADCAST, 1)
                    sock.sendto(magic_packet, ('255.255.255.255', 9))
                    sock.close()
                    
                    logging.info(f"✅ Python Wake-on-LAN Packet gesendet an {target_mac}")
                    wol_method = "python"
                except Exception as e:
                    logging.error(f"❌ Wake-on-LAN Fehler: {e}")
                    raise
            
            # Sende Erfolgs-Response
            response = {
                'status': 'success',
                'message': f'Wake-on-LAN Packet gesendet an {target_mac}',
                'target_mac': target_mac,
                'target_ip': target_ip,
                'source': source,
                'method': wol_method,
                'timestamp': time.time()
            }
            
            self.send_response(200)
            self.send_header('Content-Type', 'application/json')
            self.end_headers()
            self.wfile.write(json.dumps(response).encode('utf-8'))
            
            logging.info(f"✅ Bootup-Response gesendet an {source}")
            
        except json.JSONDecodeError:
            self.send_error(400, "Invalid JSON")
        except Exception as e:
            logging.error(f"❌ Bootup Handler Fehler: {e}")
            self.send_error(500, f"Bootup Error: {e}")
    
    def handle_rx_node_shutdown(self):
        """Handle RX Node Remote Shutdown Request"""
        try:
            # Lese Request Body
            content_length = int(self.headers.get('Content-Length', 0))
            post_data = self.rfile.read(content_length)
            
            # Parse JSON
            request_data = json.loads(post_data.decode('utf-8')) if content_length > 0 else {}
            
            source = request_data.get('source', 'unknown')
            delay_minutes = request_data.get('delay_minutes', 1)
            
            logging.info(f"🎯 RX Node Shutdown-Anfrage von: {source}")
            
            import subprocess
            
            # SSH-Verbindung zur RX Node über M1 Mac (als Gateway)
            rx_node_ip = "192.168.68.117"
            ssh_key = "/Users/amonbaumgartner/.ssh/gentleman_key"
            
            # SSH-Befehl für RX Node Shutdown
            ssh_cmd = [
                'ssh', '-i', ssh_key, '-o', 'StrictHostKeyChecking=no',
                '-o', 'ConnectTimeout=10', f'amo9n11@{rx_node_ip}',
                f'sudo shutdown -h +{delay_minutes}'
            ]
            
            try:
                result = subprocess.run(ssh_cmd, capture_output=True, text=True, timeout=15)
                
                if result.returncode == 0:
                    logging.info(f"✅ RX Node Shutdown erfolgreich geplant ({delay_minutes} Min)")
                    status = "success"
                    message = f"RX Node Shutdown in {delay_minutes} Minute(n) geplant"
                else:
                    logging.error(f"❌ RX Node Shutdown Fehler: {result.stderr}")
                    status = "error"
                    message = f"SSH Fehler: {result.stderr}"
                    
            except subprocess.TimeoutExpired:
                logging.error("❌ RX Node SSH Timeout")
                status = "error"
                message = "SSH Verbindung zur RX Node timeout"
            except Exception as e:
                logging.error(f"❌ RX Node SSH Fehler: {e}")
                status = "error"
                message = f"SSH Verbindungsfehler: {e}"
            
            # Sende Response
            response = {
                'status': status,
                'message': message,
                'target': 'RX Node',
                'target_ip': rx_node_ip,
                'source': source,
                'delay_minutes': delay_minutes,
                'timestamp': time.time()
            }
            
            self.send_response(200 if status == "success" else 500)
            self.send_header('Content-Type', 'application/json')
            self.end_headers()
            self.wfile.write(json.dumps(response).encode('utf-8'))
            
            logging.info(f"📡 RX Node Shutdown-Response gesendet an {source}")
            
        except json.JSONDecodeError:
            self.send_error(400, "Invalid JSON")
        except Exception as e:
            logging.error(f"❌ RX Node Shutdown Handler Fehler: {e}")
            self.send_error(500, f"RX Node Shutdown Error: {e}")
    
    def handle_rx_node_wakeup(self):
        """Handle RX Node Wake-on-LAN Request"""
        try:
            # Lese Request Body
            content_length = int(self.headers.get('Content-Length', 0))
            post_data = self.rfile.read(content_length)
            
            # Parse JSON
            request_data = json.loads(post_data.decode('utf-8')) if content_length > 0 else {}
            
            source = request_data.get('source', 'unknown')
            
            logging.info(f"🔋 RX Node Wakeup-Anfrage von: {source}")
            
            import subprocess
            import socket
            
            # RX Node Details
            rx_node_ip = "192.168.68.117"
            rx_node_mac = "30:9c:23:5f:44:a8"  # Bekannte MAC-Adresse der RX Node
            
            try:
                # Wake-on-LAN Magic Packet senden
                try:
                    # Verwende wakeonlan Tool (falls installiert)
                    wol_result = subprocess.run(['wakeonlan', rx_node_mac], 
                                              capture_output=True, text=True)
                    if wol_result.returncode == 0:
                        logging.info(f"✅ RX Node Wake-on-LAN Packet gesendet an {rx_node_mac}")
                        wol_method = "wakeonlan"
                    else:
                        raise Exception("wakeonlan nicht verfügbar")
                except:
                    # Fallback: Python-basiertes Wake-on-LAN
                    mac_bytes = bytes.fromhex(rx_node_mac.replace(':', ''))
                    magic_packet = b'\xff' * 6 + mac_bytes * 16
                    
                    sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
                    sock.setsockopt(socket.SOL_SOCKET, socket.SO_BROADCAST, 1)
                    sock.sendto(magic_packet, ('255.255.255.255', 9))
                    sock.close()
                    
                    logging.info(f"✅ RX Node Python Wake-on-LAN Packet gesendet an {rx_node_mac}")
                    wol_method = "python"
                
                status = "success"
                message = f"Wake-on-LAN Packet an RX Node gesendet ({rx_node_mac})"
                
            except Exception as e:
                logging.error(f"❌ RX Node Wake-on-LAN Fehler: {e}")
                status = "error"
                message = f"Wake-on-LAN Fehler: {e}"
                wol_method = "failed"
            
            # Sende Response
            response = {
                'status': status,
                'message': message,
                'target': 'RX Node',
                'target_ip': rx_node_ip,
                'target_mac': rx_node_mac,
                'source': source,
                'method': wol_method,
                'timestamp': time.time()
            }
            
            self.send_response(200 if status == "success" else 500)
            self.send_header('Content-Type', 'application/json')
            self.end_headers()
            self.wfile.write(json.dumps(response).encode('utf-8'))
            
            logging.info(f"📡 RX Node Wakeup-Response gesendet an {source}")
            
        except json.JSONDecodeError:
            self.send_error(400, "Invalid JSON")
        except Exception as e:
            logging.error(f"❌ RX Node Wakeup Handler Fehler: {e}")
            self.send_error(500, f"RX Node Wakeup Error: {e}")
    
    def handle_rx_node_status(self):
        """Handle RX Node Status Check Request"""
        try:
            # Kann sowohl GET als auch POST sein
            source = "unknown"
            if self.command == "POST":
                content_length = int(self.headers.get('Content-Length', 0))
                if content_length > 0:
                    post_data = self.rfile.read(content_length)
                    request_data = json.loads(post_data.decode('utf-8'))
                    source = request_data.get('source', 'unknown')
            
            logging.info(f"📊 RX Node Status-Anfrage von: {source}")
            
            import subprocess
            
            # RX Node Details
            rx_node_ip = "192.168.68.117"
            rx_node_mac = "30:9c:23:5f:44:a8"
            ssh_key = "/Users/amonbaumgartner/.ssh/gentleman_key"
            
            # Teste SSH-Verbindung zur RX Node
            ssh_cmd = [
                'ssh', '-i', ssh_key, '-o', 'StrictHostKeyChecking=no',
                '-o', 'ConnectTimeout=5', f'amo9n11@{rx_node_ip}',
                'uptime && hostname && whoami'
            ]
            
            try:
                result = subprocess.run(ssh_cmd, capture_output=True, text=True, timeout=10)
                
                if result.returncode == 0:
                    # RX Node ist online
                    uptime_info = result.stdout.strip()
                    status = "online"
                    message = "RX Node ist online und erreichbar"
                    details = {
                        'ssh_accessible': True,
                        'uptime': uptime_info
                    }
                    logging.info(f"✅ RX Node Status: ONLINE")
                else:
                    # SSH-Fehler
                    status = "offline"
                    message = f"RX Node SSH Fehler: {result.stderr}"
                    details = {
                        'ssh_accessible': False,
                        'error': result.stderr
                    }
                    logging.warning(f"⚠️ RX Node Status: SSH FEHLER")
                    
            except subprocess.TimeoutExpired:
                status = "offline"
                message = "RX Node SSH Timeout - möglicherweise offline"
                details = {
                    'ssh_accessible': False,
                    'error': 'SSH Timeout'
                }
                logging.warning(f"⚠️ RX Node Status: TIMEOUT")
            except Exception as e:
                status = "offline"
                message = f"RX Node Verbindungsfehler: {e}"
                details = {
                    'ssh_accessible': False,
                    'error': str(e)
                }
                logging.error(f"❌ RX Node Status Fehler: {e}")
            
            # Sende Response
            response = {
                'status': status,
                'message': message,
                'target': 'RX Node',
                'target_ip': rx_node_ip,
                'target_mac': rx_node_mac,
                'source': source,
                'details': details,
                'timestamp': time.time()
            }
            
            self.send_response(200)
            self.send_header('Content-Type', 'application/json')
            self.end_headers()
            self.wfile.write(json.dumps(response, indent=2).encode('utf-8'))
            
            logging.info(f"📡 RX Node Status-Response gesendet an {source}")
            
        except json.JSONDecodeError:
            self.send_error(400, "Invalid JSON")
        except Exception as e:
            logging.error(f"❌ RX Node Status Handler Fehler: {e}")
            self.send_error(500, f"RX Node Status Error: {e}")
    
    def log_message(self, format, *args):
        """Überschreibe Standard-Logging"""
        logging.info(f"🌐 {self.address_string()} - {format % args}")

class HandshakeServer:
    """Main Handshake Server Class"""
    
    def __init__(self, host='0.0.0.0', port=8765):
        self.host = host
        self.port = port
        self.node_registry = NodeRegistry()
        self.server = None
        
    def start(self):
        """Starte den Handshake Server"""
        try:
            # Erstelle HTTP Server
            self.server = HTTPServer((self.host, self.port), HandshakeHandler)
            self.server.node_registry = self.node_registry
            
            logging.info(f"🚀 Handshake Server gestartet auf {self.host}:{self.port}")
            logging.info(f"📡 Endpoints verfügbar:")
            logging.info(f"   POST /handshake               - Node Registrierung")
            logging.info(f"   GET  /status                  - Cluster Status")
            logging.info(f"   GET  /nodes                   - Aktive Nodes")
            logging.info(f"   GET  /health                  - Health Check")
            logging.info(f"   POST /admin/shutdown          - M1 Mac Remote Shutdown")
            logging.info(f"   POST /admin/bootup            - M1 Mac Remote Bootup (Wake-on-LAN)")
            logging.info(f"   POST /admin/rx-node/shutdown  - RX Node Remote Shutdown")
            logging.info(f"   POST /admin/rx-node/wakeup    - RX Node Wake-on-LAN")
            logging.info(f"   GET  /admin/rx-node/status    - RX Node Status Check")
            
            # Starte Status Monitor Thread
            status_thread = threading.Thread(target=self.status_monitor, daemon=True)
            status_thread.start()
            
            # Starte Server
            self.server.serve_forever()
            
        except KeyboardInterrupt:
            logging.info("🛑 Server durch Benutzer gestoppt")
        except Exception as e:
            logging.error(f"❌ Server Fehler: {e}")
        finally:
            if self.server:
                self.server.shutdown()
                logging.info("✅ Server heruntergefahren")
    
    def status_monitor(self):
        """Überwache Cluster Status"""
        while True:
            try:
                time.sleep(60)  # Alle 60 Sekunden
                status = self.node_registry.get_cluster_summary()
                logging.info(f"📊 Cluster Status: {status['active_nodes']}/{status['total_nodes']} Nodes aktiv")
                
                # Log inactive nodes
                all_nodes = self.node_registry.nodes
                active_nodes = status['nodes']
                
                for node_id in all_nodes:
                    if node_id not in active_nodes:
                        last_seen = all_nodes[node_id]['last_seen']
                        offline_minutes = (time.time() - last_seen) / 60
                        logging.warning(f"⚠️ Node '{node_id}' offline seit {offline_minutes:.1f} Minuten")
                        
            except Exception as e:
                logging.error(f"❌ Status Monitor Fehler: {e}")

def main():
    """Main Function"""
    import argparse
    
    parser = argparse.ArgumentParser(description='GENTLEMAN M1 Handshake Server')
    parser.add_argument('--host', default='0.0.0.0', help='Server Host (default: 0.0.0.0)')
    parser.add_argument('--port', type=int, default=8765, help='Server Port (default: 8765)')
    
    args = parser.parse_args()
    
    # Erstelle und starte Server
    server = HandshakeServer(host=args.host, port=args.port)
    server.start()

if __name__ == "__main__":
    main() 