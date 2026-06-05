{
  description = "finix-flake test environment";

  inputs = {
    finix-flake.url = "path:..";
    nixpkgs.follows = "finix-flake/nixpkgs";
    flake-parts.follows = "finix-flake/flake-parts";
  };

  outputs = inputs @ {flake-parts, ...}:
    flake-parts.lib.mkFlake {inherit inputs;} {
      systems = ["x86_64-linux" "aarch64-linux"];

      perSystem = {pkgs, ...}: let
        vm = modules:
          inputs.finix-flake.lib.mkVm {
            inherit pkgs modules;
            name = "finix-test";
            headless = true;
          };
      in {
        packages = {
          # boot into a minimal shell: nix run .#minimal
          minimal = vm [
            {
              users.users.root.password = "";
              virtualisation.memorySize = 1024;
              virtualisation.cores = 2;
            }
          ];

          # add packages here to test them: nix run .#with-packages
          with-packages = vm [
            {
              users.users.root.password = "";
              environment.systemPackages = with pkgs; [
                # add finix packages to test here
              ];
              virtualisation.memorySize = 2048;
              virtualisation.cores = 2;
            }
          ];
        };
      };
    };
}
