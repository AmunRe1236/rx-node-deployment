# 📧 Proton Mail Service
.PHONY: protonmail-install protonmail-start protonmail-test protonmail-stop

protonmail-install:
	@echo "🎩 GENTLEMAN - Proton Mail Service Installation"
	@echo "═══════════════════════════════════════════════════════════════"
	@echo "📧 E-Mail: amonbaumgartner@gentlemail.com"
	@mkdir -p services/protonmail-service/logs
	@mkdir -p services/protonmail-service/data
	@cd services/protonmail-service && pip install -r requirements.txt
	@echo "✅ Proton Mail Service installiert"

protonmail-start:
	@echo "🎩 GENTLEMAN - Proton Mail Service Start"
	@echo "═══════════════════════════════════════════════════════════════"
	@cd services/protonmail-service && python app.py &
	@sleep 3
	@echo "✅ Proton Mail Service gestartet auf Port 8127"

protonmail-test:
	@echo "🎩 GENTLEMAN - Proton Mail Service Test"
	@echo "═══════════════════════════════════════════════════════════════"
	@curl -s http://localhost:8127/ | python -m json.tool || echo "⚠️ Service nicht erreichbar"
	@curl -s http://localhost:8127/health | python -m json.tool || echo "⚠️ Health Check fehlgeschlagen"

protonmail-stop:
	@echo "🎩 GENTLEMAN - Proton Mail Service Stop"
	@pkill -f "python.*app.py" || echo "Service bereits gestoppt"
	@echo "✅ Proton Mail Service gestoppt"

# 📡 Matrix Update Service
.PHONY: matrix-install matrix-start matrix-test matrix-stop matrix-update matrix-register

matrix-install:
	@echo "🎩 GENTLEMAN - Matrix Update Service Installation"
	@echo "═══════════════════════════════════════════════════════════════"
	@echo "📡 Matrix-basierte Update-Autorisierung"
	@mkdir -p services/matrix-update-service/{logs,data,config}
	@cd services/matrix-update-service && pip install -r requirements.txt
	@echo "✅ Matrix Update Service installiert"

matrix-start:
	@echo "🎩 GENTLEMAN - Matrix Update Service Start"
	@echo "═══════════════════════════════════════════════════════════════"
	@docker-compose up -d matrix-update-service
	@sleep 5
	@echo "✅ Matrix Update Service gestartet auf Port 8005"

matrix-test:
	@echo "🎩 GENTLEMAN - Matrix Update Service Test"
	@echo "═══════════════════════════════════════════════════════════════"
	@curl -s http://localhost:8005/health | python -m json.tool || echo "⚠️ Service nicht erreichbar"
	@curl -s http://localhost:8005/status | python -m json.tool || echo "⚠️ Status Check fehlgeschlagen"

matrix-stop:
	@echo "🎩 GENTLEMAN - Matrix Update Service Stop"
	@docker-compose stop matrix-update-service
	@echo "✅ Matrix Update Service gestoppt"

# 🔄 Matrix-basierte Updates
matrix-update:
	@echo "🎩 GENTLEMAN - Matrix Update Trigger"
	@echo "═══════════════════════════════════════════════════════════════"
	@./scripts/update/matrix_update_client.sh $(CMD) --user-id $(USER_ID)

matrix-register:
	@echo "🎩 GENTLEMAN - Matrix Device Registration"
	@echo "═══════════════════════════════════════════════════════════════"
	@./scripts/update/matrix_update_client.sh register --user-id $(USER_ID)

# 🚀 Vollständige Installation mit Matrix
install-full: install-deps install-models protonmail-install matrix-install
	@echo "🎩 GENTLEMAN - Vollständige Installation abgeschlossen"
	@echo "═══════════════════════════════════════════════════════════════"
	@echo "📧 Proton Mail: amonbaumgartner@gentlemail.com"
	@echo "📡 Matrix Update: http://localhost:8005"
	@echo "🚀 Alle Services bereit für Deployment"

