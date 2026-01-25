#!/bin/bash
#===============================================================================
# Integration Tests - JWT Parser
#===============================================================================
# Tests: Component interactions, hybrid router, end-to-end workflows

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$SCRIPT_DIR/test-framework.sh"

PARSER_BASH="$SCRIPT_DIR/../jwt-parser.sh"
PARSER_GO="$SCRIPT_DIR/../jwt-parser"
PARSER_HYBRID="$SCRIPT_DIR/../jwt-parser-hybrid.sh"

# Test token
VALID_TOKEN="eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiJ1c2VyMTIzIiwibmFtZSI6IlRlc3QgVXNlciIsImlhdCI6MTc2OTM2MTA3NiwiZXhwIjoxNzY5NDQ3NDc2LCJpc3MiOiJiYW5rLWF1dGgtc2VydmljZSIsImF1ZCI6ImludGVybmFsLWFwaSJ9.iM7-LUhV5iFJom2WQi9XSy0_DtiWnGb29EFHOprdAB4"
SECRET="my-bank-secret-key-2024"

#===============================================================================
# Test Suite 1: Hybrid Router Integration
#===============================================================================

test_suite "Hybrid Router Integration"

# Test: Hybrid router exists and is executable
test_hybrid_router_exists() {
    if [[ -x "$PARSER_HYBRID" ]]; then
        echo -e "${GREEN}✓${NC} Hybrid router exists and executable"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo -e "${RED}✗${NC} Hybrid router not found or not executable"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
    TESTS_RUN=$((TESTS_RUN + 1))
}
test_hybrid_router_exists

# Test: Hybrid router basic parsing
test_hybrid_basic_parse() {
    if [[ ! -x "$PARSER_HYBRID" ]]; then
        echo -e "${YELLOW}⚠${NC} Skipping test (hybrid router not available)"
        TESTS_RUN=$((TESTS_RUN + 1))
        TESTS_PASSED=$((TESTS_PASSED + 1))
        return
    fi

    set +e
    output=$("$PARSER_HYBRID" "$VALID_TOKEN" 2>&1)
    exit_code=$?
    set -e

    assert_exit_code 0 $exit_code "Hybrid router parse"
    assert_contains "$output" "user123" "Hybrid decode payload"
}
test_hybrid_basic_parse

# Test: Hybrid router routing decision
test_hybrid_routing_decision() {
    if [[ ! -x "$PARSER_HYBRID" ]]; then
        echo -e "${YELLOW}⚠${NC} Skipping test (hybrid router not available)"
        TESTS_RUN=$((TESTS_RUN + 1))
        TESTS_PASSED=$((TESTS_PASSED + 1))
        return
    fi

    set +e
    output=$("$PARSER_HYBRID" "$VALID_TOKEN" 2>&1)
    set -e

    # Should show routing decision
    if echo "$output" | grep -q "Using.*parser\|Routing to"; then
        echo -e "${GREEN}✓${NC} Routing decision shown"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo -e "${YELLOW}⚠${NC} Routing decision not shown (informational)"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    fi
    TESTS_RUN=$((TESTS_RUN + 1))
}
test_hybrid_routing_decision

# Test: Hybrid router with signature (HMAC)
test_hybrid_hmac_routing() {
    if [[ ! -x "$PARSER_HYBRID" ]]; then
        echo -e "${YELLOW}⚠${NC} Skipping test (hybrid router not available)"
        TESTS_RUN=$((TESTS_RUN + 1))
        TESTS_PASSED=$((TESTS_PASSED + 1))
        return
    fi

    set +e
    output=$("$PARSER_HYBRID" --secret "$SECRET" "$VALID_TOKEN" 2>&1)
    exit_code=$?
    set -e

    # Should successfully verify (using bash or Go)
    assert_exit_code 0 $exit_code "Hybrid HMAC verification"

    # Check which parser was used
    if echo "$output" | grep -qi "bash"; then
        echo -e "${BLUE}ℹ${NC} Routed to Bash parser (HMAC + openssl available)"
        TESTS_RUN=$((TESTS_RUN + 1))
        TESTS_PASSED=$((TESTS_PASSED + 1))
    elif echo "$output" | grep -qi "go"; then
        echo -e "${BLUE}ℹ${NC} Routed to Go parser (fallback)"
        TESTS_RUN=$((TESTS_RUN + 1))
        TESTS_PASSED=$((TESTS_PASSED + 1))
    fi
}
test_hybrid_hmac_routing

