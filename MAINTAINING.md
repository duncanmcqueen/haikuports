# Rebuild and publish personal Haiku packages

## Rebuild Node.js on Haiku

The script uses a separate tree and configuration. It does not overwrite the shared
HaikuPorts work tree or `~/config/settings/haikuports.conf`.

Install the build prerequisites, obtain this repository, and run:

```sh
pkgman install git haikuporter python3.12 cmd:gcc ninja make which findutils pkgconfig
sh scripts/rebuild-node-haiku.sh --packager 'Your Name <you@example.com>' --prepare-only
```

`--prepare-only` clones the pinned HaikuPorts tree, copies the maintained Node recipe
and patches, and lints the recipe. It starts no compiler or package build.

Start the build when ready:

```sh
sh scripts/rebuild-node-haiku.sh --packager 'Your Name <you@example.com>' --jobs 3
```

The default work directory is `~/nodejs22-rebuild`. It contains `build.log`, `status`,
`build-inputs.txt`, and, after success, `package-checksums.txt`. Packages are in
`~/nodejs22-rebuild/haikuports/packages/`.

Re-run the same command to resume. Use `--clean` only when an intentional clean
rebuild is required: HaikuPorter then discards its work directory. Use `--work`
to select a different isolated build. Never run two builds in the same directory.

If Git's HTTPS helper fails, use an existing clone that contains the pinned revision:

```sh
sh scripts/rebuild-node-haiku.sh --packager 'Your Name <you@example.com>' \
  --tree-source /boot/home/haikuports --prepare-only
```

This copies the existing clone into the isolated work directory with no hardlinks.
It does not change the source clone, its working files, or its build outputs.

For a detached build, with this repository as the working directory:

```sh
nohup sh scripts/rebuild-node-haiku.sh --packager 'Your Name <you@example.com>' --jobs 3 </dev/null >node-rebuild-driver.log 2>&1 &
```

Inspect `status` and `build.log`. Do not put the build under `timeout`.
The default parallelism is 3. Reduce it if the machine is under memory pressure.

The maintained recipe targets system ICU ABI 74 at build time. ICU 77 development
files conflict with ICU 74 development files, so inspect any dependency proposal.
Do not change runtime requirements by hand: verify the resulting ELF dependencies
and let HaikuPorter generate the package dependencies for the actual build.

Install a new package revision and validate Node, Intl, HTTP, workers, and GC before
publishing. `node --expose-gc scripts/check-node.mjs` performs the GC/worker/SQLite check.

## Generate an index, including other packages

On Haiku, put the selected runtime and optional development `.hpkg` files in a
directory. Include any dependency packages unavailable from the official repositories.
Keep one version of each package in this directory.

```sh
sh scripts/build-haiku-repository.sh \
  --input /boot/home/personal-packages \
  --out /boot/home/personal-index-new \
  --url https://duncanmcqueen.github.io/haikuports/r1beta6/x86_64
```

The output directory must be new. The script generates `repo.info`, `repo`,
`repo.sha256`, `SHA256SUMS`, `PACKAGES.txt`, and `packages/`.
It accepts x86_64 and architecture-independent packages. Package vendors must match
the repository vendor; the default is `Haiku Project`, matching HaikuPorter outputs.

## Publish to the existing fork

Work on a clone of `duncanmcqueen/haikuports`, branch `personal-packages`.
Copy the new index into `r1beta6/x86_64/`. Keep older versioned `.hpkg` files on the
site for clients using an older index, even when they are not in the new index.
Copy the landing-page README and update `BUILD-INFO.md` with actual verification.
Commit and push that branch. GitHub Pages serves it from `/` and `.nojekyll` disables
Jekyll processing of binary files. Do not put personal hosting changes in an upstream PR.

From a supported host, the publisher script checks input checksums, rejects a changed
binary with an already published filename, preserves older package files, and commits
and pushes only the repository data:

```sh
sh scripts/publish-haiku-repository.sh ./personal-index-new ./hosting-checkout
```

This command explicitly commits and pushes. The checkout must be clean and must have
`personal-packages` selected. It does not create the initial hosting branch or change
GitHub Pages settings.

Obtain a hosting checkout on that host with:

```sh
git clone --branch personal-packages --single-branch \
  https://github.com/duncanmcqueen/haikuports.git hosting-checkout
```

Transfer the complete Haiku-generated index directory to the same host before running
the publisher. Do not omit its `packages/` directory or checksum files.

GitHub Pages publication is asynchronous. Wait for it to finish, then verify:

```sh
pkgman refresh DuncanHaikuPackages
pkgman search nodejs22
```

Check HTTP downloads and checksums for the index and every newly published package.
Test dependency resolution and inspect a `pkgman full-sync` proposal without accepting
unrelated system updates. SoftwareUpdater sees the new index at its next refresh.
