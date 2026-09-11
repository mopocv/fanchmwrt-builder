#!/usr/bin/env bash
set +x
set -euo pipefail

source_dir="${1:?Usage: customize-defaults.sh SOURCE_DIR}"
uci_defaults_dir="$source_dir/files/etc/uci-defaults"
output="$uci_defaults_dir/99-fanchmwrt-builder"

# Convert the plaintext secret via stdin; never put it in command arguments.
if [[ -n "${CUSTOM_ROOT_PASSWORD:-}" ]]; then
  if [[ -n "${CUSTOM_ROOT_PASSWORD_HASH:-}" ]]; then
    echo 'Set only FANCHMWRT_ROOT_PASSWORD or FANCHMWRT_ROOT_PASSWORD_HASH' >&2
    exit 1
  fi
  CUSTOM_ROOT_PASSWORD_HASH="$(python3 - <<'HASH'
import os, subprocess, sys
password = os.environ['CUSTOM_ROOT_PASSWORD']
if '\n' in password or '\r' in password:
    raise SystemExit('FANCHMWRT_ROOT_PASSWORD must not contain line breaks')
env = dict(os.environ)
env.pop('CUSTOM_ROOT_PASSWORD', None)
result = subprocess.run(['openssl', 'passwd', '-6', '-stdin'],
                        input=password + '\n', text=True, capture_output=True, env=env)
if result.returncode:
    raise SystemExit('Password hashing failed; OpenSSL with passwd -6 support is required')
sys.stdout.write(result.stdout.strip())
HASH
)"
  export CUSTOM_ROOT_PASSWORD_HASH
  unset CUSTOM_ROOT_PASSWORD
fi
if [[ "${GITHUB_ACTIONS:-}" == true && -n "${CUSTOM_ROOT_PASSWORD_HASH:-}" ]]; then
  printf '::add-mask::%s\n' "$CUSTOM_ROOT_PASSWORD_HASH"
fi

# Validate without printing secret values.
python3 - <<'CHECK'
import ipaddress, os, re
ip = os.environ.get('CUSTOM_LAN_IP', '')
if ip:
    try:
        ipaddress.IPv4Address(ip)
    except ValueError:
        raise SystemExit('FANCHMWRT_LAN_IP must be a valid IPv4 address')
h = os.environ.get('CUSTOM_ROOT_PASSWORD_HASH', '')
if h and not re.fullmatch(r'\$6\$(?:rounds=[0-9]+\$)?[./A-Za-z0-9]{1,16}\$[./A-Za-z0-9]{86}', h):
    raise SystemExit('FANCHMWRT_ROOT_PASSWORD_HASH must be a SHA-512 crypt hash')
CHECK

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
  if [[ -n "${CUSTOM_ROOT_PASSWORD_HASH:-}" ]]; then
    hash_value="$(quote_for_shell "$CUSTOM_ROOT_PASSWORD_HASH")"
    printf "printf '%%s\\n' 'root:%s' | chpasswd -e\n" "$hash_value"
  fi
  echo 'exit 0'
} > "$output"

chmod 0755 "$output"
