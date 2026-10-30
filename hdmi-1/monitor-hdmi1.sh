#!/usr/bin/env bash
# Switch the ASUS MX279 monitor input to HDMI-1 via DDC/CI.
# VCP feature 0x60 = Input Source; value 0x11 = HDMI-1 (0x12 = HDMI-2, 0x01 = VGA).
#
# Talks raw DDC/CI with i2ctransfer: a write takes ~20ms, whereas each ddcutil
# call costs ~2s of startup and built-in sleeps. The monitor often drops
# commands over the NVIDIA i2c bus and writes can't be acknowledged, so we
# read the input back and resend until it actually reports HDMI-1.
set -uo pipefail

TARGET=0x11
CACHE=${XDG_CACHE_HOME:-$HOME/.cache}/monitor-hdmi1.bus

# DDC/CI packets to the monitor at 0x37; last byte is the XOR checksum
# (seeded with 0x6E, the host's write address).
set_input() {
    local chk=$((0x6E ^ 0x51 ^ 0x84 ^ 0x03 ^ 0x60 ^ 0x00 ^ TARGET))
    i2ctransfer -y "$bus" w7@0x37 0x51 0x84 0x03 0x60 0x00 "$TARGET" "$chk" 2>/dev/null
}

# Prints the current input value (e.g. 0x11), or nothing if the reply was garbled.
get_input() {
    i2ctransfer -y "$bus" w5@0x37 0x51 0x82 0x01 0x60 0xDC 2>/dev/null || return
    sleep 0.05
    local r
    r=($(i2ctransfer -y "$bus" r11@0x37 2>/dev/null)) || return
    # Valid reply: 6E 88 02 <rc=00> 60 <type> <maxH> <maxL> <curH> <curL> <chk>
    [[ ${r[0]} == 0x6e && ${r[1]} == 0x88 && ${r[3]} == 0x00 && ${r[4]} == 0x60 ]] &&
        echo "${r[9]}"
}

detect_bus() {
    ddcutil detect --terse 2>/dev/null |
        awk '/I2C bus:/ {b=$3} /MX279/ {sub("/dev/i2c-", "", b); print b; exit}'
}

bus=$(cat "$CACHE" 2>/dev/null)
if [[ -z $bus ]] || ! set_input; then
    bus=$(detect_bus)
    [[ -n $bus ]] && echo "$bus" >"$CACHE"
    [[ -n $bus ]] && set_input
fi

if [[ -n $bus ]]; then
    # Poll the input for ~3s, resending whenever the monitor clearly ignored us.
    # A string of garbled reads right after a send is normal on this bus.
    misses=0
    for ((i = 0; i < 15; i++)); do
        sleep 0.2
        cur=$(get_input)
        if [[ $cur == "$TARGET" ]]; then
            exit 0
        elif [[ -n $cur ]]; then
            set_input
            misses=0
        else
            # Once switched away, some monitors stop answering on the old
            # input; lots of silence after a send most likely means it worked.
            ((++misses >= 10)) && exit 0
        fi
    done
fi

command -v notify-send >/dev/null &&
    notify-send "Monitor switch failed" "Monitor still on input ${cur:-unknown}."
exit 1
