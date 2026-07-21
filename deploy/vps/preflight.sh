#!/bin/sh

set -eu

paths_file=${OTSERV_PATHS_FILE:-/etc/otserv/paths.env}

fail() {
    printf 'Preflight failed: %s\n' "$1" >&2
    exit 1
}

[ -r "$paths_file" ] || fail "paths file is missing or unreadable: $paths_file"
. "$paths_file"

: "${TFS_CURRENT_DIR:?}"
: "${TFS_STATE_DIR:?}"
: "${TFS_CONFIG_FILE:?}"
: "${TFS_ENV_FILE:?}"
: "${TFS_EXECUTABLE:?}"
: "${TFS_CONFIG_LOADER:?}"
: "${TFS_DATAPACK_DIR:?}"
: "${TFS_MAP_FILE:?}"
: "${TFS_KEY_FILE:?}"

[ -x "$TFS_EXECUTABLE" ] || fail "TFS executable is missing or not executable"
[ -d "$TFS_CURRENT_DIR" ] || fail "active release directory is missing"
[ -d "$TFS_STATE_DIR" ] || fail "state directory is missing"
[ -r "$TFS_CONFIG_FILE" ] || fail "TFS configuration is missing or unreadable"
[ -r "$TFS_CONFIG_LOADER" ] || fail "release config loader is missing or unreadable"
[ -f "$TFS_ENV_FILE" ] || fail "environment file is missing"
[ "$(stat -c '%U:%G' "$TFS_ENV_FILE")" = "root:root" ] || fail "environment file must be owned by root:root"
[ "$(stat -c '%a' "$TFS_ENV_FILE")" = "600" ] || fail "environment file mode must be 0600"
[ -d "$TFS_DATAPACK_DIR" ] || fail "datapack directory is missing"
[ -r "$TFS_MAP_FILE" ] || fail "official map is missing or unreadable"
[ -r "$TFS_KEY_FILE" ] || fail "RSA key is missing or unreadable"

: "${MYSQL_HOST:?}"
: "${MYSQL_PORT:?}"
: "${MYSQL_DATABASE:?}"
: "${MYSQL_USER:?}"
: "${MYSQL_PASSWORD:?}"

command -v mariadb >/dev/null 2>&1 || fail "MariaDB client is not installed"

MYSQL_PWD="$MYSQL_PASSWORD" mariadb \
    --protocol=tcp \
    --host="$MYSQL_HOST" \
    --port="$MYSQL_PORT" \
    --user="$MYSQL_USER" \
    --database="$MYSQL_DATABASE" \
    --execute='SELECT 1' >/dev/null 2>&1 || fail "MariaDB is not ready"
