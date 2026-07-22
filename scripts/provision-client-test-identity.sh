#!/bin/sh

set -eu

PROJECT_ROOT=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
SECRET_FILE="$PROJECT_ROOT/env/client-test.env"
MAP_FILE="$PROJECT_ROOT/server/data/world/forgotten.otbm"
ITEMS_FILE="$PROJECT_ROOT/server/data/items/items.otb"
MAP_PROBE="$PROJECT_ROOT/scripts/probe-otbm-tile.py"
REMOTE=root@srv1826871.hstgr.cloud
EXPECTED_TFS_REVISION=098641981400f8ff89959f427f0e8718d9dd22e2
EXPECTED_MAP_SHA256=92ffae05e4da12b3d6603283e7a4356f39c4735dd9b996306c62de5c72549327
ACCOUNT_NAME=otserv-smoke
CHARACTER_NAME='Docker Scout'
TEMPLE_X=95
TEMPLE_Y=117
TEMPLE_Z=7

file_mode() {
    mode_file=$1
    if stat -f '%Lp' "$mode_file" >/dev/null 2>&1; then
        stat -f '%Lp' "$mode_file"
    else
        stat -c '%a' "$mode_file"
    fi
}

file_owner() {
    owner_file=$1
    if stat -f '%Su' "$owner_file" >/dev/null 2>&1; then
        stat -f '%Su' "$owner_file"
    else
        stat -c '%U' "$owner_file"
    fi
}

secret_value() {
    secret_value_key=$1
    secret_value_file=$2
    awk -v wanted="$secret_value_key" '
        index($0, wanted "=") == 1 {
            print substr($0, length(wanted) + 2)
            count++
        }
        END { if (count != 1) exit 1 }
    ' "$secret_value_file"
}

validate_secret_file() {
    validate_file=$1
    [ -f "$validate_file" ] && [ ! -L "$validate_file" ] || return 1
    [ "$(file_mode "$validate_file")" = 600 ] || return 1
    [ "$(file_owner "$validate_file")" = "$(id -un)" ] || return 1
    [ "$(wc -l <"$validate_file" | tr -d ' ')" = 3 ] || return 1
    ! grep -q "$(printf '\r')" "$validate_file" || return 1
    [ "$(sed -n '1s/=.*//p' "$validate_file")" = OTC_ACCOUNT_NAME ] || return 1
    [ "$(sed -n '2s/=.*//p' "$validate_file")" = OTC_CHARACTER_NAME ] || return 1
    [ "$(sed -n '3s/=.*//p' "$validate_file")" = OTC_PASSWORD ] || return 1

    validate_account=$(secret_value OTC_ACCOUNT_NAME "$validate_file") || return 1
    validate_character=$(secret_value OTC_CHARACTER_NAME "$validate_file") || return 1
    validate_password=$(secret_value OTC_PASSWORD "$validate_file") || return 1
    [ "$validate_account" = "$ACCOUNT_NAME" ] || return 1
    [ "$validate_character" = "$CHARACTER_NAME" ] || return 1
    [ "${#validate_password}" -eq 32 ] || return 1
    case "$validate_password" in
        *[!A-Za-z0-9_-]*) return 1 ;;
    esac
    unset validate_account validate_character validate_password
}

generate_password() {
    LC_ALL=C tr -dc 'A-Za-z0-9_-' </dev/urandom | dd bs=32 count=1 2>/dev/null
}

