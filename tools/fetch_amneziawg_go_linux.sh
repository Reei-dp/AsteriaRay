#!/usr/bin/env bash
# Build amneziawg-go (userspace AmneziaWG) into linux/ so awg-quick can use it when the kernel
# module is missing ("Unknown device type" / "Protocol not supported" from `ip link type amneziawg`).
# Requires: git, Go 1.21+
# Usage from repo root: ./tools/fetch_amneziawg_go_linux.sh [tag]
# Example: ./tools/fetch_amneziawg_go_linux.sh v0.2.16
# Upstream: https://github.com/amnezia-vpn/amneziawg-go

set -euo pipefail
VERSION="${1:-v0.2.16}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="${ROOT}/linux/amneziawg-go"

if ! command -v go >/dev/null; then
  echo "Go is required to build amneziawg-go. Install Go or load the amneziawg kernel module instead." >&2
  exit 1
fi

tmpdir="$(mktemp -d)"
trap 'rm -rf "${tmpdir}"' EXIT
echo "Cloning amnezia-vpn/amneziawg-go@${VERSION}"
git clone --depth 1 --branch "${VERSION}" \
  https://github.com/amnezia-vpn/amneziawg-go.git "${tmpdir}/src"

echo "Building -> ${OUT}"
export CGO_ENABLED=0
export GOOS=linux
export GOARCH="${GOARCH:-amd64}"
(
  cd "${tmpdir}/src"
  go build -trimpath -ldflags="-s -w" -o "${OUT}" .
)
chmod +x "${OUT}"
echo "Installed: ${OUT}"
"${OUT}" --version 2>/dev/null || "${OUT}" -h 2>&1 | head -3 || true
