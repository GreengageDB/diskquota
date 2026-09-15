#!/bin/bash
# FILE:    ci/build_in_docker.sh
# CONTEXT: Build diskquota and package it as a .deb in container
# PURPOSE: Runs inside a Greengage developer image (ggdb*_ubuntu, pulled from
#          ghcr.io/greengagedb/greengage) that already provides the build
#          toolchain. Installs the matching Greengage runtime package via
#          apt, then builds the diskquota .deb with `make -f package.mk pkg`.
#          Invoked either directly by CI or via ci/build_in_docker_local.sh
#          for local development; chowns the bind-mounted source tree back
#          to the host user when HOST_UID/HOST_GID are provided.

# Local/manual run examples (see ci/build_in_docker_local.sh for the wrapper):
# GGDB_IMAGE=ghcr.io/greengagedb/greengage/ggdb6_ubuntu:latest
# GGDB_IMAGE=ghcr.io/greengagedb/greengage/ggdb6_ubuntu24.04:latest
# GGDB_IMAGE=ghcr.io/greengagedb/greengage/ggdb7_ubuntu:latest

# shellcheck disable=SC2086

set -eux

is_container() {
    [[ -f /.dockerenv || -f /run/.containerenv ]] ||
        grep -qE '(docker|containerd|libpod|podman|kubepods)' \
            /proc/1/cgroup 2>/dev/null
}

if ! is_container; then
    echo "WARNING: This script is designed to run in a container."
    echo "Running it directly on the host system may modify the system unexpectedly."
    read -r -p "Continue anyway? [y/N] " answer

    [[ "$answer" =~ ^[Yy]$ ]] || exit 1
fi

: "${PG_HOME:?PG_HOME must be set}"

export DEBIAN_FRONTEND=noninteractive
export GP_MAJORVERSION=${GP_MAJORVERSION:-6}
export GREENGAGE_PACKAGE=${GREENGAGE_PACKAGE:-greengage$GP_MAJORVERSION}

# Configure
git config --system --add safe.directory "$(pwd)"

update-locale LANG=en_US.UTF-8
localedef -c -i ru_RU -f CP1251 ru_RU.CP1251

# Install packages from apt
echo -n "Installing packages via apt... "
{
  # shellcheck disable=SC1091 # External source
  apt-get -yq update
  apt-get -yq install --no-install-recommends "$GREENGAGE_PACKAGE"
  apt-get clean
} # 1>/dev/null ; echo "Done"

# GreengageDB environment variables
export PYTHONPATH="$PG_HOME/lib/python"
export LD_LIBRARY_PATH="$PG_HOME/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"

# shellcheck disable=SC1091 # External source
source "$PG_HOME/greengage_path.sh"

if [ -e "$PG_HOME/etc/openssl.cnf" ]; then
	export OPENSSL_CONF="$PG_HOME/etc/openssl.cnf"
fi

# Package
make -f package.mk pkg

# Fix file ownership after build (root inside container -> host user)
# Pass '-e HOST_UID=$(id -u) -e HOST_GID=$(id -g)' to 'docker run' for this
if [[ -n "${HOST_UID:-}" && -n "${HOST_GID:-}" ]]; then
    chown -R "${HOST_UID}:${HOST_GID}" "$SRC"
fi
