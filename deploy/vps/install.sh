#!/bin/sh

set -eu

TFS_REVISION=098641981400f8ff89959f427f0e8718d9dd22e2
EXPECTED_UBUNTU_VERSION=24.04
EXPECTED_ARCHITECTURE=amd64

fail() {
    printf 'Installation failed: %s\n' "$1" >&2
    return 1
}

validate_root() {
    [ "$1" -eq 0 ] || fail "run this installer as root"
}

os_release_value() {
    key=$1
    file=$2

    sed -n "s/^${key}=//p" "$file" | tail -n 1 | sed 's/^"//; s/"$//'
}

validate_platform() {
    os_release_file=$1
    architecture=$2

    [ -r "$os_release_file" ] || {
        fail "cannot read $os_release_file"
        return 1
    }
    [ "$(os_release_value ID "$os_release_file")" = ubuntu ] || {
        fail "only Ubuntu is supported"
        return 1
    }
    [ "$(os_release_value VERSION_ID "$os_release_file")" = "$EXPECTED_UBUNTU_VERSION" ] || {
        fail "only Ubuntu $EXPECTED_UBUNTU_VERSION is supported"
        return 1
    }
    [ "$architecture" = "$EXPECTED_ARCHITECTURE" ] || {
        fail "only the $EXPECTED_ARCHITECTURE architecture is supported"
        return 1
    }
}

package_list() {
    cat <<'EOF'
build-essential
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
util-linux
EOF
}

verify_revision() {
    source_directory=$1
    expected_revision=$2

    [ -d "$source_directory/.git" ] || [ -f "$source_directory/.git" ] ||
        fail "TFS source is not a Git checkout: $source_directory"
    actual_revision=$(git -C "$source_directory" rev-parse HEAD 2>/dev/null) ||
        fail "cannot read the TFS revision"
    [ "$actual_revision" = "$expected_revision" ] ||
        fail "TFS revision does not match the approved pin"
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
    ' "$file"
}

validate_environment_source() {
    source_file=$1

    [ -f "$source_file" ] || {
        fail "environment source is not a regular file"
        return 1
    }
    case "$(basename "$source_file")" in
        *.example)
            fail "an example environment file cannot be installed"
            return 1
            ;;
    esac

    if grep -Ev '^(#.*|[[:space:]]*|[A-Z][A-Z0-9_]*=.*)$' "$source_file" >/dev/null; then
        fail "environment source contains an invalid line"
        return 1
    fi
    if grep -Eiq 'CHANGE_ME|REPLACE_ME|YOUR_[A-Z_]*' "$source_file"; then
        fail "environment source still contains placeholders"
        return 1
    fi

    for required_key in \
        MYSQL_HOST MYSQL_PORT MYSQL_DATABASE MYSQL_USER MYSQL_PASSWORD \
        TFS_IP TFS_LOGIN_PORT TFS_GAME_PORT TFS_STATUS_PORT TFS_MAP_NAME TFS_PROTOCOL
    do
        required_value=$(environment_value "$required_key" "$source_file") ||
            {
                fail "environment key is missing or duplicated: $required_key"
                return 1
            }
        [ -n "$required_value" ] || {
            fail "environment key is blank: $required_key"
            return 1
        }
    done

    [ "$(environment_value MYSQL_HOST "$source_file")" = 127.0.0.1 ] || {
        fail "native MariaDB must use MYSQL_HOST=127.0.0.1"
        return 1
    }
}

validate_existing_environment() {
    destination=$1

    [ "$(stat -c '%U:%G' "$destination")" = root:root ] ||
        fail "existing environment must be owned by root:root"
    [ "$(stat -c '%a' "$destination")" = 600 ] ||
        fail "existing environment must have mode 0600"
}

install_environment() {
    source_file=$1
    destination=$2

    if [ -e "$destination" ]; then
        validate_existing_environment "$destination"
        return 0
    fi

    validate_environment_source "$source_file"
    install -d -o root -g root -m 0755 "$(dirname "$destination")"
    install -o root -g root -m 0600 "$source_file" "$destination"
}

install_configuration() {
    source_file=$1
    destination=$2
    destination_group=$3

    [ -e "$destination" ] && return 0
    install -o root -g "$destination_group" -m 0640 "$source_file" "$destination"
}

