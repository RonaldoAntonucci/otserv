#!/bin/sh

set -u

ROOT_DIR=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
. "$ROOT_DIR/tests/lib/assert.sh"

PROJECT="otservtest$$"
UNHEALTHY_PROJECT="${PROJECT}unhealthy"
MISSING_MAP_PROJECT="${PROJECT}missingmap"
TEMP_DIR=$(mktemp -d "$ROOT_DIR/tests/.compose-test.XXXXXX")
ENV_FILE="$TEMP_DIR/development.env"
MISSING_SECRET_ENV="$TEMP_DIR/missing-secret.env"
UNHEALTHY_OVERRIDE="$TEMP_DIR/unhealthy.yaml"
MISSING_MAP_OVERRIDE="$TEMP_DIR/missing-map.yaml"
MISSING_MAP_FILE="$TEMP_DIR/missing.otbm"
DB_PASSWORD="otserv-test-$$-password"
MARIADB_IMAGE="mariadb:10.11@sha256:be981e4113326ada8d6004174dd09eeaefc03094037f811182a52d4f2e737350"

cleanup() {
    for cleanup_project in "$MISSING_MAP_PROJECT" "$UNHEALTHY_PROJECT" "$PROJECT"; do
        docker compose \
            --project-name "$cleanup_project" \
            --env-file "$ENV_FILE" \
            --file "$ROOT_DIR/compose.yaml" \
            down --volumes --remove-orphans >/dev/null 2>&1 || true
    done
    rm -rf "$TEMP_DIR"
}
trap cleanup EXIT HUP INT TERM

cat >"$ENV_FILE" <<EOF
MYSQL_HOST=db
MYSQL_PORT=3306
MYSQL_DATABASE=forgottenserver
MYSQL_USER=otserv
MYSQL_PASSWORD=$DB_PASSWORD
MYSQL_SOCK=
TFS_IP=127.0.0.1
TFS_LOGIN_PORT=7171
TFS_GAME_PORT=7172
TFS_STATUS_PORT=7171
TFS_MAP_NAME=forgotten
TFS_PROTOCOL=13.10
EOF

main_compose() {
    docker compose \
        --project-name "$PROJECT" \
        --env-file "$ENV_FILE" \
        --file "$ROOT_DIR/compose.yaml" \
        "$@"
}

db_query() {
    main_compose exec -T db mariadb \
        --protocol=tcp \
        --host=127.0.0.1 \
        --user=otserv \
        --password="$DB_PASSWORD" \
        forgottenserver \
        --batch --skip-column-names \
        --execute "$1" 2>/dev/null
}

wait_for_health() {
    container_id=$1
    attempts=0
    while [ "$attempts" -lt 90 ]; do
        if [ "$(docker inspect --format '{{if .State.Health}}{{.State.Health.Status}}{{end}}' "$container_id" 2>/dev/null)" = "healthy" ]; then
            return 0
        fi
        attempts=$((attempts + 1))
        sleep 1
    done
    return 1
}

wait_for_log() {
    attempts=0
    while [ "$attempts" -lt 90 ]; do
        if main_compose logs --no-color tfs 2>/dev/null | grep -Fq "$1"; then
            return 0
        fi
        attempts=$((attempts + 1))
        sleep 1
    done
    return 1
}

cd "$ROOT_DIR"

if [ ! -f compose.yaml ]; then
    printf 'FAIL compose.yaml does not exist\n' >&2
    exit 1
fi

services=$(main_compose config --services 2>/dev/null || true)
assert_equal "db
tfs" "$services" "valid development configuration defines only db and tfs" || true

config_json=$(main_compose config --format json 2>/dev/null | tr -d '[:space:]' || true)
image_contract=failed
if printf '%s' "$config_json" | grep -Fq "\"image\":\"$MARIADB_IMAGE\""; then
    image_contract=ready
fi
assert_equal ready "$image_contract" "database uses the pinned official MariaDB 10.11 image" || true

ordering_contract=failed
if printf '%s' "$config_json" | grep -Fq '"condition":"service_healthy"'; then
    ordering_contract=ready
fi
assert_equal ready "$ordering_contract" "TFS startup depends on a healthy database" || true

main_started=false
if main_compose up --detach --build; then
    main_started=true
