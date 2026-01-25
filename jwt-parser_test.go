package main

import (
	"strings"
	"testing"
	"time"

	"github.com/golang-jwt/jwt/v5"
)

// Test helper: create test token
func createTestToken(t *testing.T, secret string, claims map[string]interface{}) string {
	t.Helper()

	token := jwt.NewWithClaims(jwt.SigningMethodHS256, jwt.MapClaims(claims))
	tokenString, err := token.SignedString([]byte(secret))
	if err != nil {
		t.Fatalf("Failed to create test token: %v", err)
	}
	return tokenString
}

//===============================================================================
// Test Suite 1: JWT Parsing
//===============================================================================

func TestParse_ValidToken(t *testing.T) {
	secret := "test-secret"
	claims := map[string]interface{}{
		"sub":  "user123",
		"name": "Test User",
		"iat":  time.Now().Unix(),
		"exp":  time.Now().Add(24 * time.Hour).Unix(),
	}

	tokenString := createTestToken(t, secret, claims)

	parser := NewJWTParser()
	result, err := parser.Parse(tokenString)

	if err != nil {
		t.Fatalf("Parse failed: %v", err)
	}

	if result.Subject != "user123" {
		t.Errorf("Expected subject 'user123', got '%s'", result.Subject)
	}

	if result.Algorithm != "HS256" {
		t.Errorf("Expected algorithm 'HS256', got '%s'", result.Algorithm)
	}
}

func TestParse_InvalidToken(t *testing.T) {
	parser := NewJWTParser()

	tests := []struct {
		name  string
		token string
	}{
		{"Empty token", ""},
		{"Only two parts", "header.payload"},
		{"Four parts", "a.b.c.d"},
		{"Invalid base64", "invalid!@#$.token!@#$.here!@#$"},
		{"Malformed header", "not-base64.eyJzdWIiOiJ0ZXN0In0.sig"},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			_, err := parser.Parse(tt.token)
			if err == nil {
				t.Errorf("Expected error for %s, got nil", tt.name)
			}
		})
	}
}

func TestParse_TokenStructure(t *testing.T) {
	secret := "test-secret"
	claims := map[string]interface{}{
		"sub": "test-user",
		"iss": "test-issuer",
		"aud": "test-audience",
		"exp": time.Now().Add(1 * time.Hour).Unix(),
		"nbf": time.Now().Unix(),
		"iat": time.Now().Unix(),
	}

	tokenString := createTestToken(t, secret, claims)

	parser := NewJWTParser()
	result, err := parser.Parse(tokenString)

	if err != nil {
		t.Fatalf("Parse failed: %v", err)
	}

	// Check all expected fields
	if result.Subject != "test-user" {
		t.Errorf("Subject mismatch: got %s", result.Subject)
	}

	if result.Issuer != "test-issuer" {
		t.Errorf("Issuer mismatch: got %s", result.Issuer)
	}

	if len(result.Audience) == 0 || result.Audience[0] != "test-audience" {
		t.Errorf("Audience mismatch: got %v", result.Audience)
	}
}

//===============================================================================
// Test Suite 2: Signature Verification
//===============================================================================

func TestVerifySignature_ValidHMAC(t *testing.T) {
	secret := "test-secret"
	claims := map[string]interface{}{
		"sub": "user123",
		"exp": time.Now().Add(1 * time.Hour).Unix(),
	}

	tokenString := createTestToken(t, secret, claims)

	parser := NewJWTParser()
	parser.Secret = []byte(secret)
	parser.VerifySignature = true
	result, err := parser.Parse(tokenString)

	if err != nil {
		t.Fatalf("Parse failed: %v", err)
	}

	// Verify signature
	err = parser.verifySignature(tokenString, result)
	if err != nil {
		t.Errorf("Signature verification failed: %v", err)
	}
}

func TestVerifySignature_InvalidSecret(t *testing.T) {
	secret := "correct-secret"
	claims := map[string]interface{}{
		"sub": "user123",
		"exp": time.Now().Add(1 * time.Hour).Unix(),
	}

	tokenString := createTestToken(t, secret, claims)

	// Try to verify with wrong secret
	parser := NewJWTParser()
	parser.Secret = []byte("wrong-secret")
	parser.VerifySignature = true
	result, err := parser.Parse(tokenString)

	if err != nil {
		t.Fatalf("Parse failed: %v", err)
	}

	err = parser.verifySignature(tokenString, result)
	if err == nil {
		t.Error("Expected signature verification to fail with wrong secret")
	}
}

