# ERPNext v16 Production Installation Guide

**Version:** ERPNext v16 (Latest)
**Tested On:** Ubuntu 22.04 LTS (LXC Container)
**Installation Time:** ~30 minutes
**Architecture:** Systemd + Nginx (Production-Ready)

---

## Overview

This guide provides a streamlined, production-ready installation of ERPNext v16 using a proven architecture that avoids common pitfalls:

- ✅ **ERPNext v16 Latest** - Latest version with newest features
- ✅ **Systemd Process Management** - No supervisor complications
- ✅ **Nginx Reverse Proxy** - Production-grade web serving
- ✅ **MariaDB with Native Auth** - Reliable database authentication
- ✅ **Development Mode + Production Proxy** - Best of both worlds

---

## Prerequisites

### Container Specifications

- **OS:** Ubuntu 22.04 LTS
- **CPU:** 2 cores minimum (4 recommended)
- **RAM:** 4GB minimum (8GB recommended)
- **Storage:** 30GB minimum (50GB+ recommended)
- **Network:** Public IP or domain name
- **Features:** `nesting=1` (for LXC containers)

---

## Quick Installation

### Option 1: One-Command Installation

```bash
curl -fsSL https://raw.githubusercontent.com/your-repo/betaerpnext/main/install-erpnext-v16.sh | sudo bash
```

### Option 2: Manual Step-by-Step

Follow the complete installation steps below.

---

## Complete Installation Steps

### 1. System Preparation

```bash
# Update system
apt-get update && apt-get upgrade -y

# Install essential dependencies
apt-get install -y git curl wget vim htop build-essential \
    python3-dev python3-pip python3-setuptools python3-venv \
    software-properties-common libssl-dev libffi-dev \
    libmysqlclient-dev libjpeg-dev libpng-dev libwebp-dev \
    fontconfig xfonts-75dpi xfonts-base libxrender1 libxext6
```

### 2. Install Python 3.11

```bash
# Add Python repository
add-apt-repository ppa:deadsnakes/ppa -y
apt-get update

# Install Python 3.11
apt-get install -y python3.11 python3.11-dev python3.11-venv

# Set as default
update-alternatives --install /usr/bin/python3 python3 /usr/bin/python3.11 2
update-alternatives --set python3 /usr/bin/python3.11

# Verify
python3 --version  # Should show Python 3.11.x
```

### 3. Install MariaDB

```bash
# Install MariaDB
apt-get install -y mariadb-server mariadb-client

# Configure for ERPNext
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

# Restart MariaDB
systemctl restart mariadb
systemctl enable mariadb

# Secure installation
mysql_secure_installation
# Set root password: Pelusa411! (or your choice)
# Answer Y to all security questions
```

### 4. Install Redis

```bash
# Install Redis
apt-get install -y redis-server

# Configure
sed -i 's/^supervised no/supervised systemd/' /etc/redis/redis.conf

# Start Redis
systemctl start redis-server
systemctl enable redis-server

# Test
redis-cli ping  # Should return PONG
```

### 5. Install Node.js 18.x & Yarn

```bash
# Add Node.js repository
curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key | \
    gpg --dearmor -o /usr/share/keyrings/nodesource.gpg

echo "deb [signed-by=/usr/share/keyrings/nodesource.gpg] https://deb.nodesource.com/node_18.x nodistro main" | \
    tee /etc/apt/sources.list.d/nodesource.list

# Install Node.js
apt-get update
apt-get install -y nodejs

# Install Yarn
npm install -g yarn

# Verify
node --version   # v18.x.x
yarn --version   # 1.22.x
```

### 6. Install wkhtmltopdf

```bash
cd /tmp
wget https://github.com/wkhtmltopdf/packaging/releases/download/0.12.6.1-2/wkhtmltox_0.12.6.1-2.jammy_amd64.deb
apt-get install -y ./wkhtmltox_0.12.6.1-2.jammy_amd64.deb
rm wkhtmltox_0.12.6.1-2.jammy_amd64.deb
```

