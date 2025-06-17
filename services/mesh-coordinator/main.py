#!/usr/bin/env python3
"""
🌐 GENTLEMAN Mesh Coordinator
═══════════════════════════════════════════════════════════════
Koordiniert die verteilten AI-Services im Mesh-Netzwerk
Intelligente Service Discovery mit automatischer Hardware-Erkennung
"""

import os
import logging
import socket
import ipaddress
import subprocess
import platform
from typing import Dict, List, Optional, Tuple
from datetime import datetime
import asyncio
import yaml

from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
import uvicorn
import httpx

# 🎯 Logging Setup
logging.basicConfig(
    level=logging.INFO,
    format='🌐 %(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger("gentleman-mesh")

# 🌐 FastAPI App
app = FastAPI(
    title="🌐 Gentleman Mesh Coordinator",
    description="Intelligent mesh network coordinator for distributed AI services",
    version="2.0.0",
    docs_url="/docs",
    redoc_url="/redoc"
)

# 🌐 CORS Middleware
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# 📝 Models
class ServiceInfo(BaseModel):
    name: str
    url: str
    status: str
    last_check: datetime
    response_time: float
    hardware_type: Optional[str] = None
    node_info: Optional[Dict] = None

class NodeInfo(BaseModel):
    hostname: str
    ip_address: str
    hardware_type: str
    available_services: List[str]
    system_info: Dict

class HealthResponse(BaseModel):
    status: str
    services_count: int
    healthy_services: int
    uptime: float

class MeshStatus(BaseModel):
    coordinator_status: str
    services: List[ServiceInfo]
    nodes: List[NodeInfo]
    network_info: Dict

# 🔧 Service Discovery Configuration
SERVICE_DISCOVERY_CONFIG = {
    "scan_networks": [
        "192.168.1.0/24",
        "192.168.0.0/24", 
        "10.0.0.0/24",
        "172.20.0.0/16"
    ],
    "service_ports": {
        "llm-server": 8001,
        "stt-service": 8002,
        "tts-service": 8003,
        "mesh-coordinator": 8004,
        "web-interface": 8080
    },
    "timeout": 2.0,
    "max_concurrent_scans": 50
}

# 📊 Global State
class MeshState:
    def __init__(self):
        self.services = {}
        self.nodes = {}
        self.is_ready = False
        self.start_time = datetime.now()
        self.stats = {
            "requests_total": 0,
            "health_checks_total": 0,
            "services_discovered": 0,
            "nodes_discovered": 0,
            "network_scans": 0
        }
        self.service_config = None

state = MeshState()

# 🔍 Hardware Detection
def detect_hardware_type():
    """Detect the type of hardware this is running on"""
    try:
        system = platform.system().lower()
        machine = platform.machine().lower()
        
        if system == "darwin" and ("arm" in machine or "m1" in machine or "m2" in machine):
            return "apple_silicon"
        elif system == "linux":
            # Check for AMD GPU
            try:
                result = subprocess.run(["lspci"], capture_output=True, text=True, timeout=5)
                if "amd" in result.stdout.lower() and ("radeon" in result.stdout.lower() or "rx" in result.stdout.lower()):
                    return "amd_gpu"
            except:
                pass
            
            # Check for NVIDIA GPU
            try:
                result = subprocess.run(["nvidia-smi"], capture_output=True, text=True, timeout=5)
                if result.returncode == 0:
                    return "nvidia_gpu"
            except:
                pass
            
            return "linux_cpu"
        
        return "unknown"
    except Exception as e:
        logger.warning(f"⚠️ Hardware detection failed: {e}")
        return "unknown"

def get_local_ip():
    """Get the local IP address"""
    try:
        # Connect to a remote address to determine local IP
        with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as s:
            s.connect(("8.8.8.8", 80))
            return s.getsockname()[0]
    except:
        return "127.0.0.1"

async def scan_port(ip: str, port: int, timeout: float = 2.0) -> bool:
    """Scan a single port on an IP address"""
    try:
        future = asyncio.open_connection(ip, port)
        reader, writer = await asyncio.wait_for(future, timeout=timeout)
        writer.close()
        await writer.wait_closed()
        return True
    except:
        return False

async def check_service_endpoint(url: str, timeout: float = 5.0) -> Tuple[bool, Dict]:
    """Check if a service endpoint is responding and get info"""
    try:
        async with httpx.AsyncClient(timeout=timeout) as client:
            # Try health endpoint first
            try:
                response = await client.get(f"{url}/health")
                if response.status_code == 200:
                    health_data = response.json()
                    return True, health_data
            except:
                pass
            
            # Try root endpoint
            try:
                response = await client.get(url)
                if response.status_code == 200:
                    return True, {"status": "responding", "endpoint": "root"}
            except:
                pass
            
            return False, {}
    except Exception as e:
        return False, {"error": str(e)}

async def discover_services_in_network():
    """Discover services across the network"""
    logger.info("🔍 Starting network service discovery...")
    state.stats["network_scans"] += 1
    
    discovered_services = {}
    discovered_nodes = {}
    
    # Get local network info
    local_ip = get_local_ip()
    logger.info(f"🌐 Local IP: {local_ip}")
    
    # Scan configured networks
    for network in SERVICE_DISCOVERY_CONFIG["scan_networks"]:
        try:
            network_obj = ipaddress.IPv4Network(network, strict=False)
            logger.info(f"🔍 Scanning network: {network}")
            
            # Create scanning tasks
            scan_tasks = []
            for ip in network_obj.hosts():
                ip_str = str(ip)
                
                # Skip local IP to avoid self-scanning
                if ip_str == local_ip:
                    continue
                
                # Scan all service ports on this IP
                for service_name, port in SERVICE_DISCOVERY_CONFIG["service_ports"].items():
                    scan_tasks.append(scan_and_check_service(ip_str, port, service_name))
                
                # Limit concurrent scans
                if len(scan_tasks) >= SERVICE_DISCOVERY_CONFIG["max_concurrent_scans"]:
                    results = await asyncio.gather(*scan_tasks, return_exceptions=True)
                    process_scan_results(results, discovered_services, discovered_nodes)
                    scan_tasks = []
            
            # Process remaining tasks
            if scan_tasks:
                results = await asyncio.gather(*scan_tasks, return_exceptions=True)
                process_scan_results(results, discovered_services, discovered_nodes)
                
        except Exception as e:
            logger.error(f"❌ Error scanning network {network}: {e}")
    
    # Update global state
    state.services.update(discovered_services)
    state.nodes.update(discovered_nodes)
    state.stats["services_discovered"] = len(state.services)
    state.stats["nodes_discovered"] = len(state.nodes)
    
    logger.info(f"✅ Discovery complete: {len(discovered_services)} services, {len(discovered_nodes)} nodes")

async def scan_and_check_service(ip: str, port: int, service_name: str) -> Dict:
    """Scan a specific IP:port for a service"""
    try:
        # First check if port is open
        if await scan_port(ip, port, timeout=SERVICE_DISCOVERY_CONFIG["timeout"]):
            # Port is open, check if it's our service
            url = f"http://{ip}:{port}"
            is_service, service_info = await check_service_endpoint(url)
            
            if is_service:
                return {
                    "type": "service",
                    "name": service_name,
                    "ip": ip,
                    "port": port,
                    "url": url,
                    "info": service_info,
                    "discovered_at": datetime.now()
                }
        
        return None
    except Exception as e:
        return None

def process_scan_results(results: List, discovered_services: Dict, discovered_nodes: Dict):
    """Process the results from network scanning"""
    for result in results:
        if result and isinstance(result, dict) and result.get("type") == "service":
            service_name = result["name"]
            ip = result["ip"]
            
            # Add service
            service_key = f"{service_name}@{ip}"
            discovered_services[service_key] = {
                "name": service_name,
                "url": result["url"],
                "status": "discovered",
                "last_check": result["discovered_at"],
                "response_time": 0.0,
                "hardware_type": None,
                "node_info": {"ip": ip, "port": result["port"]}
            }
            
            # Add or update node info
            if ip not in discovered_nodes:
                discovered_nodes[ip] = {
                    "hostname": f"node-{ip.replace('.', '-')}",
                    "ip_address": ip,
                    "hardware_type": "unknown",
                    "available_services": [],
                    "system_info": {},
                    "last_seen": result["discovered_at"]
                }
            
            discovered_nodes[ip]["available_services"].append(service_name)

# 🚀 Startup Event
@app.on_event("startup")
async def startup_event():
    """Initialize Mesh Coordinator with intelligent discovery"""
    logger.info("🌐 Starting Intelligent Gentleman Mesh Coordinator...")
    
    try:
        # Load service discovery configuration
        config_path = "/app/config/service-discovery.yml"
        if os.path.exists(config_path):
            with open(config_path, 'r') as f:
                state.service_config = yaml.safe_load(f)
                logger.info("📋 Loaded service discovery configuration")
        
        # Detect local hardware
        hardware_type = detect_hardware_type()
        local_ip = get_local_ip()
        logger.info(f"🔧 Detected hardware: {hardware_type} on {local_ip}")
        
        # Discover services in network
        await discover_services_in_network()
        
        # Start background tasks
        asyncio.create_task(health_check_loop())
        asyncio.create_task(periodic_discovery_loop())
        
        state.is_ready = True
        logger.info("✅ Intelligent Gentleman Mesh Coordinator ready!")
        
    except Exception as e:
        logger.error(f"❌ Startup failed: {e}")
        state.is_ready = True  # Continue for testing

async def periodic_discovery_loop():
    """Periodically rediscover services"""
    while True:
        try:
            await asyncio.sleep(300)  # Every 5 minutes
            await discover_services_in_network()
        except Exception as e:
            logger.error(f"❌ Periodic discovery error: {e}")
            await asyncio.sleep(600)  # Wait longer on error

async def health_check_loop():
    """Background task to check service health"""
    while True:
        try:
            await check_all_services()
            await asyncio.sleep(30)  # Check every 30 seconds
        except Exception as e:
            logger.error(f"❌ Health check loop error: {e}")
            await asyncio.sleep(60)

async def check_all_services():
    """Check health of all known services"""
    state.stats["health_checks_total"] += 1
    
    async with httpx.AsyncClient(timeout=5.0) as client:
        for service_key, service_info in state.services.items():
            try:
                start_time = datetime.now()
                response = await client.get(f"{service_info['url']}/health")
                response_time = (datetime.now() - start_time).total_seconds()
                
                if response.status_code == 200:
                    state.services[service_key].update({
                        "status": "healthy",
                        "last_check": datetime.now(),
                        "response_time": response_time
                    })
                else:
                    state.services[service_key].update({
                        "status": "unhealthy",
                        "last_check": datetime.now(),
                        "response_time": response_time
                    })
                    
            except Exception as e:
                state.services[service_key].update({
                    "status": "unreachable",
                    "last_check": datetime.now(),
                    "response_time": 0.0
                })

# 🌐 Enhanced Endpoints
@app.get("/mesh/status", response_model=MeshStatus)
async def get_mesh_status():
    """Get comprehensive mesh network status"""
    state.stats["requests_total"] += 1
    
    services_list = [
        ServiceInfo(**service_info) for service_info in state.services.values()
    ]
    
    nodes_list = [
        NodeInfo(**node_info) for node_info in state.nodes.values()
    ]
    
    return MeshStatus(
        coordinator_status="healthy" if state.is_ready else "starting",
        services=services_list,
        nodes=nodes_list,
        network_info={
            "total_services": len(state.services),
            "healthy_services": len([s for s in state.services.values() if s["status"] == "healthy"]),
            "total_nodes": len(state.nodes),
            "coordinator_uptime": (datetime.now() - state.start_time).total_seconds(),
            "local_ip": get_local_ip(),
            "hardware_type": detect_hardware_type()
        }
    )

@app.post("/mesh/discover")
async def trigger_discovery():
    """Trigger immediate network service discovery"""
    await discover_services_in_network()
    return {
        "message": "Network discovery completed",
        "services_found": len(state.services),
        "nodes_found": len(state.nodes)
    }

@app.get("/mesh/services")
async def list_services():
    """List all discovered services"""
    return {"services": state.services}

@app.get("/mesh/nodes")
async def list_nodes():
    """List all discovered nodes"""
    return {"nodes": state.nodes}

@app.get("/mesh/service/{service_name}")
async def get_service_info(service_name: str):
    """Get information about a specific service"""
    matching_services = {k: v for k, v in state.services.items() if v["name"] == service_name}
    
    if not matching_services:
        raise HTTPException(status_code=404, detail="Service not found")
    
    return {"services": matching_services}

@app.get("/mesh/find/{service_type}")
async def find_best_service(service_type: str):
    """Find the best available instance of a service type"""
    matching_services = [
        (k, v) for k, v in state.services.items() 
        if v["name"] == service_type and v["status"] == "healthy"
    ]
    
    if not matching_services:
        raise HTTPException(status_code=404, detail=f"No healthy {service_type} services found")
    
    # Sort by response time (best first)
    matching_services.sort(key=lambda x: x[1]["response_time"])
    
    best_service = matching_services[0][1]
    return {
        "service": best_service,
        "alternatives": [s[1] for s in matching_services[1:]]
    }

# 🏥 Health Check
@app.get("/health", response_model=HealthResponse)
async def health_check():
    """Health check endpoint"""
    healthy_services = len([s for s in state.services.values() if s["status"] == "healthy"])
    
    return HealthResponse(
        status="healthy" if state.is_ready else "starting",
        services_count=len(state.services),
        healthy_services=healthy_services,
        uptime=(datetime.now() - state.start_time).total_seconds()
    )

@app.get("/stats")
async def get_stats():
    """Get coordinator statistics"""
    return {
        "stats": state.stats,
        "uptime": (datetime.now() - state.start_time).total_seconds(),
        "services": len(state.services),
        "nodes": len(state.nodes),
        "hardware_type": detect_hardware_type(),
        "local_ip": get_local_ip()
    }

# 🚀 Main
if __name__ == "__main__":
    uvicorn.run(
        "main:app",
        host="0.0.0.0",
        port=8000,
        reload=False,
        log_level="info"
    ) 