#!/bin/sh

set -u

ROOT_DIR=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
. "$ROOT_DIR/tests/lib/assert.sh"

INSTALLER="$ROOT_DIR/deploy/vps/install.sh"
EXPECTED_REVISION=098641981400f8ff89959f427f0e8718d9dd22e2
SCRATCH_DIR=$(mktemp -d)
MOCK_BIN="$SCRATCH_DIR/bin"
CALL_LOG="$SCRATCH_DIR/calls.log"

cleanup() {
    rm -rf "$SCRATCH_DIR"
}
trap cleanup EXIT HUP INT TERM

mkdir -p "$MOCK_BIN"
chmod 0755 "$SCRATCH_DIR"
: >"$CALL_LOG"

installer_loaded=false
if [ -f "$INSTALLER" ]; then
    OTSERV_INSTALLER_SOURCE_ONLY=true
    export OTSERV_INSTALLER_SOURCE_ONLY
    # shellcheck source=/dev/null
    if . "$INSTALLER"; then
        installer_loaded=true
    fi
fi

contract=false
if [ -f "$INSTALLER" ] && sh -n "$INSTALLER" &&
    grep -Fxq 'set -eu' "$INSTALLER" &&
    grep -Fq 'flock ' "$INSTALLER" &&
    ! grep -Fq 'rm -rf /' "$INSTALLER" &&
    ! grep -Eq 'rm -rf.*\$\{?(HOME|CODEX_HOME)' "$INSTALLER" &&
    ! grep -Eq '(echo|printf).*MYSQL_PASSWORD' "$INSTALLER"; then
    contract=true
fi
assert_equal true "$contract" "installer uses strict shell, locking and bounded cleanup" || true

contract=false
if [ "$installer_loaded" = true ] && command -v validate_root >/dev/null 2>&1 &&
    ! validate_root 1000 >/dev/null 2>&1; then
    contract=true
fi
assert_equal true "$contract" "installer rejects a non-root invocation before mutation" || true

write_os_release() {
    os_id=$1
    os_version=$2
    cat >"$SCRATCH_DIR/os-release" <<EOF
ID=$os_id
VERSION_ID="$os_version"
EOF
}

contract=false
write_os_release debian 24.04
if [ "$installer_loaded" = true ] && command -v validate_platform >/dev/null 2>&1 &&
    ! validate_platform "$SCRATCH_DIR/os-release" amd64 >/dev/null 2>&1; then
    contract=true
fi
assert_equal true "$contract" "installer rejects non-Ubuntu systems" || true

contract=false
write_os_release ubuntu 22.04
if [ "$installer_loaded" = true ] && command -v validate_platform >/dev/null 2>&1 &&
    ! validate_platform "$SCRATCH_DIR/os-release" amd64 >/dev/null 2>&1; then
    contract=true
fi
assert_equal true "$contract" "installer rejects Ubuntu releases other than 24.04" || true

contract=false
write_os_release ubuntu 24.04
if [ "$installer_loaded" = true ] && command -v validate_platform >/dev/null 2>&1 &&
    ! validate_platform "$SCRATCH_DIR/os-release" arm64 >/dev/null 2>&1 &&
    validate_platform "$SCRATCH_DIR/os-release" amd64 >/dev/null 2>&1; then
    contract=true
fi
assert_equal true "$contract" "installer accepts only the validated amd64 architecture" || true

expected_packages='build-essential
ca-certificates
cmake
git
libboost-iostreams-dev
libboost-json-dev
libboost-locale-dev
libboost-system-dev
libfmt-dev
libluajit-5.1-dev
libmariadb-dev
libmariadb-dev-compat
libpugixml-dev
libssl-dev
mariadb-client
mariadb-server
ninja-build
util-linux'
actual_packages=missing
if [ "$installer_loaded" = true ] && command -v package_list >/dev/null 2>&1; then
    actual_packages=$(package_list | sort)
fi
assert_equal "$expected_packages" "$actual_packages" "package list matches TFS and MariaDB 10.11 requirements" || true

contract=false
if [ "$installer_loaded" = true ] && [ "${TFS_REVISION:-missing}" = "$EXPECTED_REVISION" ] &&
    command -v verify_revision >/dev/null 2>&1 &&
    verify_revision "$ROOT_DIR/server" "$EXPECTED_REVISION" >/dev/null 2>&1 &&
    ! verify_revision "$ROOT_DIR/server" 0000000000000000000000000000000000000000 >/dev/null 2>&1; then
    contract=true
fi
assert_equal true "$contract" "installer verifies the pinned TFS revision before building" || true

