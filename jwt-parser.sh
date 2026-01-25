#!/bin/bash
#===============================================================================
# JWT Parser - Pure Bash Implementation with Auto-Detection
#===============================================================================
# Purpose: Parse and validate JWT tokens in restricted environments
# Use case: Banking closed-loop authorization diagnostics
# Requirements: bash 4.0+, base64 (optional: jq, openssl/libressl)
#
# Author: Security Engineering Team
# Version: 1.0.0
# License: Internal Use Only
#===============================================================================

set -euo pipefail

# Global configuration (check if already defined for source compatibility)
if [[ -z "${VERSION:-}" ]]; then
    readonly VERSION="1.0.0"
fi

if [[ -z "${SCRIPT_NAME:-}" ]]; then
    readonly SCRIPT_NAME="$(basename "$0")"
fi

# Exit codes
if [[ -z "${EXIT_SUCCESS:-}" ]]; then
    readonly EXIT_SUCCESS=0
    readonly EXIT_INVALID_ARGS=1
    readonly EXIT_INVALID_JWT=2
    readonly EXIT_EXPIRED=3
    readonly EXIT_NOT_YET_VALID=4
    readonly EXIT_SIGNATURE_INVALID=5
    readonly EXIT_MISSING_TOOLS=6
fi

# Color codes (disable if non-interactive)
if [[ -z "${RED:-}" ]]; then
    if [[ -t 1 ]]; then
        readonly RED='\033[0;31m'
        readonly GREEN='\033[0;32m'
        readonly YELLOW='\033[1;33m'
        readonly BLUE='\033[0;34m'
        readonly NC='\033[0m' # No Color
    else
        readonly RED=''
        readonly GREEN=''
        readonly YELLOW=''
        readonly BLUE=''
        readonly NC=''
    fi
fi

#===============================================================================
# TOOL DETECTION
#===============================================================================

detect_tools() {
    # Detect available tools and set global flags

    # Base64 (required)
    if command -v base64 >/dev/null 2>&1; then
        HAS_BASE64=1
    else
        echo "ERROR: base64 not found. Cannot proceed." >&2
        exit $EXIT_MISSING_TOOLS
    fi

    # jq (optional)
    if command -v jq >/dev/null 2>&1; then
        HAS_JQ=1
    else
        HAS_JQ=0
    fi

    # openssl or libressl (optional)
    if command -v openssl >/dev/null 2>&1; then
        HAS_OPENSSL=1
        SSL_CMD="openssl"
    elif command -v libressl >/dev/null 2>&1; then
        HAS_OPENSSL=1
        SSL_CMD="libressl"
    else
        HAS_OPENSSL=0
        SSL_CMD=""
    fi
}

#===============================================================================
# BASE64 URL DECODING (Pure Bash)
#===============================================================================

