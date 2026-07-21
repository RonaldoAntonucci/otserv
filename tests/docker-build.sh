#!/bin/sh

set -u

ROOT_DIR=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
. "$ROOT_DIR/tests/lib/assert.sh"

IMAGE=${TFS_TEST_IMAGE:-otserv-tfs:test}
EXPECTED_REVISION=098641981400f8ff89959f427f0e8718d9dd22e2
TEMP_DIR=$(mktemp -d)
BUILD_LOG="$TEMP_DIR/build.log"
IMAGE_READY=false

cleanup() {
    rm -rf "$TEMP_DIR"
}
trap cleanup EXIT HUP INT TERM

cd "$ROOT_DIR"

if docker build \
    --platform linux/amd64 \
    --file docker/tfs.Dockerfile \
    --tag "$IMAGE" \
    . >"$BUILD_LOG" 2>&1; then
    revision=$(docker image inspect --format '{{index .Config.Labels "org.opencontainers.image.revision"}}' "$IMAGE")
    architecture=$(docker image inspect --format '{{.Architecture}}' "$IMAGE")
    if [ "$revision" = "$EXPECTED_REVISION" ] && [ "$architecture" = "amd64" ]; then
        IMAGE_READY=true
        build_contract=ready
    else
        build_contract=invalid
    fi
else
    build_contract=failed
    cat "$BUILD_LOG" >&2
fi
assert_equal ready "$build_contract" "clean amd64 build records the pinned TFS revision" || true

binary_contract=failed
if [ "$IMAGE_READY" = true ] && docker run --rm --platform linux/amd64 --entrypoint /bin/sh "$IMAGE" -c 'test -x /usr/local/bin/tfs'; then
    binary_contract=ready
fi
assert_equal ready "$binary_contract" "runtime image contains an executable TFS binary" || true

runtime_contract=failed
if [ "$IMAGE_READY" = true ] && docker run --rm --platform linux/amd64 --entrypoint /bin/sh "$IMAGE" -c \
    'test -f /srv/config.lua && test -f /srv/schema.sql && test -f /srv/data/world/forgotten.otbm && test -f /srv/data/scripts/talkactions/position.lua'; then
    runtime_contract=ready
fi
assert_equal ready "$runtime_contract" "runtime image contains config schema and official datapack" || true

security_contract=failed
if [ "$IMAGE_READY" = true ]; then
    image_user=$(docker image inspect --format '{{.Config.User}}' "$IMAGE")
    image_volumes=$(docker image inspect --format '{{json .Config.Volumes}}' "$IMAGE")
    if [ -n "$image_user" ] && [ "$image_user" != "0" ] && [ "$image_user" != "root" ] && \
        ! printf '%s' "$image_volumes" | grep -q '"/srv"'; then
        security_contract=ready
    fi
fi
assert_equal ready "$security_contract" "runtime uses a non-root user without a broad srv volume" || true

libraries_contract=failed
if [ "$IMAGE_READY" = true ]; then
    libraries=$(docker run --rm --platform linux/amd64 --entrypoint /usr/bin/ldd "$IMAGE" /usr/local/bin/tfs 2>&1 || true)
    if ! printf '%s\n' "$libraries" | grep -q 'not found' && \
        printf '%s\n' "$libraries" | grep -q 'libboost' && \
        printf '%s\n' "$libraries" | grep -q 'libfmt' && \
        printf '%s\n' "$libraries" | grep -q 'libluajit' && \
        printf '%s\n' "$libraries" | grep -q 'libmariadb' && \
        printf '%s\n' "$libraries" | grep -q 'libpugixml' && \
        printf '%s\n' "$libraries" | grep -Eq 'libssl|libcrypto'; then
        libraries_contract=ready
    fi
fi
assert_equal ready "$libraries_contract" "TFS resolves the expected runtime libraries" || true

mkdir -p "$TEMP_DIR/invalid-context/docker"
invalid_contract=failed
if cp docker/tfs.Dockerfile "$TEMP_DIR/invalid-context/docker/tfs.Dockerfile" 2>/dev/null && \
    cp docker/config.lua "$TEMP_DIR/invalid-context/docker/config.lua" 2>/dev/null && \
    ! docker build \
        --platform linux/amd64 \
        --file "$TEMP_DIR/invalid-context/docker/tfs.Dockerfile" \
        "$TEMP_DIR/invalid-context" >/dev/null 2>&1; then
    invalid_contract=ready
fi
assert_equal ready "$invalid_contract" "build rejects a context without pinned TFS source" || true

finish_tests
