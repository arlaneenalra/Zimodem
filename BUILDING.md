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
python3 -m http.server 8000 -d build/update-site
```

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

Header J8 (UART1, 3.3 V): TX GP20 -> ESP RXD (GPIO3), RX GP21 <- ESP TXD
(GPIO1), RTS GP23 -> ESP GPIO5 (Zimodem CTS), CTS GP22 <- ESP GPIO4
(Zimodem RTS), 3V3 and GND. DTR/DSR/DCD/RI stay unconnected (leave S63=0).
Add 100-470 uF at the module for the transmit current peaks.
