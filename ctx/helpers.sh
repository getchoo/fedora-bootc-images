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
		https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-"$FEDORA_VERSION".noarch.rpm \
		https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-"$FEDORA_VERSION".noarch.rpm
	dnf install rpmfusion-\*-appstream-data rpmfusion-nonfree-release-tainted
}

# Let kmodtool know where our private key is from build secrets
setup-kmod-signing() {
	akmod_key="/run/secrets/AKMOD_KEY"
	macro_file=/etc/rpm/macros.kmod-signing

	# Short circuit if this has already ran
	if [ -f "$macro_file" ]; then
		echo "LOG: kmod signatures are already enabled"
		return
	fi

	if [ -f "$akmod_key" ]; then
		cat >"$macro_file" <<EOF
%_kmodtool_signmodules_privkey "$akmod_key"
EOF
		echo "LOG: kmod signatures enabled!"
	else
		echo "WARNING: kmod signatures disabled!"
	fi
}

# Build a given kmod and copy the RPM output to /rpms
build-kmod() {
	local kmod="${1}"

	# NOTE: Basic sanity check; required packages for build kmods
	for rpm in akmods gcc kernel{,-devel}; do
		if ! rpm -q "$rpm"; then
			echo "ERROR: '$rpm' must be installed to build kmods!"
			exit 1
		fi
	done
	kernel_version="$(rpm -q kernel-devel --queryformat '%{VERSION}-%{RELEASE}.%{ARCH}')"
	akmods_dir=/var/cache/akmods
	kmod_dir="$akmods_dir"/"$kmod"

	if ! akmods --force --kernels "$kernel_version" --kmod "$kmod" || ls "$kmod_dir"/*"$kernel_version".failed.log &>/dev/null; then
		cat "$kmod_dir"/*"$kernel_version".failed.log && exit 1
	fi

	[ ! -d /rpms ] && mkdir -p /rpms
	cp "$kmod_dir"/*.rpm /rpms
}
