{
  description = "Homelab development environment";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs { inherit system; config.allowUnfree = true; };
        pythonEnv = pkgs.python3.withPackages (ps: [
          ps.ansible-core
          ps.mitogen
          ps.jmespath
        ]);
      in {
        devShells.default = pkgs.mkShell {
          name = "homelab";
          packages = [
            pythonEnv

            # Infrastructure as Code
            pkgs.opentofu
            pkgs.packer

            # Kubernetes
            pkgs.kubectl
            pkgs.kubectx
            pkgs.kubernetes-helm
            pkgs.talosctl
            pkgs.argocd
            pkgs.k9s

            # Networking & service mesh
            pkgs.cilium-cli
            pkgs.hubble
            pkgs.cloudflared

            # Secrets & certs
            pkgs.sops
            pkgs.age
            pkgs.openbao
            pkgs.cmctl

            # Backup
            pkgs.velero

            # Cloud providers
            pkgs.hcloud

            # Utilities
            pkgs.yq
            pkgs.dos2unix
            pkgs.pre-commit
          ];
          shellHook = ''
            # Set Mitogen strategy plugins path for Ansible
            export ANSIBLE_STRATEGY_PLUGINS=$(python3 -c "import ansible_mitogen; print(ansible_mitogen.__path__[0] + '/plugins/strategy')" 2>/dev/null || echo "")

            # Aliases
            alias k=kubectl
            alias t=tofu
            alias a=ansible
            alias ta=talosctl

            # Shell completions
            source <(kubectl completion bash)
            source <(talosctl completion bash)
            source <(hcloud completion bash)

            echo ""
            echo "Homelab dev shell ready."
            echo "  IaC:        ansible, tofu, packer"
            echo "  Kubernetes: kubectl, kubectx, helm, talosctl, argocd, k9s"
            echo "  Network:    cilium, hubble, cloudflared"
            echo "  Secrets:    sops, age, bao, cmctl"
            echo "  Backup:     velero"
            echo "  Cloud:      hcloud"
            echo "  Utils:      yq, dos2unix, pre-commit"
            echo ""
          '';
        };
      }
    );
}
