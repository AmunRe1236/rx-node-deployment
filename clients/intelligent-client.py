#!/usr/bin/env python3
"""
🎩 GENTLEMAN Intelligent Client
═══════════════════════════════════════════════════════════════
Intelligenter Client der automatisch die besten Services findet
Funktioniert sowohl vom M1 Mac als auch von der RX-Node
"""

import asyncio
import logging
import socket
import ipaddress
from typing import Dict, List, Optional, Tuple
from datetime import datetime
import json
import time

import httpx
import yaml

# 🎯 Logging Setup
logging.basicConfig(
    level=logging.INFO,
    format='🎩 %(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger("gentleman-client")

class GentlemanIntelligentClient:
    """Intelligenter Client für das Gentleman AI System"""
    
    def __init__(self):
        self.discovered_services = {}
        self.mesh_coordinators = []
        self.service_cache = {}
        self.cache_ttl = 300  # 5 Minuten
        
        # Service Discovery Konfiguration
        self.discovery_config = {
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
            "timeout": 3.0
        }
    
    def get_local_ip(self) -> str:
        """Lokale IP-Adresse ermitteln"""
        try:
            with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as s:
                s.connect(("8.8.8.8", 80))
                return s.getsockname()[0]
        except:
            return "127.0.0.1"
    
    async def scan_port(self, ip: str, port: int, timeout: float = 2.0) -> bool:
        """Einzelnen Port scannen"""
        try:
            future = asyncio.open_connection(ip, port)
            reader, writer = await asyncio.wait_for(future, timeout=timeout)
            writer.close()
            await writer.wait_closed()
            return True
        except:
            return False
    
    async def discover_mesh_coordinators(self) -> List[str]:
        """Mesh Coordinators im Netzwerk finden"""
        logger.info("🔍 Suche nach Mesh Coordinators...")
        coordinators = []
        
        local_ip = self.get_local_ip()
        
        for network in self.discovery_config["scan_networks"]:
            try:
                network_obj = ipaddress.IPv4Network(network, strict=False)
                
                # Paralleles Scannen für bessere Performance
                scan_tasks = []
                for ip in network_obj.hosts():
                    ip_str = str(ip)
                    if ip_str != local_ip:  # Nicht sich selbst scannen
                        scan_tasks.append(self.check_mesh_coordinator(ip_str))
                
                # Maximal 50 gleichzeitige Scans
                for i in range(0, len(scan_tasks), 50):
                    batch = scan_tasks[i:i+50]
                    results = await asyncio.gather(*batch, return_exceptions=True)
                    
                    for result in results:
                        if result and isinstance(result, str):
                            coordinators.append(result)
                            
            except Exception as e:
                logger.warning(f"⚠️ Fehler beim Scannen von {network}: {e}")
        
        self.mesh_coordinators = coordinators
        logger.info(f"✅ {len(coordinators)} Mesh Coordinators gefunden: {coordinators}")
        return coordinators
    
    async def check_mesh_coordinator(self, ip: str) -> Optional[str]:
        """Prüfen ob IP ein Mesh Coordinator ist"""
        try:
            port = self.discovery_config["service_ports"]["mesh-coordinator"]
            if await self.scan_port(ip, port, timeout=self.discovery_config["timeout"]):
                url = f"http://{ip}:{port}"
                
                async with httpx.AsyncClient(timeout=5.0) as client:
                    response = await client.get(f"{url}/health")
                    if response.status_code == 200:
                        return url
        except:
            pass
        return None
    
    async def discover_services_via_mesh(self) -> Dict:
        """Services über Mesh Coordinators entdecken"""
        if not self.mesh_coordinators:
            await self.discover_mesh_coordinators()
        
        all_services = {}
        
        for coordinator_url in self.mesh_coordinators:
            try:
                async with httpx.AsyncClient(timeout=10.0) as client:
                    response = await client.get(f"{coordinator_url}/mesh/services")
                    if response.status_code == 200:
                        services_data = response.json()
                        all_services.update(services_data.get("services", {}))
                        
            except Exception as e:
                logger.warning(f"⚠️ Fehler beim Abrufen von Services von {coordinator_url}: {e}")
        
        self.discovered_services = all_services
        logger.info(f"🔍 {len(all_services)} Services über Mesh entdeckt")
        return all_services
    
    async def find_best_service(self, service_type: str) -> Optional[Dict]:
        """Besten Service für einen Typ finden"""
        # Cache prüfen
        cache_key = f"best_{service_type}"
        if cache_key in self.service_cache:
            cached_time, cached_service = self.service_cache[cache_key]
            if time.time() - cached_time < self.cache_ttl:
                return cached_service
        
        # Über Mesh Coordinator suchen
        for coordinator_url in self.mesh_coordinators:
            try:
                async with httpx.AsyncClient(timeout=5.0) as client:
                    response = await client.get(f"{coordinator_url}/mesh/find/{service_type}")
                    if response.status_code == 200:
                        result = response.json()
                        best_service = result.get("service")
                        
                        # In Cache speichern
                        self.service_cache[cache_key] = (time.time(), best_service)
                        return best_service
                        
            except Exception as e:
                logger.warning(f"⚠️ Fehler beim Suchen von {service_type}: {e}")
        
        # Fallback: Direkte Suche in entdeckten Services
        matching_services = [
            service for service in self.discovered_services.values()
            if service.get("name") == service_type and service.get("status") == "healthy"
        ]
        
        if matching_services:
            # Sortiere nach Response Time
            matching_services.sort(key=lambda x: x.get("response_time", float('inf')))
            best_service = matching_services[0]
            
            # In Cache speichern
            self.service_cache[cache_key] = (time.time(), best_service)
            return best_service
        
        return None
    
    async def chat_with_ai(self, message: str) -> Dict:
        """Chat mit dem AI System"""
        logger.info(f"💬 Sende Nachricht: '{message[:50]}...'")
        
        # Besten LLM Service finden
        llm_service = await self.find_best_service("llm-server")
        if not llm_service:
            return {"error": "Kein LLM Service verfügbar"}
        
        try:
            start_time = time.time()
            
            async with httpx.AsyncClient(timeout=30.0) as client:
                response = await client.post(
                    f"{llm_service['url']}/generate",
                    json={"prompt": message, "max_tokens": 150}
                )
                
                if response.status_code == 200:
                    result = response.json()
                    response_time = time.time() - start_time
                    
                    logger.info(f"✅ AI Antwort erhalten ({response_time:.2f}s)")
                    return {
                        "response": result.get("response", ""),
                        "service_used": llm_service["url"],
                        "response_time": response_time,
                        "tokens": result.get("tokens", 0)
                    }
                else:
                    return {"error": f"LLM Service Fehler: {response.status_code}"}
                    
        except Exception as e:
            logger.error(f"❌ Chat Fehler: {e}")
            return {"error": str(e)}
    
    async def speech_to_text(self, audio_data: bytes) -> Dict:
        """Sprache zu Text konvertieren"""
        logger.info("🎤 Konvertiere Sprache zu Text...")
        
        # Besten STT Service finden
        stt_service = await self.find_best_service("stt-service")
        if not stt_service:
            return {"error": "Kein STT Service verfügbar"}
        
        try:
            start_time = time.time()
            
            async with httpx.AsyncClient(timeout=30.0) as client:
                files = {"audio": ("audio.wav", audio_data, "audio/wav")}
                response = await client.post(
                    f"{stt_service['url']}/transcribe",
                    files=files
                )
                
                if response.status_code == 200:
                    result = response.json()
                    response_time = time.time() - start_time
                    
                    logger.info(f"✅ Text erkannt ({response_time:.2f}s)")
                    return {
                        "text": result.get("text", ""),
                        "service_used": stt_service["url"],
                        "response_time": response_time
                    }
                else:
                    return {"error": f"STT Service Fehler: {response.status_code}"}
                    
        except Exception as e:
            logger.error(f"❌ STT Fehler: {e}")
            return {"error": str(e)}
    
    async def text_to_speech(self, text: str) -> Dict:
        """Text zu Sprache konvertieren"""
        logger.info(f"🗣️ Konvertiere Text zu Sprache: '{text[:30]}...'")
        
        # Besten TTS Service finden
        tts_service = await self.find_best_service("tts-service")
        if not tts_service:
            return {"error": "Kein TTS Service verfügbar"}
        
        try:
            start_time = time.time()
            
            async with httpx.AsyncClient(timeout=30.0) as client:
                response = await client.post(
                    f"{tts_service['url']}/synthesize",
                    json={"text": text}
                )
                
                if response.status_code == 200:
                    audio_data = response.content
                    response_time = time.time() - start_time
                    
                    logger.info(f"✅ Sprache generiert ({response_time:.2f}s)")
                    return {
                        "audio_data": audio_data,
                        "service_used": tts_service["url"],
                        "response_time": response_time
                    }
                else:
                    return {"error": f"TTS Service Fehler: {response.status_code}"}
                    
        except Exception as e:
            logger.error(f"❌ TTS Fehler: {e}")
            return {"error": str(e)}
    
    async def get_system_status(self) -> Dict:
        """Gesamtstatus des Systems abrufen"""
        logger.info("📊 Rufe Systemstatus ab...")
        
        if not self.mesh_coordinators:
            await self.discover_mesh_coordinators()
        
        system_status = {
            "coordinators": len(self.mesh_coordinators),
            "services": {},
            "nodes": {},
            "overall_health": "unknown"
        }
        
        for coordinator_url in self.mesh_coordinators:
            try:
                async with httpx.AsyncClient(timeout=10.0) as client:
                    response = await client.get(f"{coordinator_url}/mesh/status")
                    if response.status_code == 200:
                        status_data = response.json()
                        
                        # Services zusammenführen
                        for service in status_data.get("services", []):
                            service_key = f"{service['name']}@{service.get('node_info', {}).get('ip', 'unknown')}"
                            system_status["services"][service_key] = service
                        
                        # Nodes zusammenführen
                        for node in status_data.get("nodes", []):
                            system_status["nodes"][node["ip_address"]] = node
                        
                        # Gesamtstatus bestimmen
                        if status_data.get("coordinator_status") == "healthy":
                            system_status["overall_health"] = "healthy"
                            
            except Exception as e:
                logger.warning(f"⚠️ Fehler beim Abrufen des Status von {coordinator_url}: {e}")
        
        return system_status
    
    async def initialize(self):
        """Client initialisieren"""
        logger.info("🎩 Initialisiere Gentleman Intelligent Client...")
        
        # Mesh Coordinators finden
        await self.discover_mesh_coordinators()
        
        # Services entdecken
        await self.discover_services_via_mesh()
        
        logger.info("✅ Gentleman Intelligent Client bereit!")
    
    def print_status(self, status: Dict):
        """Status schön formatiert ausgeben"""
        print("\n🎩 GENTLEMAN SYSTEM STATUS")
        print("═" * 50)
        print(f"🌐 Mesh Coordinators: {status['coordinators']}")
        print(f"🔧 Services: {len(status['services'])}")
        print(f"🖥️ Nodes: {len(status['nodes'])}")
        print(f"💚 Gesamtstatus: {status['overall_health']}")
        
        if status['services']:
            print("\n🔧 Verfügbare Services:")
            for service_key, service in status['services'].items():
                status_icon = "✅" if service['status'] == 'healthy' else "❌"
                print(f"  {status_icon} {service['name']} - {service['url']} ({service['status']})")
        
        if status['nodes']:
            print("\n🖥️ Verfügbare Nodes:")
            for ip, node in status['nodes'].items():
                print(f"  🖥️ {node['hostname']} ({ip}) - {node['hardware_type']}")
                for service in node['available_services']:
                    print(f"    └─ {service}")

# 🧪 Test-Funktionen
async def test_intelligent_client():
    """Test des intelligenten Clients"""
    print("🎩 GENTLEMAN INTELLIGENT CLIENT TEST")
    print("═" * 50)
    
    client = GentlemanIntelligentClient()
    
    # Client initialisieren
    await client.initialize()
    
    # Systemstatus abrufen
    status = await client.get_system_status()
    client.print_status(status)
    
    # Chat-Test
    print("\n💬 Teste Chat-Funktionalität...")
    chat_result = await client.chat_with_ai("Hallo! Ich bin ein intelligenter Client und teste das Gentleman AI System. Bitte antworte kurz auf Deutsch.")
    
    if "error" not in chat_result:
        print(f"✅ Chat erfolgreich ({chat_result['response_time']:.2f}s)")
        print(f"🤖 AI Antwort: '{chat_result['response']}'")
        print(f"🔧 Service verwendet: {chat_result['service_used']}")
        print(f"📊 Tokens: {chat_result['tokens']}")
    else:
        print(f"❌ Chat Fehler: {chat_result['error']}")
    
    print("\n🎉 Test abgeschlossen!")

if __name__ == "__main__":
    asyncio.run(test_intelligent_client()) 