contract=false
if [ -f "$INSTALLER" ] &&
    grep -Fq -- '-DBUILD_TESTING=OFF' "$INSTALLER" &&
    grep -Fq -- '-DSKIP_GIT=ON' "$INSTALLER" &&
    grep -Fq -- '-DUSE_LUAJIT=ON' "$INSTALLER" &&
    grep -Fq -- '--config RelWithDebInfo --parallel 1' "$INSTALLER"; then
    contract=true
fi
assert_equal true "$contract" "native TFS build uses the approved flags and one job" || true

cat >"$MOCK_BIN/cmake" <<'EOF'
#!/bin/sh
set -eu
printf '%s\n' "$*" >>"$CALL_LOG"
if [ "$1" = "--build" ]; then
    [ "${MOCK_BUILD_FAIL:-false}" != true ] || exit 42
    mkdir -p "$2/RelWithDebInfo"
    printf '#!/bin/sh\nexit 0\n' >"$2/RelWithDebInfo/tfs"
    chmod 0755 "$2/RelWithDebInfo/tfs"
fi
EOF
chmod 0755 "$MOCK_BIN/cmake"

contract=false
release_root="$SCRATCH_DIR/releases-success"
current_link="$SCRATCH_DIR/current-success"
if [ "$installer_loaded" = true ] && command -v deploy_release >/dev/null 2>&1 &&
    PATH="$MOCK_BIN:$PATH" CALL_LOG="$CALL_LOG" deploy_release \
        "$ROOT_DIR/server" "$release_root" "$current_link" "$EXPECTED_REVISION" \
        "$ROOT_DIR/deploy/vps/config-loader.lua" >/dev/null 2>&1 &&
    [ "$(readlink "$current_link")" = "$release_root/$EXPECTED_REVISION" ] &&
    [ -x "$release_root/$EXPECTED_REVISION/tfs" ] &&
    [ -r "$release_root/$EXPECTED_REVISION/config.lua" ] &&
    [ -r "$release_root/$EXPECTED_REVISION/data/world/forgotten.otbm" ] &&
    runuser -u otserv -- sh -c 'cd "$1" && test -x tfs && test -r config.lua && test -r key.pem && test -r data/world/forgotten.otbm' \
        sh "$release_root/$EXPECTED_REVISION" &&
    [ "$(cat "$release_root/$EXPECTED_REVISION/REVISION")" = "$EXPECTED_REVISION" ]; then
    contract=true
fi
assert_equal true "$contract" "successful build activates a complete immutable release" || true

contract=false
release_root="$SCRATCH_DIR/releases-failure"
current_link="$SCRATCH_DIR/current-failure"
old_release="$release_root/old"
db_marker="$SCRATCH_DIR/database-marker"
mkdir -p "$old_release"
ln -s "$old_release" "$current_link"
printf 'keep-me\n' >"$db_marker"
if [ "$installer_loaded" = true ] && command -v deploy_release >/dev/null 2>&1 &&
    ! PATH="$MOCK_BIN:$PATH" CALL_LOG="$CALL_LOG" MOCK_BUILD_FAIL=true deploy_release \
        "$ROOT_DIR/server" "$release_root" "$current_link" "$EXPECTED_REVISION" \
        "$ROOT_DIR/deploy/vps/config-loader.lua" >/dev/null 2>&1 &&
    [ "$(readlink "$current_link")" = "$old_release" ] &&
    [ "$(cat "$db_marker")" = keep-me ] &&
    [ ! -e "$release_root/$EXPECTED_REVISION" ]; then
    contract=true
fi
assert_equal true "$contract" "failed build preserves active release and database marker" || true

contract=false
release_root="$SCRATCH_DIR/releases-existing"
current_link="$SCRATCH_DIR/current-existing"
existing_release="$release_root/$EXPECTED_REVISION"
mkdir -p "$existing_release/data/world"
printf '#!/bin/sh\nexit 0\n' >"$existing_release/tfs"
chmod 0755 "$existing_release/tfs"
cp "$ROOT_DIR/deploy/vps/config-loader.lua" "$existing_release/config.lua"
cp "$ROOT_DIR/server/key.pem" "$existing_release/key.pem"
cp "$ROOT_DIR/server/data/world/forgotten.otbm" "$existing_release/data/world/forgotten.otbm"
printf '%s\n' "$EXPECTED_REVISION" >"$existing_release/REVISION"
chmod -R go= "$existing_release"
: >"$CALL_LOG"
if [ "$installer_loaded" = true ] && command -v deploy_release >/dev/null 2>&1 &&
    PATH="$MOCK_BIN:$PATH" CALL_LOG="$CALL_LOG" deploy_release \
        "$ROOT_DIR/server" "$release_root" "$current_link" "$EXPECTED_REVISION" \
        "$ROOT_DIR/deploy/vps/config-loader.lua" >/dev/null 2>&1 &&
    [ ! -s "$CALL_LOG" ] && [ "$(readlink "$current_link")" = "$existing_release" ] &&
    runuser -u otserv -- sh -c 'cd "$1" && test -x tfs && test -r config.lua && test -r key.pem && test -r data/world/forgotten.otbm' \
        sh "$existing_release"; then
    contract=true
