#!/bin/sh

set -u

ROOT_DIR=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
. "$ROOT_DIR/tests/lib/assert.sh"

SMOKE_SCRIPT="$ROOT_DIR/scripts/smoke-vps.sh"
EXPECTED_REVISION=098641981400f8ff89959f427f0e8718d9dd22e2
SCRATCH_DIR=$(mktemp -d)
FIXTURE_ROOT="$SCRATCH_DIR/root"
FIXTURE_STATE="$SCRATCH_DIR/state"
MOCK_BIN="$SCRATCH_DIR/bin"
SECRET_SENTINEL=DO_NOT_PRINT_THIS_SECRET

cleanup() {
    rm -rf "$SCRATCH_DIR"
}
trap cleanup EXIT HUP INT TERM

mkdir -p \
    "$FIXTURE_ROOT/etc/otserv" \
    "$FIXTURE_ROOT/opt/otserv/current/data/world" \
    "$FIXTURE_ROOT/run/systemd/system" \
    "$FIXTURE_STATE" \
    "$MOCK_BIN"

cat >"$FIXTURE_ROOT/etc/os-release" <<'EOF'
ID=ubuntu
VERSION_ID="24.04"
EOF
cat >"$FIXTURE_ROOT/etc/otserv/otserv.env" <<EOF
MYSQL_HOST=127.0.0.1
MYSQL_PORT=3306
MYSQL_DATABASE=forgottenserver
MYSQL_USER=otserv
MYSQL_PASSWORD=$SECRET_SENTINEL
TFS_IP=127.0.0.1
TFS_LOGIN_PORT=7171
TFS_GAME_PORT=7172
TFS_STATUS_PORT=7171
TFS_MAP_NAME=forgotten
TFS_PROTOCOL=13.10
EOF
printf '%s\n' "$EXPECTED_REVISION" >"$FIXTURE_ROOT/opt/otserv/current/REVISION"
printf '#!/bin/sh\nexit 0\n' >"$FIXTURE_ROOT/opt/otserv/current/tfs"
chmod 0755 "$FIXTURE_ROOT/opt/otserv/current/tfs"
printf 'fixture map\n' >"$FIXTURE_ROOT/opt/otserv/current/data/world/forgotten.otbm"

cat >"$MOCK_BIN/systemctl" <<'EOF'
#!/bin/sh
set -eu
case "$*" in
    is-system-running*)
        [ ! -e "$FIXTURE_STATE/fail-systemd" ] || exit 1
        printf 'running\n'
        ;;
    'is-active --quiet mariadb.service')
        [ ! -e "$FIXTURE_STATE/fail-mariadb" ]
        ;;
    'is-active --quiet tfs.service')
        [ ! -e "$FIXTURE_STATE/fail-tfs" ]
        ;;
    *) exit 2 ;;
esac
EOF

cat >"$MOCK_BIN/ss" <<'EOF'
#!/bin/sh
set -eu
if [ -e "$FIXTURE_STATE/exposed-database" ]; then
    printf 'LISTEN 0 80 0.0.0.0:3306 0.0.0.0:*\n'
else
    printf 'LISTEN 0 80 127.0.0.1:3306 0.0.0.0:*\n'
fi
[ -e "$FIXTURE_STATE/missing-ports" ] || {
    printf 'LISTEN 0 80 0.0.0.0:7171 0.0.0.0:*\n'
    printf 'LISTEN 0 80 0.0.0.0:7172 0.0.0.0:*\n'
}
EOF

cat >"$MOCK_BIN/mariadb" <<'EOF'
#!/bin/sh
set -eu
case "$*" in
    *information_schema.tables*)
        [ -e "$FIXTURE_STATE/missing-schema" ] && printf '0\n' || printf '1\n'
        ;;
    *bootstrap_persistence_marker*)
        [ -e "$FIXTURE_STATE/missing-marker" ] || printf 'vps-bootstrap-v1\n'
        ;;
    *) exit 2 ;;
esac
EOF

cat >"$MOCK_BIN/journalctl" <<'EOF'
#!/bin/sh
set -eu
[ -e "$FIXTURE_STATE/missing-load-log" ] || printf '>> Loaded all modules, server starting up...\n'
[ -e "$FIXTURE_STATE/fatal-journal" ] && printf '> ERROR: Failed to load map\n'
exit 0
EOF

chmod 0755 "$MOCK_BIN/systemctl" "$MOCK_BIN/ss" "$MOCK_BIN/mariadb" "$MOCK_BIN/journalctl"

run_smoke() {
    output_file=$1
    OTSERV_SMOKE_FIXTURE_ROOT="$FIXTURE_ROOT" \
    FIXTURE_STATE="$FIXTURE_STATE" \
    PATH="$MOCK_BIN:$PATH" \
        sh "$SMOKE_SCRIPT" >"$output_file" 2>&1
}

contract=false
if [ -f "$SMOKE_SCRIPT" ] &&
    grep -Fq 'test-vps:' "$ROOT_DIR/Makefile" &&
    grep -Fq 'sh scripts/smoke-vps.sh' "$ROOT_DIR/Makefile" &&
    ! awk '/^test-vps:/{found=1; next} found && /^\t/{print; exit}' "$ROOT_DIR/Makefile" | grep -Fq 'test-placeholder'; then
    contract=true
fi
assert_equal true "$contract" "make test-vps delegates to the native smoke script" || true

contract=false
if [ -f "$SMOKE_SCRIPT" ]; then
    sed -i 's/^ID=ubuntu$/ID=debian/' "$FIXTURE_ROOT/etc/os-release"
    if ! run_smoke "$SCRATCH_DIR/non-vps.out"; then contract=true; fi
    sed -i 's/^ID=debian$/ID=ubuntu/' "$FIXTURE_ROOT/etc/os-release"
