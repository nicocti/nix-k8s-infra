# nix-k8s-infra

> tl;dr:
>
> This project wraps lightweight Kubernetes  components like networking, storage, and a full observability stack with Nix for greater automation and parameterization.

This project comes from the will to publish my current k3s configuration. It provides a reproducible configuration for a home lab running k3s on 4 Raspberry Pi devices.

## Getting started

### Deploying manifests

You can generate Kubernetes manifests as a Nix derivation. The derivation will be symlinked locally as a `./result` file. Use the following command to build the manifests:

```sh
nix build -f default.nix --arg pkgs 'import <nixpkgs> {}' --argstr domain 'my.domain' manifests.grafana
```

- Arguments may need to be changed depending on the targeted deployment;
- the `pkgs` argument allows for *"bring your own"* Nix channel;
- the `manifests.*` derivations contain the deployable Kubernetes YAML files;
- the `charts.*` derivations contain the raw Helm charts used to generate the manifests.

### Running operations

Some operations are automated using Nushell scripts, which are wrapped in Nix. You can run them with the following command:

```sh
nix run -f run.nix --arg pkgs 'import <nixpkgs> {}' 'listNodes'
```

## Design choices

This setup is optimized for low-end devices with locally attached storage. It uses an S3-compatible block storage, distributed across all nodes for high availability.

- Cilium is used as the CNI for its eBPF capabilities;
- Garage is used as the object storage provider;
- InfluxDB 3 is used as the OLAP database, leveraging Garage for its underlying storage;
- OpenTelemetry collector is used for observability data collection to InfluxDB;
- Grafana is connected to InfluxDB for data visualization and alerting.

## Implementation details

I didn't want to share sensitive data, so I ended up wrapping my helm values files in Nix, which I wanted to learn.

I chose not to use flakes as I'm not convinced by their approach, but it leads to painful command lines. We'll see.

I used nushell scripts to automatize some `kubectl` commands to avoid shell syntax for better readability.
