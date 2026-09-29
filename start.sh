```bash
#!/bin/bash
set -Eeuo pipefail

LOG_DIR=/data/logs
mkdir -p "$LOG_DIR" /data/home/brave /data/Downloads /data/cache
chown -R brave:brave /data/home/brave /data/Downloads /data/cache
chmod 700 /data/home/brave

log(){ printf '[%s] %s\n' "$(date -Is)" "$*" | tee -a "$LOG_DIR/startup.log"; }

if [[ -z "${RDP_PASSWORD:-}" ]]; then
  log "ERROR: RDP_PASSWORD is not set."
  exit 1
fi

# Set the password without putting it in the process command line.
printf 'brave:%s\n' "$RDP_PASSWORD" | chpasswd
unset RDP_PASSWORD

# Ensure the passwd database points at the persistent Railway volume.
usermod -d /data/home/brave brave

# Runtime directories needed by xrdp and the user session.
install -d -m 0700 -o brave -g brave /data/home/brave/.config /data/home/brave/.local
install -d -m 0755 -o brave -g brave /data/home/brave/.config/openbox
install -d -m 0755 -o brave -g brave /data/home/brave/.config/pcmanfm
install -d -m 0755 -o brave -g brave /data/home/brave/.local/share
install -d -m 0755 -o brave -g brave /data/home/brave/.local/state

# A persistent downloads directory, with a normal home-relative view too.
if [[ ! -e /data/home/brave/Downloads ]]; then
  ln -s /data/Downloads /data/home/brave/Downloads
fi

# Make logs readable to the session user.
touch "$LOG_DIR/session.log" "$LOG_DIR/brave.log" "$LOG_DIR/graphics.log"
chown brave:brave "$LOG_DIR"/*.log

# Debian's xrdp package may expect these directories to exist.
mkdir -p /run/dbus /run/xrdp
chown xrdp:xrdp /run/xrdp
chmod 755 /run/dbus

# Generate a fresh self-signed RDP certificate only if the package has not
# already generated one. xrdp can also use its Debian defaults.
if [[ ! -s /etc/xrdp/rsakeys.ini ]]; then
  if command -v xrdp-keygen >/dev/null 2>&1; then
    xrdp-keygen xrdp auto >/dev/null 2>&1 || true
  fi
fi

# Start a minimal system D-Bus. The X session uses dbus-run-session as a
# fallback as well, so this is not a single point of failure.
if command -v dbus-daemon >/dev/null 2>&1; then
  dbus-daemon --system --fork --nopidfile 2>>"$LOG_DIR/dbus.log" || true
fi

# Record software-rendering diagnostics without making them fatal.
{
  echo "=== graphics diagnostics $(date -Is) ==="
  echo "Kernel: $(uname -a)"
  echo "DISPLAY=${DISPLAY-}"
  glxinfo -B 2>&1 || true
  echo
  echo "=== Mesa environment ==="
  env | grep -E '^(LIBGL|MESA|GALLIUM|DRI|DISPLAY|XDG_)' || true
} >> "$LOG_DIR/graphics.log"

cleanup(){
  log "Shutdown requested."
  pkill -TERM -u brave 2>/dev/null || true
  pkill -TERM xrdp-sesman 2>/dev/null || true
  pkill -TERM xrdp 2>/dev/null || true
}
trap cleanup TERM INT

log "Starting xrdp on TCP 3389."
# xrdp and sesman are deliberately run in the foreground of their own
# background processes so the container has no systemd dependency.
/usr/sbin/xrdp-sesman --nodaemon >>"$LOG_DIR/xrdp-sesman.log" 2>&1 &
SESMAN_PID=$!
sleep 1
/usr/sbin/xrdp --nodaemon >>"$LOG_DIR/xrdp.log" 2>&1 &
XRDP_PID=$!

log "xrdp-sesman PID=$SESMAN_PID; xrdp PID=$XRDP_PID."
log "Ready for RDP connections on :3389."

# Keep the container alive and surface the important logs in Railway.
tail -F \
  "$LOG_DIR/xrdp.log" \
  "$LOG_DIR/xrdp-sesman.log" \
  "$LOG_DIR/session.log" \
  "$LOG_DIR/brave.log" \
  "$LOG_DIR/graphics.log" \
  "$LOG_DIR/startup.log" &
TAIL_PID=$!

wait -n "$XRDP_PID" "$SESMAN_PID"
STATUS=$?
log "An RDP service exited with status $STATUS. Stopping the container."
kill "$TAIL_PID" 2>/dev/null || true
exit "$STATUS"
```
