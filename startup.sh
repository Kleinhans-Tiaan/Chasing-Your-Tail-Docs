#!/usr/bin/env bash
set -euo pipefail

MODE="${1:-gui}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="${CYT_PROJECT_DIR:-$HOME/Chasing-Your-Tail-NG}"
RUNTIME_DIR="${CYT_RUNTIME_DIR:-$PROJECT_DIR/runtime_logs}"
KISMET_LOG_DIR="${KISMET_LOG_DIR:-$HOME/kismet_logs}"

usage() {
  cat <<'EOF'
Usage: ./startup.sh [gui|cli|none]

Modes:
  gui   Start gpsd, Kismet, and the CYT GUI
  cli   Start gpsd, Kismet, and chasing_your_tail.py
  none  Start gpsd and Kismet only

Optional environment variables:
  CYT_PROJECT_DIR   Override the project folder
  CYT_RUNTIME_DIR   Override where startup logs are written
  KISMET_LOG_DIR    Override the Kismet log directory
  GPS_DEVICE        Force a GPS device path such as /dev/ttyACM0
EOF
}

case "$MODE" in
  gui|cli|none) ;;
  -h|--help|help)
    usage
    exit 0
    ;;
  *)
    echo "Unknown mode: $MODE" >&2
    usage
    exit 1
    ;;
esac

if [[ ! -d "$PROJECT_DIR" ]]; then
  echo "Project directory not found: $PROJECT_DIR" >&2
  exit 1
fi

if [[ ! -f "$PROJECT_DIR/venv/bin/activate" ]]; then
  echo "Virtual environment not found in: $PROJECT_DIR/venv" >&2
  exit 1
fi

GPS_DEVICE="${GPS_DEVICE:-}"
if [[ -z "$GPS_DEVICE" ]]; then
  for candidate in /dev/ttyACM0 /dev/ttyUSB0 /dev/ttyACM1 /dev/ttyUSB1; do
    if [[ -e "$candidate" ]]; then
      GPS_DEVICE="$candidate"
      break
    fi
  done
fi

if [[ -z "$GPS_DEVICE" ]]; then
  echo "No GPS device found. Expected something like /dev/ttyACM0." >&2
  exit 1
fi

mkdir -p "$RUNTIME_DIR" "$KISMET_LOG_DIR"

echo "Stopping old processes..."
sudo systemctl stop gpsd.socket gpsd.service >/dev/null 2>&1 || true
sudo pkill gpsd >/dev/null 2>&1 || true
pkill -f "/usr/local/bin/kismet" >/dev/null 2>&1 || true
pkill -f "python3 .*cyt_gui.py" >/dev/null 2>&1 || true
pkill -f "python3 .*chasing_your_tail.py" >/dev/null 2>&1 || true
sleep 2

echo "Starting gpsd on $GPS_DEVICE..."
sudo gpsd -n "$GPS_DEVICE" -F /var/run/gpsd.sock
sleep 2

echo "Starting Kismet..."
nohup kismet >"$RUNTIME_DIR/kismet.log" 2>&1 &
echo $! > "$RUNTIME_DIR/kismet.pid"
sleep 5

if [[ "$MODE" == "gui" ]]; then
  if [[ -z "${DISPLAY:-}" ]]; then
    echo "DISPLAY is not set. GUI launch skipped. Run './startup.sh none' or './startup.sh cli' over SSH." >&2
    MODE="none"
  else
    echo "Starting CYT GUI..."
    (
      cd "$PROJECT_DIR"
      source "$PROJECT_DIR/venv/bin/activate"
      nohup python3 cyt_gui.py >"$RUNTIME_DIR/cyt_gui.log" 2>&1 &
      echo $! > "$RUNTIME_DIR/cyt_gui.pid"
    )
  fi
elif [[ "$MODE" == "cli" ]]; then
  echo "Starting CYT CLI..."
  (
    cd "$PROJECT_DIR"
    source "$PROJECT_DIR/venv/bin/activate"
    nohup python3 chasing_your_tail.py >"$RUNTIME_DIR/chasing_your_tail.log" 2>&1 &
    echo $! > "$RUNTIME_DIR/chasing_your_tail.pid"
  )
fi

cat <<EOF

Startup complete.

Project dir:      $PROJECT_DIR
Runtime logs:     $RUNTIME_DIR
GPS device:       $GPS_DEVICE
Kismet log dir:   $KISMET_LOG_DIR
Mode:             $MODE

Useful checks:
  gpspipe -w | head -20
  tail -f "$RUNTIME_DIR/kismet.log"
  ls "$KISMET_LOG_DIR"

Kismet UI:
  http://localhost:2501
  http://pi400.local:2501
EOF
