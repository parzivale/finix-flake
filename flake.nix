{
  description = "Pins nixpkgs and finix, exposes finix lib and test suite";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    finix.url = "github:finix-community/finix";
    finix-community-modules.url = "github:finix-community/community-modules";
    flake-parts.url = "github:hercules-ci/flake-parts";
  };

  outputs = inputs @ {flake-parts, ...}:
    flake-parts.lib.mkFlake {inherit inputs;} {
      systems = [
        "x86_64-linux"
        "aarch64-linux"
      ];

      perSystem = {
        pkgs,
        lib,
        ...
      }: {
        checks = lib.concatMapAttrs (
          name: value:
            if lib.isDerivation value
            then {${name} = value;}
            else lib.filterAttrs (_: lib.isDerivation) value
        ) (import "${inputs.finix}/tests" {inherit pkgs;});
      };

      flake.finixModules = inputs.finix-community-modules.nixosModules;

      flake.lib = let
        testLib = pkgs:
          import "${inputs.finix}/tests/lib" {
            inherit pkgs;
            lib = pkgs.lib;
          };
        lib = inputs.nixpkgs.lib;
      in
        inputs.finix.lib
        // {
          mkTest = {pkgs, ...} @ args:
            (testLib pkgs).mkTest (builtins.removeAttrs args ["pkgs"]);
          finixSystem = {self, modules ? [], specialArgs ? {}}: let
            finixModules = inputs.finix.nixosModules;
          in {
            config = lib.evalModules {
              class = "finix";
              specialArgs = lib.recursiveUpdate {modules = finixModules;} specialArgs;
              modules = [finixModules.default] ++ modules;
            };
          };
        };
    };
}
