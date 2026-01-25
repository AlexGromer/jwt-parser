package main

import (
	"crypto/rsa"
	"crypto/x509"
	"encoding/json"
	"encoding/pem"
	"flag"
	"fmt"
	"os"
	"time"

	"github.com/golang-jwt/jwt/v5"
)

// Exit codes (matching bash version)
const (
	ExitSuccess         = 0
	ExitInvalidArgs     = 1
	ExitInvalidJWT      = 2
	ExitExpired         = 3
	ExitNotYetValid     = 4
	ExitSignatureInvalid = 5
	ExitMissingTools    = 6
)

// Version information
const Version = "1.0.0"

// Color codes
const (
	ColorRed    = "\033[0;31m"
	ColorGreen  = "\033[0;32m"
	ColorYellow = "\033[1;33m"
	ColorBlue   = "\033[0;34m"
	ColorReset  = "\033[0m"
)

// OutputFormat represents the output format type
type OutputFormat string

const (
	OutputFormatHuman OutputFormat = "human"
	OutputFormatJSON  OutputFormat = "json"
)

// JWTParser handles JWT parsing and validation
type JWTParser struct {
	Secret       []byte
	PublicKey    *rsa.PublicKey
	OutputFormat OutputFormat
	Quiet        bool
	VerifySignature bool
}

// ParseResult contains the parsed JWT information
type ParseResult struct {
	ParserVersion    string                 `json:"parser_version"`
	Header           map[string]interface{} `json:"header"`
	Claims           jwt.MapClaims          `json:"claims"`
	ValidationStatus string                 `json:"validation_status"`
	ValidationErrors []string               `json:"validation_errors,omitempty"`
	Timestamp        int64                  `json:"timestamp"`
	Algorithm        string                 `json:"algorithm"`
	IssuedAt         *time.Time             `json:"issued_at,omitempty"`
	ExpiresAt        *time.Time             `json:"expires_at,omitempty"`
	NotBefore        *time.Time             `json:"not_before,omitempty"`
	Subject          string                 `json:"subject,omitempty"`
	Issuer           string                 `json:"issuer,omitempty"`
	Audience         []string               `json:"audience,omitempty"`
}

// NewJWTParser creates a new JWT parser instance
func NewJWTParser() *JWTParser {
	return &JWTParser{
		OutputFormat: OutputFormatHuman,
		VerifySignature: false,
	}
}

// SetSecret sets the HMAC secret for signature verification
func (p *JWTParser) SetSecret(secret string) {
	p.Secret = []byte(secret)
	p.VerifySignature = true
}

// SetPublicKey sets the RSA public key for signature verification
func (p *JWTParser) SetPublicKey(keyPath string) error {
	keyData, err := os.ReadFile(keyPath)
	if err != nil {
		return fmt.Errorf("failed to read public key: %w", err)
	}

	block, _ := pem.Decode(keyData)
	if block == nil {
		return fmt.Errorf("failed to decode PEM block")
	}

	pub, err := x509.ParsePKIXPublicKey(block.Bytes)
	if err != nil {
		return fmt.Errorf("failed to parse public key: %w", err)
	}

	rsaPub, ok := pub.(*rsa.PublicKey)
	if !ok {
		return fmt.Errorf("key is not RSA public key")
	}

	p.PublicKey = rsaPub
	p.VerifySignature = true
	return nil
}