# 🎯 Alle Services starten
start-all: start-llm start-stt start-tts start-mesh protonmail-start matrix-start
	@echo "🎩 GENTLEMAN - Alle Services gestartet"
	@echo "═══════════════════════════════════════════════════════════════"
	@echo "🤖 LLM Server: http://localhost:8001"
	@echo "🎤 STT Service: http://localhost:8002"  
	@echo "🔊 TTS Service: http://localhost:8003"
	@echo "📧 Proton Mail: http://localhost:8127"
	@echo "📡 Matrix Update: http://localhost:8005"
	@echo "🌐 Mesh Coordinator: http://localhost:8004"

# 🧪 Alle Services testen
test-all: test-llm test-stt test-tts test-mesh protonmail-test matrix-test
	@echo "🎩 GENTLEMAN - Alle Services getestet"

# 🛑 Alle Services stoppen
stop-all: stop-llm stop-stt stop-tts stop-mesh protonmail-stop matrix-stop
	@echo "🎩 GENTLEMAN - Alle Services gestoppt"

# 🔐 Matrix Update Shortcuts
.PHONY: update-system update-security update-software update-config restart-services rollback-system

update-system:
	@./scripts/update/matrix_update_client.sh system_update --user-id $(MATRIX_USER_ID)

update-security:
	@./scripts/update/matrix_update_client.sh security_patch --user-id $(MATRIX_USER_ID)

update-software:
	@./scripts/update/matrix_update_client.sh software_update --user-id $(MATRIX_USER_ID)

update-config:
	@./scripts/update/matrix_update_client.sh config_update --user-id $(MATRIX_USER_ID)

restart-services:
	@./scripts/update/matrix_update_client.sh service_restart --user-id $(MATRIX_USER_ID)

rollback-system:
	@./scripts/update/matrix_update_client.sh rollback --user-id $(MATRIX_USER_ID)

# 📊 Update Status
update-status:
	@./scripts/update/matrix_update_client.sh status 

# 🧪 AI Pipeline Testing
.PHONY: test-ai-pipeline test-ai-pipeline-full install-test-deps test-stt-only test-llm-only test-tts-only test-services-health

test-ai-pipeline:
	@echo "🎩 GENTLEMAN - AI Pipeline Quick Test"
	@echo "═══════════════════════════════════════════════════════════════"
	@echo "🎯 Testing: STT (M1) → LLM (RX 6700 XT) → TTS (M1)"
	@chmod +x scripts/test/test_ai_pipeline.sh
	@./scripts/test/test_ai_pipeline.sh

test-ai-pipeline-full:
	@echo "🎩 GENTLEMAN - Full AI Pipeline E2E Test"
	@echo "═══════════════════════════════════════════════════════════════"
	@echo "🎯 Comprehensive End-to-End Testing with Multiple Scenarios"
	@python3 tests/test_ai_pipeline_e2e.py

install-test-deps:
	@echo "🎩 GENTLEMAN - Installing Test Dependencies"
	@echo "═══════════════════════════════════════════════════════════════"
	@pip3 install aiohttp wave io pathlib dataclasses subprocess tempfile

test-stt-only:
	@echo "🎩 Testing STT Service (M1 Mac)..."
	@curl -f -s "http://192.168.100.20:8002/health" >/dev/null 2>&1 && echo "✅ STT Service: Healthy" || echo "❌ STT Service: Not available"

test-llm-only:
	@echo "🎩 Testing LLM Service (RX 6700 XT)..."
	@curl -f -s "http://192.168.100.10:8001/health" >/dev/null 2>&1 && echo "✅ LLM Service: Healthy" || echo "❌ LLM Service: Not available"

test-tts-only:
	@echo "🎩 Testing TTS Service (M1 Mac)..."
	@curl -f -s "http://192.168.100.20:8003/health" >/dev/null 2>&1 && echo "✅ TTS Service: Healthy" || echo "❌ TTS Service: Not available"

test-services-health:
	@echo "🎩 GENTLEMAN - AI Services Health Check"
	@echo "═══════════════════════════════════════════════════════════════"
	@make test-stt-only
	@make test-llm-only
	@make test-tts-only