validate_identifier() {
    identifier=$1
    label=$2

    printf '%s\n' "$identifier" | grep -Eq '^[A-Za-z0-9_]+$' ||
        fail "$label contains unsupported characters"
}

sql_escape_literal() {
    sed "s/\\\\/\\\\\\\\/g; s/'/''/g"
}

initialize_database() {
    environment_file=$1
    schema_file=$2

    database_name=$(environment_value MYSQL_DATABASE "$environment_file") ||
        fail "cannot read MYSQL_DATABASE"
    database_user=$(environment_value MYSQL_USER "$environment_file") ||
        fail "cannot read MYSQL_USER"
    database_password=$(environment_value MYSQL_PASSWORD "$environment_file") ||
        fail "cannot read MYSQL_PASSWORD"

    validate_identifier "$database_name" MYSQL_DATABASE
    validate_identifier "$database_user" MYSQL_USER
    escaped_password=$(printf '%s' "$database_password" | sql_escape_literal)

    mariadb --protocol=socket --user=root <<EOF
CREATE DATABASE IF NOT EXISTS \`$database_name\` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE USER IF NOT EXISTS '$database_user'@'127.0.0.1' IDENTIFIED BY '$escaped_password';
GRANT ALL PRIVILEGES ON \`$database_name\`.* TO '$database_user'@'127.0.0.1';
FLUSH PRIVILEGES;
EOF

    schema_present=$(mariadb \
        --protocol=socket \
        --user=root \
        --batch \
        --skip-column-names \
        --execute="SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = '$database_name' AND table_name = 'server_config'" \
    ) || fail "cannot inspect the database schema"

    case "$schema_present" in
        0)
            [ -r "$schema_file" ] || fail "schema file is unreadable"
            mariadb --protocol=socket --user=root --database="$database_name" <"$schema_file"
            ;;
        1) ;;
        *) fail "unexpected server_config sentinel count" ;;
    esac
}

validate_release() {
    release_directory=$1
    expected_revision=$2

    [ -d "$release_directory" ] &&
        [ -x "$release_directory/tfs" ] &&
        [ -r "$release_directory/config.lua" ] &&
        [ -r "$release_directory/key.pem" ] &&
        [ -d "$release_directory/data" ] &&
        [ -r "$release_directory/data/world/forgotten.otbm" ] &&
        [ -r "$release_directory/REVISION" ] &&
        [ "$(cat "$release_directory/REVISION")" = "$expected_revision" ]
}

apply_release_permissions() {
    release_directory=$1

    chown -R root:otserv "$release_directory"
    chmod -R u=rwX,g=rX,o= "$release_directory"
}

cleanup_temporary_directory() {
    release_root=$1
    candidate=$2

    case "$candidate" in
        "$release_root"/.build-*|"$release_root"/.release-*) rm -rf -- "$candidate" ;;
        *) fail "refusing to remove an unbounded temporary path" ;;
    esac
}

activate_release() {
    release_directory=$1
    current_link=$2
    next_link="${current_link}.new.$$"

    rm -f -- "$next_link"
    ln -s "$release_directory" "$next_link"
    mv -Tf "$next_link" "$current_link"
}

deploy_release() {
    source_directory=$1
    release_root=$2
    current_link=$3
    expected_revision=$4
    config_loader=$5
    target_release="$release_root/$expected_revision"

    verify_revision "$source_directory" "$expected_revision" || return 1
    mkdir -p "$release_root"

    if validate_release "$target_release" "$expected_revision"; then
        apply_release_permissions "$target_release"
        activate_release "$target_release" "$current_link"
        return 0
    fi
    [ ! -e "$target_release" ] ||
        fail "an incomplete immutable release already exists: $target_release"

    build_directory=$(mktemp -d "$release_root/.build-${expected_revision}.XXXXXX") ||
        fail "cannot create build staging directory"
    release_stage=$(mktemp -d "$release_root/.release-${expected_revision}.XXXXXX") || {
        cleanup_temporary_directory "$release_root" "$build_directory"
        fail "cannot create release staging directory"
        return 1
    }

    if ! cmake \
        -S "$source_directory" \
        -B "$build_directory" \
        -G 'Ninja Multi-Config' \
        -DBUILD_TESTING=OFF \
        -DSKIP_GIT=ON \
        -DUSE_LUAJIT=ON; then
        cleanup_temporary_directory "$release_root" "$build_directory"
        cleanup_temporary_directory "$release_root" "$release_stage"
        return 1
    fi

    if ! cmake --build "$build_directory" --config RelWithDebInfo --parallel 1; then
        cleanup_temporary_directory "$release_root" "$build_directory"
        cleanup_temporary_directory "$release_root" "$release_stage"
        return 1
    fi

    install -m 0755 "$build_directory/RelWithDebInfo/tfs" "$release_stage/tfs"
    cp -a "$source_directory/data" "$release_stage/data"
    install -m 0644 "$source_directory/key.pem" "$release_stage/key.pem"
    install -m 0644 "$config_loader" "$release_stage/config.lua"
    printf '%s\n' "$expected_revision" >"$release_stage/REVISION"

    apply_release_permissions "$release_stage"

    if ! validate_release "$release_stage" "$expected_revision"; then
        cleanup_temporary_directory "$release_root" "$build_directory"
        cleanup_temporary_directory "$release_root" "$release_stage"
        fail "staged release is incomplete"
        return 1
    fi

    mv "$release_stage" "$target_release"
    cleanup_temporary_directory "$release_root" "$build_directory"
    activate_release "$target_release" "$current_link"
}

install_packages() {
    apt-get update
    # Word splitting is intentional: package_list emits one validated package per line.
    # shellcheck disable=SC2046
    apt-get install --yes --no-install-recommends $(package_list)
}

provision_identity() {
    getent group otserv >/dev/null 2>&1 || groupadd --system otserv
    id otserv >/dev/null 2>&1 ||
        useradd --system --gid otserv --home-dir /var/lib/otserv --shell /usr/sbin/nologin otserv
}

install_service_bundle() {
    project_root=$1

    install -d -o root -g root -m 0755 /usr/local/libexec/otserv /etc/systemd/system
    install -o root -g root -m 0755 "$project_root/deploy/vps/preflight.sh" /usr/local/libexec/otserv/preflight.sh
    install -o root -g root -m 0644 "$project_root/deploy/vps/paths.env" /etc/otserv/paths.env
    install -o root -g root -m 0644 "$project_root/deploy/vps/tfs.service" /etc/systemd/system/tfs.service
}

main() {
    [ "$#" -eq 1 ] || fail "usage: $0 /path/to/real-otserv.env"
    environment_source=$1
    script_directory=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
    project_root=$(CDPATH= cd -- "$script_directory/../.." && pwd)
    server_source="$project_root/server"

    # All eligibility and input checks happen before the installer creates or changes anything.
    validate_root "$(id -u)"
    validate_platform /etc/os-release "$(dpkg --print-architecture)"
    validate_environment_source "$environment_source"
    verify_revision "$server_source" "$TFS_REVISION"

    exec 9>/run/lock/otserv-install.lock
    flock -n 9 || fail "another installer process is already running"

    install_packages
    provision_identity
    systemctl enable --now mariadb.service
    mariadb --version | grep -Fq 'Distrib 10.11' ||
        fail "Ubuntu did not install the validated MariaDB 10.11 series"

    install -d -o root -g root -m 0755 /opt/otserv /opt/otserv/releases /etc/otserv
    install -d -o otserv -g otserv -m 0750 /var/lib/otserv
    install_environment "$environment_source" /etc/otserv/otserv.env
    install_configuration "$project_root/deploy/vps/config.lua" /etc/otserv/config.lua otserv
    install_service_bundle "$project_root"

    initialize_database /etc/otserv/otserv.env "$server_source/schema.sql"
    deploy_release \
        "$server_source" \
        /opt/otserv/releases \
        /opt/otserv/current \
        "$TFS_REVISION" \
        "$project_root/deploy/vps/config-loader.lua"

    systemctl daemon-reload
    systemctl enable tfs.service
    printf 'Installation ready. Run: systemctl start tfs.service\n'
}

if [ "${OTSERV_INSTALLER_SOURCE_ONLY:-false}" != true ]; then
    main "$@"
fi
