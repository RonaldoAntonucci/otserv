#!/bin/sh

set -u

. ./tests/lib/assert.sh

expected_fork_url="https://github.com/RonaldoAntonucci/forgottenserver.git"
expected_upstream_url="https://github.com/otland/forgottenserver.git"
expected_server_sha="098641981400f8ff89959f427f0e8718d9dd22e2"
expected_client_fork_url="https://github.com/RonaldoAntonucci/otclient.git"
expected_client_upstream_url="https://github.com/opentibiabr/otclient.git"
expected_client_sha="99d43bd6559841ee684e35082da3ea9a360d0e16"

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

client_topology="$(git config -f .gitmodules --get submodule.client.path 2>/dev/null)|$(git config -f .gitmodules --get submodule.client.url 2>/dev/null)|$(git -C client remote get-url origin 2>/dev/null || true)|$(git -C client remote get-url upstream 2>/dev/null || true)"
assert_equal "client|$expected_client_fork_url|$expected_client_fork_url|$expected_client_upstream_url" "$client_topology" "client path, origin and upstream URLs are exact"

actual_client_sha=$(git ls-files --stage client 2>/dev/null | awk '$1 == "160000" { print $2 }')
assert_equal "$expected_client_sha" "$actual_client_sha" "client gitlink is pinned to OTClient 4.1"

compatibility_line=$(grep -F '| TFS 1.6 (13.10) |' client/README.md 2>/dev/null || true)
case "$compatibility_line" in
    *'| ✅ |') compatibility_result="compatible" ;;
    *) compatibility_result="missing" ;;
esac
assert_equal "compatible" "$compatibility_result" "pinned client declares TFS 1.6 protocol 13.10 compatibility"

cp .gitmodules "$scratch_root/wrong-client-owner.gitmodules" 2>/dev/null || :
sed -i 's#RonaldoAntonucci/otclient#AnotherOwner/otclient#' "$scratch_root/wrong-client-owner.gitmodules"
if GITMODULES_FILE="$scratch_root/wrong-client-owner.gitmodules" sh scripts/validate-repositories.sh >/dev/null 2>&1; then client_owner_result="accepted"; else client_owner_result="rejected"; fi

cp .gitmodules "$scratch_root/wrong-client-url.gitmodules" 2>/dev/null || :
sed -i 's#https://github.com/RonaldoAntonucci/otclient.git#git@github.com:RonaldoAntonucci/otclient.git#' "$scratch_root/wrong-client-url.gitmodules"
if GITMODULES_FILE="$scratch_root/wrong-client-url.gitmodules" sh scripts/validate-repositories.sh >/dev/null 2>&1; then client_url_result="accepted"; else client_url_result="rejected"; fi

if CLIENT_SHA_OVERRIDE="0000000000000000000000000000000000000000" sh scripts/validate-repositories.sh >/dev/null 2>&1; then client_sha_result="accepted"; else client_sha_result="rejected"; fi

: > "$scratch_root/missing-compatibility.md"
if CLIENT_README_FILE="$scratch_root/missing-compatibility.md" sh scripts/validate-repositories.sh >/dev/null 2>&1; then client_compatibility_result="accepted"; else client_compatibility_result="rejected"; fi

client_mutation_results="$client_owner_result|$client_url_result|$client_sha_result|$client_compatibility_result"
assert_equal "rejected|rejected|rejected|rejected" "$client_mutation_results" "wrong client owner, URL, SHA and compatibility are rejected"

finish_tests