# 🎯 Performance Testing
test-performance:
	@echo "🎩 GENTLEMAN - AI Pipeline Performance Test"
	@echo "═══════════════════════════════════════════════════════════════"
	@echo "⚡ Running 5 consecutive pipeline tests for performance metrics..."
	@for i in 1 2 3 4 5; do \
		echo "🔄 Test Run $$i/5:"; \
		./scripts/test/test_ai_pipeline.sh; \
		sleep 2; \
	done

# 🏗️ Development Testing
test-dev:
	@echo "🎩 GENTLEMAN - Development Test Suite"
	@echo "═══════════════════════════════════════════════════════════════"
	@make test-services-health
	@make test-ai-pipeline
	@echo "✅ Development testing complete"

# 🔒 Security Commands
.PHONY: security-audit security-harden security-check install-security-hooks

security-audit:
	@echo "🔒 GENTLEMAN - Security Audit"
	@echo "═══════════════════════════════════════════════════════════════"
	@chmod +x scripts/security/security_hardening.sh
	@./scripts/security/security_hardening.sh

security-harden:
	@echo "🔒 GENTLEMAN - Security Hardening"
	@echo "═══════════════════════════════════════════════════════════════"
	@echo "⚠️  KRITISCHE Sicherheitsmaßnahmen werden implementiert..."
	@chmod +x scripts/security/security_hardening.sh
	@./scripts/security/security_hardening.sh

security-check:
	@echo "🔒 GENTLEMAN - Quick Security Check"
	@echo "═══════════════════════════════════════════════════════════════"
	@chmod +x scripts/security/pre_commit_security_check.sh
	@./scripts/security/pre_commit_security_check.sh

install-security-hooks:
	@echo "🔒 GENTLEMAN - Installing Security Git Hooks"
	@echo "═══════════════════════════════════════════════════════════════"
	@chmod +x scripts/security/pre_commit_security_check.sh
	@cp scripts/security/pre_commit_security_check.sh .git/hooks/pre-commit
	@chmod +x .git/hooks/pre-commit
	@echo "✅ Pre-commit security hook installed"

# 🚨 Pre-Deployment Security
pre-deploy-security:
	@echo "🚨 GENTLEMAN - Pre-Deployment Security Check"
	@echo "═══════════════════════════════════════════════════════════════"
	@echo "🔒 Führe vollständige Sicherheitsprüfung durch..."
	@make security-harden
	@make security-check
	@make test-services-health
	@echo ""
	@echo "✅ System ist bereit für sicheres Deployment!"
	@echo ""
	@echo "🔐 NÄCHSTE SCHRITTE:"
	@echo "1. Führe 'make install-security-hooks' aus"
	@echo "2. Teste Firewall mit './scripts/security/setup_firewall.sh'"
	@echo "3. Sichere deine .env Datei"
	@echo "4. Aktiviere Matrix-Autorisierung"

# 📚 Git Server Commands
.PHONY: git-setup git-start git-stop git-restart git-status git-logs git-backup git-clean git-update git-shell

git-setup:
	@echo "🎩 GENTLEMAN - Git Server Setup"
	@echo "═══════════════════════════════════════════════════════════════"
	@echo "📚 Setting up local Git server with Gitea..."
	@chmod +x scripts/git-server/setup_git_server.sh
	@chmod +x scripts/git-server/backup.sh
	@./scripts/git-server/setup_git_server.sh

git-setup-m1:
	@echo "🎩 GENTLEMAN - Git Server Setup für M1 Mac"
	@echo "═══════════════════════════════════════════════════════════════"
	@echo "🍎 Setting up Git server optimized for M1 Mac..."
	@chmod +x scripts/git-server/setup_git_server_m1.sh
	@chmod +x scripts/git-server/backup.sh
	@./scripts/git-server/setup_git_server_m1.sh

git-start:
	@echo "🎩 GENTLEMAN - Starting Git Server"
	@echo "═══════════════════════════════════════════════════════════════"
	@docker-compose -f docker-compose.git-server.yml up -d
	@echo "✅ Git Server started"
	@echo "🌐 Access: https://git.gentleman.local"

