# Building a HomeLab on leftovers
  
# Backstory
I love watching YouTube – and watching all the tech-bloggers building their own home labs made me to realize that I want the same – the cluster at home, a digital playground where I can play around with all the stuff, but to my own taste. 
Being an ex-DevOps-lead for one of largest investment banks I have a certain bias about availability, disaster recovery and all boring controls stuff. 
On top of that I didn’t want to spend a ton of money on hardware which I would barely use (there’s a decent chance for that!), and I really wanted independent bare-metal hardware nodes, without any kind of VM virtualization – I want to be able to physically turn off any one of them, replace with newer / other, and do any kind of maintenance without any disruption. 
And of course, because of electricity prices (and noise), I can’t just buy old HP server and put it into server rack at home – each node would consume at least 200 W of power, and for high availability I need at least two of them.
So, inevitably this leads to weirdest solution of all possible – a Kubernetes cluster on Thin-Clients!

# Planning
As with every project the first step is to write down a detailed plan how it should look like and work together with within my home network.
So, currently I have a router coming from ISP, Fritzbox. It is a simple network router for use at home, with a coaxial cable connection (yes, it is still a thing in Germany in 2024), 1*2.5Gb port and 4*1Gb ports. It is not very configurable, so my current home network is 192.168.178.0/24 with single gateway to internet 192.168.178.1. 
I know that I need at least 3 nodes with static ips for Kubernetes for proper multi-master highly-available setup. Plus I might need some virtual Ips for loadbalancing of services running inside K8s cluster. 
So this led me to following network setup:

| 192.168.178.0/23 |	Subnet coming from router |
| 192.168.178.1    |	Router itself            |
| 192.168.178.2-192.168.178.9 |	Reserved for unknown future usages |
| 192.168.178.10-192.168.178-20 |	Kubernetes nodes –(I doubt I’ll ever have more than 10 physical k8s nodes at home) |
| 192.168.178.100-192.168.178.255 |	DHCP for everyone –(when I tried to count my smart bulbs and other IoT devices which loves to connect to wifi – I could get up to 50. Probably 150 is future-proof enough  ). |
| 192.168.179.1 |	Virtual IP for K8s API |
| 192.168.178.2-192.168.178.10 |	Reserved for unknown future usages |
| 192.168.179.11 - 192.168.179.255 |	Virtual IPs for K8s services |

Next steps would be getting actual hardware. In the era when latest Raspberry PI costs almost 100$, and provides very limited performance per bucks the very next choice would be used thin-client or mini-pc (with upgradable RAM and much more expansion options!).
I already had an upgraded HP T620 (AMD GX-415 4*1.5Ghz core, 16Gb RAM and 256GB SSD) – so I will repurpose it for being an K8s node and buy two others.
The second node would be ThinkCentre M710q (i3 6100T 4*3.2GHz core, 16GB RAM and 512GB SSD) – was sold by a friend of mine, and also upgraded to decent memory size and storage.
For the third node I had to revert to the last resort of getting cheap hardware – infamous Aliexpress. After hours of lurking through offers I discovered Firebat AM02 (N100, 4*3.4Ghz cores, 16GB RAM, 512GB SSD) for just 160$ - a great deal.
Also I had spare old network router, which could be used as 1Gbps switch – I certainly don’t want to build the cluster over wifi! 

# Hardware configuration
  
Once I got all the hardware – I need to set up an operating system, and basic remote access – because they would reside in network rack without any keyboard or display to configure them.
So I decided to use Debian Testing (pre-release of next Debian release (Trixie, as of writing) with all the new and shiny stuff). Why not Ubuntu (or other distro name) you may ask? Well, simply because Debian isn’t as bloated as Ubuntu (I still hate snaps and all ad on Ubuntu Advantage). And I want to get all the nice and shiny things – so had to switch to Testing from Bookworm. 
Made a bootable USB-drive with rufus, inserted into each of the node, configured same user with password, enabled openssh, minimal setup , set up static IP, connected to the switch – and moved each of the node to the rack.
Now, here comes automation, because I don’t want to ever repeat all the manual steps I do to configure the nodes. 
For OS configuration I am using ansible – a simple playbook with a single task which would set up everything. Lame and slow, I know, but it works.
First of all, I decided to use k3s as Kubernetes distribution. It ships as single binary, with a few components cut out, and a few others which can be disabled.
Originally I thought about using k3s + kine + Mysql galera cluster instead of etcd, but that turned out to be very bad idea – kine can’t work with clustered databases (or when id increases non-monotonically).

Besides k3s for a highly-available K3S api endpoint I’ll use keepalived. This is a linux project which basically advertises additionally IP over ARP, if no one else took that IP. 
It doesn’t do any kind of load-balancing – so if k3s is stopped, but node and keepalived is alive – then endpoint won’t work. If we really want to have HA access to K8S Api – then we can install loadbalancer with a list of backends for each of API server and  then use keepalived on each of these servers -> then we’ll have a single loadbalancer IP.
… todo insert here config example…
…todo ansible playbook for installing k3s…

Ansible playbook is to be stored in Git and publicly accessible – this means that all passwords/credentials/secret have to be encrypted in the playbook as well. 
Ansible Vault can do this for you, and JetBrains PyCharm offers really nice integration to encrypt password as simple as pushing Alt+Enter -> Encrypt.

The only things we need to install initially on K8s cluster – is ArgoCD. This is a GitOps tool which add CRDs for applications, allowing us to store in Git all objects we need to create in cluster – this way we can have a single repo containing all cluster configuration both from operating system configuration and k8s objects perspective – allowing us to easily recreate cluster from scratch, if required.
So, to bootstrap a cluster we’ll also create a first meta-app Application which would reference a subfolder of yaml files in repos to install them into cluster. There will reside all references to other k8s apps we’ll install in next step.

# Storage, DNS, internal and external connectivity
 



Parts:
1)	Additional infrastructure services
 .	DNS setup, internal and external connectivity – CertMgr + Cloudflared + MetalLB + Traefik ingresses + ExternalDNS + PiHole (PR+DR+OrbitalSync)
 .	Storage – Longhorn, Backups
 .	Monitoring – Prometheus stack
 .	VerticalPodAutoscaler, 
2)	Backups – how to recover everything(?)
3)	What I do actually host?
 .	Seedbox+media stack (radar,sonar,plex,overseer,jacket) 
 .	Actualbudget
 .	Homepage/statuspage(+operator for copying secrets to annotations)
 .	NextCloud
 .	Bonsai demo-site
 .	Rss-to-telegram
 .	Telegram chat summarizer (ollama+java)
 .	
