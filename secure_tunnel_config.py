#!/usr/bin/env python3
"""
GENTLEMAN Secure Tunnel Configuration
Authentifizierte SSH-Tunnel mit Token-basierter Sicherheit
"""

import os
import secrets
import hashlib
import json
from datetime import datetime, timedelta

class SecureTunnelAuth:
    def __init__(self):
        self.token_file = "/tmp/gentleman_tunnel_tokens.json"
        self.valid_tokens = {}
        self.load_tokens()
    
    def generate_token(self, duration_hours=24):
        """Generiert einen sicheren Token mit Ablaufzeit"""
        token = secrets.token_urlsafe(32)
        expires = datetime.now() + timedelta(hours=duration_hours)
        
        self.valid_tokens[token] = {
            "expires": expires.isoformat(),
            "created": datetime.now().isoformat()
        }
        
        self.save_tokens()
        return token
    
    def validate_token(self, token):
        """Validiert einen Token"""
        if token not in self.valid_tokens:
            return False
        
        expires = datetime.fromisoformat(self.valid_tokens[token]["expires"])
        if datetime.now() > expires:
            del self.valid_tokens[token]
            self.save_tokens()
            return False
        
        return True
    
    def load_tokens(self):
        """Lädt Tokens aus Datei"""
        try:
            if os.path.exists(self.token_file):
                with open(self.token_file, 'r') as f:
                    self.valid_tokens = json.load(f)
        except:
            self.valid_tokens = {}
    
    def save_tokens(self):
        """Speichert Tokens in Datei"""
        try:
            with open(self.token_file, 'w') as f:
                json.dump(self.valid_tokens, f, indent=2)
            os.chmod(self.token_file, 0o600)
        except:
            pass

# Token generieren für aktuellen Benutzer
if __name__ == "__main__":
    auth = SecureTunnelAuth()
    token = auth.generate_token(24)
    print(f"Neuer Tunnel-Token (24h gültig): {token}")