initialize_secret_file() {
    initialize_file=$1
    initialize_directory=$(dirname "$initialize_file")
    [ ! -e "$initialize_file" ] && [ ! -L "$initialize_file" ] || {
        printf 'ERROR: secret file already exists; refusing to overwrite it\n' >&2
        return 1
    }
    [ -d "$initialize_directory" ] && [ ! -L "$initialize_directory" ] || {
        printf 'ERROR: secret directory is missing or unsafe\n' >&2
        return 1
    }

    umask 077
    initialize_temporary=$(mktemp "$initialize_directory/.client-test.env.XXXXXX")
    trap 'rm -f "$initialize_temporary"' EXIT HUP INT TERM
    initialize_password=$(generate_password)
    {
        printf 'OTC_ACCOUNT_NAME=%s\n' "$ACCOUNT_NAME"
        printf 'OTC_CHARACTER_NAME=%s\n' "$CHARACTER_NAME"
        printf 'OTC_PASSWORD=%s\n' "$initialize_password"
    } >"$initialize_temporary"
    chmod 0600 "$initialize_temporary"
    validate_secret_file "$initialize_temporary"
    mv "$initialize_temporary" "$initialize_file"
    trap - EXIT HUP INT TERM
    unset initialize_password
    printf 'PASS secret file created at env/client-test.env with mode 0600\n'
}

sha1_digest() {
    sha1_value=$1
    if command -v sha1sum >/dev/null 2>&1; then
        printf '%s' "$sha1_value" | sha1sum | awk '{print $1}'
    else
        printf '%s' "$sha1_value" | shasum -a 1 | awk '{print $1}'
    fi
}

write_provision_sql() {
    sql_digest=$1
    case "$sql_digest" in
        *[!0-9a-f]*|'') return 1 ;;
    esac
    [ "${#sql_digest}" -eq 40 ] || return 1

    cat <<'SQL'
SET @account_name = 'otserv-smoke';
SET @character_name = 'Docker Scout';
SQL
    printf "SET @password_sha1 = '%s';\n" "$sql_digest"
    cat <<'SQL'
SELECT GET_LOCK('otserv:client-test-identity', 30) INTO @lock_acquired;
SET @guard = IF(@lock_acquired = 1, 'DO 0',
  "SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'PROVISION_LOCK_FAILED'");
PREPARE guard_statement FROM @guard;
EXECUTE guard_statement;
DEALLOCATE PREPARE guard_statement;

START TRANSACTION;
SELECT COUNT(*), COALESCE(MIN(id), 0), COALESCE(MIN(password = @password_sha1), 0)
  INTO @account_count, @account_id, @digest_match
  FROM accounts WHERE name = @account_name;
SELECT COUNT(*) INTO @character_name_count
  FROM players WHERE name = @character_name;
SELECT COUNT(*) INTO @active_player_count
  FROM players WHERE account_id = @account_id AND deletion = 0;
SELECT COUNT(*) INTO @linked_character_count
  FROM players
  WHERE account_id = @account_id AND name = @character_name AND deletion = 0;
SELECT COUNT(*) INTO @town_valid
  FROM towns WHERE id = 1 AND posx = 95 AND posy = 117 AND posz = 7;
SELECT COUNT(*) INTO @schema_valid
  FROM server_config WHERE config = 'db_version' AND value = '37';
SELECT @@GLOBAL.general_log = 0 INTO @general_log_disabled;

SET @create_mode = (@account_count = 0 AND @character_name_count = 0);
SET @noop_mode = (
  @account_count = 1 AND @digest_match = 1 AND
  @character_name_count = 1 AND @active_player_count = 1 AND
  @linked_character_count = 1
);
SET @preflight_valid = (
  @town_valid = 1 AND @schema_valid = 1 AND @general_log_disabled = 1 AND
  (@create_mode = 1 OR @noop_mode = 1)
);
SET @guard = IF(@preflight_valid = 1, 'DO 0',
  "SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'PROVISION_PREFLIGHT_FAILED'");
PREPARE guard_statement FROM @guard;
EXECUTE guard_statement;
DEALLOCATE PREPARE guard_statement;

INSERT INTO accounts (name, password)
SELECT @account_name, @password_sha1 WHERE @create_mode = 1;
SET @account_id = IF(@create_mode = 1, LAST_INSERT_ID(), @account_id);
INSERT INTO players (name, account_id, town_id, posx, posy, posz)
SELECT @character_name, @account_id, 1, 0, 0, 0 WHERE @create_mode = 1;

