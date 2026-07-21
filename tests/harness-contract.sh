#!/bin/sh

passed=0
failed=0

record_result() {
    label=$1
    shift

    if "$@"; then
        passed=$((passed + 1))
        printf 'PASS %s\n' "$label"
    else
        failed=$((failed + 1))
        printf 'FAIL %s\n' "$label" >&2
    fi
}

docker_gate_is_pinned_and_read_only() {
    grep -q '^FROM ubuntu:24.04@sha256:4fbb8e6a8395de5a7550b33509421a2bafbc0aab6c06ba2cef9ebffbc7092d90$' docker/test.Dockerfile &&
        grep -q '^test-static:$' Makefile &&
        grep -Fq 'docker build --file docker/test.Dockerfile --tag $(TEST_IMAGE) .' Makefile &&
        grep -Fq 'docker run --rm --volume "$(CURDIR):/workspace:ro" $(TEST_IMAGE)' Makefile
}

deliberate_failure_is_detected() {
    output=$(sh -c '. ./tests/lib/assert.sh; assert_equal "expected" "actual" "deliberate failure"; finish_tests' 2>&1)
    status=$?

    [ "$status" -ne 0 ] &&
        printf '%s\n' "$output" | grep -q '^FAIL deliberate failure: expected \[expected\], got \[actual\]$' &&
        printf '%s\n' "$output" | grep -q '^0 passed, 1 failed$'
}

mixed_summary_is_explicit() {
    output=$(sh -c '. ./tests/lib/assert.sh; assert_equal "one" "one" "passing"; assert_equal "two" "wrong" "failing"; finish_tests' 2>&1)
    status=$?

    [ "$status" -ne 0 ] &&
        [ "$(printf '%s\n' "$output" | tail -n 1)" = "1 passed, 1 failed" ]
}

placeholder_target_fails() {
    output=$(make --no-print-directory --silent test-placeholder SUITE=scratch 2>&1)
    status=$?

    [ "$status" -eq 2 ] &&
        printf '%s\n' "$output" | grep -q '^ERROR: scratch test suite is not implemented$'
}

record_result "static gate uses the pinned container read-only" docker_gate_is_pinned_and_read_only
record_result "deliberate assertion failure is detected" deliberate_failure_is_detected
record_result "summary reports explicit pass and fail counts" mixed_summary_is_explicit
record_result "unimplemented suite placeholder fails" placeholder_target_fails

printf '%s passed, %s failed\n' "$passed" "$failed"
[ "$failed" -eq 0 ]
