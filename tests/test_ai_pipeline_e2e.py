#!/usr/bin/env python3
"""
🎩 GENTLEMAN - End-to-End AI Pipeline Test
═══════════════════════════════════════════════════════════════
Test der kompletten AI-Pipeline: STT (M1) → LLM (RX 6700 XT) → TTS (M1)
"""

import asyncio
import aiohttp
import json
import time
import wave
import io
import base64
import logging
from pathlib import Path
from typing import Dict, Any, Optional, List
from dataclasses import dataclass
import subprocess
import tempfile

# 🎯 Test Configuration
@dataclass
class ServiceConfig:
    name: str
    host: str
    port: int
    endpoint: str
    health_endpoint: str = "/health"

@dataclass
class TestResult:
    service: str
    success: bool
    response_time: float
    error: Optional[str] = None
    data: Optional[Dict[str, Any]] = None

# 🏗️ Service Configurations
SERVICES = {
    'stt': ServiceConfig(
        name="STT Service (M1)",
        host="192.168.100.20",
        port=8002,
        endpoint="/transcribe"
    ),
    'llm': ServiceConfig(
        name="LLM Server (RX 6700 XT)",
        host="192.168.100.10", 
        port=8001,
        endpoint="/generate"
    ),
    'tts': ServiceConfig(
        name="TTS Service (M1)",
        host="192.168.100.20",
        port=8003,
        endpoint="/synthesize"
    )
}

# 🎭 Test Scenarios
TEST_SCENARIOS = [
    {
        "name": "Einfache Begrüßung",
        "text": "Hallo Gentleman, wie geht es dir heute?",
        "expected_keywords": ["hallo", "gut", "danke"]
    },
    {
        "name": "Technische Frage",
        "text": "Erkläre mir bitte Machine Learning in einfachen Worten.",
        "expected_keywords": ["machine learning", "algorithmus", "daten"]
    },
    {
        "name": "Smart Home Befehl",
        "text": "Schalte das Licht im Wohnzimmer an.",
        "expected_keywords": ["licht", "wohnzimmer", "an"]
    },
    {
        "name": "Wetter Anfrage",
        "text": "Wie wird das Wetter morgen?",
        "expected_keywords": ["wetter", "morgen", "temperatur"]
    }
]

