variable "BASE_VARIANT" {
  default = "ubuntu"
}
variable "DEFAULT_TAG" {
  default = "osxcross:local"
}

// Special target: https://github.com/docker/metadata-action#bake-definition
target "docker-metadata-action" {
  tags = ["${DEFAULT_TAG}"]
}

// Default target if none specified
group "default" {
  targets = ["image-local"]
}

target "image" {
  inherits = ["docker-metadata-action"]
  args = {
    BASE_VARIANT = BASE_VARIANT
  }
}

target "image-local" {
  inherits = ["image"]
  output = ["type=docker"]
}

target "image-all" {
  inherits = ["image"]
  platforms = [
    "darwin/amd64",
    "darwin/arm64",
    "freebsd/amd64",
    "linux/386",
    "linux/amd64",
    "linux/arm",
    "linux/arm64",
    "linux/arm/v5",
    "linux/arm/v6",
    "linux/mips",
    "linux/mips64",
    "linux/mips64le",
    "linux/mipsle",
    "linux/ppc64le",
    "linux/riscv64",
    "linux/s390x",
    "windows/386",
    "windows/amd64",
    "windows/arm",
    "windows/arm64"
  ]
}

group "test" {
  targets = ["test-osxcross", "test-osxsdk"]
}

target "test-osxcross" {
  target = "test-osxcross"
  args = {
    BASE_VARIANT = BASE_VARIANT
  }
  output = ["type=cacheonly"]
}

target "test-osxsdk" {
  target = "test-osxsdk"
  output = ["type=cacheonly"]
  platforms = [
    "darwin/amd64",
    "darwin/arm64",
    "linux/amd64",
    "linux/arm64",
  ]
}