fi
assert_equal true "$contract" "valid existing release is reused without recompilation" || true

valid_env="$SCRATCH_DIR/real.env"
cat >"$valid_env" <<'EOF'
MYSQL_HOST=127.0.0.1
MYSQL_PORT=3306
MYSQL_DATABASE=forgottenserver
MYSQL_USER=otserv
MYSQL_PASSWORD=test-only-secret
TFS_IP=127.0.0.1
TFS_LOGIN_PORT=7171
TFS_GAME_PORT=7172
TFS_STATUS_PORT=7171
TFS_MAP_NAME=forgotten
TFS_PROTOCOL=13.10
EOF
placeholder_env="$SCRATCH_DIR/placeholder.env"
sed 's/test-only-secret/CHANGE_ME_PASSWORD/' "$valid_env" >"$placeholder_env"
blank_env="$SCRATCH_DIR/blank.env"
sed 's/MYSQL_PASSWORD=test-only-secret/MYSQL_PASSWORD=/' "$valid_env" >"$blank_env"
example_env="$SCRATCH_DIR/otserv.env.example"
cp "$valid_env" "$example_env"

contract=false
if [ "$installer_loaded" = true ] && command -v validate_environment_source >/dev/null 2>&1 &&
    validate_environment_source "$valid_env" >/dev/null 2>&1 &&
    ! validate_environment_source "$placeholder_env" >/dev/null 2>&1 &&
    ! validate_environment_source "$blank_env" >/dev/null 2>&1 &&
    ! validate_environment_source "$example_env" >/dev/null 2>&1; then
    contract=true
fi
assert_equal true "$contract" "environment source must be real, complete and placeholder-free" || true

contract=false
semantic_contract=true
if [ "$installer_loaded" = true ] && command -v validate_vps_configuration >/dev/null 2>&1 &&
    validate_vps_configuration "$valid_env" "$ROOT_DIR/scripts/validate-config.sh" >/dev/null 2>&1; then
    for invalid_case in \
        MYSQL_PORT:3307 \
        MYSQL_DATABASE:wrong_database \
        MYSQL_USER:wrong_user \
        TFS_LOGIN_PORT:not-a-port \
        TFS_GAME_PORT:7173 \
        TFS_STATUS_PORT:7172 \
        TFS_MAP_NAME:missing-map \
        TFS_PROTOCOL:12.00
    do
        invalid_key=${invalid_case%%:*}
        invalid_value=${invalid_case#*:}
        invalid_env="$SCRATCH_DIR/invalid-${invalid_key}.env"
        awk -F= -v key="$invalid_key" -v value="$invalid_value" '
            $1 == key { print key "=" value; next }
            { print }
        ' "$valid_env" >"$invalid_env"
        if validate_vps_configuration "$invalid_env" "$ROOT_DIR/scripts/validate-config.sh" >/dev/null 2>&1; then
            semantic_contract=false
        fi
    done

    validation_line=$(grep -nF 'validate_vps_configuration "$environment_source" "$project_root/scripts/validate-config.sh"' "$INSTALLER" | tail -n 1 | cut -d: -f1)
    lock_line=$(grep -nF 'exec 9>/run/lock/otserv-install.lock' "$INSTALLER" | cut -d: -f1)
    if [ "$semantic_contract" = true ] && [ -n "$validation_line" ] && [ -n "$lock_line" ] &&
        [ "$validation_line" -lt "$lock_line" ]; then
        contract=true
    fi
fi
assert_equal true "$contract" "installer enforces canonical VPS semantics before mutation" || true

contract=false
installed_env="$SCRATCH_DIR/etc/otserv.env"
if [ "$installer_loaded" = true ] && command -v install_environment >/dev/null 2>&1 &&
    install_environment "$valid_env" "$installed_env" >/dev/null 2>&1 &&
    cmp -s "$valid_env" "$installed_env" &&
    [ "$(stat -c '%U:%G' "$installed_env")" = root:root ] &&
    [ "$(stat -c '%a' "$installed_env")" = 600 ]; then
    contract=true
fi
assert_equal true "$contract" "first install stores the environment as root-only" || true

contract=false
preserved_env="$SCRATCH_DIR/preserved.env"
preserved_config="$SCRATCH_DIR/config.lua"
printf 'MYSQL_PASSWORD=existing-secret\n' >"$preserved_env"
chmod 0600 "$preserved_env"
printf 'serverName = "Existing"\n' >"$preserved_config"
chmod 0640 "$preserved_config"
if [ "$installer_loaded" = true ] &&
    command -v install_environment >/dev/null 2>&1 &&
    command -v install_configuration >/dev/null 2>&1 &&
    install_environment "$valid_env" "$preserved_env" >/dev/null 2>&1 &&
    install_configuration "$ROOT_DIR/deploy/vps/config.lua" "$preserved_config" root >/dev/null 2>&1 &&
    [ "$(cat "$preserved_env")" = 'MYSQL_PASSWORD=existing-secret' ] &&
    [ "$(cat "$preserved_config")" = 'serverName = "Existing"' ]; then
    contract=true
fi
assert_equal true "$contract" "rerun preserves existing secrets and server configuration" || true

contract=false
if [ -f "$INSTALLER" ] &&
    grep -Fq 'CREATE DATABASE IF NOT EXISTS' "$INSTALLER" &&
    grep -Fq 'CREATE USER IF NOT EXISTS' "$INSTALLER" &&
    grep -Fq 'GRANT ALL PRIVILEGES' "$INSTALLER" &&
    ! grep -Fq 'ALTER USER' "$INSTALLER"; then
    contract=true
fi
assert_equal true "$contract" "database and user initialization is repeatable without resetting passwords" || true

cat >"$MOCK_BIN/mariadb" <<'EOF'
#!/bin/sh
set -eu
printf '%s\n' "$*" >>"$CALL_LOG"
case "$*" in
    *information_schema.tables*) printf '1\n' ;;
