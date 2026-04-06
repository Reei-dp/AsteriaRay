#!/usr/bin/env bash
# Download AmneziaWG userspace tools (Ubuntu 22.04 / glibc amd64) into linux/ so CMake bundles them next to the app.
# Same layout as sing-box: linux/awg + linux/awg-quick (awg-quick prepends its dir to PATH so awg is found).
# Usage from repo root: ./tools/fetch_amneziawg_tools_linux.sh [release tag]
# Example: ./tools/fetch_amneziawg_tools_linux.sh v1.0.20260223
#
# Releases: https://github.com/amnezia-vpn/amneziawg-tools/releases
#
# If `ip link type amneziawg` fails (no kernel module), also run:
#   ./tools/fetch_amneziawg_go_linux.sh
# and rebuild so `amneziawg-go` is bundled next to `awg-quick`.

set -euo pipefail
VERSION="${1:-v1.0.20260223}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT_DIR="${ROOT}/linux"
ZIP_NAME="ubuntu-22.04-amneziawg-tools.zip"
URL="https://github.com/amnezia-vpn/amneziawg-tools/releases/download/${VERSION}/${ZIP_NAME}"

echo "Downloading ${URL}"
tmpdir="$(mktemp -d)"
trap 'rm -rf "${tmpdir}"' EXIT
curl -fsSL -o "${tmpdir}/${ZIP_NAME}" "${URL}"
unzip -q "${tmpdir}/${ZIP_NAME}" -d "${tmpdir}"
src="$(find "${tmpdir}" -mindepth 2 -maxdepth 2 -name awg-quick -type f | head -1)"
if [[ -z "${src}" ]]; then
  echo "awg-quick not found in archive" >&2
  exit 1
fi
bindir="$(dirname "${src}")"
cp -f "${bindir}/awg" "${OUT_DIR}/awg"
cp -f "${bindir}/awg-quick" "${OUT_DIR}/awg-quick"
chmod +x "${OUT_DIR}/awg" "${OUT_DIR}/awg-quick"
echo "Installed: ${OUT_DIR}/awg ${OUT_DIR}/awg-quick"
"${OUT_DIR}/awg" version || true
