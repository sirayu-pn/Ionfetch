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
    assert_contains 'combined options show version' "$output" 'ionfetch v0.3.0'
else
    fail 'combined options show version'
fi

if output=$(bash "$IONFETCH" --json --all-disks 2>&1); then
    assert_contains 'JSON output has version' "$output" '"version": "0.3.0"'
    assert_contains 'JSON output has disks' "$output" '"disks": ['
    assert_contains 'JSON output has reboot flag' "$output" '"reboot_required":'
else
    fail 'JSON output succeeds'
fi

if output=$(IONFETCH_DISK_PATH=/tmp bash "$IONFETCH" --disk / 2>&1); then
    assert_contains 'CLI disk option overrides environment' "$output" 'DISK 1 [/]'
else
    fail 'CLI disk option overrides environment'
fi

if output=$(bash "$IONFETCH" --disk 2>&1); then
    fail 'disk option requires a path'
else
    status=$?
    if [[ "$status" -eq 2 ]]; then
        pass 'disk option requires a path'
    else
        fail "disk option returns status 2 (got $status)"
    fi
fi

if output=$(bash "$IONFETCH" --disk= 2>&1); then
    fail 'disk option with empty equals requires a path'
else
    status=$?
    if [[ "$status" -eq 2 ]]; then
        pass 'disk option with empty equals requires a path'
    else
        fail "disk option with empty equals returns status 2 (got $status)"
    fi
fi

if output=$(IONFETCH_DISK_PATH=/nonexistent bash "$IONFETCH" --all-disks --no-color 2>&1); then
    assert_contains '--all-disks overrides IONFETCH_DISK_PATH' "$output" 'DISK'
else
    fail '--all-disks overrides IONFETCH_DISK_PATH'
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
