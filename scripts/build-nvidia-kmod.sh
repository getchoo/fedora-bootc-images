#!/usr/bin/env bash
source "$(readlink -f "$0" | xargs dirname)"/helpers.sh

setup-rpmfusion
dnf-minimal-install akmod-nvidia kernel{,-devel}

setup-kmod-signing
build-kmod nvidia
