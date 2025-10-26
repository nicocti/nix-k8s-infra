{ pkgs }:
rec {
  pullHelmChartFromGit =
    {
      name,
      repo,
      rev,
      path ? "",
      patches ? [ ],
      hash ? pkgs.lib.fakeHash,
      ...
    }:
    pkgs.stdenv.mkDerivation {
      name = "helm-chart-${name}-${rev}";
      phases = [ "unpackPhase" "patchPhase" "installPhase" ];
      src = pkgs.fetchgit {
        name = "helm-chart-sources-${name}-${rev}";
        url = repo;
        rev = rev;
        hash = hash;
        sparseCheckout = [ path ];
      };
      patches = patches;
      installPhase = ''
        mkdir -p $out
        mv ${path}/* $out
      '';
    };

  pullHelmChartFromRepo =
    {
      chart,
      repo,
      version,
      hash ? pkgs.lib.fakeHash,
      ...
    }:
    pkgs.stdenv.mkDerivation {
      name = "helm-chart-${chart}-${version}";
      nativeBuildInputs = [ pkgs.cacert ];

      phases = [ "installPhase" ];
      installPhase = ''
        export HELM_CACHE_HOME="$TMP/.helm"
        ${pkgs.kubernetes-helm}/bin/helm pull \
        --version "${version}" --repo "${repo}" \
        --untar --untardir $out "${chart}"
        mv $out/${chart}/* $out
        rm -r $out/*gz
      '';
      outputHashMode = "recursive";
      outputHashAlgo = "sha256";
      outputHash = hash;
    };

  pullHelmChart =
    value:
    if builtins.hasAttr "rev" value then
      pullHelmChartFromGit value
    else if builtins.hasAttr "repo" value then
      pullHelmChartFromRepo value
    else
      null;

  buildHelmChart =
    {
      name,
      chart,
      helmValues,
      namespace,
      extraManifests ? [ ],
      ...
    }:
    pkgs.stdenv.mkDerivation {
      name = name;
      manifests = builtins.toJSON extraManifests;
      values = builtins.toJSON helmValues;
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

  buildManifestsOnly =
    {
      name,
      namespace ? name,
      extraManifests,
      ...
    }:
    pkgs.stdenv.mkDerivation {
      name = name;
      manifests = builtins.toJSON extraManifests;
      passAsFile = [ "manifests" ];
      phases = [ "installPhase" ];
      installPhase = ''
        ${pkgs.yq-go}/bin/yq -oy -P ".[] | split_doc" $manifestsPath > $out
      '';
    };

  buildManifests =
    value:
    if value.chart != null then
      buildHelmChart value
    else if builtins.hasAttr "extraManifests" value then
      buildManifestsOnly value
    else
      null;
}
