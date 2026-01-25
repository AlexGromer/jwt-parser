#!/bin/bash
#===============================================================================
# Test Framework - Simple Bash Testing Library
#===============================================================================

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Test counters
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0
CURRENT_SUITE=""

# Test suite start
test_suite() {
    CURRENT_SUITE="$1"
    echo -e "${BLUE}━━━ Test Suite: $CURRENT_SUITE ━━━${NC}"
}

# Assert equals
assert_equals() {
    local expected="$1"
    local actual="$2"
    local test_name="${3:-Test}"

    TESTS_RUN=$((TESTS_RUN + 1))

    if [[ "$expected" == "$actual" ]]; then
        TESTS_PASSED=$((TESTS_PASSED + 1))
        echo -e "${GREEN}✓${NC} $test_name"
        return 0
    else
        TESTS_FAILED=$((TESTS_FAILED + 1))
        echo -e "${RED}✗${NC} $test_name"
        echo -e "  Expected: ${GREEN}$expected${NC}"
        echo -e "  Actual:   ${RED}$actual${NC}"
        return 1
    fi
}

# Assert contains
assert_contains() {
    local haystack="$1"
    local needle="$2"
    local test_name="${3:-Test}"

    TESTS_RUN=$((TESTS_RUN + 1))

    if [[ "$haystack" == *"$needle"* ]]; then
        TESTS_PASSED=$((TESTS_PASSED + 1))
        echo -e "${GREEN}✓${NC} $test_name"
        return 0
    else
        TESTS_FAILED=$((TESTS_FAILED + 1))
        echo -e "${RED}✗${NC} $test_name"
        echo -e "  Expected to contain: ${GREEN}$needle${NC}"
        echo -e "  Actual:              ${RED}$haystack${NC}"
        return 1
    fi
}

# Assert exit code
assert_exit_code() {
    local expected_code="$1"
    local actual_code="$2"
    local test_name="${3:-Exit code test}"

    TESTS_RUN=$((TESTS_RUN + 1))

    if [[ $expected_code -eq $actual_code ]]; then
        TESTS_PASSED=$((TESTS_PASSED + 1))
        echo -e "${GREEN}✓${NC} $test_name (exit: $actual_code)"
        return 0
    else
        TESTS_FAILED=$((TESTS_FAILED + 1))
        echo -e "${RED}✗${NC} $test_name"
        echo -e "  Expected exit code: ${GREEN}$expected_code${NC}"
        echo -e "  Actual exit code:   ${RED}$actual_code${NC}"
        return 1
    fi
}

# Assert not empty
assert_not_empty() {
    local value="$1"
    local test_name="${2:-Not empty test}"

    TESTS_RUN=$((TESTS_RUN + 1))

    if [[ -n "$value" ]]; then
        TESTS_PASSED=$((TESTS_PASSED + 1))
        echo -e "${GREEN}✓${NC} $test_name"
        return 0
    else
        TESTS_FAILED=$((TESTS_FAILED + 1))
        echo -e "${RED}✗${NC} $test_name (value is empty)"
        return 1
    fi
}

# Test summary
test_summary() {
    echo ""
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}Test Summary${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "Total:  $TESTS_RUN"
    echo -e "${GREEN}Passed: $TESTS_PASSED${NC}"
    echo -e "${RED}Failed: $TESTS_FAILED${NC}"

    local success_rate=0
    if [[ $TESTS_RUN -gt 0 ]]; then
        success_rate=$((TESTS_PASSED * 100 / TESTS_RUN))
    fi

    echo -e "Success rate: ${success_rate}%"
    echo ""

    if [[ $TESTS_FAILED -eq 0 ]]; then
        echo -e "${GREEN}All tests passed! ✓${NC}"
        return 0
    else
        echo -e "${RED}Some tests failed! ✗${NC}"
        return 1
    fi
}
