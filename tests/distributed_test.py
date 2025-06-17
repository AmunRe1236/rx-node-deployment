#!/usr/bin/env python3
"""
🎩 GENTLEMAN Distributed Test
═══════════════════════════════════════════════════════════════
Intelligenter Test der automatisch Services im Netzwerk findet
Funktioniert vom M1 Mac, RX-Node oder jedem anderen Gerät
"""

import asyncio
import logging
import socket
import ipaddress
import platform
import sys
from typing import Dict, List, Optional
from datetime import datetime
import time
import json

import httpx

# 🎯 Logging Setup
logging.basicConfig(
    level=logging.INFO,
    format='🎩 %(asctime)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger("gentleman-test")

class GentlemanDistributedTest:
    """Verteilter Test für das Gentleman AI System"""
    
    def __init__(self):
        self.discovered_services = {}
        self.mesh_coordinators = []
        self.test_results = {}
        self.start_time = datetime.now()
        
        # Hardware-Info
        self.local_hardware = self.detect_hardware()
        self.local_ip = self.get_local_ip()
        
        # Discovery-Konfiguration
        self.discovery_config = {
            "scan_networks": [
                "192.168.1.0/24",
                "192.168.0.0/24", 
                "10.0.0.0/24",
                "172.20.0.0/16",
                "localhost"
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
    
    def detect_hardware(self) -> str:
        """Hardware-Typ erkennen"""
        try:
            system = platform.system().lower()
            machine = platform.machine().lower()
            
            if system == "darwin":
                if "arm" in machine or "m1" in machine or "m2" in machine:
                    return "apple_silicon_m1"
                else:
                    return "intel_mac"
            elif system == "linux":
                return "linux_amd64"
            else:
                return "unknown"
        except:
            return "unknown"
    
    def get_local_ip(self) -> str:
        """Lokale IP ermitteln"""
        try:
            with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as s:
                s.connect(("8.8.8.8", 80))
                return s.getsockname()[0]
        except:
            return "127.0.0.1"
    
    async def scan_port(self, ip: str, port: int, timeout: float = 2.0) -> bool:
        """Port scannen"""
        try:
            future = asyncio.open_connection(ip, port)
            reader, writer = await asyncio.wait_for(future, timeout=timeout)
            writer.close()
            await writer.wait_closed()
            return True
        except:
            return False
    
    async def discover_services(self) -> Dict:
        """Services im Netzwerk entdecken"""
        print("🔍 Suche nach Gentleman AI Services...")
        
        discovered = {}
        
        # Localhost zuerst prüfen
        await self.scan_localhost(discovered)
        
        # Netzwerk scannen
        for network in self.discovery_config["scan_networks"]:
            if network == "localhost":
                continue
                
            try:
                await self.scan_network(network, discovered)
            except Exception as e:
                logger.warning(f"⚠️ Fehler beim Scannen von {network}: {e}")
        
        self.discovered_services = discovered
        print(f"✅ {len(discovered)} Services entdeckt")
        
        return discovered
    
    async def scan_localhost(self, discovered: Dict):
        """Localhost Services scannen"""
        for service_name, port in self.discovery_config["service_ports"].items():
            if await self.scan_port("127.0.0.1", port):
                url = f"http://127.0.0.1:{port}"
                if await self.verify_service(url):
                    discovered[f"{service_name}@localhost"] = {
                        "name": service_name,
                        "url": url,
                        "ip": "127.0.0.1",
                        "port": port,
                        "location": "localhost"
                    }
    
    async def scan_network(self, network: str, discovered: Dict):
        """Netzwerk scannen"""
        try:
            network_obj = ipaddress.IPv4Network(network, strict=False)
            
            # Paralleles Scannen
            scan_tasks = []
            for ip in list(network_obj.hosts())[:50]:  # Maximal 50 IPs
                ip_str = str(ip)
                if ip_str != self.local_ip:
                    scan_tasks.append(self.scan_ip_for_services(ip_str, discovered))
            
            if scan_tasks:
                await asyncio.gather(*scan_tasks, return_exceptions=True)
                
        except Exception as e:
            logger.warning(f"⚠️ Netzwerk-Scan Fehler für {network}: {e}")
    
    async def scan_ip_for_services(self, ip: str, discovered: Dict):
        """Einzelne IP nach Services scannen"""
        for service_name, port in self.discovery_config["service_ports"].items():
            try:
                if await self.scan_port(ip, port, timeout=1.0):
                    url = f"http://{ip}:{port}"
                    if await self.verify_service(url):
                        key = f"{service_name}@{ip}"
                        discovered[key] = {
                            "name": service_name,
                            "url": url,
                            "ip": ip,
                            "port": port,
                            "location": "network"
                        }
            except:
                pass
    
    async def verify_service(self, url: str) -> bool:
        """Service verifizieren"""
        try:
            async with httpx.AsyncClient(timeout=3.0) as client:
                response = await client.get(f"{url}/health")
                return response.status_code == 200
        except:
            return False
    
    async def find_service(self, service_type: str) -> Optional[Dict]:
        """Besten Service eines Typs finden"""
        candidates = [
            service for service in self.discovered_services.values()
            if service["name"] == service_type
        ]
        
        if not candidates:
            return None
        
        # Localhost bevorzugen, dann nach IP sortieren
        candidates.sort(key=lambda x: (x["location"] != "localhost", x["ip"]))
        return candidates[0]
    
    async def test_service_health(self, service: Dict) -> Dict:
        """Service-Gesundheit testen"""
        try:
            start_time = time.time()
            
            async with httpx.AsyncClient(timeout=10.0) as client:
                response = await client.get(f"{service['url']}/health")
                response_time = time.time() - start_time
                
                if response.status_code == 200:
                    return {
                        "status": "healthy",
                        "response_time": response_time,
                        "data": response.json()
                    }
                else:
                    return {
                        "status": "unhealthy",
                        "response_time": response_time,
                        "error": f"HTTP {response.status_code}"
                    }
                    
        except Exception as e:
            return {
                "status": "error",
                "response_time": 0.0,
                "error": str(e)
            }
    
    async def test_llm_service(self, service: Dict) -> Dict:
        """LLM Service testen"""
        try:
            start_time = time.time()
            
            test_prompt = f"Hallo! Ich teste das Gentleman AI System von einem {self.local_hardware} Gerät mit IP {self.local_ip}. Bitte antworte kurz auf Deutsch."
            
            async with httpx.AsyncClient(timeout=30.0) as client:
                response = await client.post(
                    f"{service['url']}/generate",
                    json={"prompt": test_prompt, "max_tokens": 100}
                )
                
                response_time = time.time() - start_time
                
                if response.status_code == 200:
                    result = response.json()
                    return {
                        "status": "success",
                        "response_time": response_time,
                        "response": result.get("response", ""),
                        "tokens": result.get("tokens", 0)
                    }
                else:
                    return {
                        "status": "error",
                        "response_time": response_time,
                        "error": f"HTTP {response.status_code}"
                    }
                    
        except Exception as e:
            return {
                "status": "error",
                "response_time": 0.0,
                "error": str(e)
            }
    
    async def test_web_interface(self, service: Dict) -> Dict:
        """Web Interface testen"""
        try:
            start_time = time.time()
            
            async with httpx.AsyncClient(timeout=10.0) as client:
                # Hauptseite testen
                response = await client.get(service['url'])
                response_time = time.time() - start_time
                
                if response.status_code == 200:
                    return {
                        "status": "success",
                        "response_time": response_time,
                        "accessible": True
                    }
                else:
                    return {
                        "status": "error",
                        "response_time": response_time,
                        "error": f"HTTP {response.status_code}"
                    }
                    
        except Exception as e:
            return {
                "status": "error",
                "response_time": 0.0,
                "error": str(e)
            }
    
    async def run_comprehensive_test(self):
        """Umfassenden Test durchführen"""
        print("🎩 GENTLEMAN DISTRIBUTED SYSTEM TEST")
        print("═" * 60)
        print(f"🖥️ Teste von: {self.local_hardware} ({self.local_ip})")
        print(f"🕐 Startzeit: {self.start_time.strftime('%Y-%m-%d %H:%M:%S')}")
        print()
        
        # Services entdecken
        await self.discover_services()
        
        if not self.discovered_services:
            print("❌ Keine Services gefunden!")
            return
        
        # Entdeckte Services anzeigen
        print("🔧 Entdeckte Services:")
        for key, service in self.discovered_services.items():
            location_icon = "🏠" if service["location"] == "localhost" else "🌐"
            print(f"  {location_icon} {service['name']} - {service['url']}")
        print()
        
        # Tests durchführen
        test_results = {}
        
        # 1. Health Checks
        print("🏥 Teste Service-Gesundheit...")
        for key, service in self.discovered_services.items():
            result = await self.test_service_health(service)
            test_results[f"health_{key}"] = result
            
            status_icon = "✅" if result["status"] == "healthy" else "❌"
            print(f"  {status_icon} {service['name']} ({service['ip']}): {result['status']} ({result['response_time']:.2f}s)")
        print()
        
        # 2. LLM Test
        llm_service = await self.find_service("llm-server")
        if llm_service:
            print("🧠 Teste LLM Service...")
            llm_result = await self.test_llm_service(llm_service)
            test_results["llm_test"] = llm_result
            
            if llm_result["status"] == "success":
                print(f"  ✅ LLM Test erfolgreich ({llm_result['response_time']:.2f}s)")
                print(f"  🤖 Antwort: '{llm_result['response'][:100]}...'")
                print(f"  📊 Tokens: {llm_result['tokens']}")
            else:
                print(f"  ❌ LLM Test fehlgeschlagen: {llm_result['error']}")
            print()
        
        # 3. Web Interface Test
        web_service = await self.find_service("web-interface")
        if web_service:
            print("🌐 Teste Web Interface...")
            web_result = await self.test_web_interface(web_service)
            test_results["web_test"] = web_result
            
            if web_result["status"] == "success":
                print(f"  ✅ Web Interface erreichbar ({web_result['response_time']:.2f}s)")
                print(f"  🌐 URL: {web_service['url']}")
            else:
                print(f"  ❌ Web Interface nicht erreichbar: {web_result['error']}")
            print()
        
        # Ergebnisse zusammenfassen
        self.print_test_summary(test_results)
        
        return test_results
    
    def print_test_summary(self, results: Dict):
        """Test-Zusammenfassung ausgeben"""
        print("📊 TEST-ZUSAMMENFASSUNG")
        print("═" * 40)
        
        total_tests = len(results)
        successful_tests = len([r for r in results.values() if r.get("status") in ["healthy", "success"]])
        
        success_rate = (successful_tests / total_tests * 100) if total_tests > 0 else 0
        
        print(f"✅ Erfolgreich: {successful_tests}/{total_tests} ({success_rate:.1f}%)")
        print(f"🕐 Gesamtdauer: {(datetime.now() - self.start_time).total_seconds():.1f}s")
        print(f"🖥️ Getestet von: {self.local_hardware} ({self.local_ip})")
        
        if success_rate >= 80:
            print("🎉 SYSTEM FUNKTIONIERT AUSGEZEICHNET!")
        elif success_rate >= 60:
            print("✅ System funktioniert gut")
        else:
            print("⚠️ System hat Probleme")
        
        print()
        print("🎩 Das Gentleman AI System ist bereit für den Einsatz!")

async def main():
    """Hauptfunktion"""
    # Kommandozeilen-Argumente verarbeiten
    target_ip = None
    if len(sys.argv) > 1:
        target_ip = sys.argv[1]
        print(f"🎯 Ziel-IP spezifiziert: {target_ip}")
    
    # Test durchführen
    test = GentlemanDistributedTest()
    
    # Falls Ziel-IP angegeben, nur diese testen
    if target_ip:
        test.discovery_config["scan_networks"] = [f"{target_ip}/32"]
    
    await test.run_comprehensive_test()

if __name__ == "__main__":
    try:
        asyncio.run(main())
    except KeyboardInterrupt:
        print("\n🛑 Test abgebrochen")
    except Exception as e:
        print(f"\n❌ Test-Fehler: {e}")
        sys.exit(1) 