esac
EOF
chmod 0755 "$MOCK_BIN/mariadb"

contract=false
schema_marker="$SCRATCH_DIR/schema-marker"
printf 'existing-data\n' >"$schema_marker"
: >"$CALL_LOG"
if [ "$installer_loaded" = true ] && command -v initialize_database >/dev/null 2>&1 &&
    PATH="$MOCK_BIN:$PATH" CALL_LOG="$CALL_LOG" initialize_database \
        "$valid_env" "$ROOT_DIR/server/schema.sql" >/dev/null 2>&1 &&
    [ "$(cat "$schema_marker")" = existing-data ] &&
    [ "$(grep -c -- '--database=forgottenserver' "$CALL_LOG" || true)" -eq 0 ]; then
    contract=true
fi
assert_equal true "$contract" "existing schema sentinel prevents destructive re-import" || true

cat >"$MOCK_BIN/systemctl" <<'EOF'
#!/bin/sh
set -eu
printf '%s\n' "$*" >>"$CALL_LOG"
if [ "$*" = "is-active --quiet tfs.service" ] && [ "${MOCK_TFS_INACTIVE:-false}" = true ]; then
    exit 3
fi
EOF
chmod 0755 "$MOCK_BIN/systemctl"

contract=false
: >"$CALL_LOG"
if [ "$installer_loaded" = true ] && command -v start_tfs_service >/dev/null 2>&1 &&
    PATH="$MOCK_BIN:$PATH" CALL_LOG="$CALL_LOG" start_tfs_service >/dev/null 2>&1 &&
    [ "$(cat "$CALL_LOG")" = "enable --now tfs.service
is-active --quiet tfs.service" ]; then
    : >"$CALL_LOG"
    start_line=$(grep -nF 'start_tfs_service' "$INSTALLER" | tail -n 1 | cut -d: -f1)
    ready_line=$(grep -nF "printf 'Installation ready." "$INSTALLER" | cut -d: -f1)
    if ! PATH="$MOCK_BIN:$PATH" CALL_LOG="$CALL_LOG" MOCK_TFS_INACTIVE=true \
        start_tfs_service >/dev/null 2>&1 &&
        [ -n "$start_line" ] && [ -n "$ready_line" ] && [ "$start_line" -lt "$ready_line" ]; then
        contract=true
    fi
fi
assert_equal true "$contract" "installer requires active TFS before declaring readiness" || true

finish_tests
