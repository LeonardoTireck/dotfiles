#!/usr/bin/env bash
# Focus an existing Ghostty window or launch a new one.

GHOSTTY_BIN="/snap/bin/ghostty"
CLASS="ghostty.com.mitchellh.ghostty"

WIN_ID=$(wmctrl -lx | awk -v cls="$CLASS" '$3 ~ cls {print $1; exit}')

if [ -n "$WIN_ID" ]; then
  wmctrl -ia "$WIN_ID"
  exit 0
fi

"$GHOSTTY_BIN" &>/dev/null &
