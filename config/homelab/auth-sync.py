#!/usr/bin/env python3
"""
🎩 GENTLEMAN Auth Sync Service
Synchronizes users and authentication across homelab services
"""

import os
import time
import yaml
import requests
import json
from keycloak import KeycloakAdmin
from ldap3 import Server, Connection, ALL
from flask import Flask, jsonify

app = Flask(__name__)

class GentlemanAuthSync:
    def __init__(self):
        self.keycloak_url = os.getenv('KEYCLOAK_URL', 'http://keycloak:8080')
        self.keycloak_admin_user = os.getenv('KEYCLOAK_ADMIN_USER', 'admin')
        self.keycloak_admin_password = os.getenv('KEYCLOAK_ADMIN_PASSWORD')
        
        self.ldap_url = os.getenv('LDAP_URL', 'ldap://openldap:389')
        self.ldap_admin_dn = os.getenv('LDAP_ADMIN_DN')
        self.ldap_admin_password = os.getenv('LDAP_ADMIN_PASSWORD')
        
        self.realm_name = 'gentleman-homelab'
        
        # Initialize Keycloak Admin
        try:
            self.keycloak_admin = KeycloakAdmin(
                server_url=self.keycloak_url,
                username=self.keycloak_admin_user,
                password=self.keycloak_admin_password,
                realm_name='master',
                verify=False
            )
            print("✅ Keycloak connection established")
        except Exception as e:
            print(f"❌ Keycloak connection failed: {e}")
            self.keycloak_admin = None

    def setup_realm(self):
        """Create and configure the GENTLEMAN realm"""
        try:
            # Check if realm exists
            realms = self.keycloak_admin.get_realms()
            realm_exists = any(realm['realm'] == self.realm_name for realm in realms)
            
            if not realm_exists:
                print(f"Creating realm: {self.realm_name}")
                realm_config = {
                    "realm": self.realm_name,
                    "displayName": "GENTLEMAN Homelab",
                    "enabled": True,
                    "registrationAllowed": False,
                    "loginWithEmailAllowed": True,
                    "duplicateEmailsAllowed": False,
                    "resetPasswordAllowed": True,
                    "editUsernameAllowed": False,
                    "bruteForceProtected": True,
                    "permanentLockout": False,
                    "maxFailureWaitSeconds": 900,
                    "minimumQuickLoginWaitSeconds": 60,
                    "waitIncrementSeconds": 60,
                    "quickLoginCheckMilliSeconds": 1000,
                    "maxDeltaTimeSeconds": 43200,
                    "failureFactor": 30
                }
                self.keycloak_admin.create_realm(realm_config)
                print("✅ Realm created successfully")
            else:
                print("✅ Realm already exists")
                
            # Switch to the new realm
            self.keycloak_admin.realm_name = self.realm_name
            
        except Exception as e:
            print(f"❌ Failed to setup realm: {e}")

    def create_service_clients(self):
        """Create OAuth clients for homelab services"""
        clients = [
            {
                "clientId": "gitea-client",
                "name": "Gitea Git Server",
                "description": "Git repository server",
                "enabled": True,
                "clientAuthenticatorType": "client-secret",
                "redirectUris": ["http://git.gentleman.local:3000/user/oauth2/keycloak/callback"],
                "webOrigins": ["http://git.gentleman.local:3000"],
                "protocol": "openid-connect",
                "publicClient": False,
                "standardFlowEnabled": True,
                "implicitFlowEnabled": False,
                "directAccessGrantsEnabled": True
            },
            {
                "clientId": "nextcloud-client",
                "name": "Nextcloud",
                "description": "Personal cloud storage",
                "enabled": True,
                "clientAuthenticatorType": "client-secret",
                "redirectUris": ["http://cloud.gentleman.local:8080/apps/user_oidc/code"],
                "webOrigins": ["http://cloud.gentleman.local:8080"],
                "protocol": "openid-connect",
                "publicClient": False,
                "standardFlowEnabled": True,
                "implicitFlowEnabled": False,
                "directAccessGrantsEnabled": True
            },
            {
                "clientId": "grafana-client",
                "name": "Grafana",
                "description": "Monitoring dashboard",
                "enabled": True,
                "clientAuthenticatorType": "client-secret",
                "redirectUris": ["http://localhost:3001/login/generic_oauth"],
                "webOrigins": ["http://localhost:3001"],
                "protocol": "openid-connect",
                "publicClient": False,
                "standardFlowEnabled": True,
                "implicitFlowEnabled": False,
                "directAccessGrantsEnabled": True
            }
        ]
        
        try:
            existing_clients = self.keycloak_admin.get_clients()
            existing_client_ids = [client['clientId'] for client in existing_clients]
            
            for client_config in clients:
                if client_config['clientId'] not in existing_client_ids:
                    client_id = self.keycloak_admin.create_client(client_config)
                    print(f"✅ Created client: {client_config['clientId']}")
                    
                    # Get client secret
                    client_secret = self.keycloak_admin.get_client_secrets(client_id)
                    print(f"🔑 Client secret for {client_config['clientId']}: {client_secret['value']}")
                else:
                    print(f"✅ Client already exists: {client_config['clientId']}")
                    
        except Exception as e:
            print(f"❌ Failed to create clients: {e}")

    def create_default_groups(self):
        """Create default user groups"""
        groups = [
            {
                "name": "homelab-admins",
                "path": "/homelab-admins",
                "attributes": {
                    "description": ["Full access to all homelab services"]
                }
            },
            {
                "name": "homelab-users", 
                "path": "/homelab-users",
                "attributes": {
                    "description": ["Standard access to homelab services"]
                }
            },
            {
                "name": "media-users",
                "path": "/media-users", 
                "attributes": {
                    "description": ["Access to media services only"]
                }
            }
        ]
        
        try:
            existing_groups = self.keycloak_admin.get_groups()
            existing_group_names = [group['name'] for group in existing_groups]
            
            for group_config in groups:
                if group_config['name'] not in existing_group_names:
                    self.keycloak_admin.create_group(group_config)
                    print(f"✅ Created group: {group_config['name']}")
                else:
                    print(f"✅ Group already exists: {group_config['name']}")
                    
        except Exception as e:
            print(f"❌ Failed to create groups: {e}")

    def sync_users_to_services(self):
        """Sync Keycloak users to individual services"""
        try:
            users = self.keycloak_admin.get_users()
            print(f"📊 Found {len(users)} users to sync")
            
            for user in users:
                print(f"🔄 Syncing user: {user['username']}")
                # Here you would implement service-specific user sync
                # For example, create users in Gitea, Nextcloud, etc.
                
        except Exception as e:
            print(f"❌ Failed to sync users: {e}")

    def health_check(self):
        """Check health of authentication services"""
        status = {
            'keycloak': False,
            'ldap': False,
            'services_synced': 0
        }
        
        # Check Keycloak
        try:
            self.keycloak_admin.get_realms()
            status['keycloak'] = True
        except:
            pass
            
        # Check LDAP
        try:
            server = Server(self.ldap_url, get_info=ALL)
            conn = Connection(server, self.ldap_admin_dn, self.ldap_admin_password)
            if conn.bind():
                status['ldap'] = True
                conn.unbind()
        except:
            pass
            
        return status

