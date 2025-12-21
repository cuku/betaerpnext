#!/bin/bash

# Frappe Insights Installation Script
# Installs Frappe Insights alongside existing ERPNext installation

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

print_status() { echo -e "${GREEN}[✓] $1${NC}"; }
print_error() { echo -e "${RED}[✗] $1${NC}"; exit 1; }
print_info() { echo -e "${YELLOW}[→] $1${NC}"; }

echo "=========================================="
echo "Frappe Insights Installation Script"
echo "=========================================="
echo ""

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    print_error "Please run as root (use sudo)"
fi

# Check if frappe-bench exists
if [ ! -d "/home/frappe/frappe-bench" ]; then
    print_error "Frappe bench not found. Please install ERPNext first."
fi

# Check if site exists
if [ ! -d "/home/frappe/frappe-bench/sites/erp.local" ]; then
    print_error "Site 'erp.local' not found. Please create a site first."
fi

print_info "Step 1: Installing system dependencies for Insights..."
apt-get update
apt-get install -y postgresql postgresql-contrib libpq-dev

# Setup PostgreSQL
print_info "Step 2: Setting up PostgreSQL..."
systemctl enable postgresql
systemctl start postgresql

# Create PostgreSQL user and database for Insights
print_info "Step 3: Creating PostgreSQL database for Insights..."
sudo -u postgres psql <<EOF
-- Create user if not exists
DO \$\$
BEGIN
    IF NOT EXISTS (SELECT FROM pg_catalog.pg_user WHERE usename = 'frappe') THEN
        CREATE USER frappe WITH PASSWORD 'frappe123';
    END IF;
END
\$\$;

-- Create database if not exists
SELECT 'CREATE DATABASE insights_db OWNER frappe'
WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = 'insights_db')\gexec

-- Grant privileges
GRANT ALL PRIVILEGES ON DATABASE insights_db TO frappe;
ALTER USER frappe CREATEDB;
EOF

print_status "PostgreSQL configured"

# Install Insights app
print_info "Step 4: Installing Frappe Insights app..."
su - frappe <<'FRAPPE_INSTALL'
cd ~/frappe-bench

# Get Insights app from GitHub
bench get-app insights

# Install Insights on the site
bench --site erp.local install-app insights

# Run migrations
bench --site erp.local migrate

# Clear cache
bench --site erp.local clear-cache

# Build assets
bench build --app insights
FRAPPE_INSTALL

print_status "Frappe Insights installed"

# Configure Insights to use PostgreSQL
print_info "Step 5: Configuring Insights database connection..."
su - frappe <<'FRAPPE_CONFIG'
cd ~/frappe-bench

# Add PostgreSQL connection to site_config.json
bench --site erp.local set-config insights_db_host localhost
bench --site erp.local set-config insights_db_port 5432
bench --site erp.local set-config insights_db_name insights_db
bench --site erp.local set-config insights_db_user frappe
bench --site erp.local set-config insights_db_password frappe123
FRAPPE_CONFIG

print_status "Database connection configured"

# Restart services
print_info "Step 6: Restarting services..."
systemctl restart frappe-bench

# Wait for services to start
sleep 10

print_info "Step 7: Verifying installation..."
su - frappe -c "cd ~/frappe-bench && bench --site erp.local list-apps"

# Get server IP
SERVER_IP=$(hostname -I | awk '{print $1}')

echo ""
echo "=========================================="
echo "Frappe Insights Installation Complete!"
echo "=========================================="
echo ""
echo "Access Information:"
echo "  URL: http://${SERVER_IP}"
echo "  Username: Administrator"
echo "  Password: admin"
echo ""
echo "Frappe Insights is now available in your ERPNext installation!"
echo ""
echo "To access Insights:"
echo "  1. Login to ERPNext"
echo "  2. Go to the Awesome Bar (Ctrl+K or Cmd+K)"
echo "  3. Type 'Insights' and select it"
echo ""
echo "PostgreSQL Database:"
echo "  Host: localhost"
echo "  Port: 5432"
echo "  Database: insights_db"
echo "  User: frappe"
echo "  Password: frappe123"
echo ""
echo "Useful Commands:"
echo "  Restart services: sudo systemctl restart frappe-bench"
echo "  View logs: sudo journalctl -u frappe-bench -f"
echo "  Update Insights: su - frappe -c 'cd ~/frappe-bench && bench update --app insights'"
echo ""
echo "=========================================="
