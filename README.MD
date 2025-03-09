# Summary
This is configuration for my homelab. 
It is a multi-master Kubernetes cluster with high availability.

## Why
I love watching YouTube – and watching all the tech-bloggers building their own home labs made me realize that I want
the same: the cluster at home, a digital playground where I could play around with all the stuff, but to my own taste.

Being an ex-DevOps-lead for one of the largest investment banks, I have a certain bias about availability, disaster
recovery and all boring controls stuff.

On top of that, I didn’t want to spend a ton of money on hardware which I would barely use (there’s a decent chance for
that!), and I really wanted independent bare-metal hardware nodes, without any kind of VM virtualization – I want to be
able to physically turn off any one of them, replace with newer / other, and do any kind of maintenance without any
disruption.

Because of electricity prices and noise, I couldn’t buy used HP server and put it into server rack at home:
each node would consume at least 200 W of power, and for high availability I need at least two of them.

So, inevitably this led to the weirdest solution of all possible – a multi-master Kubernetes cluster on 
Thin-Clients and mini-pcs!

## Network

| IP                                | Description                                                                                                                                                               |
|-----------------------------------|---------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| 192.168.178.0/23                  | 	Subnet coming from router                                                                                                                                                |
| 192.168.178.1                     | 	Fritzbox router                                                                                                                                                          |
| 192.168.178.2 - 192.168.178.9     | 	*Reserved for unknown future usages*                                                                                                                                     |
| 192.168.178.10 - 192.168.178.20   | 	Kubernetes nodes. I doubt I’ll ever have more than 10 physical k8s nodes at home                                                                                         |
| 192.168.178.100 - 192.168.178.255 | 	DHCP for devices. When I tried to count my smart bulbs and other IoT devices which loves to connect to wifi – I could get up to 50. Probably 150 is future-proof enough. |
| 192.168.179.1                     | 	Virtual IP (keepalived) for master nodes                                                                                                                                 |
| 192.168.178.2 - 192.168.178.10    | 	*Reserved for unknown future usages*                                                                                                                                     |
| 192.168.179.11 - 192.168.179.255  | 	Virtual IPs for K8s services                                                                                                                                             |

## Hardware

| Node name  | IP             | Roles  | Device            | CPU                      | RAM  | Storage   | Price            | Notes                         |
|------------|----------------|--------|-------------------|--------------------------|------|-----------|------------------|-------------------------------|
| Alfheimr   | 192.168.178.10 | Worker | HP T620           | AMD GX-415 4*1.5Ghz core | 16Gb | 256GB SSD | 45$  + SSD + RAM | Bought used from some website |
| Midgard    | 192.168.178.11 | Master | ThinkCenter M710q | i3 6100T 4*3.2GHz core   | 16GB | 512GB SSD | 100$ + SSD + RAM | Bought used from a friend     |
| Niflheimr  | 192.168.178.12 | Master | Firebat AM02      | N100 4*3.4Ghz cores      | 16GB | 512GB SSD | 160$             | Bought from AliExpress as new |
| Yotunheimr | 192.168.178.13 | Master | SOYO M2PLUS       | N100 4*3.4Ghz cores      | 16GB | 512GB SSD | 115$             | Bought from AliExpress as new |