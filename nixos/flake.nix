{
  inputs = {
    nixpkgs.url = "nixpkgs/nixos-unstable";
  };
  outputs = { self, nixpkgs }: {
    nixosConfigurations.munin = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [ 
          nixpkgs.nixosModules.notDetected

          ./configuration.nix 
      ];
    };
    nixosConfigurations.hugin = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [ 
          nixpkgs.nixosModules.notDetected

          ./configuration.nix 
      ];
    };
    nixosConfigurations.odin = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [ 
          nixpkgs.nixosModules.notDetected

          ./configuration.nix 
      ];
    };
  };
}
