
# Infrastructure Report

- **Generated:** 2025-10-20T09:10:58+00:00
- **Report Version:** 5.1-multi-host
- **Hostname:** n8n-teilscail

## System Information

- **OS Type:** ubuntu
- **OS Name:** Ubuntu 22.04.5 LTS
- **OS Version:** 22.04.5 LTS (Jammy Jellyfish)
- **Kernel:** 6.8.0-1029-oracle
- **Architecture:** x86_64
- **Uptime:** up 10 weeks, 1 day, 20 hours, 45 minutes

## CPU Information

- **CPU Model:** AMD EPYC 7551 32-Core Processor
- **CPU Cores:** 2

## Memory Information

- **Total Memory:** 956Mi
- **Used Memory:** 428Mi
- **Free Memory:** 112Mi

## Disk Information


### Disk Usage

```text
Filesystem      Size  Used Avail Use% Mounted on
efivarfs        256K   17K  235K   7% /sys/firmware/efi/efivars
/dev/sda1        45G   12G   34G  27% /
/dev/sda15      105M  6.1M   99M   6% /boot/efi
```


## Network Information


### Network Interfaces

```text
lo               UNKNOWN        127.0.0.1/8 ::1/128 
ens3             UP             10.0.0.18/24 metric 100 fe80::17ff:fe19:740c/64 
tailscale0       UNKNOWN        100.66.97.93/32 fd7a:115c:a1e0::8133:615d/128 fe80::4b0e:c513:8e59:eb92/64 
docker0          DOWN           10.0.1.1/24 fe80::d891:89ff:fe9b:a9f7/64 
br-9bbe074d65cf  UP             10.0.2.1/24 fe80::c499:18ff:fe19:eb72/64 
veth69da80f@if2  UP             fe80::4490:c9ff:fed0:9fc5/64 
vethd8f3cca@if2  UP             fe80::7826:9bff:fedb:769d/64 
```


### Listening Ports

```text
Netid State  Recv-Q Send-Q               Local Address:Port  Peer Address:PortProcess
udp   UNCONN 0      0                    127.0.0.53%lo:53         0.0.0.0:*          
udp   UNCONN 0      0                   10.0.0.18%ens3:68         0.0.0.0:*          
udp   UNCONN 0      0                          0.0.0.0:111        0.0.0.0:*          
udp   UNCONN 0      0                          0.0.0.0:41641      0.0.0.0:*          
udp   UNCONN 0      0                                *:52482            *:*          
udp   UNCONN 0      0                                *:58204            *:*          
udp   UNCONN 0      0                                *:53625            *:*          
udp   UNCONN 0      0                                *:56903            *:*          
udp   UNCONN 0      0                             [::]:111           [::]:*          
udp   UNCONN 0      0                             [::]:41641         [::]:*          
tcp   LISTEN 0      128                        0.0.0.0:22         0.0.0.0:*          
tcp   LISTEN 0      4096                       0.0.0.0:111        0.0.0.0:*          
tcp   LISTEN 0      1024                     127.0.0.1:20241      0.0.0.0:*          
tcp   LISTEN 0      4096                  100.66.97.93:63251      0.0.0.0:*          
tcp   LISTEN 0      4096                 127.0.0.53%lo:53         0.0.0.0:*          
tcp   LISTEN 0      1024                     127.0.0.1:5678       0.0.0.0:*          
tcp   LISTEN 0      128                           [::]:22            [::]:*          
tcp   LISTEN 0      4096                          [::]:111           [::]:*          
tcp   LISTEN 0      4096   [fd7a:115c:a1e0::8133:615d]:62836         [::]:*          
```


## Docker Information

- **Docker Version:** Docker version 28.3.3, build 980b856

### Running Containers

```text
NAMES            IMAGE                STATUS                 PORTS
n8n-n8n-1        n8nio/n8n:latest     Up 7 weeks             127.0.0.1:5678->5678/tcp
n8n-postgres-1   postgres:16-alpine   Up 7 weeks (healthy)   5432/tcp
```


### Docker Images

```text
REPOSITORY   TAG         SIZE
n8nio/n8n    latest      1.03GB
postgres     16-alpine   276MB
n8nio/n8n    <none>      1.02GB
postgres     <none>      276MB
```


### Docker Networks

