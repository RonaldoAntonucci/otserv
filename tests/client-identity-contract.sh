#!/bin/sh

set -u

ROOT_DIR=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
. "$ROOT_DIR/tests/lib/assert.sh"

PROVISIONER="$ROOT_DIR/scripts/provision-client-test-identity.sh"
MAP_PROBE="$ROOT_DIR/scripts/probe-otbm-tile.py"
SCRATCH_DIR=$(mktemp -d)
trap 'rm -rf "$SCRATCH_DIR"' EXIT HUP INT TERM

contract=false
if sh -n "$PROVISIONER" && python3 "$MAP_PROBE" --help >/dev/null &&
    grep -Fq 'set -eu' "$PROVISIONER" &&
    grep -Fq -- '-o StrictHostKeyChecking=yes' "$PROVISIONER" &&
    grep -Fq -- '--protocol=socket' "$PROVISIONER" &&
    ! grep -Fq 'set -x' "$PROVISIONER" &&
    ! grep -Fq 'echo "$provision_password"' "$PROVISIONER"; then
    contract=true
fi
assert_equal true "$contract" "provisioner syntax and trust boundaries are strict" || true

OTSERV_PROVISION_SOURCE_ONLY=true
export OTSERV_PROVISION_SOURCE_ONLY
# shellcheck source=/dev/null
. "$PROVISIONER"

secret_file="$SCRATCH_DIR/client-test.env"
contract=false
if initialize_secret_file "$secret_file" >/dev/null 2>&1 &&
    validate_secret_file "$secret_file" &&
    [ "$(file_mode "$secret_file")" = 600 ] &&
    test_password=$(secret_value OTC_PASSWORD "$secret_file") &&
    [ "${#test_password}" -eq 32 ]; then
    contract=true
fi
unset test_password
assert_equal true "$contract" "secret initialization creates one valid mode-0600 fixture" || true

contract=false
if ! initialize_secret_file "$secret_file" >/dev/null 2>&1; then
    contract=true
fi
assert_equal true "$contract" "secret initialization refuses to overwrite credentials" || true

chmod 0644 "$secret_file"
contract=false
if ! validate_secret_file "$secret_file" >/dev/null 2>&1; then
    contract=true
fi
assert_equal true "$contract" "unsafe secret permissions are rejected" || true
chmod 0600 "$secret_file"

symlink_file="$SCRATCH_DIR/symlink.env"
ln -s "$secret_file" "$symlink_file"
contract=false
if ! validate_secret_file "$symlink_file" >/dev/null 2>&1; then
    contract=true
fi
assert_equal true "$contract" "symlink secret files are rejected" || true

map_output=$(python3 "$MAP_PROBE" \
    "$ROOT_DIR/server/data/world/forgotten.otbm" \
    "$ROOT_DIR/server/data/items/items.otb" 95 117 7) || map_output=failed
expected_map='map_sha256=92ffae05e4da12b3d6603283e7a4356f39c4735dd9b996306c62de5c72549327
tile=95,117,7
has_ground=1
static_blocker_count=0
no_logout=0
item_ids=407,5591'
assert_equal "$expected_map" "$map_output" "exact town-1 temple tile is present and placeable" || true

contract=false
if ! python3 "$MAP_PROBE" \
    "$ROOT_DIR/server/data/world/forgotten.otbm" \
    "$ROOT_DIR/server/data/items/items.otb" 0 0 0 >/dev/null 2>&1; then
    contract=true
fi
assert_equal true "$contract" "absent temple coordinates fail closed" || true

fake_digest=0123456789abcdef0123456789abcdef01234567
sql=$(write_provision_sql "$fake_digest") || sql=failed
contract=false
if printf '%s\n' "$sql" | grep -Fq "GET_LOCK('otserv:client-test-identity', 30)" &&
    printf '%s\n' "$sql" | grep -Fq 'START TRANSACTION;' &&
    printf '%s\n' "$sql" | grep -Fq 'PROVISION_PREFLIGHT_FAILED' &&
    printf '%s\n' "$sql" | grep -Fq 'INSERT INTO accounts (name, password)' &&
    printf '%s\n' "$sql" | grep -Fq 'INSERT INTO players (name, account_id, town_id, posx, posy, posz)' &&
    printf '%s\n' "$sql" | grep -Fq 'PROVISION_VERIFICATION_FAILED' &&
    printf '%s\n' "$sql" | grep -Fq 'COMMIT;' &&
    printf '%s\n' "$sql" | grep -Fq "DO RELEASE_LOCK('otserv:client-test-identity')" &&
    ! printf '%s\n' "$sql" | grep -Fq 'REPLACE INTO' &&
    ! printf '%s\n' "$sql" | grep -Fq 'INSERT IGNORE'; then
    contract=true
fi
assert_equal true "$contract" "SQL is serialized transactional idempotent and fail-closed" || true

contract=false
if ! write_provision_sql invalid-digest >/dev/null 2>&1; then
    contract=true
fi
assert_equal true "$contract" "malformed password digests are rejected before SSH" || true

finish_tests
