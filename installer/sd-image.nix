{
  config,
  pkgs,
  nixos-raspberrypi,
  ssid ? "",
  pwd ? "",
  sshPublicKey ? "",
  ...
}: {
  nix.settings = {
    trusted-users = ["root" "nixos"];
    experimental-features = ["nix-command" "flakes"];
    substituters = [
      "https://nixos-raspberrypi.cachix.org"
    ];
    trusted-substituters = [
      "https://nixos-raspberrypi.cachix.org"
    ];
    trusted-public-keys = [
      "nixos-raspberrypi.cachix.org-1:4iMO9LXa8BqhU+Rpg6LQKiGa2lsNh/j2oiYLNOQ5sPI="
    ];
  };
  imports = [
    nixos-raspberrypi.nixosModules.raspberry-pi-5.base
    nixos-raspberrypi.nixosModules.raspberry-pi-5.page-size-16k
    nixos-raspberrypi.nixosModules.trusted-nix-caches
    nixos-raspberrypi.nixosModules.nixpkgs-rpi
    nixos-raspberrypi.nixosModules.sd-image
    "${nixos-raspberrypi}/modules/installer/raspberrypi-installer.nix"
  ];
  nixpkgs.overlays = [
    nixos-raspberrypi.overlays.bootloader
    nixos-raspberrypi.overlays.pkgs
    nixos-raspberrypi.overlays.vendor-pkgs
    nixos-raspberrypi.overlays.jemalloc-page-size-16k
    nixos-raspberrypi.overlays.vendor-firmware
    nixos-raspberrypi.overlays.vendor-kernel
    nixos-raspberrypi.overlays.kernel-and-firmware
    nixos-raspberrypi.overlays.libpisp-default-config-path
  ];

  console.keyMap = "fr";
  users.users.nixos.openssh.authorizedKeys.keys = [
    sshPublicKey
  ];
  users.users.root.openssh.authorizedKeys.keys = [
    sshPublicKey
  ];

  networking = {
    hostName = "installer";
    networkmanager.ensureProfiles.profiles.home = {
      connection = {
        id = "home";
        type = "wifi";
        autoconnect = true;
      };
      wifi = {
        ssid = ssid;
        mode = "infrastructure";
      };
      wifi-security = {
        key-mgmt = "wpa-psk";
        psk = pwd;
      };
      ipv4.method = "auto";
      ipv6.method = "auto";
    };
  };

  environment.systemPackages = with pkgs; [
    tree
    micro
    npins
  ];

  system.nixos.tags = let
    cfg = config.boot.loader.raspberry-pi;
  in [
    "raspberry-pi-${cfg.variant}"
    cfg.bootloader
    config.boot.kernelPackages.kernel.version
  ];
}
