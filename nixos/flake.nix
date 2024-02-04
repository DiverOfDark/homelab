{
  inputs = {
    nixpkgs.url = "nixpkgs/nixos-unstable";
    nixpkgs-wsl.url = "github:nix-community/NixOS-WSL";

    deploy-rs.url = "github:serokell/deploy-rs";
  };
  outputs = { self, nixpkgs, nixpkgs-wsl, deploy-rs }: {
    nixosConfigurations = let 
      kubeMaster = hostname: nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        nixos-modules = [ 
            nixpkgs.nixosModules.notDetected
            ./k8s.nix
            ./hardware-configuration.nix
            ./proxmox.nix
            ./configuration.nix 
        ];
      };
    in {
      #munin = kubeMaster "";
      #hugin = kubeMaster "";
      #odin = kubeMaster "";

      wsl = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        modules = [ 
          nixpkgs.nixosModules.notDetected
            nixpkgs-wsl.nixosModules.wsl
            ./k8s.nix
            ./wsl-configuration.nix
            ./configuration.nix 
            ({ config, pkgs, ... }: {
              services.k3s.role = "agent";
            })
        ];
      };
    };

    deploy.nodes.wsl = {
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

    checks = builtins.mapAttrs (system: deployLib: deployLib.deployChecks self.deploy) deploy-rs.lib;
  };
}
