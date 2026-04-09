#!/usr/bin/env bash
# Download Xray-core for Linux amd64 into linux/xray so CMake bundles it next to the app.
# Usage: from repo root: ./tools/fetch_xray_linux.sh [version]
# Example: ./tools/fetch_xray_linux.sh 26.3.27

set -euo pipefail
VERSION="${1:-26.3.27}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="${ROOT}/linux/xray"
URL="https://github.com/XTLS/Xray-core/releases/download/v${VERSION}/Xray-linux-64.zip"

echo "Downloading ${URL}"
tmpdir="$(mktemp -d)"
trap 'rm -rf "${tmpdir}"' EXIT
curl -fsSL -o "${tmpdir}/xray.zip" "${URL}"
unzip -q -o "${tmpdir}/xray.zip" -d "${tmpdir}"
bin="$(find "${tmpdir}" -name xray -type f | head -1)"
chmod +x "${bin}"
cp -f "${bin}" "${OUT}"
chmod +x "${OUT}"
echo "Installed: ${OUT}"
"${OUT}" version
