#!/usr/bin/env bash

set -eu
set -o pipefail

readonly PROGDIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly BUILDPACKDIR="$(cd "${PROGDIR}/.." && pwd)"

function main() {
  while [[ "${#}" != 0 ]]; do
    case "${1}" in
      --help|-h)
        shift 1
        usage
        exit 0
        ;;

      "")
        # skip if the argument is empty
        shift 1
        ;;

      *)
        util::print::error "unknown argument \"${1}\""
    esac
  done

  mkdir -p "${BUILDPACKDIR}/linux"

  run::build
  cmd::build
}

function usage() {
  cat <<-USAGE
build.sh [OPTIONS]

Builds the buildpack executables.

OPTIONS
  --help  -h  prints the command usage
USAGE
}

function run::build() {
  if [[ -f "${BUILDPACKDIR}/run/main.go" ]]; then
      printf "%s" "Building run... "

      GOOS=linux \
      GOARCH="amd64" \
      CGO_ENABLED=0 \
        go build \
          -ldflags="-s -w" \
          -o "linux/amd64/bin/run" \
            "${BUILDPACKDIR}/run"

      GOOS=linux \
      GOARCH="arm64" \
      CGO_ENABLED=0 \
        go build \
          -ldflags="-s -w" \
          -o "linux/arm64/bin/run" \
            "${BUILDPACKDIR}/run"


      echo "Success!"

      names=("detect")

      if [ -f "${BUILDPACKDIR}/extension.toml" ]; then
        names+=("generate")
      else
        names+=("build")
      fi

      for name in "${names[@]}"; do
        printf "%s" "Linking ${name}... "

        ln -sf "run" "linux/amd64/bin/${name}"
        ln -sf "run" "linux/arm64/bin/${name}"

        echo "Success!"
      done
  fi
}

function cmd::build() {
  if [[ -d "${BUILDPACKDIR}/cmd" ]]; then
    local name
    for src in "${BUILDPACKDIR}"/cmd/*; do
      name="$(basename "${src}")"

      if [[ -f "${src}/main.go" ]]; then
        printf "%s" "Building ${name}... "

        GOOS="linux" \
        GOARCH="amd64" \
        CGO_ENABLED=0 \
          go build \
            -ldflags="-s -w" \
            -o "${BUILDPACKDIR}/linux/amd64/bin/${name}" \
              "${src}/main.go"

        GOOS="linux" \
        GOARCH="arm64" \
        CGO_ENABLED=0 \
          go build \
            -ldflags="-s -w" \
            -o "${BUILDPACKDIR}/linux/arm64/bin/${name}" \
              "${src}/main.go"

        echo "Success!"
      else
        printf "%s" "Skipping ${name}... "
      fi
    done
  fi
}

main "${@:-}"
