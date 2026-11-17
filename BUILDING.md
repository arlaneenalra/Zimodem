# Building with arduino-cli

A command-line build of Zimodem for a 4 MB ESP-12F (AI-Thinker or
"ESP8266MOD"), without the Arduino IDE. The toolchain is pinned in
`toolchain.env` (arduino-cli 1.5.1, ESP8266 core 2.7.4, the version the
README recommends) and installed under the repo in `.arduino15/`
(git-ignored); needs `curl`, `python3` and `git`.

```sh
scripts/setup-toolchain.sh   # arduino-cli + ESP8266 core 2.7.4 -> .arduino15/
scripts/build.sh             # -> build/zimodem.ino.bin, build/build-info.txt
scripts/cli.sh ...           # the pinned arduino-cli with this repo's config
```

`build.sh` defaults to the Generic ESP8266 Module at 160 MHz, DIO flash at
40 MHz, 4 MB with a 1 MB filesystem (`eesz=4M1M`, for SPIFFS). Override
with `FQBN=...`, e.g. `eesz=1M160` for a 1 MB ESP-01. Zimodem only enables
GPIO4/5 (RTS/CTS) and GPIO9-16 on modules with at least 4 MB of flash.

## Flashing

Hold GPIO0 low across a reset to enter the boot loader (unless the adapter
does it from DTR/RTS). The first time, erase the old firmware so no stale
config or RF calibration is left:

```sh
ESPTOOL="python3 .arduino15/packages/esp8266/hardware/esp8266/2.7.4/tools/esptool/esptool.py"
$ESPTOOL --port /dev/ttyUSB0 read_flash 0 0x400000 stock-backup.bin  # optional
$ESPTOOL --port /dev/ttyUSB0 erase_flash
$ESPTOOL --port /dev/ttyUSB0 write_flash -fm dio 0 build/zimodem.ino.bin
```

The first boot formats SPIFFS (a pause), then shows `INITIALIZED` and
`READY` at the default 1200 baud.

## Over-the-air updates (AT&U)

Each build's version is `4.0.3-<BUILD_ID>` (ATI4, the banner), BUILD_ID
being the UTC build time as digits unless set. `scripts/update-site.sh`
builds and lays out an update site in `build/update-site` (`SITE_DIR=...`
for another directory, `NO_BUILD=1` to publish the last build), keeping
earlier images so you can roll back:

```sh
scripts/update-site.sh
scripts/serve-update-site.py            # port 8000, build/update-site (-p, -d)
```

Use `serve-update-site.py` rather than `python3 -m http.server`: that
sends the headers and the body separately, and firmware before the fix
(including stock Zimodem) checks the image's first byte before it has
arrived, so the update fails with ERROR (a broken pipe on the server).

On the modem (plain HTTP; the ESP8266 has too little RAM for HTTPS):

| Command | |
|---|---|
| `AT&U?` | show the update site (Frankless default `http://claude-box.seg9.com:8000`) |
| `AT&U"http://host:port/path"` | set it (then `AT&W` to keep it); `AT&U""` resets the default |
| `AT&U` | compare with `<site>/frankless-latest-version.txt` |
| `AT&U6502` | install `<site>/frankless-firmware-<latest>.bin` and restart |
| `AT&U=4.0.3-<id>` | install that version (roll back) |

The update replaces only the program; saved settings (SPIFFS) stay. The
image is not signed: anyone who can type AT commands can install any image.

## Frankless / dvi-feather-terminal wiring

Header J8 (UART1, 3.3 V; pins 1-6: 3V3, GND, RTS, CTS, RX, TX):

| J8 | ESP-12F |
|---|---|
| 1 3V3 | VCC (and EN, through its pull-up) |
| 2 GND | GND |
| 3 RTS (GP23, out) | GPIO13 (U0CTS) |
| 4 CTS (GP22, in) | GPIO15 (U0RTS); 10 kOhm to GND, the boot strap |
| 5 RX (GP21, in) | TXD (GPIO1) |
| 6 TX (GP20, out) | RXD (GPIO3) |

DTR/DSR/DCD/RI stay unconnected (leave S63=0). Add 100-470 uF at the
module for the transmit current peaks.

GPIO13 and GPIO15 are the UART's own CTS and RTS, so with RTS/CTS flow
control the UART stops sending within a byte by itself and Zimodem fills
its 128-byte TX FIFO instead of writing a byte at a time
(serout.ino serialHwFlowApply). The Frankless build fixes them there
(FRANKLESS_HW_FLOW, default 1): saved S49/S51 values are ignored, ATS49 and
ATS51 refuse other pins, and DSR (GPIO13 in stock Zimodem) is off. GPIO15
must be low when the module resets or it does not boot from flash:
carrier boards have the pull-down, a bare module needs it added.

The earlier wiring (RTS GP23 -> GPIO5, CTS GP22 <- GPIO4, read and
driven in software) needs a build with `FRANKLESS_HW_FLOW=0
scripts/build.sh` (or `update-site.sh`); its pins are S49/S51 as in stock
Zimodem.

WiFi in the Frankless build (stock Zimodem is unchanged):

- Modem sleep off (`WIFI_NONE_SLEEP`): with it, an interactive session
  froze for 2-3 s at a time (missed packets, TCP retransmissions). Set
  before `WiFi.begin()` it did not always stick (after a rejoin the ping
  was 100-200 ms again), so `checkReconnect()` also puts it back once a
  second while connected. Under a full-speed stream pings still read
  100-200 ms: that is the 115200 serial line's queue, not sleep.
- `WiFi.persistent(false)`: the SSID and password are Zimodem's own (ATW,
  saved by AT&W) and passed to every `WiFi.begin()`; the SDK no longer
  rewrites its copy in flash on each connect and disconnect, where a reset
  mid-write left a network the modem could not rejoin without a new ATW.
- Each join attempt gets 30 s (stock 10 s), and a lost network is retried
  every 30 s after the last attempt ended (stock: 60 s doubling to 30
  minutes). An attempt blocks the modem while it runs, so AT commands
  typed meanwhile wait.
