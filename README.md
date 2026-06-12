<p align="center">
  <img src="https://raw.githubusercontent.com/virbicoin/vbc-stats/main/public/VBC.svg" alt="VirBiCoin Logo" width="120" height="120">
</p>

<h1 align="center">Open VirBiCoin</h1>

<p align="center">
  <strong>Rust Implementation of the VirBiCoin Protocol</strong>
</p>

<p align="center">
  <a href="https://www.virbicoin.com">
    <img src="https://img.shields.io/badge/Website-virbicoin.com-cyan?style=for-the-badge&logo=google-chrome&logoColor=white" alt="Website">
  </a>
  <a href="https://github.com/virbicoin/open-virbicoin/releases">
    <img src="https://img.shields.io/badge/Downloads-Releases-green?style=for-the-badge&logo=github&logoColor=white" alt="Releases">
  </a>
  <a href="https://discord.virbicoin.com">
    <img src="https://img.shields.io/badge/Discord-Join-5865F2?style=for-the-badge&logo=discord&logoColor=white" alt="Discord">
  </a>
</p>

<p align="center">
  <a href="https://github.com/virbicoin/open-virbicoin/actions/workflows/release.yml">
    <img src="https://img.shields.io/github/actions/workflow/status/virbicoin/open-virbicoin/release.yml?style=flat-square&label=CI" alt="CI">
  </a>
  <img src="https://img.shields.io/badge/Rust-1.75-orange?style=flat-square&logo=rust&logoColor=white" alt="Rust">
  <img src="https://img.shields.io/badge/License-GPL--3.0-blue?style=flat-square" alt="License: GPL-3.0">
</p>

---

`ovbc` is a fast Rust client for the **VirBiCoin** network — an
[OpenEthereum](https://github.com/openethereum/openethereum) fork that ships with
VirBiCoin built in. It is the Rust counterpart to
[go-virbicoin](https://github.com/virbicoin/go-virbicoin) (`gvbc`); the two are
not meant to run on the same machine at the same time.

Automated builds are available for stable releases and the unstable `main`
branch. Prebuilt binaries are published at
https://github.com/virbicoin/open-virbicoin/releases/.

## Quick start

Download the `ovbc` binary for your platform from the
[Releases page](https://github.com/virbicoin/open-virbicoin/releases/latest), make
it executable, and run it — **no flags or config files required**:

```shell
./ovbc
```

Prebuilt binaries are available for:

| OS      | Architecture            | Archive                        |
| ------- | ----------------------- | ------------------------------ |
| Linux   | x86_64                  | `ovbc-linux-x86_64.tar.gz`     |
| Linux   | aarch64 (arm64)         | `ovbc-linux-aarch64.tar.gz`    |
| Windows | x86_64                  | `ovbc-windows-x86_64.zip`      |
| macOS   | x86_64 (Intel)          | `ovbc-darwin-x86_64.tar.gz`    |
| macOS   | aarch64 (Apple Silicon) | `ovbc-darwin-aarch64.tar.gz`   |

There is no native Windows arm64 binary (the vintage dependency tree cannot
target it); on Windows on ARM, run `ovbc-windows-x86_64.zip` through the
built-in x64 emulation.

It connects to the VirBiCoin network (chainId 329) out of the box and exposes the
JSON-RPC endpoints on the standard VirBiCoin ports:

| Service   | Port  |
| --------- | ----- |
| HTTP-RPC  | 8329  |
| WebSocket | 8330  |
| P2P       | 28329 |

Once running, the node reports its client identity in the same shape as `gvbc`,
for example:

```
Ovbc/v3.3.8-stable/linux-amd64/rustc1.75.0
```

## Building the source

Building `ovbc` requires a Rust toolchain and a C/C++ compiler. The pinned
toolchain (Rust 1.75.0) is declared in [`rust-toolchain.toml`](rust-toolchain.toml)
and installed automatically by [rustup](https://rustup.rs/).

On Debian/Ubuntu, install the build dependencies:

```shell
sudo apt-get install -y build-essential pkg-config libudev-dev clang libclang-dev cmake
```

On macOS, install the Xcode Command Line Tools and CMake (both Intel and Apple
Silicon Macs are supported):

```shell
xcode-select --install
brew install cmake
```

Then build the release binary with the `final` feature (which marks the build as
a `stable` release in the version string):

```shell
git clone https://github.com/virbicoin/open-virbicoin
cd open-virbicoin
cargo build --release --features final
```

This produces the `ovbc` executable in `./target/release`. Omit `--features
final` for a development (`unstable`) build.

## Running `ovbc`

Run the client directly; it joins VirBiCoin with no further configuration:

```shell
./target/release/ovbc
```

The data directory defaults to `~/.local/share/openvirbicoin` on Linux,
`~/Library/Application Support/OpenVirBiCoin` on macOS and
`%APPDATA%\OpenVirBiCoin` on Windows. A few common flags:

```shell
# Enable the HTTP JSON-RPC server on all interfaces
./ovbc --jsonrpc-interface all

# Use a custom data directory
./ovbc --base-path /path/to/data

# List all options
./ovbc --help
```

**Note: understand the security implications of exposing an HTTP/WS RPC interface
before enabling it on a public address.**

## Release cycle

Versions follow the go-ethereum / go-virbicoin unstable/stable cycle. The version
track is encoded directly in the client version string (`-unstable` / `-stable`).

### Branch model

- `main` — Mainline development. Always `vX.Y.Z`, built as `unstable`.
- `dev` — Feature integration and verification.
- `release/X.Y` — Maintenance line. Stable release tags live here.

### Cycle

1. **Development**: `main` is `vX.Y.Z` and builds without `--features final`, so
   the client reports `Ovbc/vX.Y.Z-unstable/...`.
2. **Release**: `release/X.Y` takes the stable tag `vX.Y.Z`. The release workflow
   builds plain tags with `--features final`, so the published binaries report
   `Ovbc/vX.Y.Z-stable/...`.
3. **Post-release**: bump `main`'s patch number for the next development cycle
   (`main` stays `unstable`).

This flow is semi-automated by [`build/release.sh`](build/release.sh):

```shell
# Release main's version as a stable build on release/X.Y, then advance main
build/release.sh

# Print the steps without making any changes
build/release.sh --dry-run
```

The release binaries themselves are produced by the GitHub Actions workflow
([`.github/workflows/release.yml`](.github/workflows/release.yml)) when the
`vX.Y.Z` tag is pushed. Releases are created as drafts; review and publish them
from the Releases page.

## Testing

Run the test suite with Cargo:

```shell
# All packages
cargo test --all

# A specific package
cargo test --package <spec>
```

## VirBiCoin ecosystem

| Repository | Role |
| --- | --- |
| [virbicoin.com](https://github.com/virbicoin/virbicoin.com) | Official website and protocol docs |
| [go-virbicoin](https://github.com/virbicoin/go-virbicoin) | Main client (`gvbc`, Go implementation) |
| **open-virbicoin** | Rust client (`ovbc`, OpenEthereum fork) |
| [vbc-explorer](https://github.com/virbicoin/vbc-explorer) | Block explorer |
| [vbc-stats](https://github.com/virbicoin/vbc-stats) | Network statistics dashboard |
| [vbc-pool](https://github.com/virbicoin/vbc-pool) | Mining pool |

## License

[GPL-3.0](LICENSE). `ovbc` is a fork of OpenEthereum; upstream library code is
LGPL-3.0 and the client code is GPL-3.0.
