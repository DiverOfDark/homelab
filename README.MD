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
    - Keepalived
    - K3S Master 1
- ThinkCentre M710q (Midgard)     
  - 192.168.179.11
  - Roles:
    - K3S Master 2
    - Keepalived
- Firebat AM02 (Niflheimr)
  - 192.168.179.12
  - Roles:
    - K3S Master 3
    - Keepalived

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
    - 2 installations - PR and DR
    - OrbitalSync to sync from PR to DR
  - External Secret Operator
  - Reloader
  - MariaDB-operator
  - VerticalPodAutoscaler

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
 - bonsai
 - homepage

# Restore cluster

- create new cluster
- add argocd
- add eso and longhorn
- restore all volumes from longhorn
- create pv and pvc (using button in longhorn ui)
- add meta-app - it will reconfigure all back

# ToDo how to:

- Setup proper liveness / startup / readyness checks for userapps
- Ensure all tags are not current - so that renovate would work
- HA for ALL apps
- RSSTT - switch to statefulset 
- All ingresses - check http(s) 
  - or even better - write a policy for Kyverno for that