ARG POLICY=manylinux_2_35
ARG BASE_IMAGE_VERSION=${POLICY}
ARG BASE_IMAGE_VERSION=${BASE_IMAGE_VERSION/manylinux_2_31/20.04}
ARG BASE_IMAGE_VERSION=${BASE_IMAGE_VERSION/manylinux_2_35/22.04}

FROM ubuntu:${BASE_IMAGE_VERSION}

ARG DEBIAN_FRONTEND=noninteractive
ARG POLICY
ARG TARGETARCH

RUN rm -f /etc/apt/apt.conf.d/docker-clean; echo 'Binary::apt::APT::Keep-Downloaded-Packages "true";' > /etc/apt/apt.conf.d/keep-cache

# Base tools
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked --mount=type=cache,target=/var/lib/apt,sharing=locked \
    apt-get update && \
    apt-get install --no-install-recommends -y \
      autoconf \
      automake \
      build-essential \
      ca-certificates \
      curl \
      gpg-agent \
      hardlink \
      libtool \
      software-properties-common

# git
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked --mount=type=cache,target=/var/lib/apt,sharing=locked \
    add-apt-repository ppa:git-core/ppa && \
    apt-get update && \
    apt-get install --no-install-recommends -y git

# Pythons
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked --mount=type=cache,target=/var/lib/apt,sharing=locked \
    add-apt-repository $( (test "${TARGETARCH}" = "riscv64" && echo "ppa:mayeut-github/python-riscv64") || echo "ppa:deadsnakes/ppa" ) && \
    apt-get update && \
    apt-get install --no-install-recommends -y \
      python3.8-dev \
      python3.8-tk \
      python3.8-venv \
      python3.9-dev \
      python3.9-tk \
      python3.9-venv \
      python3.10-dev \
      python3.10-tk \
      python3.10-venv \
      python3.11-dev \
      python3.11-tk \
      python3.11-venv \
      python3.12-dev \
      python3.12-tk \
      python3.12-venv \
      python3.13-dev \
      python3.13-tk \
      python3.13-venv \
      python3.13-nogil \
      python3.13-tk-nogil

ARG PLATFORM=${TARGETARCH}
ARG PLATFORM=${PLATFORM/amd64/x86_64}
ARG PLATFORM=${PLATFORM/arm64/aarch64}
ARG PLATFORM=${PLATFORM/arm/armv7l}

ENV AUDITWHEEL_POLICY=${POLICY} AUDITWHEEL_ARCH=${PLATFORM} AUDITWHEEL_PLAT=${POLICY}_${PLATFORM}

COPY manylinux/docker/manylinux-entrypoint /usr/local/bin/manylinux-entrypoint
ENTRYPOINT ["manylinux-entrypoint"]

COPY manylinux/docker/build_scripts /opt/_internal/build_scripts/

RUN --mount=type=cache,target=/var/cache/apt,sharing=locked --mount=type=cache,target=/var/lib/apt,sharing=locked <<EOFD
#!/bin/bash
set -euxo pipefail

apt-get update
update-ca-certificates --fresh

for VERSION in 3.8 3.9 3.10 3.11 3.12 3.13 3.13t; do
  python${VERSION} -m venv --without-pip /opt/_internal/cpython-${VERSION}
done

# patch tools installation
cat <<'EOF' | sed -i "/TOOL} in/r /dev/stdin" /opt/_internal/build_scripts/finalize.sh
		manylinux*_armv7l-cmake)
			curl -fsSLo - https://apt.kitware.com/keys/kitware-archive-latest.asc | gpg --dearmor - > /usr/share/keyrings/kitware-archive-keyring.gpg
			echo "deb [signed-by=/usr/share/keyrings/kitware-archive-keyring.gpg] https://apt.kitware.com/ubuntu/ $(. /etc/os-release; echo ${UBUNTU_CODENAME}) main" > /etc/apt/sources.list.d/kitware.list
			apt-get update
			rm /usr/share/keyrings/kitware-archive-keyring.gpg
			apt-get install --no-install-recommends -y kitware-archive-keyring cmake
			;;
		manylinux*_riscv64-patchelf)
			apt-get install --no-install-recommends -y cmake
			pipx install patchelf==0.17.2.1
			;;
		manylinux*_riscv64-cmake|manylinux*_armv7l-swig|manylinux*_riscv64-swig) apt-get install --no-install-recommends -y ${TOOL};;
		*_riscv64-uv) continue;;  # no uv for riscv64
EOF

# overwrite update-system-packages
cat <<'EOF' > /opt/_internal/build_scripts/update-system-packages.sh
#!/bin/bash
set -euxo pipefail
# apt-get update
# apt-get upgrade -y
exit 0
EOF

manylinux-entrypoint /opt/_internal/build_scripts/finalize.sh pp39-pypy39_pp73 pp310-pypy310_pp73
EOFD
