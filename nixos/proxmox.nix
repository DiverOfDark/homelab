{ config, pkgs, ... }:
{
  systemd.services."cloud-init-local".before = [ "network-pre.target" "systemd-networkd.service" "dhcpcd.service" ];
  systemd.services."nixos-cloud-cleanup" = {
    description = "delete hostname";
    serviceConfig.PassEnvironment = "DISPLAY";
    script = ''
      rm -f /var/lib/cloud/data/set-hostname
      rm -f /etc/hostname
    '';
    wantedBy = [ "cloud-init-local.service" "cloud-init.service" ]; # starts after login
  };
  systemd.network = {
    enable = true;
    wait-online = {
      anyInterface = true;
      timeout = 0;
    };
  };
  
  networking = {
    usePredictableInterfaceNames = true;
    useDHCP = true;
    useNetworkd = true;
    dhcpcd.enable = true;
    firewall.enable = false;
    defaultGateway = { address = "192.168.178.1"; interface = "eth0"; };
  };

  services = {
    qemuGuest.enable = true;
    resolved = {
      enable = false;
      fallbackDns = [ "192.168.178.1" ];
    };
    cloud-init = { 
      enable = true;
      network.enable = true;
      config = ''
       output: { all: "> /var/log/cloud-init-output.log" }
       cloud_init_modules:
        - seed_random
        - growpart
        - resizefs
        - set_hostname
        - update_hostname
        - resolv_conf
       cloud_config_modules:
         - disk_setup
         - mounts
         - set-passwords
         - ssh
       cloud_final_modules: []
       disable_root: false
       preserve_hostname: false
       create_hostname_file: false
       system_info:
        distro: nixos
        network:
         renderers:
         - networkd
'';
    };

  };
}