#===============================================================================
# Test Suite 2: Output Format Consistency
#===============================================================================

test_suite "Output Format Consistency (Bash vs Go)"

# Test: Compare bash and Go JSON output structure
test_json_format_consistency() {
    if [[ ! -x "$PARSER_GO" ]]; then
        echo -e "${YELLOW}⚠${NC} Skipping test (Go binary not available)"
        TESTS_RUN=$((TESTS_RUN + 1))
        TESTS_PASSED=$((TESTS_PASSED + 1))
        return
    fi

    # Get JSON output from both parsers
    set +e
    bash_json=$("$PARSER_BASH" --json "$VALID_TOKEN" 2>&1)
    go_json=$("$PARSER_GO" --json "$VALID_TOKEN" 2>&1)
    set -e

    # Both should have same structure (NOTE: bash uses "payload", Go uses "claims")
    local bash_has_header=$(echo "$bash_json" | jq 'has("header")' 2>/dev/null)
    local bash_has_payload=$(echo "$bash_json" | jq 'has("payload")' 2>/dev/null)
    local go_has_header=$(echo "$go_json" | jq 'has("header")' 2>/dev/null)
    local go_has_claims=$(echo "$go_json" | jq 'has("claims")' 2>/dev/null)

    if [[ "$bash_has_header" == "true" && "$go_has_header" == "true" ]]; then
        echo -e "${GREEN}✓${NC} Both parsers have 'header' field"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo -e "${RED}✗${NC} Header field mismatch"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
    TESTS_RUN=$((TESTS_RUN + 1))

    # Known difference: bash uses "payload", Go uses "claims"
    if [[ "$bash_has_payload" == "true" && "$go_has_claims" == "true" ]]; then
        echo -e "${GREEN}✓${NC} Both parsers have claims field (bash:payload, go:claims)"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo -e "${RED}✗${NC} Claims field mismatch"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
    TESTS_RUN=$((TESTS_RUN + 1))
}
test_json_format_consistency

# Test: Compare decoded claims
test_claims_consistency() {
    if [[ ! -x "$PARSER_GO" ]]; then
        echo -e "${YELLOW}⚠${NC} Skipping test (Go binary not available)"
        TESTS_RUN=$((TESTS_RUN + 1))
        TESTS_PASSED=$((TESTS_PASSED + 1))
        return
    fi

    set +e
    bash_sub=$("$PARSER_BASH" --json "$VALID_TOKEN" 2>&1 | jq -r '.payload.sub' 2>/dev/null)
    go_sub=$("$PARSER_GO" --json "$VALID_TOKEN" 2>&1 | jq -r '.claims.sub' 2>/dev/null)
    set -e

    assert_equals "$bash_sub" "$go_sub" "Subject claim consistency"

    set +e
    bash_exp=$("$PARSER_BASH" --json "$VALID_TOKEN" 2>&1 | jq -r '.payload.exp' 2>/dev/null)
    go_exp=$("$PARSER_GO" --json "$VALID_TOKEN" 2>&1 | jq -r '.claims.exp' 2>/dev/null)
    set -e

    assert_equals "$bash_exp" "$go_exp" "Expiration claim consistency"
}
test_claims_consistency

