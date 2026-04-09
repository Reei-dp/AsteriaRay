#!/usr/bin/env bash
# Invoked elevated (sudo/pkexec). Apply/remove IPv4 routes for full-tunnel through Xray TUN.
# Args are positional only — see VpnLinuxFullTunnelRoutes in Dart.
set -euo pipefail

_ip() {
  if command -v ip >/dev/null 2>&1; then
    command -v ip
  elif [[ -x /usr/sbin/ip ]]; then
    echo /usr/sbin/ip
  else
    echo /sbin/ip
  fi
}

IP="$(_ip)"

case "${1:-}" in
apply)
  gw="${2:?}" dev="${3:?}" tun="${4:?}"
  shift 4
  for addr in "$@"; do
    "$IP" -4 route replace "$addr/32" via "$gw" dev "$dev"
  done
  "$IP" -4 route replace 0.0.0.0/1 dev "$tun"
  "$IP" -4 route replace 128.0.0.0/1 dev "$tun"
  ;;
undo)
  tun="${2:?}" gw="${3:?}" dev="${4:?}"
  shift 4
  "$IP" -4 route del 0.0.0.0/1 dev "$tun" 2>/dev/null || true
  "$IP" -4 route del 128.0.0.0/1 dev "$tun" 2>/dev/null || true
  for addr in "$@"; do
    "$IP" -4 route del "$addr/32" via "$gw" dev "$dev" 2>/dev/null || true
  done
  ;;
*)
  exit 1
  ;;
esac
