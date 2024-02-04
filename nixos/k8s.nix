{ config, pkgs, ... }:
{
  environment.systemPackages = with pkgs; [
       k9s
    ];

  services.openiscsi.name = "iqn.2020-08.org.linux-iscsi.initiatorhost:kirillorlovhomelab";
  services.openiscsi.enable = true;

  services.k3s = {
    enable = true;
    package = pkgs.k3s_1_29;
    clusterInit = false;
  };
}
