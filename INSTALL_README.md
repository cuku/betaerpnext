# ERPNext Production Installation for LXC/CT

Production-ready ERPNext v16 installation guide and automated installer for Ubuntu 22.04 LTS containers.

[![ERPNext](https://img.shields.io/badge/ERPNext-v16-blue.svg)](https://erpnext.com)
[![Ubuntu](https://img.shields.io/badge/Ubuntu-22.04%20LTS-orange.svg)](https://ubuntu.com)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)
[![Architecture](https://img.shields.io/badge/Architecture-Systemd%20%2B%20Nginx-brightgreen.svg)]()

---

## 🎯 Overview

This repository provides a **battle-tested**, **production-ready** approach to installing ERPNext v16 on Ubuntu 22.04 LTS containers (Proxmox LXC/CT or similar).

### Why This Installation Method?

After extensive testing and troubleshooting, this method emerged as the most reliable:

- ✅ **ERPNext v16 Latest** - Latest stable version with newest features
- ✅ **Systemd Process Management** - No supervisor pkg_resources issues
- ✅ **Nginx Reverse Proxy** - Production-grade web serving
- ✅ **Development Mode + Production Proxy** - Best of both worlds
- ✅ **MariaDB Native Auth** - Reliable database authentication
- ✅ **30-Minute Installation** - Fully automated

---

## 🚀 Quick Start

### Automated Installation

```bash
# Download and run installer
curl -fsSL https://raw.githubusercontent.com/cuku/betaerpnext/claude/review-ct-installation-loT79/install-erpnext-v16.sh -o install-erpnext-v16.sh
sudo bash install-erpnext-v16.sh
```

### Manual Installation

Follow the comprehensive guide: [PRODUCTION_INSTALL_GUIDE.md](PRODUCTION_INSTALL_GUIDE.md)

---

## 📋 System Requirements

### Minimum Specifications

- **OS:** Ubuntu 22.04 LTS
- **CPU:** 2 cores
- **RAM:** 4GB
- **Storage:** 30GB
- **Network:** Public IP or domain

### Recommended Specifications

- **CPU:** 4 cores
- **RAM:** 8GB
- **Storage:** 50GB+
- **Features:** LXC nesting=1 (if using containers)

---

## 📁 Installation Files

| File | Description |
|------|-------------|
| **PRODUCTION_INSTALL_GUIDE.md** | Complete step-by-step installation guide |
| **install-erpnext-v16.sh** | Automated installation script |
| **INSIGHTS_OPTIONAL_INSTALL.md** | Optional Insights BI tool guide |
| **CT_INSTALLATION_ANALYSIS.md** | Initial project analysis |
| **CT_INSTALLATION_COMPLETE_GUIDE.md** | Legacy guide (v16) |

---

## 🏗️ Architecture

### System Architecture

```
Internet
   ↓
Nginx (Port 80/443)
   ↓
Bench Dev Server (Port 8000)
   ↓
ERPNext Application
   ↓
├── MariaDB (Port 3306) - Database
└── Redis (Port 6379) - Cache/Queue
```

### Key Components

| Component | Version | Purpose |
|-----------|---------|---------|
| Ubuntu | 22.04 LTS | Operating System |
| Python | 3.11 | Runtime |
| Node.js | 18.x | Frontend Build |
| MariaDB | 10.6+ | Database |
| Redis | 6.0+ | Cache & Queue |
| Nginx | 1.18+ | Reverse Proxy |
| Systemd | - | Process Manager |
| Frappe | v16 | Framework |
| ERPNext | v16 | ERP Application |

---

## 📖 Installation Options

### Option 1: Automated (Recommended)

**File:** [install-erpnext-v16.sh](install-erpnext-v16.sh)

One-command installation:
```bash
sudo bash install-erpnext-v16.sh
```

**Features:**
- ✅ 30-minute installation
- ✅ All dependencies included
- ✅ Production-ready configuration
- ✅ Automatic service setup
- ✅ Error handling

### Option 2: Manual Step-by-Step

**File:** [PRODUCTION_INSTALL_GUIDE.md](PRODUCTION_INSTALL_GUIDE.md)

Complete guide with:
- Detailed explanations
- System preparation
- Service configuration
- Security hardening
- Troubleshooting

### Option 3: Optional Add-ons

**File:** [INSIGHTS_OPTIONAL_INSTALL.md](INSIGHTS_OPTIONAL_INSTALL.md)

Business Intelligence add-on:
- Multiple installation methods
- Resource requirements
- Troubleshooting
- Alternatives

---

## 🔧 Post-Installation

### Access ERPNext

```
URL:      http://YOUR_SERVER_IP
Username: Administrator
Password: Admin@2025!
```

### Essential Commands

```bash
# Service management
sudo systemctl status frappe-bench
sudo systemctl restart frappe-bench
sudo journalctl -u frappe-bench -f

# Bench operations (as frappe user)
su - frappe
cd frappe-bench
bench --site erp.local migrate
bench --site erp.local backup --with-files
bench --site erp.local clear-cache
```

### Security Checklist

1. ✅ Change Administrator password
2. ✅ Setup firewall (UFW)
3. ✅ Configure SSL/HTTPS
4. ✅ Setup automated backups
5. ✅ Disable root SSH login

---

## 🛠️ Troubleshooting

### Service Issues

```bash
# Check service status
sudo systemctl status frappe-bench

# View recent logs
sudo journalctl -u frappe-bench -n 100 --no-pager

# Restart service
sudo systemctl restart frappe-bench
```

### Database Issues

```bash
su - frappe
cd frappe-bench

# Run migrations
bench --site erp.local migrate

# Clear cache
bench --site erp.local clear-cache

# Rebuild assets
bench build --app erpnext
```

### Permission Issues

```bash
# Fix bench permissions
sudo chown -R frappe:frappe /home/frappe/frappe-bench
sudo chmod -R 755 /home/frappe/frappe-bench

# Restart service
sudo systemctl restart frappe-bench
```

See [PRODUCTION_INSTALL_GUIDE.md](PRODUCTION_INSTALL_GUIDE.md#troubleshooting) for complete troubleshooting guide.

---

## 🔄 Updates & Maintenance

### Update ERPNext

```bash
su - frappe
cd frappe-bench

# Backup first!
bench --site erp.local backup --with-files

# Update to latest v15 patches
bench update --patch

# Or full update (includes git pull)
bench update
```

### Automated Backups

```bash
# Add to frappe user's crontab
su - frappe
crontab -e

# Daily backup at 2 AM
0 2 * * * cd /home/frappe/frappe-bench && /home/frappe/.local/bin/bench --site erp.local backup --with-files
```

---

## 🎓 Learning Resources

### Official Documentation

- **ERPNext Docs:** https://docs.erpnext.com/
- **Frappe Framework:** https://frappeframework.com/docs/
- **Frappe School:** https://frappe.school

### Community Support

- **Forum:** https://discuss.frappe.io/
- **GitHub Issues:** https://github.com/frappe/erpnext/issues
- **Telegram:** https://t.me/frappecommunity

---

## 📝 Version History

### v4.0 - Production Release (2026-02-06)

**The Elegant Solution - ERPNext v16**

- ✨ Production-ready systemd + nginx architecture
- ✨ ERPNext v16 installation
- ✨ 30-minute automated installation script
- ✨ Comprehensive troubleshooting guide
- ✨ Optional Insights installation guide
- 🐛 Fixed supervisor pkg_resources issues
- 🐛 Fixed MariaDB authentication
- 🐛 Fixed nginx default page issues
- 🐛 Resolved database schema issues (v15 vs v16)

**Key Learnings:**
- ERPNext v16 with version-16 branch provides latest stable features
- Systemd is simpler and more reliable than supervisor for LXC
- Development mode with nginx proxy provides best stability
- Hiding supervisor during bench init avoids pkg_resources errors

### v2.0 - Complete Guide (2025-12-18)

- 📖 16-step installation guide
- 📖 ERPNext v16 development branch
- 🐛 Database schema troubleshooting

### v1.0 - Initial Analysis (2025-12-17)

- 📊 Project analysis
- 📊 Installation requirements

---

## 🤝 Contributing

Contributions are welcome! Please feel free to submit issues or pull requests.

### Reporting Issues

When reporting issues, please include:
- Ubuntu version
- ERPNext version (`bench version --format table`)
- Error messages
- Steps to reproduce

---

## 📄 License

This project is licensed under the MIT License.

ERPNext itself is licensed under GNU General Public License v3.0.

---

## ⚠️ Disclaimer

This installation guide is provided as-is for educational and production use. Always:

- Test in development environment first
- Backup data regularly
- Follow security best practices
- Keep systems updated

---

## 🙏 Acknowledgments

- **Frappe Technologies** - For ERPNext and Frappe Framework
- **Community Contributors** - For testing and feedback
- **Proxmox Team** - For excellent LXC/CT technology

---

**Made with ❤️ for the ERPNext Community**

*Last Updated: February 6, 2026*
