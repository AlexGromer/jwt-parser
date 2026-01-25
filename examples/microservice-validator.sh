#!/bin/bash
#===============================================================================
# Microservice Token Validator
#===============================================================================
# Purpose: Validate JWT tokens in microservice architecture
# Usage: ./microservice-validator.sh <JWT_TOKEN>
# Environment: JWT_SECRET must be set
#===============================================================================

set -euo pipefail

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly JWT_PARSER="$SCRIPT_DIR/jwt-parser-hybrid.sh"

# Check for secret
if [[ -z "${JWT_SECRET:-}" ]]; then
    echo "ERROR: JWT_SECRET environment variable not set" >&2
    exit 1
fi

TOKEN="${1:-}"

if [[ -z "$TOKEN" ]]; then
    echo "ERROR: JWT token required" >&2
    echo "Usage: $0 <JWT_TOKEN>" >&2
    exit 1
fi

# Validate token with signature verification
RESULT=$("$JWT_PARSER" --secret "$JWT_SECRET" --json "$TOKEN" 2>&1)
EXIT_CODE=$?

if [[ $EXIT_CODE -eq 0 ]]; then
    # Token valid - extract claims for application use
    USER_ID=$(echo "$RESULT" | jq -r '.claims.sub // "unknown"')
    ROLES=$(echo "$RESULT" | jq -r '.claims.roles // [] | join(",")')
    TENANT=$(echo "$RESULT" | jq -r '.claims.tenant // "default"')

    # Output for application consumption
    cat <<EOF
{
  "authenticated": true,
  "user_id": "$USER_ID",
  "roles": "$ROLES",
  "tenant": "$TENANT"
}
EOF

    exit 0
else
    # Token invalid
    STATUS=$(echo "$RESULT" | jq -r '.validation_status // "INVALID"')

    cat <<EOF
{
  "authenticated": false,
  "error": "$STATUS"
}
EOF

    exit $EXIT_CODE
fi
