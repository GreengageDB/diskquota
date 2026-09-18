# Diskquota Debian Packaging

## Overview

`.deb` packages are built by the top-level `package.mk` (via `debuild`),
which hands off to `debian/rules` for the actual `dh` sequence. This is a
**single-package** source tree — one binary package plus the automatically
generated `-dbgsym` companion:

| Package | Contents |
| --- | --- |
| `greengage$(GP_MAJORVERSION)-diskquota` | Diskquota extension: `.so`, DDL/SQL files, `diskquota.control` |
| `greengage$(GP_MAJORVERSION)-diskquota-dbgsym` | Debug symbols, produced by `dh_strip` (`.ddeb`) |

Because there is only one binary package, debhelper uses the **default
file names** without a package prefix: `debian/install`,
`debian/not-installed`, `debian/lintian-overrides`, `debian/copyright`,
`debian/compat`, `debian/rules`. No `debian/<pkg>.install` variants.

## Requirements / Environment Variables

| Variable | Enforced by | Required? | Default | Purpose |
| --- | --- | --- | --- | --- |
| `GP_MAJORVERSION` | `package.mk` (all goals except `help`, `version-info`), `debian/rules` (always) | Yes | — | Drives the package name (`greengage<GP_MAJORVERSION>-diskquota`), `PG_HOME`, and the `@GP_MAJORVERSION@` substitution in `debian/control.in` |
| `PG_HOME` | `debian/rules` | No | `/opt/greengagedb/greengage$(GP_MAJORVERSION)` | Greengage install prefix; `CMAKE_INSTALL_PREFIX` for the build, base for `@PG_HOME_REL@` substitution |
| `PG_CONFIG` | `debian/rules` | No | `$(PG_HOME)/bin/pg_config` | Must be runnable and report `Greengage <GP_MAJORVERSION>` via `--gp_version`; used by CMake to resolve headers/libs |
| `DEB_PACKAGES` | `package.mk` | No | `Package/<package>_<version>` | Overrides the final output directory (used by CI) |
| `DISKQUOTA_PACKAGE_VERSION` | `package.mk` | No | — | Explicit version override, takes priority over git and `.version` |

`ci/build_in_docker.sh` determines `GP_MAJORVERSION` from the
Greengage developer image and derives `PG_HOME` from it.

## Build Flow

```text
GP_MAJORVERSION=6 make -f package.mk pkg
                    ↓
debian/control  (generated from debian/control.in,
                  substituting @GP_MAJORVERSION@)
                    ↓
debian/changelog (single entry; package name/maintainer
                   read from debian/control.in)
                    ↓
debuild --preserve-env -us -uc -b
   (PG_HOME, GP_MAJORVERSION exported explicitly)
                    ↓
debian/rules: dh sequence
                    ↓
override_dh_auto_configure
   (render install.in / not-installed.in → debian/install, debian/not-installed;
    hand off to CMake with -DPG_CONFIG / -DCMAKE_INSTALL_PREFIX)
                    ↓
dh_auto_build (cmake --build)
                    ↓
override_dh_auto_install
   (cmake --install with DESTDIR=debian/tmp)
                    ↓
dh_install (filters debian/tmp through debian/install)
                    ↓
dh_strip → .ddeb, dh_installchangelogs, dh_lintian, dh_builddeb
                    ↓
rm -rf $(PACKAGE_DIR) && mkdir -p $(PACKAGE_DIR)
                    ↓
mv of exact filenames:
   <package>_<version>_*.<deb|ddeb>
   <source>_<version>_*.<build|buildinfo|changes>
   → $(PACKAGE_DIR)/  (default: ./Package/greengage$(GP_MAJORVERSION)-diskquota_$(PACKAGE_VERSION))
```

## package.mk Targets

### Informational (no `GP_MAJORVERSION` required)

| Target | Description |
| --- | --- |
| `help` | Prints usage and the list of targets |
| `version-info` | Prints the resolved package version and build metadata |

Every other target hard-fails if `GP_MAJORVERSION` is unset or empty:

```text
package.mk:16: *** GP_MAJORVERSION must be set.  Stop.
```

### Version

The package version is resolved from `DISKQUOTA_PACKAGE_VERSION`, then
`git describe --tags`, then `.version`. If none of them yields a value,
`0.0.0+unknown` is used (with a warning).

Git development versions in the form `<version>-<commits>-<hash>` are
converted to `<version>+dev.<commits>.<hash>` for Debian packaging.

### Control / changelog generation

| Target | Description |
| --- | --- |
| `debian/control` | Generated from `debian/control.in`, substituting `@GP_MAJORVERSION@` |
| `changelog` / `debian/changelog` | Generates a single-entry changelog using the resolved package version and the package name/maintainer read out of `debian/control.in` |

### Packaging

| Target | Description |
| --- | --- |
| `pkg` | Alias for `pkg-deb` — the entry point used by `ci/build_in_docker.sh` |
| `pkg-deb` | Depends on `debian/changelog` and `debian/control`. Runs `debuild --preserve-env -us -uc -b` (binary-only, unsigned), scoped via `DH_OPTIONS="-p greengage$(GP_MAJORVERSION)-diskquota"` with `PG_HOME`/`GP_MAJORVERSION` exported into the debuild environment; then wipes `$(PACKAGE_DIR)`, recreates it, and moves exact filenames (`<package>_<version>_*.<deb\|ddeb>` and `<source>_<version>_*.<build\|buildinfo\|changes>`) from the parent directory into it |

A `.debuilder.lock` directory (created with `mkdir`, atomic) guards
against concurrent `pkg-deb` runs in the same working tree.

`MAINTAINER` and `PACKAGE_SOURCE` (used to build `debian/changelog` and
the `PACKAGE_DEBIAN` package name) are read via `grep`/`awk` from
**`debian/control.in`** (the template), not from the generated
`debian/control` — this works because neither field contains
`@GP_MAJORVERSION@`, so the values are identical in both files.

`debian/control` and `debian/changelog` are declared `.PHONY` in
`package.mk`, so they are regenerated on every `make -f package.mk pkg`
invocation regardless of file timestamps. This matters because their
content depends on the `GP_MAJORVERSION` environment variable, not on
`debian/control.in`'s mtime — without `.PHONY`, rebuilding a different
`GP_MAJORVERSION` in the same working directory right after another run
would silently reuse the stale `debian/control` from the previous run.

## debian/rules

| Override | Behaviour |
| --- | --- |
| `dh_auto_configure` | Fails if `PG_CONFIG` is not runnable or doesn't report `Greengage $(GP_MAJORVERSION)`; renders `debian/install` and `debian/not-installed` from `*.in` templates via `sed`; calls `dh_auto_configure` with `-DPG_CONFIG`, `-DCMAKE_BUILD_TYPE=RelWithDebInfo`, `-DCMAKE_INSTALL_PREFIX=$(PG_HOME)` |
| `dh_auto_install` | Forces `--destdir=debian/tmp` so `dh_install` can filter through `debian/install` (otherwise the single-binary-package default is `debian/<pkg>/`) |

`debian/rules` hard-fails on missing `GP_MAJORVERSION` and on a
`PG_CONFIG` that cannot run or whose `--gp_version` doesn't match
`GP_MAJORVERSION`.

## Install Manifests

Two generated manifests control what goes into the package. Both use the
**default, unprefixed** names, valid because there is exactly one binary
package:

| File | Source | Purpose |
| --- | --- | --- |
| `debian/install` | `debian/install.in` | Whitelist of files to package: `lib/postgresql/*` and `share/postgresql/extension/*` under `@PG_HOME_REL@` |
| `debian/not-installed` | `debian/not-installed.in` | Files intentionally produced by `cmake --install` but not shipped in the `.deb`: `install_gpdb_component`, `diskquota-build-info` |

Both are generated at configure time in `override_dh_auto_configure` so
they can be templated by `GP_MAJORVERSION`.

