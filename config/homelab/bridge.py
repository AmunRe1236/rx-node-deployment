#!/usr/bin/env python3
"""
🎩 GENTLEMAN Homelab Bridge
Service integration and status monitoring
"""

from flask import Flask, jsonify
import requests
import json
import os

app = Flask(__name__)

@app.route('/')
def status():
    """Main status endpoint showing all services"""
    return jsonify({
        'status': 'running',
        'project': 'GENTLEMAN Homelab',
        'services': {
            'gitea': 'http://gitea:3000',
            'nextcloud': 'http://nextcloud:80',
            'homeassistant': 'http://homeassistant:8123',
            'vaultwarden': 'http://vaultwarden:80',
            'jellyfin': 'http://jellyfin:8096',
            'pihole': 'http://pihole:80',
            'grafana': 'http://grafana:3000',
            'prometheus': 'http://prometheus:9090'
        }
    })

@app.route('/health')
def health():
    """Health check endpoint"""
    return jsonify({'status': 'healthy'})

@app.route('/services')
def services():
    """Detailed service information"""
    service_status = {}
    
    services = {
        'gitea': 'http://gitea:3000',
        'nextcloud': 'http://nextcloud:80',
        'homeassistant': 'http://homeassistant:8123',
        'vaultwarden': 'http://vaultwarden:80',
        'jellyfin': 'http://jellyfin:8096'
    }
    
    for name, url in services.items():
        try:
            response = requests.get(url, timeout=5)
            service_status[name] = {
                'url': url,
                'status': 'online' if response.status_code == 200 else 'error',
                'response_code': response.status_code
            }
        except Exception as e:
            service_status[name] = {
                'url': url,
                'status': 'offline',
                'error': str(e)
            }
    
    return jsonify(service_status)

@app.route('/config')
def config():
    """Configuration information"""
    return jsonify({
        'homeassistant_token': bool(os.getenv('HOMEASSISTANT_TOKEN')),
        'gitea_api_token': bool(os.getenv('GITEA_API_TOKEN')),
        'environment': 'homelab'
    })

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=8090, debug=True) 