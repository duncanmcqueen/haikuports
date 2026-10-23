# Additional packages for HaikuPorts

This is a personal **additional package repository** for Haiku R1/beta6 x86_64.
It supplements the official Haiku and HaikuPorts repositories. Keep those repositories enabled.
This repository is not maintained or endorsed by the Haiku or HaikuPorts projects.

I worked on [BeKaffe](https://bekaffe.sourceforge.net/), the project that brought
Java to BeOS, a long time ago. I am not part of the pi or HaikuPorts projects. I
publish these packages because I want to help move Haiku forward.

## AI assistance, human review, and AS-IS software

Some packages, recipes, patches, and scripts in this repository may have been created
with the assistance of AI. Human review and validation matter and occur in the process.
That review does not guarantee correctness. These packages can contain defects,
compatibility problems, or incomplete functionality.

**Everything here is provided AS-IS, without warranties or guarantees of any kind.**
Upstream component licenses continue to apply. Review changes and package-manager
proposals before installation or updates. Keep backups of important data.

## Configure a clean Haiku installation

Use Terminal on Haiku R1/beta6 **x86_64**:

```sh
pkgman add-repo https://duncanmcqueen.github.io/haikuports/r1beta6/x86_64
pkgman refresh DuncanHaikuPackages
pkgman install nodejs22 npm
node --version
node -p 'process.versions.icu'
```

To install the `pi` coding agent and its Haiku developer skills:

```sh
pkgman install pi haiku_agent_library
pi install /boot/system/data/haiku-agent-library
pi
```

If `pi` is not found after installation, reboot Haiku. New system packages become
available on the next boot.

The current package is Node.js 22.23.3. Its compiled binary loads ICU 77, so this
repository also supplies `icu77`. pkgman installs that runtime dependency automatically.
ICU 74 remains available from the official repositories. Node can be rebuilt against
ICU 74; that does not change the ICU dependency of an already compiled binary.

If Node.js 20 is installed, Node.js 22 conflicts with it. If necessary, uninstall `nodejs20` and its development package before installing Node 22.
Development headers are optional: `pkgman install nodejs22_devel`.
ICU development files and tools are also optional; they are not needed to run Node.

## Packages in this repository

| Package | Purpose |
|---------|---------|
| `nodejs22` | Node.js 22.23.3 runtime (loads ICU 77) |
| `nodejs22_devel` | Node.js development files |
| `icu77`, `icu77_devel`, `icu77_tools` | ICU 77 runtime for the Node binary, plus optional development and tool files, from the maintained `icu77` port |
| `filmcraft` | Experimental video editor with native file panels and SDL2 audio |
| `wordcraft` | Experimental word processor with a Haiku frontend |
| `fd` | `fd` file-search tool used by `pi` |
| `pi` | The `pi` coding agent (`pi` command) |
| `haiku_agent_library` | Haiku developer skills for `pi`, including the Haiku Book API reference |
| `intel_bluetooth_firmwares` | Firmware for Intel 8260/8265 Bluetooth controllers; needs a patched `h2generic` driver |

## Rebuild the packages

Recipes, patchsets, and build scripts are public:

- Full rebuild guide: `sources/README.md`, at
  `https://github.com/duncanmcqueen/haikuports/tree/personal-packages/sources`.
- Node.js 22 recipe and patchset:
  `https://github.com/duncanmcqueen/haikuports/tree/nodejs22/net-libs/nodejs`.
  Rebuild with `sources/nodejs22/rebuild-node-haiku.sh`.
- ICU 77 recipe:
  `https://github.com/duncanmcqueen/haikuports/tree/icu77/dev-libs/icu`.
- `fd` recipe, the pi patch and build scripts, and the agent-library archive and
  builder: the `sources/` directory.

## Future updates and SoftwareUpdater

`pkgman add-repo` saves a system repository configuration. It persists across restarts.
You can also use **Deskbar → Preferences → Repositories**: press the add (`+`)
button, paste `https://duncanmcqueen.github.io/haikuports/r1beta6/x86_64`, and enable
the new entry. Keep `Haiku`, `HaikuPorts`, and `DuncanHaikuPackages` enabled.
SoftwareUpdater uses the registered repositories, including this one, when it checks
for updates. It can then offer newer packages published here. Installation of updates
still follows SoftwareUpdater's normal confirmation flow.

Check the registration:

```sh
pkgman list-repos
```

Refresh this repository and update Node from Terminal:

```sh
pkgman refresh DuncanHaikuPackages
pkgman update nodejs22
```

Or check all enabled repositories with `pkgman update` or Softwarte downloads. GitHub Pages limits this hosting approach to a
1 GB site; move to a larger host if the package collection outgrows it.

See `BUILD-INFO.md` for the provenance and verification of the current package set.
eUpdater.
This repository has priority 0 (the official repositories on beta6 use priority 1).
Only personal packages are included; official repositories continue to supply their
dependencies. Keep this repository registered so repository synchronization has a
source for Node.js 22 rather than substituting Node.js 20.

To stop receiving these packages:

```sh
pkgman drop-repo DuncanHaikuPackages
```

Dropping the repository does not uninstall packages. A later full synchronization
can replace or remove packages that are no longer provided by an enabled repository.


## Filmcraft

Install the experimental video editor with `pkgman install filmcraft`. Open it
from Deskbar > Applications. The current package is 0.8.0-4. It uses CPU
rendering; hardware acceleration and microphone capture are not implemented.
See [sources/filmcraft/README.md](sources/filmcraft/README.md) for tests, limits
and build instructions.

## Intel Bluetooth firmware

`pkgman install intel_bluetooth_firmwares` installs the firmware for the Intel
Wireless 8260 and 8265 Bluetooth controllers (USB `8087:0a2b`) to
`/boot/system/data/firmware/h2generic/`. The stock `h2generic` driver does not
load it yet; a firmware loader is proposed to RenkuOS. Tested on a Xiaomi Mi
Air 12.5 (8260) with the patched driver. The 8265 files are not tested.
[Source and notes](sources/intel-bluetooth-firmwares/README.md).

## Pdfcraft

Experimental PDF editor for Haiku x86_64:

```sh
pkgman refresh DuncanHaikuPackages
pkgman install pdfcraft
```

Open Pdfcraft from Deskbar > Applications, or run `pdfcraft file.pdf`.
The package includes `pdfcraft-cli`. Opening, rendering, rotation, native
Save As and save-before-close passed on a synthetic PDF. Printing, scanning,
signing and other optional workflows remain unverified.
[Source, build notes and tests](sources/pdfcraft/README.md).
