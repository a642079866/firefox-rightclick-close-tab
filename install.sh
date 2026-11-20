#!/usr/bin/env bash
# install.sh —— 给本机 Firefox 装上「标签栏右键关闭标签」
#
# 用法：  ./install.sh
# 需要 sudo（要写入 Firefox 安装目录）
# 卸载：  ./uninstall.sh

set -euo pipefail

SELF="$(readlink -f "${BASH_SOURCE[0]}")"
REPO_DIR="$(dirname "$SELF")"
CFG_SRC="$REPO_DIR/files/tabutils.cfg"
JS_SRC="$REPO_DIR/files/autoconfig.js"

die()  { printf '\033[31m错误:\033[0m %s\n' "$*" >&2; exit 1; }
info() { printf '\033[36m==>\033[0m %s\n' "$*"; }

detect_firefox_dir() {
  local d bin
  for d in /usr/lib/firefox /usr/lib64/firefox /usr/lib/firefox-esr \
           /usr/lib64/firefox-esr /opt/firefox /opt/firefox-esr; do
    if [ -f "$d/application.ini" ] && [ -d "$d/defaults/pref" ]; then
      printf '%s' "$d"
      return 0
    fi
  done
  bin="$(command -v firefox 2>/dev/null || true)"
  if [ -n "$bin" ]; then
    bin="$(readlink -f "$bin")"
    d="$(dirname "$bin")"
    if [ -f "$d/application.ini" ] && [ -d "$d/defaults/pref" ]; then
      printf '%s' "$d"
      return 0
    fi
  fi
  return 1
}

[ -f "$CFG_SRC" ] && [ -f "$JS_SRC" ] || die "找不到 files/ 下的脚本，请确认在仓库根目录运行。"

# 非 root 时自动提权
if [ "$(id -u)" -ne 0 ]; then
  info "需要管理员权限，正在通过 sudo 重新执行…"
  exec sudo bash "$SELF" "$@"
fi

# 排除不受支持的安装形态
if command -v snap >/dev/null 2>&1 && snap list firefox >/dev/null 2>&1; then
  die "检测到 snap 版 Firefox。snap 的安装目录是只读的，本方案不适用。
     建议先换成 Mozilla 官方 deb 包，再运行本脚本。"
fi

if command -v flatpak >/dev/null 2>&1 && flatpak info org.mozilla.firefox >/dev/null 2>&1; then
  die "检测到 Flatpak 版 Firefox，其应用目录不可直接写入，本方案不适用。"
fi

FF_DIR="$(detect_firefox_dir)" || die "没找到 Firefox 安装目录（已查 /usr/lib/firefox、/opt/firefox 等常见位置）。
     如果你是解压版，请手动把 files/tabutils.cfg 放到 Firefox 安装根目录，
     把 files/autoconfig.js 放到 defaults/pref/ 下。"

info "Firefox 安装目录: $FF_DIR"

# 已存在他人写的 autoconfig.js 时先备份，避免覆盖别的配置
JS_DST="$FF_DIR/defaults/pref/autoconfig.js"
if [ -f "$JS_DST" ] && ! grep -q 'general.config.filename", *"tabutils.cfg' "$JS_DST"; then
  BACKUP="$JS_DST.bak.$(date +%Y%m%d%H%M%S)"
  cp -a "$JS_DST" "$BACKUP"
  info "已备份原有 autoconfig.js -> $BACKUP"
fi

install -d -m 0755 "$FF_DIR/defaults/pref"
install -m 0644 "$JS_SRC"  "$JS_DST"
install -m 0644 "$CFG_SRC" "$FF_DIR/tabutils.cfg"

info "已写入："
echo "     $JS_DST"
echo "     $FF_DIR/tabutils.cfg"
echo
info "安装完成。请把 Firefox 完全退出（Ctrl+Q）后重新打开。"
echo "     验证：cat /tmp/firefox-tabutils.log，应看到 bound ok (window)"
echo "     开关：about:config 里把 tabutils.rightClickCloseTab 设为 false 可临时关闭"
