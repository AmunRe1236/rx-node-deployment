#!/usr/bin/env python3
"""
RX Node Simulator - Simuliert die RX Node für Tests
"""

import json
import time
from http.server import HTTPServer, BaseHTTPRequestHandler
import threading

class RXSimulator(BaseHTTPRequestHandler):
    def do_GET(self):
        """Handle GET requests"""
        try:
            if self.path == '/status':
                self.send_response(200)
                self.send_header('Content-type', 'application/json')
                self.end_headers()
                
                status = {
                    "status": "online",
                    "node_id": "rx-simulator-local",
                    "role": "primary_trainer",
                    "timestamp": time.time(),
                    "capabilities": ["simulation", "testing", "gpu_inference"],
                    "note": "This is a simulated RX Node for testing purposes"
                }
                
                self.wfile.write(json.dumps(status, indent=2).encode())
                
            elif self.path == '/health':
                self.send_response(200)
                self.send_header('Content-type', 'text/plain')
                self.end_headers()
                self.wfile.write(b'OK - RX Node Simulator')
                
            elif self.path == '/wake':
                self.send_response(200)
                self.send_header('Content-type', 'application/json')
                self.end_headers()
                
                response = {
                    "message": "RX Node wake signal received",
                    "timestamp": time.time(),
                    "status": "awakening",
                    "from_simulator": True
                }
                
                self.wfile.write(json.dumps(response).encode())
                
            else:
                self.send_response(404)
                self.end_headers()
                
        except Exception as e:
            print(f"Error: {e}")
            self.send_response(500)
            self.end_headers()
    
    def log_message(self, format, *args):
        """Override to reduce log spam"""
        print(f"[RX-SIM] {format % args}")

def start_simulator(port=8017):
    """Start the RX Node simulator"""
    try:
        server = HTTPServer(('0.0.0.0', port), RXSimulator)
        print(f"🎭 RX Node Simulator starting on port {port}")
        print(f"   Test URLs:")
        print(f"   - Status: http://localhost:{port}/status")
        print(f"   - Health: http://localhost:{port}/health")
        print(f"   - Wake:   http://localhost:{port}/wake")
        print(f"   Press Ctrl+C to stop")
        server.serve_forever()
    except KeyboardInterrupt:
        print("\n🛑 RX Node Simulator stopped")
    except Exception as e:
        print(f"❌ Simulator error: {e}")

if __name__ == "__main__":
    start_simulator()
