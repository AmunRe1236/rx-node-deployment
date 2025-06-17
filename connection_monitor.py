#!/usr/bin/env python3
import time
import subprocess
import json
from datetime import datetime

def get_nebula_status():
    try:
        # Nebula Interface Status
        result = subprocess.run(['ip', 'addr', 'show', 'nebula-rx'], 
                              capture_output=True, text=True)
        interface_up = 'UP' in result.stdout if result.returncode == 0 else False
        
        # Nebula Process Status
        result = subprocess.run(['pgrep', '-f', 'nebula'], 
                              capture_output=True, text=True)
        process_count = len(result.stdout.strip().split('\n')) if result.stdout.strip() else 0
        
        # Test Ping to M1
        result = subprocess.run(['ping', '-c', '1', '-W', '2', '192.168.100.1'], 
                              capture_output=True, text=True)
        ping_success = result.returncode == 0
        
        # Get recent Nebula logs
        result = subprocess.run(['journalctl', '-u', 'nebula-rx', '--no-pager', '-n', '1', '--since', '30 seconds ago'], 
                              capture_output=True, text=True)
        recent_log = result.stdout.strip().split('\n')[-1] if result.stdout.strip() else "No recent logs"
        
        return {
            'interface_up': interface_up,
            'process_count': process_count,
            'ping_success': ping_success,
            'recent_log': recent_log,
            'timestamp': datetime.now().strftime('%H:%M:%S')
        }
    except Exception as e:
        return {'error': str(e), 'timestamp': datetime.now().strftime('%H:%M:%S')}

def main():
    print('🎩 GENTLEMAN NEBULA CONNECTION MONITOR')
    print('=====================================')
    print('Überwacht die Verbindung zwischen RX Node und M1 Mac')
    print('Drücke Ctrl+C zum Beenden\n')

    connection_established = False
    
    try:
        while True:
            status = get_nebula_status()
            
            print(f'⏰ {status["timestamp"]} | ', end='')
            
            if 'error' in status:
                print(f'❌ ERROR: {status["error"]}')
            else:
                # Interface Status
                if status['interface_up']:
                    print('🟢 Interface UP | ', end='')
                else:
                    print('🔴 Interface DOWN | ', end='')
                
                # Process Status
                print(f'⚙️  Prozesse: {status["process_count"]} | ', end='')
                
                # Ping Status
                if status['ping_success']:
                    if not connection_established:
                        print('🎯 M1 VERBINDUNG HERGESTELLT! ✅🎉')
                        connection_established = True
                    else:
                        print('🎯 M1 VERBUNDEN ✅')
                else:
                    print('📡 M1 Handshake läuft...')
                    connection_established = False
                
                # Show recent log if interesting
                if 'Handshake' in status['recent_log'] or 'error' in status['recent_log'].lower():
                    print(f'    📋 Log: {status["recent_log"][-80:]}')
            
            time.sleep(3)
            
    except KeyboardInterrupt:
        print('\n\n🎩 Monitor beendet. Nebula läuft weiter im Hintergrund.')
        print('Status: Verbindung wird weiterhin versucht...')

if __name__ == "__main__":
    main() 