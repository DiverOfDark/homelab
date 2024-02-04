{ config, pkgs, ... }:
let
 kubeMasterIP = "192.168.178.210";
 kubeMasterToken = "K10b05f385da6dc1ca3c25c7fe6ac0dbbfc2e0d7d6986d42dac872c4a0b35411c7e::server:3d179dbdfbeb24ec278a306b5d64919c";
in
{
  environment.systemPackages = with pkgs; [
       k9s
    ];

  services.openiscsi.name = "iqn.2020-08.org.linux-iscsi.initiatorhost:kirillorlovhomelab";
  services.openiscsi.enable = true;

  services.k3s = {
    enable = true;
    package = pkgs.k3s_1_29;
    role = "agent";
#    role = "server";
#    clusterInit = true;
    #extraFlags = " --default-local-storage-path /root/k3s/ --disable-helm-controller --etcd-arg heartbeat-interval=1500 --etcd-arg election-timeout=15000 --etcd-arg snapshot-count=1000";
    clusterInit = false;
    token = "${kubeMasterToken}";
    serverAddr = "https://${kubeMasterIP}:6443";
  };
}
