# Chasing-Your-Tail-Docs

This repository contains supporting documentation and helper scripts for running the Chasing Your Tail stack on a Linux system such as a Raspberry Pi.

## Shell Scripts

Two Bash helper scripts are included in the repository root:

- `startup.sh` starts the runtime services and optionally launches the app.
- `shutdown.sh` stops the runtime services and can optionally power the Pi off.

These scripts are meant to be run in a Linux environment with Bash, `gpsd`, and `kismet` installed. They are not intended to run directly on Windows.

## `startup.sh`

Use `startup.sh` to bring the system online in one step.

```bash
./startup.sh [gui|cli|none]
```

Available modes:

- `gui` starts `gpsd`, Kismet, and the CYT GUI.
- `cli` starts `gpsd`, Kismet, and `chasing_your_tail.py`.
- `none` starts only `gpsd` and Kismet.

What the script does:

- Verifies that the project directory exists.
- Verifies that the Python virtual environment exists at `venv/bin/activate`.
- Detects a GPS device automatically, or uses `GPS_DEVICE` if set.
- Stops old `gpsd`, Kismet, and CYT processes before starting fresh ones.
- Writes runtime logs and PID files into the runtime log directory.

Default paths:

- `CYT_PROJECT_DIR` defaults to `$HOME/Chasing-Your-Tail-NG`
- `CYT_RUNTIME_DIR` defaults to `$CYT_PROJECT_DIR/runtime_logs`
- `KISMET_LOG_DIR` defaults to `$HOME/kismet_logs`

Optional environment variables:

- `CYT_PROJECT_DIR` overrides the project folder.
- `CYT_RUNTIME_DIR` overrides where runtime logs and PID files are stored.
- `KISMET_LOG_DIR` overrides where Kismet logs are written.
- `GPS_DEVICE` forces a specific GPS device such as `/dev/ttyACM0`.

Examples:

```bash
./startup.sh gui
./startup.sh cli
./startup.sh none
GPS_DEVICE=/dev/ttyUSB0 ./startup.sh gui
```

After startup, Kismet is available at:

- `http://localhost:2501`
- `http://pi400.local:2501`

## `shutdown.sh`

Use `shutdown.sh` to stop the services started by `startup.sh`.

```bash
./shutdown.sh [--poweroff]
```

What the script stops:

- CYT GUI
- `chasing_your_tail.py`
- Kismet
- `gpsd`

What the script does:

- Stops processes using PID files when available.
- Falls back to `pkill` for cleanup if processes are still running.
- Stops `gpsd` services through `systemctl`.
- Optionally powers off the Pi after shutdown completes.

Examples:

```bash
./shutdown.sh
./shutdown.sh --poweroff
```

## Typical Workflow

```bash
./startup.sh gui
# use the system
./shutdown.sh
```