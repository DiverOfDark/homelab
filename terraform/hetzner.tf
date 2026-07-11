# Hetzner Cloud: bifrost (headscale coordination VM) + midgard (Talos edge worker).
# bifrost is deliberately NOT a cluster node — tailnet coordination must survive
# any homelab/cluster failure, so it stays a plain Debian VM managed by ansible/.

# Hetzner Cloud API token from OpenBao (ephemeral: never persisted to state).
# Expected keys: token (project API token with read+write). The admin SSH
# pubkey comes in as TF_VAR_admin_ssh_public_key (exported by flake.nix from
# the same OpenBao secret) — it can't ride the ephemeral because
# hcloud_ssh_key.public_key is a regular, state-persisted attribute.
ephemeral "vault_kv_secret_v2" "hcloud" {
  mount = "secret"
  name  = "hcloud"
}

provider "hcloud" {
  token = ephemeral.vault_kv_secret_v2.hcloud.data["token"]
}

variable "admin_ssh_public_key" {
  description = "Admin SSH public key for bifrost (exported by flake.nix from OpenBao secret/hcloud key ssh_public_key)"
  type        = string
}

# cx23 is the cheapest suitable type (2026-07); only available in Falkenstein
# (fsn1), which local.hetzner_location already pins.
variable "bifrost_server_type" {
  description = "hcloud server type for bifrost (pick cheapest via `hcloud server-type list`; CAX/arm works — headscale ships arm64 debs, but switch image to a -arm one too)"
  type        = string
  default     = "cx23"
}

variable "midgard_server_type" {
  description = "hcloud server type for midgard (cheapest x86 — Talos image is built for amd64 by packer/talos-hcloud.pkr.hcl)"
  type        = string
  default     = "cx23"
}

locals {
  hetzner_location = "fsn1"
  # Non-default SSH port for bifrost; must match ansible/inventory/hosts.yaml
  # and ansible group_vars. sshd never listens on 22 publicly (cloud-init sets
  # the port on first boot, before ansible ever runs).
  bifrost_ssh_port = 22320
}

resource "hcloud_ssh_key" "admin" {
  name       = "homelab-admin"
  public_key = var.admin_ssh_public_key
}

# Pinned IPs survive server rebuilds -> DNS records never have to change.
resource "hcloud_primary_ip" "bifrost_v4" {
  name        = "bifrost-v4"
  type        = "ipv4"
  location    = local.hetzner_location
  auto_delete = false
}

resource "hcloud_primary_ip" "midgard_v4" {
  name        = "midgard-v4"
  type        = "ipv4"
  location    = local.hetzner_location
  auto_delete = false
}

resource "hcloud_firewall" "bifrost" {
  name = "bifrost"

  rule {
    description = "SSH (non-default port, key-only; tighten to tailnet after Phase 7)"
    direction   = "in"
    protocol    = "tcp"
    port        = tostring(local.bifrost_ssh_port)
    source_ips  = ["0.0.0.0/0", "::/0"]
  }
  rule {
    description = "ACME HTTP-01 for headscale native TLS"
    direction   = "in"
    protocol    = "tcp"
    port        = "80"
    source_ips  = ["0.0.0.0/0", "::/0"]
  }
  rule {
    description = "headscale API + embedded DERP (TLS)"
    direction   = "in"
    protocol    = "tcp"
    port        = "443"
    source_ips  = ["0.0.0.0/0", "::/0"]
  }
  rule {
    description = "STUN for embedded DERP"
    direction   = "in"
    protocol    = "udp"
    port        = "3478"
    source_ips  = ["0.0.0.0/0", "::/0"]
  }
  rule {
    description = "tailscale direct WireGuard (bifrost as tailnet member)"
    direction   = "in"
    protocol    = "udp"
    port        = "41641"
    source_ips  = ["0.0.0.0/0", "::/0"]
  }
}

# Firewall for the Talos edge worker (server itself is created in Phase 4,
# see packer/talos-hcloud.pkr.hcl for the image build).
resource "hcloud_firewall" "midgard" {
  name = "midgard"

  rule {
    description = "HTTP (traefik-external redirect to https)"
    direction   = "in"
    protocol    = "tcp"
    port        = "80"
    source_ips  = ["0.0.0.0/0", "::/0"]
  }
  rule {
    description = "HTTPS (traefik-external)"
    direction   = "in"
    protocol    = "tcp"
    port        = "443"
    source_ips  = ["0.0.0.0/0", "::/0"]
  }
  rule {
    description = "HTTP/3 (traefik-external)"
    direction   = "in"
    protocol    = "udp"
    port        = "443"
    source_ips  = ["0.0.0.0/0", "::/0"]
  }
  rule {
    description = "tailscale direct WireGuard"
    direction   = "in"
    protocol    = "udp"
    port        = "41641"
    source_ips  = ["0.0.0.0/0", "::/0"]
  }
  # Talos apid (tcp/50000) is deliberately NOT exposed anymore: talosctl runs
  # over the tailnet (midgard.ts.kirillorlov.pro). Break-glass if the tailnet
  # is dead: Hetzner web console, or temporarily re-add the rule.
}

resource "hcloud_server" "bifrost" {
  name         = "bifrost"
  server_type  = var.bifrost_server_type
  image        = "debian-12"
  location     = local.hetzner_location
  ssh_keys     = [hcloud_ssh_key.admin.id]
  firewall_ids = [hcloud_firewall.bifrost.id]

  public_net {
    ipv4         = hcloud_primary_ip.bifrost_v4.id
    ipv6_enabled = true
  }

  # Move sshd off port 22 before the box is ever reachable; everything else
  # (hardening, headscale) is ansible's job — see ansible/.
  user_data = <<-EOT
    #cloud-config
    ssh_pwauth: false
    write_files:
      - path: /etc/ssh/sshd_config.d/10-port.conf
        content: |
          Port ${local.bifrost_ssh_port}
          PasswordAuthentication no
          PermitRootLogin prohibit-password
    runcmd:
      - systemctl restart ssh
  EOT

  lifecycle {
    ignore_changes = [image] # image bumps are a rebuild decision, not drift
  }
}

# Talos snapshot built by packer/talos-hcloud.pkr.hcl (rescue-mode dd of the
# Image Factory hcloud-amd64 image). Most-recent wins on version bumps.
data "hcloud_image" "talos" {
  with_selector     = "os=talos"
  most_recent       = true
  with_architecture = "x86"
}

resource "hcloud_server" "midgard" {
  name         = "midgard"
  server_type  = var.midgard_server_type
  image        = data.hcloud_image.talos.id
  location     = local.hetzner_location
  firewall_ids = [hcloud_firewall.midgard.id]

  public_net {
    ipv4         = hcloud_primary_ip.midgard_v4.id
    ipv6_enabled = true
  }

  # Talos config is applied via talosctl (talos/talconfig.yaml node entry),
  # not cloud-init. Image bumps are done by rebuilding the snapshot with
  # packer and letting talosctl upgrade handle the node — not by replacing
  # the server.
  lifecycle {
    ignore_changes = [image]
  }
}

output "bifrost_ipv4" {
  value       = hcloud_primary_ip.bifrost_v4.ip_address
  description = "bifrost public IPv4 (headscale.kirillorlov.pro, ansible inventory)"
}

output "midgard_ipv4" {
  value       = hcloud_primary_ip.midgard_v4.ip_address
  description = "midgard public IPv4 (public A records target, talosctl bootstrap)"
}
