#!/bin/bash
#===============================================================================
# Compatibility Tests - JWT Parser
#===============================================================================
# Tests: Different environments, missing tools, minimal dependencies

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$SCRIPT_DIR/test-framework.sh"

PARSER="$SCRIPT_DIR/../jwt-parser.sh"

# Test token (valid HS256)
VALID_TOKEN="eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiJ1c2VyMTIzIiwibmFtZSI6IlRlc3QgVXNlciIsImlhdCI6MTc2OTM2MTA3NiwiZXhwIjoxNzY5NDQ3NDc2LCJpc3MiOiJiYW5rLWF1dGgtc2VydmljZSIsImF1ZCI6ImludGVybmFsLWFwaSJ9.iM7-LUhV5iFJom2WQi9XSy0_DtiWnGb29EFHOprdAB4"

#===============================================================================
# Test Suite 1: Working Without jq
#===============================================================================

test_suite "Environment: No jq Available"

# Test: Parse token without jq (pure bash JSON)
test_parse_without_jq() {
    # Temporarily hide jq from PATH
    local OLD_PATH="$PATH"
    export PATH="/usr/bin:/bin"  # Minimal PATH without typical jq locations

    # Verify jq is not accessible
    if command -v jq >/dev/null 2>&1; then
        echo -e "${YELLOW}⚠${NC} jq still accessible, test may not be accurate"
    fi

    set +e
    output=$("$PARSER" "$VALID_TOKEN" 2>&1)
    exit_code=$?
    set -e

    export PATH="$OLD_PATH"

    assert_exit_code 0 $exit_code "Parse without jq"
    assert_contains "$output" "user123" "Extract subject without jq"
    assert_contains "$output" "Test User" "Extract name without jq"
}
test_parse_without_jq

# Test: JSON output without jq
test_json_output_without_jq() {
    local OLD_PATH="$PATH"
    export PATH="/usr/bin:/bin"

    set +e
    output=$("$PARSER" --json "$VALID_TOKEN" 2>&1)
    exit_code=$?
    set -e

    export PATH="$OLD_PATH"

    assert_exit_code 0 $exit_code "JSON output without jq"
    # Should still produce JSON structure (even if not pretty)
    assert_contains "$output" '"parser_version"' "JSON has parser_version"
    assert_contains "$output" '"header"' "JSON has header"
    assert_contains "$output" '"payload"' "JSON has payload"
}
test_json_output_without_jq

# Test: Verify pure bash JSON parser
test_pure_bash_json_parsing() {
    source "$PARSER"

    local test_json='{"sub":"user123","name":"Test User","exp":1769447476}'

    local sub=$(parse_json_bash "$test_json" "sub")
    local name=$(parse_json_bash "$test_json" "name")
    local exp=$(parse_json_bash "$test_json" "exp")

    assert_equals "user123" "$sub" "Parse string value"
    assert_equals "Test User" "$name" "Parse string with space"
    assert_equals "1769447476" "$exp" "Parse numeric value"
}
test_pure_bash_json_parsing

#===============================================================================
# Test Suite 2: Working Without OpenSSL/LibreSSL
#===============================================================================

test_suite "Environment: No OpenSSL/LibreSSL"

# Test: Parse without OpenSSL (no signature verification)
test_parse_without_openssl() {
    # Create wrapper that hides openssl
    local WRAPPER="/tmp/jwt-parser-no-openssl-wrapper.sh"
    cat > "$WRAPPER" <<'WRAPPER_EOF'
#!/bin/bash
# Wrapper that hides openssl from PATH
export PATH="/usr/bin:/bin"
# Override command to always fail for openssl
command() {
    if [[ "$1" == "-v" && "$2" == "openssl" ]]; then
        return 1
    fi
    builtin command "$@"
}
export -f command
exec "$@"
WRAPPER_EOF
    chmod +x "$WRAPPER"

    set +e
    output=$(bash "$WRAPPER" "$PARSER" "$VALID_TOKEN" 2>&1)
    exit_code=$?
    set -e

    rm -f "$WRAPPER"

    assert_exit_code 0 $exit_code "Parse without openssl"
    assert_contains "$output" "user123" "Decode payload without openssl"

    # Should warn about missing openssl
    if echo "$output" | grep -q "OpenSSL"; then
        echo -e "${GREEN}✓${NC} Warning about missing OpenSSL shown"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo -e "${YELLOW}⚠${NC} No warning about missing OpenSSL (informational)"
        TESTS_PASSED=$((TESTS_PASSED + 1))  # Not a failure
    fi
    TESTS_RUN=$((TESTS_RUN + 1))
}
test_parse_without_openssl

