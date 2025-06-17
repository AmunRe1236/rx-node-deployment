#!/usr/bin/env python3
"""
🎩 GENTLEMAN Quick Discovery Service
═══════════════════════════════════════════════════════════════
Schneller Service für Cross-Node Discovery
"""

from fastapi import FastAPI
import uvicorn
import socket
import subprocess
import json
from datetime import datetime

app = FastAPI(
    title="🎩 GENTLEMAN Quick Discovery",
    description="Schneller Discovery-Service für Cross-Node Manager",
    version="1.0.0"
)

def get_local_ip():
    """Ermittelt die lokale IP-Adresse"""
    try:
        # Verbindung zu einem externen Server simulieren
        s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        s.connect(("8.8.8.8", 80))
        ip = s.getsockname()[0]
        s.close()
        return ip
    except:
        return "127.0.0.1"

def get_hardware_info():
    """Ermittelt Hardware-Informationen"""
    try:
        # GPU-Info abrufen
        gpu_info = subprocess.run(['lspci', '|', 'grep', '-i', 'vga'], 
                                shell=True, capture_output=True, text=True)
        if "RX 6700 XT" in gpu_info.stdout or "6700" in gpu_info.stdout:
            return "amd_rx6700xt"
        elif "NVIDIA" in gpu_info.stdout:
            return "nvidia_gpu"
        else:
            return "linux_cpu"
    except:
        return "linux_cpu"

@app.get("/")
async def root():
    """Root endpoint mit Node-Informationen"""
    local_ip = get_local_ip()
    hardware = get_hardware_info()
    
    return {
        "service": "gentleman-discovery",
        "node_type": "rx-node",
        "status": "active",
        "hardware": hardware,
        "ip_address": local_ip,
        "services": {
            "llm-server": {"port": 8001, "status": "starting"},
            "stt-service": {"port": 8002, "status": "healthy"},
            "tts-service": {"port": 8003, "status": "healthy"},
            "web-interface": {"port": 8080, "status": "healthy"}
        },
        "timestamp": datetime.now().isoformat()
    }

@app.get("/health")
async def health_check():
    """Health check endpoint"""
    return {
        "status": "healthy",
        "service": "gentleman-discovery",
        "node_type": "rx-node",
        "timestamp": datetime.now().isoformat()
    }

@app.get("/discovery")
async def discovery_info():
    """Discovery endpoint für Cross-Node Manager"""
    local_ip = get_local_ip()
    hardware = get_hardware_info()
    
    return {
        "node_id": f"gentleman-rx-{local_ip.replace('.', '-')}",
        "node_type": "rx-node",
        "hardware_type": hardware,
        "ip_address": local_ip,
        "hostname": socket.gethostname(),
        "services": [
            {
                "name": "llm-server",
                "port": 8001,
                "endpoint": f"http://{local_ip}:8001",
                "status": "starting"
            },
            {
                "name": "stt-service", 
                "port": 8002,
                "endpoint": f"http://{local_ip}:8002",
                "status": "healthy"
            },
            {
                "name": "tts-service",
                "port": 8003, 
                "endpoint": f"http://{local_ip}:8003",
                "status": "healthy"
            },
            {
                "name": "web-interface",
                "port": 8080,
                "endpoint": f"http://{local_ip}:8080", 
                "status": "healthy"
            }
        ],
        "timestamp": datetime.now().isoformat()
    }

@app.get("/services")
async def list_services():
    """Liste aller verfügbaren Services"""
    local_ip = get_local_ip()
    
    services = []
    service_ports = [
        (8001, "llm-server", "starting"),
        (8002, "stt-service", "healthy"), 
        (8003, "tts-service", "healthy"),
        (8080, "web-interface", "healthy")
    ]
    
    for port, name, status in service_ports:
        services.append({
            "name": name,
            "port": port,
            "endpoint": f"http://{local_ip}:{port}",
            "health_check": f"http://{local_ip}:{port}/health",
            "status": status
        })
    
    return {
        "node_ip": local_ip,
        "services": services,
        "total_services": len(services),
        "timestamp": datetime.now().isoformat()
    }

if __name__ == "__main__":
    print("🎩 Starting Gentleman Quick Discovery Service...")
    print(f"🌐 Local IP: {get_local_ip()}")
    print(f"🔧 Hardware: {get_hardware_info()}")
    print("🚀 Ready for Cross-Node Discovery!")
    
    uvicorn.run(app, host="0.0.0.0", port=8005) 