git-stop:
	@echo "🎩 GENTLEMAN - Stopping Git Server"
	@echo "═══════════════════════════════════════════════════════════════"
	@docker-compose -f docker-compose.git-server.yml down
	@echo "✅ Git Server stopped"

git-restart:
	@echo "🎩 GENTLEMAN - Restarting Git Server"
	@echo "═══════════════════════════════════════════════════════════════"
	@docker-compose -f docker-compose.git-server.yml restart
	@echo "✅ Git Server restarted"

git-status:
	@echo "🎩 GENTLEMAN - Git Server Status"
	@echo "═══════════════════════════════════════════════════════════════"
	@docker-compose -f docker-compose.git-server.yml ps

git-logs:
	@echo "🎩 GENTLEMAN - Git Server Logs"
	@echo "═══════════════════════════════════════════════════════════════"
	@docker-compose -f docker-compose.git-server.yml logs -f

git-backup:
	@echo "🎩 GENTLEMAN - Creating Git Server Backup"
	@echo "═══════════════════════════════════════════════════════════════"
	@docker-compose -f docker-compose.git-server.yml exec gitea-backup /backup.sh
	@echo "✅ Backup completed"

git-clean:
	@echo "🎩 GENTLEMAN - Cleaning Git Server"
	@echo "═══════════════════════════════════════════════════════════════"
	@echo "⚠️  This will remove all Git server data!"
	@read -p "Are you sure? (y/N): " confirm && [ "$$confirm" = "y" ]
	@docker-compose -f docker-compose.git-server.yml down -v
	@docker system prune -f
	@echo "✅ Git Server cleaned"

git-update:
	@echo "🎩 GENTLEMAN - Updating Git Server"
	@echo "═══════════════════════════════════════════════════════════════"
	@docker-compose -f docker-compose.git-server.yml pull
	@docker-compose -f docker-compose.git-server.yml up -d
	@echo "✅ Git Server updated"

git-shell:
	@echo "🎩 GENTLEMAN - Git Server Shell"
	@echo "═══════════════════════════════════════════════════════════════"
	@docker-compose -f docker-compose.git-server.yml exec gitea sh

# 📚 Git Repository Management
git-create-repo:
	@echo "🎩 GENTLEMAN - Create Repository"
	@echo "═══════════════════════════════════════════════════════════════"
	@echo "📚 Creating new repository: $(REPO_NAME)"
	@echo "🌐 Access Gitea web interface to create repositories"
	@echo "   URL: https://git.gentleman.local"

git-clone-local:
	@echo "🎩 GENTLEMAN - Clone from Local Git Server"
	@echo "═══════════════════════════════════════════════════════════════"
	@echo "📚 Clone repository: $(REPO_NAME)"
	@git clone https://git.gentleman.local/$(USER)/$(REPO_NAME).git

# 🔄 Git Server Integration
git-push-to-local:
	@echo "🎩 GENTLEMAN - Push to Local Git Server"
	@echo "═══════════════════════════════════════════════════════════════"
	@echo "📚 Adding local Git server as remote..."
	@git remote add local https://git.gentleman.local/$(USER)/$(REPO_NAME).git || echo "Remote already exists"
	@git push local main

git-set-local-origin:
	@echo "🎩 GENTLEMAN - Set Local Git as Origin"
	@echo "═══════════════════════════════════════════════════════════════"
	@echo "📚 Setting local Git server as origin..."
	@git remote set-url origin https://git.gentleman.local/$(USER)/$(REPO_NAME).git
	@echo "✅ Local Git server set as origin"

git-demo:
	@echo "🎩 GENTLEMAN - Git Server Demo"
	@echo "═══════════════════════════════════════════════════════════════"
	@echo "🎯 Interactive Git server demonstration and testing"
	@chmod +x scripts/git-server/demo_git_server.sh
	@./scripts/git-server/demo_git_server.sh

# 🪟 WINDOWS COMMANDS
.PHONY: setup-windows gentleman-up-windows gentleman-test-windows gentleman-logs-windows

