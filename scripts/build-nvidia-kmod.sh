#!/usr/bin/env bash
source "$(readlink -f "$0" | xargs dirname)"/helpers.sh

setup-rpmfusion
# FIXME: Hide our ostree-ness from kmodtool so scriptlets don't fail
# https://bugzilla.redhat.com/show_bug.cgi?id=2459819
sed -i "/^OSTREE_VERSION='/d" /etc/os-release
dnf-minimal-install akmod-nvidia

setup-kmod-signing
build-kmod nvidia
