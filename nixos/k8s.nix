{ config, pkgs, ... }:
let
 kubeMasterIP = "192.168.178.210";
 kubeMasterHostname = "munin";
 kubeMasterAPIServerPort = 6443;
in
{
  environment.systemPackages = with pkgs; [
       k9s
    ];

  services.k3s = {
    enable = true;
    package = pkgs.k3s_1_29;
    role = "server";
    clusterInit = true;
    extraFlags = "--docker --default-local-storage-path /root/k3s/ --disable-helm-controller";
  };
}
