{
  pkgs,
  name,
  ...
}:
let
  default = import ./default.nix {inherit pkgs;};
in
{
  test = builtins.trace default.outputs.out default;
  listNodes = pkgs.writers.writeNuBin "listNodes" ''
    (
      ${pkgs.lib.getExe pkgs.kubectl} get nodes -o json
      | from json
      | get items
      | select metadata.name
    )
  '';
  getDiff = pkgs.writers.writeNuBin "getDiff" ''
    (
      ${pkgs.lib.getExe pkgs.kubectl} diff -f ${default.manifests.${name}}
    )
  '';
}
