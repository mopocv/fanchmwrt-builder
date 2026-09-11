#!/bin/zsh
set -euo pipefail

IMAGE="ghcr.io/openwrt/buildbot/buildworker-v3.8.0:v9"
VOLUME="fanchmwrt-build"
SCRIPT_DIR="${0:A:h}"
LOCAL_OUTPUTS_DIR="${FANCHMWRT_LOCAL_OUTPUTS_DIR:?Set FANCHMWRT_LOCAL_OUTPUTS_DIR to the previous outputs directory}"
DISK_IMAGE="${LOCAL_OUTPUTS_DIR}/FanchmWrtBuilder.sparsebundle"
BUILD_DIR="${LOCAL_OUTPUTS_DIR}/fanchmwrt-builder"
HOST_UID="$(id -u)"
HOST_GID="$(id -g)"

ensure_build_disk() {
  mkdir -p "${BUILD_DIR}"
  if ! mount | grep -Fq "on ${BUILD_DIR} ("; then
    echo "正在挂载大小写敏感的 FanchmWrt 构建盘……"
    hdiutil attach "${DISK_IMAGE}" -mountpoint "${BUILD_DIR}" -nobrowse -owners on >/dev/null
  fi
}

ensure_running() {
  if ! colima status >/dev/null 2>&1; then
    echo "正在启动 FanchmWrt Linux 编译环境……"
    colima start
  fi
}

sync_to_builder() {
  echo "正在将 Mac 源码同步到 Linux 构建盘……"
  docker run --rm \
    -v "${BUILD_DIR}:/source:ro" \
    -v "${VOLUME}:/builder" \
    "${IMAGE}" \
    rsync -rlpt --delete --delete-delay \
      --exclude=/bin/ \
      --exclude=/build_dir/ \
      --exclude=/staging_dir/ \
      --exclude=/tmp/ \
      --exclude=/dl/ \
      --exclude=/logs/ \
      --exclude=/feeds/ \
      --exclude=/package/feeds/ \
      --exclude=/.config-backups/ \
      --exclude=/.gitconfig \
      --exclude='sed??????' \
      --exclude='pp??????' \
      /source/ /builder/
}

sync_from_builder() {
  docker run --rm \
    --user "${HOST_UID}:${HOST_GID}" \
    --entrypoint /bin/bash \
    -v "${BUILD_DIR}:/source" \
    -v "${VOLUME}:/builder:ro" \
    "${IMAGE}" \
    -lc 'test ! -f /builder/.config || cp /builder/.config /source/.config'
}

run_builder() {
  ensure_build_disk
  ensure_running
  sync_to_builder
  if docker run --rm -it \
    -e TERM="${TERM:-xterm-256color}" \
    -v "${VOLUME}:/builder" \
    -w /builder \
    "${IMAGE}" \
    bash -lc "umask 022; $1"; then
    result=0
  else
    result=$?
  fi
  sync_from_builder
  return "${result}"
}

case "${1:-help}" in
  status)
    ensure_build_disk
    ensure_running
    colima status
    git -C "${BUILD_DIR}" status --short --branch --untracked-files=no
    docker run --rm -v "${VOLUME}:/builder" -w /builder "${IMAGE}" \
      sh -lc 'echo "Linux 构建盘："; df -h /builder'
    ;;
  shell)
    run_builder 'exec bash'
    ;;
  feeds)
    run_builder './scripts/feeds update -a && ./scripts/feeds install -a'
    ;;
  import)
    if [[ $# -ne 3 ]]; then
      echo "用法：$0 import <Mac上的.config路径> <Mac上的feeds配置路径>" >&2
      exit 2
    fi
    CONFIG_FILE="${2:A}"
    FEEDS_FILE="${3:A}"
    if [[ ! -f "${CONFIG_FILE}" ]]; then
      echo "找不到配置文件：${CONFIG_FILE}" >&2
      exit 2
    fi
    if [[ ! -f "${FEEDS_FILE}" ]]; then
      echo "找不到 feeds 文件：${FEEDS_FILE}" >&2
      exit 2
    fi
    ensure_build_disk
    stamp="$(date +%Y%m%d-%H%M%S)"
    mkdir -p "${BUILD_DIR}/.config-backups/${stamp}"
    [[ ! -f "${BUILD_DIR}/.config" ]] || cp "${BUILD_DIR}/.config" "${BUILD_DIR}/.config-backups/${stamp}/config"
    [[ ! -f "${BUILD_DIR}/feeds.conf.default" ]] || cp "${BUILD_DIR}/feeds.conf.default" "${BUILD_DIR}/.config-backups/${stamp}/feeds.conf.default"
    cp "${CONFIG_FILE}" "${BUILD_DIR}/.config"
    cp "${FEEDS_FILE}" "${BUILD_DIR}/feeds.conf.default"
    ensure_running
    sync_to_builder
    echo "导入完成；旧文件备份在 ${BUILD_DIR}/.config-backups/${stamp}/"
    ;;
  sync)
    ensure_build_disk
    ensure_running
    sync_to_builder
    ;;
  defconfig)
    run_builder 'make defconfig'
    ;;
  menuconfig)
    run_builder 'make menuconfig'
    ;;
  build)
    run_builder 'make -j1 V=s'
    ;;
  export)
    ensure_running
    EXPORT_DIR="${LOCAL_OUTPUTS_DIR}/x86-64"
    mkdir -p "${EXPORT_DIR}"
    docker run --rm \
      --user "${HOST_UID}:${HOST_GID}" \
      --entrypoint /bin/bash \
      -v "${VOLUME}:/builder:ro" \
      -v "${EXPORT_DIR}:/export" \
      -w /builder \
      "${IMAGE}" \
      -lc 'set -e; test -d /builder/bin/targets/x86/64; cp -R /builder/bin/targets/x86/64/. /export/; echo "x86/64 镜像、清单和校验文件已导出"'
    echo "Mac 导出目录：${EXPORT_DIR}"
    ;;
  stop)
    colima stop
    ;;
  help|*)
    echo "用法：$0 {status|shell|import|sync|feeds|defconfig|menuconfig|build|export|stop}"
    echo "  status      查看环境和源码状态"
    echo "  shell       进入 Linux 编译终端"
    echo "  import      从 Mac 导入 .config 和 feeds.conf.default"
    echo "  sync        将 Mac 源码同步到 Linux 构建盘"
    echo "  feeds       更新并安装 feeds"
    echo "  defconfig   检查并补全现有 .config"
    echo "  menuconfig  选择目标设备和软件包"
    echo "  build       使用单任务详细日志编译 (make -j1 V=s)"
    echo "  export      导出全部 x86/64 镜像和校验文件"
    echo "  stop        停止 Linux 环境"
    ;;
esac
