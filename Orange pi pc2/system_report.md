# 🌐 Infrastructure Report

- **Version:** 5.0-multi-host
- **Generated:** 2025-10-20T09:01:46+03:00

## 📋 System Information

- **Hostname:** debian
- **OS:** debian
- **Kernel:** 6.11.10-arm64
- **CPU Cores:** 4
- **Uptime:** up 2 days, 8 hours, 15 minutes

## 🚀 Knowledge Pipeline Role

- **Detected Role:** Сховище (MinIO)

## 💾 Memory & Swap

```
               total        used        free      shared  buff/cache   available
Mem:           972Mi       672Mi        42Mi        11Mi       350Mi       299Mi
Swap:          1.7Gi       656Mi       1.1Gi
```

> Swap information not available (need sudo or /proc/swaps access)

## 💿 Disk Usage

```
Filesystem      Size  Used Avail Use% Mounted on
udev            443M     0  443M   0% /dev
tmpfs            98M  1.3M   96M   2% /run
/dev/mmcblk0p2   29G   13G   15G  48% /
tmpfs           487M     0  487M   0% /dev/shm
tmpfs           5.0M     0  5.0M   0% /run/lock
tmpfs           1.0M     0  1.0M   0% /run/credentials/systemd-journald.service
tmpfs           1.0M     0  1.0M   0% /run/credentials/systemd-resolved.service
tmpfs           1.0M     0  1.0M   0% /run/credentials/systemd-networkd.service
/dev/zram1       56M  280K   52M   1% /var/log
tmpfs           487M     0  487M   0% /tmp
tmpfs           1.0M     0  1.0M   0% /run/credentials/getty@tty1.service
tmpfs           1.0M     0  1.0M   0% /run/credentials/serial-getty@ttyS0.service
tmpfs            98M   28K   98M   1% /run/user/1000
```


## 🐳 Docker

- **Docker Version:** 27.4.0
2.31.0
- **Daemon Status:** Running ✅
- **Containers:** 7
```
NAMES              STATUS                IMAGE
wallabag           Up 2 days (healthy)   wallabag/wallabag:latest
portainer          Up 2 days             portainer/portainer-ce:latest
minio              Up 2 days (healthy)   minio/minio:latest
mcp-server         Up 2 days             quay.io/minio/aistor/mcp-server-aistor:latest
cloudflared        Up 31 hours           erisamoe/cloudflared
drakon-converter   Up 2 days             arm64v8/nginx:alpine
exodus-handler     Up 2 days             kroschu/exodus-handler
```


## 📦 Application Stack

- **N8N:** Not found ❌
- **PostgreSQL:** Not found ❌
- **Portainer:** Running ✅
- **Cloudflared:** Not found ❌
- **Tailscale:** Connected ✅
- **Tailscale:** Installed but not connected ⚠️

## 🌐 Network

- **Internal IP:** 192.168.3.161
- **External IP:** 188.163.44.178
- **Tailscale IP:** 100.65.225.122

## 💡 Recommendations

### Low Memory System (0.9 GB)
- Enable swap (2GB recommended)
- Use memory limits in Docker containers
- Enable execution pruning in N8N
- Optimize PostgreSQL for low memory

## ✅ Summary

Infrastructure analysis completed successfully!

**Key Points:**
- System: debian (debian on 6.11.10-arm64)
- Role: Сховище (MinIO)
- Resources: 4 CPU cores, 0.9 GB RAM
- Docker: Installed
- Stack: N8N not found

🇺🇦 **Слава Україні!**