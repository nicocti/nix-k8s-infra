# nix-k8s-infra (WIP)

> tl;dr:
>
> A Nix-based infrastructure for provisioning NixOS hosts and deploying a lightweight Kubernetes stack with networking, storage, and a full observability pipeline.

> **Note:** This project documents my current home lab setup. It is not a fully packaged or turnkey solution. While the goal is to make it easily installable and configurable over time, it currently requires manual adjustments to fit your own environment.

This project provides a reproducible configuration for a home lab running k3s on 4 Raspberry Pi 5 devices. It covers the full stack: NixOS host provisioning (installer image, disk partitioning, encrypted storage, kernel tweaks), Kubernetes manifest generation from Helm charts, and cluster bootstrap automation. Everything is built with Nix from a single source of truth.

## Design choices

The hosts run NixOS with LUKS-encrypted disks and FIDO2-based unlock, with partitioning managed by disko. A custom Raspberry Pi 5 kernel is built from the official sources with compatibility fixes.

The Kubernetes layer is optimized for low-end devices with locally attached storage. It relies on S3-compatible object storage distributed across all nodes for high availability.

- Cilium is used with native routing for maximum performance and minimal overhead;
- Garage is used as the object storage provider;
- InfluxDB 3 is used as the OLAP database, leveraging Garage for its underlying storage;
- OpenTelemetry collector handles observability data collection, deployed as both a daemonset (per-node metrics and logs) and a central deployment (cluster-level metrics and events);
- Grafana is connected to InfluxDB for data visualization and alerting.

Kubernetes manifests are generated from Helm charts as Nix derivations. Bootstrap operations such as CA setup, storage layout, and database provisioning are scripted in Nushell and wrapped as Nix derivations.

This project intentionally does not use Nix flakes (as much as possible). Dependencies are pinned with npins instead.

## Project structure

```
.
├── default.nix              # Main entry point: hosts, manifests, and charts derivations
├── config.nix               # Shared configuration (domain, IPs, etc.)
├── lib.nix                  # Helm chart pulling and manifest building helpers
├── run.nix                  # Runnable bootstrap scripts (setupCA, applyGarageLayout, etc.)
├── cilium/                  # Cilium CNI configuration
├── garage/                  # Garage S3 storage configuration and patches
├── grafana/                 # Grafana dashboard configuration
├── influxdb/                # InfluxDB 3 configuration
├── opentelemetry/           # OpenTelemetry collector (daemonset + deployment)
├── hosts/                   # NixOS host configuration (k3s, disko, etc.)
├── installer/               # NixOS SD card installer image for Raspberry Pi
└── npins/                   # Pinned Nix dependencies
```

## Configuration

The `config.nix` file contains the shared parameters used across the project:

- `domain`: the base ingress domain, must resolved to the rProxyIP;
- `cilium.rproxyIp`: the IP address assigned to the reverse proxy;
- `cilium.ipPoolStart` / `cilium.ipPoolStop`: the L2-announced load balancer IP range;
- `influxdb.email`: the email address used for InfluxDB home license registration.

## Hosts setup

NixOS configurations are available as Nix derivations. The built derivation is symlinked locally as `./result`. Use the following command to build:

```sh
nix build -f default.nix --print-out-paths installer
```

- the `installer` derivation outputs a ready-to-use NixOS installer image for Raspberry Pi devices;
- the `kernel` derivation outputs a custom RaspberryPi 5 Linux kernel (bcm2512) with 4K pages and 48 VA bits for compatibility reasons;
- the `disko` derivation outputs the disko script, which is used to partition and format the USB-attached disk on the hosts. The partition layout in `hosts/disko.nix` must be adapted to your own disk setup before running;
- the `toplevel` derivation outputs the top-level configuration for the hosts, representing the full NixOS system.

### Raspberry Pi hosts installation

Build the NixOS installer image, flash it onto an SD card, and boot the Raspberry Pi from it:

```sh
unzstd "$(SSID="{SSID}" PASS="{PASS}" nix build --print-out-paths --builders 'ssh://nixos@{HOST} aarch64-linux' --option builders-use-substitutes true -f default.nix installer)/sd-image/nixos-image-rpi5-kernel.img.zst" -o rpi5.img
sudo dd if=rpi5.img of={usbdevice} bs=10MB oflag=dsync status=progress
# Find the running installer on the LAN:
sudo nmap -p 22 --open 192.168.0.0/24
```

