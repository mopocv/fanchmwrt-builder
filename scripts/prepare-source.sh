#!/usr/bin/env bash
set -euo pipefail

source_dir="${1:?Usage: prepare-source.sh SOURCE_DIR}"
builder_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

[[ -f "$source_dir/Makefile" ]] || {
  echo "OpenWrt source directory is invalid: $source_dir" >&2
  exit 1
}

feeds_append="$builder_dir/custom/feeds.conf.append"
if [[ -s "$feeds_append" ]]; then
  printf '\n# Custom feeds managed by fanchmwrt-builder\n' \
    >> "$source_dir/feeds.conf.default"
  sed '/^[[:space:]]*#/d; /^[[:space:]]*$/d' "$feeds_append" \
    >> "$source_dir/feeds.conf.default"
fi

packages_dir="$builder_dir/custom/packages"
if [[ -d "$packages_dir" ]]; then
  mkdir -p "$source_dir/package/custom"
  rsync -a --delete --exclude='README.md' \
    "$packages_dir/" "$source_dir/package/custom/"
fi

patches_dir="$builder_dir/custom/patches"
if [[ -d "$patches_dir" ]]; then
  shopt -s nullglob
  patches=("$patches_dir"/*.patch)
  for patch_file in "${patches[@]}"; do
    echo "Applying $(basename "$patch_file")"
    git -C "$source_dir" apply --check "$patch_file"
    git -C "$source_dir" apply "$patch_file"
  done
fi

files_dir="$builder_dir/custom/files"
if [[ -d "$files_dir" ]]; then
  mkdir -p "$source_dir/files"
  rsync -a --exclude='README.md' "$files_dir/" "$source_dir/files/"
fi
