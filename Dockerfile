FROM ubuntu:22.04

ARG DEBIAN_FRONTEND=noninteractive

RUN rm -f /etc/apt/apt.conf.d/docker-clean; echo 'Binary::apt::APT::Keep-Downloaded-Packages "true";' > /etc/apt/apt.conf.d/keep-cache

# Base tools
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt,sharing=locked \
    apt-get update && \
    apt-get install --no-install-recommends -y \
      build-essential \
      curl \
      gpg-agent \
      software-properties-common

# git
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt,sharing=locked \
    add-apt-repository ppa:git-core/ppa && \
    apt-get update && \
    apt-get install --no-install-recommends -y git

# Pythons
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt,sharing=locked \
    add-apt-repository ppa:deadsnakes/ppa && \
    apt-get update && \
    apt-get install --no-install-recommends -y \
      python3.8-dev \
      python3.8-venv \
      python3.9-dev \
      python3.9-venv \
      python3.10-dev \
      python3.10-venv \
      python3.11-dev \
      python3.11-venv \
      python3.12-dev \
      python3.12-venv \
      python3.13-dev \
      python3.13-venv \
      python3.13-nogil

ARG TARGETARCH
ARG PLATFORM=${TARGETARCH}
ARG PLATFORM=${PLATFORM/amd64/x86_64}
ARG PLATFORM=${PLATFORM/arm64/aarch64}
ARG PLATFORM=${PLATFORM/arm/armv7l}

ENV AUDITWHEEL_POLICY=manylinux_2_35 AUDITWHEEL_ARCH=${PLATFORM} AUDITWHEEL_PLAT=manylinux_2_35_${PLATFORM}


COPY manylinux/docker/manylinux-entrypoint /usr/local/bin/manylinux-entrypoint
ENTRYPOINT ["manylinux-entrypoint"]

COPY manylinux/docker/build_scripts /opt/_internal/build_scripts/
COPY finalize.sh /opt/_internal/build_scripts/finalize.sh
COPY finalize-one.sh /opt/_internal/build_scripts/finalize-one.sh

RUN manylinux-entrypoint /opt/_internal/build_scripts/finalize.sh \
      pp39-pypy39_pp73 \
      pp310-pypy310_pp73