### 7. Create Frappe User

```bash
# Create user
useradd -m -s /bin/bash frappe
echo "frappe:frappe" | chpasswd

# Add to sudo with no password (for bench operations)
usermod -aG sudo frappe
echo "frappe ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/frappe
chmod 440 /etc/sudoers.d/frappe

# Create MariaDB user
mysql -u root -p'Pelusa411!' << 'EOF'
CREATE USER 'frappe'@'localhost' IDENTIFIED VIA mysql_native_password USING PASSWORD('Pelusa411!');
GRANT ALL PRIVILEGES ON *.* TO 'frappe'@'localhost' WITH GRANT OPTION;
FLUSH PRIVILEGES;
EOF
```

### 8. Install Frappe Bench & Initialize

```bash
# Switch to frappe user
su - frappe

# Install bench
pip3 install frappe-bench

# Add to PATH
echo 'export PATH=$PATH:~/.local/bin' >> ~/.bashrc
source ~/.bashrc

# IMPORTANT: Hide supervisor to avoid pkg_resources error
sudo mv /usr/bin/supervisorctl /usr/bin/supervisorctl.disabled 2>/dev/null || true

# Initialize bench with ERPNext v16
bench init frappe-bench \
    --frappe-branch version-16 \
    --python python3.11

# Restore supervisor
sudo mv /usr/bin/supervisorctl.disabled /usr/bin/supervisorctl 2>/dev/null || true

cd frappe-bench
```

### 9. Get ERPNext & Create Site

```bash
# Still as frappe user in frappe-bench directory

# Get ERPNext v16
bench get-app erpnext --branch version-16

# Create site
bench new-site erp.local \
    --mariadb-root-password 'Pelusa411!' \
    --admin-password 'Admin@2025!'

# Install ERPNext
bench --site erp.local install-app erpnext

# Verify
bench version --format table
```

### 10. Configure Systemd Service

```bash
# Exit frappe user
exit

# Create systemd service
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

# Enable and start service
systemctl daemon-reload
systemctl enable frappe-bench
systemctl start frappe-bench

# Check status
systemctl status frappe-bench
```

### 11. Install & Configure Nginx

```bash
# Install Nginx
apt-get install -y nginx

# Get server IP
SERVER_IP=$(hostname -I | awk '{print $1}')

# Create Nginx configuration
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

# Enable site
ln -sf /etc/nginx/sites-available/erpnext /etc/nginx/sites-enabled/
rm -f /etc/nginx/sites-enabled/default

# Test and reload
nginx -t && systemctl reload nginx
```

### 12. Verify Installation

```bash
# Check all services
systemctl status frappe-bench
systemctl status nginx
systemctl status mariadb
systemctl status redis-server

# Test web access
SERVER_IP=$(hostname -I | awk '{print $1}')
curl -I http://${SERVER_IP}

echo ""
echo "=========================================="
echo "   ERPNext Installation Complete!"
echo "=========================================="
echo ""
echo "Access ERPNext at: http://${SERVER_IP}"
echo "Username: Administrator"
echo "Password: Admin@2025!"
echo ""
echo "=========================================="
```

---

## Post-Installation

### Security Checklist

1. **Change Administrator Password**
   ```bash
   su - frappe
   cd frappe-bench
   bench set-admin-password erp.local
   ```

2. **Setup Firewall**
   ```bash
   ufw allow 22/tcp
   ufw allow 80/tcp
   ufw allow 443/tcp
   ufw enable
   ```

3. **Configure SSL (if you have a domain)**
   ```bash
   apt-get install -y certbot python3-certbot-nginx
   certbot --nginx -d yourdomain.com
   ```

### Automated Backups

```bash
# Add to frappe user's crontab
su - frappe
crontab -e

# Add this line (daily backup at 2 AM):
0 2 * * * cd /home/frappe/frappe-bench && /home/frappe/.local/bin/bench --site erp.local backup --with-files
```