fi
assert_equal true "$contract" "smoke rejects a non-VPS platform fixture" || true

contract=false
if [ -f "$SMOKE_SCRIPT" ]; then
    : >"$FIXTURE_STATE/fail-systemd"
    if ! run_smoke "$SCRATCH_DIR/non-systemd.out"; then contract=true; fi
    rm -f "$FIXTURE_STATE/fail-systemd"
fi
assert_equal true "$contract" "smoke rejects a host without operational systemd" || true

contract=false
if [ -f "$SMOKE_SCRIPT" ] && run_smoke "$SCRATCH_DIR/valid.out" &&
    grep -Fxq '14 passed, 0 failed' "$SCRATCH_DIR/valid.out" &&
    [ "$(grep -c '^PASS ' "$SCRATCH_DIR/valid.out")" -eq 14 ] &&
    ! grep -Fq "$SECRET_SENTINEL" "$SCRATCH_DIR/valid.out"; then
    contract=true
fi
assert_equal true "$contract" "healthy fixture reports fourteen passes without secrets" || true

contract=false
if [ -f "$SMOKE_SCRIPT" ]; then
    printf '%s\n' 0000000000000000000000000000000000000000 >"$FIXTURE_ROOT/opt/otserv/current/REVISION"
    if ! run_smoke "$SCRATCH_DIR/revision.out"; then contract=true; fi
    printf '%s\n' "$EXPECTED_REVISION" >"$FIXTURE_ROOT/opt/otserv/current/REVISION"
fi
assert_equal true "$contract" "smoke rejects the wrong active TFS revision" || true

contract=false
if [ -f "$SMOKE_SCRIPT" ]; then
    chmod 0644 "$FIXTURE_ROOT/opt/otserv/current/tfs"
    if ! run_smoke "$SCRATCH_DIR/executable.out"; then contract=true; fi
    chmod 0755 "$FIXTURE_ROOT/opt/otserv/current/tfs"
fi
assert_equal true "$contract" "smoke rejects a missing or non-executable TFS binary" || true

contract=false
if [ -f "$SMOKE_SCRIPT" ]; then
    : >"$FIXTURE_STATE/fail-mariadb"
    inactive_rejected=false
    if ! run_smoke "$SCRATCH_DIR/mariadb-inactive.out"; then inactive_rejected=true; fi
    rm -f "$FIXTURE_STATE/fail-mariadb"
    : >"$FIXTURE_STATE/exposed-database"
    if [ "$inactive_rejected" = true ] && ! run_smoke "$SCRATCH_DIR/mariadb-exposed.out"; then contract=true; fi
    rm -f "$FIXTURE_STATE/exposed-database"
fi
assert_equal true "$contract" "smoke rejects inactive or publicly listening MariaDB" || true

contract=false
if [ -f "$SMOKE_SCRIPT" ]; then
    : >"$FIXTURE_STATE/missing-schema"
    if ! run_smoke "$SCRATCH_DIR/schema.out"; then contract=true; fi
    rm -f "$FIXTURE_STATE/missing-schema"
fi
assert_equal true "$contract" "smoke rejects a missing TFS schema" || true

contract=false
if [ -f "$SMOKE_SCRIPT" ]; then
    : >"$FIXTURE_STATE/missing-marker"
    if ! run_smoke "$SCRATCH_DIR/marker.out"; then contract=true; fi
    rm -f "$FIXTURE_STATE/missing-marker"
fi
assert_equal true "$contract" "smoke rejects a missing persistence marker" || true

contract=false
if [ -f "$SMOKE_SCRIPT" ]; then
    : >"$FIXTURE_STATE/fail-tfs"
    inactive_rejected=false
    if ! run_smoke "$SCRATCH_DIR/tfs-inactive.out"; then inactive_rejected=true; fi
    rm -f "$FIXTURE_STATE/fail-tfs"
    : >"$FIXTURE_STATE/missing-ports"
    if [ "$inactive_rejected" = true ] && ! run_smoke "$SCRATCH_DIR/ports.out"; then contract=true; fi
    rm -f "$FIXTURE_STATE/missing-ports"
fi
assert_equal true "$contract" "smoke rejects inactive TFS or missing protocol ports" || true

contract=false
if [ -f "$SMOKE_SCRIPT" ]; then
    mv "$FIXTURE_ROOT/opt/otserv/current/data/world/forgotten.otbm" "$SCRATCH_DIR/forgotten.otbm"
    missing_map_rejected=false
    if ! run_smoke "$SCRATCH_DIR/map.out"; then missing_map_rejected=true; fi
    mv "$SCRATCH_DIR/forgotten.otbm" "$FIXTURE_ROOT/opt/otserv/current/data/world/forgotten.otbm"
    : >"$FIXTURE_STATE/missing-load-log"
    if [ "$missing_map_rejected" = true ] && ! run_smoke "$SCRATCH_DIR/load-log.out"; then contract=true; fi
    rm -f "$FIXTURE_STATE/missing-load-log"
fi
assert_equal true "$contract" "smoke rejects a missing map or datapack load evidence" || true

contract=false
if [ -f "$SMOKE_SCRIPT" ]; then
    : >"$FIXTURE_STATE/fatal-journal"
    if ! run_smoke "$SCRATCH_DIR/fatal.out"; then contract=true; fi
    rm -f "$FIXTURE_STATE/fatal-journal"
fi
assert_equal true "$contract" "smoke rejects fatal entries from the current boot journal" || true

finish_tests
