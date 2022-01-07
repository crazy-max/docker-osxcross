# syntax=docker/dockerfile:1-labs

ARG BASE_VARIANT="ubuntu"
ARG UBUNTU_VERSION="18.04"
ARG ALPINE_VERSION="3.15"

ARG CMAKE_VERSION="3.20.1"
ARG OSX_SDK="MacOSX11.3.sdk"
ARG OSX_SDK_URL="https://github.com/phracker/MacOSX-SDKs/releases/download/11.3/${OSX_SDK}.tar.xz"
ARG OSX_CROSS_COMMIT="062922bbb81ac52787d8e53fa4af190acb552ec7"

FROM --platform=$BUILDPLATFORM alpine AS sdk
RUN apk --update --no-cache add ca-certificates curl tar xz
ARG OSX_SDK
ARG OSX_SDK_URL
RUN curl -sSL "$OSX_SDK_URL" -o "/$OSX_SDK.tar.xz"
RUN mkdir /osxsdk && tar -xf "/$OSX_SDK.tar.xz" -C "/osxsdk"

FROM --platform=$BUILDPLATFORM alpine AS osxcross-src
RUN apk --update --no-cache add git patch
WORKDIR /osxcross
ARG OSX_CROSS_COMMIT
RUN git clone https://github.com/tpoechtrager/osxcross.git . && git reset --hard $OSX_CROSS_COMMIT
COPY patches/lcxx.patch .
RUN patch -p1 < lcxx.patch

FROM ubuntu:${UBUNTU_VERSION} AS base-ubuntu
RUN export DEBIAN_FRONTEND="noninteractive" \
  && apt-get update \
  && apt-get install --no-install-recommends -y \
    bash \
    binutils-multiarch-dev \
    build-essential \
    ca-certificates \
    clang \
    git \
    libbz2-dev \
    libmpc-dev \
    libmpfr-dev \
    libgmp-dev \
    liblzma-dev \
    libpsi3-dev \
    libssl-dev \
    libxml2-dev \
    libz-dev \
    lzma-dev \
    make \
    patch \
    python \
    uuid-dev \
    wget \
    xz-utils \
    zlib1g-dev \
  && apt-get -y autoremove \
  && apt-get clean \
  && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*
ARG CMAKE_VERSION
RUN mkdir -p /opt/cmake && cd /opt/cmake && wget -q https://github.com/Kitware/CMake/releases/download/v${CMAKE_VERSION}/cmake-${CMAKE_VERSION}-Linux-$(uname -m).tar.gz -O - | tar xvz --strip 1
ENV PATH=/opt/cmake/bin:$PATH

FROM alpine:${ALPINE_VERSION} AS base-alpine
RUN apk add --update  --no-cache \
  bash \
  bsd-compat-headers \
  clang \
  cmake \
  fts-dev \
  g++ \
  git \
  gmp-dev \
  libxml2-dev \
  make \
  mc \
  mpc1-dev \
  mpfr-dev \
  openssl-dev \
  patch \
  python3 \
  xz

FROM base-${BASE_VARIANT} AS build-osxcross
ARG OSX_SDK
WORKDIR /tmp/osxcross
COPY --from=osxcross-src /osxcross .
COPY --from=sdk /$OSX_SDK.tar.xz ./tarballs/$OSX_SDK.tar.xz
RUN mkdir -p /out/osxsdk
RUN OSX_VERSION_MIN=10.10 UNATTENDED=1 ENABLE_COMPILER_RT_INSTALL=1 TARGET_DIR=/out/osxcross ./build.sh

FROM --platform=$BUILDPLATFORM busybox AS build-dummy
RUN mkdir -p /out/osxcross /out/osxsdk

FROM build-dummy AS build-darwin
COPY --from=sdk /osxsdk /out/osxsdk

FROM build-dummy AS build-windows
FROM build-dummy AS build-freebsd
FROM build-dummy AS build-linux-386
FROM build-osxcross AS build-linux-amd64
FROM build-dummy AS build-linux-arm
FROM build-osxcross AS build-linux-arm64
FROM build-dummy AS build-linux-armv5
FROM build-dummy AS build-linux-armv6
FROM build-dummy AS build-linux-armv7
FROM build-dummy AS build-linux-mips
FROM build-dummy AS build-linux-mips64
FROM build-dummy AS build-linux-mips64le
FROM build-dummy AS build-linux-mipsle
FROM build-dummy AS build-linux-ppc64le
FROM build-dummy AS build-linux-riscv64
FROM build-dummy AS build-linux-s390x
FROM build-linux-${TARGETARCH}${TARGETVARIANT} AS build-linux
FROM build-${TARGETOS} AS build

FROM ubuntu:${UBUNTU_VERSION} AS test-ubuntu
RUN apt-get update && apt-get install -y clang file lld libc6-dev

FROM alpine:${ALPINE_VERSION} AS test-alpine
RUN apk add --no-cache clang file lld musl-dev

FROM test-${BASE_VARIANT} AS test
COPY --from=build /out/osxcross /osxcross
ENV PATH="/osxcross/bin:$PATH"
ENV LD_LIBRARY_PATH="/osxcross/lib:$LD_LIBRARY_PATH"
WORKDIR /src
RUN --mount=type=bind,source=./test <<EOT
o64-clang -v test.c -O3 -o /tmp/test
file /tmp/test
o64-clang++ -v test.cpp -O3 -o /tmp/testcxx
file /tmp/testcxx
o64-clang++ -v test_libcxx.cpp -O3 -o /tmp/testlibcxx
file /tmp/testlibcxx
EOT

FROM scratch
COPY --from=build /out /
