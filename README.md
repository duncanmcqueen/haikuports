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

If Node.js 20 is installed, Node.js 22 conflicts with it. Inspect the solver proposal.
If necessary, uninstall `nodejs20` and its development package before installing Node 22.
Development headers are optional: `pkgman install nodejs22_devel`.
ICU development files and tools are also optional; they are not needed to run Node.

## Packages in this repository

| Package | Purpose |
|---------|---------|
| `nodejs22` | Node.js 22.23.3 runtime (loads ICU 77) |
| `nodejs22_devel` | Node.js development files |
| `icu77`, `icu77_devel`, `icu77_tools` | ICU 77 runtime for the Node binary, plus optional development and tool files, from the maintained `icu77` port |
| `fd` | `fd` file-search tool used by `pi` |
| `pi` | The `pi` coding agent (`pi` command) |
| `haiku_agent_library` | Haiku developer skills for `pi`, including the Haiku Book API reference |

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

Or check all enabled repositories with `pkgman update` or SoftwareUpdater.
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

## Rebuild Node and publish other packages

The owner's `pi-on-haiku` repository contains the maintained recipe, patchset, and:

- `scripts/rebuild-node-haiku.sh`: rebuild Node in an isolated HaikuPorts tree.
- `scripts/build-haiku-repository.sh`: create this repository layout from a directory
  of `.hpkg` files. It supports other personal packages, not only Node.
- `scripts/publish-haiku-repository.sh`: verify and publish a generated index from
  a clean checkout of the hosting branch. It preserves older package download files.

The `pi-on-haiku` repository is private. Download it with the owner's authorized account.
The public package repository can be used without GitHub credentials.

The publishing branch is `personal-packages`. The upstream `master` and port branches
remain separate. Repository data is in `r1beta6/x86_64/`; the binary index, checksum,
metadata, and `packages/` files must be published together.

Only one version of each package belongs in an index. Increment its package revision
when replacing an existing binary. Preserve published versioned files so clients with
an older index can complete downloads. GitHub Pages limits this hosting approach to a
1 GB site; move to a larger host if the package collection outgrows it.

See `BUILD-INFO.md` for the provenance and verification of the current package set.
