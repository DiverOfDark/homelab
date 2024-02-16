{
  inputs = {
    nixpkgs.url = "nixpkgs/nixos-unstable";
    nixpkgs-wsl.url = "github:nix-community/NixOS-WSL";
    
    agenix.url = "github:ryantm/agenix";
    deploy-rs.url = "github:serokell/deploy-rs";
  };
  outputs = { self, nixpkgs, nixpkgs-wsl, agenix, deploy-rs }@inputs: let
      mkSystem = arch: extraModules:
        nixpkgs.lib.nixosSystem rec {
          system = arch;
          modules = [
              inputs.agenix.nixosModules.age
              ./configuration.nix 
              ({ config, pkgs, ... }: {
                  environment.systemPackages = [ agenix.packages.${arch}.default ];
              })
              
              {
                nixpkgs.overlays = [
                  (_:_: { 
                    flakes = inputs;
                    unstable = import inputs.agenix {
                      inherit system;
                      config.allowUnfree = true;
                    };
                  })
                ];
              }
          ] ++ extraModules;
        };

      kubeMaster = clusterInit: mkSystem "x86_64-linux" [
        ./k8s.nix
        ./hardware-configuration.nix
        ./proxmox.nix
        ./configuration.nix 
        ({ config, pkgs, ... }: {
          services.k3s.role = "server";
          services.k3s.extraFlags = " --default-local-storage-path /root/k3s/ --disable-helm-controller --etcd-arg heartbeat-interval=1500 --etcd-arg election-timeout=15000 --etcd-arg snapshot-count=1000";
          services.k3s.clusterInit = clusterInit;
        })
      ];

      nodeDef = {hostname, arch, config}: {
        hostname = "${hostname}";
        fastConnection = true;
        profiles = {
          system = {
            sshUser = "diverofdark";
            path = deploy-rs.lib.${arch}.activate.nixos config;
            user = "root";
            magicRollback = false;
          };
        };
    };
 in {
    nixosConfigurations = {
      wsl = mkSystem "x86_64-linux" [
        nixpkgs-wsl.nixosModules.wsl
        ./k8s.nix
        ./wsl-configuration.nix
        ({ config, pkgs, ... }: {
          boot.binfmt.emulatedSystems = [ "aarch64-linux" ];
        })
      ];

      onemix = mkSystem "x86_64-linux" [
        nixpkgs-wsl.nixosModules.wsl
        ./onemix-configuration.nix
        ./desktop.nix
      ];

      firstMaster = kubeMaster true;
      otherMasters = kubeMaster false;

      ratatoskr = mkSystem "aarch64-linux" [ ./raspi-configuration.nix ];
    };
    
    deploy.nodes = {
      munin = nodeDef { hostname = "munin"; arch = "x86_64-linux"; config = self.nixosConfigurations.firstMaster; };
      hugin = nodeDef { hostname = "hugin"; arch = "x86_64-linux"; config = self.nixosConfigurations.otherMasters; };
      odin  = nodeDef { hostname = "odin"; arch = "x86_64-linux"; config = self.nixosConfigurations.otherMasters; };
      
      ratatoskr = nodeDef { hostname = "ratatoskr"; arch = "aarch64-linux"; config = self.nixosConfigurations.ratatoskr; };
      needle = nodeDef { hostname = "needle"; arch = "x86_64-linux"; config = self.nixosConfigurations.onemix; };
      wsl = nodeDef { hostname = "localhost"; arch = "x86_64-linux"; config = self.nixosConfigurations.wsl; };
    };

    checks = builtins.mapAttrs (system: deployLib: deployLib.deployChecks self.deploy) deploy-rs.lib;
  };
}
