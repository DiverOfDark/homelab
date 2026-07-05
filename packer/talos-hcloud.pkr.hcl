# Builds an hcloud snapshot with Talos for the midgard edge worker: boots a
# throwaway server into rescue mode, dd's the Image Factory disk image onto
# /dev/sda, snapshots it. terraform/hetzner.tf picks the snapshot up by label.
#
# Run (dev shell): HCLOUD_TOKEN=$(bao kv get -field=token secret/hcloud) \
#   packer init packer && packer build packer/
#
# Re-run on talos_version bumps; the schematic is midgard-specific (tailscale
# extension + -selinux, NO metal args / home hardware extensions). Regenerate
# the id after changing the schematic:
#   curl -X POST https://factory.talos.dev/schematics \
#     -d '{"customization":{"extraKernelArgs":["-selinux"],"systemExtensions":{"officialExtensions":["siderolabs/tailscale"]}}}'

packer {
  required_plugins {
    hcloud = {
      source  = "github.com/hetznercloud/hcloud"
      version = ">= 1.6.0"
    }
  }
}

variable "talos_version" {
  type = string
  # renovate: image=ghcr.io/siderolabs/talosctl
  default = "v1.13.5"
}

variable "schematic_id" {
  type    = string
  default = "c3203b75a4828ec40dfaec94dc936ea329ace3bf9ed45b336f517f5f6ec989df"
}

locals {
  image_url = "https://factory.talos.dev/image/${var.schematic_id}/${var.talos_version}/hcloud-amd64.raw.xz"
}

source "hcloud" "talos" {
  image         = "debian-12"
  rescue        = "linux64"
  location      = "fsn1"
  server_type   = "cx23"
  ssh_username  = "root"
  snapshot_name = "talos-${var.talos_version}"

  snapshot_labels = {
    os             = "talos"
    talos_version  = var.talos_version
    schematic_hint = substr(var.schematic_id, 0, 8)
  }
}

build {
  sources = ["source.hcloud.talos"]

  provisioner "shell" {
    inline = [
      "wget -q -O /tmp/talos.raw.xz '${local.image_url}'",
      "xz -dc /tmp/talos.raw.xz | dd of=/dev/sda bs=4M conv=fsync status=progress",
      "sync",
    ]
  }
}
