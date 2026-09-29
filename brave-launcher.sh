#!/bin/bash
set -u

LOG=/data/logs/brave.log
exec >>"$LOG" 2>&1

export HOME=/data/home/rdp
export XDG_CONFIG_HOME="$HOME/.config"
export XDG_DATA_HOME="$HOME/.local/share"
export XDG_STATE_HOME="$HOME/.local/state"
export XDG_CACHE_HOME=/tmp/rdp-cache
export LIBGL_ALWAYS_SOFTWARE=1
export MESA_LOADER_DRIVER_OVERRIDE=llvmpipe
export GDK_BACKEND=x11
export QT_X11_NO_MITSHM=1

mkdir -p "$XDG_CONFIG_HOME" "$XDG_DATA_HOME" "$XDG_STATE_HOME" /tmp/rdp-cache
chown -R rdp:rdp "$HOME" /tmp/rdp-cache 2>/dev/null || true

echo "=== Brave launch $(date -Is) ==="
echo "DISPLAY=${DISPLAY:-unset}"

# Do not use --no-sandbox. Brave is a non-root user and should retain the
# Chromium sandbox. Disable GPU paths that are commonly problematic inside
# headless/containerized Xorg, while keeping normal multi-process Chromium
# operation, extensions, tabs, windows, downloads, and media.
exec /usr/bin/brave-browser \
  --ozone-platform=x11 \
  --disable-gpu \
  --disable-gpu-compositing \
  --disable-dev-shm-usage \
  --no-first-run \
  --no-default-browser-check \
  --user-data-dir="$HOME/.config/BraveSoftware/Brave-Browser" \
  "$@"