SSH into the installer, copy the NixOS host configuration over, and install the system:

```sh
scp -r . nixos@{HOST}:
sudo $(nix build --print-out-paths -f default.nix disko)
sudo mkdir -p /mnt/etc/nixos
sudo cp -a npins /mnt/etc/
sudo cp -a hosts/* /mnt/etc/nixos/
sudo nixos-install --root /mnt  --no-root-passwd --no-channel-copy
# Choose a LUKS key slot method, otherwise it won't reboot:
sudo systemd-cryptenroll /dev/sda3 --fido2-device=auto --fido2-with-client-pin=no --unlock-key-file=/nix/store/
systemd-cryptenroll /dev/sda3 --wipe-slot=0
```

### Maintenance

Full package upgrades:

```sh
sudo npins -d /etc/npins upgrade
sudo npins -d /etc/npins update
sudo nixos-rebuild switch
```

## Kubernetes setup

Kubernetes manifests are available as Nix derivations. The built derivation is symlinked locally as `./result`. Use the following command to build a manifest:

```sh
nix build -f default.nix --arg pkgs 'import <nixpkgs> {}' manifests.grafana
```

- Arguments may need to be adjusted depending on the target deployment;
- the `pkgs` argument allows for _"bring your own"_ Nix channel;
- the `manifests.*` derivations contain the deployable Kubernetes YAML files;
- the `charts.*` derivations contain the raw Helm charts used to generate the manifests.

### Bootstrap operations

Some operations are wrapped as runnable Nix derivations. The full bootstrap sequence is:

```sh
kubectl create ns cilium garage influxdb grafana otel
nix run -f run.nix --arg pkgs 'import <nixpkgs> {}' setupCA
kubectl apply -f $(nix build -f default.nix --arg pkgs 'import <nixpkgs> {}' manifests.cilium)
kubectl apply -f $(nix build -f default.nix --arg pkgs 'import <nixpkgs> {}' manifests.garage)
nix run -f run.nix --arg pkgs 'import <nixpkgs> {}' applyGarageLayout
kubectl apply -f $(nix build -f default.nix --arg pkgs 'import <nixpkgs> {}' manifests.influxdb)
nix run -f run.nix --arg pkgs 'import <nixpkgs> {}' setupInfluxDB
kubectl apply -f $(nix build -f default.nix --arg pkgs 'import <nixpkgs> {}' manifests.grafana)
kubectl apply -f $(nix build -f default.nix --arg pkgs 'import <nixpkgs> {}' manifests.opentelemetry)
```

### Ingress hostnames

Once deployed, the following services are exposed via Cilium ingress (where `{domain}` is the value of `domain` in `config.nix`):

| Service   | Hostname                       |
| --------- | ------------------------------ |
| Hubble UI | `hubble.{domain}`              |
| Garage S3 | `s3.{domain}`, `*.s3.{domain}` |
| InfluxDB  | `influxdb.{domain}`            |
| Grafana   | `grafana.{domain}`             |

## Reference

### npins setup

How npins was initially set up:

```sh
npins add github -b modules-with-keys-25.11 nvmd nixpkgs
npins add github nix-community disko --at latest
npins add github -b main nvmd nixos-raspberrypi
```

### Wiping the USB-attached disk

To wipe the USB-attached disk before reinstalling:

```sh
sudo cryptsetup erase /dev/disk/by-partlabel/disk-main-luks
sudo dd if=/dev/zero of=/dev/sda3 bs=1M count=100
sudo wipefs --all -f /dev/sda
sudo sgdisk --zap-all /dev/sda
```

## TODO

- document patches and tricky customizations (kernel, nixos, etc.)
- replay everything from scratch to make sure everything is covered and documented
- improve automation and configurability (use colmena, nixos-anywhere or nixops4 for host provisioning?)
- improve secret management (use sops-nix, agenix, ragenix?)
- replace manual minica setup with automatic certificate management (cert-manager with LE?)
