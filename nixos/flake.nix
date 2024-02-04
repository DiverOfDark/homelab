{
  inputs = {
    nixpkgs.url = "nixpkgs/nixos-unstable";
    nixpkgs-wsl.url = "github:nix-community/NixOS-WSL";
  };
  outputs = { self, nixpkgs, nixpkgs-wsl }: {
    nixosConfigurations = let 
      kubeMaster = nixpkgs.lib.nixosSystem {
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
      munin = kubeMaster;
      hugin = kubeMaster;
      odin = kubeMaster;

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
  };
}
