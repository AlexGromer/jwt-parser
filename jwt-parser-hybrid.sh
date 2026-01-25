#!/bin/bash
#===============================================================================
# JWT Parser - Hybrid Orchestrator (Bash + Go)
#===============================================================================
# Purpose: Intelligent routing between bash and Go implementations
# Strategy:
#   - Use bash parser (minimal overhead) when possible
#   - Fallback to Go parser for signature verification (if no openssl)
#   - Fallback to Go parser for complex algorithms (RSA, ECDSA)
#
# Author: Security Engineering Team
# Version: 1.0.0
# License: Internal Use Only
#===============================================================================

set -euo pipefail

readonly VERSION="1.0.0-hybrid"
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly BASH_PARSER="$SCRIPT_DIR/jwt-parser.sh"
readonly GO_PARSER="$SCRIPT_DIR/jwt-parser-static"

# Exit codes
readonly EXIT_SUCCESS=0
readonly EXIT_INVALID_ARGS=1
readonly EXIT_NO_PARSER=10

# Color codes
if [[ -t 1 ]]; then
    readonly CYAN='\033[0;36m'
    readonly NC='\033[0m'
else
    readonly CYAN=''
    readonly NC=''
fi

#===============================================================================
# PARSER DETECTION
#===============================================================================

detect_parsers() {
    local parsers_found=0

    # Check bash parser
    if [[ -x "$BASH_PARSER" ]]; then
        HAS_BASH_PARSER=1
        parsers_found=$((parsers_found + 1))
    else
        HAS_BASH_PARSER=0
    fi

    # Check Go parser (try multiple names)
    if [[ -x "$GO_PARSER" ]]; then
        GO_PARSER_CMD="$GO_PARSER"
        HAS_GO_PARSER=1
        parsers_found=$((parsers_found + 1))
    elif [[ -x "$SCRIPT_DIR/jwt-parser-alpine" ]]; then
        GO_PARSER_CMD="$SCRIPT_DIR/jwt-parser-alpine"
        HAS_GO_PARSER=1
        parsers_found=$((parsers_found + 1))
    elif [[ -x "$SCRIPT_DIR/jwt-parser-astra" ]]; then
        GO_PARSER_CMD="$SCRIPT_DIR/jwt-parser-astra"
        HAS_GO_PARSER=1
        parsers_found=$((parsers_found + 1))
    elif [[ -x "$SCRIPT_DIR/jwt-parser" ]]; then
        GO_PARSER_CMD="$SCRIPT_DIR/jwt-parser"
        HAS_GO_PARSER=1
        parsers_found=$((parsers_found + 1))
    else
        HAS_GO_PARSER=0
    fi

    # Check for openssl/libressl
    if command -v openssl >/dev/null 2>&1; then
        HAS_OPENSSL=1
    elif command -v libressl >/dev/null 2>&1; then
        HAS_OPENSSL=1
    else
        HAS_OPENSSL=0
    fi

    if [[ $parsers_found -eq 0 ]]; then
        echo "ERROR: No JWT parser found!" >&2
        echo "Please build at least one parser:" >&2
        echo "  - Bash: jwt-parser.sh" >&2
        echo "  - Go:   make build-static" >&2
        exit $EXIT_NO_PARSER
    fi
}

#===============================================================================
# ALGORITHM DETECTION
#===============================================================================

