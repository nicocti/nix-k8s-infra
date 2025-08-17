{
  pkgs,
  ...
}@args:
let

  pullHelmChart =
    {
      name,
      version,
      repo,
      hash ? pkgs.lib.fakeHash,
      rev ? "",
      path ? "",
      ...
    }:
    if rev != "" then
      pkgs.fetchgit {
        name = "helm-chart-${name}-${version}";
        url = repo;
        rev = rev;
        hash = hash;
        sparseCheckout = [ path ];
        postFetch = ''
          mv $out/${path}/* $out
          ls $out
        '';
      }
    else
      pkgs.stdenv.mkDerivation {
        name = "helm-chart-${name}-${version}";
        nativeBuildInputs = [ pkgs.cacert ];

        phases = [ "installPhase" ];
        installPhase = ''
          export HELM_CACHE_HOME="$TMP/.helm"
          ${pkgs.kubernetes-helm}/bin/helm pull \
          --version "${version}" --repo "${repo}" \
          --untar --untardir $out \
          "${name}"
          mv $out/${name}/* $out
          rm -r $out/*gz
        '';
        outputHashMode = "recursive";
        outputHashAlgo = "sha256";
        outputHash = hash;
      };

  buildHelmChart =
    {
      name,
      helmValues,
      namespace ? name,
      extraManifests ? [ ],
      ...
    }:
    chart:
    pkgs.stdenv.mkDerivation {
      name = "k8s-manifests-${name}";
      values = builtins.toJSON helmValues;
      manifests = builtins.toJSON extraManifests;
      passAsFile = [
        "values"
        "manifests"
      ];

      phases = [ "installPhase" ];
      installPhase = ''
        export HELM_CACHE_HOME="$TMP/.helm"

        ${pkgs.kubernetes-helm}/bin/helm template \
        --namespace "${namespace}" --create-namespace \
        --include-crds --values "$valuesPath" \
        "${name}" "${chart}" > $out

        # Append extra manifests as additional YAML documents if any
        if ${if (builtins.length extraManifests) > 0 then "true" else "false"}; then
          echo "---" >> $out
          ${pkgs.yq-go}/bin/yq -oy -P ".[] | split_doc" $manifestsPath >> $out
        fi
      '';
    };
in
rec {
  cilium = import ./cilium {
    inherit (args)
      domain
      rproxyIp
      k8sApiAddr
      ipPoolStart
      ipPoolStop
      ;
  };
  grafana = import ./grafana { inherit (args) domain; };
  garage = import ./garage { inherit (args) domain; };
  influxfb = import ./influxdb { inherit (args) domain email; };

  test = buildHelmChart garage (pullHelmChart garage);
}
