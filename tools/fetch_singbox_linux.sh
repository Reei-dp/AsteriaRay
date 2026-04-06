#!/usr/bin/env bash
# Download sing-box for Linux amd64 (glibc) into linux/sing-box so CMake bundles it next to the app.
# Usage: from repo root: ./tools/fetch_singbox_linux.sh [version]
# Example: ./tools/fetch_singbox_linux.sh 1.10.7

set -euo pipefail
VERSION="${1:-1.13.5}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="${ROOT}/linux/sing-box"
URL="https://github.com/SagerNet/sing-box/releases/download/v${VERSION}/sing-box-${VERSION}-linux-amd64.tar.gz"

echo "Downloading ${URL}"
tmpdir="$(mktemp -d)"
trap 'rm -rf "${tmpdir}"' EXIT
curl -fsSL -o "${tmpdir}/sing-box.tgz" "${URL}"
tar -xzf "${tmpdir}/sing-box.tgz" -C "${tmpdir}"
# Archive contains sing-box-*/sing-box
bin="$(find "${tmpdir}" -name sing-box -type f | head -1)"
chmod +x "${bin}"
cp -f "${bin}" "${OUT}"
chmod +x "${OUT}"
echo "Installed: ${OUT}"
"${OUT}" version
