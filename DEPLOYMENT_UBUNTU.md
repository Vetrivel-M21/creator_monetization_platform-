# ARMSS Creator Platform — Ubuntu Server Deployment Guide

This guide details the complete production deployment setup on an Ubuntu 22.04 / 24.04 LTS server using Docker and Docker Compose.

---

## 1. Quick Start (1-Command Deployment)

On your Ubuntu server, clone the repository and run:

```bash
cd /opt
git clone <your-repo-url> creator_platform
cd creator_platform

# Make scripts executable
chmod +x deploy.sh scripts/backup_db.sh

# Run automated deployment
./deploy.sh
```

---

## 2. Architecture & Components

```
                ┌──────────────────────────────────────┐
                │   Ubuntu Host Server (Port 80/443)   │
                └──────────────────┬───────────────────┘
                                   │
               ┌───────────────────┴───────────────────┐
               ▼                                       ▼
    ┌──────────────────────┐               ┌──────────────────────┐
    │  creator_frontend    │               │   creator_backend    │
    │  Nginx Web Proxy     │──── /api/ ───▶│   Go Chi API Server  │
    │  (Port 80 / 8080)    │               │   (Port 8085)        │
    └──────────────────────┘               └───────────┬──────────┘
                                                       │
                                          Private Docker Network
                                                       │
                                                       ▼
                                           ┌──────────────────────┐
                                           │    creator_mysql     │
                                           │    MySQL 8.0 Engine  │
                                           │    (Port 3306)       │
                                           └──────────────────────┘
```

---

## 3. Persistent Data Protection

The following directories on the Ubuntu host persist permanently outside container filesystems:

| Host Path | Container Path | Purpose |
| :--- | :--- | :--- |
| `mysql_data` (Docker Volume) | `/var/lib/mysql` | MySQL database tables, users, balances |
| `./backend/data` | `/app/data` | Video files (`masters/`), HLS chunks (`hls/`), thumbnails & logos |
| `./backend/logs` | `/app/logs` | Application error and audit logs |

---

## 4. Automated Daily Backups

Set up automatic daily database backups using `cron`:

```bash
# Open crontab editor
sudo crontab -e
```

Add the following line to run every day at 2:00 AM:

```cron
0 2 * * * /opt/creator_platform/scripts/backup_db.sh >> /var/log/creator_backup.log 2>&1
```

---

## 5. Production Health Verification

Verify that all containers are healthy:

```bash
# Check container status
docker compose ps

# Check backend health endpoint
curl http://127.0.0.1:8085/api/health

# View live backend logs
docker compose logs -f backend
```