# 🎨 Logging Setup
logging.basicConfig(
    level=logging.INFO,
    format='🎩 %(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger("gentleman-e2e-test")

class AIpipelineE2ETest:
    def __init__(self):
        self.session: Optional[aiohttp.ClientSession] = None
        self.results: List[TestResult] = []
        self.test_audio_file: Optional[str] = None
        
    async def __aenter__(self):
        """Async Context Manager Entry"""
        self.session = aiohttp.ClientSession(
            timeout=aiohttp.ClientTimeout(total=300)  # 5 Minuten Timeout
        )
        return self
        
    async def __aexit__(self, exc_type, exc_val, exc_tb):
        """Async Context Manager Exit"""
        if self.session:
            await self.session.close()
            
    def generate_test_audio(self, text: str, filename: str) -> str:
        """Generiere Test-Audio mit System TTS"""
        try:
            # macOS: say command
            if subprocess.run(["which", "say"], capture_output=True).returncode == 0:
                temp_file = f"/tmp/{filename}.aiff"
                subprocess.run([
                    "say", "-v", "Anna", "-o", temp_file, text
                ], check=True)
                
                # Konvertiere zu WAV mit ffmpeg falls verfügbar
                wav_file = f"/tmp/{filename}.wav"
                if subprocess.run(["which", "ffmpeg"], capture_output=True).returncode == 0:
                    subprocess.run([
                        "ffmpeg", "-i", temp_file, "-ar", "16000", 
                        "-ac", "1", "-y", wav_file
                    ], check=True, capture_output=True)
                    return wav_file
                return temp_file
                
            # Linux: espeak/espeak-ng
            elif subprocess.run(["which", "espeak"], capture_output=True).returncode == 0:
                wav_file = f"/tmp/{filename}.wav"
                subprocess.run([
                    "espeak", "-v", "de", "-s", "150", "-w", wav_file, text
                ], check=True)
                return wav_file
                
            else:
                # Fallback: Stilles Audio generieren
                return self.generate_silent_audio(filename)
                
        except Exception as e:
            logger.warning(f"⚠️ Audio-Generierung fehlgeschlagen: {e}")
            return self.generate_silent_audio(filename)
            
    def generate_silent_audio(self, filename: str) -> str:
        """Generiere stille Audio-Datei als Fallback"""
        wav_file = f"/tmp/{filename}.wav"
        
        # 2 Sekunden stilles Audio (16kHz, Mono)
        sample_rate = 16000
        duration = 2
        samples = [0] * (sample_rate * duration)
        
        with wave.open(wav_file, 'w') as wav:
            wav.setnchannels(1)  # Mono
            wav.setsampwidth(2)  # 16-bit
            wav.setframerate(sample_rate)
            wav.writeframes(b''.join([int(s).to_bytes(2, 'little', signed=True) for s in samples]))
            
        return wav_file
        
    async def test_service_health(self, service_key: str) -> TestResult:
        """Teste Service Health"""
        service = SERVICES[service_key]
        start_time = time.time()
        
        try:
            url = f"http://{service.host}:{service.port}{service.health_endpoint}"
            async with self.session.get(url) as response:
                response_time = time.time() - start_time
                
                if response.status == 200:
                    data = await response.json()
                    return TestResult(
                        service=service.name,
                        success=True,
                        response_time=response_time,
                        data=data
                    )
                else:
                    return TestResult(
                        service=service.name,
                        success=False,
                        response_time=response_time,
                        error=f"HTTP {response.status}"
                    )
                    
        except Exception as e:
            response_time = time.time() - start_time
            return TestResult(
                service=service.name,
                success=False,
                response_time=response_time,
                error=str(e)
            )
            
    async def test_stt_service(self, audio_file: str) -> TestResult:
        """Teste STT Service"""
        service = SERVICES['stt']
        start_time = time.time()
        
        try:
            url = f"http://{service.host}:{service.port}{service.endpoint}"
            
            # Audio-Datei lesen
            with open(audio_file, 'rb') as f:
                audio_data = f.read()
                
            # Multipart Form Data
            data = aiohttp.FormData()
            data.add_field('audio', 
                          io.BytesIO(audio_data),
                          filename='test_audio.wav',
                          content_type='audio/wav')
            
            async with self.session.post(url, data=data) as response:
                response_time = time.time() - start_time
                
                if response.status == 200:
                    result = await response.json()
                    transcribed_text = result.get('text', '')
                    
                    return TestResult(
                        service=service.name,
                        success=True,
                        response_time=response_time,
                        data={
                            'transcribed_text': transcribed_text,
                            'confidence': result.get('confidence', 0),
                            'language': result.get('language', 'unknown')
                        }
                    )
                else:
                    error_text = await response.text()
                    return TestResult(
                        service=service.name,
                        success=False,
                        response_time=response_time,
                        error=f"HTTP {response.status}: {error_text}"
                    )
                    
        except Exception as e:
            response_time = time.time() - start_time
            return TestResult(
                service=service.name,
                success=False,
                response_time=response_time,
                error=str(e)
            )
            
    async def test_llm_service(self, prompt: str) -> TestResult:
        """Teste LLM Service"""
        service = SERVICES['llm']
        start_time = time.time()
        
        try:
            url = f"http://{service.host}:{service.port}{service.endpoint}"
            
            payload = {
                "prompt": prompt,
                "max_tokens": 150,
                "temperature": 0.7,
                "language": "de"
            }
            
            async with self.session.post(url, json=payload) as response:
                response_time = time.time() - start_time
                
                if response.status == 200:
                    result = await response.json()
                    generated_text = result.get('response', result.get('text', ''))
                    
                    return TestResult(
                        service=service.name,
                        success=True,
                        response_time=response_time,
                        data={
                            'generated_text': generated_text,
                            'tokens_used': result.get('tokens_used', 0),
                            'model': result.get('model', 'unknown')
                        }
                    )
                else:
                    error_text = await response.text()
                    return TestResult(
                        service=service.name,
                        success=False,
                        response_time=response_time,
                        error=f"HTTP {response.status}: {error_text}"
                    )
                    
        except Exception as e:
            response_time = time.time() - start_time
            return TestResult(
                service=service.name,
                success=False,
                response_time=response_time,
                error=str(e)
            )
            
    async def test_tts_service(self, text: str) -> TestResult:
        """Teste TTS Service"""
        service = SERVICES['tts']
        start_time = time.time()
        
        try:
            url = f"http://{service.host}:{service.port}{service.endpoint}"
            
            payload = {
                "text": text,
                "voice": "neural_german_female",
                "speed": 1.0,
                "pitch": 1.0
            }
            
            async with self.session.post(url, json=payload) as response:
                response_time = time.time() - start_time
                
                if response.status == 200:
                    content_type = response.headers.get('content-type', '')
                    
                    if 'audio' in content_type:
                        # Binary Audio Response
                        audio_data = await response.read()
                        return TestResult(
                            service=service.name,
                            success=True,
                            response_time=response_time,
                            data={
                                'audio_size': len(audio_data),
                                'content_type': content_type,
                                'audio_format': 'wav' if 'wav' in content_type else 'unknown'
                            }
                        )
                    else:
                        # JSON Response with audio data
                        result = await response.json()
                        audio_data = result.get('audio_data', '')
                        
                        return TestResult(
                            service=service.name,
                            success=True,
                            response_time=response_time,
                            data={
                                'audio_base64_length': len(audio_data),
                                'voice': result.get('voice', 'unknown'),
                                'duration': result.get('duration', 0)
                            }
                        )
                else:
                    error_text = await response.text()
                    return TestResult(
                        service=service.name,
                        success=False,
                        response_time=response_time,
                        error=f"HTTP {response.status}: {error_text}"
                    )
                    
        except Exception as e:
            response_time = time.time() - start_time
            return TestResult(
                service=service.name,
                success=False,
                response_time=response_time,
                error=str(e)
            )
            
    async def test_full_pipeline(self, scenario: Dict[str, Any]) -> Dict[str, TestResult]:
        """Teste die komplette AI-Pipeline"""
        logger.info(f"🎯 Teste Szenario: {scenario['name']}")
        
        pipeline_results = {}
        
        # 1. Audio generieren
        audio_file = self.generate_test_audio(
            scenario['text'], 
            f"test_{scenario['name'].lower().replace(' ', '_')}"
        )
        
        # 2. STT Test
        logger.info("🎤 Teste STT Service...")
        stt_result = await self.test_stt_service(audio_file)
        pipeline_results['stt'] = stt_result
        
        if not stt_result.success:
            logger.error(f"❌ STT fehlgeschlagen: {stt_result.error}")
            return pipeline_results
            
        # 3. LLM Test mit STT Output
        transcribed_text = stt_result.data.get('transcribed_text', scenario['text'])
        logger.info(f"🧠 Teste LLM mit: '{transcribed_text}'")
        
        llm_result = await self.test_llm_service(transcribed_text)
        pipeline_results['llm'] = llm_result
        
        if not llm_result.success:
            logger.error(f"❌ LLM fehlgeschlagen: {llm_result.error}")
            return pipeline_results
            
        # 4. TTS Test mit LLM Output
        generated_text = llm_result.data.get('generated_text', 'Test response')
        logger.info(f"🔊 Teste TTS mit: '{generated_text[:50]}...'")
        
        tts_result = await self.test_tts_service(generated_text)
        pipeline_results['tts'] = tts_result
        
        if not tts_result.success:
            logger.error(f"❌ TTS fehlgeschlagen: {tts_result.error}")
            
        # Cleanup
        try:
            Path(audio_file).unlink()
        except:
            pass
            
        return pipeline_results
        
    async def run_health_checks(self) -> Dict[str, TestResult]:
        """Führe Health Checks für alle Services aus"""
        logger.info("🏥 Führe Service Health Checks aus...")
        
        health_results = {}
        for service_key in SERVICES.keys():
            result = await self.test_service_health(service_key)
            health_results[service_key] = result
            
            if result.success:
                logger.info(f"✅ {result.service}: Gesund ({result.response_time:.2f}s)")
            else:
                logger.error(f"❌ {result.service}: {result.error}")
                
        return health_results
        
    async def run_full_test_suite(self) -> Dict[str, Any]:
        """Führe die komplette Test-Suite aus"""
        logger.info("🎩 GENTLEMAN AI-Pipeline E2E Test gestartet")
        logger.info("═══════════════════════════════════════════════════════════════")
        
        test_results = {
            'start_time': time.time(),
            'health_checks': {},
            'pipeline_tests': {},
            'summary': {}
        }
        
        # 1. Health Checks
        test_results['health_checks'] = await self.run_health_checks()
        
        # Prüfe ob alle Services gesund sind
        unhealthy_services = [
            service for service, result in test_results['health_checks'].items() 
            if not result.success
        ]
        
        if unhealthy_services:
            logger.warning(f"⚠️ Ungesunde Services: {unhealthy_services}")
            logger.info("⏩ Überspringe Pipeline-Tests")
        else:
            logger.info("✅ Alle Services gesund - starte Pipeline-Tests")
            
            # 2. Pipeline Tests
            for scenario in TEST_SCENARIOS:
                try:
                    pipeline_result = await self.test_full_pipeline(scenario)
                    test_results['pipeline_tests'][scenario['name']] = pipeline_result
                    
                    # Kurze Pause zwischen Tests
                    await asyncio.sleep(2)
                    
                except Exception as e:
                    logger.error(f"❌ Pipeline-Test '{scenario['name']}' fehlgeschlagen: {e}")
                    test_results['pipeline_tests'][scenario['name']] = {
                        'error': str(e)
                    }
        
        # 3. Summary generieren
        test_results['end_time'] = time.time()
        test_results['duration'] = test_results['end_time'] - test_results['start_time']
        test_results['summary'] = self.generate_summary(test_results)
        
        return test_results
        
    def generate_summary(self, test_results: Dict[str, Any]) -> Dict[str, Any]:
        """Generiere Test-Summary"""
        summary = {
            'total_tests': 0,
            'successful_tests': 0,
            'failed_tests': 0,
            'health_status': {},
            'pipeline_status': {},
            'average_response_times': {},
            'recommendations': []
        }
        
        # Health Check Summary
        for service, result in test_results['health_checks'].items():
            summary['total_tests'] += 1
            summary['health_status'][service] = {
                'status': 'healthy' if result.success else 'unhealthy',
                'response_time': result.response_time,
                'error': result.error
            }
            
            if result.success:
                summary['successful_tests'] += 1
            else:
                summary['failed_tests'] += 1
                
        # Pipeline Test Summary
        for scenario_name, pipeline_result in test_results['pipeline_tests'].items():
            if 'error' in pipeline_result:
                summary['failed_tests'] += 1
                continue
                
            scenario_summary = {}
            total_time = 0
            
            for service, result in pipeline_result.items():
                summary['total_tests'] += 1
                total_time += result.response_time
                
                if result.success:
                    summary['successful_tests'] += 1
                    scenario_summary[service] = 'success'
                else:
                    summary['failed_tests'] += 1
                    scenario_summary[service] = 'failed'
                    
            scenario_summary['total_time'] = total_time
            summary['pipeline_status'][scenario_name] = scenario_summary
            
        # Average Response Times
        service_times = {}
        service_counts = {}
        
        for service in SERVICES.keys():
            service_times[service] = []
            
        # Sammle alle Response Times
        for result in test_results['health_checks'].values():
            if result.success:
                service_name = result.service.split(' ')[0].lower()
                if service_name in service_times:
                    service_times[service_name].append(result.response_time)
                    
        for pipeline_result in test_results['pipeline_tests'].values():
            if 'error' not in pipeline_result:
                for service, result in pipeline_result.items():
                    if result.success and service in service_times:
                        service_times[service].append(result.response_time)
                        
        # Berechne Durchschnitte
        for service, times in service_times.items():
            if times:
                summary['average_response_times'][service] = sum(times) / len(times)
                
        # Generiere Empfehlungen
        summary['recommendations'] = self.generate_recommendations(summary)
        
        return summary
        
    def generate_recommendations(self, summary: Dict[str, Any]) -> List[str]:
        """Generiere Empfehlungen basierend auf Test-Ergebnissen"""
        recommendations = []
        
        # Performance Empfehlungen
        avg_times = summary['average_response_times']
        
        if avg_times.get('stt', 0) > 3.0:
            recommendations.append("🎤 STT Service Optimierung: Response Zeit > 3s")
            
        if avg_times.get('llm', 0) > 5.0:
            recommendations.append("🧠 LLM Server Optimierung: Response Zeit > 5s, prüfe GPU-Auslastung")
            
        if avg_times.get('tts', 0) > 2.0:
            recommendations.append("🔊 TTS Service Optimierung: Response Zeit > 2s")
            
        # Health Empfehlungen
        for service, status in summary['health_status'].items():
            if status['status'] == 'unhealthy':
                recommendations.append(f"🚨 {service.upper()} Service reparieren: {status['error']}")
                
        # Success Rate Empfehlungen
        if summary['total_tests'] > 0:
            success_rate = summary['successful_tests'] / summary['total_tests']
            if success_rate < 0.8:
                recommendations.append(f"📊 Erfolgsrate niedrig ({success_rate:.1%}): System-Debugging empfohlen")
                
        if not recommendations:
            recommendations.append("✅ Alle Tests erfolgreich - System läuft optimal!")
            
        return recommendations
        
    def print_results(self, test_results: Dict[str, Any]):
        """Gib Test-Ergebnisse formatiert aus"""
        print("\n" + "="*80)
        print("🎩 GENTLEMAN AI-PIPELINE TEST ERGEBNISSE")
        print("="*80)
        
        duration = test_results['duration']
        summary = test_results['summary']
        
        print(f"⏱️  Gesamtdauer: {duration:.2f}s")
        print(f"📊 Tests gesamt: {summary['total_tests']}")
        print(f"✅ Erfolgreich: {summary['successful_tests']}")
        print(f"❌ Fehlgeschlagen: {summary['failed_tests']}")
        
        if summary['total_tests'] > 0:
            success_rate = summary['successful_tests'] / summary['total_tests']
            print(f"📈 Erfolgsrate: {success_rate:.1%}")
            
        print("\n" + "-"*50)
        print("🏥 SERVICE HEALTH STATUS")
        print("-"*50)
        
        for service, status in summary['health_status'].items():
            emoji = "✅" if status['status'] == 'healthy' else "❌"
            print(f"{emoji} {service.upper()}: {status['response_time']:.2f}s")
            if status['error']:
                print(f"    Fehler: {status['error']}")
                
        print("\n" + "-"*50)
        print("🔄 PIPELINE TEST RESULTS")
        print("-"*50)
        
        for scenario, result in summary['pipeline_status'].items():
            print(f"\n🎯 {scenario}:")
            if 'total_time' in result:
                print(f"    ⏱️  Gesamtzeit: {result['total_time']:.2f}s")
                for service, status in result.items():
                    if service != 'total_time':
                        emoji = "✅" if status == 'success' else "❌"
                        print(f"    {emoji} {service.upper()}")
            else:
                print("    ❌ Test fehlgeschlagen")
                
        print("\n" + "-"*50)
        print("⚡ PERFORMANCE METRIKEN")
        print("-"*50)
        
        for service, avg_time in summary['average_response_times'].items():
            print(f"📊 {service.upper()}: {avg_time:.2f}s Durchschnitt")
            
        print("\n" + "-"*50)
        print("💡 EMPFEHLUNGEN")
        print("-"*50)
        
        for recommendation in summary['recommendations']:
            print(f"   {recommendation}")
            
        print("\n" + "="*80)


async def main():
    """Hauptfunktion"""
    async with AIpipelineE2ETest() as tester:
        results = await tester.run_full_test_suite()
        tester.print_results(results)
        
        # JSON Export für weitere Analyse
        output_file = f"/tmp/gentleman_e2e_test_{int(time.time())}.json"
        with open(output_file, 'w') as f:
            json.dump(results, f, indent=2, default=str)
        print(f"\n📄 Detaillierte Ergebnisse exportiert: {output_file}")


if __name__ == "__main__":
    asyncio.run(main())