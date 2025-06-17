#!/bin/bash

# 🎩 GENTLEMAN RX Node PAM Integration
# ═══════════════════════════════════════════════════════════════
# Systemweite LDAP/Keycloak Authentifizierung für Linux RX Node

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}🖥️  GENTLEMAN RX Node PAM Setup${NC}"
echo "═══════════════════════════════════════════════════════════════"

# Check if running on Linux
if [[ "$OSTYPE" != "linux-gnu"* ]]; then
    echo -e "${RED}❌ This script must run on the Linux RX Node${NC}"
    exit 1
fi

# Check if running as root
if [[ $EUID -ne 0 ]]; then
    echo -e "${RED}❌ This script must be run as root${NC}"
    echo "Usage: sudo $0"
    exit 1
fi

# Auto-detect M1 Control Node IP
echo -e "${BLUE}🔍 Auto-detecting M1 Control Node...${NC}"
M1_IP=""

# Try to find M1 via common network ranges
for network in "192.168.68" "192.168.1" "192.168.0" "10.0.0"; do
    for i in {1..254}; do
        test_ip="${network}.${i}"
        # Quick ping test
        if ping -c 1 -W 1 "$test_ip" >/dev/null 2>&1; then
            # Test if Keycloak is running on this IP
            if curl -s --connect-timeout 2 "http://${test_ip}:8085/health" >/dev/null 2>&1; then
                M1_IP="$test_ip"
                echo -e "${GREEN}✅ Found M1 Control Node at: $M1_IP${NC}"
                break 2
            fi
        fi
    done
done

if [ -z "$M1_IP" ]; then
    echo -e "${YELLOW}⚠️  Could not auto-detect M1 Control Node${NC}"
    read -p "Please enter M1 Control Node IP address: " M1_IP
fi

echo -e "${GREEN}✅ Using M1 Control Node: $M1_IP${NC}"

# Detect Linux distribution
if [ -f /etc/arch-release ]; then
    DISTRO="arch"
    echo -e "${GREEN}✅ Arch Linux detected${NC}"
elif [ -f /etc/debian_version ]; then
    DISTRO="debian"
    echo -e "${GREEN}✅ Debian/Ubuntu detected${NC}"
elif [ -f /etc/redhat-release ]; then
    DISTRO="redhat"
    echo -e "${GREEN}✅ RedHat/CentOS detected${NC}"
else
    echo -e "${YELLOW}⚠️  Unknown distribution, using generic setup${NC}"
    DISTRO="generic"
fi

# 1. Install required packages
echo -e "${BLUE}📦 Installing LDAP/PAM packages...${NC}"
case $DISTRO in
    "arch")
        pacman -S --noconfirm openldap nss-pam-ldapd pam-ldap sudo openssh
        ;;
    "debian")
        apt-get update
        apt-get install -y libpam-ldap libnss-ldap ldap-utils sudo openssh-server
        ;;
    "redhat")
        yum install -y openldap-clients nss-pam-ldapd pam_ldap sudo openssh-server
        ;;
    *)
        echo -e "${YELLOW}⚠️  Please install LDAP/PAM packages manually${NC}"
        ;;
esac

# 2. Create gentleman user
echo -e "${BLUE}👤 Creating gentleman user...${NC}"
useradd -m -s /bin/bash gentleman 2>/dev/null || echo "User already exists"
usermod -aG sudo gentleman
usermod -aG wheel gentleman 2>/dev/null || true

# Setup SSH directory
mkdir -p /home/gentleman/.ssh
chmod 700 /home/gentleman/.ssh
chown -R gentleman:gentleman /home/gentleman

# 3. Configure LDAP client
echo -e "${BLUE}🔧 Configuring LDAP client...${NC}"
cat > /etc/ldap/ldap.conf << EOF
# 🎩 GENTLEMAN LDAP Configuration
BASE dc=gentleman,dc=local
URI ldap://${M1_IP}:389

# Connection settings
BINDDN cn=readonly,dc=gentleman,dc=local
BINDPW LdapRead2024!

# Security settings
TLS_REQCERT never
TIMELIMIT 15
BIND_TIMELIMIT 15

# Search settings
SCOPE sub
DEREF never
EOF

