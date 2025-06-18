# 🎯 RX Node Wake-Up Procedures

## Automatische Wake-Up Methoden

### 1. Direkter Wake-Up (wenn RX Node online)
```bash
# Test ob RX Node erreichbar
ping -c 1 192.168.68.117

# Direkte SSH Verbindung
ssh amo9n11@192.168.68.117 "cd ~/Gentleman && ./start_gentleman.sh"
```

### 2. i7 → RX Wake-Up (via SSH Chain)
```bash
# Vom M1 Mac über i7 zur RX Node
ssh i7-node "ssh amo9n11@192.168.68.117 'echo Wake-Up Signal'"
```

### 3. RX Node Simulator (für Tests)
```bash
# Starte Simulator auf M1 Mac
python3 rx_simulator.py &

# Teste Simulator
curl http://localhost:8017/status
```

## Wake-on-LAN (wenn unterstützt)
```bash
# RX Node MAC Adresse ermitteln
arp -a | grep 192.168.68.117

# Wake-on-LAN Signal senden
wakeonlan [MAC_ADDRESS]
```

## Manuelle Aktivierung
1. **Physischer Zugang:** RX Node direkt einschalten
2. **Remote Management:** iDRAC/IPMI falls verfügbar
3. **Router Interface:** Wake-on-LAN über Router

## Troubleshooting

### RX Node nicht erreichbar
- Prüfe Netzwerk Status: `nmap -sn 192.168.68.0/24`
- Prüfe Router/Switch Konfiguration
- Prüfe RX Node Energieeinstellungen

### SSH Verbindung fehlgeschlagen
- Prüfe SSH Keys: `ssh-add -l`
- Teste SSH Config: `ssh -vvv amo9n11@192.168.68.117`
- Alternative über i7: `ssh i7-node "ssh amo9n11@192.168.68.117"`

### GENTLEMAN Service startet nicht
- Prüfe Dependencies: `python3 -m pip list | grep requests`
- Teste Konfiguration: `cd ~/Gentleman && ./test_gentleman.sh`
- Prüfe Port Verfügbarkeit: `ss -tlnp | grep :8008`

## Monitoring & Logging
```bash
# Status aller Nodes
curl http://192.168.68.111:8008/status  # M1 Mac
curl http://192.168.68.117:8008/status  # RX Node
curl http://192.168.68.105:8008/status  # i7 Node

# Cross-Node Tests
ssh i7-node "curl http://192.168.68.117:8008/health"
ssh rx-node "curl http://192.168.68.105:8008/health"
```