SELECT COUNT(*), COALESCE(MIN(password = @password_sha1), 0)
  INTO @verified_account_count, @verified_digest_match
  FROM accounts WHERE id = @account_id AND name = @account_name;
SELECT COUNT(*) INTO @verified_active_count
  FROM players WHERE account_id = @account_id AND deletion = 0;
SELECT COUNT(*) INTO @verified_link_count
  FROM players
  WHERE account_id = @account_id AND name = @character_name AND deletion = 0;
SELECT COUNT(*) INTO @verified_fixture_count
  FROM players
  WHERE account_id = @account_id AND name = @character_name AND deletion = 0
    AND town_id = 1 AND posx = 0 AND posy = 0 AND posz = 0;
SET @verification_valid = (
  @verified_account_count = 1 AND @verified_digest_match = 1 AND
  @verified_active_count = 1 AND @verified_link_count = 1 AND
  (@create_mode = 0 OR @verified_fixture_count = 1)
);
SET @guard = IF(@verification_valid = 1, 'DO 0',
  "SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'PROVISION_VERIFICATION_FAILED'");
PREPARE guard_statement FROM @guard;
EXECUTE guard_statement;
DEALLOCATE PREPARE guard_statement;

COMMIT;
SELECT CONCAT(
  'result=', IF(@create_mode = 1, 'created', 'noop'),
  '|account_count=', @verified_account_count,
  '|digest_match=', @verified_digest_match,
  '|active_player_count=', @verified_active_count,
  '|link_match=', @verified_link_count,
  '|initial_fixture_match=', IF(@create_mode = 1, @verified_fixture_count, 'preserved'),
  '|town_match=', @town_valid
);
DO RELEASE_LOCK('otserv:client-test-identity');
SQL
}

run_map_preflight() {
    map_output=$(python3 "$MAP_PROBE" "$MAP_FILE" "$ITEMS_FILE" "$TEMPLE_X" "$TEMPLE_Y" "$TEMPLE_Z")
    printf '%s\n' "$map_output" | grep -Fxq "map_sha256=$EXPECTED_MAP_SHA256"
    printf '%s\n' "$map_output" | grep -Fxq 'has_ground=1'
    printf '%s\n' "$map_output" | grep -Fxq 'static_blocker_count=0'
    printf '%s\n' "$map_output" | grep -Fxq 'no_logout=0'
    printf 'PASS exact deployed-map temple tile is placeable\n'
}

provision_identity() {
    validate_secret_file "$SECRET_FILE" || {
        printf 'ERROR: env/client-test.env is missing or unsafe; run with --init-secret first\n' >&2
        return 1
    }
    run_map_preflight
    provision_password=$(secret_value OTC_PASSWORD "$SECRET_FILE")
    provision_digest=$(sha1_digest "$provision_password")
    unset provision_password

    write_provision_sql "$provision_digest" | ssh \
        -o BatchMode=yes \
        -o StrictHostKeyChecking=yes \
        "$REMOTE" \
        "set -eu; test \"\$(cat /opt/otserv/current/REVISION)\" = '$EXPECTED_TFS_REVISION'; test \"\$(sha256sum /opt/otserv/current/data/world/forgotten.otbm | cut -d' ' -f1)\" = '$EXPECTED_MAP_SHA256'; test \"\$(systemctl is-active tfs.service)\" = active; test \"\$(systemctl is-active mariadb.service)\" = active; exec mariadb --protocol=socket --database=forgottenserver --batch --skip-column-names --abort-source-on-error"
    unset provision_digest
}

main() {
    case "${1:-}" in
        --init-secret)
            [ "$#" -eq 1 ] || return 2
            initialize_secret_file "$SECRET_FILE"
            ;;
        '')
            provision_identity
            ;;
        *)
            printf 'Usage: %s [--init-secret]\n' "$0" >&2
            return 2
            ;;
    esac
}

if [ "${OTSERV_PROVISION_SOURCE_ONLY:-false}" != true ]; then
    main "$@"
fi