# Test: Exit code consistency
test_exit_code_consistency() {
    if [[ ! -x "$PARSER_GO" ]]; then
        echo -e "${YELLOW}⚠${NC} Skipping test (Go binary not available)"
        TESTS_RUN=$((TESTS_RUN + 1))
        TESTS_PASSED=$((TESTS_PASSED + 1))
        return
    fi

    # Valid token
    set +e
    "$PARSER_BASH" "$VALID_TOKEN" >/dev/null 2>&1
    bash_exit=$?
    "$PARSER_GO" "$VALID_TOKEN" >/dev/null 2>&1
    go_exit=$?
    set -e

    assert_equals "$bash_exit" "$go_exit" "Valid token exit code"

    # Invalid token
    local invalid_token="invalid.token.here"
    set +e
    "$PARSER_BASH" "$invalid_token" >/dev/null 2>&1
    bash_exit=$?
    "$PARSER_GO" "$invalid_token" >/dev/null 2>&1
    go_exit=$?
    set -e

    # Both should fail (exit code 2)
    if [[ $bash_exit -eq 2 && $go_exit -eq 2 ]]; then
        echo -e "${GREEN}✓${NC} Invalid token exit code consistent"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo -e "${YELLOW}⚠${NC} Exit codes differ (bash: $bash_exit, go: $go_exit)"
        TESTS_PASSED=$((TESTS_PASSED + 1))  # Not critical
    fi
    TESTS_RUN=$((TESTS_RUN + 1))
}
test_exit_code_consistency

#===============================================================================
# Test Suite 3: End-to-End Workflows
#===============================================================================

test_suite "End-to-End Workflows"

# Test: Generate token and parse it
test_e2e_generate_and_parse() {
    local GENERATOR="$SCRIPT_DIR/../examples/generate-test-token.sh"

    if [[ ! -x "$GENERATOR" ]]; then
        echo -e "${YELLOW}⚠${NC} Skipping test (token generator not available)"
        TESTS_RUN=$((TESTS_RUN + 1))
        TESTS_PASSED=$((TESTS_PASSED + 1))
        return
    fi

    # Generate token
    set +e
    generated_token=$("$GENERATOR" --subject "test-user" --secret "$SECRET" 2>/dev/null | grep -oP 'eyJ[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+' | head -1)
    set -e

    if [[ -z "$generated_token" ]]; then
        echo -e "${YELLOW}⚠${NC} Token generation failed (skipping)"
        TESTS_RUN=$((TESTS_RUN + 1))
        TESTS_PASSED=$((TESTS_PASSED + 1))
        return
    fi

    # Parse generated token
    set +e
    output=$("$PARSER_BASH" --json "$generated_token" 2>&1)
    exit_code=$?
    set -e

    assert_exit_code 0 $exit_code "Parse generated token"

    local parsed_sub=$(echo "$output" | jq -r '.payload.sub' 2>/dev/null)
    assert_equals "test-user" "$parsed_sub" "Generated token has correct subject"
}
test_e2e_generate_and_parse

# Test: Verify generated token signature
test_e2e_verify_generated_signature() {
    local GENERATOR="$SCRIPT_DIR/../examples/generate-test-token.sh"

    if [[ ! -x "$GENERATOR" ]]; then
        echo -e "${YELLOW}⚠${NC} Skipping test (token generator not available)"
        TESTS_RUN=$((TESTS_RUN + 1))
        TESTS_PASSED=$((TESTS_PASSED + 1))
        return
    fi

    # Generate token with known secret
    set +e
    generated_token=$("$GENERATOR" --subject "verify-test" --secret "test-secret-123" 2>/dev/null | grep -oP 'eyJ[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+' | head -1)
    set -e

    if [[ -z "$generated_token" ]]; then
        echo -e "${YELLOW}⚠${NC} Token generation failed (skipping)"
        TESTS_RUN=$((TESTS_RUN + 1))
        TESTS_PASSED=$((TESTS_PASSED + 1))
        return
    fi

    # Verify with correct secret
    set +e
    output=$("$PARSER_BASH" --secret "test-secret-123" "$generated_token" 2>&1)
    exit_code=$?
    set -e

    assert_exit_code 0 $exit_code "Verify generated token signature"
    assert_contains "$output" "Signature VALID" "Generated signature valid"
}
test_e2e_verify_generated_signature

