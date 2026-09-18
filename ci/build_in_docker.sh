#!/bin/bash -l
# FILE:    ci/build_in_docker.sh
# CONTEXT: Build diskquota and package it as a .deb inside a Greengage
#          developer image.
# PURPOSE: Requires root privileges and the Greengage developer image
#          layout. Installs the matching Greengage package and runs the
#          package build as an unprivileged user.

set -eo pipefail

function assert_root() {
    if [ "$(id -u)" -ne 0 ]; then
        echo "FATAL: build must run as root"
        exit 1
    fi
}

function assert_developer_image() {
    if [ ! -f /home/gpadmin/gpdb_src/VERSION ]; then
        echo "FATAL: not a Greengage developer image"
        exit 1
    fi
}

function detect_gp_major_version() {
    GP_MAJORVERSION="$(sed 's/\..*//' /home/gpadmin/gpdb_src/VERSION)"

    case "$GP_MAJORVERSION" in
        6|7)
            ;;
        *)
            echo "FATAL: unknown Greengage version: $GP_MAJORVERSION"
            exit 1
            ;;
    esac

    PG_HOME="/opt/greengagedb/greengage$GP_MAJORVERSION"

    export GP_MAJORVERSION PG_HOME
}

function install_greengage() {
    export DEBIAN_FRONTEND=noninteractive

    echo -n "Installing packages via apt... "
    {
        apt-get -yq update
        apt-get -yq install \
            --no-install-recommends "greengage$GP_MAJORVERSION"
        apt-get clean
    } 1>/dev/null
    echo "Done"
}

function prepare_build_user() {
    local uid user

    read -r uid < <(stat -c '%u' "$PWD")

    if [ "$uid" -eq 0 ]; then
        echo "FATAL: source directory is owned by root"
        exit 1
    fi

    user="$(getent passwd "$uid" | cut -d: -f1 || true)"

    if [ -z "$user" ]; then
        user="build-$(od -An -N8 -tx1 /dev/urandom | tr -d ' \n')"
        useradd --uid "$uid" --create-home --user-group \
            --shell /bin/bash "$user"
    fi

    BUILD_USER="$user"
}

function run_build() {
    chown "$BUILD_USER" ..

    sudo --preserve-env=GP_MAJORVERSION,PG_HOME,DISKQUOTA_PACKAGE_VERSION \
        --user "$BUILD_USER" -- \
        make -f package.mk
}

function _main() {
    assert_root
    assert_developer_image
    detect_gp_major_version
    install_greengage
    prepare_build_user

    time run_build
}

_main "$@"