# 4. Configure NSS (Name Service Switch)
echo -e "${BLUE}🔧 Configuring NSS...${NC}"
cp /etc/nsswitch.conf /etc/nsswitch.conf.backup

cat > /etc/nsswitch.conf << 'EOF'
# 🎩 GENTLEMAN NSS Configuration
passwd:         files ldap
group:          files ldap
shadow:         files ldap

hosts:          files dns
networks:       files

protocols:      db files
services:       db files
ethers:         db files
rpc:            db files

netgroup:       nis
EOF

# 5. Configure PAM for LDAP authentication
echo -e "${BLUE}🔧 Configuring PAM...${NC}"

# Backup original PAM files
cp /etc/pam.d/system-auth /etc/pam.d/system-auth.backup 2>/dev/null || true
cp /etc/pam.d/common-auth /etc/pam.d/common-auth.backup 2>/dev/null || true

# Configure PAM authentication
if [ -f /etc/pam.d/system-auth ]; then
    # RedHat/CentOS style
    cat > /etc/pam.d/system-auth << 'EOF'
#%PAM-1.0
# 🎩 GENTLEMAN PAM System Authentication

auth        required      pam_env.so
auth        sufficient    pam_unix.so nullok try_first_pass
auth        requisite     pam_succeed_if.so uid >= 1000 quiet_success
auth        sufficient    pam_ldap.so use_first_pass
auth        required      pam_deny.so

account     required      pam_unix.so
account     sufficient    pam_localuser.so
account     sufficient    pam_succeed_if.so uid < 1000 quiet
account     [default=bad success=ok user_unknown=ignore] pam_ldap.so
account     required      pam_permit.so

password    requisite     pam_pwquality.so try_first_pass local_users_only retry=3 authtok_type=
password    sufficient    pam_unix.so sha512 shadow nullok try_first_pass use_authtok
password    sufficient    pam_ldap.so use_authtok
password    required      pam_deny.so

session     optional      pam_keyinit.so revoke
session     required      pam_limits.so
session     optional      pam_mkhomedir.so skel=/etc/skel umask=077
session     [success=1 default=ignore] pam_succeed_if.so service in crond quiet use_uid
session     required      pam_unix.so
session     optional      pam_ldap.so
EOF

elif [ -f /etc/pam.d/common-auth ]; then
    # Debian/Ubuntu style
    cat > /etc/pam.d/common-auth << 'EOF'
#%PAM-1.0
# 🎩 GENTLEMAN PAM Common Authentication

auth    [success=2 default=ignore]      pam_unix.so nullok_secure
auth    [success=1 default=ignore]      pam_ldap.so use_first_pass
auth    requisite                       pam_deny.so
auth    required                        pam_permit.so
auth    optional                        pam_cap.so
EOF

    cat > /etc/pam.d/common-account << 'EOF'
#%PAM-1.0
# 🎩 GENTLEMAN PAM Common Account

account [success=2 new_authtok_reqd=done default=ignore]        pam_unix.so
account [success=1 new_authtok_reqd=done default=ignore]        pam_ldap.so
account requisite                       pam_deny.so
account required                        pam_permit.so
EOF

    cat > /etc/pam.d/common-session << 'EOF'
#%PAM-1.0
# 🎩 GENTLEMAN PAM Common Session

session [default=1]                     pam_permit.so
session requisite                       pam_deny.so
session required                        pam_permit.so
session optional                        pam_mkhomedir.so skel=/etc/skel umask=077
session required                        pam_unix.so
session optional                        pam_ldap.so
EOF
fi

# 6. Configure LDAP daemon (nslcd)
echo -e "${BLUE}🔧 Configuring NSLCD...${NC}"
cat > /etc/nslcd.conf << EOF
# 🎩 GENTLEMAN NSLCD Configuration

# LDAP server settings
uri ldap://${M1_IP}:389
base dc=gentleman,dc=local

# Bind settings
binddn cn=readonly,dc=gentleman,dc=local
bindpw LdapRead2024!

# Search scope
scope sub

# Mapping settings
map passwd uid              uid
map passwd gidNumber        gidNumber
map passwd homeDirectory    homeDirectory
map passwd loginShell       loginShell
map passwd gecos            cn

# Security settings
ssl no
tls_reqcert never

