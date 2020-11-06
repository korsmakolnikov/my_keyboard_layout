#!/bin/bash

sudo cp /usr/share/X11/xkb/symbols/us /usr/share/X11/xkb/symbols/us.bak
sudo cp us /usr/share/X11/xkb/symbols/
setxkbmap -layout us