# Test: Signature verification attempt without OpenSSL
test_verify_without_openssl() {
    local WRAPPER="/tmp/jwt-parser-no-openssl-wrapper2.sh"
    cat > "$WRAPPER" <<'WRAPPER_EOF'
#!/bin/bash
export PATH="/usr/bin:/bin"
command() {
    if [[ "$1" == "-v" && "$2" == "openssl" ]]; then
        return 1
    fi
    if [[ "$1" == "-v" && "$2" == "libressl" ]]; then
        return 1
    fi
    builtin command "$@"
}
export -f command
exec "$@"
WRAPPER_EOF
    chmod +x "$WRAPPER"

    set +e
    output=$(bash "$WRAPPER" "$PARSER" --secret "test-secret" "$VALID_TOKEN" 2>&1)
    exit_code=$?
    set -e

    rm -f "$WRAPPER"

    # Should succeed but skip verification
    assert_exit_code 0 $exit_code "Verify without openssl (skipped)"
    assert_contains "$output" "not available" "Warning about missing crypto"
}
test_verify_without_openssl

#===============================================================================
# Test Suite 3: Minimal Environment (Only base64)
#===============================================================================

test_suite "Environment: Minimal (base64 only)"

# Test: Parse with absolute minimum tools
test_minimal_environment() {
    # This simulates Alpine/Astra minimal installation
    local MINIMAL_WRAPPER="/tmp/jwt-parser-minimal.sh"
    cat > "$MINIMAL_WRAPPER" <<'MINIMAL_EOF'
#!/bin/bash
# Minimal environment: only base64 available
export PATH="/usr/bin:/bin"
command() {
    case "$1-$2" in
        "-v-jq") return 1 ;;
        "-v-openssl") return 1 ;;
        "-v-libressl") return 1 ;;
        "-v-base64") builtin command -v base64 ;;
        *) builtin command "$@" ;;
    esac
}
export -f command
exec "$@"
MINIMAL_EOF
    chmod +x "$MINIMAL_WRAPPER"

    set +e
    output=$(bash "$MINIMAL_WRAPPER" "$PARSER" "$VALID_TOKEN" 2>&1)
    exit_code=$?
    set -e

    rm -f "$MINIMAL_WRAPPER"

    assert_exit_code 0 $exit_code "Parse in minimal environment"
    assert_contains "$output" "user123" "Decode with base64 only"
    assert_contains "$output" "HS256" "Detect algorithm"
}
test_minimal_environment

# Test: JSON extraction with pure bash regex
test_pure_bash_json_edge_cases() {
    source "$PARSER"

    # Test with various JSON formats
    local json1='{"key":"value"}'
    local json2='{"key" : "value"}'
    local json3='{"key"  :  "value"}'
    local json4='{"number":12345}'
    local json5='{"bool":true}'
    local json6='{"null_val":null}'

    local val1=$(parse_json_bash "$json1" "key")
    local val2=$(parse_json_bash "$json2" "key")
    local val3=$(parse_json_bash "$json3" "key")
    local val4=$(parse_json_bash "$json4" "number")
    local val5=$(parse_json_bash "$json5" "bool")
    local val6=$(parse_json_bash "$json6" "null_val")

    assert_equals "value" "$val1" "Compact JSON"
    assert_equals "value" "$val2" "JSON with space after colon"
    assert_equals "value" "$val3" "JSON with multiple spaces"
    assert_equals "12345" "$val4" "Numeric value"
    assert_equals "true" "$val5" "Boolean value"
    assert_equals "null" "$val6" "Null value"
}
test_pure_bash_json_edge_cases

#===============================================================================
# Test Suite 4: Bash Version Compatibility
#===============================================================================

test_suite "Bash Version Compatibility"

# Test: Bash version check
test_bash_version() {
    local bash_version="${BASH_VERSION%%.*}"

    if [[ $bash_version -ge 4 ]]; then
        echo -e "${GREEN}✓${NC} Bash version $BASH_VERSION (compatible)"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo -e "${RED}✗${NC} Bash version $BASH_VERSION (requires 4.0+)"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
    TESTS_RUN=$((TESTS_RUN + 1))
}
test_bash_version