fi

db_id=$(main_compose ps --quiet db 2>/dev/null || true)
tfs_id=$(main_compose ps --all --quiet tfs 2>/dev/null || true)

volume_contract=failed
if [ -n "$db_id" ]; then
    db_mount=$(docker inspect --format '{{range .Mounts}}{{if eq .Destination "/var/lib/mysql"}}{{.Type}}|{{.Name}}{{end}}{{end}}' "$db_id" 2>/dev/null || true)
    if [ "$PROJECT" != "otserv" ] && [ "$db_mount" = "volume|${PROJECT}_db_data" ]; then
        volume_contract=ready
    fi
fi
assert_equal ready "$volume_contract" "database uses an isolated named volume" || true

db_ports=invalid
if [ -n "$db_id" ]; then
    db_ports=$(docker inspect --format '{{len .HostConfig.PortBindings}}' "$db_id" 2>/dev/null || true)
fi
assert_equal 0 "$db_ports" "database publishes no host port" || true

tfs_ports=invalid
if [ -n "$tfs_id" ]; then
    tfs_ports=$(docker inspect --format '{{(index (index .HostConfig.PortBindings "7171/tcp") 0).HostPort}}|{{(index (index .HostConfig.PortBindings "7172/tcp") 0).HostPort}}|{{len .HostConfig.PortBindings}}' "$tfs_id" 2>/dev/null || true)
fi
assert_equal "7171|7172|2" "$tfs_ports" "TFS publishes only login and game ports" || true

db_health=failed
if [ "$main_started" = true ] && [ -n "$db_id" ] && wait_for_health "$db_id"; then
    db_health=healthy
fi
assert_equal healthy "$db_health" "database reaches healthy state" || true

schema_contract=failed
schema_tables=$(db_query "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = 'forgottenserver';" || true)
case "$schema_tables" in
    ''|*[!0-9]*) ;;
    *) [ "$schema_tables" -ge 20 ] && schema_contract=ready ;;
esac
assert_equal ready "$schema_contract" "empty volume imports the official schema" || true

initial_imports=$(main_compose logs --no-color db 2>/dev/null | grep -Fc '/docker-entrypoint-initdb.d/001-schema.sql' || true)
assert_equal 1 "$initial_imports" "schema initialization runs exactly once on first boot" || true

tfs_running=failed
if [ -n "$tfs_id" ] && wait_for_log 'Server Online!' && \
    [ "$(docker inspect --format '{{.State.Running}}' "$tfs_id" 2>/dev/null)" = "true" ]; then
    tfs_running=ready
fi
assert_equal ready "$tfs_running" "TFS remains running and reports online" || true

login_contract=failed
if main_compose exec -T db bash -ec 'timeout 5 bash -c "</dev/tcp/tfs/7171"' >/dev/null 2>&1; then
    login_contract=ready
fi
assert_equal ready "$login_contract" "login port accepts connections inside the stack" || true

game_contract=failed
if main_compose exec -T db bash -ec 'timeout 5 bash -c "</dev/tcp/tfs/7172"' >/dev/null 2>&1; then
    game_contract=ready
fi
assert_equal ready "$game_contract" "game port accepts connections inside the stack" || true

tfs_logs=$(main_compose logs --no-color tfs 2>/dev/null || true)
map_contract=failed
if printf '%s\n' "$tfs_logs" | grep -Fq '>> Loading map' && \
    printf '%s\n' "$tfs_logs" | grep -Fq 'Server Online!'; then
    map_contract=ready
fi
assert_equal ready "$map_contract" "official forgotten map loads before server readiness" || true

scripts_contract=failed
if printf '%s\n' "$tfs_logs" | grep -Fq '>> Loading script systems' && \
    printf '%s\n' "$tfs_logs" | grep -Fq '>> Loading lua scripts' && \
    ! printf '%s\n' "$tfs_logs" | grep -Fq '> ERROR:'; then
    scripts_contract=ready
fi
assert_equal ready "$scripts_contract" "official scripts load without fatal startup errors" || true

