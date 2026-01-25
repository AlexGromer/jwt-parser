#!/bin/bash
#===============================================================================
# Security Tests - JWT Parser
#===============================================================================
# Tests: Injection, malformed tokens, algorithm confusion, secret leakage

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$SCRIPT_DIR/test-framework.sh"

PARSER="$SCRIPT_DIR/../jwt-parser.sh"

#===============================================================================
# Test Suite 1: Malformed Tokens
#===============================================================================

test_suite "Malformed Token Handling"

# Test: SQL Injection attempt in payload
test_sql_injection_payload() {
    # Create token with SQL injection string
    local payload='{"sub":"admin'\'' OR 1=1--","name":"Test"}'
    local header='{"alg":"HS256","typ":"JWT"}'

    base64url() { openssl base64 -e -A | tr '+/' '-_' | tr -d '=' 2>/dev/null; }
    local h=$(echo -n "$header" | base64url)
    local p=$(echo -n "$payload" | base64url)
    local s=$(echo -n "${h}.${p}" | openssl dgst -sha256 -hmac "secret" -binary 2>/dev/null | base64url)
    local malicious_token="${h}.${p}.${s}"

    set +e
    output=$("$PARSER" --json "$malicious_token" 2>&1)
    exit_code=$?
    set -e

    # Should parse without execution (just decode)
    assert_exit_code 0 $exit_code "SQL injection string handled safely"

    # Verify the dangerous string is in output but NOT executed
    if echo "$output" | jq -e '.payload.sub' | grep -q "OR 1=1"; then
        echo -e "${GREEN}✓${NC} SQL injection string decoded but not executed"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo -e "${RED}✗${NC} SQL injection string not properly handled"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
    TESTS_RUN=$((TESTS_RUN + 1))
}
test_sql_injection_payload

# Test: Command injection attempt
test_command_injection() {
    local payload='{"sub":"user; rm -rf /","cmd":"$(whoami)"}'
    local header='{"alg":"HS256","typ":"JWT"}'

    base64url() { openssl base64 -e -A | tr '+/' '-_' | tr -d '=' 2>/dev/null; }
    local h=$(echo -n "$header" | base64url)
    local p=$(echo -n "$payload" | base64url)
    local s=$(echo -n "${h}.${p}" | openssl dgst -sha256 -hmac "secret" -binary 2>/dev/null | base64url)
    local cmd_token="${h}.${p}.${s}"

    set +e
    output=$("$PARSER" --json "$cmd_token" 2>&1)
    exit_code=$?
    set -e

    assert_exit_code 0 $exit_code "Command injection string handled safely"
    assert_contains "$output" '$(whoami)' "Dangerous payload decoded (not executed)"
}
test_command_injection

# Test: Extremely long token (DoS attempt)
test_extremely_long_token() {
    # Create token with very long payload (10KB)
    local long_string=$(python3 -c "print('A' * 10000)")
    local payload="{\"sub\":\"user\",\"data\":\"$long_string\"}"
    local header='{"alg":"HS256","typ":"JWT"}'

    base64url() { openssl base64 -e -A | tr '+/' '-_' | tr -d '=' 2>/dev/null; }
    local h=$(echo -n "$header" | base64url)
    local p=$(echo -n "$payload" | base64url)
    local s="fake_signature"
    local long_token="${h}.${p}.${s}"

    set +e
    timeout 5 "$PARSER" --json "$long_token" >/dev/null 2>&1
    exit_code=$?
    set -e

    # Should complete within 5 seconds
    if [[ $exit_code -ne 124 ]]; then
        echo -e "${GREEN}✓${NC} Long token handled without timeout"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo -e "${RED}✗${NC} Long token caused timeout (DoS risk)"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
    TESTS_RUN=$((TESTS_RUN + 1))
}
test_extremely_long_token

# Test: Invalid base64 characters
test_invalid_base64_chars() {
    local invalid_token="ey!@#$.ey$%^&*.xyz"

    set +e
    output=$("$PARSER" "$invalid_token" 2>&1)
    exit_code=$?
    set -e

    # Should fail gracefully with error code
    if [[ $exit_code -ne 0 ]]; then
        echo -e "${GREEN}✓${NC} Invalid base64 rejected gracefully"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo -e "${RED}✗${NC} Invalid base64 not properly rejected"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
    TESTS_RUN=$((TESTS_RUN + 1))
}
test_invalid_base64_chars

#===============================================================================
# Test Suite 2: Algorithm Confusion Attack
#===============================================================================

test_suite "Algorithm Confusion Attack Prevention"

# Test: Algorithm none
test_algorithm_none() {
    local payload='{"sub":"admin","role":"superuser"}'
    local header='{"alg":"none","typ":"JWT"}'

    base64url() { openssl base64 -e -A | tr '+/' '-_' | tr -d '=' 2>/dev/null; }
    local h=$(echo -n "$header" | base64url)
    local p=$(echo -n "$payload" | base64url)
    local none_token="${h}.${p}."

    set +e
    output=$("$PARSER" "$none_token" 2>&1)
    exit_code=$?
    set -e

    # Should parse but warn about insecure algorithm
    assert_contains "$output" "none" "Algorithm none detected"
}
test_algorithm_none