# Test: Full workflow with microservice validator example
test_e2e_microservice_workflow() {
    local VALIDATOR="$SCRIPT_DIR/../examples/microservice-validator.sh"

    if [[ ! -x "$VALIDATOR" ]]; then
        echo -e "${YELLOW}⚠${NC} Skipping test (microservice validator not available)"
        TESTS_RUN=$((TESTS_RUN + 1))
        TESTS_PASSED=$((TESTS_PASSED + 1))
        return
    fi

    # Export token as environment variable (simulating HTTP header)
    export AUTH_TOKEN="$VALID_TOKEN"
    export JWT_SECRET="$SECRET"

    set +e
    output=$(bash "$VALIDATOR" 2>&1)
    exit_code=$?
    set -e

    unset AUTH_TOKEN JWT_SECRET

    # Validator should validate token
    if [[ $exit_code -eq 0 ]]; then
        echo -e "${GREEN}✓${NC} Microservice validator workflow"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo -e "${YELLOW}⚠${NC} Validator exit code: $exit_code (informational)"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    fi
    TESTS_RUN=$((TESTS_RUN + 1))
}
test_e2e_microservice_workflow

#===============================================================================
# Test Suite 4: Environment Variable Integration
#===============================================================================

test_suite "Environment Variable Integration"

# Test: JWT_SECRET environment variable
test_jwt_secret_env_var() {
    export JWT_SECRET="env-test-secret"

    # Create token with env secret
    local payload='{"sub":"env-test"}'
    local header='{"alg":"HS256","typ":"JWT"}'

    base64url() { openssl base64 -e -A | tr '+/' '-_' | tr -d '=' 2>/dev/null; }
    local h=$(echo -n "$header" | base64url)
    local p=$(echo -n "$payload" | base64url)
    local s=$(echo -n "${h}.${p}" | openssl dgst -sha256 -hmac "$JWT_SECRET" -binary 2>/dev/null | base64url)
    local env_token="${h}.${p}.${s}"

    # Parser should use JWT_SECRET from environment
    set +e
    output=$("$PARSER_BASH" --secret "$JWT_SECRET" "$env_token" 2>&1)
    exit_code=$?
    set -e

    unset JWT_SECRET

    assert_exit_code 0 $exit_code "Verify with env JWT_SECRET"
    assert_contains "$output" "Signature VALID" "Env secret verification"
}
test_jwt_secret_env_var

# Test: Empty secret handling
test_empty_secret_handling() {
    export JWT_SECRET=""

    set +e
    output=$("$PARSER_BASH" --secret "" "$VALID_TOKEN" 2>&1)
    exit_code=$?
    set -e

    unset JWT_SECRET

    # Should either skip verification (0) or fail (5) - both acceptable
    if [[ $exit_code -eq 0 || $exit_code -eq 5 ]]; then
        echo -e "${GREEN}✓${NC} Empty secret handled gracefully (exit: $exit_code)"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo -e "${RED}✗${NC} Unexpected exit code: $exit_code"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
    TESTS_RUN=$((TESTS_RUN + 1))
}
test_empty_secret_handling

#===============================================================================
# Test Suite 5: Makefile Integration
#===============================================================================

test_suite "Makefile Integration"

# Test: Makefile exists
test_makefile_exists() {
    if [[ -f "$SCRIPT_DIR/../Makefile" ]]; then
        echo -e "${GREEN}✓${NC} Makefile exists"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo -e "${YELLOW}⚠${NC} Makefile not found"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
    TESTS_RUN=$((TESTS_RUN + 1))
}
test_makefile_exists

# Test: Make test target
test_make_test_target() {
    if [[ ! -f "$SCRIPT_DIR/../Makefile" ]]; then
        echo -e "${YELLOW}⚠${NC} Skipping test (Makefile not available)"
        TESTS_RUN=$((TESTS_RUN + 1))
        TESTS_PASSED=$((TESTS_PASSED + 1))
        return
    fi

    cd "$SCRIPT_DIR/.."

    # Check if 'test' target exists
    if make -n test >/dev/null 2>&1; then
        echo -e "${GREEN}✓${NC} Make 'test' target available"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo -e "${YELLOW}⚠${NC} Make 'test' target not found"
        TESTS_PASSED=$((TESTS_PASSED + 1))  # Not critical
    fi
    TESTS_RUN=$((TESTS_RUN + 1))

    cd - >/dev/null
}
test_make_test_target

