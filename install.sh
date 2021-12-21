#!/bin/bash

sudo cp /usr/share/X11/xkb/symbols/us /usr/share/X11/xkb/symbols/us.bak
sudo cp us /usr/share/X11/xkb/symbols/
setxkbmap -layout us

# Set fn keys to normal behavior
echo 2 | sudo tee /sys/module/hid_apple/parameters/fnmode

sudo cp ./etc.default.keyboard /etc/default/keyboard
