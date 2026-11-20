#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORKDIR="${TMPDIR:-/tmp}/tagitalspace-acton-tonconnect-diagnostics"
INSTALL_DIR="$HOME/.local/bin"
INSTALL_PATH="$INSTALL_DIR/acton-tonconnect-diagnostics"

command -v git >/dev/null || { echo "git is required"; exit 1; }
command -v curl >/dev/null || { echo "curl is required"; exit 1; }

if ! command -v rustup >/dev/null 2>&1; then
    echo "Installing the Rust toolchain required by Acton 1.2.1..."
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --profile minimal --default-toolchain 1.98.1
fi

source "$HOME/.cargo/env"
rustup toolchain install 1.98.1 --profile minimal --component rustfmt --component clippy

rm -rf "$WORKDIR"
git clone --depth 1 --branch v1.2.1 https://github.com/ton-blockchain/acton.git "$WORKDIR"
patch -d "$WORKDIR" -p1 < "$ROOT/scripts/patches/acton-tonconnect-error-details.patch"

echo "Building diagnostic Acton..."
CARGO_BUILD_JOBS="${CARGO_BUILD_JOBS:-2}" cargo +1.98.1 build --release --bin acton --manifest-path "$WORKDIR/Cargo.toml"

mkdir -p "$INSTALL_DIR"
install -m 755 "$WORKDIR/target/release/acton" "$INSTALL_PATH"
rm -rf "$WORKDIR"

echo
echo "Diagnostic Acton installed at: $INSTALL_PATH"
"$INSTALL_PATH" --version
echo "No transaction was sent."