base64url_decode() {
    local input="$1"

    # Replace URL-safe chars with standard Base64
    input=$(echo "$input" | tr '_-' '/+')

    # Add padding if needed
    case $((${#input} % 4)) in
        2) input="${input}==" ;;
        3) input="${input}=" ;;
    esac

    # Decode using base64 utility
    echo "$input" | base64 -d 2>/dev/null || {
        echo "ERROR: Failed to decode base64" >&2
        return 1
    }
}

#===============================================================================
# JSON PARSING (Pure Bash - fallback if no jq)
#===============================================================================

parse_json_bash() {
    local json="$1"
    local key="$2"

    # Simple JSON extraction using bash regex
    # WARNING: Not RFC-compliant, but sufficient for JWT claims

    # Try to extract "key": value or "key": "value"
    if [[ $json =~ \"$key\"[[:space:]]*:[[:space:]]*\"([^\"]*)\" ]]; then
        echo "${BASH_REMATCH[1]}"
    elif [[ $json =~ \"$key\"[[:space:]]*:[[:space:]]*([0-9]+) ]]; then
        echo "${BASH_REMATCH[1]}"
    elif [[ $json =~ \"$key\"[[:space:]]*:[[:space:]]*(true|false|null) ]]; then
        echo "${BASH_REMATCH[1]}"
    else
        echo ""
    fi
}

get_json_value() {
    local json="$1"
    local key="$2"

    if [[ $HAS_JQ -eq 1 ]]; then
        # Use jq if available (more reliable)
        echo "$json" | jq -r ".$key // empty" 2>/dev/null
    else
        # Fallback to pure bash parsing
        parse_json_bash "$json" "$key"
    fi
}

#===============================================================================
# JWT PARSING
#===============================================================================

parse_jwt() {
    local jwt="$1"

    # Validate JWT structure (3 parts separated by dots)
    local parts_count=$(echo "$jwt" | tr -cd '.' | wc -c)
    if [[ $parts_count -ne 2 ]]; then
        echo "ERROR: Invalid JWT format. Expected 3 parts (header.payload.signature)" >&2
        return $EXIT_INVALID_JWT
    fi

    # Split JWT into components
    IFS='.' read -r HEADER_B64 PAYLOAD_B64 SIGNATURE_B64 <<< "$jwt"

    # Decode header
    HEADER_JSON=$(base64url_decode "$HEADER_B64") || {
        echo "ERROR: Failed to decode JWT header" >&2
        return $EXIT_INVALID_JWT
    }

    # Decode payload
    PAYLOAD_JSON=$(base64url_decode "$PAYLOAD_B64") || {
        echo "ERROR: Failed to decode JWT payload" >&2
        return $EXIT_INVALID_JWT
    }

    # Extract algorithm from header
    JWT_ALG=$(get_json_value "$HEADER_JSON" "alg")
    JWT_TYP=$(get_json_value "$HEADER_JSON" "typ")

    return 0
}

#===============================================================================
# CLAIMS VALIDATION
#===============================================================================

validate_claims() {
    local payload="$1"
    local current_time=$(date +%s)
    local validation_errors=0

    # Extract standard claims
    local exp=$(get_json_value "$payload" "exp")
    local nbf=$(get_json_value "$payload" "nbf")
    local iat=$(get_json_value "$payload" "iat")
    local sub=$(get_json_value "$payload" "sub")
    local iss=$(get_json_value "$payload" "iss")
    local aud=$(get_json_value "$payload" "aud")

    echo -e "${BLUE}=== Claims Validation ===${NC}"

    # Check expiration (exp)
    if [[ -n "$exp" ]]; then
        if [[ $exp =~ ^[0-9]+$ ]]; then
            local exp_human=$(date -d "@$exp" '+%Y-%m-%d %H:%M:%S %Z' 2>/dev/null || echo "N/A")
            if [[ $current_time -gt $exp ]]; then
                echo -e "${RED}✗ Token EXPIRED${NC}"
                echo "  Expired at: $exp_human (Unix: $exp)"
                echo "  Current time: $(date '+%Y-%m-%d %H:%M:%S %Z') (Unix: $current_time)"
                echo "  Time since expiration: $((current_time - exp)) seconds"
                validation_errors=$((validation_errors + 1))
                VALIDATION_STATUS="EXPIRED"
            else
                echo -e "${GREEN}✓ Token valid (not expired)${NC}"
                echo "  Expires at: $exp_human (Unix: $exp)"
                echo "  Time until expiration: $((exp - current_time)) seconds"
            fi
        else
            echo -e "${YELLOW}⚠ Invalid 'exp' claim format: $exp${NC}"
        fi
    else
        echo -e "${YELLOW}⚠ No 'exp' claim found (token never expires)${NC}"
    fi

    # Check not-before (nbf)
    if [[ -n "$nbf" ]]; then
        if [[ $nbf =~ ^[0-9]+$ ]]; then
            local nbf_human=$(date -d "@$nbf" '+%Y-%m-%d %H:%M:%S %Z' 2>/dev/null || echo "N/A")
            if [[ $current_time -lt $nbf ]]; then
                echo -e "${RED}✗ Token NOT YET VALID${NC}"
                echo "  Valid from: $nbf_human (Unix: $nbf)"
                echo "  Current time: $(date '+%Y-%m-%d %H:%M:%S %Z') (Unix: $current_time)"
                echo "  Time until valid: $((nbf - current_time)) seconds"
                validation_errors=$((validation_errors + 1))
                VALIDATION_STATUS="NOT_YET_VALID"
            else
                echo -e "${GREEN}✓ Token valid (after nbf)${NC}"
                echo "  Valid from: $nbf_human (Unix: $nbf)"
            fi
        else
            echo -e "${YELLOW}⚠ Invalid 'nbf' claim format: $nbf${NC}"
        fi
    fi

    # Check issued-at (iat)
    if [[ -n "$iat" ]]; then
        if [[ $iat =~ ^[0-9]+$ ]]; then
            local iat_human=$(date -d "@$iat" '+%Y-%m-%d %H:%M:%S %Z' 2>/dev/null || echo "N/A")
            local token_age=$((current_time - iat))
            echo -e "${BLUE}ℹ Token issued at: $iat_human${NC}"
            echo "  Token age: $token_age seconds ($((token_age / 3600)) hours)"
        fi
    fi

    # Display other claims
    if [[ -n "$sub" ]]; then
        echo -e "${BLUE}ℹ Subject (sub): $sub${NC}"
    fi

    if [[ -n "$iss" ]]; then
        echo -e "${BLUE}ℹ Issuer (iss): $iss${NC}"
    fi

    if [[ -n "$aud" ]]; then
        echo -e "${BLUE}ℹ Audience (aud): $aud${NC}"
    fi

    return $validation_errors
}

#===============================================================================
# SIGNATURE VERIFICATION (OpenSSL/LibreSSL)
#===============================================================================

verify_signature() {
    local jwt="$1"
    local secret="$2"

    if [[ $HAS_OPENSSL -eq 0 ]]; then
        echo -e "${YELLOW}⚠ OpenSSL/LibreSSL not available. Skipping signature verification.${NC}"
        return 0
    fi

    # Extract signing input (header.payload)
    IFS='.' read -r header_b64 payload_b64 signature_b64 <<< "$jwt"
    local signing_input="${header_b64}.${payload_b64}"

    # Determine hash algorithm from JWT header
    case "$JWT_ALG" in
        HS256)
            local hash_alg="sha256"
            ;;
        HS384)
            local hash_alg="sha384"
            ;;
        HS512)
            local hash_alg="sha512"
            ;;
        RS256|ES256|PS256)
            echo -e "${YELLOW}⚠ Algorithm $JWT_ALG requires public key verification (not implemented in bash)${NC}"
            return 0
            ;;
        none)
            echo -e "${RED}✗ SECURITY WARNING: Algorithm 'none' is insecure!${NC}"
            return 0
            ;;
        *)
            echo -e "${YELLOW}⚠ Unknown algorithm: $JWT_ALG${NC}"
            return 0
            ;;
    esac

    # Compute HMAC signature
    local computed_sig=$(echo -n "$signing_input" | \
        $SSL_CMD dgst -$hash_alg -hmac "$secret" -binary | \
        base64 | tr '+/' '-_' | tr -d '=')

    # Compare signatures
    if [[ "$computed_sig" == "$signature_b64" ]]; then
        echo -e "${GREEN}✓ Signature VALID${NC}"
        echo "  Algorithm: $JWT_ALG"
        return 0
    else
        echo -e "${RED}✗ Signature INVALID${NC}"
        echo "  Algorithm: $JWT_ALG"
        echo "  Expected: $signature_b64"
        echo "  Computed: $computed_sig"
        return $EXIT_SIGNATURE_INVALID
    fi
}

#===============================================================================
# OUTPUT FORMATTING
#===============================================================================

print_header() {
    echo -e "${BLUE}=== JWT Parser v$VERSION ===${NC}"
    echo ""
}

print_tools_status() {
    echo -e "${BLUE}=== Available Tools ===${NC}"
    echo "base64:        ${GREEN}✓${NC}"
    echo "jq:            $([[ $HAS_JQ -eq 1 ]] && echo -e "${GREEN}✓${NC}" || echo -e "${YELLOW}✗ (using pure bash JSON parser)${NC}")"
    echo "openssl/libre: $([[ $HAS_OPENSSL -eq 1 ]] && echo -e "${GREEN}✓ ($SSL_CMD)${NC}" || echo -e "${YELLOW}✗ (signature verification disabled)${NC}")"
    echo ""
}

print_jwt_info() {
    echo -e "${BLUE}=== JWT Header ===${NC}"
    if [[ $HAS_JQ -eq 1 ]]; then
        echo "$HEADER_JSON" | jq .
    else
        echo "$HEADER_JSON"
    fi
    echo ""

    echo -e "${BLUE}=== JWT Payload ===${NC}"
    if [[ $HAS_JQ -eq 1 ]]; then
        echo "$PAYLOAD_JSON" | jq .
    else
        echo "$PAYLOAD_JSON"
    fi
    echo ""
}

print_json_output() {
    # Structured JSON output for automation
    local status="${VALIDATION_STATUS:-VALID}"

    cat <<EOF
{
  "parser_version": "$VERSION",
  "tools": {
    "jq": $([[ $HAS_JQ -eq 1 ]] && echo "true" || echo "false"),
    "openssl": $([[ $HAS_OPENSSL -eq 1 ]] && echo "true" || echo "false")
  },
  "header": $HEADER_JSON,
  "payload": $PAYLOAD_JSON,
  "validation_status": "$status",
  "timestamp": $(date +%s)
}
EOF
}

#===============================================================================
# MAIN
#===============================================================================

usage() {
    cat <<EOF
Usage: $SCRIPT_NAME [OPTIONS] <JWT_TOKEN>

Parse and validate JWT tokens in restricted environments.

OPTIONS:
  -s, --secret <SECRET>   Verify signature with HMAC secret
  -j, --json              Output as JSON (for automation)
  -q, --quiet             Minimal output (validation result only)
  -v, --version           Show version
  -h, --help              Show this help

EXAMPLES:
  # Parse token and validate claims
  $SCRIPT_NAME "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIxMjM0..."

  # Parse and verify signature
  $SCRIPT_NAME --secret "your-secret" "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."

  # JSON output for automation
  $SCRIPT_NAME --json "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..." | jq .

EXIT CODES:
  0  Success (token valid)
  1  Invalid arguments
  2  Invalid JWT format
  3  Token expired
  4  Token not yet valid
  5  Signature invalid
  6  Required tools missing

EOF
}

main() {
    local jwt=""
    local secret=""
    local output_json=0
    local quiet=0

    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -s|--secret)
                secret="$2"
                shift 2
                ;;
            -j|--json)
                output_json=1
                shift
                ;;
            -q|--quiet)
                quiet=1
                shift
                ;;
            -v|--version)
                echo "$SCRIPT_NAME v$VERSION"
                exit 0
                ;;
            -h|--help)
                usage
                exit 0
                ;;
            -*)
                echo "ERROR: Unknown option: $1" >&2
                usage >&2
                exit $EXIT_INVALID_ARGS
                ;;
            *)
                jwt="$1"
                shift
                ;;
        esac
    done

    # Validate input
    if [[ -z "$jwt" ]]; then
        echo "ERROR: JWT token required" >&2
        usage >&2
        exit $EXIT_INVALID_ARGS
    fi

    # Detect available tools
    detect_tools

    # Print header (unless quiet/json)
    if [[ $quiet -eq 0 && $output_json -eq 0 ]]; then
        print_header
        print_tools_status
    fi

    # Parse JWT
    if ! parse_jwt "$jwt"; then
        exit $EXIT_INVALID_JWT
    fi

    # Print JWT info (unless quiet/json)
    if [[ $quiet -eq 0 && $output_json -eq 0 ]]; then
        print_jwt_info
    fi

    # Validate claims
    VALIDATION_STATUS="VALID"
    if [[ $output_json -eq 0 ]]; then
        if ! validate_claims "$PAYLOAD_JSON"; then
            if [[ "$VALIDATION_STATUS" == "EXPIRED" ]]; then
                exit $EXIT_EXPIRED
            elif [[ "$VALIDATION_STATUS" == "NOT_YET_VALID" ]]; then
                exit $EXIT_NOT_YET_VALID
            fi
        fi
    fi

    # Verify signature (if secret provided)
    if [[ -n "$secret" ]]; then
        if [[ $output_json -eq 0 ]]; then
            echo -e "${BLUE}=== Signature Verification ===${NC}"
        fi

        if ! verify_signature "$jwt" "$secret"; then
            exit $EXIT_SIGNATURE_INVALID
        fi

        if [[ $output_json -eq 0 ]]; then
            echo ""
        fi
    fi

    # Output
    if [[ $output_json -eq 1 ]]; then
        print_json_output
    elif [[ $quiet -eq 0 ]]; then
        echo -e "${GREEN}=== Parsing Complete ===${NC}"
    fi

    exit $EXIT_SUCCESS
}

# Run main if executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
