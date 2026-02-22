{
  config,
  pkgs,
  lib,
  ...
}: let
  hostname = "";
  username = "";
  sshPublicKey = "";
  k3sToken = "";
  sources = import ../npins;
  disko = sources.disko;
  nixos-raspberrypi = builtins.getFlake "github:nvmd/nixos-raspberrypi/refs/tags/v1.20260125.0";
in {
  imports = [
    nixos-raspberrypi.nixosModules.raspberry-pi-5.base
    # nixos-raspberrypi.nixosModules.raspberry-pi-5.page-size-16k
    nixos-raspberrypi.nixosModules.trusted-nix-caches
    nixos-raspberrypi.nixosModules.nixpkgs-rpi
    "${disko}/module.nix"
    ./disko.nix
  ];

  nix = {
    nixPath = ["nixpkgs=${sources.nixpkgs}" "nixos-config=/etc/nixos/configuration.nix"];
    settings = {
      trusted-users = ["root" username];
      cores = 2;
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
  };

  nixpkgs = {
    hostPlatform = "aarch64-linux";
    overlays = [
      nixos-raspberrypi.overlays.pkgs
      nixos-raspberrypi.overlays.vendor-pkgs
      nixos-raspberrypi.overlays.bootloader
      nixos-raspberrypi.overlays.vendor-kernel
      nixos-raspberrypi.overlays.vendor-firmware
      nixos-raspberrypi.overlays.kernel-and-firmware
      # nixos-raspberrypi.overlays.jemalloc-page-size-16k
      nixos-raspberrypi.overlays.libpisp-default-config-path
    ];
  };

  hardware = {
    enableRedistributableFirmware = true;
    raspberry-pi.config = {
      all = {
        options = {
          # https://www.raspberrypi.com/documentation/computers/config_txt.html
          cmdline = {
            enable = true;
            value = "cmdline.txt";
          };
          usb_max_current_enable = {
            enable = true;
            value = 1;
          };
        };
        # https://github.com/raspberrypi/linux/blob/a1d3defcca200077e1e382fe049ca613d16efd2b/arch/arm/boot/dts/overlays/README#L132
        base-dt-params = {
          # https://www.raspberrypi.com/documentation/computers/raspberry-pi.html
          pciex1 = {
            enable = true;
            value = "on";
          };
          pciex1_gen = {
            enable = true;
            value = "3";
          };
        };
      };
    };
  };

  time.timeZone = "UTC";
  boot = {
    tmp.useTmpfs = true;
    initrd.systemd.enable = true;
    initrd.luks.devices.crypted = {
      crypttabExtraOpts = ["fido2-device=auto"];
    };
    # kernelPackages = pkgs.linuxAndFirmware.default.linuxPackages_rpi4;
    kernelPatches = [
      {
        name = "4k-pages";
        patch = null;
        structuredExtraConfig = {
          ARM64_4K_PAGES = lib.kernel.yes;
          ARM64_16K_PAGES = lib.kernel.no;
          ARM64_64K_PAGES = lib.kernel.no;
          ARM64_VA_BITS_48 = lib.kernel.yes;
          ARM64_VA_BITS_39 = lib.kernel.no;
        };
      }
    ];
    loader.raspberry-pi.bootloader = "kernel";
    kernelParams = [
      "cgroup_enable=memory"
      "cgroup_memory=1"
    ];
    kernelModules = [
      "vxlan" # for Cilium
      "wireguard" # for Cilium encrypted tunnels
    ];
    kernel.sysctl = {
      # Basic forwarding (required by Cilium)
      "net.ipv4.ip_forward" = 1;
      "net.ipv6.conf.all.forwarding" = 1;
      # Reverse path filtering (required by Cilium)
      "net.ipv4.conf.all.rp_filter" = 0;
      "net.ipv4.conf.default.rp_filter" = 0;
      # ARP settings for multi-interface/VXLAN (required by Cilium)
      "net.ipv4.conf.all.arp_ignore" = 1;
      "net.ipv4.conf.all.arp_announce" = 2;
    };
  };

  environment.systemPackages = with pkgs; [
    npins
    micro
    tree
    libfido2
    fuse-overlayfs
  ];

  users.users = {
    ${username} = {
      isNormalUser = true;
      initialHashedPassword = "";
      extraGroups = [
        "wheel"
        "video"
        "networkmanager"
      ];
      openssh.authorizedKeys.keys = [
        sshPublicKey
      ];
    };
    root = {
      initialHashedPassword = "";
      openssh.authorizedKeys.keys = [
        sshPublicKey
      ];
    };
  };

  console.keyMap = "fr";
  security.sudo = {
    enable = true;
    wheelNeedsPassword = false;
  };
  services = {
    udev.extraRules = ''
      # Ignore partitions with "Required Partition" GPT partition attribute
      # On our RPis this is firmware (/boot/firmware) partition
      ENV{ID_PART_ENTRY_SCHEME}=="gpt", \
        ENV{ID_PART_ENTRY_FLAGS}=="0x1", \
        ENV{UDISKS_IGNORE}="1"
    '';
    udev.packages = [pkgs.yubikey-personalization];
    pcscd.enable = true;
    openssh = {
      enable = true;
      ports = [22];
      settings = {
        PasswordAuthentication = false;
        AllowUsers = ["root" username];
        UseDns = true;
        X11Forwarding = false;
        PermitRootLogin = "prohibit-password"; # "yes", "without-password", "prohibit-password", "forced-commands-only", "no"
      };
    };

    k3s = {
      enable = true;
      role =
        if hostname == "VERT"
        then "agent"
        else "server";
      token = k3sToken;
      disable =
        if hostname == "VERT"
        then []
        else [
          "traefik"
          "servicelb"
        ];
      nodeName = hostname;
      extraFlags =
        if hostname == "VERT"
        then []
        else [
          "--flannel-backend=none"
          "--disable-kube-proxy"
          "--disable-network-policy"
          "--disable-cloud-controller"
          "--secrets-encryption"
          "--secrets-encryption-provider=secretbox"
          "--default-local-storage-path=/data"
          # "--snapshotter=fuse-overlayfs"
        ];
      clusterInit =
        if hostname == "ROUGE"
        then true
        else false;
      serverAddr =
        if hostname != "ROUGE"
        then "https://192.168.0.101:6443"
        else "";
    };
  };

  networking = {
    hostName = hostname;
    useNetworkd = true;
    firewall = {
      enable = true;
      checkReversePath = false;
      extraInputRules = ''
        meta mark & 0x00000f00 == 0x00000200 accept comment "Accept Cilium proxy traffic"
      '';
      trustedInterfaces = ["cilium_host" "cilium_net"];
      allowedTCPPorts = [
        22 # ssh
        443 # http
        2379 # etcd
        2380 # etcd
        6443 # k3s API
        10250 # kubelet API
        4240 # cilium health checks
        4250 # cilium auth
        4244 # hubble server
        4245 # hubble relay
        9962 # cilium-agent metrics
        9963 # cilium-operator metrics
        9964 # cilium-envoy metrics
      ];
      allowedUDPPorts = [
        5353 # mdns
        8472 # cilium VXLAN
        51871 # cilium wireguard tunnels
      ];
    };
    nftables.enable = true;
  };

  # This comment was lifted from `srvos`
  # Do not take down the network for too long when upgrading,
  # This also prevents failures of services that are restarted instead of stopped.
  # It will use `systemctl restart` rather than stopping it with `systemctl stop`
  # followed by a delayed `systemctl start`.
  systemd.services = {
    systemd-networkd.stopIfChanged = false;
    systemd-resolved.stopIfChanged = false;
  };

  system.nixos.tags = let
    cfg = config.boot.loader.raspberry-pi;
  in [
    "raspberry-pi-${cfg.variant}"
    cfg.bootloader
    config.boot.kernelPackages.kernel.version
  ];
  system.stateVersion = config.system.nixos.release;
}
