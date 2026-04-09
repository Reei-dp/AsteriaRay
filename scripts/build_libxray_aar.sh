#!/usr/bin/env bash
# Build libv2ray.aar from AndroidLibXrayLite (gomobile bind of Xray-core).
# Place output: android/app/libs/libv2ray.aar
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUT_DIR="${ROOT}/android/app/libs"
REPO_URL="${ANDROID_LIB_XRAY_LITE_URL:-https://github.com/2dust/AndroidLibXrayLite.git}"
BRANCH="${ANDROID_LIB_XRAY_LITE_BRANCH:-main}"

TMP="${TMPDIR:-/tmp}/AndroidLibXrayLite-$$"
trap 'rm -rf "${TMP}"' EXIT

echo "Cloning ${REPO_URL} (${BRANCH})..."
git clone --depth 1 -b "${BRANCH}" "${REPO_URL}" "${TMP}"

cd "${TMP}"
# AsteriaRay: route outbound dials through VpnService.protect (see android/libv2ray-source/libv2ray_main.go).
cp -f "${ROOT}/android/libv2ray-source/libv2ray_main.go" "${TMP}/libv2ray_main.go"
echo "Running gomobile bind (requires Go 1.22+, Android NDK, gomobile)..."
go install golang.org/x/mobile/cmd/gomobile@latest
gomobile init
gomobile bind -v -androidapi 21 -trimpath -ldflags='-s -w' -tags='with_gvisor,with_quic,with_wireguard,with_ech,with_utls,with_clash_api' -o libv2ray.aar ./

mkdir -p "${OUT_DIR}"
cp -f libv2ray.aar "${OUT_DIR}/"
echo "OK: ${OUT_DIR}/libv2ray.aar"
