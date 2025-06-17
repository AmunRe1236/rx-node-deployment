#!/usr/bin/env python3
# 🎩 Gentleman Discovery Service

import json
import time
from http.server import HTTPServer, BaseHTTPRequestHandler
from datetime import datetime
import subprocess
import socket

class GentlemanDiscoveryHandler(BaseHTTPRequestHandler):
    def do_GET(self):
        if self.path == '/discovery':
            self.send_discovery_info()
        elif self.path == '/health':
            self.send_health_check()
        elif self.path == '/status':
            self.send_system_status()
        else:
            self.send_welcome()
    
    def send_discovery_info(self):
        """Send discovery information for the Gentleman system"""
        discovery_info = {
            "system": "Gentleman Mesh Network",
            "node_type": "M1 Lighthouse",
            "node_id": "m1-lighthouse",
            "timestamp": datetime.now().isoformat(),
            "services": {
                "nebula": {
                    "status": "active",
                    "ip": "192.168.100.1",
                    "port": 4243,
                    "network": "192.168.100.0/24"
                },
                "gitea": {
                    "status": "active",
                    "url": "http://192.168.100.1:3010",
                    "ssh_port": 2223
                },
                "discovery": {
                    "status": "active",
                    "port": 8005
                }
            },
            "network": {
                "physical_ip": self.get_physical_ip(),
                "nebula_ip": "192.168.100.1",
                "mesh_ready": True
            }
        }
        
        self.send_response(200)
        self.send_header('Content-type', 'application/json')
        self.end_headers()
        self.wfile.write(json.dumps(discovery_info, indent=2).encode())
    
    def send_health_check(self):
        """Send health check information"""
        health = {
            "status": "healthy",
            "timestamp": datetime.now().isoformat(),
            "uptime": self.get_uptime(),
            "services": {
                "nebula": self.check_nebula_status(),
                "gitea": self.check_gitea_status()
            }
        }
        
        self.send_response(200)
        self.send_header('Content-type', 'application/json')
        self.end_headers()
        self.wfile.write(json.dumps(health, indent=2).encode())
    
    def send_system_status(self):
        """Send detailed system status"""
        status = {
            "system": "Gentleman M1 Lighthouse",
            "timestamp": datetime.now().isoformat(),
            "nebula": {
                "interface": "utun7",
                "ip": "192.168.100.1",
                "listening": self.check_port(4243),
                "process_running": self.check_nebula_process()
            },
            "gitea": {
                "port": 3010,
                "ssh_port": 2223,
                "healthy": self.check_gitea_status()
            },
            "ready_for_connections": True
        }
        
        self.send_response(200)
        self.send_header('Content-type', 'application/json')
        self.end_headers()
        self.wfile.write(json.dumps(status, indent=2).encode())
    
    def send_welcome(self):
        """Send welcome message"""
        welcome = """
        🎩 Gentleman Discovery Service
        
        Available endpoints:
        - /discovery - System discovery information
        - /health    - Health check
        - /status    - Detailed system status
        
        M1 Lighthouse Status: ACTIVE
        Nebula Network: 192.168.100.0/24
        Ready for RX Node connections!
        """
        
        self.send_response(200)
        self.send_header('Content-type', 'text/plain')
        self.end_headers()
        self.wfile.write(welcome.encode())
    
    def get_physical_ip(self):
        """Get the physical IP address"""
        try:
            result = subprocess.run(['ifconfig', 'en0'], capture_output=True, text=True)
            for line in result.stdout.split('\n'):
                if 'inet ' in line and '127.0.0.1' not in line:
                    return line.split()[1]
        except:
            pass
        return "unknown"
    
    def get_uptime(self):
        """Get system uptime"""
        try:
            result = subprocess.run(['uptime'], capture_output=True, text=True)
            return result.stdout.strip()
        except:
            return "unknown"
    
    def check_nebula_status(self):
        """Check if Nebula is running"""
        try:
            result = subprocess.run(['ifconfig', 'utun7'], capture_output=True, text=True)
            return "active" if "192.168.100.1" in result.stdout else "inactive"
        except:
            return "inactive"
    
    def check_nebula_process(self):
        """Check if Nebula process is running"""
        try:
            result = subprocess.run(['pgrep', 'nebula'], capture_output=True, text=True)
            return len(result.stdout.strip()) > 0
        except:
            return False
    
    def check_gitea_status(self):
        """Check if Gitea is healthy"""
        try:
            import urllib.request
            response = urllib.request.urlopen('http://localhost:3010/api/healthz', timeout=5)
            return response.status == 200
        except:
            return False
    
    def check_port(self, port):
        """Check if a port is listening"""
        try:
            sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
            result = sock.connect_ex(('localhost', port))
            sock.close()
            return result == 0
        except:
            return False

if __name__ == "__main__":
    print("🎩 Starting Gentleman Discovery Service...")
    print("📡 Listening on http://0.0.0.0:8007")
    print("🔍 Available endpoints:")
    print("   GET  /discovery.json - Service discovery data")
    print("   GET  /health        - Health check")
    print("   GET  /status        - Detailed status")
    print("   GET  /              - Human-readable overview")
    
    server = HTTPServer(('0.0.0.0', 8007), GentlemanDiscoveryHandler)
    
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print("\n🛑 Discovery service stopped")
        server.server_close() 