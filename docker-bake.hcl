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
    "linux/arm/v7",
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
    "windows/arm/v7",
    "windows/arm64"
  ]
}
