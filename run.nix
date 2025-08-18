{ pkgs }:
{
  test = pkgs.writers.writeNuBin "kubectl" ''
    (
      ${pkgs.lib.getExe pkgs.kubectl} get nodes -o json
      | from json
      | get items
      | select metadata.name
    )
  '';
}