`install_gpdb_component` and `diskquota-build-info` still end up in the
TGZ artifact produced by the regular CMake `package` target — they are
used by the upgrade test pipeline and by build fingerprinting,
respectively. They are excluded from the `.deb` only.

## Lintian Overrides

| File | Covers |
| --- | --- |
| `debian/lintian-overrides` | `dir-or-file-in-opt` (Greengage install layout under `/opt` is expected) |

The unprefixed name is used because there is a single binary package.
`dh_lintian` picks it up as the default override file for that package.

## Key Files

| File | Purpose |
| --- | --- |
| `package.mk` | Version, control/changelog generation, packaging targets |
| `ci/build_in_docker.sh` | Runs the full build inside a Greengage container image |
| `ci/build_in_docker_local.sh` | Wrapper for local development (see Usage below) |
| `.version` | Fallback package version, used when neither `DISKQUOTA_PACKAGE_VERSION` nor a git tag is available; populated at `git archive` time via `.gitattributes` |
| `debian/control.in` | `debian/control` template, substituting `@GP_MAJORVERSION@` |
| `debian/rules` | Debhelper overrides |
| `debian/install.in` | Install manifest template, rendered per `GP_MAJORVERSION` |
| `debian/not-installed.in` | Files excluded from the `.deb` (still in TGZ) |
| `debian/lintian-overrides` | Suppressed lintian warnings |
| `debian/copyright` | Debian copyright file (Apache-2.0) |
| `debian/compat` | Debhelper compat level (13) |

Generated (do not commit, `.gitignore`d): `debian/control`,
`debian/changelog`, `debian/install`, `debian/not-installed`.

## Usage

### Local build in a container (recommended)

The recommended way to build a package locally is to use the
`ci/build_in_docker_local.sh` wrapper. It runs the build inside the
matching Greengage developer image, so the Greengage build toolchain
does not need to be installed on the host.

```bash
ci/build_in_docker_local.sh
```

The default configuration is Greengage 6 on Ubuntu 22.04. Greengage and
Ubuntu versions can be specified explicitly:

```bash
ci/build_in_docker_local.sh 6 24.04
ci/build_in_docker_local.sh 7 22.04
```

The `ci/build_in_docker.sh` script determines the Greengage major version
from the developer image and runs the package build as the owner of the
mounted source tree, avoiding root-owned build artifacts. The script
must be run as root inside the Greengage developer image and is not
intended for direct execution on a host system.

By default, resulting `.deb`/`.ddeb`/`.build`/`.buildinfo`/`.changes`
land in `./Package/greengage$(GP_MAJORVERSION)-diskquota_$(PACKAGE_VERSION)/`.
The output directory can be overridden with `DEB_PACKAGES` (CI uses this
to write into a flat, version-tagged directory that matches the upload
step and the shared `tests/install/deb` action).

### Local build on a host with Greengage installed

```bash
export GP_MAJORVERSION=6
export PG_HOME=/opt/greengagedb/greengage${GP_MAJORVERSION}

make -f package.mk pkg
make -f package.mk version-info
```

Use `GP_MAJORVERSION=7` to build the package for Greengage 7.

`GP_MAJORVERSION` must be set for every target except `help` and
`version-info`. You can pass it either via the environment
(`GP_MAJORVERSION=6 make -f package.mk pkg`) or as a make variable
(`make -f package.mk GP_MAJORVERSION=6 pkg`) — both work.

### Notes

* `debian/control` and `debian/changelog` are **generated on every
  build** (declared `.PHONY` in `package.mk`, see above) from
  `debian/control.in` and the current `GP_MAJORVERSION`/package version.
  `debian/install` and `debian/not-installed` are generated at configure
  time from their `.in` templates. All four are `.gitignore`d and should
  not be committed.
* `cmake --install` runs against `debian/tmp`, and `dh_install` filters
  that directory through `debian/install`. Anything present in
  `debian/tmp` but not matched by either `debian/install` or
  `debian/not-installed` will abort the build via `dh_missing`.
