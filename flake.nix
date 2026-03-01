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

            # Talos — config rendered by Ansible to /tmp/talos/
            export TALOSCONFIG=/tmp/talos/talosconfig

            # OpenTofu / Kubernetes — override in_cluster_config for local use
            export KUBE_CONFIG_PATH=~/.kube/config

            export TF_VAR_kube_config=~/.kube/config
            export TF_CLI_ARGS_init="-backend-config=$PWD/terraform/config.kubernetes.tfbackend"

            # OpenBao
            export BAO_ADDR=https://openbao.kirillorlov.pro

            # OpenTofu — required TF_VAR_* for terraform/cloudflare.tf
            # Set these in your environment or via a sops-encrypted shell snippet:
            export TF_VAR_cloudflare_email=`bao kv get -field=email secret/cloudflare`
            export TF_VAR_cloudflare_api_key=`bao kv get -field=api_key secret/cloudflare`
            export TF_VAR_cloudflare_api_token=`bao kv get -field=api_token secret/cloudflare`
            export TF_VAR_tunnel_secret=`bao kv get -field=tunnel_secret secret/cloudflare`

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