// Parse parses and validates a JWT token
func (p *JWTParser) Parse(tokenString string) (*ParseResult, error) {
	result := &ParseResult{
		ParserVersion:    Version,
		Timestamp:        time.Now().Unix(),
		ValidationStatus: "VALID",
		ValidationErrors: []string{},
	}

	// Parse without verification first to extract claims
	parser := jwt.NewParser(jwt.WithoutClaimsValidation())
	token, _, err := parser.ParseUnverified(tokenString, jwt.MapClaims{})
	if err != nil {
		return nil, fmt.Errorf("invalid JWT format: %w", err)
	}

	// Extract header
	result.Header = token.Header
	if alg, ok := token.Header["alg"].(string); ok {
		result.Algorithm = alg
	}

	// Extract claims
	claims, ok := token.Claims.(jwt.MapClaims)
	if !ok {
		return nil, fmt.Errorf("failed to extract claims")
	}
	result.Claims = claims

	// Extract standard claims
	if sub, ok := claims["sub"].(string); ok {
		result.Subject = sub
	}

	if iss, ok := claims["iss"].(string); ok {
		result.Issuer = iss
	}

	// Handle audience (can be string or array)
	if aud, ok := claims["aud"]; ok {
		switch v := aud.(type) {
		case string:
			result.Audience = []string{v}
		case []interface{}:
			for _, item := range v {
				if audStr, ok := item.(string); ok {
					result.Audience = append(result.Audience, audStr)
				}
			}
		}
	}

	// Extract time claims
	if iat, err := claims.GetIssuedAt(); err == nil && iat != nil {
		issuedAt := iat.Time
		result.IssuedAt = &issuedAt
	}

	if exp, err := claims.GetExpirationTime(); err == nil && exp != nil {
		expiresAt := exp.Time
		result.ExpiresAt = &expiresAt
	}

	if nbf, err := claims.GetNotBefore(); err == nil && nbf != nil {
		notBefore := nbf.Time
		result.NotBefore = &notBefore
	}

	// Validate claims timing
	now := time.Now()

	// Check expiration
	if result.ExpiresAt != nil {
		if now.After(*result.ExpiresAt) {
			result.ValidationStatus = "EXPIRED"
			result.ValidationErrors = append(result.ValidationErrors,
				fmt.Sprintf("Token expired at %s (current time: %s)",
					result.ExpiresAt.Format(time.RFC3339),
					now.Format(time.RFC3339)))
		}
	}

	// Check not-before
	if result.NotBefore != nil {
		if now.Before(*result.NotBefore) {
			result.ValidationStatus = "NOT_YET_VALID"
			result.ValidationErrors = append(result.ValidationErrors,
				fmt.Sprintf("Token not valid until %s (current time: %s)",
					result.NotBefore.Format(time.RFC3339),
					now.Format(time.RFC3339)))
		}
	}

	// Verify signature if requested
	if p.VerifySignature {
		if err := p.verifySignature(tokenString, result); err != nil {
			result.ValidationStatus = "SIGNATURE_INVALID"
			result.ValidationErrors = append(result.ValidationErrors,
				fmt.Sprintf("Signature verification failed: %s", err))
		}
	}

	return result, nil
}

// verifySignature verifies the JWT signature
func (p *JWTParser) verifySignature(tokenString string, result *ParseResult) error {
	var keyFunc jwt.Keyfunc

	// Determine verification method based on algorithm
	alg := result.Algorithm

	switch {
	case alg == "HS256" || alg == "HS384" || alg == "HS512":
		if p.Secret == nil {
			return fmt.Errorf("HMAC secret required for algorithm %s", alg)
		}
		keyFunc = func(token *jwt.Token) (interface{}, error) {
			return p.Secret, nil
		}

	case alg == "RS256" || alg == "RS384" || alg == "RS512":
		if p.PublicKey == nil {
			return fmt.Errorf("RSA public key required for algorithm %s", alg)
		}
		keyFunc = func(token *jwt.Token) (interface{}, error) {
			return p.PublicKey, nil
		}

	case alg == "none":
		return fmt.Errorf("SECURITY WARNING: algorithm 'none' is insecure")

	default:
		return fmt.Errorf("unsupported algorithm: %s", alg)
	}

	// Parse and verify
	_, err := jwt.Parse(tokenString, keyFunc)
	return err
}

