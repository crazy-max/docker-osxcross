# syntax=docker/dockerfile:1.3

ARG OSX_SDK="MacOSX11.3.sdk"
ARG OSX_SDK_URL="https://github.com/phracker/MacOSX-SDKs/releases/download/11.3/${OSX_SDK}.tar.xz"
ARG OSX_CROSS_COMMIT="d904031e7e3faa8a23c21b319a65cc915dac51b3"

FROM debian:bullseye-slim AS base
RUN export DEBIAN_FRONTEND="noninteractive" \
  && apt-get update \
  && apt-get install --no-install-recommends -y \
    bash \
    build-essential \
    ca-certificates \
    clang \
    cmake \
    curl \
    git \
    llvm \
    libssl-dev \
    libxml2-dev \
    libz-dev \
    lzma-dev \
    patch \
    python \
    xz-utils \
  && apt-get -y autoremove \
  && apt-get clean \
  && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

FROM base as osxcross
WORKDIR /tmp/osxcross
ARG OSX_CROSS_COMMIT
ARG OSX_SDK
ARG OSX_SDK_URL
RUN git clone https://github.com/tpoechtrager/osxcross.git . && git reset --hard $OSX_CROSS_COMMIT
RUN curl -sSL "$OSX_SDK_URL" -o "./tarballs/$OSX_SDK.tar.xz"
COPY patches/lcxx.patch .
RUN patch -p1 < lcxx.patch && OSX_VERSION_MIN=10.10 UNATTENDED=1 ENABLE_COMPILER_RT_INSTALL=1 TARGET_DIR=/osxsdk ./build.sh

FROM scratch
COPY --from=osxcross /osxsdk /osxsdk
