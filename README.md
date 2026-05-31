# finix-flake

A Nix flake that pins [finix-community/finix](https://github.com/finix-community/finix), exposes its library, and runs its test suite via `nix flake check`.

## Usage

### As a flake input

```nix
{
  inputs.finix-flake.url = "github:parzivale/finix-flake";

  outputs = { finix-flake, ... }: {
    # Access finix lib
    # finix-flake.lib
  };
}
```

### Run tests

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
