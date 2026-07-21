#!/bin/sh

set -u

repository_root=${REPOSITORY_ROOT:-.}
gitmodules_file=${GITMODULES_FILE:-$repository_root/.gitmodules}
expected_path="server"
expected_fork_url="https://github.com/RonaldoAntonucci/forgottenserver.git"
expected_upstream_url="https://github.com/otland/forgottenserver.git"
expected_server_sha="098641981400f8ff89959f427f0e8718d9dd22e2"
failed=0

check_equal() {
    expected=$1
    actual=$2
    label=$3

    if [ "$expected" = "$actual" ]; then
        printf 'PASS %s\n' "$label"
        return
    fi

    printf 'FAIL %s: expected [%s], got [%s]\n' "$label" "$expected" "$actual" >&2
    failed=$((failed + 1))
}

gitmodule_path=$(git config -f "$gitmodules_file" --get submodule.server.path 2>/dev/null || true)
gitmodule_url=$(git config -f "$gitmodules_file" --get submodule.server.url 2>/dev/null || true)
server_sha=${SERVER_SHA_OVERRIDE:-$(git -C "$repository_root" ls-files --stage server 2>/dev/null | awk '$1 == "160000" { print $2 }')}
origin_url=$(git -C "$repository_root/server" remote get-url origin 2>/dev/null || true)
upstream_url=$(git -C "$repository_root/server" remote get-url upstream 2>/dev/null || true)

check_equal "$expected_path" "$gitmodule_path" "server gitmodule path"
check_equal "$expected_fork_url" "$gitmodule_url" "server gitmodule URL"
check_equal "$expected_server_sha" "$server_sha" "server pinned SHA"
check_equal "$expected_fork_url" "$origin_url" "server origin URL"
check_equal "$expected_upstream_url" "$upstream_url" "server upstream URL"

[ "$failed" -eq 0 ]
