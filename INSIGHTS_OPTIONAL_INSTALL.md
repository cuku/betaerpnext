# Frappe Insights Installation (Optional)

**Status:** Optional Advanced Feature
**Difficulty:** Advanced
**Requirements:** Working ERPNext v16 installation

---

## Overview

Frappe Insights is a business intelligence tool for creating data visualizations and reports. It's an **optional** add-on for ERPNext.

> ⚠️ **Warning:** Insights installation can be resource-intensive during the build process. This guide provides multiple approaches to handle common issues.

---

## Prerequisites

- Working ERPNext v16 installation
- At least 4GB RAM (8GB recommended)
- 2GB free swap space (will be created if needed)
- PostgreSQL (for data warehouse)

---

## Installation Methods

### Method 1: Standard Installation (Recommended)

This method adds swap space to handle the build process:

```bash
# 1. Create temporary swap space
sudo fallocate -l 2G /swapfile
sudo chmod 600 /swapfile
sudo mkswap /swapfile
sudo swapon /swapfile
free -h  # Verify swap is active

# 2. Install PostgreSQL
sudo apt-get update
sudo apt-get install -y postgresql postgresql-contrib libpq-dev

# 3. Configure PostgreSQL
sudo systemctl enable postgresql
sudo systemctl start postgresql

sudo -u postgres psql << 'EOF'
CREATE USER frappe WITH PASSWORD 'frappe123';
CREATE DATABASE insights_db OWNER frappe;
GRANT ALL PRIVILEGES ON DATABASE insights_db TO frappe;
ALTER USER frappe CREATEDB;
EOF

# 4. Install Insights as frappe user
su - frappe
cd frappe-bench

# Get Insights app
bench get-app insights

# Install on site (skip assets initially)
bench --site erp.local install-app insights --skip-assets

# Build with memory limits
NODE_OPTIONS="--max_old_space_size=2048" bench build --app insights

# Clear cache
bench --site erp.local clear-cache

# Exit frappe user
exit

# 5. Restart services
sudo systemctl restart frappe-bench

# 6. Clean up swap (optional - after successful installation)
sudo swapoff /swapfile
sudo rm /swapfile
```

### Method 2: Pre-built Installation (Fastest)

Skip the build process by using pre-built assets:

```bash
# Install PostgreSQL (as root)
sudo apt-get install -y postgresql postgresql-contrib libpq-dev

sudo -u postgres psql << 'EOF'
CREATE USER frappe WITH PASSWORD 'frappe123';
CREATE DATABASE insights_db OWNER frappe;
GRANT ALL PRIVILEGES ON DATABASE insights_db TO frappe;
ALTER USER frappe CREATEDB;
EOF

# Install Insights without building (as frappe user)
su - frappe
cd frappe-bench

bench get-app insights
bench --site erp.local install-app insights --skip-assets

# Use development mode (no build needed)
bench --site erp.local set-config developer_mode 1

bench --site erp.local clear-cache
exit

sudo systemctl restart frappe-bench
```

### Method 3: Lightweight Installation (Skip Insights)

If you encounter persistent build issues, consider these alternatives:

1. **Use ERPNext Built-in Reports** - ERPNext has powerful reporting tools
2. **Use Report Builder** - Create custom reports without Insights
3. **Install Later** - Wait for system upgrade or Insights improvements
4. **Use Metabase/Redash** - Alternative BI tools that connect to ERPNext database

---

## Configuration

After successful installation:

```bash
su - frappe
cd frappe-bench

# Configure PostgreSQL connection
bench --site erp.local set-config insights_db_host localhost
bench --site erp.local set-config insights_db_port 5432
bench --site erp.local set-config insights_db_name insights_db
bench --site erp.local set-config insights_db_user frappe
bench --site erp.local set-config insights_db_password frappe123

bench --site erp.local clear-cache
exit

sudo systemctl restart frappe-bench
```

---

## Accessing Insights

1. Login to ERPNext: `http://YOUR_IP`
2. Press `Ctrl+K` (or `Cmd+K` on Mac)
3. Type "Insights" and press Enter
4. Start creating data sources and visualizations

