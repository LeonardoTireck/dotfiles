#!/bin/bash

if wmctrl -lx | grep -i 'code.Code'; then
  wmctrl -x -R 'code.Code'
else
  code &
  sleep 2
  wmctrl -x -R 'code.Code'
fi
