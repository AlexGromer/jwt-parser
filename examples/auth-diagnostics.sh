#!/bin/bash
#===============================================================================
# Authorization Diagnostics Script
#===============================================================================
# Purpose: Periodic check of JWT token validity in closed banking network
# Usage: ./auth-diagnostics.sh <JWT_TOKEN>
#===============================================================================

set -euo pipefail

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly JWT_PARSER="$SCRIPT_DIR/jwt-parser.sh"
readonly LOG_FILE="/var/log/auth-diagnostics.log"

log() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOG_FILE"
}

TOKEN="${1:-}"

if [[ -z "$TOKEN" ]]; then
    echo "ERROR: JWT token required" >&2
    echo "Usage: $0 <JWT_TOKEN>" >&2
    exit 1
fi

log "Starting authorization diagnostics..."

# Parse token
RESULT=$("$JWT_PARSER" --json "$TOKEN" 2>&1)
EXIT_CODE=$?

STATUS=$(echo "$RESULT" | jq -r '.validation_status // "ERROR"')

log "Validation status: $STATUS (exit code: $EXIT_CODE)"

# Extract key information
if [[ $EXIT_CODE -eq 0 || $EXIT_CODE -eq 3 || $EXIT_CODE -eq 4 ]]; then
    SUBJECT=$(echo "$RESULT" | jq -r '.payload.sub // "N/A"')
    ISSUER=$(echo "$RESULT" | jq -r '.payload.iss // "N/A"')
    EXPIRES=$(echo "$RESULT" | jq -r '.payload.exp // "N/A"')

    log "  Subject: $SUBJECT"
    log "  Issuer: $ISSUER"
    log "  Expires: $EXPIRES"
fi

# Handle different statuses
case $EXIT_CODE in
    0)
        log "✓ Token is VALID - authorization OK"
        ;;
    3)
        log "✗ Token EXPIRED - user needs to re-authenticate"
        # Could trigger automatic notification here
        ;;
    4)
        log "✗ Token NOT YET VALID - clock skew or invalid token"
        ;;
    5)
        log "✗ SECURITY ALERT: Invalid signature detected!"
        # Could trigger security alert here
        ;;
    *)
        log "✗ Token validation failed with code $EXIT_CODE"
        ;;
esac

exit $EXIT_CODE
