{
  description = "Geometric preview bar for a running paneru strip";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/f20cd90e28fe0403873f473b29e42662cd86e8c4";

  outputs =
    { self, nixpkgs }:
    let
      systems = [
        "aarch64-darwin"
        "x86_64-darwin"
      ];
      each = f: nixpkgs.lib.genAttrs systems (system: f nixpkgs.legacyPackages.${system});
    in
    {
      packages = each (pkgs: {
        default = pkgs.callPackage ./package.nix { };
        paneru-minimap = pkgs.callPackage ./package.nix { };
      });
      homeManagerModules.default = ./module.nix;
    };
}
