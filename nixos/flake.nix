{
  inputs = {
    nixpkgs.url = "nixpkgs/nixos-unstable";
    nixpkgs-wsl.url = "github:nix-community/NixOS-WSL";

    kubenix.url = "github:hall/kubenix";
    
    agenix.url = "github:ryantm/agenix";
    deploy-rs.url = "github:serokell/deploy-rs";
  };
  outputs = { self, kubenix, nixpkgs, nixpkgs-wsl, agenix, deploy-rs }@inputs: let
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

      kubernetesInitConfig = arch: kubenix.evalModules.${arch} {
        module = { kubenix, ... }: {
          imports = [ kubenix.modules.helm ];

          kubernetes.helm.releases.argocd = {
              chart = kubenix.lib.helm.fetch {
                repo = "https://argoproj.github.io/argo-helm";
                chart = "argo-cd";
                version = "6.6.0";
                sha256 = "iolvDY7v7YetylQdvFDpTf9OcnAaKpexDaPrni/utcI=";
              };
              namespace = "argocd";

              # arbitrary attrset passed as values to the helm release
              values = {
                config.global.domain = "argo.k8s.kirillorlov.pro";
                
                redis-ha.enabled = false;

                controller.replicas = 1;

                server.autoscaling.enabled = false;
                server.autoscaling.minReplicas = 1;

                repoServer.autoscaling.enabled = false;
                repoServer.autoscaling.minReplicas = 1;

                applicationSet.replicas = 1;
              };
            };
          };
      };
 in {
    nixosConfigurations = {
      wsl = mkSystem "x86_64-linux" [
        nixpkgs-wsl.nixosModules.wsl
#        ./k8s.nix
        ./wsl-configuration.nix
        ({ config, pkgs, ... }: {
          boot.binfmt.emulatedSystems = [ "aarch64-linux" ];
        })
      ];

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

          environment.etc."kubenix-namespaces.yaml".text = builtins.readFile ./k3s-ns.yaml;
          environment.etc."kubenix.yaml".source = (kubernetesInitConfig "x86_64-linux").config.kubernetes.resultYAML;

          system.activationScripts.kubenix.text = ''
            ln -sf /etc/kubenix-namespaces.yaml /var/lib/rancher/k3s/server/manifests/kubenix-namespaces.yaml
            ln -sf /etc/kubenix.yaml /var/lib/rancher/k3s/server/manifests/kubenix.yaml
          '';
        })
      ];

      ratatoskr = mkSystem "aarch64-linux" [ ./raspi-configuration.nix ];
    };
    
    deploy.nodes = {
      alfheimr = nodeDef { hostname = "192.168.178.10"; arch = "x86_64-linux"; config = self.nixosConfigurations.alfheimr; };
      
      ratatoskr = nodeDef { hostname = "192.168.178.2"; arch = "aarch64-linux"; config = self.nixosConfigurations.ratatoskr; };
      needle = nodeDef { hostname = "needle"; arch = "x86_64-linux"; config = self.nixosConfigurations.onemix; };
      wsl = nodeDef { hostname = "localhost"; arch = "x86_64-linux"; config = self.nixosConfigurations.wsl; };
    };

    checks = builtins.mapAttrs (system: deployLib: deployLib.deployChecks self.deploy) deploy-rs.lib;
  };
}
