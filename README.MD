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

TBD:
- Freika nettop     
  - 192.168.179.11
  - Midgard
  - K3S Master 2
  - MySQL Galera cluster
  - Keepalived
- Ali nettop
  - 192.168.179.12
  - Niflheimr
  - K3S Master 3
  - MySQL Galera cluster
  - Keepalived

Physical Hardware Placement
---

Target state:

Server Rack:
 - older router
 - Alfheimr
 - Midgard
 - Niflheimr
 - TBD NAS 


# Infrastructure


To be installed:

- Keepalived
- MySQL Galera cluster
- K3S
  - ArgoCD
  - MetalLB
  - CertMgr ( *.k8s.kirillorlov.pro )
  - Longhorn (backup to OVH S3)
  - Minio for S3 over longhorn
  - Cloudflared
  - External DNS (to sync with pi-hole)
  - PiHole as DNS server
  - promtheus-operator (node-exporter, grafana, prometheus)
  - csi-driver-sshfs (for seedbox)
  - External Secret Operator 

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

Backup MySQL?