// PrintHuman prints the result in human-readable format
func (p *JWTParser) PrintHuman(result *ParseResult) {
	if p.Quiet {
		fmt.Println(result.ValidationStatus)
		return
	}

	fmt.Printf("%s=== JWT Parser v%s ===%s\n\n", ColorBlue, Version, ColorReset)

	// Header
	fmt.Printf("%s=== JWT Header ===%s\n", ColorBlue, ColorReset)
	headerJSON, _ := json.MarshalIndent(result.Header, "", "  ")
	fmt.Println(string(headerJSON))
	fmt.Println()

	// Claims
	fmt.Printf("%s=== JWT Claims ===%s\n", ColorBlue, ColorReset)
	claimsJSON, _ := json.MarshalIndent(result.Claims, "", "  ")
	fmt.Println(string(claimsJSON))
	fmt.Println()

	// Validation
	fmt.Printf("%s=== Claims Validation ===%s\n", ColorBlue, ColorReset)

	// Expiration
	if result.ExpiresAt != nil {
		if result.ValidationStatus == "EXPIRED" {
			fmt.Printf("%s✗ Token EXPIRED%s\n", ColorRed, ColorReset)
			fmt.Printf("  Expired at: %s\n", result.ExpiresAt.Format(time.RFC3339))
			fmt.Printf("  Time since expiration: %s\n", time.Since(*result.ExpiresAt))
		} else {
			fmt.Printf("%s✓ Token valid (not expired)%s\n", ColorGreen, ColorReset)
			fmt.Printf("  Expires at: %s\n", result.ExpiresAt.Format(time.RFC3339))
			fmt.Printf("  Time until expiration: %s\n", time.Until(*result.ExpiresAt))
		}
	} else {
		fmt.Printf("%s⚠ No expiration claim (token never expires)%s\n", ColorYellow, ColorReset)
	}

	// Not Before
	if result.NotBefore != nil {
		if result.ValidationStatus == "NOT_YET_VALID" {
			fmt.Printf("%s✗ Token NOT YET VALID%s\n", ColorRed, ColorReset)
			fmt.Printf("  Valid from: %s\n", result.NotBefore.Format(time.RFC3339))
			fmt.Printf("  Time until valid: %s\n", time.Until(*result.NotBefore))
		} else {
			fmt.Printf("%s✓ Token valid (after nbf)%s\n", ColorGreen, ColorReset)
			fmt.Printf("  Valid from: %s\n", result.NotBefore.Format(time.RFC3339))
		}
	}

	// Issued At
	if result.IssuedAt != nil {
		fmt.Printf("%sℹ Token issued at: %s%s\n", ColorBlue,
			result.IssuedAt.Format(time.RFC3339), ColorReset)
		fmt.Printf("  Token age: %s\n", time.Since(*result.IssuedAt))
	}

	// Other claims
	if result.Subject != "" {
		fmt.Printf("%sℹ Subject (sub): %s%s\n", ColorBlue, result.Subject, ColorReset)
	}

	if result.Issuer != "" {
		fmt.Printf("%sℹ Issuer (iss): %s%s\n", ColorBlue, result.Issuer, ColorReset)
	}

	if len(result.Audience) > 0 {
		fmt.Printf("%sℹ Audience (aud): %v%s\n", ColorBlue, result.Audience, ColorReset)
	}

	// Signature verification result
	if p.VerifySignature {
		fmt.Println()
		fmt.Printf("%s=== Signature Verification ===%s\n", ColorBlue, ColorReset)
		if result.ValidationStatus == "SIGNATURE_INVALID" {
			fmt.Printf("%s✗ Signature INVALID%s\n", ColorRed, ColorReset)
			fmt.Printf("  Algorithm: %s\n", result.Algorithm)
		} else {
			fmt.Printf("%s✓ Signature VALID%s\n", ColorGreen, ColorReset)
			fmt.Printf("  Algorithm: %s\n", result.Algorithm)
		}
	}

	// Validation errors
	if len(result.ValidationErrors) > 0 {
		fmt.Println()
		fmt.Printf("%s=== Validation Errors ===%s\n", ColorRed, ColorReset)
		for _, err := range result.ValidationErrors {
			fmt.Printf("  - %s\n", err)
		}
	}

	// Summary
	fmt.Println()
	statusColor := ColorGreen
	if result.ValidationStatus != "VALID" {
		statusColor = ColorRed
	}
	fmt.Printf("%s=== Status: %s ===%s\n", statusColor, result.ValidationStatus, ColorReset)
}

// PrintJSON prints the result in JSON format
func (p *JWTParser) PrintJSON(result *ParseResult) error {
	encoder := json.NewEncoder(os.Stdout)
	encoder.SetIndent("", "  ")
	return encoder.Encode(result)
}

