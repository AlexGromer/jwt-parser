#!/bin/bash
#===============================================================================
# Test Token Generator
#===============================================================================
# Purpose: Generate test JWT tokens for development and testing
# Requires: openssl, jq, base64
#===============================================================================

set -euo pipefail

# Configuration
SECRET="${JWT_SECRET:-my-bank-secret-key-2024}"
ALGORITHM="${JWT_ALGORITHM:-HS256}"
ISSUER="${JWT_ISSUER:-bank-auth-service}"
AUDIENCE="${JWT_AUDIENCE:-internal-api}"

# Generate timestamps
CURRENT_TIME=$(date +%s)
EXPIRES_IN="${JWT_EXPIRES_IN:-86400}"  # 24 hours default
EXP_TIME=$((CURRENT_TIME + EXPIRES_IN))

# User information
USER_ID="${1:-user123}"
USER_NAME="${2:-Test User}"

# Create payload
PAYLOAD=$(jq -n \
    --arg sub "$USER_ID" \
    --arg name "$USER_NAME" \
    --arg iss "$ISSUER" \
    --arg aud "$AUDIENCE" \
    --argjson iat "$CURRENT_TIME" \
    --argjson exp "$EXP_TIME" \
    '{
        sub: $sub,
        name: $name,
        iat: $iat,
        exp: $exp,
        iss: $iss,
        aud: $aud,
        roles: ["user", "viewer"]
    }')

# Create header
HEADER=$(jq -n \
    --arg alg "$ALGORITHM" \
    '{
        alg: $alg,
        typ: "JWT"
    }')

# Base64URL encoding function
base64url() {
    openssl base64 -e -A | tr '+/' '-_' | tr -d '='
}

# Encode header and payload
HEADER_B64=$(echo -n "$HEADER" | base64url)
PAYLOAD_B64=$(echo -n "$PAYLOAD" | base64url)

# Create signing input
SIGNING_INPUT="${HEADER_B64}.${PAYLOAD_B64}"

# Sign based on algorithm
case "$ALGORITHM" in
    HS256)
        SIGNATURE=$(echo -n "$SIGNING_INPUT" | openssl dgst -sha256 -hmac "$SECRET" -binary | base64url)
        ;;
    HS384)
        SIGNATURE=$(echo -n "$SIGNING_INPUT" | openssl dgst -sha384 -hmac "$SECRET" -binary | base64url)
        ;;
    HS512)
        SIGNATURE=$(echo -n "$SIGNING_INPUT" | openssl dgst -sha512 -hmac "$SECRET" -binary | base64url)
        ;;
    *)
        echo "ERROR: Unsupported algorithm: $ALGORITHM" >&2
        echo "Supported: HS256, HS384, HS512" >&2
        exit 1
        ;;
esac

# Complete JWT
JWT="${SIGNING_INPUT}.${SIGNATURE}"

# Output
echo "Generated JWT Token:"
echo ""
echo "$JWT"
echo ""
echo "Token Details:"
echo "  User: $USER_NAME ($USER_ID)"
echo "  Issued: $(date -d "@$CURRENT_TIME" '+%Y-%m-%d %H:%M:%S')"
echo "  Expires: $(date -d "@$EXP_TIME" '+%Y-%m-%d %H:%M:%S')"
echo "  Algorithm: $ALGORITHM"
echo "  Secret: $SECRET"
echo ""
echo "Verify with:"
echo "  ./jwt-parser.sh --secret \"$SECRET\" \"$JWT\""
