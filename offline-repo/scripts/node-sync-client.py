#!/usr/bin/env python3
# 🎩 Gentleman Node Sync Client

import os
import sys
import time
import json
import subprocess
import requests
from datetime import datetime

class GentlemanNodeSync:
    def __init__(self, config_file="sync-config.json"):
        self.config = self.load_config(config_file)
        self.git_server = self.config.get("git_server", "http://192.168.100.1:3000")
        self.local_repo = self.config.get("local_repo", "/opt/gentleman")
        self.sync_interval = self.config.get("sync_interval", 300)  # 5 minutes
        self.node_id = self.config.get("node_id", "unknown")
        
    def load_config(self, config_file):
        """Load configuration from JSON file"""
        default_config = {
            "git_server": "http://192.168.100.1:3000",
            "local_repo": "/opt/gentleman",
            "sync_interval": 300,
            "node_id": "unknown",
            "auto_restart_services": True,
            "services_to_restart": ["docker-compose"]
        }
        
        if os.path.exists(config_file):
            try:
                with open(config_file, 'r') as f:
                    config = json.load(f)
                    return {**default_config, **config}
            except Exception as e:
                print(f"⚠️  Error loading config: {e}")
                return default_config
        else:
            # Create default config
            with open(config_file, 'w') as f:
                json.dump(default_config, f, indent=2)
            return default_config
    
    def check_git_server(self):
        """Check if Git server is accessible"""
        try:
            response = requests.get(f"{self.git_server}/api/healthz", timeout=5)
            return response.status_code == 200
        except:
            return False
    
    def sync_repository(self):
        """Sync local repository with Git server"""
        print(f"🔄 [{datetime.now()}] Syncing repository...")
        
        if not os.path.exists(self.local_repo):
            os.makedirs(self.local_repo)
        
        os.chdir(self.local_repo)
        
        try:
            if not os.path.exists(".git"):
                # Initial clone
                print("🚀 Initial clone from Git server...")
                result = subprocess.run([
                    "git", "clone", 
                    f"{self.git_server}/gentleman/gentleman.git", 
                    "."
                ], capture_output=True, text=True)
                
                if result.returncode == 0:
                    print("✅ Initial clone successful")
                    return True
                else:
                    print(f"❌ Clone failed: {result.stderr}")
                    return False
            else:
                # Update existing repo
                subprocess.run(["git", "fetch", "origin"], check=True)
                
                # Check for changes
                local_commit = subprocess.run(
                    ["git", "rev-parse", "HEAD"], 
                    capture_output=True, text=True
                ).stdout.strip()
                
                remote_commit = subprocess.run(
                    ["git", "rev-parse", "origin/master"], 
                    capture_output=True, text=True
                ).stdout.strip()
                
                if local_commit != remote_commit:
                    print("📥 New changes detected, updating...")
                    subprocess.run(["git", "reset", "--hard", "origin/master"], check=True)
                    
                    # Get commit info
                    commit_info = subprocess.run([
                        "git", "log", "-1", "--format=%h - %s (%an, %ar)"
                    ], capture_output=True, text=True).stdout.strip()
                    
                    print(f"✅ Updated to: {commit_info}")
                    
                    # Restart services if configured
                    if self.config.get("auto_restart_services", False):
                        self.restart_services()
                    
                    return True
                else:
                    print("✅ Repository up to date")
                    return True
                    
        except Exception as e:
            print(f"❌ Sync failed: {e}")
            return False
    
    def restart_services(self):
        """Restart configured services after update"""
        services = self.config.get("services_to_restart", [])
        for service in services:
            try:
                if service == "docker-compose":
                    print("🔄 Restarting Docker services...")
                    subprocess.run(["docker-compose", "down"], cwd=self.local_repo)
                    subprocess.run(["docker-compose", "up", "-d"], cwd=self.local_repo)
                    print("✅ Docker services restarted")
                else:
                    subprocess.run(["systemctl", "restart", service])
                    print(f"✅ Service {service} restarted")
            except Exception as e:
                print(f"⚠️  Failed to restart {service}: {e}")
    
    def run_continuous_sync(self):
        """Run continuous synchronization loop"""
        print(f"🎩 Gentleman Node Sync Client - Node: {self.node_id}")
        print(f"📡 Git Server: {self.git_server}")
        print(f"📁 Local Repo: {self.local_repo}")
        print(f"⏰ Sync Interval: {self.sync_interval}s")
        
        while True:
            if self.check_git_server():
                self.sync_repository()
            else:
                print(f"⚠️  Git server not accessible: {self.git_server}")
            
            time.sleep(self.sync_interval)

if __name__ == "__main__":
    if len(sys.argv) > 1:
        config_file = sys.argv[1]
    else:
        config_file = "sync-config.json"
    
    sync_client = GentlemanNodeSync(config_file)
    
    try:
        sync_client.run_continuous_sync()
    except KeyboardInterrupt:
        print("\n🛑 Sync client stopped by user")
    except Exception as e:
        print(f"💥 Sync client crashed: {e}")
        sys.exit(1) 