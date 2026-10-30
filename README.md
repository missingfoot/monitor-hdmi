# monitor-hdmi

Switches the ASUS MX279 monitor's input from the PC, over DDC/CI. Each PC gets
a launcher (and a Meta+H hotkey) that pulls the monitor over to its own input:

| PC         | Script             | Launcher | Input value |
|------------|--------------------|----------|-------------|
| beast      | `monitor-hdmi2.sh` | HDMI 2   | `0x12`      |
| baby-beast | `monitor-hdmi1.sh` | HDMI 1   | `0x11`      |

Grab the folder for the input the PC is plugged into:

- `hdmi-1/` — `monitor-hdmi1.sh` + "HDMI 1" launcher
- `hdmi-2/` — `monitor-hdmi2.sh` + "HDMI 2" launcher

The two scripts are the same apart from `TARGET` and the names.

## How it works

The script sends the DDC/CI "set VCP 0x60 (Input Source)" command straight to
the monitor at i2c address `0x37` with `i2ctransfer`. That takes about 20 ms,
while each `ddcutil` call takes about 2 s. The NVIDIA i2c bus often drops
commands, so the script reads the input back and resends until the monitor
reports the target input. If it fails after about 3 s, you get a notification.

`ddcutil` is only used once, on the first run, to find which `/dev/i2c-N` bus
the MX279 is on. The bus number is cached in `~/.cache/monitor-hdmiN.bus`. If
the cached bus stops working, the script detects it again.

Input values: `0x11` = HDMI 1, `0x12` = HDMI 2, `0x01` = VGA.

## Setting it up on a PC (Arch/CachyOS)

```
gh repo clone missingfoot/monitor-hdmi && cd monitor-hdmi
./install 1        # or ./install 2 — the input this PC is plugged into
```

`./install` does the following:

- installs `i2c-tools`, `ddcutil` and `libnotify` if they're missing (asks
  for sudo). ddcutil also loads the `i2c-dev` kernel module on every boot.
- copies `monitor-hdmiN.sh` to `~/.local/bin` and the "HDMI N" launcher to
  `~/.local/share/applications`, with `Exec=` pointed at your own home, and
  refreshes the app menu so "HDMI N" shows up straight away
- on KDE, binds Meta+H to the launcher and removes the other input's Meta+H
  binding if it exists. The keyboard has a key that sends Super+H.

Then **log out and back in**. ddcutil's udev rule (which gives your user
access to `/dev/i2c-*`) and Plasma 6 launcher shortcuts both only apply at
login. To test, put the monitor on the other input and run `monitor-hdmiN.sh`
in a terminal. It should exit with code 0 and the monitor should switch.

On Xfce, bind the hotkey yourself: Settings → Keyboard → Application
Shortcuts → `<Super>h` → the script.

To do it by hand, install the two packages and copy the files from `hdmi-N/`
to the same places. The shortcut lives in `~/.config/kglobalshortcutsrc` as
`[services][monitor-hdmiN.desktop] _launch=Meta+H`.

## Troubleshooting

- **Nothing happens / "Monitor switch failed":** make sure DDC/CI is turned
  on in the monitor's OSD menu. Delete `~/.cache/monitor-hdmiN.bus` and try
  again.
- **Permission denied on `/dev/i2c-*`:** the ddcutil udev rule isn't active
  yet, so log in again. You can also add your user to the `i2c` group as a
  fallback (`sudo usermod -aG i2c $USER`). If `/dev/i2c-*` doesn't exist,
  load the module with `sudo modprobe i2c-dev`, and make it permanent with
  `echo i2c-dev | sudo tee /etc/modules-load.d/i2c-dev.conf`.

Related: keyboard/mouse sharing between the PCs is done with Deskflow (edge
switching). Deskflow can't switch the monitor, which is why this tool exists.
