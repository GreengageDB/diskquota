# Diskquota Debian Packaging

## Overview

`.deb` packages are built by the top-level `package.mk` (via `debuild`),
which hands off to `debian/rules` for the actual `dh` sequence. This is a
**single-package** source tree — one binary package plus the automatically
generated `-dbgsym` companion:

| Package | Contents |
| --- | --- |
| `greengage$(GP_MAJORVERSION)-diskquota` | Diskquota extension: `diskquota-2.x.so`, DDL/SQL files, `diskquota.control` |
| `greengage$(GP_MAJORVERSION)-diskquota-dbgsym` | Debug symbols, produced by `dh_strip` (`.ddeb`) |

Because there is only one binary package, debhelper uses the **default
file names** without a package prefix: `debian/install`,
`debian/not-installed`, `debian/lintian-overrides`, `debian/copyright`,
`debian/compat`, `debian/rules`. No `debian/<pkg>.install` variants.

## Requirements / Environment Variables

| Variable | Enforced by | Required? | Default | Purpose |
| --- | --- | --- | --- | --- |
| `GP_MAJORVERSION` | `debian/rules` (`$(error ...)` if unset) | Yes — hard error if unset | — | Drives the package name (`greengage6-diskquota`), `PG_HOME`, and the `@GP_MAJORVERSION@` substitution in `debian/control.in` |
| `PG_HOME` | `debian/rules` | No | `/opt/greengagedb/greengage$(GP_MAJORVERSION)` | Greengage install prefix; `CMAKE_INSTALL_PREFIX` for the build, base for `@PG_HOME_REL@` substitution |
| `PG_CONFIG` | `debian/rules` (`test -x` hard check) | No | `$(PG_HOME)/bin/pg_config` | Used by CMake to resolve headers/libs |

`ci/build_in_docker.sh` determines `GP_MAJORVERSION` from the
Greengage developer image and derives `PG_HOME` from it.

## Build Flow

```text
make -f package.mk pkg
                    ↓
version-vars (reads ./VERSION)
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
find + mv → ./Package/*.deb, *.ddeb, *.build, *.buildinfo, *.changes
```

## package.mk Targets

### Version

| Target | Description |
| --- | --- |
| `version-vars` | Parses `./VERSION` into `FULL_VERSION`, `PACKAGE_VERSION` (`-SNAPSHOT` → `~snapshot`), `DISTRO_CODENAME` (`lsb_release -sc`), `IS_RELEASE`, `BUILD_TYPE` |
| `version-info` | Prints the above (debug) |

### Control / changelog generation

| Target | Description |
| --- | --- |
| `debian/control` | Generated from `debian/control.in`, substituting `@GP_MAJORVERSION@` |
| `changelog` / `debian/changelog` | Generates a single-entry changelog from `version-vars` plus the package name/maintainer read out of `debian/control.in` |

### Packaging

| Target | Description |
| --- | --- |
| `pkg` | Alias for `pkg-deb` — the entry point used by `ci/build_in_docker.sh` |
| `pkg-deb` | Depends on `debian/changelog` and `debian/control`. Runs `debuild --preserve-env -us -uc -b` (binary-only, unsigned), scoped via `DH_OPTIONS="-p greengage$(GP_MAJORVERSION)-diskquota"` with `PG_HOME`/`GP_MAJORVERSION` exported into the debuild environment; then moves `*.deb`, `*.ddeb`, `*.build`, `*.buildinfo`, `*.changes` from the parent directory into `$(ARTIFACTS_DIR)` (`./Package`) in the same recipe |

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
`GP_MAJORVERSION` in the same working directory right after another build
would silently reuse the stale `debian/control` from the previous run.

## debian/rules

| Override | Behaviour |
| --- | --- |
| `dh_auto_clean` | Delegated to `dh_clean` (default), cleans `obj-*` |
| `dh_auto_configure` | Sanity-checks `PG_CONFIG`; renders `debian/install` and `debian/not-installed` from `*.in` templates via `sed 's|@PG_HOME_REL@|$(PG_HOME:/%=%)|g'`; calls `dh_auto_configure` with `-DPG_CONFIG`, `-DCMAKE_BUILD_TYPE=RelWithDebInfo`, `-DCMAKE_INSTALL_PREFIX=$(PG_HOME)` |
| `dh_auto_install` | Forces `--destdir=debian/tmp` so `dh_install` can filter through `debian/install` (otherwise the single-binary-package default is `debian/<pkg>/`) |

`debian/rules` hard-fails on missing `GP_MAJORVERSION` and on a
non-executable `PG_CONFIG`.

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
| `VERSION` | Package version string, read by `version-vars` |
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

Resulting `.deb`/`.ddeb`/`.buildinfo`/`.changes` land in `./Package/`.

### Local build on a host with Greengage installed

```bash
export GP_MAJORVERSION=6
export PG_HOME=/opt/greengagedb/greengage${GP_MAJORVERSION}

make -f package.mk pkg
make -f package.mk version-info
```

Use `GP_MAJORVERSION=7` to build the package for Greengage 7.

### Notes

- `debian/control` and `debian/changelog` are **generated on every
  build** (declared `.PHONY` in `package.mk`, see above) from
  `debian/control.in` and the current `GP_MAJORVERSION`/`VERSION`.
  `debian/install` and `debian/not-installed` are generated at configure
  time from their `.in` templates. All four are `.gitignore`d and should
  not be committed.
- `cmake --install` runs against `debian/tmp`, and `dh_install` filters
  that directory through `debian/install`. Anything present in
  `debian/tmp` but not matched by either `debian/install` or
  `debian/not-installed` will abort the build via `dh_missing`.