# Flask API endpoints
auth_sync = GentlemanAuthSync()

@app.route('/')
def status():
    return jsonify({
        'service': 'GENTLEMAN Auth Sync',
        'status': 'running',
        'realm': auth_sync.realm_name
    })

@app.route('/health')
def health():
    return jsonify(auth_sync.health_check())

@app.route('/sync')
def sync():
    """Trigger manual sync"""
    try:
        auth_sync.sync_users_to_services()
        return jsonify({'status': 'sync completed'})
    except Exception as e:
        return jsonify({'status': 'sync failed', 'error': str(e)}), 500

@app.route('/setup')
def setup():
    """Setup realm and clients"""
    try:
        auth_sync.setup_realm()
        auth_sync.create_service_clients()
        auth_sync.create_default_groups()
        return jsonify({'status': 'setup completed'})
    except Exception as e:
        return jsonify({'status': 'setup failed', 'error': str(e)}), 500

def main():
    print("🎩 GENTLEMAN Auth Sync Service Starting...")
    
    # Wait for Keycloak to be ready
    max_retries = 30
    for i in range(max_retries):
        try:
            if auth_sync.keycloak_admin:
                auth_sync.keycloak_admin.get_realms()
                print("✅ Keycloak is ready")
                break
        except:
            print(f"⏳ Waiting for Keycloak... ({i+1}/{max_retries})")
            time.sleep(10)
    
    # Initial setup
    if auth_sync.keycloak_admin:
        auth_sync.setup_realm()
        auth_sync.create_service_clients()
        auth_sync.create_default_groups()
    
    # Start Flask API
    app.run(host='0.0.0.0', port=5000, debug=True)

if __name__ == '__main__':
    main() 