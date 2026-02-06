#!/bin/bash

#######################################
# ERPNext v16 Production Installation
# Ubuntu 22.04 LTS
# Architecture: Systemd + Nginx
#######################################

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Functions
print_header() {
    echo ""
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}  $1${NC}"
    echo -e "${BLUE}========================================${NC}"
    echo ""
}

print_status() { echo -e "${GREEN}[✓]${NC} $1"; }
print_error() { echo -e "${RED}[✗]${NC} $1"; exit 1; }
print_info() { echo -e "${YELLOW}[→]${NC} $1"; }

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    print_error "Please run as root (use: sudo bash $0)"
fi

# Verify Ubuntu 22.04
if ! grep -q "22.04" /etc/os-release; then
    print_error "This script requires Ubuntu 22.04 LTS"
fi

print_header "ERPNext v16 Production Installation"
echo "This will install:"
echo "  • Python 3.11"
echo "  • MariaDB 10.6+"
echo "  • Redis"
echo "  • Node.js 18.x"
echo "  • Frappe Framework v16"
echo "  • ERPNext v16"
echo "  • Nginx (reverse proxy)"
echo "  • Systemd service"
echo ""
read -p "Continue? (y/n) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    exit 1
fi

# Get passwords
print_info "Setting up credentials..."
MYSQL_ROOT_PASSWORD=${MYSQL_ROOT_PASSWORD:-"Pelusa411!"}
ADMIN_PASSWORD=${ADMIN_PASSWORD:-"Admin@2025!"}

print_header "Step 1: System Preparation"
print_info "Updating system packages..."
export DEBIAN_FRONTEND=noninteractive
apt-get update -qq
apt-get upgrade -y -qq

print_info "Installing dependencies..."
apt-get install -y -qq \
    git curl wget vim htop build-essential \
    python3-dev python3-pip python3-setuptools python3-venv \
    software-properties-common libssl-dev libffi-dev \
    libmysqlclient-dev libjpeg-dev libpng-dev libwebp-dev \
    fontconfig xfonts-75dpi xfonts-base libxrender1 libxext6 \
    gnupg2 ca-certificates lsb-release

print_status "System prepared"

print_header "Step 2: Installing Python 3.11"
add-apt-repository ppa:deadsnakes/ppa -y
apt-get update -qq
apt-get install -y -qq python3.11 python3.11-dev python3.11-venv

update-alternatives --install /usr/bin/python3 python3 /usr/bin/python3.11 2
update-alternatives --set python3 /usr/bin/python3.11

PYTHON_VERSION=$(python3 --version)
print_status "Python installed: $PYTHON_VERSION"

print_header "Step 3: Installing MariaDB"
apt-get install -y -qq mariadb-server mariadb-client

cat > /etc/mysql/mariadb.conf.d/erpnext.cnf << 'EOF'
[mysqld]
character-set-client-handshake = FALSE
character-set-server = utf8mb4
collation-server = utf8mb4_unicode_ci

innodb_buffer_pool_size = 1G
innodb_log_file_size = 512M
innodb_file_per_table = 1

max_connections = 200
max_allowed_packet = 256M

binlog_format = row

[mysql]
default-character-set = utf8mb4
EOF

systemctl restart mariadb
systemctl enable mariadb

# Secure MariaDB non-interactively
mysql -e "ALTER USER 'root'@'localhost' IDENTIFIED VIA mysql_native_password USING PASSWORD('${MYSQL_ROOT_PASSWORD}');"
mysql -u root -p"${MYSQL_ROOT_PASSWORD}" -e "DELETE FROM mysql.user WHERE User='';"
mysql -u root -p"${MYSQL_ROOT_PASSWORD}" -e "DELETE FROM mysql.user WHERE User='root' AND Host NOT IN ('localhost', '127.0.0.1', '::1');"
mysql -u root -p"${MYSQL_ROOT_PASSWORD}" -e "DROP DATABASE IF EXISTS test;"
mysql -u root -p"${MYSQL_ROOT_PASSWORD}" -e "DELETE FROM mysql.db WHERE Db='test' OR Db='test\\_%';"
mysql -u root -p"${MYSQL_ROOT_PASSWORD}" -e "FLUSH PRIVILEGES;"

print_status "MariaDB installed and secured"

print_header "Step 4: Installing Redis"
apt-get install -y -qq redis-server

sed -i 's/^supervised no/supervised systemd/' /etc/redis/redis.conf

systemctl start redis-server
systemctl enable redis-server

REDIS_STATUS=$(redis-cli ping)
print_status "Redis installed: $REDIS_STATUS"

print_header "Step 5: Installing Node.js 18.x"
curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key | \
    gpg --dearmor -o /usr/share/keyrings/nodesource.gpg

echo "deb [signed-by=/usr/share/keyrings/nodesource.gpg] https://deb.nodesource.com/node_18.x nodistro main" | \
    tee /etc/apt/sources.list.d/nodesource.list

apt-get update -qq
apt-get install -y -qq nodejs

npm install -g yarn --silent

NODE_VERSION=$(node --version)
YARN_VERSION=$(yarn --version)
print_status "Node.js installed: $NODE_VERSION"
print_status "Yarn installed: $YARN_VERSION"

print_header "Step 6: Installing wkhtmltopdf"
cd /tmp
wget -q https://github.com/wkhtmltopdf/packaging/releases/download/0.12.6.1-2/wkhtmltox_0.12.6.1-2.jammy_amd64.deb
apt-get install -y -qq ./wkhtmltox_0.12.6.1-2.jammy_amd64.deb
rm -f wkhtmltox_0.12.6.1-2.jammy_amd64.deb
print_status "wkhtmltopdf installed"

