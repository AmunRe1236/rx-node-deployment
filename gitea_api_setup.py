#!/usr/bin/env python3
"""
GENTLEMAN Cluster - Gitea API Setup Automation
Automatisiert die Erstellung von Benutzer, Organisation und Repository in Gitea
"""

import requests
import json
import time
import logging
import sys
from urllib.parse import urljoin

# Logging Setup
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s'
)

class GiteaAPISetup:
    def __init__(self, base_url="http://192.168.100.1:3010"):
        self.base_url = base_url
        self.api_url = urljoin(base_url, "/api/v1/")
        self.session = requests.Session()
        self.session.headers.update({
            'Content-Type': 'application/json',
            'Accept': 'application/json'
        })
        
        # Konfiguration
        self.admin_user = "gentleman"
        self.admin_email = "admin@gentleman.local" 
        self.admin_password = "gentleman123"
        self.org_name = "gentleman"
        self.repo_name = "gentleman"
        self.api_token = None
        
    def wait_for_gitea(self, timeout=120):
        """Warte bis Gitea verfügbar ist"""
        logging.info("🕒 Warte auf Gitea Server...")
        
        start_time = time.time()
        while time.time() - start_time < timeout:
            try:
                response = self.session.get(urljoin(self.base_url, "/api/healthz"))
                if response.status_code == 200:
                    logging.info("✅ Gitea Server ist verfügbar")
                    return True
            except requests.exceptions.RequestException:
                pass
            
            time.sleep(5)
            logging.info("⏳ Warte weiter auf Gitea...")
        
        logging.error("❌ Gitea Server Timeout")
        return False
    
    def check_installation_status(self):
        """Prüfe ob Gitea bereits installiert ist"""
        try:
            response = self.session.get(urljoin(self.base_url, "/"))
            
            # Wenn Setup-Seite erscheint, ist Gitea nicht installiert
            if "Install" in response.text or "installation" in response.text.lower():
                logging.info("ℹ️ Gitea benötigt Initial-Setup")
                return False
            else:
                logging.info("✅ Gitea ist bereits installiert")
                return True
                
        except requests.exceptions.RequestException as e:
            logging.error(f"❌ Fehler beim Prüfen des Installation-Status: {e}")
            return False
    
    def create_admin_user(self):
        """Erstelle Admin User (falls noch nicht vorhanden)"""
        logging.info("👤 Prüfe/Erstelle Admin User...")
        
        # Versuche Login zu testen
        try:
            login_data = {
                "user_name": self.admin_user,
                "password": self.admin_password
            }
            
            response = self.session.post(
                urljoin(self.base_url, "/user/login"),
                data=login_data,
                allow_redirects=False
            )
            
            if response.status_code in [200, 302]:
                logging.info("✅ Admin User existiert bereits")
                return True
            else:
                logging.info("ℹ️ Admin User muss erstellt werden")
                return self._setup_initial_admin()
                
        except Exception as e:
            logging.warning(f"⚠️ Login-Test fehlgeschlagen: {e}")
            return self._setup_initial_admin()
    
    def _setup_initial_admin(self):
        """Setup initial admin via install endpoint"""
        logging.info("🔧 Führe Initial-Setup durch...")
        
        install_data = {
            "db_type": "sqlite3",
            "db_host": "localhost:3306",
            "db_user": "",
            "db_passwd": "",
            "db_name": "gitea",
            "ssl_mode": "disable",
            "db_schema": "",
            "charset": "utf8",
            "db_path": "/data/gitea/gitea.db",
            "app_name": "GENTLEMAN Git",
            "repo_root_path": "/data/git/repositories",
            "lfs_root_path": "/data/git/lfs",
            "run_user": "git",
            "domain": "192.168.100.1",
            "ssh_port": "2223",
            "http_port": "3000",
            "app_url": self.base_url + "/",
            "log_root_path": "/data/gitea/log",
            "smtp_host": "",
            "smtp_from": "",
            "smtp_user": "",
            "smtp_passwd": "",
            "enable_federated_avatar": "on",
            "enable_open_id_sign_in": "on",
            "enable_open_id_sign_up": "on",
            "default_allow_create_organization": "on",
            "default_enable_timetracking": "on",
            "no_reply_address": "noreply.192.168.100.1",
            "password_algorithm": "pbkdf2",
            "admin_name": self.admin_user,
            "admin_passwd": self.admin_password,
            "admin_confirm_passwd": self.admin_password,
            "admin_email": self.admin_email
        }
        
        try:
            response = self.session.post(
                urljoin(self.base_url, "/"),
                data=install_data
            )
            
            if response.status_code in [200, 302]:
                logging.info("✅ Initial-Setup erfolgreich")
                time.sleep(5)  # Warte auf Setup-Abschluss
                return True
            else:
                logging.error(f"❌ Initial-Setup fehlgeschlagen: {response.status_code}")
                return False
                
        except Exception as e:
            logging.error(f"❌ Initial-Setup Fehler: {e}")
            return False
    
    def authenticate(self):
        """Authentifiziere und hole API Token"""
        logging.info("🔑 Authentifiziere mit Gitea...")
        
        # Versuche bestehende Session zu nutzen
        try:
            response = self.session.get(
                urljoin(self.api_url, "user"),
                auth=(self.admin_user, self.admin_password)
            )
            
            if response.status_code == 200:
                logging.info("✅ Authentifizierung erfolgreich")
                return True
            else:
                logging.error(f"❌ Authentifizierung fehlgeschlagen: {response.status_code}")
                return False
                
        except Exception as e:
            logging.error(f"❌ Authentifizierung Fehler: {e}")
            return False
    
    def create_organization(self):
        """Erstelle Organisation"""
        logging.info(f"🏢 Erstelle Organisation '{self.org_name}'...")
        
        # Prüfe ob Organisation bereits existiert
        try:
            response = self.session.get(
                urljoin(self.api_url, f"orgs/{self.org_name}"),
                auth=(self.admin_user, self.admin_password)
            )
            
            if response.status_code == 200:
                logging.info("✅ Organisation existiert bereits")
                return True
                
        except Exception:
            pass
        
        # Erstelle neue Organisation
        org_data = {
            "username": self.org_name,
            "full_name": "GENTLEMAN Cluster Organization",
            "description": "GENTLEMAN Dynamic Cluster - Git Repository Organization",
            "website": "",
            "location": "",
            "visibility": "public",
            "repo_admin_change_team_access": True
        }
        
        try:
            response = self.session.post(
                urljoin(self.api_url, "orgs"),
                data=json.dumps(org_data),
                auth=(self.admin_user, self.admin_password)
            )
            
            if response.status_code == 201:
                logging.info("✅ Organisation erfolgreich erstellt")
                return True
            else:
                logging.error(f"❌ Organisation-Erstellung fehlgeschlagen: {response.status_code}")
                logging.error(f"Response: {response.text}")
                return False
                
        except Exception as e:
            logging.error(f"❌ Organisation-Erstellung Fehler: {e}")
            return False
    
    def create_repository(self):
        """Erstelle Repository"""
        logging.info(f"📦 Erstelle Repository '{self.repo_name}'...")
        
        # Prüfe ob Repository bereits existiert
        try:
            response = self.session.get(
                urljoin(self.api_url, f"repos/{self.org_name}/{self.repo_name}"),
                auth=(self.admin_user, self.admin_password)
            )
            
            if response.status_code == 200:
                logging.info("✅ Repository existiert bereits")
                return True
                
        except Exception:
            pass
        
        # Erstelle neues Repository
        repo_data = {
            "name": self.repo_name,
            "description": "GENTLEMAN Dynamic Cluster - Main Repository",
            "private": False,
            "auto_init": True,
            "gitignores": "",
            "license": "MIT",
            "readme": "Default",
            "default_branch": "main",
            "trust_model": "default"
        }
        
        try:
            response = self.session.post(
                urljoin(self.api_url, f"orgs/{self.org_name}/repos"),
                data=json.dumps(repo_data),
                auth=(self.admin_user, self.admin_password)
            )
            
            if response.status_code == 201:
                logging.info("✅ Repository erfolgreich erstellt")
                return True
            else:
                logging.error(f"❌ Repository-Erstellung fehlgeschlagen: {response.status_code}")
                logging.error(f"Response: {response.text}")
                return False
                
        except Exception as e:
            logging.error(f"❌ Repository-Erstellung Fehler: {e}")
            return False
    
    def setup_complete(self):
        """Vollständiges Setup ausführen"""
        logging.info("🚀 Starte vollständiges Gitea Setup...")
        
        # 1. Warte auf Gitea
        if not self.wait_for_gitea():
            return False
        
        # 2. Prüfe Installation Status
        if not self.check_installation_status():
            # 3. Erstelle Admin User (Initial Setup)
            if not self.create_admin_user():
                return False
        
        # 4. Authentifiziere
        if not self.authenticate():
            return False
        
        # 5. Erstelle Organisation
        if not self.create_organization():
            return False
        
        # 6. Erstelle Repository
        if not self.create_repository():
            return False
        
        logging.info("🎉 Gitea Setup vollständig abgeschlossen!")
        self.print_summary()
        return True
    
    def print_summary(self):
        """Zeige Setup-Zusammenfassung"""
        print("\n" + "="*50)
        print("🎯 GITEA SETUP ZUSAMMENFASSUNG")
        print("="*50)
        print(f"🌐 Web Interface: {self.base_url}")
        print(f"👤 Admin User: {self.admin_user}")
        print(f"📧 Admin Email: {self.admin_email}")
        print(f"🏢 Organisation: {self.org_name}")
        print(f"📦 Repository: {self.repo_name}")
        print(f"🔗 Clone URL: {self.base_url}/{self.org_name}/{self.repo_name}.git")
        print(f"🔐 SSH Clone: ssh://git@192.168.100.1:2223/{self.org_name}/{self.repo_name}.git")
        print("="*50)
        print("✅ Bereit für Git Push!")

def main():
    """Main Function"""
    setup = GiteaAPISetup()
    
    if len(sys.argv) > 1 and sys.argv[1] == "--base-url":
        if len(sys.argv) > 2:
            setup.base_url = sys.argv[2]
            setup.api_url = urljoin(setup.base_url, "/api/v1/")
    
    success = setup.setup_complete()
    sys.exit(0 if success else 1)

if __name__ == "__main__":
    main() 