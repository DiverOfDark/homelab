# Do not modify this file!  It was generated by ‘nixos-generate-config’
# and may be overwritten by future invocations.  Please make changes
# to /etc/nixos/configuration.nix instead.
{ config, lib, pkgs, modulesPath, ... }:

{
  imports =
    [ (modulesPath + "/installer/scan/not-detected.nix")
  ];

  boot = {
    supportedFilesystems = [ "ntfs" ];
    initrd.availableKernelModules = [ "xhci_pci" "ahci" "ohci_pci" "ehci_pci" "usb_storage" "usbhid" "sd_mod" ];
    initrd.kernelModules = [ ];

    kernelModules = [ "kvm-amd" ];
    kernelPackages = pkgs.linuxPackages_latest;

    kernel.sysctl."net.ipv4.ip_unprivileged_port_start" = 80;
    
    extraModulePackages = [ ];
    
    loader.efi.canTouchEfiVariables = false;
    loader.systemd-boot = {
      enable = true;
      configurationLimit = 3;
    };
    loader.grub = {
      efiSupport = true;
      efiInstallAsRemovable = true;
      device = "nodev";
    };
  };

  age.secrets.k3s-secrets.file = secrets/k3s-secrets.age; 

  environment.etc."kubenix.yaml".text = builtins.readFile ./k3s-ns.yaml;
  environment.etc."kubenix-secrets.yaml".source = config.age.secrets.k3s-secrets.path;

  system.activationScripts.kubenix.text = ''
    ln -sf /etc/kubenix.yaml /var/lib/rancher/k3s/server/manifests/kubenix.yaml
    ln -sf /etc/kubenix-secrets.yaml /var/lib/rancher/k3s/server/manifests/kubenix-secrets.yaml
  '';

  networking.hostName = "alfheimr"; # Define your hostname.

  networking.interfaces.eth0.useDHCP = lib.mkForce false;
  networking.interfaces.eth0.ipv4.addresses = [ {
    address = "192.168.178.10";
    prefixLength = 24;
  } ];
  networking.defaultGateway = "192.168.178.1";
  networking.nameservers = [ "192.168.178.2" ];
  
  networking.firewall.enable = false;

  fileSystems."/" =
    { device = "/dev/disk/by-uuid/4a151618-95d5-4550-95dd-ac23b24628cb";
      fsType = "btrfs";
      options = [ "subvol=root" "compress=zstd" ];
    };

  fileSystems."/nix" =
    { device = "/dev/disk/by-uuid/4a151618-95d5-4550-95dd-ac23b24628cb";
      fsType = "btrfs";
      options = [ "subvol=nix" "compress=zstd" ];
    };

  fileSystems."/boot" =
    { device = "/dev/disk/by-uuid/12CE-A600";
      fsType = "vfat";
    };

  swapDevices = [ ];

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
  hardware.cpu.amd.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;

#  swapDevices = [ {
#     device = "/var/lib/swapfile";
#     size = 4*1024;
#    } 
#  ];
}