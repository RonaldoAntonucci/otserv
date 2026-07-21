#!/bin/sh

set -u

. ./tests/lib/assert.sh

expected_fork_url="https://github.com/RonaldoAntonucci/forgottenserver.git"
expected_upstream_url="https://github.com/otland/forgottenserver.git"
expected_server_sha="098641981400f8ff89959f427f0e8718d9dd22e2"

scratch_root=$(mktemp -d)
trap 'rm -rf "$scratch_root"' EXIT

if sh scripts/validate-repositories.sh >/dev/null 2>&1; then
    validator_result="accepted"
else
    validator_result="rejected"
fi
assert_equal "accepted" "$validator_result" "valid repository topology is accepted"

gitmodule_contract="$(git config -f .gitmodules --get submodule.server.path 2>/dev/null)|$(git config -f .gitmodules --get submodule.server.url 2>/dev/null)"
assert_equal "server|$expected_fork_url" "$gitmodule_contract" "server gitmodule path and fork URL are exact"

actual_server_sha=$(git ls-files --stage server 2>/dev/null | awk '$1 == "160000" { print $2 }')
assert_equal "$expected_server_sha" "$actual_server_sha" "server gitlink is pinned to TFS v1.6"

actual_origin_url=$(git -C server remote get-url origin 2>/dev/null || true)
assert_equal "$expected_fork_url" "$actual_origin_url" "server origin points to the user fork"

actual_upstream_url=$(git -C server remote get-url upstream 2>/dev/null || true)
assert_equal "$expected_upstream_url" "$actual_upstream_url" "server upstream points to otland"

cp .gitmodules "$scratch_root/wrong-owner.gitmodules" 2>/dev/null || :
sed -i 's#RonaldoAntonucci#AnotherOwner#' "$scratch_root/wrong-owner.gitmodules"
if GITMODULES_FILE="$scratch_root/wrong-owner.gitmodules" sh scripts/validate-repositories.sh >/dev/null 2>&1; then
    wrong_owner_result="accepted"
else
    wrong_owner_result="rejected"
fi
assert_equal "rejected" "$wrong_owner_result" "wrong fork owner is rejected"

cp .gitmodules "$scratch_root/wrong-url.gitmodules" 2>/dev/null || :
sed -i 's#https://github.com/RonaldoAntonucci/forgottenserver.git#git@github.com:RonaldoAntonucci/forgottenserver.git#' "$scratch_root/wrong-url.gitmodules"
if GITMODULES_FILE="$scratch_root/wrong-url.gitmodules" sh scripts/validate-repositories.sh >/dev/null 2>&1; then
    wrong_url_result="accepted"
else
    wrong_url_result="rejected"
fi
assert_equal "rejected" "$wrong_url_result" "noncanonical fork URL is rejected"

if SERVER_SHA_OVERRIDE="0000000000000000000000000000000000000000" sh scripts/validate-repositories.sh >/dev/null 2>&1; then
    wrong_sha_result="accepted"
else
    wrong_sha_result="rejected"
fi
assert_equal "rejected" "$wrong_sha_result" "wrong server SHA is rejected"

finish_tests
