#!/bin/bash

if wmctrl -lx | grep -i 'Navigator.firefox'; then
  wmctrl -x -a 'Navigator.firefox'
else
  firefox &
  sleep 2
  wmctrl -x -a 'Navigator.firefox'
fi