setup-windows:
	@echo "🪟 Setting up GENTLEMAN on Windows..."
	@powershell -ExecutionPolicy Bypass -File scripts/setup/setup_windows.ps1 -InstallDocker -InstallWSL

gentleman-up-windows:
	@echo "🚀 Starting GENTLEMAN services on Windows..."
	@docker-compose -f docker-compose.yml -f docker-compose.windows.yml up -d

gentleman-test-windows:
	@echo "🧪 Testing GENTLEMAN on Windows..."
	@powershell -ExecutionPolicy Bypass -File scripts/test/test_windows.ps1

gentleman-logs-windows:
	@echo "📋 Viewing Windows logs..."
	@docker-compose -f docker-compose.yml -f docker-compose.windows.yml logs -f

# 🌐 MULTI-PLATFORM COMMANDS
.PHONY: detect-platform setup-auto gentleman-up-auto

detect-platform:
	@echo "🔍 Detecting platform..."
	@if [ "$$(uname -s)" = "Darwin" ]; then \
		if [ "$$(uname -m)" = "arm64" ]; then \
			echo "🍎 Detected: macOS Apple Silicon (M1/M2/M3)"; \
		else \
			echo "🍎 Detected: macOS Intel"; \
		fi \
	elif [ "$$(uname -s)" = "Linux" ]; then \
		echo "🐧 Detected: Linux ($$(lsb_release -si 2>/dev/null || echo Unknown))"; \
	else \
		echo "❓ Unknown platform: $$(uname -s)"; \
	fi

setup-auto: detect-hardware
	@echo "🎯 Auto-detecting platform and running setup..."
	@if [ -f config/hardware/node_config.env ]; then \
		source config/hardware/node_config.env; \
		case "$$GENTLEMAN_NODE_ROLE" in \
			"llm-server") \
				echo "🎮 Starting LLM Server services..."; \
				echo "✅ Hardware-optimized LLM Server configuration applied"; \
				;; \
			"audio-server") \
				echo "🎤 Starting Audio Server services..."; \
				echo "✅ Hardware-optimized Audio Server configuration applied"; \
				;; \
			"git-server") \
				echo "📚 Starting Git Server services..."; \
				echo "✅ Hardware-optimized Git Server configuration applied"; \
				;; \
			"client") \
				echo "💻 Starting Client services..."; \
				echo "✅ Hardware-optimized Client configuration applied"; \
				;; \
			*) \
				echo "❓ Unknown role, using platform detection..."; \
				if [ "$$(uname -s)" = "Darwin" ]; then \
					if [ "$$(uname -m)" = "arm64" ]; then \
						echo "🍎 Running M1 Mac setup..."; \
						$(MAKE) git-setup-m1; \
					else \
						echo "🍎 Running Intel Mac setup..."; \
						$(MAKE) setup; \
					fi \
				elif [ "$$(uname -s)" = "Linux" ]; then \
					echo "🐧 Running Linux setup..."; \
					$(MAKE) setup; \
				else \
					echo "❓ Unsupported platform. Please run setup manually."; \
					exit 1; \
				fi \
				;; \
		esac \
	else \
		echo "❌ No hardware configuration found. Running detect-hardware first..."; \
		$(MAKE) detect-hardware; \
		$(MAKE) setup-auto; \
	fi

gentleman-up-auto:
	@echo "🚀 Auto-starting services based on platform..."
	@if [ "$$(uname -s)" = "Darwin" ]; then \
		if [ "$$(uname -m)" = "arm64" ]; then \
			echo "🍎 Starting M1 Mac services (STT/TTS + Git Server)..."; \
			$(MAKE) start-stt start-tts git-start; \
		else \
			echo "🍎 Starting Intel Mac services (Client)..."; \
			$(MAKE) start-web; \
		fi \
	elif [ "$$(uname -s)" = "Linux" ]; then \
		echo "🐧 Starting Linux services (LLM Server)..."; \
		./setup.sh; \
	else \
		echo "❓ Unsupported platform for auto-start."; \
		exit 1; \
	fi 

