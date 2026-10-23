# Intel Bluetooth firmware (`intel_bluetooth_firmwares`)

Firmware for the Intel Wireless 8260 and 8265 Bluetooth controllers (USB
`8087:0a2b`), for example in the Xiaomi Mi Air 12.5. These controllers start in
a bootloader and need this firmware before the Bluetooth stack can use them.

The package installs these files from linux-firmware 20261019 (commit
`a2dcb924f0897368b0b4f305cbf9808cdda90ce0`) to `data/firmware/h2generic/`:

| File | Controller |
| --- | --- |
| `ibt-11-5.sfi`, `ibt-11-5.ddc` | 8260 |
| `ibt-12-16.sfi`, `ibt-12-16.ddc` | 8265 |

The files are unmodified. The Intel license (`licenses/Intel Bluetooth Firmware`,
from `LICENSES/LICENCE.ibt_firmware` in linux-firmware) permits redistribution in
binary form.

## Driver requirement

The stock Haiku `h2generic` driver does not load this firmware. A firmware
loader for `h2generic` is proposed to RenkuOS. Without that driver change, this
package has no effect.

## Rebuild

Put the recipe and the `licenses/` directory in
`<tree>/sys-firmware/intel-bluetooth-firmwares/` and run
`haikuporter intel_bluetooth_firmwares`. The recipe downloads each file from
git.kernel.org at the pinned commit and checks its SHA-256.
