#!/usr/bin/env bash
set -euxo pipefail

dnf() {
	command dnf --assumeyes "$@"
}

dnf-minimal-install() {
	dnf --setopt="install_weak_deps=False" install "$@"
}

add-coprs() {
	for copr in "$@"; do
		dnf copr enable "$copr"
	done
}

add-repofiles() {
	for repo in "$@"; do
		dnf config-manager addrepo --from-repofile "$repo"
	done
}

setup-rpmfusion() {
	dnf install \
		https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-${FEDORA_VERSION}.noarch.rpm \
		https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-${FEDORA_VERSION}.noarch.rpm
	dnf install rpmfusion-\*-appstream-data rpmfusion-nonfree-release-tainted
}

setup-1password() {
	cp 1password.repo /etc/yum.repos.d
}
