#!/bin/sh
# Runs the system's stock labwc headless with a few test apps, for testing
# nim-expose without touching the real session. Prints nothing; the
# Wayland socket name is in the log (WAYLAND_DISPLAY=...).
#   tests/run-labwc.sh > log 2>&1 &
here=$(cd "$(dirname "$0")" && pwd)
export WLR_BACKENDS=headless WLR_HEADLESS_OUTPUTS=1 WLR_LIBINPUT_NO_DEVICES=1
export PATH="$here/../build:$PATH"
exec dbus-run-session -- labwc -C "$here/labwc-config" -d
