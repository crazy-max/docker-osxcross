# syntax=docker/dockerfile:1

ARG BASE_VARIANT="ubuntu"
# renovate: datasource=docker depName=ubuntu versioning=ubuntu
ARG UBUNTU_VERSION=26.04
# renovate: datasource=docker depName=debian versioning=debian
ARG DEBIAN_VERSION=trixie
# renovate: datasource=docker depName=alpine versioning=docker
ARG ALPINE_VERSION=3.24
# renovate: datasource=docker depName=tonistiigi/xx versioning=docker
ARG XX_VERSION=1.10.0
# renovate: datasource=github-releases depName=NiklasRosenstein/pbzx
ARG PBZX_VERSION=v1.1.0
# renovate: datasource=git-refs depName=tpoechtrager/osxcross ref=master
ARG OSX_CROSS_COMMIT=8d457942c0237df988eb191c1c88546ad09e2696

ARG OSX_SDK_VERSION=26.5
ARG OSX_SDK_SHA256=5f044578cd78a3a9b9c965a42d56bad609ee5d252e1d4e6aa7c42fc3f35fee7b
ARG OSX_SDK="MacOSX${OSX_SDK_VERSION}.sdk"
ARG OSX_SDK_URL="https://swcdn.apple.com/content/downloads/09/08/047-91568-A_Y1CFZWQCD4/4xekpyz43i26dbp4enxfro8eb1q7wiujh5/CLTools_macOSNMOS_SDK.pkg"

FROM --platform=$BUILDPLATFORM busybox AS build-dummy-cross
RUN mkdir -p /out/osxcross/osxcross

FROM --platform=$BUILDPLATFORM busybox AS build-dummy-sdk
RUN mkdir -p /out/osxsdk/osxsdk

FROM --platform=$BUILDPLATFORM busybox AS build-dummy-winsdk
RUN mkdir -p /out/osxsdk /out/Files/osxsdk

FROM scratch AS build-dummy
COPY --link --from=build-dummy-cross / /
COPY --link --from=build-dummy-sdk / /

FROM --platform=$BUILDPLATFORM alpine:${ALPINE_VERSION} AS pbzx
RUN apk add --no-cache build-base xar-dev xz-dev
ARG PBZX_VERSION
ADD "https://github.com/NiklasRosenstein/pbzx.git#${PBZX_VERSION}" /src
RUN cc -O2 /src/pbzx.c -o /usr/local/bin/pbzx -llzma -lxar

FROM --platform=$BUILDPLATFORM alpine:${ALPINE_VERSION} AS sdk
RUN apk add --no-cache libarchive-tools libxar tar xz
COPY --from=pbzx /usr/local/bin/pbzx /usr/local/bin/
ARG OSX_SDK
ARG OSX_SDK_URL
ARG OSX_SDK_SHA256
ADD --checksum=sha256:${OSX_SDK_SHA256} ${OSX_SDK_URL} /tmp/sdk.pkg
RUN <<EOT
  set -eo pipefail
  mkdir /osxsdk
  cd /tmp
  bsdtar -xOf sdk.pkg Payload | pbzx -n - | bsdtar -xf - "./Library/Developer/CommandLineTools/SDKs/$OSX_SDK"
  mv "Library/Developer/CommandLineTools/SDKs/$OSX_SDK" /osxsdk/
  XZ_OPT=-1 tar -cJf "/$OSX_SDK.tar.xz" -C /osxsdk "$OSX_SDK"
EOT

FROM scratch AS osxcross-src
WORKDIR /osxcross
ARG OSX_CROSS_COMMIT
ADD "https://github.com/tpoechtrager/osxcross.git#${OSX_CROSS_COMMIT}" .

FROM ubuntu:${UBUNTU_VERSION} AS base-ubuntu
RUN apt-get update && apt-get install --no-install-recommends -y \
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
  libssl-dev \
  libxml2-dev \
  libz-dev \
  llvm-dev \
  make \
  patch \
  python3 \
  uuid-dev \
  wget \
  xz-utils \
  zlib1g-dev

FROM debian:${DEBIAN_VERSION} AS base-debian
RUN apt-get update && apt-get install --no-install-recommends -y \
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
  libssl-dev \
  libxml2-dev \
  libz-dev \
  llvm-dev \
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
  xz

FROM base-${BASE_VARIANT} AS build-osxcross
ARG OSX_SDK
WORKDIR /tmp/osxcross
COPY --link --from=osxcross-src /osxcross .
COPY --link --from=sdk /$OSX_SDK.tar.xz ./tarballs/$OSX_SDK.tar.xz
RUN OSX_VERSION_MIN=10.13 UNATTENDED=1 ENABLE_COMPILER_RT_INSTALL=1 TARGET_DIR=/out/osxcross ./build.sh
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
RUN apt-get update && apt-get install -y clang file lld libc6-dev

FROM --platform=$BUILDPLATFORM debian:${DEBIAN_VERSION} AS test-debian
RUN apt-get update && apt-get install -y clang file lld libc6-dev

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
  file -b /tmp/test | grep -F 'Mach-O 64-bit x86_64 executable'

  oa64-clang -v test.c -O3 -o /tmp/test-arm64
  file -b /tmp/test-arm64 | grep -F 'Mach-O 64-bit arm64 executable'

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

  if [ "${TARGETPLATFORM%%/*}" = darwin ]; then
    xx-clang test_corefoundation.c -framework CoreFoundation -o /tmp/test-corefoundation
    xx-verify /tmp/test-corefoundation
  fi
EOT

FROM scratch
COPY --link --from=build /out /
