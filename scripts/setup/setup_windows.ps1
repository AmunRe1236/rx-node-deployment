# 🎩 GENTLEMAN - Windows 10/11 Setup Script
# ═══════════════════════════════════════════════════════════════

param(
    [string]$NodeType = "client",
    [switch]$InstallDocker,
    [switch]$InstallWSL,
    [switch]$Force
)

# 🎨 Colors für PowerShell
$Colors = @{
    Red = "Red"
    Green = "Green"
    Yellow = "Yellow"
    Blue = "Blue"
    Cyan = "Cyan"
    White = "White"
}

function Write-Banner {
    Write-Host "🎩 GENTLEMAN - Windows Setup" -ForegroundColor Magenta
    Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Magenta
    Write-Host "🌟 Windows 10/11 Installation" -ForegroundColor White
    Write-Host ""
}

function Write-Step {
    param([string]$Message)
    Write-Host "🔧 $Message" -ForegroundColor Blue
}

function Write-Success {
    param([string]$Message)
    Write-Host "✅ $Message" -ForegroundColor Green
}

function Write-Warning {
    param([string]$Message)
    Write-Host "⚠️  $Message" -ForegroundColor Yellow
}

function Write-Error {
    param([string]$Message)
    Write-Host "❌ $Message" -ForegroundColor Red
}

function Test-Administrator {
    $currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($currentUser)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Install-Chocolatey {
    Write-Step "Installing Chocolatey package manager..."
    
    if (Get-Command choco -ErrorAction SilentlyContinue) {
        Write-Success "Chocolatey already installed"
        return
    }
    
    Set-ExecutionPolicy Bypass -Scope Process -Force
    [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
    iex ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))
    
    Write-Success "Chocolatey installed"
}

function Install-Dependencies {
    Write-Step "Installing Windows dependencies..."
    
    $packages = @(
        "git",
        "curl",
        "make",
        "python3",
        "nodejs"
    )
    
    foreach ($package in $packages) {
        Write-Host "Installing $package..." -ForegroundColor Cyan
        choco install $package -y --no-progress
    }
    
    Write-Success "Dependencies installed"
}

function Install-DockerDesktop {
    if (-not $InstallDocker) {
        Write-Warning "Docker Desktop installation skipped. Use -InstallDocker to install."
        return
    }
    
    Write-Step "Installing Docker Desktop..."
    
    if (Get-Process "Docker Desktop" -ErrorAction SilentlyContinue) {
        Write-Success "Docker Desktop already running"
        return
    }
    
    # Download Docker Desktop
    $dockerUrl = "https://desktop.docker.com/win/main/amd64/Docker%20Desktop%20Installer.exe"
    $dockerInstaller = "$env:TEMP\DockerDesktopInstaller.exe"
    
    Write-Host "Downloading Docker Desktop..." -ForegroundColor Cyan
    Invoke-WebRequest -Uri $dockerUrl -OutFile $dockerInstaller
    
    Write-Host "Installing Docker Desktop..." -ForegroundColor Cyan
    Start-Process -FilePath $dockerInstaller -ArgumentList "install", "--quiet" -Wait
    
    Remove-Item $dockerInstaller -Force
    Write-Success "Docker Desktop installed. Please restart and enable WSL2 backend."
}

function Enable-WSL2 {
    if (-not $InstallWSL) {
        Write-Warning "WSL2 installation skipped. Use -InstallWSL to install."
        return
    }
    
    Write-Step "Enabling WSL2..."
    
    # Enable WSL feature
    dism.exe /online /enable-feature /featurename:Microsoft-Windows-Subsystem-Linux /all /norestart
    
    # Enable Virtual Machine Platform
    dism.exe /online /enable-feature /featurename:VirtualMachinePlatform /all /norestart
    
    # Set WSL2 as default
    wsl --set-default-version 2
    
    Write-Success "WSL2 enabled. Restart required."
    Write-Warning "Please restart Windows and run: wsl --install -d Ubuntu"
}

function Install-Nebula {
    Write-Step "Installing Nebula VPN..."
    
    $nebulaVersion = "v1.9.5"
    $nebulaUrl = "https://github.com/slackhq/nebula/releases/download/$nebulaVersion/nebula-windows-amd64.zip"
    $nebulaZip = "$env:TEMP\nebula-windows.zip"
    $nebulaDir = "C:\Program Files\Nebula"
    
    # Create Nebula directory
    if (-not (Test-Path $nebulaDir)) {
        New-Item -ItemType Directory -Path $nebulaDir -Force
    }
    
    # Download Nebula
    Write-Host "Downloading Nebula $nebulaVersion..." -ForegroundColor Cyan
    Invoke-WebRequest -Uri $nebulaUrl -OutFile $nebulaZip
    
    # Extract Nebula
    Expand-Archive -Path $nebulaZip -DestinationPath $nebulaDir -Force
    
    # Add to PATH
    $currentPath = [Environment]::GetEnvironmentVariable("PATH", "Machine")
    if ($currentPath -notlike "*$nebulaDir*") {
        [Environment]::SetEnvironmentVariable("PATH", "$currentPath;$nebulaDir", "Machine")
    }
    
    Remove-Item $nebulaZip -Force
    Write-Success "Nebula installed to $nebulaDir"
}

