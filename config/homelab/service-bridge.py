#!/usr/bin/env python3
"""
🎩 GENTLEMAN Service Bridge
Cross-Node Service Discovery & Communication Bridge
Handles service registration and discovery across Nebula mesh network
"""

import os
import time
import json
import requests
import consul
from flask import Flask, jsonify, request
import threading
import socket
import subprocess

app = Flask(__name__)

class GentlemanServiceBridge:
    def __init__(self):
        self.consul_host = os.getenv('CONSUL_HOST', 'localhost')
        self.consul_port = int(os.getenv('CONSUL_PORT', '8500'))
        self.node_type = os.getenv('NODE_TYPE', 'unknown')
        self.node_ip = os.getenv('NODE_IP', '127.0.0.1')
        self.nebula_config_path = os.getenv('NEBULA_CONFIG_PATH', '/app/nebula')
        
        # Initialize Consul client
        try:
            self.consul = consul.Consul(host=self.consul_host, port=self.consul_port)
            print(f"✅ Connected to Consul at {self.consul_host}:{self.consul_port}")
        except Exception as e:
            print(f"❌ Failed to connect to Consul: {e}")
            self.consul = None
        
        # Service definitions for each node type
        self.service_definitions = {
            'rx-node': {
                'lm-studio': {
                    'port': 1234,
                    'health_endpoint': '/v1/models',
                    'capabilities': ['llm', 'text-generation', 'gpu-acceleration'],
                    'tags': ['ai', 'gpu', 'llm']
                },
                'ollama': {
                    'port': 11434,
                    'health_endpoint': '/api/tags',
                    'capabilities': ['llm', 'local-models'],
                    'tags': ['ai', 'local', 'ollama']
                }
            },
            'm1-node': {
                'keycloak': {
                    'port': 8085,
                    'health_endpoint': '/admin/',
                    'capabilities': ['authentication', 'sso', 'oauth'],
                    'tags': ['auth', 'sso', 'identity']
                },
                'auth-sync': {
                    'port': 8091,
                    'health_endpoint': '/health',
                    'capabilities': ['user-sync', 'ldap', 'auth-bridge'],
                    'tags': ['auth', 'sync', 'ldap']
                },
                'smtp-relay': {
                    'port': 1025,
                    'health_endpoint': None,  # SMTP doesn't have HTTP health check
                    'capabilities': ['email', 'smtp', 'relay'],
                    'tags': ['email', 'smtp', 'communication']
                },
                'homelab-services': {
                    'port': 8080,
                    'health_endpoint': '/health',
                    'capabilities': ['homelab', 'management', 'dashboard'],
                    'tags': ['homelab', 'management', 'web']
                }
            },
            'i7-node': {
                'web-client': {
                    'port': 8080,
                    'health_endpoint': '/health',
                    'capabilities': ['web-interface', 'client', 'mobile'],
                    'tags': ['web', 'client', 'interface']
                }
            }
        }

    def register_node_services(self):
        """Register all services for this node type"""
        if not self.consul:
            print("❌ Consul not available, skipping service registration")
            return
            
        services = self.service_definitions.get(self.node_type, {})
        
        for service_name, config in services.items():
            try:
                # Check if service is actually running
                if self.is_service_healthy(service_name, config):
                    service_id = f"{service_name}-{self.node_type}"
                    
                    # Register service with Consul
                    self.consul.agent.service.register(
                        name=service_name,
                        service_id=service_id,
                        address=self.node_ip,
                        port=config['port'],
                        tags=config['tags'] + [self.node_type],
                        meta={
                            'node_type': self.node_type,
                            'capabilities': json.dumps(config['capabilities']),
                            'nebula_ip': self.node_ip
                        },
                        check=consul.Check.http(
                            f"http://{self.node_ip}:{config['port']}{config['health_endpoint']}",
                            interval="30s",
                            timeout="10s"
                        ) if config['health_endpoint'] else consul.Check.tcp(
                            f"{self.node_ip}:{config['port']}",
                            interval="30s",
                            timeout="10s"
                        )
                    )
                    
                    print(f"✅ Registered service: {service_name} on {self.node_ip}:{config['port']}")
                else:
                    print(f"⚠️  Service {service_name} not healthy, skipping registration")
                    
            except Exception as e:
                print(f"❌ Failed to register service {service_name}: {e}")

    def is_service_healthy(self, service_name, config):
        """Check if a service is running and healthy"""
        try:
            if config['health_endpoint']:
                # HTTP health check
                response = requests.get(
                    f"http://{self.node_ip}:{config['port']}{config['health_endpoint']}",
                    timeout=5
                )
                return response.status_code < 400
            else:
                # TCP port check
                sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
                sock.settimeout(5)
                result = sock.connect_ex((self.node_ip, config['port']))
                sock.close()
                return result == 0
        except:
            return False

    def discover_services(self, service_name=None, capability=None):
        """Discover services across all nodes"""
        if not self.consul:
            return []
            
        try:
            if service_name:
                # Get specific service
                services = self.consul.health.service(service_name, passing=True)[1]
            else:
                # Get all services
                services = []
                all_services = self.consul.agent.services()
                for svc_id, svc_info in all_services.items():
                    health = self.consul.health.service(svc_info['Service'], passing=True)[1]
                    services.extend(health)
            
            # Filter by capability if specified
            if capability:
                filtered_services = []
                for service in services:
                    svc_capabilities = json.loads(service['Service'].get('Meta', {}).get('capabilities', '[]'))
                    if capability in svc_capabilities:
                        filtered_services.append(service)
                services = filtered_services
            
            return services
            
        except Exception as e:
            print(f"❌ Service discovery failed: {e}")
            return []

    def get_service_endpoint(self, service_name, capability=None):
        """Get the best endpoint for a service"""
        services = self.discover_services(service_name, capability)
        
        if not services:
            return None
            
        # Simple load balancing - return first healthy service
        service = services[0]['Service']
        return {
            'host': service['Address'],
            'port': service['Port'],
            'url': f"http://{service['Address']}:{service['Port']}",
            'node_type': service.get('Meta', {}).get('node_type'),
            'capabilities': json.loads(service.get('Meta', {}).get('capabilities', '[]'))
        }

    def proxy_request(self, service_name, path, method='GET', **kwargs):
        """Proxy a request to a service on another node"""
        endpoint = self.get_service_endpoint(service_name)
        
        if not endpoint:
            return {'error': f'Service {service_name} not found'}, 404
            
        try:
            url = f"{endpoint['url']}{path}"
            response = requests.request(method, url, **kwargs)
            
            return {
                'status_code': response.status_code,
                'data': response.json() if response.headers.get('content-type', '').startswith('application/json') else response.text,
                'headers': dict(response.headers),
                'service_endpoint': endpoint
            }
            
        except Exception as e:
            return {'error': str(e)}, 500