```text
NETWORK ID     NAME             DRIVER    SCOPE
9cabfa5867f7   bridge           bridge    local
f013c3edfeef   host             host      local
9bbe074d65cf   n8n_exodus-net   bridge    local
c0970e14e3eb   none             null      local
```


### Docker Volumes

```text
DRIVER    VOLUME NAME
local     coolify-db
local     coolify-redis
local     n8n_n8n_storage
local     n8n_postgres_storage
local     portainer_data
local     portainer_portainer_data
```


## System Services


### Active Services

```text
  UNIT                                                       LOAD   ACTIVE SUB     DESCRIPTION
  cloudflared.service                                        loaded active running cloudflared
  containerd.service                                         loaded active running containerd container runtime
  cron.service                                               loaded active running Regular background program processing daemon
  dbus.service                                               loaded active running D-Bus System Message Bus
  docker.service                                             loaded active running Docker Application Container Engine
  getty@tty1.service                                         loaded active running Getty on tty1
  irqbalance.service                                         loaded active running irqbalance daemon
  iscsid.service                                             loaded active running iSCSI initiator daemon (iscsid)
  multipathd.service                                         loaded active running Device-Mapper Multipath Device Controller
  networkd-dispatcher.service                                loaded active running Dispatcher daemon for systemd-networkd
  packagekit.service                                         loaded active running PackageKit Daemon
  polkit.service                                             loaded active running Authorization Manager
  rpcbind.service                                            loaded active running RPC bind portmap service
  rsyslog.service                                            loaded active running System Logging Service
  serial-getty@ttyS0.service                                 loaded active running Serial Getty on ttyS0
  snap.oracle-cloud-agent.oracle-cloud-agent-updater.service loaded active running Service for snap application oracle-cloud-agent.oracle-cloud-agent-updater
  snap.oracle-cloud-agent.oracle-cloud-agent.service         loaded active running Service for snap application oracle-cloud-agent.oracle-cloud-agent
  snapd.service                                              loaded active running Snap Daemon
  ssh.service                                                loaded active running OpenBSD Secure Shell server
```


### Failed Services

```text
  UNIT LOAD ACTIVE SUB DESCRIPTION
0 loaded units listed.
```


## Top Processes (by CPU)

```text
USER         PID %CPU %MEM    VSZ   RSS TTY      STAT START   TIME COMMAND
ubuntu   1175149  6.0  0.3   8028  3456 pts/0    S+   09:10   0:00 bash infra-report.sh
root     1666396  0.4  1.8 1262868 18256 ?       Ssl  Aug31 294:42 /usr/bin/cloudflared --no-autoupdate --config /etc/cloudflared/config.yml tunnel run
root        5438  0.2  2.3 1320760 22956 ?       Ssl  Aug09 242:56 /usr/sbin/tailscaled --state=/var/lib/tailscale/tailscaled.state --socket=/run/tailscale/tailscaled.sock --port=41641
snap_da+    1783  0.1  1.3 1240360 13360 ?       Sl   Aug09 158:20 /snap/oracle-cloud-agent/current/plugins/gomon/gomon
root     1263456  0.1  3.7 2541208 36724 ?       Ssl  Aug27 101:21 /usr/bin/dockerd -H fd:// --containerd=/run/containerd/containerd.sock
root           1  0.0  0.9 167804  9216 ?        Ss   Aug09   5:48 /lib/systemd/systemd --system --deserialize 42
root           2  0.0  0.0      0     0 ?        S    Aug09   0:01 [kthreadd]
root           3  0.0  0.0      0     0 ?        S    Aug09   0:00 [pool_workqueue_release]
root           4  0.0  0.0      0     0 ?        I<   Aug09   0:00 [kworker/R-rcu_g]
root           5  0.0  0.0      0     0 ?        I<   Aug09   0:00 [kworker/R-rcu_p]
```


## Security Information


### SSH Configuration

- **SSH Port:** 22
- **Root Login:** unknown

### Firewall Status

```text
Status: inactive
```


## Key Software

Checking installed software...

- **Git:** git version 2.34.1
- **Python:** Python 3.10.12
- **Docker:** Docker version 28.3.3, build 980b856

---

*Report generated by infra-report.sh v5.1-multi-host*
*Time: 2025-10-20T09:10:58+00:00*
