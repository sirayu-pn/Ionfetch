#!/bin/bash

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
IONFETCH="${SCRIPT_DIR}/ionfetch.sh"
failures=0

pass() {
    printf 'PASS: %s\n' "$1"
}

fail() {
    printf 'FAIL: %s\n' "$1" >&2
    failures=$((failures + 1))
}

assert_contains() {
    local name="$1" output="$2" expected="$3"
    if [[ "$output" == *"$expected"* ]]; then
        pass "$name"
    else
        fail "$name (missing: $expected)"
    fi
}

if output=$(bash "$IONFETCH" --no-color 2>&1); then
    pass 'default execution succeeds'
    assert_contains 'default output has RAM' "$output" 'RAM'
    assert_contains 'default output has DISK' "$output" 'DISK'
    assert_contains 'default output has LOAD' "$output" 'LOAD'
else
    fail 'default execution succeeds'
fi

if output=$(bash "$IONFETCH" --no-color --version 2>&1); then
    assert_contains 'combined options show version' "$output" 'ionfetch v0.2.2'
else
    fail 'combined options show version'
fi

if output=$(bash "$IONFETCH" --help 2>&1); then
    assert_contains 'help shows usage' "$output" 'Usage:'
    assert_contains 'help shows disk setting' "$output" 'IONFETCH_DISK_PATH'
else
    fail 'help succeeds'
fi

if output=$(bash "$IONFETCH" --unknown-option 2>&1); then
    fail 'unknown option is rejected'
else
    status=$?
    if [[ "$status" -eq 2 ]]; then
        pass 'unknown option is rejected with status 2'
    else
        fail "unknown option returns status 2 (got $status)"
    fi
fi

if ((failures > 0)); then
    printf '%d test(s) failed.\n' "$failures" >&2
    exit 1
fi

printf 'All tests passed.\n'
