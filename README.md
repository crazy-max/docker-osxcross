[![Latest version](https://img.shields.io/github/v/tag/crazy-max/docker-osxcross?label=version&style=flat-square)](https://hub.docker.com/r/crazymax/osxcross/tags?page=1&ordering=last_updated)
[![Build Status](https://img.shields.io/github/actions/workflow/status/crazy-max/docker-osxcross/build.yml?branch=main&label=build&logo=github&style=flat-square)](https://github.com/crazy-max/docker-osxcross/actions?query=workflow%3Abuild)
[![Docker Stars](https://img.shields.io/docker/stars/crazymax/osxcross.svg?style=flat-square&logo=docker)](https://hub.docker.com/r/crazymax/osxcross/)
[![Docker Pulls](https://img.shields.io/docker/pulls/crazymax/osxcross.svg?style=flat-square&logo=docker)](https://hub.docker.com/r/crazymax/osxcross/)

[![Become a sponsor](https://img.shields.io/badge/sponsor-crazy--max-181717.svg?logo=github&style=flat-square)](https://github.com/sponsors/crazy-max)
[![Donate Paypal](https://img.shields.io/badge/donate-paypal-00457c.svg?logo=paypal&style=flat-square)](https://www.paypal.me/crazyws)

## About

MacOSX cross toolchain as a Docker image.

> [!TIP] 
> Want to be notified of new releases? Check out 🔔 [Diun (Docker Image Update Notifier)](https://github.com/crazy-max/diun)
> project!

## Notice of Non-Affiliation and Disclaimer

This Docker image is not affiliated with Apple Inc. and does not represent
Apple's official product, service or practice. Apple is not responsible for and
does not endorse this Docker image.

This Docker image is not affiliated with the Xcode project.

**[Please ensure you have read and understood the Xcode license
terms before using it.](https://www.apple.com/legal/sla/docs/xcode.pdf)**

___

* [Build](#build)
* [Image](#image)
  * [Supported tags](#supported-tags)
* [Usage](#usage)
* [Contributing](#contributing)
* [License](#license)

## Projects using osxcross

* [crazy-max/goxx](https://github.com/crazy-max/goxx)
* [docker/docker-credential-helpers](https://github.com/docker/docker-credential-helpers)
* [jzelinskie/faq](https://github.com/jzelinskie/faq)

## Build

```shell
git clone https://github.com/crazy-max/docker-osxcross.git
cd docker-osxcross

# Build image and output to docker (default)
docker buildx bake

# Build multi-platform image
docker buildx bake image-all
```

## Image

| Registry                                                                                             | Image                           |
|------------------------------------------------------------------------------------------------------|---------------------------------|
| [Docker Hub](https://hub.docker.com/r/crazymax/osxcross/)                                            | `crazymax/osxcross`             |
| [GitHub Container Registry](https://github.com/users/crazy-max/packages/container/package/osxcross)  | `ghcr.io/crazy-max/osxcross`    |

```
$ docker buildx imagetools inspect crazymax/osxcross --format "{{json .Manifest}}" | \
  jq -r '.manifests[] | select(.platform.os != null and .platform.os != "unknown") | .platform | "\(.os)/\(.architecture)\(if .variant then "/" + .variant else "" end)"'

darwin/amd64
darwin/arm64
linux/amd64
linux/arm64
```

### Supported tags

`alpine`, `debian` and `ubuntu` variants are available for this image with
`ubuntu` being the default one.

* `edge`, `edge-ubuntu`
* `edge-debian`
* `edge-alpine`
* `latest`, `latest-ubuntu`, `xx.x`, `xx.x-rx`, `xx.x-ubuntu`, `xx.x-rx-ubuntu`
* `latest-debian`, `xx.x-debian`, `xx.x-rx-debian`
* `latest-alpine`, `xx.x-alpine`, `xx.x-rx-alpine`

> [!NOTE]
> `xx.x` has to be replaced with one of the MaxOSX releases available (e.g. `11.3`).
> `rx` has to be replaced with a release number (e.g. `r6`).

## Usage

```dockerfile
# syntax=docker/dockerfile:1

ARG OSXCROSS_VERSION=latest
FROM --platform=$BUILDPLATFORM crazymax/osxcross:${OSXCROSS_VERSION}-ubuntu AS osxcross

FROM ubuntu
RUN apt-get update && apt-get install -y clang lld libc6-dev
ENV PATH="/osxcross/bin:$PATH"
ENV LD_LIBRARY_PATH="/osxcross/lib:$LD_LIBRARY_PATH"
RUN --mount=type=bind,from=osxcross,source=/osxcross,target=/osxcross \
      o64-clang ...
```

With alpine:

```dockerfile
# syntax=docker/dockerfile:1

ARG OSXCROSS_VERSION=latest
FROM --platform=$BUILDPLATFORM crazymax/osxcross:${OSXCROSS_VERSION}-alpine AS osxcross

FROM alpine
RUN apk add --no-cache clang lld musl-dev
ENV PATH="/osxcross/bin:$PATH"
ENV LD_LIBRARY_PATH="/osxcross/lib:$LD_LIBRARY_PATH"
RUN --mount=type=bind,from=osxcross,source=/osxcross,target=/osxcross \
      o64-clang ...
```

`darwin/amd64` and `darwin/arm64` platforms are also available with the
MacOSX SDK in `/osxsdk` if you want to use it as sysroot with your own toolchain
like [`tonistiigi/xx`](https://github.com/tonistiigi/xx):

```dockerfile
# syntax=docker/dockerfile:1

ARG OSXCROSS_VERSION=latest
FROM crazymax/osxcross:${OSXCROSS_VERSION}-alpine AS osxcross
FROM --platform=$BUILDPLATFORM tonistiigi/xx:1.1.2 AS xx

FROM --platform=$BUILDPLATFORM alpine
COPY --from=xx / /
RUN apk add --no-cache clang lld musl-dev
ARG TARGETPLATFORM
RUN xx-apk add gcc g++ musl-dev
RUN --mount=type=bind,target=. \
    --mount=type=bind,from=osxcross,source=/osxsdk,target=/xx-sdk \
      xx-clang ...
```

## Contributing

Want to contribute? Awesome! The most basic way to show your support is to star the project, or to raise issues. You
can also support this project by [**becoming a sponsor on GitHub**](https://github.com/sponsors/crazy-max) or by making
a [Paypal donation](https://www.paypal.me/crazyws) to ensure this journey continues indefinitely!

Thanks again for your support, it is much appreciated! :pray:

## License

MIT. See `LICENSE` for more details.
