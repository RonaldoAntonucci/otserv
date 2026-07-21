#!/bin/sh

set -u

ROOT_DIR=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
. "$ROOT_DIR/tests/lib/assert.sh"

if [ ! -f /.dockerenv ]; then
    printf 'FAIL native service contracts must run in the test container\n' >&2
    exit 1
fi

SCRATCH_DIR=$(mktemp -d)
FIXTURE_ROOT="$SCRATCH_DIR/root"
MOCK_BIN="$SCRATCH_DIR/bin"
PATHS_FILE="$SCRATCH_DIR/paths.env"
UNIT_FILE="$ROOT_DIR/deploy/vps/tfs.service"
PREFLIGHT="$ROOT_DIR/deploy/vps/preflight.sh"

cleanup() {
    rm -rf "$SCRATCH_DIR"
}
trap cleanup EXIT HUP INT TERM

mkdir -p \
    "$FIXTURE_ROOT/etc/otserv" \
    "$FIXTURE_ROOT/opt/otserv/current/data/world" \
    "$FIXTURE_ROOT/var/lib/otserv" \
    "$MOCK_BIN"

if ! getent group otserv >/dev/null 2>&1; then
    groupadd --system otserv
fi

cat >"$FIXTURE_ROOT/opt/otserv/current/tfs" <<'EOF'
#!/bin/sh
exit 0
EOF
chmod 0755 "$FIXTURE_ROOT/opt/otserv/current/tfs"
printf '%s\n' "dofile('/etc/otserv/config.lua')" >"$FIXTURE_ROOT/opt/otserv/current/config.lua"
printf '%s\n' 'test key' >"$FIXTURE_ROOT/opt/otserv/current/key.pem"
printf '%s\n' 'test map' >"$FIXTURE_ROOT/opt/otserv/current/data/world/forgotten.otbm"
printf '%s\n' 'serverName = "OTServ"' >"$FIXTURE_ROOT/etc/otserv/config.lua"
printf '%s\n' 'MYSQL_PASSWORD=test-only' >"$FIXTURE_ROOT/etc/otserv/otserv.env"
chgrp otserv "$FIXTURE_ROOT/etc/otserv/config.lua"
chmod 0640 "$FIXTURE_ROOT/etc/otserv/config.lua"
chmod 0600 "$FIXTURE_ROOT/etc/otserv/otserv.env"

cat >"$PATHS_FILE" <<EOF
TFS_CURRENT_DIR=$FIXTURE_ROOT/opt/otserv/current
TFS_STATE_DIR=$FIXTURE_ROOT/var/lib/otserv
TFS_CONFIG_FILE=$FIXTURE_ROOT/etc/otserv/config.lua
TFS_ENV_FILE=$FIXTURE_ROOT/etc/otserv/otserv.env
TFS_EXECUTABLE=$FIXTURE_ROOT/opt/otserv/current/tfs
TFS_CONFIG_LOADER=$FIXTURE_ROOT/opt/otserv/current/config.lua
TFS_DATAPACK_DIR=$FIXTURE_ROOT/opt/otserv/current/data
TFS_MAP_FILE=$FIXTURE_ROOT/opt/otserv/current/data/world/forgotten.otbm
TFS_KEY_FILE=$FIXTURE_ROOT/opt/otserv/current/key.pem
EOF

cat >"$MOCK_BIN/mariadb" <<'EOF'
#!/bin/sh
[ "${DB_READY:-false}" = "true" ]
EOF
chmod 0755 "$MOCK_BIN/mariadb"

run_preflight() {
    DB_READY=${DB_READY:-true} \
    MYSQL_HOST=127.0.0.1 \
    MYSQL_PORT=3306 \
    MYSQL_DATABASE=forgottenserver \
    MYSQL_USER=otserv \
    MYSQL_PASSWORD=test-only \
    OTSERV_PATHS_FILE="$PATHS_FILE" \
    PATH="$MOCK_BIN:$PATH" \
    sh "$PREFLIGHT" >/dev/null 2>&1
}

validate_dependencies() {
    candidate_unit=$1
    grep -Fxq 'Wants=network-online.target' "$candidate_unit" &&
        grep -Fxq 'After=network-online.target mariadb.service' "$candidate_unit" &&
        grep -Fxq 'Requires=mariadb.service' "$candidate_unit"
}

mkdir -p /opt/otserv/current /usr/local/libexec/otserv /etc/systemd/system
cp "$FIXTURE_ROOT/opt/otserv/current/tfs" /opt/otserv/current/tfs 2>/dev/null || true
cp "$PREFLIGHT" /usr/local/libexec/otserv/preflight.sh 2>/dev/null || true
cat >/etc/systemd/system/mariadb.service <<'EOF'
[Service]
Type=oneshot
ExecStart=/usr/bin/true
EOF

syntax_contract=failed
if systemd-analyze verify "$UNIT_FILE" >/dev/null 2>&1; then
    syntax_contract=ready
fi
assert_equal ready "$syntax_contract" "systemd unit passes Ubuntu 24.04 verification" || true