# 🔍 HARDWARE DETECTION COMMANDS
.PHONY: detect-hardware hardware-report hardware-config hardware-test

detect-hardware:
	@echo "🔍 Running hardware detection..."
	@chmod +x scripts/setup/hardware_detection.sh
	@./scripts/setup/hardware_detection.sh

hardware-report:
	@echo "📊 Generating hardware report..."
	@if [ -f config/hardware/current_hardware.json ]; then \
		cat config/hardware/current_hardware.json | jq .; \
	else \
		echo "❌ No hardware report found. Run 'make detect-hardware' first."; \
	fi

hardware-config:
	@echo "⚙️ Showing hardware configuration..."
	@if [ -f config/hardware/node_config.env ]; then \
		cat config/hardware/node_config.env; \
	else \
		echo "❌ No hardware configuration found. Run 'make detect-hardware' first."; \
	fi

hardware-test:
	@echo "🧪 Testing hardware capabilities..."
	@scripts/test/test_hardware_capabilities.sh

# 🎯 SMART SETUP COMMANDS
.PHONY: setup-smart setup-with-detection setup-force

setup-smart: detect-hardware setup-auto
	@echo "🎯 Smart setup completed based on detected hardware"

setup-with-detection:
	@echo "🔍 Running setup with hardware detection..."
	@./setup.sh

setup-force:
	@echo "⚡ Running forced setup (skipping hardware detection)..."
	@./setup.sh --skip-hardware-detection --force

# 🌐 NEBULA VPN COMMANDS
.PHONY: nebula-setup nebula-start nebula-stop nebula-status nebula-test

nebula-setup:
	@echo "🌐 Setting up Nebula VPN for RX Node..."
	@chmod +x scripts/setup/setup_nebula_rx.sh
	@sudo scripts/setup/setup_nebula_rx.sh

nebula-setup-test:
	@echo "🧪 Testing Nebula setup (no service installation)..."
	@chmod +x scripts/setup/setup_nebula_rx.sh
	@scripts/setup/setup_nebula_rx.sh --no-service

nebula-start:
	@echo "🚀 Starting Nebula VPN service..."
	@sudo systemctl start nebula-rx.service
	@sudo systemctl status nebula-rx.service --no-pager

nebula-stop:
	@echo "🛑 Stopping Nebula VPN service..."
	@sudo systemctl stop nebula-rx.service

nebula-restart:
	@echo "🔄 Restarting Nebula VPN service..."
	@sudo systemctl restart nebula-rx.service
	@sudo systemctl status nebula-rx.service --no-pager

nebula-status:
	@echo "📊 Nebula VPN Status..."
	@echo "═══════════════════════════════════════════════════════════════"
	@if systemctl is-active --quiet nebula-rx.service 2>/dev/null; then \
		echo "✅ Service: Active"; \
	else \
		echo "❌ Service: Inactive"; \
	fi
	@if ip addr show nebula1 &>/dev/null; then \
		NEBULA_IP=$$(ip addr show nebula1 | grep -oP 'inet \K[\d.]+' || echo "Unknown"); \
		echo "✅ Interface: nebula1 ($$NEBULA_IP)"; \
	else \
		echo "❌ Interface: Not available"; \
	fi

nebula-test:
	@echo "🧪 Testing Nebula connectivity..."
	@echo "═══════════════════════════════════════════════════════════════"
	@if ip addr show nebula1 &>/dev/null; then \
		echo "🌐 Testing Lighthouse (192.168.100.1)..."; \
		if ping -c 1 -W 5 192.168.100.1 &>/dev/null; then \
			echo "✅ Lighthouse reachable"; \
		else \
			echo "❌ Lighthouse unreachable"; \
		fi; \
		echo "🌐 Testing other nodes..."; \
		for node_ip in 192.168.100.20 192.168.100.30; do \
			if ping -c 1 -W 2 $$node_ip &>/dev/null; then \
				echo "✅ Node $$node_ip reachable"; \
			else \
				echo "ℹ️  Node $$node_ip not available"; \
			fi; \
		done; \
	else \
		echo "❌ Nebula interface not available"; \
	fi

