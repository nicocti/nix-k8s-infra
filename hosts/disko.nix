{
  pkgs,
  lib,
  ...
}: let
  luksBootstrapKey = pkgs.writeText "luks-bootstrap-key" "remove-before-production";
  firmwarePartition = lib.recursiveUpdate {
    priority = 1;
    type = "0700"; # Microsoft basic data
    attributes = [
      0 # Required Partition
    ];
    size = "1024M";
    content = {
      type = "filesystem";
      format = "vfat";
      mountOptions = [
        "noatime"
        "fmask=0022"
        "dmask=0022"
      ];
    };
  };

  espPartition = lib.recursiveUpdate {
    type = "EF00"; # EFI System Partition (ESP)
    attributes = [
      2 # Legacy BIOS Bootable, for U-Boot to find extlinux config
    ];
    size = "1024M";
    content = {
      type = "filesystem";
      format = "vfat";
      mountOptions = [
        "noatime"
        "umask=0077"
      ];
    };
  };
in {
  fileSystems = {
    # mount early enough in the boot process so no logs will be lost
    "/var/log".neededForBoot = true;
  };

  disko.devices = {
    disk.main = {
      device = "/dev/sda";
      type = "disk";
      content = {
        type = "gpt";
        partitions = {
          FIRMWARE = firmwarePartition {
            label = "FIRMWARE";
            content.mountpoint = "/boot/firmware";
          };

          ESP = espPartition {
            label = "ESP";
            content.mountpoint = "/boot";
          };
          luks = {
            size = "100%";
            content = {
              type = "luks";
              name = "crypted";
              extraOpenArgs = [];
              settings = {
                allowDiscards = true;
                keyFile = toString luksBootstrapKey;
              };
              content = {
                type = "lvm_pv";
                vg = "pool";
              };
            };
          };
        };
      };
    };
    lvm_vg = {
      pool = {
        type = "lvm_vg";
        lvs = {
          root = {
            size = "100G";
            content = {
              type = "filesystem";
              format = "ext4";
              mountpoint = "/";
              mountOptions = [
                "defaults"
              ];
            };
          };
          log = {
            size = "10G";
            content = {
              type = "filesystem";
              format = "xfs";
              mountpoint = "/var/log";
            };
          };
          data = {
            size = "100G";
            content = {
              type = "filesystem";
              format = "xfs";
              mountpoint = "/data";
            };
          };
          raw = {
            size = "100%";
          };
        };
      };
    };
  };
}
