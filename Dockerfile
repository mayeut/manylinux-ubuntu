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
    if [ "${TARGETARCH}" != "s390x" ]; then add-apt-repository ppa:git-core/ppa; fi && \
    apt-get update && \
    apt-get install --no-install-recommends -y git

# Pythons
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked --mount=type=cache,target=/var/lib/apt,sharing=locked \
    add-apt-repository ppa:mayeut-github/python-$(. /etc/os-release; echo ${UBUNTU_CODENAME}) && \
    apt-get update && \
    apt-get install --no-install-recommends -y \
      python3.8-dev python3.8-tk python3.8-venv python3.8-gdbm \
      python3.9-dev python3.9-tk python3.9-venv python3.9-gdbm \
      python3.10-dev python3.10-tk python3.10-venv python3.10-gdbm \
      python3.11-dev python3.11-tk python3.11-venv python3.11-gdbm \
      python3.12-dev python3.12-tk python3.12-venv python3.12-gdbm \
      python3.13-dev python3.13-tk python3.13-venv python3.13-gdbm \
      python3.13-nogil python3.13-tk-nogil python3.13-gdbm-nogil  \
      $(if [ "${POLICY}" != "manylinux_2_31" ]; then echo "python3.14-dev python3.14-tk python3.14-venv python3.14-gdbm python3.14-nogil python3.14-tk-nogil python3.14-gdbm-nogil"; fi)

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

VERSIONS="3.8 3.9 3.10 3.11 3.12 3.13 3.13t"
if [ "${POLICY}" != "manylinux_2_31" ]; then
	VERSIONS="${VERSIONS} 3.14 3.14t"
fi

for VERSION in ${VERSIONS}; do
  python${VERSION} -m venv --without-pip /opt/_internal/cpython-${VERSION}
done

# overwrite update-system-packages
cat <<'EOF' > /opt/_internal/build_scripts/update-system-packages.sh
#!/bin/bash
set -euxo pipefail
# apt-get update
# apt-get upgrade -y
exit 0
EOF

manylinux-entrypoint /opt/_internal/build_scripts/finalize.sh pp310-pypy310_pp73 pp311-pypy311_pp73
EOFD