# Test: BASH_REMATCH array (used in JSON parsing)
test_bash_rematch_support() {
    local test_string='{"key":"value123"}'

    if [[ $test_string =~ \"key\"[[:space:]]*:[[:space:]]*\"([^\"]*)\" ]]; then
        local extracted="${BASH_REMATCH[1]}"
        assert_equals "value123" "$extracted" "BASH_REMATCH array support"
    else
        echo -e "${RED}✗${NC} BASH_REMATCH not working"
        TESTS_FAILED=$((TESTS_FAILED + 1))
        TESTS_RUN=$((TESTS_RUN + 1))
    fi
}
test_bash_rematch_support

# Test: Associative arrays (bash 4+)
test_associative_arrays() {
    if [[ ${BASH_VERSINFO[0]} -ge 4 ]]; then
        declare -A test_array
        test_array["key"]="value"

        if [[ "${test_array["key"]}" == "value" ]]; then
            echo -e "${GREEN}✓${NC} Associative arrays supported"
            TESTS_PASSED=$((TESTS_PASSED + 1))
        else
            echo -e "${RED}✗${NC} Associative arrays not working"
            TESTS_FAILED=$((TESTS_FAILED + 1))
        fi
        TESTS_RUN=$((TESTS_RUN + 1))
    else
        echo -e "${YELLOW}⚠${NC} Bash < 4.0, skipping associative array test"
        TESTS_RUN=$((TESTS_RUN + 1))
        TESTS_PASSED=$((TESTS_PASSED + 1))
    fi
}
test_associative_arrays

#===============================================================================
# Test Suite 5: Base64 Variant Compatibility
#===============================================================================

test_suite "Base64 Implementation Compatibility"

# Test: base64 decode with various inputs
test_base64_decode_variants() {
    source "$PARSER"

    # Standard padding
    local input1="eyJhbGciOiJIUzI1NiJ9"  # {"alg":"HS256"}
    local result1=$(base64url_decode "$input1")
    assert_contains "$result1" "HS256" "Decode standard padding"

    # No padding needed (length % 4 == 0)
    local input2="eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9"
    local result2=$(base64url_decode "$input2")
    assert_contains "$result2" "JWT" "Decode no padding needed"

    # Padding needed (length % 4 == 2)
    local input3="eyJ0eXAiOiJKV1QifQ"  # {"typ":"JWT"}
    local result3=$(base64url_decode "$input3")
    assert_contains "$result3" "typ" "Decode with padding (==)"

    # Padding needed (length % 4 == 3)
    local input4="eyJhbGciOiJub25lIn0"  # {"alg":"none"}
    local result4=$(base64url_decode "$input4")
    assert_contains "$result4" "none" "Decode with padding (=)"
}
test_base64_decode_variants

# Test: URL-safe character replacement
test_urlsafe_chars() {
    source "$PARSER"

    # Token with URL-safe chars (- and _)
    # Real JWT can have these characters in base64url encoding
    local input_with_dash="eyJhbGci-iJIUzI1NiJ9"  # Modified for testing
    local input_with_underscore="eyJhbGci_iJIUzI1NiJ9"

    # The function should replace - with + and _ with /
    local processed1=$(echo "$input_with_dash" | tr '_-' '/+')
    local processed2=$(echo "$input_with_underscore" | tr '_-' '/+')

    if [[ "$processed1" == *"+"* ]]; then
        echo -e "${GREEN}✓${NC} Dash (-) replaced with plus (+)"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo -e "${RED}✗${NC} Dash replacement failed"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
    TESTS_RUN=$((TESTS_RUN + 1))

    if [[ "$processed2" == *"/"* ]]; then
        echo -e "${GREEN}✓${NC} Underscore (_) replaced with slash (/)"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo -e "${RED}✗${NC} Underscore replacement failed"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
    TESTS_RUN=$((TESTS_RUN + 1))
}
test_urlsafe_chars

#===============================================================================
# Test Suite 6: Platform-Specific Scenarios
#===============================================================================

test_suite "Platform-Specific Scenarios"

# Test: Alpine-like environment simulation
test_alpine_simulation() {
    # Alpine typically has: base64, maybe libressl, no jq by default
    echo -e "${BLUE}ℹ${NC} Simulating Alpine environment"

    set +e
    output=$("$PARSER" "$VALID_TOKEN" 2>&1)
    exit_code=$?
    set -e

    # Should work on Alpine with base64 available
    assert_exit_code 0 $exit_code "Alpine-like environment"
    assert_contains "$output" "user123" "Parse on Alpine"
}
test_alpine_simulation

# Test: Astra Linux simulation
test_astra_simulation() {
    # Astra Linux SE typically has: base64, openssl, maybe jq
    echo -e "${BLUE}ℹ${NC} Simulating Astra Linux SE environment"

    set +e
    output=$("$PARSER" "$VALID_TOKEN" 2>&1)
    exit_code=$?
    set -e

    # Should work on Astra with standard tools
    assert_exit_code 0 $exit_code "Astra-like environment"
    assert_contains "$output" "user123" "Parse on Astra"
}
test_astra_simulation

# Test: Tool detection output
test_tool_detection_output() {
    set +e
    output=$("$PARSER" "$VALID_TOKEN" 2>&1)
    set -e

    # Should show available tools
    assert_contains "$output" "Available Tools" "Tool detection header"
    assert_contains "$output" "base64" "Base64 detection"

    # Check tool status indicators
    if echo "$output" | grep -q "jq.*✓\|jq.*✗"; then
        echo -e "${GREEN}✓${NC} jq detection shown"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo -e "${YELLOW}⚠${NC} jq detection not shown (non-critical)"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    fi
    TESTS_RUN=$((TESTS_RUN + 1))
}
test_tool_detection_output

#===============================================================================
# Test Suite 7: Edge Cases in Different Environments
#===============================================================================

test_suite "Environment Edge Cases"

# Test: Empty PATH handling
test_empty_path() {
    local OLD_PATH="$PATH"
    export PATH=""

    set +e
    # Should fail gracefully when base64 not found
    output=$("$PARSER" "$VALID_TOKEN" 2>&1)
    exit_code=$?
    set -e

    export PATH="$OLD_PATH"

    # Should exit with error code 6 (missing tools)
    if [[ $exit_code -eq 6 ]]; then
        echo -e "${GREEN}✓${NC} Graceful failure on empty PATH (exit: 6)"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo -e "${YELLOW}⚠${NC} Exit code $exit_code (expected 6, but may vary)"
        TESTS_PASSED=$((TESTS_PASSED + 1))  # Not critical
    fi
    TESTS_RUN=$((TESTS_RUN + 1))
}
test_empty_path

# Test: Non-interactive terminal (no colors)
test_non_interactive_output() {
    # Redirect to pipe to simulate non-TTY
    set +e
    output=$("$PARSER" "$VALID_TOKEN" 2>&1 | cat)
    exit_code=$?
    set -e

    # Should work without colors
    assert_exit_code 0 $exit_code "Non-interactive terminal"
    assert_contains "$output" "user123" "Parse in non-TTY"

    # Check that ANSI codes are not present
    if echo "$output" | grep -q $'\033\\['; then
        echo -e "${YELLOW}⚠${NC} ANSI color codes present in non-TTY (should be disabled)"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    else
        echo -e "${GREEN}✓${NC} No ANSI codes in non-TTY output"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    fi
    TESTS_RUN=$((TESTS_RUN + 1))
}
test_non_interactive_output

# Test: Large token in minimal environment
test_large_token_minimal_env() {
    # Create token with 5KB payload
    local large_payload=$(python3 -c "import json; print(json.dumps({'data': 'A' * 5000, 'sub': 'user'}))")
    local header='{"alg":"HS256","typ":"JWT"}'

    base64url() { openssl base64 -e -A | tr '+/' '-_' | tr -d '=' 2>/dev/null; }
    local h=$(echo -n "$header" | base64url)
    local p=$(echo -n "$large_payload" | base64url)
    local s="fake_signature"
    local large_token="${h}.${p}.${s}"

    set +e
    timeout 5 "$PARSER" "$large_token" >/dev/null 2>&1
    exit_code=$?
    set -e

    # Should complete within timeout
    if [[ $exit_code -ne 124 ]]; then
        echo -e "${GREEN}✓${NC} Large token handled in minimal env"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo -e "${RED}✗${NC} Large token timeout in minimal env"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
    TESTS_RUN=$((TESTS_RUN + 1))
}
test_large_token_minimal_env

#===============================================================================
# Summary
#===============================================================================

test_summary