# Performance settings
idle_timelimit 3600
reconnect_sleeptime 1
reconnect_retrytime 10
EOF

chmod 600 /etc/nslcd.conf

# 7. Configure SSH for LDAP users
echo -e "${BLUE}🔧 Configuring SSH...${NC}"
cp /etc/ssh/sshd_config /etc/ssh/sshd_config.backup

# Add LDAP-friendly SSH configuration
cat >> /etc/ssh/sshd_config << 'EOF'

# 🎩 GENTLEMAN SSH LDAP Configuration
UsePAM yes
ChallengeResponseAuthentication no
PasswordAuthentication yes
PubkeyAuthentication yes
AuthorizedKeysFile .ssh/authorized_keys

# Allow LDAP users
AllowUsers gentleman
AllowGroups sudo wheel homelab-admins

# Security settings
PermitRootLogin no
MaxAuthTries 3
ClientAliveInterval 300
ClientAliveCountMax 2
EOF

# 8. Configure sudo for LDAP groups
echo -e "${BLUE}🔧 Configuring sudo...${NC}"
cat > /etc/sudoers.d/gentleman-ldap << 'EOF'
# 🎩 GENTLEMAN LDAP Sudo Configuration

# Allow homelab-admins group full sudo access
%homelab-admins ALL=(ALL:ALL) ALL

# Allow gentleman user full sudo access
gentleman ALL=(ALL:ALL) ALL

# Allow homelab-users limited sudo access
%homelab-users ALL=(ALL:ALL) /usr/bin/systemctl, /usr/bin/docker, /usr/bin/docker-compose
EOF

chmod 440 /etc/sudoers.d/gentleman-ldap

# 9. Start and enable services
echo -e "${BLUE}🚀 Starting services...${NC}"
case $DISTRO in
    "arch")
        systemctl enable --now nslcd
        systemctl enable --now sshd
        ;;
    "debian")
        systemctl enable --now nslcd
        systemctl enable --now ssh
        ;;
    "redhat")
        systemctl enable --now nslcd
        systemctl enable --now sshd
        ;;
esac

# 10. Test LDAP connectivity
echo -e "${BLUE}🧪 Testing LDAP connectivity...${NC}"
if ldapsearch -x -H ldap://${M1_IP}:389 -D "cn=readonly,dc=gentleman,dc=local" -w "LdapRead2024!" -b "dc=gentleman,dc=local" >/dev/null 2>&1; then
    echo -e "${GREEN}✅ LDAP connectivity successful${NC}"
else
    echo -e "${YELLOW}⚠️  LDAP connectivity failed - check network/firewall${NC}"
fi

# 11. Create local fallback user
echo -e "${BLUE}👤 Creating local fallback admin...${NC}"
useradd -m -s /bin/bash gentlemanlocal 2>/dev/null || echo "Local user exists"
usermod -aG sudo gentlemanlocal
usermod -aG wheel gentlemanlocal 2>/dev/null || true

echo "gentlemanlocal:GentlemanLocal2024!" | chpasswd

echo ""
echo -e "${GREEN}🎉 RX Node PAM Setup Complete!${NC}"
echo "═══════════════════════════════════════════════════════════════"
echo ""
echo -e "${BLUE}✅ Configured:${NC}"
echo "• LDAP client authentication"
echo "• PAM integration"
echo "• NSS user lookup"
echo "• SSH LDAP support"
echo "• Sudo group permissions"
echo ""
echo -e "${BLUE}🔑 Authentication Methods:${NC}"
echo "• LDAP users: ssh gentleman@rx-node-ip"
echo "• Local fallback: ssh gentlemanlocal@rx-node-ip (password: GentlemanLocal2024!)"
echo ""
echo -e "${YELLOW}📝 Next Steps:${NC}"
echo "1. M1 Control Node detected at: $M1_IP"
echo "   (LDAP services should be accessible)"
echo ""
echo "2. Create LDAP user in Keycloak:"
echo "   - Access: http://${M1_IP}:8085"
echo "   - Username: gentleman"
echo "   - Group: homelab-admins"
echo ""
echo "3. Test authentication:"
echo "   getent passwd gentleman"
echo "   ssh gentleman@localhost"
echo ""
echo -e "${GREEN}🚀 RX Node ready for systemwide authentication!${NC}" 