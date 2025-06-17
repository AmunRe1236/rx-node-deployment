# 🎩 GENTLEMAN AI - Test Suite

Umfassende Test-Suite für das verteilte Gentleman AI System mit M1 Mac und RX 6700 XT Node.

## 📋 Übersicht

Diese Test-Suite ermöglicht es, das verteilte Gentleman AI System zu testen, bei dem:
- **M1 Mac**: STT (Spracherkennung) und TTS (Sprachsynthese) Services
- **RX 6700 XT Node**: LLM Server, Mesh Coordinator und Web Interface

## 🚀 Schnellstart

### Lokaler Test (alle Services auf einer Maschine)
```bash
# Einfacher Test
python3 tests/m1_client_test.py

# Mit Test-Runner
./tests/run_tests.sh local
```

### Verteilter Test (M1 → RX Node)
```bash
# M1 Mac testet gegen entfernte RX-Node
python3 tests/m1_client_test.py 192.168.1.100

# Mit Test-Runner
./tests/run_tests.sh distributed 192.168.1.100
```

## 📁 Test-Dateien

### `m1_client_test.py`
**Einfacher Client-Test vom M1 Mac aus**

- ✅ Systemverbindung testen
- ✅ Service-Status überprüfen  
- ✅ End-to-End Chat-Test mit LLM
- ✅ Einfache Ausgabe und Ergebnisse

**Verwendung:**
```bash
python3 tests/m1_client_test.py [RX_NODE_IP]
```

**Beispiele:**
```bash
# Lokaler Test
python3 tests/m1_client_test.py

# Test gegen entfernte RX-Node
python3 tests/m1_client_test.py 192.168.1.100
```

### `distributed_system_test.py`
**Umfassender Systemtest (in Entwicklung)**

- 🔍 Vollständige Service-Discovery
- 🧪 Funktionale Tests aller Services
- ⚡ Performance-Tests
- 📊 Detaillierte Berichte
- 🎯 Node-spezifische Analyse

### `run_tests.sh`
**Bash-Script für einfache Testausführung**

```bash
# Lokaler Test
./tests/run_tests.sh local

# Verteilter Test
./tests/run_tests.sh distributed 192.168.1.100

# Vollständiger Test
./tests/run_tests.sh full
```

## 🎯 Test-Szenarien

### 1. Lokaler Entwicklungstest
Alle Services laufen auf einer Maschine (Docker Compose):
```bash
docker-compose up -d
python3 tests/m1_client_test.py localhost
```

### 2. Verteilter Produktionstest
M1 Mac testet gegen entfernte RX-Node:
```bash
# Auf RX-Node: Services starten
docker-compose up -d

# Auf M1 Mac: Test ausführen
python3 tests/m1_client_test.py <RX_NODE_IP>
```

### 3. Vollständiger Systemtest
Umfassende Tests aller Komponenten:
```bash
./tests/run_tests.sh full
```

## 📊 Test-Ergebnisse

### Erfolgreicher Test
```
🎩 GENTLEMAN M1 CLIENT TEST
════════════════════════════════════════
🖥️ Teste von M1 Mac gegen RX-Node: localhost
🕐 Startzeit: 2025-06-15 19:22:36

🔗 Teste Systemverbindung...
✅ System erreichbar: healthy

📊 Überprüfe Service-Status...
✅ Status-Seite erreichbar
🔧 Service-Status:
  ✅ llm-server: healthy
  ✅ stt-service: healthy
  ✅ tts-service: healthy
  ✅ mesh-coordinator: healthy
📈 Gesamt: 4/4 Services gesund

💬 Teste Chat-Funktionalität...
📤 Sende Nachricht: 'Hallo! Ich bin ein M1 Mac...'
✅ Chat erfolgreich (1.25s)
🤖 AI Antwort: 'Hallo! Ich bin Ihr Gentleman AI...'
📊 Verarbeitung: 1.21s, 35 Tokens

════════════════════════════════════════
📊 TEST-ERGEBNIS:
✅ Erfolgreich: 3/3 (100.0%)
🎉 SYSTEM FUNKTIONIERT!
Das Gentleman AI System ist vom M1 aus voll funktionsfähig.
```

## 🔧 Voraussetzungen

### Python-Abhängigkeiten
```bash
pip3 install requests
```

### System-Voraussetzungen
- Python 3.7+
- Docker & Docker Compose (für lokale Tests)
- Netzwerkzugriff zur RX-Node (für verteilte Tests)

## 🌐 Netzwerk-Konfiguration

### Docker-Netzwerk (lokal)
```yaml
networks:
  gentleman-mesh:
    driver: bridge
    ipam:
      config:
        - subnet: 172.20.0.0/16
```

### Service-Ports
- **Web Interface**: 8080
- **LLM Server**: 8001  
- **STT Service**: 8002
- **TTS Service**: 8003
- **Mesh Coordinator**: 8004

### Verteiltes Setup
Für verteilte Tests müssen die Ports auf der RX-Node erreichbar sein:
```bash
# Firewall-Regeln (Beispiel für Ubuntu)
sudo ufw allow 8080
sudo ufw allow 8001
sudo ufw allow 8002
sudo ufw allow 8003
sudo ufw allow 8004
```

## 🐛 Troubleshooting

### Services nicht erreichbar
```bash
# Services-Status prüfen
docker-compose ps

# Services neu starten
docker-compose restart

# Logs überprüfen
docker-compose logs [service-name]
```

### Netzwerk-Probleme
```bash
# Verbindung testen
curl http://RX_NODE_IP:8080/health

# Port-Erreichbarkeit prüfen
telnet RX_NODE_IP 8080
```

### Performance-Probleme
```bash
# Ressourcen-Verbrauch prüfen
docker stats

# GPU-Status (RX-Node)
rocm-smi
```

## 📈 Erweiterte Tests

### Custom Test-Prompts
```python
# In m1_client_test.py anpassen
test_message = "Ihr eigener Test-Prompt hier"
```

### Performance-Benchmarks
```python
# Mehrere Anfragen für Performance-Test
for i in range(10):
    # Test-Code hier
```

### Monitoring-Integration
```python
# Prometheus-Metriken abrufen
response = requests.get("http://RX_NODE_IP:9090/metrics")
```

## 🎉 Erfolgreiche Implementierung

Das Gentleman AI System wurde erfolgreich getestet und funktioniert:

✅ **Alle Services online und gesund**  
✅ **End-to-End Chat funktioniert**  
✅ **M1 ↔ RX Node Kommunikation**  
✅ **ROCm-optimierte LLM-Verarbeitung**  
✅ **Microservices-Architektur stabil**  

Das System ist bereit für den Produktionseinsatz! 🎩 