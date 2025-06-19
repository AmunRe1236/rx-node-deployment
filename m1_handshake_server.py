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
            logging.info(f"   POST /handshake - Node Registrierung")
            logging.info(f"   GET  /status    - Cluster Status")
            logging.info(f"   GET  /nodes     - Aktive Nodes")
            logging.info(f"   GET  /health    - Health Check")
            
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