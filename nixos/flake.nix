{
  inputs = {
    nixpkgs.url = "nixpkgs/nixos-unstable";

    agenix.url = "github:ryantm/agenix";
    deploy-rs.url = "github:serokell/deploy-rs";
  };
  outputs = { self, nixpkgs, agenix, deploy-rs }@inputs: let
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
      onemix = mkSystem "x86_64-linux" [
        ./onemix-configuration.nix
        ./desktop.nix
      ];

      alfheimr = mkSystem "x86_64-linux" [
        ./alfheimr-configuration.nix
        ./k8s.nix
        ({ config, pkgs, ... }: {
          services.k3s.role = "server";
          services.k3s.extraFlags = " --default-local-storage-path /root/k3s/ --etcd-arg heartbeat-interval=1500 --etcd-arg election-timeout=15000 --etcd-arg snapshot-count=1000";
          services.k3s.clusterInit = true;
        })
      ];

      ratatoskr = mkSystem "aarch64-linux" [ ./raspi-configuration.nix ];
    };
    
    deploy.nodes = {
      alfheimr = nodeDef { hostname = "192.168.178.10"; arch = "x86_64-linux"; config = self.nixosConfigurations.alfheimr; };
      
      ratatoskr = nodeDef { hostname = "192.168.178.2"; arch = "aarch64-linux"; config = self.nixosConfigurations.ratatoskr; };
      needle = nodeDef { hostname = "needle"; arch = "x86_64-linux"; config = self.nixosConfigurations.onemix; };
    };

    checks = builtins.mapAttrs (system: deployLib: deployLib.deployChecks self.deploy) deploy-rs.lib;
  };
}
