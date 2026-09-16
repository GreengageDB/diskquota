#!/bin/bash
# FILE:    ci/build_in_docker.sh
# CONTEXT: Build diskquota and package it as a .deb
# PURPOSE: Runs inside a Greengage developer image, installs the matching
#          Greengage package, and builds the diskquota .deb.

# shellcheck disable=SC2086

set -eux

is_container() {
    [[ -f /.dockerenv || -f /run/.containerenv ]] ||
        grep -qE '(docker|containerd|libpod|podman|kubepods)' \
            /proc/1/cgroup 2>/dev/null
}

prepare_build_user() {
    local uid gid user group

    read -r uid gid < <(stat -c '%u %g' "$PWD")

    if [[ "$uid" -eq 0 && "$gid" -eq 0 ]]; then
        echo "WARNING: $PWD is owned by root; build will run as root"
        return
    fi

    user=$(getent passwd "$uid" | cut -d: -f1 || true)
    if [[ -z "$user" ]]; then
        group=$(getent group "$gid" | cut -d: -f1 || true)

        if [[ -z "$group" ]]; then
            group=build
            groupadd --gid "$gid" "$group"
        fi

        user=build
        useradd --uid "$uid" --gid "$gid" \
            --create-home --shell /bin/bash "$user"
    fi

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
    apt-get clean
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