---

## Maintenance

### Daily Operations

```bash
# View logs
sudo journalctl -u frappe-bench -f

# Restart service
sudo systemctl restart frappe-bench

# Check status
sudo systemctl status frappe-bench
```

### Updates

```bash
su - frappe
cd frappe-bench

# Backup first!
bench --site erp.local backup --with-files

# Update
bench update --patch

# Or full update
bench update
```

### Manual Backup & Restore

```bash
su - frappe
cd frappe-bench

# Create backup
bench --site erp.local backup --with-files

# List backups
ls -lh sites/erp.local/private/backups/

# Restore
bench --site erp.local restore /path/to/backup.sql.gz
```

---

## Troubleshooting

### Service Not Starting

```bash
# Check logs
sudo journalctl -u frappe-bench -n 50 --no-pager

# Check bench manually
su - frappe
cd frappe-bench
bench start
# Press Ctrl+C to stop, then restart service
exit
sudo systemctl restart frappe-bench
```

### Nginx Issues

```bash
# Test configuration
nginx -t

# Check logs
tail -f /var/log/nginx/error.log

# Restart
systemctl restart nginx
```

### Database Issues

```bash
su - frappe
cd frappe-bench

# Run migrations
bench --site erp.local migrate

# Clear cache
bench --site erp.local clear-cache

# Rebuild
bench build --app erpnext
```

### Permission Issues

```bash
# Fix permissions
chown -R frappe:frappe /home/frappe/frappe-bench
chmod -R 755 /home/frappe/frappe-bench

# Restart
sudo systemctl restart frappe-bench
```

---

## Architecture Details

### Why This Approach Works

1. **ERPNext v15 Stable** - Proven, production-ready version
2. **Systemd Management** - Native Linux service management, no supervisor complexity
3. **Development Mode** - Easier debugging and auto-reload
4. **Nginx Reverse Proxy** - Production-grade web serving with proper headers
5. **Host Header Forwarding** - Critical for multi-tenant routing

### Service Flow

```
Internet → Nginx (Port 80) → Bench (Port 8000) → ERPNext
                              ↓
                         MariaDB (Port 3306)
                              ↓
                         Redis (Port 6379)
```

---

## Important File Locations

- **Bench Directory:** `/home/frappe/frappe-bench/`
- **Site Config:** `/home/frappe/frappe-bench/sites/erp.local/site_config.json`
- **Nginx Config:** `/etc/nginx/sites-available/erpnext`
- **Systemd Service:** `/etc/systemd/system/frappe-bench.service`
- **Backups:** `/home/frappe/frappe-bench/sites/erp.local/private/backups/`
- **Logs:** `journalctl -u frappe-bench`

---

## Useful Commands

```bash
# Service management
sudo systemctl start frappe-bench
sudo systemctl stop frappe-bench
sudo systemctl restart frappe-bench
sudo systemctl status frappe-bench

# View logs
sudo journalctl -u frappe-bench -f
sudo journalctl -u frappe-bench -n 100 --no-pager

# Bench commands (as frappe user)
su - frappe
cd frappe-bench
bench --site erp.local migrate
bench --site erp.local clear-cache
bench --site erp.local backup --with-files
bench build --app erpnext
bench version --format table
```

---

## Version Information

- **Ubuntu:** 22.04 LTS
- **Python:** 3.11
- **Node.js:** 18.x
- **MariaDB:** 10.6+
- **Redis:** 6.0+
- **Nginx:** 1.18+
- **Frappe:** 16.x (version-16 branch)
- **ERPNext:** 16.x (version-16 branch)

---

## Support Resources

- **Official Docs:** https://docs.erpnext.com/
- **Frappe Framework:** https://frappeframework.com/docs/
- **Community Forum:** https://discuss.frappe.io/
- **GitHub:** https://github.com/frappe/erpnext

---

**Last Updated:** February 6, 2026
**Document Version:** 4.0 (Production-Ready - ERPNext v16)
