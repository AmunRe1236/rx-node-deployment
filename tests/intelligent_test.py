#!/usr/bin/env python3
"""
🎩 GENTLEMAN Intelligent Test
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

try:
    import httpx
except ImportError:
    print("❌ httpx nicht installiert. Installiere mit: pip install httpx")
    sys.exit(1)

# 🎯 Logging Setup
logging.basicConfig(
    level=logging.INFO,
    format='🎩 %(asctime)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger("gentleman-test")

class GentlemanIntelligentTest:
    """Intelligenter Test für das Gentleman AI System"""
    
    def __init__(self):
        self.discovered_services = {}
        self.test_results = {}
        self.start_time = datetime.now()
        
        # Hardware-Info
        self.local_hardware = self.detect_hardware()
        self.local_ip = self.get_local_ip()
        
        # Discovery-Konfiguration
        self.discovery_config = {
            "scan_networks": [
                "127.0.0.1/32",      # Localhost zuerst
                "192.168.1.0/24",    # Typisches Heimnetzwerk
                "192.168.0.0/24",    # Alternative
                "10.0.0.0/24",       # Docker/VPN
                "172.20.0.0/16"      # Docker Compose
            ],
            "service_ports": {
                "llm-server": 8001,
                "stt-service": 8002,
                "tts-service": 8003,
                "mesh-coordinator": 8004,
                "web-interface": 8080
            },
            "timeout": 2.0
        }
    
    def detect_hardware(self) -> str:
        """Hardware-Typ erkennen"""
        try:
            system = platform.system().lower()
            machine = platform.machine().lower()
            
            if system == "darwin":
                if "arm" in machine or "m1" in machine or "m2" in machine:
                    return "Apple Silicon M1/M2"
                else:
                    return "Intel Mac"
            elif system == "linux":
                # Versuche GPU zu erkennen
                try:
                    import subprocess
                    result = subprocess.run(["lspci"], capture_output=True, text=True, timeout=3)
                    if "amd" in result.stdout.lower() and "radeon" in result.stdout.lower():
                        return "Linux mit AMD GPU (RX 6700 XT)"
                    elif "nvidia" in result.stdout.lower():
                        return "Linux mit NVIDIA GPU"
                except:
                    pass
                return "Linux System"
            else:
                return f"{system.title()} System"
        except:
            return "Unbekanntes System"
    
    def get_local_ip(self) -> str:
        """Lokale IP ermitteln"""
        try:
            with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as s:
                s.connect(("8.8.8.8", 80))
                return s.getsockname()[0]
        except:
            return "127.0.0.1"
    
    async def scan_port(self, ip: str, port: int, timeout: float = 1.0) -> bool:
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
        print("🔍 Intelligente Service-Discovery...")
        print(f"   Scanne von: {self.local_hardware} ({self.local_ip})")
        
        discovered = {}
        
        # Localhost zuerst und gründlich prüfen
        await self.scan_localhost(discovered)
        
        # Dann Netzwerk scannen (falls nötig)
        if len(discovered) < 3:  # Weniger als 3 Services lokal gefunden
            print("   Erweitere Suche auf Netzwerk...")
            await self.scan_networks(discovered)
        
        self.discovered_services = discovered
        print(f"✅ {len(discovered)} Services entdeckt")
        
        return discovered
    
    async def scan_localhost(self, discovered: Dict):
        """Localhost gründlich scannen"""
        print("   🏠 Scanne localhost...")
        
        for service_name, port in self.discovery_config["service_ports"].items():
            if await self.scan_port("127.0.0.1", port, timeout=1.0):
                url = f"http://127.0.0.1:{port}"
                if await self.verify_service(url):
                    discovered[f"{service_name}@localhost"] = {
                        "name": service_name,
                        "url": url,
                        "ip": "127.0.0.1",
                        "port": port,
                        "location": "localhost",
                        "priority": 1  # Höchste Priorität
                    }
                    print(f"      ✅ {service_name} gefunden")
    
    async def scan_networks(self, discovered: Dict):
        """Netzwerke scannen"""
        for network in self.discovery_config["scan_networks"]:
            if network.startswith("127.0.0.1"):
                continue  # Localhost bereits gescannt
                
            try:
                print(f"   🌐 Scanne {network}...")
                await self.scan_network(network, discovered)
            except Exception as e:
                logger.debug(f"Netzwerk-Scan Fehler für {network}: {e}")
    
    async def scan_network(self, network: str, discovered: Dict):
        """Einzelnes Netzwerk scannen"""
        try:
            network_obj = ipaddress.IPv4Network(network, strict=False)
            
            # Begrenze auf erste 20 IPs für Performance
            hosts = list(network_obj.hosts())[:20]
            
            # Paralleles Scannen
            scan_tasks = []
            for ip in hosts:
                ip_str = str(ip)
                if ip_str != self.local_ip:  # Nicht sich selbst scannen
                    scan_tasks.append(self.scan_ip_for_services(ip_str, discovered))
            
            if scan_tasks:
                await asyncio.gather(*scan_tasks, return_exceptions=True)
                
        except Exception as e:
            logger.debug(f"Netzwerk-Scan Fehler: {e}")
    
    async def scan_ip_for_services(self, ip: str, discovered: Dict):
        """Einzelne IP nach Services scannen"""
        for service_name, port in self.discovery_config["service_ports"].items():
            try:
                if await self.scan_port(ip, port, timeout=0.5):
                    url = f"http://{ip}:{port}"
                    if await self.verify_service(url):
                        key = f"{service_name}@{ip}"
                        if key not in discovered:  # Nicht überschreiben falls bereits gefunden
                            discovered[key] = {
                                "name": service_name,
                                "url": url,
                                "ip": ip,
                                "port": port,
                                "location": "network",
                                "priority": 2  # Niedrigere Priorität als localhost
                            }
            except:
                pass
    
    async def verify_service(self, url: str) -> bool:
        """Service verifizieren"""
        try:
            async with httpx.AsyncClient(timeout=2.0) as client:
                response = await client.get(f"{url}/health")
                return response.status_code == 200
        except:
            return False
    
    async def find_best_service(self, service_type: str) -> Optional[Dict]:
        """Besten Service eines Typs finden"""
        candidates = [
            service for service in self.discovered_services.values()
            if service["name"] == service_type
        ]
        
        if not candidates:
            return None
        
        # Nach Priorität sortieren (localhost zuerst)
        candidates.sort(key=lambda x: (x["priority"], x["ip"]))
        return candidates[0]
    
    async def test_service_health(self, service: Dict) -> Dict:
        """Service-Gesundheit testen"""
        try:
            start_time = time.time()
            
            async with httpx.AsyncClient(timeout=5.0) as client:
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
            
            test_prompt = f"Hallo! Ich teste das Gentleman AI System von einem {self.local_hardware} mit IP {self.local_ip}. Bitte antworte kurz auf Deutsch."
            
            async with httpx.AsyncClient(timeout=20.0) as client:
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
            
            async with httpx.AsyncClient(timeout=5.0) as client:
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
        print("🎩 GENTLEMAN INTELLIGENT SYSTEM TEST")
        print("═" * 60)
        print(f"🖥️ Hardware: {self.local_hardware}")
        print(f"🌐 IP-Adresse: {self.local_ip}")
        print(f"🕐 Startzeit: {self.start_time.strftime('%Y-%m-%d %H:%M:%S')}")
        print()
        
        # Services entdecken
        await self.discover_services()
        
        if not self.discovered_services:
            print("❌ Keine Gentleman AI Services gefunden!")
            print("💡 Tipps:")
            print("   • Stelle sicher, dass Services laufen: docker-compose up -d")
            print("   • Prüfe Firewall-Einstellungen")
            print("   • Versuche manuell: curl http://localhost:8080/health")
            return False
        
        # Entdeckte Services anzeigen
        print("🔧 Entdeckte Services:")
        for key, service in self.discovered_services.items():
            location_icon = "🏠" if service["location"] == "localhost" else "🌐"
            priority_text = "⭐" if service["priority"] == 1 else ""
            print(f"  {location_icon} {service['name']} - {service['url']} {priority_text}")
        print()
        
        # Tests durchführen
        test_results = {}
        
        # 1. Health Checks für alle Services
        print("🏥 Teste Service-Gesundheit...")
        healthy_services = 0
        for key, service in self.discovered_services.items():
            result = await self.test_service_health(service)
            test_results[f"health_{key}"] = result
            
            status_icon = "✅" if result["status"] == "healthy" else "❌"
            location_icon = "🏠" if service["location"] == "localhost" else "🌐"
            print(f"  {status_icon} {location_icon} {service['name']} ({service['ip']}): {result['status']} ({result['response_time']:.2f}s)")
            
            if result["status"] == "healthy":
                healthy_services += 1
        print()
        
        # 2. LLM Test (wichtigster Test)
        llm_service = await self.find_best_service("llm-server")
        if llm_service:
            print("🧠 Teste LLM Service (Kernfunktionalität)...")
            llm_result = await self.test_llm_service(llm_service)
            test_results["llm_test"] = llm_result
            
            if llm_result["status"] == "success":
                print(f"  ✅ LLM Test erfolgreich ({llm_result['response_time']:.2f}s)")
                print(f"  🤖 AI Antwort: '{llm_result['response'][:80]}...'")
                print(f"  📊 Tokens: {llm_result['tokens']}")
                print(f"  🔧 Service: {llm_service['url']}")
            else:
                print(f"  ❌ LLM Test fehlgeschlagen: {llm_result['error']}")
            print()
        else:
            print("⚠️ Kein LLM Service gefunden - Kernfunktionalität nicht verfügbar")
            print()
        
        # 3. Web Interface Test
        web_service = await self.find_best_service("web-interface")
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
        
        # 4. Mesh Coordinator Test (falls verfügbar)
        mesh_service = await self.find_best_service("mesh-coordinator")
        if mesh_service:
            print("🕸️ Teste Mesh Coordinator...")
            try:
                async with httpx.AsyncClient(timeout=5.0) as client:
                    response = await client.get(f"{mesh_service['url']}/mesh/status")
                    if response.status_code == 200:
                        print(f"  ✅ Mesh Coordinator aktiv")
                        mesh_data = response.json()
                        print(f"  📊 Services im Mesh: {mesh_data.get('network_info', {}).get('total_services', 'N/A')}")
                    else:
                        print(f"  ⚠️ Mesh Coordinator antwortet nicht korrekt")
            except Exception as e:
                print(f"  ❌ Mesh Coordinator Fehler: {e}")
            print()
        
        # Ergebnisse zusammenfassen
        self.print_test_summary(test_results, healthy_services)
        
        return len([r for r in test_results.values() if r.get("status") in ["healthy", "success"]]) > 0
    
    def print_test_summary(self, results: Dict, healthy_services: int):
        """Test-Zusammenfassung ausgeben"""
        print("📊 TEST-ZUSAMMENFASSUNG")
        print("═" * 40)
        
        total_tests = len(results)
        successful_tests = len([r for r in results.values() if r.get("status") in ["healthy", "success"]])
        
        success_rate = (successful_tests / total_tests * 100) if total_tests > 0 else 0
        
        print(f"✅ Erfolgreich: {successful_tests}/{total_tests} ({success_rate:.1f}%)")
        print(f"🏥 Gesunde Services: {healthy_services}/{len(self.discovered_services)}")
        print(f"🕐 Gesamtdauer: {(datetime.now() - self.start_time).total_seconds():.1f}s")
        print(f"🖥️ Getestet von: {self.local_hardware}")
        print(f"🌐 IP-Adresse: {self.local_ip}")
        
        # Bewertung
        if success_rate >= 80 and healthy_services >= 3:
            print("\n🎉 SYSTEM FUNKTIONIERT AUSGEZEICHNET!")
            print("   Alle wichtigen Services sind verfügbar und funktionsfähig.")
        elif success_rate >= 60 and healthy_services >= 2:
            print("\n✅ System funktioniert gut")
            print("   Die meisten Services sind verfügbar.")
        elif healthy_services >= 1:
            print("\n⚠️ System funktioniert teilweise")
            print("   Einige Services sind verfügbar, aber nicht alle.")
        else:
            print("\n❌ System hat Probleme")
            print("   Keine oder nur wenige Services verfügbar.")
        
        # Nützliche Links
        if healthy_services > 0:
            print("\n🔗 Nützliche Links:")
            web_service = next((s for s in self.discovered_services.values() if s["name"] == "web-interface"), None)
            if web_service:
                print(f"   🌐 Web Interface: {web_service['url']}")
            
            llm_service = next((s for s in self.discovered_services.values() if s["name"] == "llm-server"), None)
            if llm_service:
                print(f"   🧠 LLM API: {llm_service['url']}/docs")
            
            mesh_service = next((s for s in self.discovered_services.values() if s["name"] == "mesh-coordinator"), None)
            if mesh_service:
                print(f"   🕸️ Mesh Status: {mesh_service['url']}/mesh/status")
        
        print("\n🎩 Gentleman AI System - Intelligente verteilte KI")

async def main():
    """Hauptfunktion"""
    print("🎩 Gentleman AI - Intelligenter System-Test")
    print("Automatische Service-Discovery und Hardware-optimierte Tests")
    print()
    
    # Kommandozeilen-Argumente verarbeiten
    if len(sys.argv) > 1 and sys.argv[1] in ["-h", "--help", "help"]:
        print("Verwendung: python3 intelligent_test.py [Optionen]")
        print()
        print("Dieser Test findet automatisch alle verfügbaren Gentleman AI Services")
        print("und führt intelligente Tests basierend auf der erkannten Hardware durch.")
        print()
        print("Der Test funktioniert von jedem Gerät aus:")
        print("  • M1/M2 Mac")
        print("  • Linux mit AMD/NVIDIA GPU")
        print("  • Jedes andere System im Netzwerk")
        print()
        return
    
    # Test durchführen
    test = GentlemanIntelligentTest()
    
    try:
        success = await test.run_comprehensive_test()
        sys.exit(0 if success else 1)
    except KeyboardInterrupt:
        print("\n🛑 Test abgebrochen")
        sys.exit(1)
    except Exception as e:
        print(f"\n❌ Unerwarteter Fehler: {e}")
        logger.exception("Test-Fehler")
        sys.exit(1)

if __name__ == "__main__":
    asyncio.run(main()) 