func TestVerifySignature_AlgorithmNone(t *testing.T) {
	// Create token with algorithm "none" using real base64 encoding
	token := jwt.NewWithClaims(jwt.SigningMethodNone, jwt.MapClaims{"sub": "test"})
	tokenString, err := token.SignedString(jwt.UnsafeAllowNoneSignatureType)

	if err != nil {
		t.Fatalf("Failed to create 'none' token: %v", err)
	}

	parser := NewJWTParser()
	result, err := parser.Parse(tokenString)

	if err != nil {
		t.Fatalf("Parse failed: %v", err)
	}

	if result.Algorithm != "none" {
		t.Errorf("Expected algorithm 'none', got '%s'", result.Algorithm)
	}

	// Should return security warning for "none" algorithm
	err = parser.verifySignature(tokenString, result)
	if err == nil {
		t.Error("Expected security warning for 'none' algorithm, got nil")
	} else if !strings.Contains(err.Error(), "none") {
		t.Errorf("Expected 'none' algorithm warning, got: %v", err)
	}
}

//===============================================================================
// Test Suite 3: Claims Validation
//===============================================================================

func TestValidateClaims_ExpiredToken(t *testing.T) {
	secret := "test-secret"
	claims := map[string]interface{}{
		"sub": "user123",
		"exp": time.Now().Add(-1 * time.Hour).Unix(), // Expired 1 hour ago
	}

	tokenString := createTestToken(t, secret, claims)

	parser := NewJWTParser()
	result, err := parser.Parse(tokenString)

	if err != nil {
		t.Fatalf("Parse failed: %v", err)
	}

	if result.ValidationStatus != "EXPIRED" {
		t.Errorf("Expected status 'EXPIRED', got '%s'", result.ValidationStatus)
	}
}

func TestValidateClaims_NotYetValid(t *testing.T) {
	secret := "test-secret"
	claims := map[string]interface{}{
		"sub": "user123",
		"nbf": time.Now().Add(1 * time.Hour).Unix(), // Valid in 1 hour
		"exp": time.Now().Add(2 * time.Hour).Unix(),
	}

	tokenString := createTestToken(t, secret, claims)

	parser := NewJWTParser()
	result, err := parser.Parse(tokenString)

	if err != nil {
		t.Fatalf("Parse failed: %v", err)
	}

	if result.ValidationStatus != "NOT_YET_VALID" {
		t.Errorf("Expected status 'NOT_YET_VALID', got '%s'", result.ValidationStatus)
	}
}

func TestValidateClaims_ValidToken(t *testing.T) {
	secret := "test-secret"
	now := time.Now()
	claims := map[string]interface{}{
		"sub": "user123",
		"iat": now.Unix(),
		"nbf": now.Unix(),
		"exp": now.Add(1 * time.Hour).Unix(),
	}

	tokenString := createTestToken(t, secret, claims)

	parser := NewJWTParser()
	result, err := parser.Parse(tokenString)

	if err != nil {
		t.Fatalf("Parse failed: %v", err)
	}

	if result.ValidationStatus != "VALID" {
		t.Errorf("Expected status 'VALID', got '%s'", result.ValidationStatus)
	}
}

func TestValidateClaims_NoExpiration(t *testing.T) {
	secret := "test-secret"
	claims := map[string]interface{}{
		"sub": "user123",
	}

	tokenString := createTestToken(t, secret, claims)

	parser := NewJWTParser()
	result, err := parser.Parse(tokenString)

	if err != nil {
		t.Fatalf("Parse failed: %v", err)
	}

	// Token without exp should still be valid
	if result.ValidationStatus != "VALID" {
		t.Errorf("Expected status 'VALID' for token without exp, got '%s'", result.ValidationStatus)
	}
}

//===============================================================================
// Test Suite 4: JSON Output
//===============================================================================

func TestJSONOutput_Structure(t *testing.T) {
	secret := "test-secret"
	claims := map[string]interface{}{
		"sub":  "user123",
		"name": "Test User",
		"exp":  time.Now().Add(1 * time.Hour).Unix(),
	}

	tokenString := createTestToken(t, secret, claims)

	parser := NewJWTParser()
	result, err := parser.Parse(tokenString)

	if err != nil {
		t.Fatalf("Parse failed: %v", err)
	}

	// Verify ParseResult has required fields
	if result.ParserVersion == "" {
		t.Error("Missing ParserVersion")
	}

	if result.ValidationStatus == "" {
		t.Error("Missing ValidationStatus")
	}

	if result.Timestamp == 0 {
		t.Error("Missing Timestamp")
	}

	if result.Algorithm == "" {
		t.Error("Missing Algorithm")
	}
}

