#!/bin/sh

set -u

EXPECTED_TFS_REVISION=098641981400f8ff89959f427f0e8718d9dd22e2
EXPECTED_MARKER_VALUE=vps-bootstrap-v1
SMOKE_ROOT=${OTSERV_SMOKE_FIXTURE_ROOT:-}
passed=0
failed=0

if [ -n "$SMOKE_ROOT" ] && [ ! -f /.dockerenv ]; then
    printf 'ERROR: fixture roots are allowed only inside the test container\n' >&2
    exit 2
fi

root_path() {
    printf '%s%s\n' "$SMOKE_ROOT" "$1"
}

record_result() {
    label=$1
    shift

    if "$@"; then
        passed=$((passed + 1))
        printf 'PASS %s\n' "$label"
    else
        failed=$((failed + 1))
        printf 'FAIL %s\n' "$label" >&2
    fi
}

environment_value() {
    key=$1
    file=$2

    awk -v wanted="$key" '
        index($0, wanted "=") == 1 {
            value = substr($0, length(wanted) + 2)
            count++
        }
        END {
            if (count != 1) exit 1
            print value
        }
    ' "$file" 2>/dev/null
}

os_release_value() {
    key=$1
    file=$2

    sed -n "s/^${key}=//p" "$file" 2>/dev/null | tail -n 1 | sed 's/^"//; s/"$//'
}

detected_architecture() {
    if [ -n "$SMOKE_ROOT" ]; then
        printf 'amd64\n'
        return 0
    fi
    dpkg --print-architecture 2>/dev/null
}

environment_file=$(root_path /etc/otserv/otserv.env)
active_release=$(root_path /opt/otserv/current)
os_release_file=$(root_path /etc/os-release)

database_host=$(environment_value MYSQL_HOST "$environment_file") || database_host=
database_port=$(environment_value MYSQL_PORT "$environment_file") || database_port=
database_name=$(environment_value MYSQL_DATABASE "$environment_file") || database_name=
database_user=$(environment_value MYSQL_USER "$environment_file") || database_user=
database_password=$(environment_value MYSQL_PASSWORD "$environment_file") || database_password=

supported_platform() {
    [ "$(id -u)" -eq 0 ] &&
        [ "$(os_release_value ID "$os_release_file")" = ubuntu ] &&
        [ "$(os_release_value VERSION_ID "$os_release_file")" = 24.04 ] &&
        [ "$(detected_architecture)" = amd64 ]
}

systemd_operational() {
    [ -d "$(root_path /run/systemd/system)" ] &&
        systemctl is-system-running --quiet >/dev/null 2>&1
}

revision_is_pinned() {
    revision_file="$active_release/REVISION"
    [ -r "$revision_file" ] && [ "$(cat "$revision_file")" = "$EXPECTED_TFS_REVISION" ]
}

executable_is_ready() {
    [ -x "$active_release/tfs" ]
}

official_map_is_present() {
    [ -r "$active_release/data/world/forgotten.otbm" ]
}

mariadb_is_active() {
    systemctl is-active --quiet mariadb.service >/dev/null 2>&1
}

mariadb_is_loopback_only() {
    listeners=$(ss -H -ltn 2>/dev/null | awk '$4 ~ /:3306$/ { print $4 }') || return 1
    [ -n "$listeners" ] || return 1
    printf '%s\n' "$listeners" | awk '
        $0 !~ /^127\.0\.0\.1:3306$/ && $0 !~ /^\[::1\]:3306$/ { unsafe = 1 }
        END { exit unsafe }
    '
}

database_query() {
    query=$1

    [ -n "$database_host" ] &&
        [ -n "$database_port" ] &&
        [ -n "$database_name" ] &&
        [ -n "$database_user" ] &&
        [ -n "$database_password" ] || return 1

    MYSQL_PWD="$database_password" mariadb \
        --protocol=tcp \
        --host="$database_host" \
        --port="$database_port" \
        --user="$database_user" \
        --database="$database_name" \
        --batch \
        --skip-column-names \
        --execute="$query" 2>/dev/null
}

schema_is_ready() {
    [ "$(database_query "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = '$database_name' AND table_name = 'server_config'")" = 1 ]
}

persistence_marker_is_present() {
    marker=$(database_query "SELECT value FROM server_config WHERE config = 'bootstrap_persistence_marker'") || return 1
    [ "$marker" = "$EXPECTED_MARKER_VALUE" ]
}

tfs_is_active() {
    systemctl is-active --quiet tfs.service >/dev/null 2>&1
}

port_is_listening() {
    expected_port=$1
    ss -H -ltn 2>/dev/null | awk -v port=":$expected_port" '$4 ~ (port "$") { found = 1 } END { exit !found }'
}

journal_from_current_boot() {
    journalctl --unit=tfs.service --boot --no-pager --output=cat 2>/dev/null
}

datapack_load_is_logged() {
    journal_from_current_boot | grep -Fq '>> Loaded all modules, server starting up...'
}

journal_has_no_fatal_startup_entries() {
    journal=$(journal_from_current_boot) || return 1
    ! printf '%s\n' "$journal" | grep -Eq '> ERROR:|FATAL|Failed to load map|Segmentation fault|terminate called|Address already in use'
}

record_result "supported Ubuntu 24.04 amd64 VPS" supported_platform
record_result "systemd is operational" systemd_operational
record_result "active release matches the pinned TFS revision" revision_is_pinned
record_result "TFS executable is ready" executable_is_ready
record_result "official forgotten map is present" official_map_is_present
record_result "MariaDB service is active" mariadb_is_active
record_result "MariaDB listens only on loopback" mariadb_is_loopback_only
record_result "TFS database schema is present" schema_is_ready
record_result "database persistence marker is present" persistence_marker_is_present
record_result "TFS service is active" tfs_is_active
record_result "login protocol port 7171 is listening" port_is_listening 7171
record_result "game protocol port 7172 is listening" port_is_listening 7172
record_result "datapack load completion is in the current boot journal" datapack_load_is_logged
record_result "current boot journal has no fatal startup entries" journal_has_no_fatal_startup_entries

printf '%s passed, %s failed\n' "$passed" "$failed"
[ "$failed" -eq 0 ]
