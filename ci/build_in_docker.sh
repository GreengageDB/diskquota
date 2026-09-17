#!/bin/bash
# FILE:    ci/build_in_docker.sh
# CONTEXT: Build diskquota and package it as a .deb
# PURPOSE: Runs inside a Greengage developer image, installs the matching
#          Greengage package, and builds the diskquota deb-package.

# shellcheck disable=SC2086

set -eux

# Expect the source tree to be bind-mounted from outside and used as the
# working directory.
# Check that $PWD is a mount point in /proc/self/mountinfo.
is_container() {
    local mp
    mp=$(pwd -P) || return 1

    # mountinfo escapes space as \040 and backslash as \134.
    mp=${mp//\\/\\134}
    mp=${mp// /\\040}

    MP="$mp" awk '
        $5 == ENVIRON["MP"] { found = 1 }
        END { exit !found }
    ' /proc/self/mountinfo
}

prepare_build_user() {
    local uid user

    read -r uid < <(stat -c '%u' "$PWD")

    if [[ "$uid" -eq 0 ]]; then
        echo "WARNING: $PWD is owned by root; build will run as root"
        return
    fi

    user=$(getent passwd "$uid" | cut -d: -f1 || true)
    if [[ -n "$user" ]]; then
        BUILD_USER="$user"
        return
    fi

    user="build-$(od -An -N8 -tx1 /dev/urandom | tr -d ' \n')"
    useradd --uid "$uid" --create-home --user-group \
        --shell /bin/bash "$user"

    BUILD_USER="$user"
}

if ! is_container; then
    echo "WARNING: This script is designed to run in a container."
    echo "Running it directly on the host system may modify the system unexpectedly."
    read -r -p "Continue anyway? [y/N] " answer

    [[ "$answer" =~ ^[Yy]$ ]] || exit 1
fi

if [[ ! -f /home/gpadmin/gpdb_src/VERSION ]]; then
    echo "ERROR: Not a Greengage developer image"
    exit 1
fi

GP_MAJORVERSION=$(sed 's/\..*//' /home/gpadmin/gpdb_src/VERSION)

case "$GP_MAJORVERSION" in
    6|7)
        ;;
    *)
        echo "ERROR: Unknown Greengage version: $GP_MAJORVERSION"
        exit 1
        ;;
esac

PG_HOME="/opt/greengagedb/greengage$GP_MAJORVERSION"

# Install packages from apt
export DEBIAN_FRONTEND=noninteractive
echo -n "Installing packages via apt... "
{
    apt-get -yq update
    apt-get -yq install \
        --no-install-recommends "greengage$GP_MAJORVERSION"
} 1>/dev/null
echo "Done"

BUILD_USER=
export GP_MAJORVERSION PG_HOME

if [[ "$(id -u)" -eq 0 ]]; then
    prepare_build_user
    if [[ -n "$BUILD_USER" ]]; then
        chown "$BUILD_USER" ..
        sudo --preserve-env=GP_MAJORVERSION,PG_HOME,DISKQUOTA_PACKAGE_VERSION \
             --user "$BUILD_USER" -- \
            make -f package.mk
        exit
    fi
fi

make -f package.mk