print_header "Step 7: Creating Frappe User"
if id "frappe" &>/dev/null; then
    print_info "Frappe user already exists"
else
    useradd -m -s /bin/bash frappe
    echo "frappe:frappe" | chpasswd
    usermod -aG sudo frappe
    echo "frappe ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/frappe
    chmod 440 /etc/sudoers.d/frappe
    print_status "Frappe user created"
fi

# Create MariaDB user
mysql -u root -p"${MYSQL_ROOT_PASSWORD}" << EOF
DROP USER IF EXISTS 'frappe'@'localhost';
CREATE USER 'frappe'@'localhost' IDENTIFIED VIA mysql_native_password USING PASSWORD('${MYSQL_ROOT_PASSWORD}');
GRANT ALL PRIVILEGES ON *.* TO 'frappe'@'localhost' WITH GRANT OPTION;
FLUSH PRIVILEGES;
EOF

print_status "MariaDB user configured"

print_header "Step 8: Installing Frappe Bench"
su - frappe << 'EOF'
pip3 install frappe-bench --quiet
echo 'export PATH=$PATH:~/.local/bin' >> ~/.bashrc
source ~/.bashrc
EOF

print_status "Frappe Bench installed"

print_header "Step 9: Initializing Bench"
print_info "This may take 5-10 minutes..."

# Hide supervisor to avoid pkg_resources error
mv /usr/bin/supervisorctl /usr/bin/supervisorctl.disabled 2>/dev/null || true

su - frappe << EOF
export PATH=\$PATH:~/.local/bin
bench init frappe-bench \
    --frappe-branch version-16 \
    --python python3.11 \
    --verbose
EOF

# Restore supervisor
mv /usr/bin/supervisorctl.disabled /usr/bin/supervisorctl 2>/dev/null || true

print_status "Bench initialized"

print_header "Step 10: Getting ERPNext"
print_info "Downloading ERPNext v16..."

su - frappe << 'EOF'
export PATH=$PATH:~/.local/bin
cd frappe-bench
bench get-app erpnext --branch version-16
EOF

print_status "ERPNext downloaded"

print_header "Step 11: Creating Site"
su - frappe << EOF
export PATH=\$PATH:~/.local/bin
cd frappe-bench
bench new-site erp.local \
    --mariadb-root-password '${MYSQL_ROOT_PASSWORD}' \
    --admin-password '${ADMIN_PASSWORD}'
EOF

print_status "Site created: erp.local"

print_header "Step 12: Installing ERPNext"
print_info "This may take 5-10 minutes..."

su - frappe << 'EOF'
export PATH=$PATH:~/.local/bin
cd frappe-bench
bench --site erp.local install-app erpnext
bench --site erp.local clear-cache
EOF

print_status "ERPNext installed"

print_header "Step 13: Setting up Systemd Service"
cat > /etc/systemd/system/frappe-bench.service << 'EOF'
[Unit]
Description=Frappe Bench
After=network.target mariadb.service redis-server.service

[Service]
Type=simple
User=frappe
Group=frappe
WorkingDirectory=/home/frappe/frappe-bench
Environment="PATH=/home/frappe/.local/bin:/usr/local/bin:/usr/bin:/bin"
ExecStart=/home/frappe/.local/bin/bench start
Restart=always
RestartSec=10
StandardOutput=journal
StandardError=journal
SyslogIdentifier=frappe-bench

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable frappe-bench
systemctl start frappe-bench

sleep 5

if systemctl is-active --quiet frappe-bench; then
    print_status "Frappe service started"
else
    print_error "Frappe service failed to start. Check: journalctl -u frappe-bench -n 50"
fi

print_header "Step 14: Installing Nginx"
apt-get install -y -qq nginx

SERVER_IP=$(hostname -I | awk '{print $1}')

cat > /etc/nginx/sites-available/erpnext << EOF
upstream frappe-bench {
    server 127.0.0.1:8000 fail_timeout=0;
}

server {
    listen 80;
    server_name ${SERVER_IP} erp.local _;

    root /home/frappe/frappe-bench/sites;

    location /assets {
        try_files \$uri =404;
    }

    location /files {
        try_files \$uri =404;
    }

    location / {
        proxy_pass http://frappe-bench;
        proxy_set_header Host erp.local;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_redirect off;

        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
    }
}
EOF

ln -sf /etc/nginx/sites-available/erpnext /etc/nginx/sites-enabled/
rm -f /etc/nginx/sites-enabled/default

nginx -t && systemctl reload nginx

print_status "Nginx configured"

print_header "Step 15: Final Verification"
sleep 3

HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" http://localhost)

if [ "$HTTP_STATUS" = "200" ] || [ "$HTTP_STATUS" = "303" ]; then
    print_status "Web server responding"
else
    print_error "Web server not responding properly (HTTP $HTTP_STATUS)"
fi

print_header "Installation Complete!"
cat << EOF

${GREEN}✓ ERPNext v16 has been successfully installed!${NC}

Access Information:
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  URL:      http://${SERVER_IP}
  Username: Administrator
  Password: ${ADMIN_PASSWORD}
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Service Management:
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  Status:   sudo systemctl status frappe-bench
  Restart:  sudo systemctl restart frappe-bench
  Logs:     sudo journalctl -u frappe-bench -f
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Bench Commands (as frappe user):
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  su - frappe
  cd frappe-bench
  bench --site erp.local backup --with-files
  bench --site erp.local migrate
  bench --site erp.local clear-cache
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

${YELLOW}Next Steps:${NC}
1. Change Administrator password
2. Complete setup wizard
3. Configure automated backups
4. Setup SSL/HTTPS (if you have a domain)

${BLUE}Documentation: /home/user/betaerpnext/PRODUCTION_INSTALL_GUIDE.md${NC}

EOF