identity_contract=failed
if grep -Fxq 'User=otserv' "$UNIT_FILE" 2>/dev/null &&
    grep -Fxq 'Group=otserv' "$UNIT_FILE" 2>/dev/null &&
    grep -Fxq 'WorkingDirectory=/opt/otserv/current' "$UNIT_FILE" 2>/dev/null &&
    grep -Fxq 'ExecStart=/opt/otserv/current/tfs' "$UNIT_FILE" 2>/dev/null &&
    ! grep -Fq -- '--config=' "$UNIT_FILE" 2>/dev/null; then
    identity_contract=ready
fi
assert_equal ready "$identity_contract" "unit uses the dedicated identity and approved release paths" || true

permission_contract=failed
if grep -Fxq 'EnvironmentFile=/etc/otserv/otserv.env' "$UNIT_FILE" 2>/dev/null && run_preflight; then
    chmod 0644 "$FIXTURE_ROOT/etc/otserv/otserv.env"
    if ! run_preflight; then
        permission_contract=ready
    fi
    chmod 0600 "$FIXTURE_ROOT/etc/otserv/otserv.env"
fi
assert_equal ready "$permission_contract" "preflight rejects weakened environment-file permissions" || true

dependency_contract=failed
if validate_dependencies "$UNIT_FILE" 2>/dev/null; then
    cp "$UNIT_FILE" "$SCRATCH_DIR/tfs.service"
    sed -i '/^Requires=mariadb.service$/d; s/^After=network-online.target mariadb.service$/After=network-online.target/' "$SCRATCH_DIR/tfs.service"
    if ! validate_dependencies "$SCRATCH_DIR/tfs.service"; then
        dependency_contract=ready
    fi
fi
assert_equal ready "$dependency_contract" "contract rejects removed MariaDB dependencies" || true

hardening_contract=failed
if grep -Fxq 'Restart=on-failure' "$UNIT_FILE" 2>/dev/null &&
    grep -Fxq 'NoNewPrivileges=yes' "$UNIT_FILE" 2>/dev/null &&
    grep -Fxq 'ProtectSystem=strict' "$UNIT_FILE" 2>/dev/null &&
    grep -Fxq 'ProtectHome=yes' "$UNIT_FILE" 2>/dev/null &&
    grep -Fxq 'ReadWritePaths=/var/lib/otserv' "$UNIT_FILE" 2>/dev/null &&
    grep -Fxq 'CapabilityBoundingSet=' "$UNIT_FILE" 2>/dev/null; then
    hardening_contract=ready
fi
assert_equal ready "$hardening_contract" "unit applies restart policy and filesystem hardening" || true

valid_preflight=failed
if run_preflight; then
    valid_preflight=ready
fi
assert_equal ready "$valid_preflight" "preflight accepts a complete ready installation" || true

executable_contract=failed
mv "$FIXTURE_ROOT/opt/otserv/current/tfs" "$FIXTURE_ROOT/opt/otserv/current/tfs.missing"
if ! run_preflight; then
    executable_contract=ready
fi
mv "$FIXTURE_ROOT/opt/otserv/current/tfs.missing" "$FIXTURE_ROOT/opt/otserv/current/tfs"
assert_equal ready "$executable_contract" "preflight rejects a missing executable" || true

configuration_contract=failed
mv "$FIXTURE_ROOT/etc/otserv/config.lua" "$FIXTURE_ROOT/etc/otserv/config.lua.missing"
missing_config_rejected=false
if ! run_preflight; then
    missing_config_rejected=true
fi
mv "$FIXTURE_ROOT/etc/otserv/config.lua.missing" "$FIXTURE_ROOT/etc/otserv/config.lua"
mv "$FIXTURE_ROOT/etc/otserv/otserv.env" "$FIXTURE_ROOT/etc/otserv/otserv.env.missing"
if [ "$missing_config_rejected" = true ] && ! run_preflight; then
    configuration_contract=ready
fi
mv "$FIXTURE_ROOT/etc/otserv/otserv.env.missing" "$FIXTURE_ROOT/etc/otserv/otserv.env"
assert_equal ready "$configuration_contract" "preflight rejects missing config or environment files" || true

datapack_contract=failed
mv "$FIXTURE_ROOT/opt/otserv/current/data/world/forgotten.otbm" "$FIXTURE_ROOT/opt/otserv/current/data/world/forgotten.otbm.missing"
missing_map_rejected=false
if ! run_preflight; then
    missing_map_rejected=true
fi
mv "$FIXTURE_ROOT/opt/otserv/current/data/world/forgotten.otbm.missing" "$FIXTURE_ROOT/opt/otserv/current/data/world/forgotten.otbm"
mv "$FIXTURE_ROOT/opt/otserv/current/key.pem" "$FIXTURE_ROOT/opt/otserv/current/key.pem.missing"
if [ "$missing_map_rejected" = true ] && ! run_preflight; then
    datapack_contract=ready
fi
mv "$FIXTURE_ROOT/opt/otserv/current/key.pem.missing" "$FIXTURE_ROOT/opt/otserv/current/key.pem"
assert_equal ready "$datapack_contract" "preflight rejects missing datapack or key material" || true

database_contract=failed
if DB_READY=false run_preflight; then
    database_contract=unexpected-success
else
    database_contract=ready
fi
assert_equal ready "$database_contract" "preflight rejects an unavailable database" || true

finish_tests
