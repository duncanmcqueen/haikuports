#!/usr/bin/env python3
"""Generate the HaikuPorts recipe for maki from its (patched) Cargo.lock.

Usage: gen-recipe.py <patched Cargo.lock> > maki-0.5.7.recipe

Every crates.io package becomes SOURCE_URI_n/CHECKSUM_SHA256_n (the checksum is
the .crate SHA-256 from the lockfile). Git packages come from GitHub archives;
GIT_SOURCES below lists them with their archive SHA-256.
"""
import re
import sys

VERSION = "0.6.0"
MAIN_SHA256 = "7e70e303d849d0d6cd35c869237f427bf747a920517695d395769a8c4df2f191"

# (lockfile source prefix, repo, rev, archive sha256)
GIT_SOURCES = [
	("git+https://github.com/crossterm-rs/crossterm",
	 "crossterm-rs/crossterm", "3ca54292d2b1f1c58e200a06122ddaf5dd6b5c77",
	 "d252e6f9f311a0f88a6d3cad99e3664fb7a86d00e17c4bf7280861a5825c7bf9"),
	("git+https://github.com/tontinton/syntect",
	 "tontinton/syntect", "01df275f6f25da670e5ba5b7128cb89d03795119",
	 "ee96b75c2e3c53d8e7593960aa60148c89551b99ac52e01576f8a03d57f824e9"),
]

lock = open(sys.argv[1]).read()
crates = re.findall(
	r'\[\[package\]\]\nname = "([^"]+)"\nversion = "([^"]+)"\n'
	r'source = "registry\+https://github.com/rust-lang/crates.io-index"\n'
	r'checksum = "([0-9a-f]{64})"', lock)
gits = re.findall(r'source = "(git\+[^"]+)"', lock)
for g in gits:
	if not any(g.startswith(prefix + "?") for prefix, *_ in GIT_SOURCES):
		sys.exit(f"unhandled git source: {g}")

out = []
w = out.append
w('''SUMMARY="An AI coding agent optimized for minimal use of context tokens"
DESCRIPTION="maki is a terminal AI coding agent. It reads and edits code, runs \\
tools, and talks to several LLM providers. It keeps the context small: an \\
index tool gives file skeletons from tree-sitter before reads, a sandboxed \\
Python interpreter (monty) filters tool output, and subagents can use \\
weaker or stronger models of the selected provider. It is configurable \\
and extensible in Lua."
HOMEPAGE="https://github.com/tontinton/maki"
COPYRIGHT="2026 Tony Solomonik"
LICENSE="MIT"
REVISION="1"
SOURCE_URI="$HOMEPAGE/archive/refs/tags/v$portVersion.tar.gz"
CHECKSUM_SHA256="%s"
SOURCE_FILENAME="maki-$portVersion.tar.gz"
SOURCE_DIR="maki-$portVersion"
PATCHES="maki-$portVersion.patchset"
''' % MAIN_SHA256)

n = 2
for name, version, sha in crates:
	w(f'SOURCE_URI_{n}="https://static.crates.io/crates/{name}/{name}-{version}.crate"')
	w(f'CHECKSUM_SHA256_{n}="{sha}"')
	w('')
	n += 1
lastCrate = n - 1

firstGit = n
for _prefix, repo, rev, sha in GIT_SOURCES:
	base = repo.split("/")[1]
	w(f'SOURCE_URI_{n}="https://github.com/{repo}/archive/{rev}.tar.gz"')
	w(f'CHECKSUM_SHA256_{n}="{sha}"')
	w(f'SOURCE_FILENAME_{n}="{base}-{rev}.tar.gz"')
	w('')
	n += 1
lastGit = n - 1

gitConfig = []
for i, (prefix, repo, rev, _sha) in enumerate(GIT_SOURCES):
	url = prefix[len("git+"):]
	gitConfig.append(
		f'\t[source."{prefix}?rev={rev}"]\n'
		f'\tgit = "{url}"\n'
		f'\trev = "{rev}"\n'
		f'\treplace-with = "haiku-git"\n')

w('''ARCHITECTURES="!x86_gcc2 x86_64"

PROVIDES="
	maki = $portVersion
	cmd:maki = $portVersion
	"
REQUIRES="
	haiku
	lib:libcrypto >= 3
	lib:libcurl
	lib:libssl >= 3
	lib:libz
	"

BUILD_REQUIRES="
	haiku_devel
	devel:libcrypto >= 3
	devel:libcurl
	devel:libssl >= 3
	devel:libz
	"
BUILD_PREREQUIRES="
	cmd:cargo
	cmd:gcc
	cmd:pkg_config
	cmd:rustc >= 1.95
	"

defineDebugInfoPackage maki \\
	"$prefix"/bin/maki

BUILD()
{
	# cargo prepends its own directories to LIBRARY_PATH for the rustc it
	# spawns; if LIBRARY_PATH is empty (as in the build chroot) the system
	# library paths are lost and rustc cannot load libroot (exit status 3).
	export LIBRARY_PATH="%%A/lib:/boot/system/lib"
	export CARGO_HOME=$sourceDir/../cargo
	vendor=$CARGO_HOME/haiku
	vendorGit=$CARGO_HOME/haiku-git
	mkdir -p "$vendor" "$vendorGit"

	# crates.io crates
	for i in $(seq 2 %(lastCrate)d); do
		eval "srcDir=\\$sourceDir$i"
		eval "sha256sum=\\$CHECKSUM_SHA256_$i"
		set -- "$srcDir"/*
		ln -sf "$1" "$vendor"
		cat <<-EOF >"$vendor/${1##*/}/.cargo-checksum.json"
		{
		  "package": "$sha256sum",
		  "files": {}
		}
		EOF
	done

	# git dependencies (crossterm, syntect): their manifests do not inherit
	# from a workspace, so they can be served as a directory source
	for i in $(seq %(firstGit)d %(lastGit)d); do
		eval "srcDir=\\$sourceDir$i"
		set -- "$srcDir"/*
		ln -sf "$1" "$vendorGit"
		echo '{"package":null,"files":{}}' >"$vendorGit/${1##*/}/.cargo-checksum.json"
	done

	cat <<-EOF >"$CARGO_HOME"/config.toml
	[source.haiku]
	directory = "$vendor"

	[source.haiku-git]
	directory = "$vendorGit"

	[source.crates-io]
	replace-with = "haiku"

%(gitConfig)s	EOF

	cargo build --release --frozen
}

INSTALL()
{
	install -v -m 755 -d "$prefix"/bin "$docDir"
	install -v -m 755 target/release/maki "$prefix"/bin
	install -v -m 644 README.md "$docDir"
}

TEST()
{
	export LIBRARY_PATH="%%A/lib:/boot/system/lib"
	export CARGO_HOME=$sourceDir/../cargo
	cargo test --release --frozen
}''' % {"lastCrate": lastCrate, "firstGit": firstGit, "lastGit": lastGit,
	"gitConfig": "\n".join(gitConfig)})

print("\n".join(out))
print(f"crates={len(crates)} git={len(GIT_SOURCES)} sources={lastGit}",
	file=sys.stderr)