detect_algorithm() {
    local jwt="$1"

    # Extract header (first part before first dot)
    local header_b64=$(echo "$jwt" | cut -d. -f1)

    # Decode header (simple base64url decode)
    header_b64=$(echo "$header_b64" | tr '_-' '/+')
    case $((${#header_b64} % 4)) in
        2) header_b64="${header_b64}==" ;;
        3) header_b64="${header_b64}=" ;;
    esac

    local header_json=$(echo "$header_b64" | base64 -d 2>/dev/null || echo "{}")

    # Extract algorithm using grep/sed (portable)
    local alg=$(echo "$header_json" | grep -o '"alg"[[:space:]]*:[[:space:]]*"[^"]*"' | sed 's/.*"\([^"]*\)".*/\1/')

    echo "$alg"
}

#===============================================================================
# ROUTING LOGIC
#===============================================================================

route_request() {
    local jwt="$1"
    local secret="$2"
    local has_secret=0

    [[ -n "$secret" ]] && has_secret=1

    # Detect algorithm
    local algorithm=$(detect_algorithm "$jwt")

    # Decision matrix
    local use_bash=0
    local reason=""

    # Rule 1: If no signature verification needed, prefer bash (faster)
    if [[ $has_secret -eq 0 ]]; then
        if [[ $HAS_BASH_PARSER -eq 1 ]]; then
            use_bash=1
            reason="No signature verification needed (bash is sufficient)"
        fi
    fi

    # Rule 2: If signature needed + openssl available, use bash
    if [[ $has_secret -eq 1 && $HAS_OPENSSL -eq 1 ]]; then
        case "$algorithm" in
            HS256|HS384|HS512)
                if [[ $HAS_BASH_PARSER -eq 1 ]]; then
                    use_bash=1
                    reason="HMAC algorithm + openssl available (bash can handle)"
                fi
                ;;
            RS256|RS384|RS512|ES256|ES384|ES512|PS256|PS384|PS512)
                if [[ $HAS_GO_PARSER -eq 1 ]]; then
                    use_bash=0
                    reason="RSA/ECDSA algorithm requires Go implementation"
                fi
                ;;
            none)
                use_bash=1
                reason="Algorithm 'none' (no verification, bash sufficient)"
                ;;
        esac
    fi

    # Rule 3: If signature needed but NO openssl, must use Go
    if [[ $has_secret -eq 1 && $HAS_OPENSSL -eq 0 ]]; then
        if [[ $HAS_GO_PARSER -eq 1 ]]; then
            use_bash=0
            reason="Signature verification needed but openssl missing (using Go)"
        else
            echo "WARNING: Signature verification requested but:" >&2
            echo "  - No openssl/libressl available" >&2
            echo "  - No Go parser available" >&2
            echo "  - Proceeding with bash (NO signature verification)" >&2
            use_bash=1
            secret=""  # Clear secret to skip verification
            reason="Fallback to bash without verification"
        fi
    fi

    # Rule 4: If only Go parser available, use it
    if [[ $HAS_BASH_PARSER -eq 0 && $HAS_GO_PARSER -eq 1 ]]; then
        use_bash=0
        reason="Only Go parser available"
    fi

    # Output routing decision
    if [[ "${ROUTING_VERBOSE:-0}" -eq 1 ]]; then
        echo -e "${CYAN}=== Routing Decision ===${NC}" >&2
        echo "Algorithm: $algorithm" >&2
        echo "Signature verification: $([[ $has_secret -eq 1 ]] && echo "YES" || echo "NO")" >&2
        echo "OpenSSL available: $([[ $HAS_OPENSSL -eq 1 ]] && echo "YES" || echo "NO")" >&2
        echo "Selected parser: $([[ $use_bash -eq 1 ]] && echo "BASH" || echo "GO")" >&2
        echo "Reason: $reason" >&2
        echo "" >&2
    fi

    # Return decision
    if [[ $use_bash -eq 1 ]]; then
        echo "bash:$secret"
    else
        echo "go:$secret"
    fi
}

#===============================================================================
# MAIN
#===============================================================================

usage() {
    cat <<EOF
Usage: $(basename "$0") [OPTIONS] <JWT_TOKEN>

Hybrid JWT parser - intelligent routing between bash and Go implementations.

OPTIONS:
  -s, --secret <SECRET>   Verify signature with HMAC secret
  -j, --json              Output as JSON (for automation)
  -q, --quiet             Minimal output
  -v, --verbose           Show routing decision
  --version               Show version
  -h, --help              Show this help

ROUTING STRATEGY:
  ✓ No signature needed          → Bash (fastest)
  ✓ HMAC + openssl available     → Bash (native)
  ✓ RSA/ECDSA algorithms         → Go (required)
  ✓ No openssl but Go available  → Go (fallback)
  ✓ No tools for verification    → Bash (skip verification)

EXAMPLES:
  # Parse token (auto-route to bash)
  $0 "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."

  # Verify signature (auto-route based on tools)
  $0 --secret "my-secret" "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."

  # Show routing decision
  $0 --verbose --secret "my-secret" "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."

AVAILABLE PARSERS:
  Bash: $([[ -x "$BASH_PARSER" ]] && echo "✓" || echo "✗") $BASH_PARSER
  Go:   $([[ $HAS_GO_PARSER -eq 1 ]] && echo "✓" || echo "✗") ${GO_PARSER_CMD:-Not found}

AUTHOR:
  Security Engineering Team

VERSION:
  $VERSION

EOF
}

main() {
    local jwt=""
    local secret=""
    local extra_args=()

    # Detect available parsers
    detect_parsers

    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -s|--secret)
                secret="$2"
                shift 2
                ;;
            -j|--json)
                extra_args+=("$1")
                shift
                ;;
            -q|--quiet)
                extra_args+=("$1")
                shift
                ;;
            -v|--verbose)
                ROUTING_VERBOSE=1
                shift
                ;;
            --version)
                echo "jwt-parser-hybrid v$VERSION"
                echo "Bash parser: $([[ $HAS_BASH_PARSER -eq 1 ]] && echo "available" || echo "missing")"
                echo "Go parser: $([[ $HAS_GO_PARSER -eq 1 ]] && echo "available" || echo "missing")"
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

    # Route request
    local routing_result=$(route_request "$jwt" "$secret")
    local parser=$(echo "$routing_result" | cut -d: -f1)
    local final_secret=$(echo "$routing_result" | cut -d: -f2-)

    # Execute selected parser
    case "$parser" in
        bash)
            if [[ -n "$final_secret" ]]; then
                exec "$BASH_PARSER" --secret "$final_secret" "${extra_args[@]}" "$jwt"
            else
                exec "$BASH_PARSER" "${extra_args[@]}" "$jwt"
            fi
            ;;
        go)
            if [[ -n "$final_secret" ]]; then
                exec "$GO_PARSER_CMD" -secret "$final_secret" "${extra_args[@]}" "$jwt"
            else
                exec "$GO_PARSER_CMD" "${extra_args[@]}" "$jwt"
            fi
            ;;
        *)
            echo "ERROR: Invalid routing decision: $parser" >&2
            exit $EXIT_INVALID_ARGS
            ;;
    esac
}

# Run main if executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
