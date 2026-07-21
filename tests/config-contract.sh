#!/bin/sh

set -u

. ./tests/lib/assert.sh

scratch_root=$(mktemp -d)
trap 'rm -rf "$scratch_root"' EXIT

value_from() {
    key=$1
    file=$2
    awk -F= -v key="$key" '$1 == key { sub(/^[^=]*=/, ""); print; exit }' "$file" 2>/dev/null
}

write_valid_env() {
    file=$1
    mysql_host=$2
    tfs_ip=$3

    {
        printf 'MYSQL_HOST=%s\n' "$mysql_host"
        printf 'MYSQL_PORT=3306\n'
        printf 'MYSQL_DATABASE=forgottenserver\n'
        printf 'MYSQL_USER=otserv\n'
        printf 'MYSQL_PASSWORD=contract-test-secret\n'
        printf 'MYSQL_SOCK=\n'
        printf 'TFS_IP=%s\n' "$tfs_ip"
        printf 'TFS_LOGIN_PORT=7171\n'
        printf 'TFS_GAME_PORT=7172\n'
        printf 'TFS_STATUS_PORT=7171\n'
        printf 'TFS_MAP_NAME=forgotten\n'
        printf 'TFS_PROTOCOL=13.10\n'
    } > "$file"
}

validator_result() {
    target=$1
    file=$2

    if sh scripts/validate-config.sh "$target" "$file" >/dev/null 2>&1; then
        printf 'accepted'
    else
        printf 'rejected'
    fi
}

if git check-ignore --quiet env/development.env && git check-ignore --quiet deploy/vps/otserv.env; then
    runtime_secret_rules="ignored"
else
    runtime_secret_rules="exposed"
fi
example_secret_contract="$(value_from MYSQL_PASSWORD env/development.env.example)|$(value_from MYSQL_PASSWORD deploy/vps/otserv.env.example)|$runtime_secret_rules"
assert_equal "CHANGE_ME_LOCAL_PASSWORD|CHANGE_ME_VPS_PASSWORD|ignored" "$example_secret_contract" "examples use placeholders and runtime secrets are ignored"

assert_equal "db" "$(value_from MYSQL_HOST env/development.env.example)" "development database host is the Compose service"

assert_equal "127.0.0.1" "$(value_from MYSQL_HOST deploy/vps/otserv.env.example)" "VPS database host is loopback"

database_contract="$(value_from MYSQL_PORT env/development.env.example)|$(value_from MYSQL_DATABASE env/development.env.example)|$(value_from MYSQL_USER env/development.env.example)|$(value_from MYSQL_PORT deploy/vps/otserv.env.example)|$(value_from MYSQL_DATABASE deploy/vps/otserv.env.example)|$(value_from MYSQL_USER deploy/vps/otserv.env.example)"
assert_equal "3306|forgottenserver|otserv|3306|forgottenserver|otserv" "$database_contract" "database port, name and user are exact in both examples"

port_contract="$(value_from TFS_LOGIN_PORT env/development.env.example)|$(value_from TFS_GAME_PORT env/development.env.example)|$(value_from TFS_STATUS_PORT env/development.env.example)|$(value_from TFS_LOGIN_PORT deploy/vps/otserv.env.example)|$(value_from TFS_GAME_PORT deploy/vps/otserv.env.example)|$(value_from TFS_STATUS_PORT deploy/vps/otserv.env.example)"
assert_equal "7171|7172|7171|7171|7172|7171" "$port_contract" "TFS ports are exact in both examples"

map_contract="$(value_from TFS_MAP_NAME env/development.env.example)|$(value_from TFS_MAP_NAME deploy/vps/otserv.env.example)"
assert_equal "forgotten|forgotten" "$map_contract" "official map is selected in both examples"

protocol_contract="$(value_from TFS_PROTOCOL env/development.env.example)|$(value_from TFS_PROTOCOL deploy/vps/otserv.env.example)"
assert_equal "13.10|13.10" "$protocol_contract" "protocol 13.10 is declared in both examples"

if cmp -s docker/config.lua deploy/vps/config.lua &&
    grep -Fq 'os.getenv("TFS_LOGIN_PORT") or "7171"' docker/config.lua &&
    grep -Fq 'os.getenv("TFS_GAME_PORT") or "7172"' docker/config.lua &&
    grep -Fq 'os.getenv("TFS_MAP_NAME") or "forgotten"' docker/config.lua; then
    shared_config_result="shared"
else
    shared_config_result="different"
fi
assert_equal "shared" "$shared_config_result" "development and VPS use the same environment-driven config"

write_valid_env "$scratch_root/development.env" "db" "127.0.0.1"
assert_equal "accepted" "$(validator_result development "$scratch_root/development.env")" "valid development configuration is accepted"

write_valid_env "$scratch_root/vps.env" "127.0.0.1" "game.example.invalid"
assert_equal "accepted" "$(validator_result vps "$scratch_root/vps.env")" "valid VPS configuration is accepted"

write_valid_env "$scratch_root/missing.env" "db" "127.0.0.1"
sed -i '/^MYSQL_DATABASE=/d' "$scratch_root/missing.env"
assert_equal "rejected" "$(validator_result development "$scratch_root/missing.env")" "missing required variable is rejected"

write_valid_env "$scratch_root/blank-secret.env" "db" "127.0.0.1"
sed -i 's/^MYSQL_PASSWORD=.*/MYSQL_PASSWORD=/' "$scratch_root/blank-secret.env"
assert_equal "rejected" "$(validator_result development "$scratch_root/blank-secret.env")" "blank database password is rejected"

invalid_port_results=""
for mutation in 'MYSQL_PORT=0' 'TFS_LOGIN_PORT=7172' 'TFS_GAME_PORT=65536' 'TFS_STATUS_PORT=abc'; do
    write_valid_env "$scratch_root/invalid-port.env" "db" "127.0.0.1"
    key=${mutation%%=*}
    sed -i "s/^$key=.*/$mutation/" "$scratch_root/invalid-port.env"
    result=$(validator_result development "$scratch_root/invalid-port.env")
    invalid_port_results="${invalid_port_results}${invalid_port_results:+|}$result"
done
assert_equal "rejected|rejected|rejected|rejected" "$invalid_port_results" "invalid or unexpected ports are rejected"

write_valid_env "$scratch_root/wrong-map.env" "db" "127.0.0.1"
sed -i 's/^TFS_MAP_NAME=.*/TFS_MAP_NAME=wrong-map/' "$scratch_root/wrong-map.env"
wrong_map_result=$(validator_result development "$scratch_root/wrong-map.env")

tracked_root="$scratch_root/tracked-repository"
mkdir -p "$tracked_root"
git -C "$tracked_root" init --quiet
write_valid_env "$tracked_root/development.env" "db" "127.0.0.1"
git -C "$tracked_root" add development.env
if REPOSITORY_ROOT="$tracked_root" sh scripts/validate-config.sh development "$tracked_root/development.env" >/dev/null 2>&1; then tracked_secret_result="accepted"; else tracked_secret_result="rejected"; fi
assert_equal "rejected|rejected" "$wrong_map_result|$tracked_secret_result" "wrong map and tracked secret file are rejected"

finish_tests
