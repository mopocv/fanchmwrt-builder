#!/usr/bin/env bash
set -euo pipefail

source_dir="${1:?Usage: customize-defaults.sh SOURCE_DIR}"
uci_defaults_dir="$source_dir/files/etc/uci-defaults"
output="$uci_defaults_dir/99-fanchmwrt-builder"

mkdir -p "$uci_defaults_dir"

quote_for_shell() {
  printf "%s" "$1" | sed "s/'/'\\\\''/g"
}

hostname_value="$(quote_for_shell "${CUSTOM_HOSTNAME:-}")"
lan_ip_value="$(quote_for_shell "${CUSTOM_LAN_IP:-}")"
timezone_value="$(quote_for_shell "${CUSTOM_TIMEZONE:-}")"
zonename_value="$(quote_for_shell "${CUSTOM_ZONENAME:-}")"

{
  echo '#!/bin/sh'
  echo 'set -eu'

  if [[ -n "$hostname_value" ]]; then
    echo "uci set system.@system[0].hostname='$hostname_value'"
  fi

  if [[ -n "$timezone_value" ]]; then
    echo "uci set system.@system[0].timezone='$timezone_value'"
  fi

  if [[ -n "$zonename_value" ]]; then
    echo "uci set system.@system[0].zonename='$zonename_value'"
  fi

  if [[ -n "$lan_ip_value" ]]; then
    echo "uci set network.lan.ipaddr='$lan_ip_value'"
  fi

  echo 'uci commit system'
  if [[ -n "$lan_ip_value" ]]; then
    echo 'uci commit network'
  fi
  echo 'exit 0'
} > "$output"

chmod 0755 "$output"
