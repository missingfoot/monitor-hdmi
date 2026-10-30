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

1. **Install the tools**

   ```
   sudo pacman -S i2c-tools ddcutil
   ```

   ddcutil's udev rule gives your logged-in user access to `/dev/i2c-*`, so
   you don't need the `i2c` group. Reboot or log out and back in afterwards.
   Check that `ddcutil detect` lists the MX279.

2. **Install the script and launcher.** Using HDMI 1 as the example (swap
   in `2` for HDMI 2):

   ```
   gh repo clone missingfoot/monitor-hdmi
   cd monitor-hdmi
   install -Dm755 hdmi-1/monitor-hdmi1.sh ~/.local/bin/monitor-hdmi1.sh
   install -Dm644 hdmi-1/monitor-hdmi1.desktop ~/.local/share/applications/monitor-hdmi1.desktop
   ```

   Change the launcher's `Exec=` path if the username isn't `james`.

3. **Hotkey (optional).** The keyboard has a key that sends Super+H.
   - KDE: System Settings → Shortcuts → add the "HDMI 1" launcher and set it
     to Meta+H. This writes `[services][monitor-hdmi1.desktop] _launch=Meta+H`
     to `~/.config/kglobalshortcutsrc`. **Log out and back in**, because
     Plasma 6 only loads launcher shortcuts at login.
   - Xfce: Settings → Keyboard → Application Shortcuts → `<Super>h` → the
     script.

4. **Test.** With the monitor on the other input, run the script from a
   terminal. It should exit with code 0 and the monitor should switch.

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
