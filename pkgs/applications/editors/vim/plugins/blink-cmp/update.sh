#!/usr/bin/env nix-shell
#!nix-shell -i bash -p curl gnugrep gnused jq

set -euo pipefail

cd "$(dirname "$0")" || exit 1

# grab latest release version
BLINK_CMP_LATEST_VER="$(curl --fail -s ${GITHUB_TOKEN:+-u ":$GITHUB_TOKEN"} "https://api.github.com/repos/Saghen/blink.cmp/releases/latest" | jq -r '.tag_name' | sed 's/^v//')"
BLINK_CMP_CURRENT_VER="$(grep -oP 'version = "\K[^"]+' default.nix)"

if [[ "$BLINK_CMP_LATEST_VER" == "$BLINK_CMP_CURRENT_VER" ]]; then
    echo "blink.cmp is up-to-date"
    exit 0
fi

# download updated Cargo.lock
CARGO_LOCK_URL="https://raw.githubusercontent.com/Saghen/blink.cmp/refs/tags/v${BLINK_CMP_LATEST_VER}/Cargo.lock"
curl --fail --output Cargo.lock "$CARGO_LOCK_URL"

# update frizbee output hash, update blink.cmp hash
FRIZBEE_COMMIT="$(grep -oP -m 1 '(?<=git\+https:\/\/github\.com\/saghen\/frizbee\#)[0-9a-f]{40}' Cargo.lock)"
FRIZBEE_HASH="$(nix hash convert --hash-algo sha256 --to sri "$(nix-prefetch-url --type sha256 --unpack "https://github.com/saghen/frizbee/archive/${FRIZBEE_COMMIT}.tar.gz")")"
BLINK_CMP_HASH="$(nix hash convert --hash-algo sha256 --to sri "$(nix-prefetch-url --type sha256 --unpack "https://github.com/Saghen/blink.cmp/archive/refs/tags/v${BLINK_CMP_LATEST_VER}.tar.gz")")"

sed -i "s#hash = \".*\"#hash = \"$BLINK_CMP_HASH\"#g" default.nix
sed -i "s#version = \".*\";#version = \"$BLINK_CMP_LATEST_VER\";#g" default.nix
sed -i "s#\"frizbee-0.1.0\" = \".*\";#\"frizbee-0.1.0\" = \"$FRIZBEE_HASH\";#g" default.nix
