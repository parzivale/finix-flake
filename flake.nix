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
        finixSystem = {self, modules ? [], specialArgs ? {}}: let
          finixModules = inputs.finix.nixosModules;
        in {
          config = lib.evalModules {
            class = "finix";
            specialArgs = lib.recursiveUpdate {modules = finixModules;} specialArgs;
            modules = [finixModules.default] ++ modules;
          };
        };
      in
        inputs.finix.lib
        // {
          inherit finixSystem;
          mkTest = {pkgs, self, name, nodes, testScript, extraDriverArgs ? [], ...}:
            let
              qemuSerialDevice =
                if pkgs.stdenv.hostPlatform.isx86 then "ttyS0"
                else if pkgs.stdenv.hostPlatform.isAarch then "ttyAMA0"
                else throw "unknown QEMU serial device for ${pkgs.stdenv.hostPlatform.system}";

              mkVmNode = allNodes: nodeName: nodeConfig:
                (finixSystem {
                  inherit self;
                  modules = [
                    "${inputs.finix}/tests/lib/testing.nix"
                    "${inputs.finix}/modules/virtualisation/qemu.nix"
                    nodeConfig
                    {
                      nixpkgs.pkgs = pkgs;
                      boot.kernelParams = ["console=${qemuSerialDevice},115200n8"];
                      fileSystems."/" = {device = "tmpfs"; fsType = "tmpfs"; options = ["mode=755"];};
                      networking.hostName = nodeName;
                      testing.enable = true;
                      virtualisation.qemu.package = pkgs.qemu_test;
                    }
                  ];
                  specialArgs = {nodes = allNodes;};
                }).config;

              evaluatedNodes = lib.mapAttrs (mkVmNode evaluatedNodes) nodes;

              mkVmScript = nodeName: config:
                pkgs.writeShellScript "run-${nodeName}-vm" ''
                  set -e
                  if [ -n "$TMPDIR" ]; then mkdir -p "$TMPDIR"; cd "$TMPDIR"; fi
                  if [ -n "$SHARED_DIR" ]; then mkdir -p "$SHARED_DIR"; fi
                  exec ${lib.escapeShellArgs config.virtualisation.qemu.argv} \
                    -name "${nodeName}" \
                    -device "virtio-net-pci,netdev=vlan${toString config.testing.network.vlan},mac=${config.testing.network.mac}" \
                    -netdev "vde,id=vlan${toString config.testing.network.vlan},sock=$TMPDIR/../vde${toString config.testing.network.vlan}.ctl" \
                    "$@"
                '';

              mkVmDerivation = nodeName: config:
                pkgs.runCommand "finix-vm-${nodeName}"
                  {preferLocalBuild = true; meta.mainProgram = "run-${nodeName}-vm";}
                  ''
                    mkdir -p $out/bin
                    ln -s ${config.system.topLevel} $out/system
                    ln -s ${mkVmScript nodeName config} $out/bin/run-${nodeName}-vm
                  '';

              vms = lib.mapAttrs (n: nodeEval: mkVmDerivation n nodeEval.config) evaluatedNodes;

              vlans = lib.unique (
                lib.mapAttrsToList (_: nodeEval: nodeEval.config.testing.network.vlan) evaluatedNodes
              );

              testScriptStr =
                if builtins.isFunction testScript
                then testScript {nodes = evaluatedNodes;}
                else testScript;

              driverConfigurationFile = pkgs.writers.writeJSON "finix-driver-configuration-${name}.json" {
                vms = lib.mapAttrs (n: vm: {name = n; start_script = "${vm}/bin/run-${n}-vm";}) vms;
                containers = {};
                inherit vlans;
                global_timeout = 3600;
                enable_ssh_backdoor = false;
                test_script = pkgs.writeText "test-${name}.py" testScriptStr;
              };

              testDrv = (testLib pkgs).testDriver;

              driver = pkgs.runCommand "finix-test-driver-${name}"
                {
                  nativeBuildInputs = [pkgs.makeWrapper];
                  buildInputs = [testDrv];
                  passthru = {inherit vms evaluatedNodes; nodes = evaluatedNodes;};
                  meta.mainProgram = "finix-test-driver";
                }
                ''
                  mkdir -p $out/bin
                  makeWrapper ${testDrv}/bin/nixos-test-driver $out/bin/finix-test-driver \
                    --add-flags "--config ${driverConfigurationFile}" \
                    ${lib.escapeShellArgs (lib.concatMap (arg: ["--add-flags" arg]) extraDriverArgs)}
                '';
            in
              pkgs.runCommand "finix-test-${name}"
                {
                  requiredSystemFeatures = ["kvm"];
                  nativeBuildInputs = [pkgs.vde2];
                  passthru = {inherit driver vms; driverInteractive = driver;};
                }
                ''
                  mkdir -p $out
                  export LOGFILE=/dev/null
                  ${driver}/bin/finix-test-driver -o $out
                '';
        };
    };
}
