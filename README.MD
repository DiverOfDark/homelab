Physical Network IPs
---

- 192.168.178.1 - Router + DHCP Server 
- 192.168.178.10 - 192.168.178.20 -> Servers
- 192.168.178.100-255 -> DHCP

Virtual Network IP
---
- 192.168.179.1 - 192.168.179.10 -> Servers VIP
  - 192.168.179.1 - K3S server group keepalived
    - Alfheimr
    - Midgard
    - Niflheimr
- 192.168.179.11 - 192.168.179.255 - Virtual IPs (MetalLB)

HW
---
- HP T620T (Alfheimr)
  - IP: 192.168.178.10
  - Roles: 
    - MySQL Galera Cluster
    - Keepalived
    - K3S Master 1
- ThinkCentre M710q (Midgard)     
  - 192.168.179.11
  - Roles:
    - K3S Master 2
    - Keepalived
    - MySQL Galera cluster
- Firebat AM02 (Niflheimr)
  - 192.168.179.12
  - Roles:
    - K3S Master 3
    - Keepalived
    - MySQL Galera cluster

Physical Hardware Placement
---

Server Rack:
 - older router
 - Alfheimr
 - Midgard
 - Niflheimr

TBD:
 - NAS

# Infrastructure

- Keepalived
- MySQL Galera cluster
- RClone mount to seedbox ftp on each node to /mnt/seedbox
- K3S
  - ArgoCD
  - MetalLB
  - CertMgr ( *.k8s.kirillorlov.pro )
  - Longhorn (backup to OVH S3)
  - Cloudflared
  - prometheus-operator (node-exporter, grafana, prometheus)
  - External DNS (to sync with pi-hole)
  - PiHole as DNS server
  - External Secret Operator 

To be installed:
  - MariaDB-operator
  - Minio for S3 over longhorn
  - Velero for backups

# Apps

Running:
 - rss-to-telegram
 - nextcloud (+mariadb)
 - hugo (website)
 - photoprism
 - actualbudget
 - paperless (+redis)
 - jackett
 - sonarr
 - radarr
 - plex
 - overseerr

To be installed:
 - bonsai (+postgres)
 - homarr (status page)
 
# ToDo how to:

- Backup MySQL?
- Backup K3s objects? Restore PV?
- Try to Restore PV?
- Setup additional scrape target for prometheus from ansible (now it's hardcoded in values)
- Setup proper requests / limits for userapps
- Setup proper liveness / startup / readyness checks for userapps
- Ensure all tags are not current - so that renovate would work
- Reloader to restart app if ConfigMap changes
  - Or KEDA operator? 
- HA for ALL apps
- HA for PiHole (?) - or caching proxy-server / fallback dns server?
- Custom metrics for all installed apps - check what doesn't and whether they support
- RSSTT - switch to statefulset 
- Default resource limit for all pods = 50cpu / 16mib
- All ingresses - check http(s) 
  - or even better - write a policy for Kyverno for that