{ config, pkgs, lib, ... }:
{
  services.k3s = {
    enable = true;
    package = pkgs.k3s_1_29;
    role = lib.mkDefault "agent";
    token = "K10b05f385da6dc1ca3c25c7fe6ac0dbbfc2e0d7d6986d42dac872c4a0b35411c7e::server:3d179dbdfbeb24ec278a306b5d64919c";
#    serverAddr = "https://192.168.178.10:6443";
   };
}
