#!/usr/bin/env bash
# uninstall.sh —— 移除「标签栏右键关闭标签」
#
# 用法：./uninstall.sh

set -euo pipefail

SELF="$(readlink -f "${BASH_SOURCE[0]}")"

die() { printf '\033[31m错误:\033[0m %s\n' "$*" >&2; exit 1; }
info() { printf '\033[36m==>\033[0m %s\n' "$*"; }

if [ "$(id -u)" -ne 0 ]; then
  exec sudo bash "$SELF" "$@"
fi

FF_DIR="$(for d in /usr/lib/firefox /usr/lib64/firefox /usr/lib/firefox-esr \
                    /usr/lib64/firefox-esr /opt/firefox /opt/firefox-esr; do
  if [ -f "$d/tabutils.cfg" ]; then printf '%s' "$d"; break; fi
done)"

if [ -z "${FF_DIR:-}" ] || [ ! -f "$FF_DIR/tabutils.cfg" ]; then
  die "没找到已安装的 tabutils.cfg，可能本来就没装。"
fi

info "从 $FF_DIR 移除…"
rm -f "$FF_DIR/tabutils.cfg"

JS_DST="$FF_DIR/defaults/pref/autoconfig.js"
if [ -f "$JS_DST" ] && grep -q 'general.config.filename", *"tabutils.cfg' "$JS_DST"; then
  rm -f "$JS_DST"
  info "已删除 autoconfig.js"
else
  info "autoconfig.js 不存在或不属于本项目，已保留"
fi

rm -f /tmp/firefox-tabutils.log
info "完成。重启 Firefox 生效。"
