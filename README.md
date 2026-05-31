# finix-flake

A Nix flake that pins [finix-community/finix](https://github.com/finix-community/finix), exposes its library, and runs its test suite via `nix flake check`.

## Usage

### As a flake input

```nix
{
  inputs.finix-flake.url = "github:parzivale/finix-flake";

  outputs = { finix-flake, ... }: {
    # finix-flake.lib.finixSystem
    # finix-flake.lib.mkTest
  };
}
```

### `lib.finixSystem`

Evaluate a finix system configuration:

```nix
finix-flake.lib.finixSystem {
  inherit lib;
  modules = [ ./configuration.nix ];
}
```

### `lib.mkTest`

Create a VM-based test using the finix test driver:

```nix
finix-flake.lib.mkTest {
  inherit pkgs;
  name = "my-test";
  nodes = {
    machine = { ... }: { /* finix node config */ };
  };
  testScript = ''
    machine.wait_for_service("myservice")
  '';
}
```

The test driver exposes a `FinitMachine` class with finit-specific methods (`wait_for_service`, `wait_for_condition`, `initctl`, etc.) in place of systemd equivalents.

### Run upstream tests

```sh
nix flake check
```

## Supported systems

- `x86_64-linux`
- `aarch64-linux`

## Inputs

| Input | Purpose |
|---|---|
| `nixpkgs` | `nixos-unstable` |
| `finix` | `finix-community/finix` |
| `flake-parts` | Flake structure |
