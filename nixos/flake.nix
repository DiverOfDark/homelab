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
  };
}