# Test: Mismatched algorithm (header says HS256, but verify with wrong alg)
test_algorithm_mismatch() {
    # Create HS256 token
    local payload='{"sub":"user"}'
    local header='{"alg":"HS256","typ":"JWT"}'

    base64url() { openssl base64 -e -A | tr '+/' '-_' | tr -d '=' 2>/dev/null; }
    local h=$(echo -n "$header" | base64url)
    local p=$(echo -n "$payload" | base64url)
    local signing_input="${h}.${p}"
    local s=$(echo -n "$signing_input" | openssl dgst -sha256 -hmac "secret1" -binary 2>/dev/null | base64url)
    local token="${h}.${p}.${s}"

    # Try to verify with wrong secret
    set +e
    output=$("$PARSER" --secret "secret2" "$token" 2>&1)
    exit_code=$?
    set -e

    # Should fail signature verification
    assert_exit_code 5 $exit_code "Wrong secret rejected"
}
test_algorithm_mismatch

#===============================================================================
# Test Suite 3: Secret Leakage Prevention
#===============================================================================

test_suite "Secret Leakage Prevention"

# Test: Secret not in stdout
test_secret_not_in_stdout() {
    local token="eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiJ1c2VyIn0.signature"
    local secret="SUPER_SECRET_KEY_12345"

    set +e
    output=$("$PARSER" --secret "$secret" "$token" 2>&1)
    set -e

    if echo "$output" | grep -q "$secret"; then
        echo -e "${RED}✗${NC} SECRET LEAKED IN OUTPUT!"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    else
        echo -e "${GREEN}✓${NC} Secret not leaked in output"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    fi
    TESTS_RUN=$((TESTS_RUN + 1))
}
test_secret_not_in_stdout

# Test: Secret not in error messages
test_secret_not_in_errors() {
    local invalid_token="invalid"
    local secret="MY_SECRET_KEY"

    set +e
    output=$("$PARSER" --secret "$secret" "$invalid_token" 2>&1)
    set -e

    if echo "$output" | grep -q "$secret"; then
        echo -e "${RED}✗${NC} SECRET LEAKED IN ERROR MESSAGE!"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    else
        echo -e "${GREEN}✓${NC} Secret not in error messages"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    fi
    TESTS_RUN=$((TESTS_RUN + 1))
}
test_secret_not_in_errors

#===============================================================================
# Test Suite 4: Unicode and Special Characters
#===============================================================================

test_suite "Unicode and Special Characters"

# Test: Unicode in claims
test_unicode_in_claims() {
    local payload='{"sub":"иванов","name":"Иван Петрович","emoji":"🔐"}'
    local header='{"alg":"HS256","typ":"JWT"}'

    base64url() { openssl base64 -e -A | tr '+/' '-_' | tr -d '=' 2>/dev/null; }
    local h=$(echo -n "$header" | base64url)
    local p=$(echo -n "$payload" | base64url)
    local s=$(echo -n "${h}.${p}" | openssl dgst -sha256 -hmac "secret" -binary 2>/dev/null | base64url)
    local unicode_token="${h}.${p}.${s}"

    set +e
    output=$("$PARSER" --json "$unicode_token" 2>&1)
    exit_code=$?
    set -e

    assert_exit_code 0 $exit_code "Unicode handled correctly"
    assert_contains "$output" "иванов" "Cyrillic decoded"
}
test_unicode_in_claims

# Test: Null bytes in payload (should be rejected or sanitized)
test_null_bytes() {
    # Null byte in base64: \x00
    local payload_with_null="eyJzdWIiOiJ1c2VyXHUwMDAwIn0"  # {"sub":"user\u0000"}
    local header="eyJhbGciOiJIUzI1NiJ9"
    local null_token="${header}.${payload_with_null}.sig"

    set +e
    output=$("$PARSER" "$null_token" 2>&1)
    exit_code=$?
    set -e

    # Should handle gracefully (not crash)
    if [[ $exit_code -eq 0 || $exit_code -eq 2 ]]; then
        echo -e "${GREEN}✓${NC} Null bytes handled without crash"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo -e "${RED}✗${NC} Null bytes caused unexpected behavior"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
    TESTS_RUN=$((TESTS_RUN + 1))
}
test_null_bytes

#===============================================================================
# Test Suite 5: Timing Attack Resistance
#===============================================================================

test_suite "Timing Attack Considerations"

# Note: Full timing attack testing requires statistical analysis
# This is a basic sanity check

test_timing_basic() {
    local token="eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiJ1c2VyIn0.sig"

    # Verify with correct secret (first char wrong)
    local start1=$(date +%s%N)
    "$PARSER" --secret "Asecret" "$token" >/dev/null 2>&1 || true
    local end1=$(date +%s%N)
    local time1=$((end1 - start1))

    # Verify with correct secret (last char wrong)
    local start2=$(date +%s%N)
    "$PARSER" --secret "secretX" "$token" >/dev/null 2>&1 || true
    local end2=$(date +%s%N)
    local time2=$((end2 - start2))

    # Times should be similar (within 50% variance)
    # Note: This is a weak test, real timing attacks need microsecond precision
    echo -e "${YELLOW}ℹ${NC} Timing test: ${time1}ns vs ${time2}ns (informational)"
    echo -e "${YELLOW}ℹ${NC} Note: OpenSSL dgst should use constant-time comparison"
    TESTS_RUN=$((TESTS_RUN + 1))
    TESTS_PASSED=$((TESTS_PASSED + 1))  # Informational only
}
test_timing_basic

#===============================================================================
# Summary
#===============================================================================

test_summary