function Setup-WindowsFirewall {
    Write-Step "Configuring Windows Firewall..."
    
    $ports = @(
        @{Port=8001; Name="GENTLEMAN-LLM"},
        @{Port=8002; Name="GENTLEMAN-STT"},
        @{Port=8003; Name="GENTLEMAN-TTS"},
        @{Port=8004; Name="GENTLEMAN-MESH"},
        @{Port=8005; Name="GENTLEMAN-MATRIX"},
        @{Port=8080; Name="GENTLEMAN-WEB"},
        @{Port=4242; Name="NEBULA-LIGHTHOUSE"; Protocol="UDP"}
    )
    
    foreach ($portRule in $ports) {
        $protocol = if ($portRule.Protocol) { $portRule.Protocol } else { "TCP" }
        
        Write-Host "Opening port $($portRule.Port)/$protocol..." -ForegroundColor Cyan
        
        New-NetFirewallRule -DisplayName $portRule.Name -Direction Inbound -Protocol $protocol -LocalPort $portRule.Port -Action Allow -ErrorAction SilentlyContinue
    }
    
    Write-Success "Windows Firewall configured"
}

function Create-WindowsConfig {
    Write-Step "Creating Windows-specific configuration..."
    
    $configDir = ".\config\windows"
    if (-not (Test-Path $configDir)) {
        New-Item -ItemType Directory -Path $configDir -Force
    }
    
    # Windows environment file
    $windowsEnv = @"
# 🪟 GENTLEMAN Windows Configuration
# ═══════════════════════════════════════════════════════════════

# 🖥️ WINDOWS SETTINGS
GENTLEMAN_OS=windows
GENTLEMAN_NODE_TYPE=$NodeType
DOCKER_DESKTOP=true
WSL2_BACKEND=true

# 🌐 NETWORK SETTINGS
WINDOWS_FIREWALL_CONFIGURED=true
NEBULA_WINDOWS_SERVICE=true

# 🐳 DOCKER SETTINGS
DOCKER_COMPOSE_VERSION=v2
DOCKER_BUILDKIT=1
COMPOSE_DOCKER_CLI_BUILD=1

# 🔒 SECURITY SETTINGS
WINDOWS_DEFENDER_EXCLUSIONS=true
FIREWALL_RULES_APPLIED=true

# 🎯 PERFORMANCE SETTINGS
WINDOWS_PERFORMANCE_MODE=high
DOCKER_MEMORY_LIMIT=8GB
DOCKER_CPU_LIMIT=4
"@
    
    $windowsEnv | Out-File -FilePath "$configDir\windows.env" -Encoding UTF8
    
    Write-Success "Windows configuration created"
}

function Test-WindowsCompatibility {
    Write-Step "Testing Windows compatibility..."
    
    $issues = @()
    
    # Check Windows version
    $winVersion = [System.Environment]::OSVersion.Version
    if ($winVersion.Major -lt 10) {
        $issues += "Windows 10 or later required"
    }
    
    # Check Hyper-V capability
    $hyperv = Get-WindowsOptionalFeature -Online -FeatureName Microsoft-Hyper-V-All
    if ($hyperv.State -ne "Enabled") {
        $issues += "Hyper-V not enabled (required for Docker Desktop)"
    }
    
    # Check available memory
    $memory = Get-CimInstance -ClassName Win32_ComputerSystem
    $memoryGB = [math]::Round($memory.TotalPhysicalMemory / 1GB)
    if ($memoryGB -lt 8) {
        $issues += "Less than 8GB RAM detected ($memoryGB GB)"
    }
    
    if ($issues.Count -eq 0) {
        Write-Success "Windows compatibility check passed"
    } else {
        Write-Warning "Compatibility issues found:"
        foreach ($issue in $issues) {
            Write-Host "  - $issue" -ForegroundColor Yellow
        }
    }
}

function Show-WindowsInstructions {
    Write-Host ""
    Write-Success "🎩 Windows Setup completed!"
    Write-Host ""
    Write-Host "📋 Next Steps:" -ForegroundColor White
    Write-Host ""
    Write-Host "1. 🔄 Restart Windows (if WSL2 was installed)" -ForegroundColor Cyan
    Write-Host "2. 🐧 Install Ubuntu in WSL2: wsl --install -d Ubuntu" -ForegroundColor Cyan
    Write-Host "3. 🐳 Start Docker Desktop" -ForegroundColor Cyan
    Write-Host "4. 🌐 Configure Nebula certificates" -ForegroundColor Cyan
    Write-Host "5. 🚀 Start GENTLEMAN services: make gentleman-up" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "🔧 Windows-specific commands:" -ForegroundColor White
    Write-Host "  make gentleman-up-windows    # Start Windows services" -ForegroundColor Gray
    Write-Host "  make gentleman-test-windows  # Test Windows setup" -ForegroundColor Gray
    Write-Host "  make gentleman-logs-windows  # View Windows logs" -ForegroundColor Gray
    Write-Host ""
    Write-Host "⚠️  Limitations on Windows:" -ForegroundColor Yellow
    Write-Host "  - No native GPU support for AMD ROCm" -ForegroundColor Yellow
    Write-Host "  - CUDA support available for NVIDIA GPUs" -ForegroundColor Yellow
    Write-Host "  - Some services run in WSL2 containers" -ForegroundColor Yellow
    Write-Host ""
}

# 🚀 Main execution
function Main {
    Write-Banner
    
    if (-not (Test-Administrator)) {
        Write-Error "This script must be run as Administrator"
        Write-Host "Right-click PowerShell and select 'Run as Administrator'" -ForegroundColor Yellow
        exit 1
    }
    
    Test-WindowsCompatibility
    Install-Chocolatey
    Install-Dependencies
    Install-DockerDesktop
    Enable-WSL2
    Install-Nebula
    Setup-WindowsFirewall
    Create-WindowsConfig
    Show-WindowsInstructions
}

# Execute main function
Main 