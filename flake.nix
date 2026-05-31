{
  description = "Pins nixpkgs and finix, exposes finix lib and test suite";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    finix.url = "github:finix-community/finix";
    flake-parts.url = "github:hercules-ci/flake-parts";
  };

  outputs =
    inputs@{ flake-parts, ... }:
    flake-parts.lib.mkFlake { inherit inputs; } {
      systems = [
        "x86_64-linux"
        "aarch64-linux"
      ];

      perSystem =
        { pkgs, lib, ... }:
        {
          checks = lib.concatMapAttrs (
            name: value:
            if lib.isDerivation value then
              { ${name} = value; }
            else
              lib.filterAttrs (_: lib.isDerivation) value
          ) (import "${inputs.finix}/tests" { inherit pkgs; });
        };

      flake.lib = inputs.finix.lib;
    };
}
