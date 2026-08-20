ARG IMAGE_FLAVOR="${IMAGE_FLAVOR:-silverblue}"
ARG BASE_IMAGE="quay.io/fedora-ostree-desktops/${IMAGE_FLAVOR}"
ARG BUILD_IMAGE="quay.io/fedora-ostree-desktops/base-atomic"
ARG FEDORA_VERSION="${FEDORA_VERSION:-44}"

FROM scratch AS ctx
COPY scripts/ /

FROM ${BUILD_IMAGE}:${FEDORA_VERSION} AS builder
ARG FEDORA_VERSION

COPY etc/pki/akmods/certs/public_key.der /etc/pki/akmods/certs/public_key.der

RUN \
	--mount=type=secret,id=AKMOD_KEY,mode=0444 \
	--mount=type=bind,from=ctx,src=/,destination=/ctx \
	--mount=type=cache,target=/var/cache \
	--mount=type=cache,target=/var/log \
	--mount=type=tmpfs,target=/tmp \
	/ctx/build-nvidia-kmod.sh

FROM ${BASE_IMAGE}:${FEDORA_VERSION}
ARG FEDORA_VERSION

COPY etc/ /etc/
COPY usr/ /usr/

RUN \
	--mount=type=bind,from=ctx,src=/,destination=/ctx \
	--mount=type=bind,from=builder,src=/rpms,destination=/rpms \
	--mount=type=cache,target=/var/cache \
	--mount=type=cache,target=/var/log \
	--mount=type=tmpfs,target=/tmp \
	<<EOF
source /ctx/helpers.sh

# Setup external repos
flatpak remote-add --system --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
setup-rpmfusion
dnf install "dnf5-command(config-manager)" "dnf5-command(copr)"
add-repofiles \
	https://pkgs.tailscale.com/stable/fedora/tailscale.repo \
	https://brave-browser-rpm-release.s3.brave.com/brave-browser.repo
add-coprs \
	imput/helium \
	scottames/ghostty

# Setup hardware enablement (codecs, drivers, firmware, etc.)
dnf config-manager setopt fedora-cisco-openh264.enabled=1
dnf swap --allowerasing ffmpeg-free ffmpeg
dnf-minimal-install --exclude=PackageKit-gstreamer-plugin \
  install @multimedia intel-media-driver mesa-va-drivers-freeworld
dnf --repo=rpmfusion-nonfree-tainted install "*-firmware"

# Install NVIDIA drivers
dnf install /rpms/*.rpm nvidia-container-toolkit xorg-x11-drv-nvidia-cuda

# Install extra packages
## HACK: /opt is a dangling symlink by default so RPMs with files there
## fail to extract correctly
mkdir -p /var/opt
dnf install 1password{,-cli} brave-origin fish ghostty helium nix tailscale

# FIXME: Why is `system-repo.lock` left here???
rm -rf /var/lib/dnf /run/dnf
EOF

LABEL containers.bootc=1
LABEL ostree.bootable=1
RUN bootc container lint
