#!/usr/bin/env bash
set -euo pipefail

mode="${1:-}"
config="${2:-}"
packages="${3:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/custom/required-packages.txt}"

if [[ "$mode" != inject && "$mode" != verify ]] || [[ ! -f "$config" || ! -f "$packages" ]]; then
  echo "Usage: required-packages.sh {inject|verify} CONFIG_FILE [PACKAGES_FILE]" >&2
  exit 2
fi

required=()
while IFS= read -r package || [[ -n "$package" ]]; do
  required+=("$package")
done < "$packages"
if (( ${#required[@]} == 0 )); then
  echo "Required package list is empty: $packages" >&2
  exit 1
fi
for package in "${required[@]}"; do
  if [[ ! "$package" =~ ^[A-Za-z0-9][A-Za-z0-9+_.-]*$ ]]; then
    echo "Invalid required package name: $package" >&2
    exit 1
  fi
done

if [[ "$mode" == inject ]]; then
  tmp="$(mktemp "${config}.required.XXXXXX")"
  trap 'rm -f "$tmp"' EXIT
  awk 'NR == FNR { required[$0] = 1; next }
    {
      for (package in required) {
        if ($0 == "CONFIG_PACKAGE_" package "=y" ||
            $0 == "CONFIG_PACKAGE_" package "=m" ||
            $0 == "CONFIG_PACKAGE_" package "=n" ||
            $0 == "# CONFIG_PACKAGE_" package " is not set") next
      }
      print
    }' "$packages" "$config" > "$tmp"
  for package in "${required[@]}"; do
    printf 'CONFIG_PACKAGE_%s=y\n' "$package" >> "$tmp"
  done
  cat "$tmp" > "$config"
else
  missing=0
  for package in "${required[@]}"; do
    if ! grep -Fqx "CONFIG_PACKAGE_${package}=y" "$config"; then
      echo "Required package unavailable or not enabled after make defconfig: $package" >&2
      missing=1
    fi
  done
  exit "$missing"
fi
