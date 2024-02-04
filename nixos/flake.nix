{
  inputs = {
    nixpkgs.url = "nixpkgs/nixos-unstable";
    nixpkgs-wsl.url = "github:nix-community/NixOS-WSL";

    deploy-rs.url = "github:serokell/deploy-rs";
  };
  outputs = { self, nixpkgs, nixpkgs-wsl, deploy-rs }: let
    kubeMasterIP = "192.168.178.210";
    kubeMasterToken = "K10b05f385da6dc1ca3c25c7fe6ac0dbbfc2e0d7d6986d42dac872c4a0b35411c7e::server:3d179dbdfbeb24ec278a306b5d64919c";
 in {
    nixosConfigurations = let 
      kubeMaster = clusterInit: nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        modules = [ 
            nixpkgs.nixosModules.notDetected
            ./k8s.nix
            ./hardware-configuration.nix
            ./proxmox.nix
            ./configuration.nix 
            ({ config, pkgs, ... }: {
              services.k3s.role = "server";
              services.k3s.extraFlags = " --default-local-storage-path /root/k3s/ --disable-helm-controller --etcd-arg heartbeat-interval=1500 --etcd-arg election-timeout=15000 --etcd-arg snapshot-count=1000";
              services.k3s.token = "${kubeMasterToken}";
              services.k3s.serverAddr = "https://${kubeMasterIP}:6443";
              services.k3s.clusterInit = clusterInit;
            })
        ];
      };
    in {
      munin = kubeMaster true;
      hugin = kubeMaster false;
      odin = kubeMaster false;

      wsl = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        modules = [ 
          nixpkgs.nixosModules.notDetected
            nixpkgs-wsl.nixosModules.wsl
            ./k8s.nix
            ./wsl-configuration.nix
            ./configuration.nix 
            ({ config, pkgs, ... }: {
              services.openiscsi.enable = true; # WSL2 doesn't have openiscsi in kernel
              services.k3s.role = "agent";
              services.k3s.token = "${kubeMasterToken}";
              services.k3s.serverAddr = "https://${kubeMasterIP}:6443";
            })
        ];
      };
    };

    deploy.nodes = {
      hugin = {
        hostname = "hugin";
        fastConnection = true;
        profiles = {
          system = {
            sshUser = "diverofdark";
            path = deploy-rs.lib.x86_64-linux.activate.nixos self.nixosConfigurations.hugin;
            user = "root";
          };
        };
      };

      munin = {
        hostname = "munin";
        fastConnection = true;
        profiles = {
          system = {
            sshUser = "diverofdark";
            path = deploy-rs.lib.x86_64-linux.activate.nixos self.nixosConfigurations.munin;
            user = "root";
          };
        };
      };

      odin = {
        hostname = "odin";
        fastConnection = true;
        profiles = {
          system = {
            sshUser = "diverofdark";
            path = deploy-rs.lib.x86_64-linux.activate.nixos self.nixosConfigurations.hugin;
            user = "root";
          };
        };
      };

      wsl = {
        hostname = "localhost";
        fastConnection = true;
        profiles = {
          system = {
            sshUser = "diverofdark";
            path = deploy-rs.lib.x86_64-linux.activate.nixos self.nixosConfigurations.wsl;
            user = "root";
          };
        };
      };
    };



    checks = builtins.mapAttrs (system: deployLib: deployLib.deployChecks self.deploy) deploy-rs.lib;
  };
}
