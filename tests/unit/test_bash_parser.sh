#!/bin/bash
#===============================================================================
# Unit Tests - Bash Parser
#===============================================================================

# Removed set -eo pipefail to allow tests to capture exit codes

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$SCRIPT_DIR/test-framework.sh"

PARSER="$SCRIPT_DIR/../jwt-parser.sh"

# Test tokens
VALID_TOKEN="eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiJ1c2VyMTIzIiwibmFtZSI6IlRlc3QgVXNlciIsImlhdCI6MTc2OTM2MTA3NiwiZXhwIjoxNzY5NDQ3NDc2LCJpc3MiOiJiYW5rLWF1dGgtc2VydmljZSIsImF1ZCI6ImludGVybmFsLWFwaSJ9.iM7-LUhV5iFJom2WQi9XSy0_DtiWnGb29EFHOprdAB4"

#===============================================================================
# Test Suite 1: Base64URL Decoding
#===============================================================================

test_suite "Base64URL Decoding"

# Test: Simple base64url decode
test_base64url_simple() {
    # Source the parser to get base64url_decode function
    source "$PARSER"

    local input="eyJhbGciOiJIUzI1NiJ9"
    local result=$(base64url_decode "$input")
    local expected='{"alg":"HS256"}'

    assert_equals "$expected" "$result" "Decode simple base64url"
}
test_base64url_simple

# Test: Base64url with padding needed
test_base64url_padding() {
    source "$PARSER"

    # Input needs padding (length % 4 == 2)
    local input="eyJ0eXAiOiJKV1QifQ"  # {"typ":"JWT"}
    local result=$(base64url_decode "$input" | tr -d '\n')

    assert_contains "$result" "typ" "Decode with padding"
}
test_base64url_padding

# Test: URL-safe characters replacement
test_base64url_urlsafe() {
    source "$PARSER"

    # Token with URL-safe chars (- and _)
    local input="eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9"
    local result=$(base64url_decode "$input")

    assert_contains "$result" "HS256" "URL-safe char replacement"
}
test_base64url_urlsafe

#===============================================================================
# Test Suite 2: Token Parsing
#===============================================================================

test_suite "Token Parsing"

# Test: Valid token structure
test_valid_token_structure() {
    local output=$("$PARSER" "$VALID_TOKEN" 2>&1)
    local exit_code=$?

    assert_exit_code 0 $exit_code "Valid token exit code"
    assert_contains "$output" "JWT Header" "Output contains header section"
    assert_contains "$output" "JWT Payload" "Output contains payload section"
}
test_valid_token_structure

# Test: Invalid token (only 2 parts)
test_invalid_token_2parts() {
    local invalid_token="eyJhbGci.eyJzdWIi"
    set +e  # Temporarily disable exit on error
    output=$("$PARSER" "$invalid_token" 2>&1)
    exit_code=$?
    set -e  # Re-enable

    assert_exit_code 2 $exit_code "Invalid token exit code"
    assert_contains "$output" "Invalid JWT format" "Error message for invalid format"
}
test_invalid_token_2parts

# Test: Invalid token (4 parts)
test_invalid_token_4parts() {
    local invalid_token="part1.part2.part3.part4"
    set +e  # Temporarily disable exit on error
    output=$("$PARSER" "$invalid_token" 2>&1)
    exit_code=$?
    set -e  # Re-enable

    assert_exit_code 2 $exit_code "Invalid 4-part token exit code"
}
test_invalid_token_4parts

# Test: Empty token
test_empty_token() {
    set +e  # Temporarily disable exit on error
    output=$("$PARSER" "" 2>&1)
    exit_code=$?
    set -e  # Re-enable

    assert_exit_code 1 $exit_code "Empty token exit code"
    assert_contains "$output" "JWT token required" "Error for empty token"
}
test_empty_token

#===============================================================================
# Test Suite 3: JSON Output
#===============================================================================

test_suite "JSON Output"

# Test: JSON format
test_json_output() {
    local output=$("$PARSER" --json "$VALID_TOKEN" 2>&1)
    local exit_code=$?

    assert_exit_code 0 $exit_code "JSON output exit code"
    assert_contains "$output" '"parser_version"' "JSON has parser_version"
    assert_contains "$output" '"header"' "JSON has header"
    assert_contains "$output" '"payload"' "JSON has payload"
    assert_contains "$output" '"validation_status"' "JSON has validation_status"
}
test_json_output