func TestJSONOutput_ClaimsPresence(t *testing.T) {
	secret := "test-secret"
	claims := map[string]interface{}{
		"sub":  "user123",
		"name": "Test User",
		"role": "admin",
	}

	tokenString := createTestToken(t, secret, claims)

	parser := NewJWTParser()
	result, err := parser.Parse(tokenString)

	if err != nil {
		t.Fatalf("Parse failed: %v", err)
	}

	// Check that custom claims are preserved
	if result.Subject != "user123" {
		t.Error("Result missing subject claim")
	}

	// Check if custom claims exist in raw Claims map
	if nameVal, ok := result.Claims["name"]; !ok || nameVal != "Test User" {
		t.Error("Result missing name claim")
	}

	if roleVal, ok := result.Claims["role"]; !ok || roleVal != "admin" {
		t.Error("Result missing custom role claim")
	}
}

//===============================================================================
// Test Suite 5: Edge Cases
//===============================================================================

func TestParse_LargePayload(t *testing.T) {
	secret := "test-secret"

	// Create large payload (5KB)
	largeString := strings.Repeat("A", 5000)
	claims := map[string]interface{}{
		"sub":  "user123",
		"data": largeString,
		"exp":  time.Now().Add(1 * time.Hour).Unix(),
	}

	tokenString := createTestToken(t, secret, claims)

	parser := NewJWTParser()
	result, err := parser.Parse(tokenString)

	if err != nil {
		t.Fatalf("Failed to parse large token: %v", err)
	}

	if result.Subject != "user123" {
		t.Error("Subject not preserved in large token")
	}
}

func TestParse_UnicodeInClaims(t *testing.T) {
	secret := "test-secret"
	claims := map[string]interface{}{
		"sub":  "иванов",
		"name": "Иван Петрович",
		"city": "Москва",
		"exp":  time.Now().Add(1 * time.Hour).Unix(),
	}

	tokenString := createTestToken(t, secret, claims)

	parser := NewJWTParser()
	result, err := parser.Parse(tokenString)

	if err != nil {
		t.Fatalf("Failed to parse token with Unicode: %v", err)
	}

	if result.Subject != "иванов" {
		t.Errorf("Unicode subject not preserved: got %s", result.Subject)
	}
}

func TestParse_SpecialCharacters(t *testing.T) {
	secret := "test-secret"
	claims := map[string]interface{}{
		"sub":   "user@example.com",
		"email": "test+tag@example.com",
		"desc":  "Token with special chars: <>&\"'",
		"exp":   time.Now().Add(1 * time.Hour).Unix(),
	}

	tokenString := createTestToken(t, secret, claims)

	parser := NewJWTParser()
	result, err := parser.Parse(tokenString)

	if err != nil {
		t.Fatalf("Failed to parse token with special chars: %v", err)
	}

	if result.Subject != "user@example.com" {
		t.Errorf("Special characters in subject not preserved: got %s", result.Subject)
	}
}

//===============================================================================
// Test Suite 6: Algorithm Support
//===============================================================================

func TestParse_HS256(t *testing.T) {
	secret := "test-secret"
	token := jwt.NewWithClaims(jwt.SigningMethodHS256, jwt.MapClaims{"sub": "test"})
	tokenString, _ := token.SignedString([]byte(secret))

	parser := NewJWTParser()
	result, err := parser.Parse(tokenString)

	if err != nil {
		t.Fatalf("Parse failed: %v", err)
	}

	if result.Algorithm != "HS256" {
		t.Errorf("Expected algorithm HS256, got %s", result.Algorithm)
	}
}

func TestParse_HS384(t *testing.T) {
	secret := "test-secret"
	token := jwt.NewWithClaims(jwt.SigningMethodHS384, jwt.MapClaims{"sub": "test"})
	tokenString, _ := token.SignedString([]byte(secret))

	parser := NewJWTParser()
	result, err := parser.Parse(tokenString)

	if err != nil {
		t.Fatalf("Parse failed: %v", err)
	}

	if result.Algorithm != "HS384" {
		t.Errorf("Expected algorithm HS384, got %s", result.Algorithm)
	}
}

func TestParse_HS512(t *testing.T) {
	secret := "test-secret"
	token := jwt.NewWithClaims(jwt.SigningMethodHS512, jwt.MapClaims{"sub": "test"})
	tokenString, _ := token.SignedString([]byte(secret))

	parser := NewJWTParser()
	result, err := parser.Parse(tokenString)

	if err != nil {
		t.Fatalf("Parse failed: %v", err)
	}

	if result.Algorithm != "HS512" {
		t.Errorf("Expected algorithm HS512, got %s", result.Algorithm)
	}
}

