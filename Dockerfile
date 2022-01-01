# syntax=docker/dockerfile:1.3

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

FROM ubuntu:21.04 AS base
RUN export DEBIAN_FRONTEND="noninteractive" \
  && apt-get update \
  && apt-get install --no-install-recommends -y \
    bash \
    binutils-multiarch \
    binutils-multiarch-dev \
    build-essential \
    ca-certificates \
    clang \
    cmake \
    gcc \
    g++ \
    git \
    llvm \
    llvm-dev \
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
    python \
    uuid-dev \
    xz-utils \
    zlib1g-dev \
  && apt-get -y autoremove \
  && apt-get clean \
  && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

FROM base as build-linux
ARG OSX_SDK
WORKDIR /tmp/osxcross
COPY --from=osxcross-src /osxcross .
COPY --from=sdk /$OSX_SDK.tar.xz ./tarballs/$OSX_SDK.tar.xz
RUN OSX_VERSION_MIN=10.10 UNATTENDED=1 ENABLE_COMPILER_RT_INSTALL=1 TARGET_DIR=/out/osxcross ./build.sh

FROM scratch as build-darwin
COPY --from=sdk /osxsdk /out/osxsdk

FROM build-${TARGETOS} AS build
FROM scratch
COPY --from=build /out /
