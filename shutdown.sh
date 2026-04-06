#!/usr/bin/env bash
set -euo pipefail

POWER_OFF="${1:-}"
PROJECT_DIR="${CYT_PROJECT_DIR:-$HOME/Chasing-Your-Tail-NG}"
RUNTIME_DIR="${CYT_RUNTIME_DIR:-$PROJECT_DIR/runtime_logs}"

usage() {
  cat <<'EOF'
Usage: ./shutdown.sh [--poweroff]

Stops:
  - CYT GUI
  - chasing_your_tail.py
  - Kismet
  - gpsd

Options:
  --poweroff   Shut down the Pi after stopping processes
EOF
}

case "$POWER_OFF" in
  ""|--poweroff) ;;
  -h|--help|help)
    usage
    exit 0
    ;;
  *)
    echo "Unknown option: $POWER_OFF" >&2
    usage
    exit 1
    ;;
esac

stop_pidfile() {
  local label="$1"
  local pidfile="$2"

  if [[ -f "$pidfile" ]]; then
    local pid
    pid="$(cat "$pidfile" 2>/dev/null || true)"
    if [[ -n "$pid" ]] && kill -0 "$pid" 2>/dev/null; then
      echo "Stopping $label (pid $pid)..."
      kill "$pid" 2>/dev/null || true
      sleep 2
      if kill -0 "$pid" 2>/dev/null; then
        kill -9 "$pid" 2>/dev/null || true
      fi
    fi
    rm -f "$pidfile"
  fi
}

echo "Stopping CYT processes..."
stop_pidfile "CYT GUI" "$RUNTIME_DIR/cyt_gui.pid"
stop_pidfile "CYT CLI" "$RUNTIME_DIR/chasing_your_tail.pid"
pkill -f "python3 .*cyt_gui.py" >/dev/null 2>&1 || true
pkill -f "python3 .*chasing_your_tail.py" >/dev/null 2>&1 || true

echo "Stopping Kismet..."
stop_pidfile "Kismet" "$RUNTIME_DIR/kismet.pid"
pkill -f "/usr/local/bin/kismet" >/dev/null 2>&1 || true
pkill -x kismet >/dev/null 2>&1 || true

echo "Stopping gpsd..."
sudo pkill gpsd >/dev/null 2>&1 || true
sudo systemctl stop gpsd.socket gpsd.service >/dev/null 2>&1 || true

echo "Shutdown complete."

if [[ "$POWER_OFF" == "--poweroff" ]]; then
  echo "Powering off Pi..."
  sudo shutdown -h now
fi