marker="marker-$$"
persistence_contract=failed
if db_query "CREATE TABLE IF NOT EXISTS bootstrap_test_marker (value VARCHAR(64) PRIMARY KEY); INSERT INTO bootstrap_test_marker VALUES ('$marker');" >/dev/null && \
    main_compose restart db >/dev/null && wait_for_health "$db_id"; then
    persisted_marker=$(db_query "SELECT value FROM bootstrap_test_marker WHERE value = '$marker';" || true)
    imports_after_restart=$(main_compose logs --no-color db 2>/dev/null | grep -Fc '/docker-entrypoint-initdb.d/001-schema.sql' || true)
    if [ "$persisted_marker" = "$marker" ] && [ "$imports_after_restart" = "1" ]; then
        persistence_contract=ready
    fi
fi
assert_equal ready "$persistence_contract" "database restart preserves data without reimporting schema" || true

grep -v '^MYSQL_PASSWORD=' "$ENV_FILE" >"$MISSING_SECRET_ENV"
missing_secret_contract=failed
if ! docker compose \
    --project-name "${PROJECT}missingsecret" \
    --env-file "$MISSING_SECRET_ENV" \
    --file compose.yaml \
    config >/dev/null 2>&1; then
    missing_secret_contract=ready
fi
assert_equal ready "$missing_secret_contract" "Compose rejects a missing database secret" || true

cat >"$UNHEALTHY_OVERRIDE" <<'EOF'
services:
  db:
    healthcheck:
      test: ["CMD", "false"]
      interval: 1s
      timeout: 1s
      retries: 2
      start_period: 0s
EOF
unhealthy_contract=failed
if ! docker compose \
    --project-name "$UNHEALTHY_PROJECT" \
    --env-file "$ENV_FILE" \
    --file compose.yaml \
    --file "$UNHEALTHY_OVERRIDE" \
    up --detach tfs >/dev/null 2>&1; then
    unhealthy_tfs_id=$(docker compose \
        --project-name "$UNHEALTHY_PROJECT" \
        --env-file "$ENV_FILE" \
        --file compose.yaml \
        --file "$UNHEALTHY_OVERRIDE" \
        ps --all --quiet tfs 2>/dev/null || true)
    if [ -z "$unhealthy_tfs_id" ] || \
        [ "$(docker inspect --format '{{.State.Running}}' "$unhealthy_tfs_id" 2>/dev/null)" != "true" ]; then
        unhealthy_contract=ready
    fi
fi
assert_equal ready "$unhealthy_contract" "unhealthy database prevents TFS startup" || true

printf 'invalid map fixture\n' >"$MISSING_MAP_FILE"
cat >"$MISSING_MAP_OVERRIDE" <<EOF
services:
  tfs:
    ports: !reset []
    volumes:
      - "$MISSING_MAP_FILE:/srv/data/world/forgotten.otbm:ro"
EOF
missing_map_contract=failed
docker compose \
    --project-name "$MISSING_MAP_PROJECT" \
    --env-file "$ENV_FILE" \
    --file compose.yaml \
    --file "$MISSING_MAP_OVERRIDE" \
    up --detach tfs >/dev/null 2>&1 || true
missing_map_attempts=0
while [ "$missing_map_attempts" -lt 30 ]; do
    missing_map_logs=$(docker compose \
        --project-name "$MISSING_MAP_PROJECT" \
        --env-file "$ENV_FILE" \
        --file compose.yaml \
        --file "$MISSING_MAP_OVERRIDE" \
        logs --no-color tfs 2>/dev/null || true)
    if printf '%s\n' "$missing_map_logs" | grep -Fq 'Failed to load map'; then
        missing_map_tfs_id=$(docker compose \
            --project-name "$MISSING_MAP_PROJECT" \
            --env-file "$ENV_FILE" \
            --file compose.yaml \
            --file "$MISSING_MAP_OVERRIDE" \
            ps --all --quiet tfs 2>/dev/null || true)
        if [ -n "$missing_map_tfs_id" ] && \
            [ "$(docker inspect --format '{{.State.Running}}' "$missing_map_tfs_id" 2>/dev/null)" != "true" ]; then
            missing_map_contract=ready
        fi
        break
    fi
    missing_map_attempts=$((missing_map_attempts + 1))
    sleep 1
done
assert_equal ready "$missing_map_contract" "missing official map is detected as a fatal startup error" || true

finish_tests
