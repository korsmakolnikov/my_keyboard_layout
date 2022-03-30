#!/bin/bash

sudo cp /usr/share/X11/xkb/symbols/us /usr/share/X11/xkb/symbols/us.bak
sudo cp ./etc.share.X11.symbols.us /usr/share/X11/xkb/symbols/us
setxkbmap -layout us

