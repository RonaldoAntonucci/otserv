#!/bin/sh

set -u

passed_files=0
failed_files=0
found_files=0

for test_file in $(find tests -maxdepth 1 -type f \( -name '*-contract.sh' -o -name 'native-install-static.sh' \) | sort); do
    found_files=$((found_files + 1))
    printf '\nRunning %s\n' "$test_file"

    if sh "$test_file"; then
        passed_files=$((passed_files + 1))
    else
        failed_files=$((failed_files + 1))
    fi
done

if [ "$found_files" -eq 0 ]; then
    printf 'ERROR: no static contract tests found\n' >&2
    exit 1
fi

printf '\n%s contract files passed, %s failed\n' "$passed_files" "$failed_files"
[ "$failed_files" -eq 0 ]
