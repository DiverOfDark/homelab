{ config, pkgs, ... }:
{
  imports =
    [ # Include the results of the hardware scan.
    ];

  time.timeZone = "Europe/Berlin";

  i18n.defaultLocale = "en_US.UTF-8";
  console = {
    font = "Lat2-Terminus16";
    keyMap = "us";
  };

  users.users = {
    diverofdark = {
      isNormalUser = true;
      extraGroups = [ "wheel" ]; # Enable ‘sudo’ for the user.
      packages = with pkgs; [ ];
      openssh.authorizedKeys.keys = [
        "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQCz5Mz8hwMB+mmNPB3g8NLUNq5SoWzoXRxOlSDQKpaGcPJCJaemXf3BVMFHdy/6pBnsrsD/aaA80ouJd40cu6jEdwy/9Z6VD65N8feNzV2xcdRoHUdAHyjyICkipX8kBTvhU4RznoGQFhunqwORuAhE4+7pEXyRHd/PUfKreYAXVuMGmh1Cs5WHmNLPje1VBdg4BgL9kSZbCkKlUsAp5KeAzvRHnJaCNAUkARDD4Bjdcm36uyctIg06AEMpun6GcEmMGSLoCwjl8S4SUCYbNbXK4mPmrGKS2Vm+tSbc3VH7JZwynHC8HQcAFiuQcXXM/j7UxWCyr8huvPTKILRIaZQZ diverofdark"
      ];
    };
    root.initialHashedPassword = "";
  };

  security.sudo.wheelNeedsPassword = false;

  # List packages installed in system profile. To search, run:
  # $ nix search wget
  environment = {
    loginShellInit = ''
     # disable for user root and non-interactive tools                                                                                
     if [ `id -u` != 0 ]; then                                                                                                        
       if [ "x''${SSH_TTY}" != "x" ]; then                                                                                            
         neofetch                                                                                                         
       fi                                                                                                                             
     fi  
    '';
  
    etc.hostname.enable = false;

    systemPackages = with pkgs; [
      nano
      wget
      htop
      iotop
      mc
      ncdu
      neofetch
      git
      usbutils
      pciutils
      bintools
      dig
    ];
  };

  services = {
    openssh.enable = true;
  };

  system = {
    #copySystemConfiguration = true;
    autoUpgrade = {
      enable = true;
      operation = "switch";
      allowReboot = true;
    };
  };

  nix = {
    optimise.automatic = true;
    gc = {
      automatic = true;
      dates = "weekly";
      options = "--delete-older-than 3d";
    };
  };
  nixpkgs.config.allowUnfree = true;
  
  systemd.extraConfig = ''
    DefaultTimeoutStartSec=300s
  '';

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It's perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "23.05"; # Did you read the comment?

  nix.settings.experimental-features = [ "nix-command" "flakes" ];
  nix.settings.trusted-users = [ "root" "@wheel" ];
}
