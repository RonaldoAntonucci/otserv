#!/bin/sh

set -u

target=${1:-}
environment_file=${2:-}
repository_root=${REPOSITORY_ROOT:-.}
failed=0

fail() {
    printf 'FAIL %s\n' "$1" >&2
    failed=$((failed + 1))
}

value_from() {
    key=$1
    awk -F= -v key="$key" '$1 == key { sub(/^[^=]*=/, ""); print; exit }' "$environment_file" 2>/dev/null
}

case "$target" in
    development|vps) ;;
    *)
        printf 'Usage: %s <development|vps> <environment-file>\n' "$0" >&2
        exit 2
        ;;
esac

if [ ! -f "$environment_file" ]; then
    printf 'FAIL environment file does not exist: %s\n' "$environment_file" >&2
    exit 1
fi

required_variables="MYSQL_HOST MYSQL_PORT MYSQL_DATABASE MYSQL_USER MYSQL_PASSWORD TFS_IP TFS_LOGIN_PORT TFS_GAME_PORT TFS_STATUS_PORT TFS_MAP_NAME TFS_PROTOCOL"
for variable in $required_variables; do
    if ! grep -q "^${variable}=" "$environment_file"; then
        fail "missing required variable: $variable"
        continue
    fi

    if [ -z "$(value_from "$variable")" ]; then
        fail "required variable is blank: $variable"
    fi
done

expected_mysql_host="db"
if [ "$target" = "vps" ]; then
    expected_mysql_host="127.0.0.1"
fi

[ "$(value_from MYSQL_HOST)" = "$expected_mysql_host" ] || fail "MYSQL_HOST must be $expected_mysql_host for $target"
[ "$(value_from MYSQL_PORT)" = "3306" ] || fail "MYSQL_PORT must be 3306"
[ "$(value_from MYSQL_DATABASE)" = "forgottenserver" ] || fail "MYSQL_DATABASE must be forgottenserver"
[ "$(value_from MYSQL_USER)" = "otserv" ] || fail "MYSQL_USER must be otserv"
[ "$(value_from TFS_LOGIN_PORT)" = "7171" ] || fail "TFS_LOGIN_PORT must be 7171"
[ "$(value_from TFS_GAME_PORT)" = "7172" ] || fail "TFS_GAME_PORT must be 7172"
[ "$(value_from TFS_STATUS_PORT)" = "7171" ] || fail "TFS_STATUS_PORT must be 7171"
[ "$(value_from TFS_MAP_NAME)" = "forgotten" ] || fail "TFS_MAP_NAME must be forgotten"
[ "$(value_from TFS_PROTOCOL)" = "13.10" ] || fail "TFS_PROTOCOL must be 13.10"

if [ "$target" = "development" ] && [ "$(value_from TFS_IP)" != "127.0.0.1" ]; then
    fail "TFS_IP must be 127.0.0.1 for development"
fi

case "$(value_from TFS_IP)" in
    CHANGE_ME*|YOUR_*) fail "TFS_IP placeholder must be replaced" ;;
esac

if git -C "$repository_root" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    tracked_secrets=$(git -C "$repository_root" ls-files | while IFS= read -r tracked_file; do
        case "$tracked_file" in
            *.env.example) ;;
            *.env|*.env.*) printf '%s\n' "$tracked_file" ;;
        esac
    done)

    if [ -n "$tracked_secrets" ]; then
        fail "runtime secret file is tracked by Git"
    fi
fi

if [ "$failed" -ne 0 ]; then
    printf '%s configuration errors found\n' "$failed" >&2
    exit 1
fi

printf 'Configuration valid for %s\n' "$target"
