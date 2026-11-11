#!/bin/bash
# Installs the custom "us" layout in the user's XKB directory (~/.xkb),
# without touching the files of the xkeyboard-config package, so that
# package upgrades can no longer overwrite it, and a user service that
# applies it again on every keyboard hotplug. On a machine with a built-in
# keyboard (the laptop) it also swaps Ctrl and Caps Lock in the kernel, and it
# removes what is left of swapcaps. Safe to run more than once; asks for sudo
# only when the swap or /usr/local/bin/swapcaps has to change.
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
bin_dir="$HOME/.local/bin"
unit_dir="${XDG_CONFIG_HOME:-$HOME/.config}/systemd/user"
unit=keyboard-layout.service
i3_config="$HOME/.config/i3/config"
i3_line="exec --no-startup-id systemctl --user restart $unit"

# 1. the layout and the scripts
install -D -m 644 "$here/xkb/symbols/us" "$HOME/.xkb/symbols/us"
install -D -m 755 -t "$bin_dir" "$here/bin/keyboard-layout-apply" "$here/bin/keyboard-layout-watch"

# 2. the service: install, enable, (re)start so it runs the new files
install -D -m 644 -t "$unit_dir" "$here/systemd/$unit"
systemctl --user daemon-reload
systemctl --user enable "$unit"
systemctl --user restart "$unit"

# 3. i3 startup: restart the service at each session start, so it applies the
#    layout at once with this session's DISPLAY. Replaces the older lines.
if [ -f "$i3_config" ]; then
    target="$(readlink -f "$i3_config")"
    if ! grep -qxF "$i3_line" "$target"; then
        old='^exec --no-startup-id setxkbmap (us|-layout us -print \| xkbcomp .*)$'
        if grep -qE "$old" "$target"; then
            sed -i -E "s#$old#$i3_line#" "$target"
        else
            printf '%s\n' "$i3_line" >> "$target"
        fi
    fi
fi

# 4. Ctrl/Caps Lock swap, in the kernel, for the built-in keyboard only.
#    The condition is the built-in (AT) keyboard, not the absence of the HHKB:
#    with the HHKB plugged into the laptop the built-in one still needs the swap,
#    and the hwdb match leaves the HHKB (USB) untouched anyway. Laptops whose
#    built-in keyboard is USB still have an AT one, so the condition holds; the
#    hwdb file matches their USB keyboard by vendor and product.
hwdb_src="$here/udev/90-swap-capslock-ctrl.hwdb"
hwdb_dst="/etc/udev/hwdb.d/90-swap-capslock-ctrl.hwdb"

# the real keyboards (kbd handler and autorepeat, the EV_REP bit), one block
# each; power buttons and hotkey devices have neither repeat nor LEDs
keyboards() { awk -v RS= -v ORS='\n\n' '/Handlers=[^\n]*kbd/ && /EV=1[0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f]\n/' /proc/bus/input/devices; }

reload_hwdb() {
    sudo systemd-hwdb update
    sudo udevadm trigger --subsystem-match=input --action=change
}

echo "keyboards:"
keyboards | sed -n 's/^N: Name="\(.*\)"$/  \1/p'
if keyboards | grep -q '^S: Sysfs=.*/serio'; then
    if ! cmp -s "$hwdb_src" "$hwdb_dst"; then
        echo "built-in keyboard found: installing the Ctrl/Caps Lock swap"
        sudo install -D -m 644 "$hwdb_src" "$hwdb_dst"
        reload_hwdb
    fi
elif [ -e "$hwdb_dst" ]; then
    echo "no built-in keyboard: removing the Ctrl/Caps Lock swap"
    sudo rm -f "$hwdb_dst"
    reload_hwdb
fi

# which keyboards got the swap: a built-in keyboard missing here (e.g. a USB
# one) needs its own entry in the hwdb file
echo "Ctrl/Caps Lock swap:"
keyboards | grep '^H: Handlers=' | grep -o 'event[0-9]*' | while read -r ev; do
    name="$(cat "/sys/class/input/$ev/device/name")"
    if udevadm info "/dev/input/$ev" | grep -q '^E: KEYBOARD_KEY_.*=capslock$'; then
        echo "  swapped:     $name"
    else
        echo "  not swapped: $name"
    fi
done

# 5. retire swapcaps, replaced by step 4
local_conf="$HOME/.config/i3/local.conf"
if [ -f "$local_conf" ]; then
    sed -i '/^exec --no-startup-id swapcaps$/d' "$(readlink -f "$local_conf")"
fi
if [ -L "$HOME/.local/bin/swapcaps" ]; then
    rm -f "$HOME/.local/bin/swapcaps"
fi
if [ -L /usr/local/bin/swapcaps ]; then
    sudo rm -f /usr/local/bin/swapcaps
fi
