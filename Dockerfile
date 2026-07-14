ARG POLICY=manylinux_2_39
ARG BASE_IMAGE_VERSION=${POLICY}
ARG BASE_IMAGE_VERSION=${BASE_IMAGE_VERSION/manylinux_2_31/20.04}
ARG BASE_IMAGE_VERSION=${BASE_IMAGE_VERSION/manylinux_2_35/22.04}
ARG BASE_IMAGE_VERSION=${BASE_IMAGE_VERSION/manylinux_2_39/24.04}

FROM ubuntu:${BASE_IMAGE_VERSION}

ARG DEBIAN_FRONTEND=noninteractive
ARG POLICY
ARG TARGETARCH

RUN rm -f /etc/apt/apt.conf.d/docker-clean; echo 'Binary::apt::APT::Keep-Downloaded-Packages "true";' > /etc/apt/apt.conf.d/keep-cache

# Base tools
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked --mount=type=cache,target=/var/lib/apt,sharing=locked <<EOR
#!/bin/bash
set -euxo pipefail

apt-get update
apt-get install --no-install-recommends -y \
    autoconf \
    automake \
    build-essential \
    ca-certificates \
    curl \
    $(if [ "${POLICY}" == "manylinux_2_31" ]; then echo "dirmngr"; fi) \
    gpg-agent \
    hardlink \
    libtool \
    software-properties-common \
    $(if [ "${TARGETARCH}" = "amd64" ]; then echo "yasm"; fi)
EOR

# git
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked --mount=type=cache,target=/var/lib/apt,sharing=locked <<EOR
#!/bin/bash
set -euxo pipefail

if [ "${POLICY}" == "manylinux_2_31" ]; then
    mkdir -p /etc/apt/keyrings
    gpg --homedir /tmp --no-default-keyring --keyring /etc/apt/keyrings/git-ppa.gpg --keyserver hkps://keyserver.ubuntu.com --recv-keys F911AB184317630C59970973E363C90F8F1B6217
    echo "deb [signed-by=/etc/apt/keyrings/git-ppa.gpg] https://ppa.launchpadcontent.net/git-core/ppa/ubuntu focal main" > /etc/apt/sources.list.d/git.list
else
    add-apt-repository ppa:git-core/ppa
fi
apt-get update
apt-get install --no-install-recommends -y git
EOR

# Pythons
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked --mount=type=cache,target=/var/lib/apt,sharing=locked <<EOR
#!/bin/bash
set -euxo pipefail

if [ "${POLICY}" == "manylinux_2_31" ]; then
    mkdir -p /etc/apt/keyrings
    gpg --homedir /tmp --no-default-keyring --keyring /etc/apt/keyrings/python-ppa.gpg --keyserver hkps://keyserver.ubuntu.com --recv-keys 07F04AF38235B3324F8B8607E2B0200952C56F5E
    echo "deb [signed-by=/etc/apt/keyrings/python-ppa.gpg] https://ppa.launchpadcontent.net/mayeut-github/python-focal/ubuntu focal main" > /etc/apt/sources.list.d/python.list
else
  add-apt-repository ppa:mayeut-github/python-$(. /etc/os-release; echo ${UBUNTU_CODENAME})
fi
apt-get update
apt-get install --no-install-recommends -y \
    python3.9-dev python3.9-tk python3.9-venv python3.9-gdbm \
    python3.10-dev python3.10-tk python3.10-venv python3.10-gdbm \
    python3.11-dev python3.11-tk python3.11-venv python3.11-gdbm \
    python3.12-dev python3.12-tk python3.12-venv python3.12-gdbm \
    python3.13-dev python3.13-tk python3.13-venv python3.13-gdbm \
    $(if [ "${POLICY}" != "manylinux_2_31" ]; then echo "python3.14-dev python3.14-tk python3.14-venv python3.14-gdbm python3.14-nogil python3.14-tk-nogil python3.14-gdbm-nogil"; fi) \
    $(if [ "${POLICY}" != "manylinux_2_31" ]; then echo "python3.15-dev python3.15-tk python3.15-venv python3.15-gdbm python3.15-nogil python3.15-tk-nogil python3.15-gdbm-nogil"; fi)
EOR

ARG PLATFORM=${TARGETARCH}
ARG PLATFORM=${PLATFORM/amd64/x86_64}
ARG PLATFORM=${PLATFORM/arm64/aarch64}
ARG PLATFORM=${PLATFORM/arm/armv7l}

ENV AUDITWHEEL_POLICY=${POLICY} AUDITWHEEL_ARCH=${PLATFORM} AUDITWHEEL_PLAT=${POLICY}_${PLATFORM}
ENV PATH=/opt/clang/bin:${PATH}

COPY manylinux/docker/manylinux-entrypoint /usr/local/bin/manylinux-entrypoint
ENTRYPOINT ["manylinux-entrypoint"]

COPY manylinux/docker/build_scripts /opt/_internal/build_scripts/

RUN --mount=type=cache,target=/var/cache/apt,sharing=locked --mount=type=cache,target=/var/lib/apt,sharing=locked <<EOR
#!/bin/bash
set -euxo pipefail

apt-get update
update-ca-certificates --fresh

VERSIONS="3.9 3.10 3.11 3.12 3.13"
if [ "${POLICY}" != "manylinux_2_31" ]; then
	VERSIONS="${VERSIONS} 3.14 3.14t 3.15 3.15t"
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

manylinux-entrypoint /opt/_internal/build_scripts/finalize.sh pp311-pypy311_pp73
EOR

COPY manylinux/docker/tests /opt/_internal/tests/
