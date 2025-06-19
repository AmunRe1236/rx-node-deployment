#!/usr/bin/env python3
"""
GENTLEMAN Cluster - Lokales Gitea Setup (localhost)
Vereinfachtes Setup für lokale Gitea-Instanz
"""

import requests
import json
import time
import logging
import sys

# Logging Setup
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s'
)

def test_gitea_local():
    """Teste lokale Gitea-Instanz"""
    print("🧪 Teste lokale Gitea-Instanz...")
    
    try:
        # Health Check
        response = requests.get("http://localhost:3010/api/healthz", timeout=5)
        if response.status_code == 200:
            print("✅ Gitea Health Check erfolgreich")
        else:
            print(f"⚠️ Gitea Health Check: Status {response.status_code}")
            
        # API Version Check
        response = requests.get("http://localhost:3010/api/v1/version", timeout=5)
        if response.status_code == 200:
            version_data = response.json()
            print(f"✅ Gitea Version: {version_data.get('version', 'Unknown')}")
        else:
            print(f"⚠️ Gitea Version Check: Status {response.status_code}")
            
        # Web Interface Check
        response = requests.get("http://localhost:3010/", timeout=5)
        if response.status_code == 200:
            print("✅ Gitea Web Interface erreichbar")
            
            # Prüfe ob Setup erforderlich
            if "Install" in response.text or "installation" in response.text:
                print("🔧 Gitea benötigt Initial-Setup")
                return "setup_required"
            else:
                print("✅ Gitea ist bereits konfiguriert")
                return "ready"
        else:
            print(f"⚠️ Gitea Web Interface: Status {response.status_code}")
            return "error"
            
    except requests.exceptions.RequestException as e:
        print(f"❌ Verbindung zu Gitea fehlgeschlagen: {e}")
        return "error"

def setup_git_remotes():
    """Konfiguriere Git Remotes für lokales Gitea"""
    print("🔗 Konfiguriere Git Remotes...")
    
    import subprocess
    
    try:
        # Entferne alte gitea remote
        subprocess.run(["git", "remote", "remove", "gitea"], 
                      capture_output=True, check=False)
        
        # Füge neue gitea remote hinzu (localhost)
        result = subprocess.run([
            "git", "remote", "add", "gitea", 
            "http://localhost:3010/gentleman/gentleman.git"
        ], capture_output=True, text=True)
        
        if result.returncode == 0:
            print("✅ Gitea Remote konfiguriert (localhost)")
        else:
            print(f"⚠️ Gitea Remote Konfiguration: {result.stderr}")
            
        # Zeige alle Remotes
        result = subprocess.run(["git", "remote", "-v"], 
                               capture_output=True, text=True)
        print("📋 Konfigurierte Git Remotes:")
        print(result.stdout)
        
    except Exception as e:
        print(f"❌ Git Remote Konfiguration fehlgeschlagen: {e}")

def print_setup_instructions():
    """Zeige manuelle Setup-Anweisungen"""
    print("\n" + "="*60)
    print("🎯 GITEA SETUP ANWEISUNGEN")
    print("="*60)
    print("1. Öffne http://localhost:3010 im Browser")
    print("2. Falls Setup-Seite erscheint:")
    print("   - Database: SQLite3 (Standard)")
    print("   - Admin Username: gentleman") 
    print("   - Admin Password: gentleman123")
    print("   - Admin Email: admin@gentleman.local")
    print("")
    print("3. Nach Setup:")
    print("   - Erstelle Organisation: 'gentleman'")
    print("   - Erstelle Repository: 'gentleman'")
    print("")
    print("4. Dann ausführen:")
    print("   git push gitea master")
    print("="*60)

def test_git_push():
    """Teste Git Push zu Gitea"""
    print("📤 Teste Git Push zu Gitea...")
    
    import subprocess
    
    try:
        # Teste git ls-remote
        result = subprocess.run([
            "git", "ls-remote", "gitea"
        ], capture_output=True, text=True, timeout=10)
        
        if result.returncode == 0:
            print("✅ Gitea Repository erreichbar")
            
            # Versuche Push
            result = subprocess.run([
                "git", "push", "gitea", "master"
            ], capture_output=True, text=True, timeout=30)
            
            if result.returncode == 0:
                print("✅ Git Push erfolgreich!")
                return True
            else:
                print(f"⚠️ Git Push fehlgeschlagen: {result.stderr}")
                return False
        else:
            print(f"⚠️ Gitea Repository nicht erreichbar: {result.stderr}")
            return False
            
    except Exception as e:
        print(f"❌ Git Push Test fehlgeschlagen: {e}")
        return False

def main():
    """Main Function"""
    print("🏗️ GENTLEMAN Lokales Gitea Setup")
    print("=================================")
    
    # Teste Gitea Status
    status = test_gitea_local()
    
    if status == "error":
        print("❌ Gitea ist nicht erreichbar. Starte zuerst den Container:")
        print("   ./gentleman_gitea_setup.sh start")
        sys.exit(1)
    elif status == "setup_required":
        print("🔧 Gitea benötigt manuelles Setup")
        print_setup_instructions()
    elif status == "ready":
        print("✅ Gitea ist bereit!")
        
        # Konfiguriere Git Remotes
        setup_git_remotes()
        
        # Test Git Push (falls Repository existiert)
        if "--test-push" in sys.argv:
            test_git_push()
    
    print("\n🎉 Setup abgeschlossen!")
    print("🌐 Gitea Web Interface: http://localhost:3010")

if __name__ == "__main__":
    main() 