# Test: JSON parseable with jq
test_json_jq_parse() {
    local output=$("$PARSER" --json "$VALID_TOKEN" 2>&1)
    local status=$(echo "$output" | jq -r '.validation_status' 2>/dev/null)

    assert_equals "VALID" "$status" "JSON parseable with jq"
}
test_json_jq_parse

#===============================================================================
# Test Suite 4: Claims Extraction
#===============================================================================

test_suite "Claims Extraction"

# Test: Extract subject
test_extract_subject() {
    local output=$("$PARSER" --json "$VALID_TOKEN" 2>&1)
    local subject=$(echo "$output" | jq -r '.payload.sub' 2>/dev/null)

    assert_equals "user123" "$subject" "Extract subject claim"
}
test_extract_subject

# Test: Extract expiration
test_extract_expiration() {
    local output=$("$PARSER" --json "$VALID_TOKEN" 2>&1)
    local exp=$(echo "$output" | jq -r '.payload.exp' 2>/dev/null)

    assert_equals "1769447476" "$exp" "Extract expiration claim"
}
test_extract_expiration

# Test: Extract issuer
test_extract_issuer() {
    local output=$("$PARSER" --json "$VALID_TOKEN" 2>&1)
    local iss=$(echo "$output" | jq -r '.payload.iss' 2>/dev/null)

    assert_equals "bank-auth-service" "$iss" "Extract issuer claim"
}
test_extract_issuer

#===============================================================================
# Test Suite 5: Signature Verification
#===============================================================================

test_suite "Signature Verification"

# Test: Valid signature
test_valid_signature() {
    local output=$("$PARSER" --secret "my-bank-secret-key-2024" "$VALID_TOKEN" 2>&1)
    local exit_code=$?

    assert_exit_code 0 $exit_code "Valid signature exit code"
    assert_contains "$output" "Signature VALID" "Valid signature message"
}
test_valid_signature

# Test: Invalid signature
test_invalid_signature() {
    set +e  # Temporarily disable exit on error
    output=$("$PARSER" --secret "WRONG_SECRET" "$VALID_TOKEN" 2>&1)
    exit_code=$?
    set -e  # Re-enable

    assert_exit_code 5 $exit_code "Invalid signature exit code"
    assert_contains "$output" "Signature INVALID" "Invalid signature message"
}
test_invalid_signature

#===============================================================================
# Test Suite 6: Expired Tokens
#===============================================================================

test_suite "Expired Token Handling"

# Test: Expired token
test_expired_token() {
    # Create expired token
    local past_time=$(($(date +%s) - 3600))
    local payload=$(jq -n --argjson exp $past_time '{"sub":"test","exp":$exp}')
    local header='{"alg":"HS256","typ":"JWT"}'

    base64url() { openssl base64 -e -A | tr '+/' '-_' | tr -d '=' 2>/dev/null; }
    local h=$(echo -n "$header" | base64url)
    local p=$(echo -n "$payload" | base64url)
    local s=$(echo -n "${h}.${p}" | openssl dgst -sha256 -hmac "secret" -binary 2>/dev/null | base64url)
    local expired_token="${h}.${p}.${s}"

    set +e  # Temporarily disable exit on error
    output=$("$PARSER" "$expired_token" 2>&1)
    exit_code=$?
    set -e  # Re-enable

    assert_exit_code 3 $exit_code "Expired token exit code"
    assert_contains "$output" "EXPIRED" "Expired token message"
}
test_expired_token

#===============================================================================
# Test Suite 7: Help and Version
#===============================================================================

test_suite "CLI Options"

# Test: Help option
test_help_option() {
    local output=$("$PARSER" --help 2>&1)
    local exit_code=$?

    assert_exit_code 0 $exit_code "Help exit code"
    assert_contains "$output" "Usage:" "Help shows usage"
    assert_contains "$output" "OPTIONS:" "Help shows options"
}
test_help_option

# Test: Version option
test_version_option() {
    local output=$("$PARSER" --version 2>&1)
    local exit_code=$?

    assert_exit_code 0 $exit_code "Version exit code"
    assert_contains "$output" "1.0.0" "Version shows version number"
}
test_version_option

#===============================================================================
# Summary
#===============================================================================

test_summary
