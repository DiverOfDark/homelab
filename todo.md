to setup
- Ceph mon config backup (or how to backup whole Ceph?)
- Fix Ceph warning!
- Alerts from alertmanager to TG!

unknown state:
- opentelemetry-operator 

fake out-of-sync:
- csi-snapshot-controller
- kubevirt
- kubevirt-vms

dashboard
- all PV without backups
- all DB without S3 backup
- all pods without requests/limits
- all pods under root
- ... ?
- **[P2]** Ensure all services are active-active
- **[P2]** Ensure all deployments have health and liveness checks
- **[P2]** Ensure all services have SSO
- **[P2]** Ensure all image references are to concrete tags, not latest

convert meta-app generator to helm chart?

- deploy garage webui

alerts and rules to make sure that I have:
 - PV usage
 - backups state
 - ceph usage 
 - free space on yggdrasil / s3
 - free space on wasabi
 - out-of-sync or failing argo apps
 


install WAZUH for security

- ~~convert cloudflare tunnels to kubespan-ned node on hetzner with second instance of traefik ingress controller~~ DONE 2026-07-11 (tailscale-shaped: bifrost=headscale, midgard=Talos edge worker via tailscale extension, traefik-external, wildcard DNS; Cloudflare = DNS zone + DNS01 only)

-- 
convert two-part apps (e.g. when some part is helm chart in k3s-apps and another part is either k3s-objects or k3s-userapps) into multiple sources app
(and e.g. store additional objects in subfolder of k3s-apps, if meta-app won't try to apply it by itself)
