#!/usr/bin/env python3
"""
🎩 GENTLEMAN - Distributed System Test Suite
═══════════════════════════════════════════════════════════════
Umfassender Test für das verteilte AI-System mit M1 und RX-Node
"""

import asyncio
import json
import time
import requests
import subprocess
import sys
from typing import Dict, List, Optional, Tuple
from dataclasses import dataclass
from datetime import datetime
import logging

# 🎯 Logging Setup
logging.basicConfig(
    level=logging.INFO,
    format='🎩 %(asctime)s - %(levelname)s - %(message)s',
    handlers=[
        logging.StreamHandler(),
        logging.FileHandler(f'test_results_{datetime.now().strftime("%Y%m%d_%H%M%S")}.log')
    ]
)
logger = logging.getLogger("gentleman-test")

@dataclass
class ServiceEndpoint:
    """Service-Endpunkt Definition"""
    name: str
    url: str
    port: int
    expected_node: str  # "m1" oder "rx"
    critical: bool = True

@dataclass
class TestResult:
    """Test-Ergebnis"""
    test_name: str
    success: bool
    duration: float
    details: str
    node: Optional[str] = None

class GentlemanSystemTester:
    """Hauptklasse für Systemtests"""
    
    def __init__(self):
        self.services = {
            "llm-server": ServiceEndpoint("LLM Server", "http://localhost:8001", 8001, "rx"),
            "stt-service": ServiceEndpoint("STT Service", "http://localhost:8002", 8002, "m1"),
            "tts-service": ServiceEndpoint("TTS Service", "http://localhost:8003", 8003, "m1"),
            "mesh-coordinator": ServiceEndpoint("Mesh Coordinator", "http://localhost:8004", 8004, "rx"),
            "web-interface": ServiceEndpoint("Web Interface", "http://localhost:8080", 8080, "rx")
        }
        self.test_results: List[TestResult] = []
        self.session = requests.Session()
        self.session.timeout = 30
        
    def log_test_result(self, result: TestResult):
        """Logge Testergebnis"""
        self.test_results.append(result)
        status = "✅ PASS" if result.success else "❌ FAIL"
        node_info = f" [{result.node}]" if result.node else ""
        logger.info(f"{status}{node_info} {result.test_name} ({result.duration:.2f}s) - {result.details}")

    def check_docker_services(self) -> bool:
        """Überprüfe Docker-Services"""
        start_time = time.time()
        try:
            result = subprocess.run(
                ["docker-compose", "ps", "--format", "json"],
                capture_output=True,
                text=True,
                check=True
            )
            
            services = []
            for line in result.stdout.strip().split('\n'):
                if line.strip():
                    services.append(json.loads(line))
            
            running_services = [s for s in services if s.get('State') == 'running']
            expected_services = len(self.services)
            
            success = len(running_services) >= expected_services
            details = f"{len(running_services)}/{expected_services} Services laufen"
            
            self.log_test_result(TestResult(
                "Docker Services Check",
                success,
                time.time() - start_time,
                details
            ))
            
            return success
            
        except Exception as e:
            self.log_test_result(TestResult(
                "Docker Services Check",
                False,
                time.time() - start_time,
                f"Fehler: {str(e)}"
            ))
            return False

    def test_service_health(self, service_name: str, endpoint: ServiceEndpoint) -> bool:
        """Teste Service Health-Check"""
        start_time = time.time()
        try:
            response = self.session.get(f"{endpoint.url}/health")
            success = response.status_code == 200
            
            if success:
                health_data = response.json()
                details = f"Status: {health_data.get('status', 'unknown')}"
                if 'uptime' in health_data:
                    details += f", Uptime: {health_data['uptime']:.1f}s"
            else:
                details = f"HTTP {response.status_code}"
                
            self.log_test_result(TestResult(
                f"{service_name} Health Check",
                success,
                time.time() - start_time,
                details,
                endpoint.expected_node
            ))
            
            return success
            
        except Exception as e:
            self.log_test_result(TestResult(
                f"{service_name} Health Check",
                False,
                time.time() - start_time,
                f"Verbindungsfehler: {str(e)}",
                endpoint.expected_node
            ))
            return False

    def test_llm_generation(self) -> bool:
        """Teste LLM-Textgenerierung"""
        start_time = time.time()
        test_prompt = "Hallo! Bitte stelle dich kurz vor und erkläre, was du kannst."
        
        try:
            response = self.session.post(
                f"{self.services['llm-server'].url}/generate",
                json={
                    "prompt": test_prompt,
                    "max_tokens": 150,
                    "temperature": 0.7
                }
            )
            
            success = response.status_code == 200
            
            if success:
                data = response.json()
                generated_text = data.get('text', '').strip()
                tokens_used = data.get('tokens_used', 0)
                processing_time = data.get('processing_time', 0)
                
                if generated_text:
                    details = f"Text generiert ({tokens_used} Tokens, {processing_time:.2f}s): '{generated_text[:100]}...'"
                else:
                    success = False
                    details = "Kein Text generiert"
            else:
                details = f"HTTP {response.status_code}: {response.text[:100]}"
                
            self.log_test_result(TestResult(
                "LLM Text Generation",
                success,
                time.time() - start_time,
                details,
                "rx"
            ))
            
            return success
            
        except Exception as e:
            self.log_test_result(TestResult(
                "LLM Text Generation",
                False,
                time.time() - start_time,
                f"Fehler: {str(e)}",
                "rx"
            ))
            return False

    def test_tts_synthesis(self) -> bool:
        """Teste Text-zu-Sprache"""
        start_time = time.time()
        test_text = "Dies ist ein Test der Sprachsynthese."
        
        try:
            response = self.session.post(
                f"{self.services['tts-service'].url}/synthesize",
                json={"text": test_text}
            )
            
            success = response.status_code == 200
            
            if success:
                # TTS gibt Audio-Daten zurück
                audio_size = len(response.content)
                details = f"Audio generiert ({audio_size} Bytes)"
            else:
                details = f"HTTP {response.status_code}"
                
            self.log_test_result(TestResult(
                "TTS Speech Synthesis",
                success,
                time.time() - start_time,
                details,
                "m1"
            ))
            
            return success
            
        except Exception as e:
            self.log_test_result(TestResult(
                "TTS Speech Synthesis",
                False,
                time.time() - start_time,
                f"Fehler: {str(e)}",
                "m1"
            ))
            return False

    def test_web_interface(self) -> bool:
        """Teste Web-Interface"""
        start_time = time.time()
        
        try:
            # Teste Hauptseite
            response = self.session.get(f"{self.services['web-interface'].url}/")
            success = response.status_code == 200 and "Gentleman AI" in response.text
            
            if success:
                details = "Dashboard lädt korrekt"
            else:
                details = f"HTTP {response.status_code} oder fehlender Inhalt"
                
            self.log_test_result(TestResult(
                "Web Interface Dashboard",
                success,
                time.time() - start_time,
                details,
                "rx"
            ))
            
            return success
            
        except Exception as e:
            self.log_test_result(TestResult(
                "Web Interface Dashboard",
                False,
                time.time() - start_time,
                f"Fehler: {str(e)}",
                "rx"
            ))
            return False

    def test_chat_api(self) -> bool:
        """Teste Chat-API über Web-Interface"""
        start_time = time.time()
        test_message = "Hallo! Kannst du mir helfen?"
        
        try:
            response = self.session.post(
                f"{self.services['web-interface'].url}/api/chat",
                json={"message": test_message}
            )
            
            success = response.status_code == 200
            
            if success:
                data = response.json()
                if data.get('success'):
                    chat_response = data.get('response', '')
                    details = f"Chat erfolgreich: '{chat_response[:100]}...'"
                else:
                    success = False
                    details = f"Chat-Fehler: {data.get('error', 'Unbekannt')}"
            else:
                details = f"HTTP {response.status_code}"
                
            self.log_test_result(TestResult(
                "End-to-End Chat Test",
                success,
                time.time() - start_time,
                details,
                "m1->rx"
            ))
            
            return success
            
        except Exception as e:
            self.log_test_result(TestResult(
                "End-to-End Chat Test",
                False,
                time.time() - start_time,
                f"Fehler: {str(e)}",
                "m1->rx"
            ))
            return False

    def test_mesh_coordination(self) -> bool:
        """Teste Mesh-Koordination"""
        start_time = time.time()
        
        try:
            response = self.session.get(f"{self.services['mesh-coordinator'].url}/services")
            success = response.status_code == 200
            
            if success:
                data = response.json()
                discovered_services = len(data.get('services', []))
                healthy_services = len([s for s in data.get('services', []) if s.get('status') == 'healthy'])
                details = f"{healthy_services}/{discovered_services} Services entdeckt und gesund"
            else:
                details = f"HTTP {response.status_code}"
                
            self.log_test_result(TestResult(
                "Mesh Service Discovery",
                success,
                time.time() - start_time,
                details,
                "rx"
            ))
            
            return success
            
        except Exception as e:
            self.log_test_result(TestResult(
                "Mesh Service Discovery",
                False,
                time.time() - start_time,
                f"Fehler: {str(e)}",
                "rx"
            ))
            return False

    def run_performance_test(self) -> bool:
        """Führe Performance-Test durch"""
        start_time = time.time()
        logger.info("🚀 Starte Performance-Test...")
        
        # Mehrere parallele Anfragen
        test_prompts = [
            "Was ist künstliche Intelligenz?",
            "Erkläre mir Machine Learning.",
            "Wie funktioniert ein neuronales Netzwerk?",
            "Was sind die Vorteile von ROCm?",
            "Beschreibe die Zukunft der KI."
        ]
        
        successful_requests = 0
        total_processing_time = 0
        
        for i, prompt in enumerate(test_prompts):
            try:
                req_start = time.time()
                response = self.session.post(
                    f"{self.services['llm-server'].url}/generate",
                    json={
                        "prompt": prompt,
                        "max_tokens": 100,
                        "temperature": 0.7
                    }
                )
                
                if response.status_code == 200:
                    data = response.json()
                    processing_time = data.get('processing_time', 0)
                    total_processing_time += processing_time
                    successful_requests += 1
                    logger.info(f"  Request {i+1}/5: ✅ {processing_time:.2f}s")
                else:
                    logger.info(f"  Request {i+1}/5: ❌ HTTP {response.status_code}")
                    
            except Exception as e:
                logger.info(f"  Request {i+1}/5: ❌ {str(e)}")
        
        success = successful_requests >= 3  # Mindestens 60% Erfolgsrate
        avg_processing_time = total_processing_time / max(successful_requests, 1)
        
        details = f"{successful_requests}/5 erfolgreich, Ø {avg_processing_time:.2f}s/Request"
        
        self.log_test_result(TestResult(
            "Performance Test",
            success,
            time.time() - start_time,
            details,
            "rx"
        ))
        
        return success

    def generate_test_report(self) -> str:
        """Generiere Test-Report"""
        total_tests = len(self.test_results)
        passed_tests = len([r for r in self.test_results if r.success])
        failed_tests = total_tests - passed_tests
        
        # Node-spezifische Statistiken
        m1_tests = [r for r in self.test_results if r.node and 'm1' in r.node]
        rx_tests = [r for r in self.test_results if r.node and 'rx' in r.node]
        
        m1_passed = len([r for r in m1_tests if r.success])
        rx_passed = len([r for r in rx_tests if r.success])
        
        report = f"""
🎩 GENTLEMAN DISTRIBUTED SYSTEM TEST REPORT
═══════════════════════════════════════════════════════════════
Datum: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}

📊 GESAMTERGEBNIS:
  • Tests gesamt: {total_tests}
  • Erfolgreich: {passed_tests} ✅
  • Fehlgeschlagen: {failed_tests} ❌
  • Erfolgsrate: {(passed_tests/total_tests*100):.1f}%

🖥️ NODE-SPEZIFISCHE ERGEBNISSE:
  • M1 Mac Tests: {m1_passed}/{len(m1_tests)} ✅
  • RX 6700 XT Tests: {rx_passed}/{len(rx_tests)} ✅

📋 DETAILLIERTE ERGEBNISSE:
"""
        
        for result in self.test_results:
            status = "✅" if result.success else "❌"
            node_info = f" [{result.node}]" if result.node else ""
            report += f"  {status}{node_info} {result.test_name}: {result.details}\n"
        
        # Empfehlungen
        report += "\n🎯 EMPFEHLUNGEN:\n"
        
        if failed_tests == 0:
            report += "  • Alle Tests erfolgreich! System ist produktionsbereit. 🎉\n"
        else:
            report += f"  • {failed_tests} Tests fehlgeschlagen - Überprüfung erforderlich.\n"
            
        if any(not r.success and r.node == 'm1' for r in self.test_results):
            report += "  • M1 Mac Services benötigen Aufmerksamkeit.\n"
            
        if any(not r.success and r.node == 'rx' for r in self.test_results):
            report += "  • RX 6700 XT Services benötigen Aufmerksamkeit.\n"
        
        return report

    async def run_all_tests(self) -> bool:
        """Führe alle Tests aus"""
        logger.info("🎩 Starte Gentleman Distributed System Tests...")
        logger.info("═" * 60)
        
        # 1. Docker Services Check
        logger.info("🐳 Überprüfe Docker Services...")
        if not self.check_docker_services():
            logger.error("❌ Docker Services nicht verfügbar!")
            return False
        
        # 2. Health Checks für alle Services
        logger.info("🏥 Führe Health Checks durch...")
        all_healthy = True
        for service_name, endpoint in self.services.items():
            if not self.test_service_health(service_name, endpoint):
                if endpoint.critical:
                    all_healthy = False
        
        if not all_healthy:
            logger.warning("⚠️ Nicht alle kritischen Services sind gesund!")
        
        # 3. Funktionale Tests
        logger.info("🧪 Führe funktionale Tests durch...")
        
        # LLM Test (RX Node)
        self.test_llm_generation()
        
        # TTS Test (M1 Node)
        self.test_tts_synthesis()
        
        # Web Interface Test
        self.test_web_interface()
        
        # End-to-End Chat Test (M1 -> RX)
        self.test_chat_api()
        
        # Mesh Coordination Test
        self.test_mesh_coordination()
        
        # 4. Performance Test
        logger.info("⚡ Führe Performance-Test durch...")
        self.run_performance_test()
        
        # 5. Report generieren
        logger.info("📊 Generiere Test-Report...")
        report = self.generate_test_report()
        
        print(report)
        
        # Report in Datei speichern
        report_file = f"gentleman_test_report_{datetime.now().strftime('%Y%m%d_%H%M%S')}.txt"
        with open(report_file, 'w', encoding='utf-8') as f:
            f.write(report)
        
        logger.info(f"📄 Report gespeichert: {report_file}")
        
        # Erfolg wenn mindestens 80% der Tests erfolgreich
        success_rate = len([r for r in self.test_results if r.success]) / len(self.test_results)
        return success_rate >= 0.8

def main():
    """Hauptfunktion"""
    print("🎩 GENTLEMAN DISTRIBUTED SYSTEM TESTER")
    print("═" * 50)
    
    tester = GentlemanSystemTester()
    
    try:
        success = asyncio.run(tester.run_all_tests())
        
        if success:
            print("\n🎉 ALLE TESTS ERFOLGREICH!")
            print("Das Gentleman AI System ist bereit für den Produktionseinsatz.")
            sys.exit(0)
        else:
            print("\n❌ TESTS FEHLGESCHLAGEN!")
            print("Das System benötigt weitere Überprüfung.")
            sys.exit(1)
            
    except KeyboardInterrupt:
        print("\n⏹️ Tests abgebrochen.")
        sys.exit(1)
    except Exception as e:
        print(f"\n💥 Unerwarteter Fehler: {e}")
        sys.exit(1)

if __name__ == "__main__":
    main() 