---

## Troubleshooting

### Build Process Stuck at 100% CPU

**Symptom:** Vite build hangs with high CPU usage

**Solutions:**

1. **Increase swap space:**
   ```bash
   sudo fallocate -l 4G /swapfile
   sudo chmod 600 /swapfile
   sudo mkswap /swapfile
   sudo swapon /swapfile
   ```

2. **Use development mode (skip build):**
   ```bash
   su - frappe
   cd frappe-bench
   bench --site erp.local set-config developer_mode 1
   bench --site erp.local clear-cache
   ```

3. **Kill stuck process and retry:**
   ```bash
   pkill -f "vite build"
   su - frappe
   cd frappe-bench
   NODE_OPTIONS="--max_old_space_size=4096" bench build --app insights
   ```

### Installation Fails During Asset Build

**Solution:** Use `--skip-assets` flag:

```bash
su - frappe
cd frappe-bench
bench --site erp.local install-app insights --skip-assets
bench --site erp.local set-config developer_mode 1
```

### PostgreSQL Connection Errors

**Check PostgreSQL is running:**

```bash
sudo systemctl status postgresql
sudo systemctl restart postgresql
```

**Test connection:**

```bash
psql -h localhost -U frappe -d insights_db
# Password: frappe123
```

### Cannot Remove Insights App

**If app is installed on site:**

```bash
su - frappe
cd frappe-bench

# Uninstall from site first
bench --site erp.local uninstall-app insights

# Then remove app
bench remove-app insights
```

---

## Uninstallation

To completely remove Insights:

```bash
# 1. Uninstall from site
su - frappe
cd frappe-bench
bench --site erp.local uninstall-app insights

# 2. Remove app
bench remove-app insights

# 3. Drop PostgreSQL database (optional)
exit
sudo -u postgres psql -c "DROP DATABASE IF EXISTS insights_db;"
sudo -u postgres psql -c "DROP USER IF EXISTS frappe;"

# 4. Restart services
sudo systemctl restart frappe-bench
```

---

## Performance Optimization

### For Production Insights Usage

```bash
# Increase PostgreSQL memory
sudo nano /etc/postgresql/*/main/postgresql.conf

# Add/modify:
shared_buffers = 256MB
effective_cache_size = 1GB
work_mem = 16MB

# Restart PostgreSQL
sudo systemctl restart postgresql
```

### Regular Maintenance

```bash
su - frappe
cd frappe-bench

# Update Insights
bench update --app insights

# Rebuild if needed
bench build --app insights

# Clear cache
bench --site erp.local clear-cache
```

---

## When NOT to Install Insights

Skip Insights if:

- **Limited Resources:** Less than 4GB RAM or 2 CPU cores
- **Simple Reporting Needs:** ERPNext built-in reports are sufficient
- **Build Issues Persist:** After multiple failed attempts
- **Learning Phase:** First-time ERPNext users
- **Production Critical:** Can't risk stability issues

**Alternative:** Use ERPNext's powerful Report Builder instead:
- Navigate to any DocType
- Click "Menu" → "Customize"
- Use "Report Builder" for custom reports
- No additional installation needed

---

## Resources

- **Insights Documentation:** https://frappe.io/insights
- **GitHub Repository:** https://github.com/frappe/insights
- **Community Support:** https://discuss.frappe.io/
- **Report Builder Guide:** https://docs.erpnext.com/docs/user/manual/en/customize-erpnext/articles/making-custom-reports

---

## Summary

**✅ Install Insights if:**
- You need advanced BI features
- Have sufficient resources (8GB+ RAM)
- Comfortable troubleshooting build issues

**❌ Skip Insights if:**
- Resource-constrained environment
- Simple reporting needs
- First-time ERPNext deployment
- Build process fails repeatedly

**Alternative:** ERPNext's built-in reporting tools are powerful enough for most use cases.

---

**Document Version:** 1.0
**Last Updated:** February 6, 2026
