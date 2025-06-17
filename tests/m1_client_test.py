#!/usr/bin/env python3
"""
🎩 GENTLEMAN - M1 Client Test
═══════════════════════════════════════════════════════════════
Einfacher Test vom M1 Mac aus für das verteilte System
"""

import requests
import time
import json
from datetime import datetime

class M1ClientTester:
    def __init__(self, rx_node_ip="localhost"):
        """
        Initialisiere M1 Client Tester
        
        Args:
            rx_node_ip: IP-Adresse der RX-Node (Standard: localhost für lokale Tests)
        """
        self.rx_node_ip = rx_node_ip
        self.base_url = f"http://{rx_node_ip}:8080"
        self.session = requests.Session()
        self.session.timeout = 30
        
    def test_system_connectivity(self):
        """Teste Verbindung zum System"""
        print("🔗 Teste Systemverbindung...")
        
        try:
            response = self.session.get(f"{self.base_url}/health")
            if response.status_code == 200:
                health_data = response.json()
                print(f"✅ System erreichbar: {health_data.get('status', 'unknown')}")
                return True
            else:
                print(f"❌ System nicht erreichbar: HTTP {response.status_code}")
                return False
        except Exception as e:
            print(f"❌ Verbindungsfehler: {e}")
            return False
    
    def test_simple_chat(self):
        """Teste einfachen Chat vom M1 aus"""
        print("\n💬 Teste Chat-Funktionalität...")
        
        test_message = "Hallo! Ich bin ein M1 Mac und teste das Gentleman AI System. Bitte antworte kurz auf Deutsch."
        
        try:
            print(f"📤 Sende Nachricht: '{test_message}'")
            
            start_time = time.time()
            response = self.session.post(
                f"{self.base_url}/api/chat",
                json={"message": test_message}
            )
            duration = time.time() - start_time
            
            if response.status_code == 200:
                data = response.json()
                if data.get('success'):
                    ai_response = data.get('response', '')
                    processing_time = data.get('processing_time', 0)
                    tokens_used = data.get('tokens_used', 0)
                    
                    print(f"✅ Chat erfolgreich ({duration:.2f}s)")
                    print(f"🤖 AI Antwort: '{ai_response}'")
                    print(f"📊 Verarbeitung: {processing_time:.2f}s, {tokens_used} Tokens")
                    return True
                else:
                    error = data.get('error', 'Unbekannter Fehler')
                    print(f"❌ Chat fehlgeschlagen: {error}")
                    return False
            else:
                print(f"❌ HTTP Fehler: {response.status_code}")
                return False
                
        except Exception as e:
            print(f"❌ Chat-Fehler: {e}")
            return False
    
    def test_service_status(self):
        """Teste Status aller Services"""
        print("\n📊 Überprüfe Service-Status...")
        
        try:
            response = self.session.get(f"{self.base_url}/status")
            if response.status_code == 200:
                print("✅ Status-Seite erreichbar")
                
                # Teste auch Health-Endpoint
                health_response = self.session.get(f"{self.base_url}/health")
                if health_response.status_code == 200:
                    health_data = health_response.json()
                    services_status = health_data.get('services_status', {})
                    
                    print("🔧 Service-Status:")
                    for service, status in services_status.items():
                        status_icon = "✅" if status == "healthy" else "❌" if status == "unhealthy" else "⚠️"
                        print(f"  {status_icon} {service}: {status}")
                    
                    healthy_count = len([s for s in services_status.values() if s == "healthy"])
                    total_count = len(services_status)
                    
                    print(f"📈 Gesamt: {healthy_count}/{total_count} Services gesund")
                    return healthy_count >= total_count * 0.8  # 80% müssen gesund sein
                else:
                    print("❌ Health-Endpoint nicht erreichbar")
                    return False
            else:
                print(f"❌ Status-Seite nicht erreichbar: HTTP {response.status_code}")
                return False
                
        except Exception as e:
            print(f"❌ Status-Check Fehler: {e}")
            return False
    
    def run_full_test(self):
        """Führe vollständigen Test aus"""
        print("🎩 GENTLEMAN M1 CLIENT TEST")
        print("═" * 40)
        print(f"🖥️ Teste von M1 Mac gegen RX-Node: {self.rx_node_ip}")
        print(f"🕐 Startzeit: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
        print()
        
        results = []
        
        # Test 1: Systemverbindung
        results.append(self.test_system_connectivity())
        
        # Test 2: Service-Status
        results.append(self.test_service_status())
        
        # Test 3: Chat-Test (Haupttest)
        results.append(self.test_simple_chat())
        
        # Ergebnis
        successful_tests = sum(results)
        total_tests = len(results)
        success_rate = successful_tests / total_tests * 100
        
        print("\n" + "═" * 40)
        print("📊 TEST-ERGEBNIS:")
        print(f"✅ Erfolgreich: {successful_tests}/{total_tests} ({success_rate:.1f}%)")
        
        if success_rate >= 80:
            print("🎉 SYSTEM FUNKTIONIERT!")
            print("Das Gentleman AI System ist vom M1 aus voll funktionsfähig.")
            return True
        else:
            print("❌ SYSTEM HAT PROBLEME!")
            print("Das System benötigt weitere Überprüfung.")
            return False

def main():
    """Hauptfunktion"""
    import sys
    
    # RX-Node IP aus Argumenten oder Standard verwenden
    rx_node_ip = sys.argv[1] if len(sys.argv) > 1 else "localhost"
    
    tester = M1ClientTester(rx_node_ip)
    
    try:
        success = tester.run_full_test()
        sys.exit(0 if success else 1)
    except KeyboardInterrupt:
        print("\n⏹️ Test abgebrochen.")
        sys.exit(1)
    except Exception as e:
        print(f"\n💥 Unerwarteter Fehler: {e}")
        sys.exit(1)

if __name__ == "__main__":
    main() 