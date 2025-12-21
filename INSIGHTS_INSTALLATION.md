# Frappe Insights Installation Guide

## Overview

This script installs Frappe Insights (Business Intelligence tool) alongside your existing ERPNext installation.

## Prerequisites

- ERPNext must already be installed on the server
- Site `erp.local` must exist
- Root or sudo access required

## What Gets Installed

- **PostgreSQL**: Database for Insights data warehouse
- **Frappe Insights**: Business Intelligence and Analytics app
- **Dependencies**: Required Python packages and libraries

## Installation

### Quick Install

Run this command as root:

```bash
sudo bash install-frappe-insights.sh
```

### Step-by-Step Process

The script will:

1. Install PostgreSQL database server
2. Create database and user for Insights
3. Download Frappe Insights app
4. Install Insights on your ERPNext site
5. Configure database connections
6. Restart services
7. Build frontend assets

Installation takes approximately 5-10 minutes.

## Post-Installation

### Accessing Insights

1. Login to ERPNext at `http://<server-ip>`
2. Use the Awesome Bar (Ctrl+K or Cmd+K)
3. Type "Insights" and select it
4. Start creating queries and dashboards!

### Database Connection

Insights uses PostgreSQL for its data warehouse:

- **Host**: localhost
- **Port**: 5432
- **Database**: insights_db
- **User**: frappe
- **Password**: frappe123

**⚠️ Security Note**: Change the default PostgreSQL password in production:

```bash
sudo -u postgres psql
\password frappe
```

Then update the site config:
```bash
su - frappe
cd ~/frappe-bench
bench --site erp.local set-config insights_db_password "new-password"
```

## Features

Frappe Insights provides:

- ✅ Visual query builder
- ✅ Interactive dashboards
- ✅ Custom reports
- ✅ Data exploration
- ✅ Chart builder
- ✅ Scheduled reports
- ✅ Share dashboards
- ✅ Export data

## Management Commands

### Update Insights

```bash
su - frappe
cd ~/frappe-bench
bench update --app insights
```

### Restart Services

```bash
sudo systemctl restart frappe-bench
```

### View Logs

```bash
sudo journalctl -u frappe-bench -f
```

### Check PostgreSQL Status

```bash
sudo systemctl status postgresql
```

### Access PostgreSQL Console

```bash
sudo -u postgres psql insights_db
```

## Troubleshooting

### Insights not showing in ERPNext

```bash
# Verify app is installed
su - frappe -c "cd ~/frappe-bench && bench --site erp.local list-apps"

# Rebuild assets
su - frappe -c "cd ~/frappe-bench && bench build --app insights"

# Clear cache
su - frappe -c "cd ~/frappe-bench && bench --site erp.local clear-cache"

# Restart
sudo systemctl restart frappe-bench
```

### PostgreSQL connection errors

```bash
# Check PostgreSQL is running
sudo systemctl status postgresql

# Restart PostgreSQL
sudo systemctl restart postgresql

# Check logs
sudo journalctl -u postgresql -n 50
```

### Permission errors

```bash
# Fix PostgreSQL permissions
sudo -u postgres psql insights_db
GRANT ALL PRIVILEGES ON DATABASE insights_db TO frappe;
ALTER USER frappe CREATEDB;
```

## Uninstalling Insights

If you need to remove Insights:

```bash
su - frappe
cd ~/frappe-bench

# Uninstall from site
bench --site erp.local uninstall-app insights

# Remove app
bench remove-app insights

# Optionally remove PostgreSQL database
sudo -u postgres psql -c "DROP DATABASE insights_db;"
```

## Resources

- [Frappe Insights Documentation](https://docs.frappe.io/insights)
- [Frappe Insights GitHub](https://github.com/frappe/insights)
- [ERPNext Forum](https://discuss.erpnext.com)

## Support

For issues:
1. Check the [Troubleshooting](#troubleshooting) section above
2. Review logs: `sudo journalctl -u frappe-bench -f`
3. Visit [Frappe Forum](https://discuss.frappe.io)

---

**Note**: This script is designed to work with the Easy ERPNext installation. If you used a different installation method, you may need to adjust paths and configurations.