func main() {
	// Command-line flags
	var (
		secret     = flag.String("secret", "", "HMAC secret for signature verification")
		secretEnv  = flag.String("secret-env", "", "Environment variable containing HMAC secret")
		publicKey  = flag.String("public-key", "", "Path to RSA public key for signature verification")
		jsonOutput = flag.Bool("json", false, "Output as JSON")
		quiet      = flag.Bool("quiet", false, "Quiet mode (minimal output)")
		version    = flag.Bool("version", false, "Show version")
		help       = flag.Bool("help", false, "Show help")
	)

	flag.Parse()

	// Handle version flag
	if *version {
		fmt.Printf("jwt-parser v%s\n", Version)
		os.Exit(ExitSuccess)
	}

	// Handle help flag
	if *help {
		printUsage()
		os.Exit(ExitSuccess)
	}

	// Get JWT token from arguments
	args := flag.Args()
	if len(args) == 0 {
		fmt.Fprintln(os.Stderr, "ERROR: JWT token required")
		printUsage()
		os.Exit(ExitInvalidArgs)
	}

	tokenString := args[0]

	// Create parser
	parser := NewJWTParser()

	// Set output format
	if *jsonOutput {
		parser.OutputFormat = OutputFormatJSON
	}

	parser.Quiet = *quiet

	// Set secret for verification
	if *secretEnv != "" {
		secretValue := os.Getenv(*secretEnv)
		if secretValue == "" {
			fmt.Fprintf(os.Stderr, "ERROR: Environment variable %s is empty\n", *secretEnv)
			os.Exit(ExitInvalidArgs)
		}
		parser.SetSecret(secretValue)
	} else if *secret != "" {
		parser.SetSecret(*secret)
	}

	// Set public key for verification
	if *publicKey != "" {
		if err := parser.SetPublicKey(*publicKey); err != nil {
			fmt.Fprintf(os.Stderr, "ERROR: %s\n", err)
			os.Exit(ExitInvalidArgs)
		}
	}

	// Parse JWT
	result, err := parser.Parse(tokenString)
	if err != nil {
		fmt.Fprintf(os.Stderr, "ERROR: %s\n", err)
		os.Exit(ExitInvalidJWT)
	}

	// Output result
	if parser.OutputFormat == OutputFormatJSON {
		if err := parser.PrintJSON(result); err != nil {
			fmt.Fprintf(os.Stderr, "ERROR: Failed to output JSON: %s\n", err)
			os.Exit(ExitInvalidArgs)
		}
	} else {
		parser.PrintHuman(result)
	}

	// Exit with appropriate code
	switch result.ValidationStatus {
	case "VALID":
		os.Exit(ExitSuccess)
	case "EXPIRED":
		os.Exit(ExitExpired)
	case "NOT_YET_VALID":
		os.Exit(ExitNotYetValid)
	case "SIGNATURE_INVALID":
		os.Exit(ExitSignatureInvalid)
	default:
		os.Exit(ExitInvalidJWT)
	}
}

func printUsage() {
	fmt.Println(`Usage: jwt-parser [OPTIONS] <JWT_TOKEN>

Parse and validate JWT tokens with full algorithm support.

OPTIONS:
  -secret <SECRET>           HMAC secret for signature verification
  -secret-env <VAR>          Environment variable containing HMAC secret
  -public-key <PATH>         Path to RSA public key file
  -json                      Output as JSON (for automation)
  -quiet                     Minimal output (validation result only)
  -version                   Show version
  -help                      Show this help

EXAMPLES:
  # Parse token and validate claims
  jwt-parser "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIxMjM0..."

  # Parse and verify HMAC signature
  jwt-parser -secret "your-secret" "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."

  # Parse and verify RSA signature
  jwt-parser -public-key /path/to/public.pem "eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9..."

  # Use secret from environment variable
  export JWT_SECRET="your-secret"
  jwt-parser -secret-env JWT_SECRET "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."

  # JSON output for automation
  jwt-parser -json "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..." | jq .

SUPPORTED ALGORITHMS:
  HMAC:  HS256, HS384, HS512
  RSA:   RS256, RS384, RS512
  ECDSA: ES256, ES384, ES512

EXIT CODES:
  0  Success (token valid)
  1  Invalid arguments
  2  Invalid JWT format
  3  Token expired
  4  Token not yet valid
  5  Signature invalid
  6  Required tools missing

AUTHOR:
  Security Engineering Team

VERSION:
  ` + Version)
}
