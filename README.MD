Physical Network IPs
---

- 192.168.178.1 - Router + DHCP Server 
- 192.168.178.10 - 192.168.178.20 -> Servers
- 192.168.178.100-255 -> DHCP

Virtual Network IP
---
- 192.168.179.1 - 192.168.179.10 -> Servers VIP
  - 192.168.179.1 - K3S server group
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

TBD:
- Ali nettop
  - 192.168.179.12
  - Niflheimr
  - K3S Master 3
  - MySQL Galera cluster
  - Keepalived

Physical Hardware Placement
---

Server Rack:
 - older router
 - Alfheimr
 - Midgard

TBD:
 - Niflheimr
 - NAS

# Infrastructure


To be installed:

- Keepalived
- MySQL Galera cluster
- K3S
  - ArgoCD
  - MetalLB
  - CertMgr ( *.k8s.kirillorlov.pro )
  - Longhorn (backup to OVH S3)
  - Cloudflared
  - promtheus-operator (node-exporter, grafana, prometheus)

TBD:
  - Minio for S3 over longhorn
  - External DNS (to sync with pi-hole)
  - PiHole as DNS server
  - csi-driver-sshfs (for seedbox)
  - External Secret Operator 
  - Velero for backups

# Apps

To be installed:

K3S - apps:
 - BitWarden
 - bonsai (+postgres)
 - jackett
 - sonarr
 - radarr
 - homarr (status page)
 - rss-to-telegram
 - photoprism
 - paperless (+redis)
 - nextcloud (+mariadb)
 - plex (disk space??? need nas... or connect hdds to each of nodes)
 - hugo (website)
 - overseerr
 
# ToDo how to:

- Backup MySQL?
- Backup K3s objects?
- Automate initial install?
- Automate backup&recovery?
- Default credentials:
  - argocd - secret 
  - grafana: 
    - default: admin/prom-operator
    - secret 
- Grafana dashboards to autoimport:
  - 16888 - longhorn
  - 7362 - mysql overview
  - 13106 - mysql cluster overview
- Setup additional scrape target for prometheus from ansible (now it's hardcoded in values)
- Check prometheus compaction over time - volume of 10gb might be not enough