#!/usr/bin/env bash
# Downloads the Rojo and Selene versions pinned in rokit.toml into ./bin.
# Needs the GitHub CLI with GH_TOKEN set (always true on GitHub Actions).
set -euo pipefail

cd "$(dirname "$0")/.."
mkdir -p bin

version_of() {
  sed -n "s/^$1 = \".*@\(.*\)\"/\1/p" rokit.toml
}

download() { # repo tag pattern...
  local repo=$1 tag=$2
  shift 2
  for pattern in "$@"; do
    if gh release download "$tag" -R "$repo" -p "$pattern" -O tool.zip --clobber 2>/dev/null; then
      unzip -o -q tool.zip -d bin
      rm tool.zip
      return 0
    fi
  done
  echo "Could not download $repo $tag" >&2
  return 1
}

download rojo-rbx/rojo "v$(version_of rojo)" '*linux-x86_64.zip' '*linux.zip'
download Kampfkarren/selene "$(version_of selene)" 'selene-[0-9]*-linux-x86_64.zip' 'selene-[0-9]*-linux.zip'
chmod +x bin/rojo bin/selene
bin/rojo --version
bin/selene --version
