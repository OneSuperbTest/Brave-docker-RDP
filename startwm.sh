#!/bin/bash
set -u

LOG=/data/logs/session.log
exec >>"$LOG" 2>&1

echo "=== XRDP session start $(date -Is) ==="
echo "DISPLAY=${DISPLAY:-unset}"
echo "USER=${USER:-unset}"
echo "HOME=${HOME:-unset}"

export HOME=/data/home/brave
export XDG_CONFIG_HOME="$HOME/.config"
export XDG_DATA_HOME="$HOME/.local/share"
export XDG_STATE_HOME="$HOME/.local/state"
export XDG_CACHE_HOME=/tmp/rdp-cache
export XDG_CURRENT_DESKTOP=Openbox
export XDG_SESSION_DESKTOP=openbox
export DESKTOP_SESSION=openbox
export LIBGL_ALWAYS_SOFTWARE=1
export MESA_LOADER_DRIVER_OVERRIDE=llvmpipe
export GDK_BACKEND=x11
export QT_X11_NO_MITSHM=1

mkdir -p "$XDG_CONFIG_HOME/openbox" "$XDG_CONFIG_HOME/pcmanfm" \
         "$XDG_DATA_HOME" "$XDG_STATE_HOME" /tmp/brave-cache
chown -R brave:brave "$HOME" /tmp/brave-cache 2>/dev/null || true

# Give xrdp/Xorg a moment to finish setting up RandR before Openbox starts.
sleep 1

# Ensure Openbox itself cannot take down the session if it unexpectedly exits.
# The loop only restarts Openbox after it exits, and never starts duplicate
# instances because each iteration waits for the previous process.
while true; do
  echo "Starting Openbox: $(date -Is)"
  if command -v dbus-run-session >/dev/null 2>&1; then
    dbus-run-session -- openbox-session
  else
    openbox-session
  fi
  rc=$?
  echo "Openbox exited with status $rc at $(date -Is)"
  sleep 1
done
