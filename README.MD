# Summary
This is configuration for my homelab. 
It is a multi-master Kubernetes cluster with high availability.

## Network

| IP                                | Description                                                                                                                                                               |
|-----------------------------------|---------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| 192.168.178.0/23                  | 	Subnet coming from router                                                                                                                                                |
| 192.168.178.1                     | 	Fritzbox router                                                                                                                                                          |
| 192.168.178.2 - 192.168.178.9     | 	*Reserved for unknown future usages*                                                                                                                                     |
| 192.168.178.10 - 192.168.178.19   | 	Kubernetes nodes. I doubt I’ll ever have more than 10 physical k8s nodes at home                                                                                         |
| 192.168.178.20                    | 	Voron 2.4r2 3d-printer                                                                                                                                                   |
| 192.168.178.100 - 192.168.178.255 | 	DHCP for devices. When I tried to count my smart bulbs and other IoT devices which loves to connect to wifi – I could get up to 50. Probably 150 is future-proof enough. |
| 192.168.179.2                     | 	Virtual IP (talos) for master nodes                                                                                                                                      |
| 192.168.178.3 - 192.168.178.10    | 	*Reserved for unknown future usages*                                                                                                                                     |
| 192.168.179.11 - 192.168.179.255  | 	Virtual IPs for K8s services                                                                                                                                             |

## Hardware

| Node name    | IP             | Roles   | Device            | CPU                      | RAM  | Storage                | Price            |
|--------------|----------------|---------|-------------------|--------------------------|------|------------------------|------------------|
| Alfheimr     | 192.168.178.10 | Unused  | HP T620           | AMD GX-415 4*1.5Ghz core | 16Gb | 256GB SSD              | 45$  + SSD + RAM |
| Yggdrasil    | Offsite        | Backups | ThinkCenter M710q | i3 6100T 4*3.2GHz core   | 16GB | 1024GB SSD             | 100$ + SSD + RAM |
| Niflheimr    | 192.168.178.12 | Master  | Firebat AM02      | N100 4*3.4Ghz cores      | 16GB | 512GB SSD + 512GB NVME | 160$             |
| Jotunheimr   | 192.168.178.13 | Master  | SOYO M2PLUS       | N100 4*3.4Ghz cores      | 16GB | 512GB SSD + 512GB NVME | 115$             |
| Muspelheimr  | 192.168.178.14 | Master  | SOYO M2PLUS       | N100 4*3.4Ghz cores      | 16GB | 512GB SSD + 512GB NVME | 100$             |