nebula-logs:
	@echo "📋 Nebula VPN Logs..."
	@journalctl -u nebula-rx.service -f

# 🐧 IMPROVED LINUX SETUP
.PHONY: setup-linux-improved setup-linux-auto setup-linux-test

setup-linux-improved:
	@echo "🐧 Running improved Linux setup..."
	@chmod +x scripts/setup/setup_linux_improved.sh
	@scripts/setup/setup_linux_improved.sh

setup-linux-auto: detect-hardware setup-linux-improved
	@echo "🚀 Automatic Linux setup with hardware detection..."
	@echo "✅ Linux setup completed with hardware optimization"

setup-linux-test:
	@echo "🧪 Testing Linux setup components..."
	@echo "═══════════════════════════════════════════════════════════════"
	@echo "🔍 Checking system components..."
	@if command -v docker >/dev/null 2>&1; then \
		echo "✅ Docker: $$(docker --version)"; \
	else \
		echo "❌ Docker: Not found"; \
	fi
	@if command -v nebula >/dev/null 2>&1; then \
		echo "✅ Nebula: $$(nebula -version 2>/dev/null | head -n1)"; \
	else \
		echo "❌ Nebula: Not found"; \
	fi
	@if systemctl is-active --quiet nebula-rx.service 2>/dev/null; then \
		echo "✅ Nebula Service: Active"; \
	else \
		echo "❌ Nebula Service: Inactive"; \
	fi
	@if [[ -f config/hardware/node_config.env ]]; then \
		echo "✅ Hardware Config: Available"; \
		source config/hardware/node_config.env && echo "   Node Role: $$GENTLEMAN_NODE_ROLE"; \
	else \
		echo "❌ Hardware Config: Not found"; \
	fi

# 🔧 SETUP TROUBLESHOOTING
.PHONY: setup-fix setup-clean setup-reset

setup-fix:
	@echo "🔧 Fixing common setup issues..."
	@echo "═══════════════════════════════════════════════════════════════"
	@echo "🔍 Checking Docker permissions..."
	@sudo usermod -aG docker $$USER || echo "Docker group already configured"
	@echo "🔍 Checking Nebula configuration..."
	@if [[ -f /etc/nebula/rx-node/config.yml ]]; then \
		echo "✅ Nebula config exists"; \
		sudo nebula -config /etc/nebula/rx-node/config.yml -test && echo "✅ Config valid" || echo "❌ Config invalid"; \
	else \
		echo "❌ Nebula config missing - run setup-linux-improved"; \
	fi
	@echo "🔍 Checking systemd services..."
	@sudo systemctl daemon-reload
	@echo "✅ Setup issues checked"

setup-clean:
	@echo "🧹 Cleaning up setup artifacts..."
	@echo "⚠️  This will remove temporary files and reset some configurations"
	@read -p "Continue? (y/N): " confirm && [ "$$confirm" = "y" ] || exit 1
	@sudo systemctl stop nebula-* 2>/dev/null || true
	@sudo rm -rf /tmp/gentleman-* 2>/dev/null || true
	@docker system prune -f 2>/dev/null || true
	@echo "✅ Cleanup completed"

setup-reset:
	@echo "🔄 Resetting GENTLEMAN setup..."
	@echo "⚠️  This will remove ALL configuration and start fresh"
	@read -p "Are you sure? This cannot be undone! (y/N): " confirm && [ "$$confirm" = "y" ] || exit 1
	@sudo systemctl stop nebula-* 2>/dev/null || true
	@sudo systemctl disable nebula-* 2>/dev/null || true
	@sudo rm -rf /etc/nebula/ 2>/dev/null || true
	@sudo rm -f /etc/systemd/system/nebula-*.service 2>/dev/null || true
	@sudo systemctl daemon-reload
	@rm -rf config/hardware/ 2>/dev/null || true
	@docker-compose down -v 2>/dev/null || true
	@echo "✅ Reset completed - run setup-linux-improved to start fresh" 