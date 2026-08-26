ARG IMAGE_FLAVOR=silverblue
ARG BASE_IMAGE=quay.io/fedora-ostree-desktops/${IMAGE_FLAVOR}
ARG BUILD_IMAGE=quay.io/fedora/fedora-bootc
ARG FEDORA_VERSION=44

FROM scratch AS ctx
COPY ctx/ /

FROM ${BUILD_IMAGE}:${FEDORA_VERSION} AS builder
ARG FEDORA_VERSION

COPY etc/pki/akmods/certs/public_key.der /etc/pki/akmods/certs/public_key.der

RUN \
	--mount=type=secret,id=AKMOD_KEY,mode=0444 \
	--mount=type=bind,from=ctx,src=/,destination=/ctx,ro \
	--mount=type=cache,target=/var/cache/libdnf5 \
	--mount=type=tmpfs,target=/var/log \
	--mount=type=tmpfs,target=/tmp \
	/ctx/build-nvidia-kmod.sh

FROM ${BASE_IMAGE}:${FEDORA_VERSION}
ARG FEDORA_VERSION

COPY etc/ /etc/

RUN \
	--mount=type=bind,from=ctx,src=/,destination=/ctx \
	--mount=type=bind,from=builder,src=/rpms,destination=/rpms \
	--mount=type=cache,target=/var/cache/libdnf5 \
	--mount=type=tmpfs,target=/var/log \
	--mount=type=tmpfs,target=/tmp \
	<<RUNEOF
source /ctx/helpers.sh

# Setup external repos
flatpak remote-add \
	--system \
	--if-not-exists \
	flathub \
	https://flathub.org/repo/flathub.flatpakrepo
setup-rpmfusion
dnf install "dnf5-command(config-manager)" "dnf5-command(copr)"
add-repofiles \
	https://pkgs.tailscale.com/stable/fedora/tailscale.repo \
	/ctx/1password.repo
add-coprs \
	imput/helium \
	scottames/ghostty

# Setup hardware enablement (codecs, drivers, firmware, etc.)
dnf config-manager setopt fedora-cisco-openh264.enabled=1
dnf swap --allowerasing ffmpeg-free ffmpeg
dnf-minimal-install --exclude=PackageKit-gstreamer-plugin install @multimedia

# Install NVIDIA drivers
add-repofiles /ctx/nvidia-container-toolkit.repo
dnf install /rpms/*.rpm libva-nvidia-driver nvidia-container-toolkit xorg-x11-drv-nvidia-cuda
cat > /usr/lib/bootc/kargs.d/00-nvidia.toml <<EOF
kargs = [
	"rd.driver.blacklist=nouveau,nova_core",
	"modprobe.blacklist=nouveau,nova_core"
]
EOF

# Install extra packages
## HACK: /opt is a dangling symlink by default so RPMs with files there
## fail to extract correctly
mkdir -p /var/opt
dnf install 1password{,-cli} ghostty helium tailscale

## HACK: / is ro with composefs. Make /nix a symlink to a writable dir
mkdir -p /var/nix
ln -s var/nix /nix
curl -fsSL https://install.lix.systems/lix | \
	sh -s -- \
	install linux \
	--no-confirm --no-start-daemon \
	--enable-flakes --extra-conf 'use-xdg-base-directories = true'

# FIXME: Why is `system-repo.lock` left here???
rm -rf /var/lib/dnf /run/dnf
RUNEOF

LABEL containers.bootc=1
LABEL ostree.bootable=1
RUN bootc container lint