# Flask API endpoints
bridge = GentlemanServiceBridge()

@app.route('/')
def status():
    return jsonify({
        'service': 'GENTLEMAN Service Bridge',
        'node_type': bridge.node_type,
        'node_ip': bridge.node_ip,
        'consul_connected': bridge.consul is not None
    })

@app.route('/services')
def list_services():
    """List all discovered services"""
    services = bridge.discover_services()
    return jsonify({
        'services': [
            {
                'name': svc['Service']['Service'],
                'address': svc['Service']['Address'],
                'port': svc['Service']['Port'],
                'node_type': svc['Service'].get('Meta', {}).get('node_type'),
                'capabilities': json.loads(svc['Service'].get('Meta', {}).get('capabilities', '[]')),
                'health': svc['Checks'][0]['Status'] if svc['Checks'] else 'unknown'
            }
            for svc in services
        ]
    })

@app.route('/services/<service_name>')
def get_service(service_name):
    """Get specific service endpoint"""
    endpoint = bridge.get_service_endpoint(service_name)
    if endpoint:
        return jsonify(endpoint)
    else:
        return jsonify({'error': 'Service not found'}), 404

@app.route('/proxy/<service_name>/<path:path>', methods=['GET', 'POST', 'PUT', 'DELETE'])
def proxy_to_service(service_name, path):
    """Proxy requests to services on other nodes"""
    result, status_code = bridge.proxy_request(
        service_name, 
        f"/{path}",
        method=request.method,
        json=request.get_json() if request.is_json else None,
        params=request.args,
        headers={k: v for k, v in request.headers if k.lower() not in ['host', 'content-length']}
    )
    return jsonify(result), status_code

@app.route('/register')
def register_services():
    """Manually trigger service registration"""
    bridge.register_node_services()
    return jsonify({'status': 'Services registered'})

def background_registration():
    """Background thread for periodic service registration"""
    while True:
        try:
            bridge.register_node_services()
            time.sleep(60)  # Re-register every minute
        except Exception as e:
            print(f"❌ Background registration failed: {e}")
            time.sleep(30)

def main():
    print(f"🎩 GENTLEMAN Service Bridge Starting on {bridge.node_type}...")
    
    # Initial service registration
    bridge.register_node_services()
    
    # Start background registration thread
    registration_thread = threading.Thread(target=background_registration, daemon=True)
    registration_thread.start()
    
    # Start Flask API
    app.run(host='0.0.0.0', port=5000, debug=True)

if __name__ == '__main__':
    main() 