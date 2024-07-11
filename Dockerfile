# syntax=docker/dockerfile:1

ARG BASE_VARIANT="ubuntu"
ARG UBUNTU_VERSION="22.04"
ARG DEBIAN_VERSION="bookworm"
ARG ALPINE_VERSION="3.18"
ARG XX_VERSION="1.4.0"

ARG OSX_SDK="MacOSX14.5.sdk"
ARG OSX_SDK_URL="https://github.com/joseluisq/macosx-sdks/releases/download/14.5/${OSX_SDK}.tar.xz"
ARG OSX_CROSS_COMMIT="fd32ecc6e0786369272be2da670bc9b5849b215a"

FROM --platform=$BUILDPLATFORM busybox AS build-dummy-cross
RUN mkdir -p /out/osxcross/osxcross

FROM --platform=$BUILDPLATFORM busybox AS build-dummy-sdk
RUN mkdir -p /out/osxsdk/osxsdk

FROM --platform=$BUILDPLATFORM busybox AS build-dummy-winsdk
RUN mkdir -p /out/osxsdk /out/Files/osxsdk

FROM scratch AS build-dummy
COPY --link --from=build-dummy-cross / /
COPY --link --from=build-dummy-sdk / /

FROM --platform=$BUILDPLATFORM alpine:${ALPINE_VERSION} AS sdk
RUN apk --update --no-cache add ca-certificates curl tar xz
ARG OSX_SDK
ARG OSX_SDK_URL
RUN curl -sSL "$OSX_SDK_URL" -o "/$OSX_SDK.tar.xz"
RUN mkdir /osxsdk && tar -xf "/$OSX_SDK.tar.xz" -C "/osxsdk"

FROM --platform=$BUILDPLATFORM alpine:${ALPINE_VERSION} AS osxcross-src
RUN apk --update --no-cache add patch
WORKDIR /osxcross
ARG OSX_CROSS_COMMIT
ADD "https://github.com/tpoechtrager/osxcross.git#${OSX_CROSS_COMMIT}" .
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
    cmake \
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
    python3 \
    uuid-dev \
    wget \
    xz-utils \
    zlib1g-dev

FROM debian:${DEBIAN_VERSION} AS base-debian
RUN export DEBIAN_FRONTEND="noninteractive" \
  && apt-get update \
  && apt-get install --no-install-recommends -y \
    bash \
    binutils-multiarch-dev \
    build-essential \
    ca-certificates \
    clang \
    cmake \
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
    python3 \
    uuid-dev \
    wget \
    xz-utils \
    zlib1g-dev

FROM alpine:${ALPINE_VERSION} AS base-alpine
RUN apk add --update --no-cache \
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
  xz \
  wget

FROM base-${BASE_VARIANT} AS build-osxcross
ARG OSX_SDK
WORKDIR /tmp/osxcross
COPY --link --from=osxcross-src /osxcross .
COPY --link --from=sdk /$OSX_SDK.tar.xz ./tarballs/$OSX_SDK.tar.xz
RUN OSX_VERSION_MIN=10.13 UNATTENDED=1 ./build.sh
RUN OSX_VERSION_MIN=10.13 ./build_gcc.sh
RUN mkdir -p /out/osxcross
RUN mv target/* /out/osxcross
RUN mkdir -p /out/osxsdk/osxsdk

FROM scratch AS build-darwin
COPY --link --from=build-dummy-cross / /
COPY --link --from=sdk /osxsdk /out/osxsdk

FROM scratch AS build-windows
COPY --link --from=build-dummy-cross / /
COPY --link --from=build-dummy-winsdk / /

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

FROM --platform=$BUILDPLATFORM ubuntu:${UBUNTU_VERSION} AS test-ubuntu
RUN export DEBIAN_FRONTEND="noninteractive" && apt-get update && apt-get install -y clang file lld libc6-dev

FROM --platform=$BUILDPLATFORM debian:${DEBIAN_VERSION} AS test-debian
RUN export DEBIAN_FRONTEND="noninteractive" && apt-get update && apt-get install -y clang file lld libc6-dev

FROM --platform=$BUILDPLATFORM alpine:${ALPINE_VERSION} AS test-alpine
RUN apk add --no-cache clang file lld musl-dev

FROM test-${BASE_VARIANT} AS test-osxcross
COPY --link --from=build /out/osxcross /osxcross
ENV PATH="/osxcross/bin:$PATH"
ENV LD_LIBRARY_PATH="/osxcross/lib:$LD_LIBRARY_PATH"
WORKDIR /src
RUN --mount=type=bind,source=./test <<EOT
  set -e

  o64-clang -v test.c -O3 -o /tmp/test
  file /tmp/test

  o64-clang++ -v test.cpp -O3 -o /tmp/testcxx
  file /tmp/testcxx

  o64-clang++ -v test_libcxx.cpp -O3 -o /tmp/testlibcxx
  file /tmp/testlibcxx
EOT

FROM --platform=$BUILDPLATFORM tonistiigi/xx:${XX_VERSION} AS xx
FROM test-alpine AS test-osxsdk
WORKDIR /src
COPY --from=xx / /
RUN apk add --no-cache clang file lld musl-dev
ARG TARGETPLATFORM
RUN xx-apk add gcc g++ musl-dev
RUN --mount=type=bind,source=./test \
    --mount=from=sdk,src=/osxsdk,target=/xx-sdk <<EOT
  set -e
  echo "sysroot: $(xx-info sysroot)"

  xx-clang -v test.c -O3 -o /tmp/test
  xx-verify /tmp/test
  file /tmp/test

  xx-clang++ -v test.cpp -O3 -o /tmp/testcxx
  xx-verify /tmp/testcxx
  file /tmp/testcxx

  xx-clang++ -v test_libcxx.cpp -O3 -o /tmp/testlibcxx
  xx-verify /tmp/testlibcxx
  file /tmp/testlibcxx
EOT

FROM scratch
COPY --link --from=build /out /