#!/bin/sh

ASSERT_PASSED=0
ASSERT_FAILED=0

assert_equal() {
    expected=$1
    actual=$2
    label=$3

    if [ "$expected" = "$actual" ]; then
        ASSERT_PASSED=$((ASSERT_PASSED + 1))
        printf 'PASS %s\n' "$label"
        return 0
    fi

    ASSERT_FAILED=$((ASSERT_FAILED + 1))
    printf 'FAIL %s: expected [%s], got [%s]\n' "$label" "$expected" "$actual" >&2
    return 1
}

finish_tests() {
    printf '%s passed, %s failed\n' "$ASSERT_PASSED" "$ASSERT_FAILED"
    [ "$ASSERT_FAILED" -eq 0 ]
}