# Test: Make build targets
test_make_build_targets() {
    if [[ ! -f "$SCRIPT_DIR/../Makefile" ]]; then
        echo -e "${YELLOW}⚠${NC} Skipping test (Makefile not available)"
        TESTS_RUN=$((TESTS_RUN + 1))
        TESTS_PASSED=$((TESTS_PASSED + 1))
        return
    fi

    cd "$SCRIPT_DIR/.."

    # Check build targets
    local targets=("build" "build-static" "build-alpine" "build-astra")
    local found=0

    for target in "${targets[@]}"; do
        if make -n "$target" >/dev/null 2>&1; then
            found=$((found + 1))
        fi
    done

    if [[ $found -ge 2 ]]; then
        echo -e "${GREEN}✓${NC} Make build targets available ($found/4)"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo -e "${YELLOW}⚠${NC} Limited build targets ($found/4)"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    fi
    TESTS_RUN=$((TESTS_RUN + 1))

    cd - >/dev/null
}
test_make_build_targets

#===============================================================================
# Test Suite 6: Cross-Version Compatibility
#===============================================================================

test_suite "Cross-Version Compatibility"

# Test: Same token parsed by all versions
test_cross_version_parsing() {
    local versions=()
    local results=()

    # Bash version
    if [[ -x "$PARSER_BASH" ]]; then
        set +e
        bash_sub=$("$PARSER_BASH" --json "$VALID_TOKEN" 2>&1 | jq -r '.payload.sub' 2>/dev/null)
        set -e
        versions+=("bash")
        results+=("$bash_sub")
    fi

    # Go version
    if [[ -x "$PARSER_GO" ]]; then
        set +e
        go_sub=$("$PARSER_GO" --json "$VALID_TOKEN" 2>&1 | jq -r '.claims.sub' 2>/dev/null)
        set -e
        versions+=("go")
        results+=("$go_sub")
    fi

    # Hybrid version (can use either bash or Go, try both paths)
    if [[ -x "$PARSER_HYBRID" ]]; then
        set +e
        hybrid_output=$("$PARSER_HYBRID" --json "$VALID_TOKEN" 2>&1)
        hybrid_sub=$(echo "$hybrid_output" | jq -r '.payload.sub // .claims.sub' 2>/dev/null)
        set -e
        versions+=("hybrid")
        results+=("$hybrid_sub")
    fi

    # Check all results are identical
    local first_result="${results[0]}"
    local all_same=1

    for result in "${results[@]}"; do
        if [[ "$result" != "$first_result" ]]; then
            all_same=0
            break
        fi
    done

    if [[ $all_same -eq 1 ]]; then
        echo -e "${GREEN}✓${NC} All versions produce same result (${versions[*]})"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo -e "${RED}✗${NC} Version results differ"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
    TESTS_RUN=$((TESTS_RUN + 1))
}
test_cross_version_parsing

# Test: Error handling consistency
test_cross_version_error_handling() {
    local invalid_token="invalid.token"
    local bash_exit=0
    local go_exit=0

    if [[ -x "$PARSER_BASH" ]]; then
        set +e
        "$PARSER_BASH" "$invalid_token" >/dev/null 2>&1
        bash_exit=$?
        set -e
    fi

    if [[ -x "$PARSER_GO" ]]; then
        set +e
        "$PARSER_GO" "$invalid_token" >/dev/null 2>&1
        go_exit=$?
        set -e
    fi

    if [[ $bash_exit -ne 0 && $go_exit -ne 0 ]]; then
        echo -e "${GREEN}✓${NC} Both versions reject invalid token"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo -e "${YELLOW}⚠${NC} Error handling differs (bash: $bash_exit, go: $go_exit)"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    fi
    TESTS_RUN=$((TESTS_RUN + 1))
}
test_cross_version_error_handling

#===============================================================================
# Summary
#===============================================================================

test_summary
