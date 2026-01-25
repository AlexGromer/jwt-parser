# JWT Parser - Development Roadmap

**Current Version:** 1.0.0
**Status:** Production Ready (131/131 tests passing)
**Last Updated:** 2026-01-25

---

## 🎯 Vision

Transform the hybrid router from a simple **delegation system** into a true **orchestrator** that intelligently combines the strengths of both Bash and Go implementations for optimal performance and flexibility.

---

## 📊 Current State Analysis

### Hybrid Router Assessment

| Aspect | Score | Status |
|--------|-------|--------|
| **Routing Logic** | 8/10 | ✅ Good - intelligent algorithm detection |
| **Orchestration** | 4/10 | ⚠️ Currently delegation, not composition |
| **Performance** | 7/10 | ✅ Good for single tokens, no batch mode |
| **Security** | 6/10 | ⚠️ Missing rate limiting and audit log |
| **Observability** | 3/10 | ⚠️ Minimal logging, no metrics |
| **Usability** | 8/10 | ✅ Good CLI, missing advanced features |

**Overall:** 6/10 — Strong foundation, significant room for improvement

### Current Architecture

```
USER REQUEST → DETECT ALGORITHM → ROUTING DECISION → EXEC PARSER
                                         │
                    ┌────────────────────┴─────────────────────┐
                    ▼                                          ▼
               BASH PARSER                                GO PARSER
           (full processing)                          (full processing)
```

**Problem:** Uses `exec` to delegate to one parser entirely. No composition of results.

---

## 🚀 Improvement Phases

## Phase 1: Core Orchestration (Priority: P1)

**Goal:** Transform hybrid router into true orchestrator with composition

**Timeline:** 1-2 weeks
**Estimated Effort:** 8-12 hours

### 1.1 Implement Orchestration Pattern

**Current (Delegation):**
```bash
exec "$BASH_PARSER" "$jwt"  # Replaces process entirely
```

**Proposed (Orchestration):**
```bash
# Step 1: Bash parses header/payload (fast, ~2ms)
header_payload=$("$BASH_PARSER" --no-verify --json "$jwt")

# Step 2: Go verifies signature (only if needed, ~5ms)
if [[ -n "$secret" ]]; then
    signature_result=$("$GO_PARSER" --verify-only --secret "$secret" "$jwt")
fi

# Step 3: Combine results (best of both worlds)
merge_results "$header_payload" "$signature_result"
```

**Benefits:**
- ⚡ Minimal overhead (bash for light operations)
- 🎯 Precision (Go only for cryptography)
- 📊 ~7ms total (vs 10ms for full Go parsing)

**Required Changes:**
- [ ] Add `--no-verify` flag to bash parser
- [ ] Add `--verify-only` flag to Go parser
- [ ] Implement `merge_results()` function in hybrid router
- [ ] Update tests to verify composition behavior

---

### 1.2 Add Rate Limiting (Security)

**Problem:** No protection against DoS (spam with signature verification requests)

**Solution:** Token bucket algorithm

```bash
RATE_LIMIT_MAX=100        # requests
RATE_LIMIT_WINDOW=60      # seconds
RATE_LIMIT_STATE="/tmp/jwt-parser-ratelimit"
```

**Implementation:**
- [ ] Create `check_rate_limit()` function
- [ ] Add `--rate-limit-max` and `--rate-limit-window` options
- [ ] Store state in `/tmp` or configurable location
- [ ] Return HTTP 429-style error when exceeded
- [ ] Add bypass flag for trusted contexts (`--no-rate-limit`)

**Tests Required:**
- [ ] Test rate limit enforcement
- [ ] Test window reset after timeout
- [ ] Test bypass flag

---

### 1.3 Add Performance Metrics

**Problem:** No visibility into production performance

**Solution:** JSON metrics logging

```bash
METRICS_FILE="/var/log/jwt-parser-metrics.json"

# Log format:
{
  "timestamp": "2026-01-25T22:00:00Z",
  "parser": "bash|go|hybrid",
  "duration_ms": 7,
  "algorithm": "HS256",
  "signature_verified": true,
  "cache_hit": false
}
```

**Implementation:**
- [ ] Create `log_metrics()` function
- [ ] Add `--metrics-file` option
- [ ] Measure parse time, verification time, total time
- [ ] Add cache hit/miss tracking
- [ ] Create `jwt-parser-metrics` command for analysis

**Metrics to Track:**
- Average duration by parser type
- Cache hit rate
- Algorithm distribution
- Error rate by type

---

## Phase 2: Performance Optimization (Priority: P2)

**Goal:** Improve throughput and latency for high-volume scenarios

**Timeline:** 1-2 weeks
**Estimated Effort:** 10-15 hours

### 2.1 Caching Layer

**Problem:** Decode header on every request to detect algorithm

**Solution:** In-memory cache based on header hash

```bash
declare -A ROUTING_CACHE  # header_hash -> routing_decision

route_request_cached() {
    local header_hash=$(echo "$jwt" | cut -d. -f1 | sha256sum | cut -d' ' -f1)

    if [[ -n "${ROUTING_CACHE[$header_hash]:-}" ]]; then
        echo "${ROUTING_CACHE[$header_hash]}"  # Cache hit!
        return
    fi

    # Cache miss - compute and store
    local decision=$(route_request "$jwt" "$secret")
    ROUTING_CACHE[$header_hash]="$decision"
    echo "$decision"
}
```

**Benefits:**
- ⚡ ~50% faster for repeated token types
- 💾 Minimal memory (~52 bytes per cached entry)

**Implementation:**
- [ ] Add associative array cache
- [ ] Add cache TTL (expire old entries)
- [ ] Add `--cache-size` option (default: 1000)
- [ ] Add `--no-cache` flag for testing
- [ ] Track cache hit rate in metrics

---

### 2.2 Batch Processing Mode

**Use Case:** Analyze logs with hundreds of JWT tokens

**Solution:** Parallel processing with xargs

```bash
# NEW FEATURE: Batch mode
jwt-parser-hybrid --batch tokens.txt --output results.json --parallel 8

# Implementation:
cat tokens.txt | xargs -P 8 -I {} ./jwt-parser-hybrid --json "{}"
```

**Benefits:**
- 🚀 8x speedup on 8-core CPU
- 📦 Perfect for DevOps/CI pipelines
- 📊 Aggregate statistics automatically

**Implementation:**
- [ ] Add `--batch <file>` option
- [ ] Add `--parallel <N>` option (default: CPU count)
- [ ] Add `--output <file>` for results
- [ ] Generate summary report (total, passed, failed, avg time)
- [ ] Support stdin mode: `cat tokens.txt | jwt-parser-hybrid --batch`

**Output Format:**
```json
{
  "summary": {
    "total": 1000,
    "valid": 987,
    "expired": 13,
    "invalid_signature": 0,
    "avg_duration_ms": 6.2
  },
  "results": [
    {"token": "eyJ...", "status": "valid", "duration_ms": 5},
    ...
  ]
}
```

---

### 2.3 Performance Diagnostics

**Problem:** No easy way to benchmark current setup

**Solution:** Built-in diagnostic mode

```bash
jwt-parser-hybrid --diagnose

# Expected Output:
✓ Bash parser: /opt/jwt-parser/jwt-parser.sh (v1.0.0)
✓ Go parser: /opt/jwt-parser/jwt-parser-static (v1.0.0)
✓ base64: GNU coreutils 9.1
✓ openssl: OpenSSL 3.0.2 (HMAC support: YES)
✓ jq: jq-1.6 (optional, found)

Performance Benchmark (1000 iterations):
- Bash (no verify):    2.3ms avg (±0.4ms)
- Bash (HMAC verify):  8.1ms avg (±1.2ms)
- Go (HMAC verify):    5.2ms avg (±0.8ms)
- Hybrid (optimal):    3.7ms avg (±0.6ms)

Routing Efficiency:
- Cache hit rate: 92% (last 1000 requests)
- Optimal parser selected: 98%

System Resources:
- CPU cores: 4
- Available memory: 8GB
- /tmp space: 50GB
```

**Implementation:**
- [ ] Create `--diagnose` flag
- [ ] Run benchmark with 100-1000 iterations
- [ ] Test all available parsers
- [ ] Check system dependencies
- [ ] Display routing statistics
- [ ] Suggest optimizations based on results

---

## Phase 3: Advanced Features (Priority: P3)

**Goal:** Add specialized modes for specific use cases

**Timeline:** 2-3 weeks
**Estimated Effort:** 15-20 hours

### 3.1 Streaming Mode

**Use Case:** Real-time log monitoring

**Solution:** Process stdin stream

```bash
# NEW FEATURE: Stream processing
tail -f /var/log/auth.log | jwt-parser-hybrid --stream --pattern "Bearer"

# Extracts JWT tokens from log lines and processes them
```

**Implementation:**
- [ ] Add `--stream` flag
- [ ] Add `--pattern <regex>` for token extraction
- [ ] Support multiple formats (Bearer, Cookie, custom)
- [ ] Buffer output for better performance
- [ ] Add `--stream-buffer <size>` option

**Patterns Supported:**
- `Bearer <token>` (Authorization header)
- `jwt=<token>` (Cookie)
- Custom regex: `--pattern 'token="([^"]+)"'`

---

### 3.2 Watch Mode

**Use Case:** Continuous monitoring of service tokens

**Solution:** Periodic checking with alerts

```bash
# NEW FEATURE: Watch mode
jwt-parser-hybrid --watch --secret "$SECRET" --interval 60 token.txt

# Checks token every 60 seconds, alerts on:
# - Token expiration approaching (< 5 min)
# - Signature validation failure
# - Token changed
# - Token rotation detected
```

**Implementation:**
- [ ] Add `--watch` flag
- [ ] Add `--interval <seconds>` (default: 60)
- [ ] Add `--alert-on <condition>` (expiring, invalid, changed)
- [ ] Add `--alert-threshold <seconds>` (e.g., 300 = 5 minutes)
- [ ] Support multiple alert methods:
  - [ ] stdout/stderr (default)
  - [ ] syslog (`--alert-syslog`)
  - [ ] webhook (`--alert-webhook <url>`)
  - [ ] email (`--alert-email <address>`)

**Alert Format:**
```
[2026-01-25 22:00:00] ALERT: Token expiring in 4m 32s
[2026-01-25 22:05:00] ALERT: Signature validation failed
[2026-01-25 22:10:00] INFO: Token rotated (new: eyJ..., old: eyJ...)
```

---

### 3.3 Audit Logging

**Problem:** No audit trail for compliance

**Solution:** Structured audit log

```bash
# Enable audit logging
jwt-parser-hybrid --audit-log /var/log/jwt-audit.log --secret "$SECRET" "$TOKEN"
```

**Log Format:**
```json
{
  "timestamp": "2026-01-25T22:00:00Z",
  "action": "verify",
  "token_hash": "sha256:a1b2c3...",
  "algorithm": "HS256",
  "subject": "user123",
  "issuer": "auth.example.com",
  "signature_valid": true,
  "expires_at": "2026-01-26T03:17:56Z",
  "source_ip": "192.168.1.100",
  "user_agent": "jwt-parser-hybrid/1.0.0"
}
```

**Implementation:**
- [ ] Add `--audit-log <file>` option
- [ ] Hash token (never log full token)
- [ ] Extract claims: sub, iss, aud, exp
- [ ] Capture source context (IP, user, hostname)
- [ ] Support log rotation (`--audit-rotate-size`, `--audit-rotate-count`)
- [ ] Create query tool: `jwt-parser-audit query --subject user123`

---

### 3.4 Prometheus Exporter (Optional)

**Use Case:** Integration with monitoring stack

**Solution:** Expose metrics endpoint

```bash
# Start metrics server
jwt-parser-hybrid --metrics-server --port 9090

# Expose metrics at http://localhost:9090/metrics
```

**Metrics Exposed:**
```
# HELP jwt_parser_requests_total Total number of parse requests
# TYPE jwt_parser_requests_total counter
jwt_parser_requests_total{parser="bash",algorithm="HS256",status="success"} 12345

# HELP jwt_parser_duration_seconds Duration of parse operations
# TYPE jwt_parser_duration_seconds histogram
jwt_parser_duration_seconds_bucket{parser="bash",le="0.005"} 8000
jwt_parser_duration_seconds_bucket{parser="bash",le="0.01"} 11000

# HELP jwt_parser_cache_hit_ratio Cache hit ratio
# TYPE jwt_parser_cache_hit_ratio gauge
jwt_parser_cache_hit_ratio 0.92
```

**Implementation:**
- [ ] Embed minimal HTTP server (bash + netcat or Go)
- [ ] Expose `/metrics` endpoint
- [ ] Support Prometheus format
- [ ] Add `--metrics-server` flag
- [ ] Add `--metrics-port <port>` option

---

## 📈 Success Metrics

### Phase 1 (Core Orchestration)
- [ ] Hybrid mode uses composition (not delegation)
- [ ] Rate limiting blocks >100 req/60s
- [ ] Metrics logged to JSON file
- [ ] Average latency reduced by 20-30%

### Phase 2 (Performance)
- [ ] Cache hit rate >80% in production
- [ ] Batch mode processes 1000 tokens in <10 seconds
- [ ] Diagnostic mode runs successfully on all platforms

### Phase 3 (Advanced)
- [ ] Streaming mode processes 10,000 lines/sec
- [ ] Watch mode alerts within 5 seconds of expiration
- [ ] Audit log captures 100% of verification attempts

---

## 🧪 Testing Strategy

### New Test Suites Required

**Phase 1:**
- [ ] `tests/orchestration/test_composition.sh` (10 tests)
- [ ] `tests/security/test_rate_limiting.sh` (8 tests)
- [ ] `tests/observability/test_metrics.sh` (5 tests)

**Phase 2:**
- [ ] `tests/performance/test_caching.sh` (12 tests)
- [ ] `tests/batch/test_batch_mode.sh` (15 tests)
- [ ] `tests/diagnostics/test_diagnose.sh` (6 tests)

**Phase 3:**
- [ ] `tests/streaming/test_stream_mode.sh` (10 tests)
- [ ] `tests/watch/test_watch_mode.sh` (8 tests)
- [ ] `tests/audit/test_audit_log.sh` (10 tests)

**Target:** 215 total tests (current: 131)

---

## 🛡️ Backward Compatibility

**Commitment:** All improvements must maintain 100% backward compatibility with v1.0.0 API.

**Guarantees:**
- ✅ Existing CLI flags continue to work
- ✅ Exit codes remain unchanged
- ✅ Output format unchanged (unless `--json` or new flags used)
- ✅ No breaking changes to bash/Go parser APIs

**Deprecation Policy:**
- Minor versions (1.x): No breaking changes
- Major versions (2.0): Breaking changes allowed with migration guide

---

## 📚 Documentation Updates

### Required Documentation

**Phase 1:**
- [ ] Update QUICKSTART.md with orchestration examples
- [ ] Add PERFORMANCE.md with benchmarks
- [ ] Update README with rate limiting info

**Phase 2:**
- [ ] Add BATCH_PROCESSING.md guide
- [ ] Add CACHING.md with tuning recommendations
- [ ] Update examples/ with batch scripts

**Phase 3:**
- [ ] Add MONITORING.md (streaming, watch, Prometheus)
- [ ] Add AUDIT.md (compliance, log format)
- [ ] Create video tutorial (optional)

---

## 🔄 Release Schedule

### v1.1.0 (Phase 1) — Target: 2026-02-15
- ✨ Orchestration pattern implemented
- 🔒 Rate limiting added
- 📊 Metrics collection

### v1.2.0 (Phase 2) — Target: 2026-03-01
- ⚡ Caching layer
- 📦 Batch processing mode
- 🔍 Diagnostic mode

### v1.3.0 (Phase 3) — Target: 2026-03-30
- 📡 Streaming mode
- 👀 Watch mode
- 📝 Audit logging

### v2.0.0 (Optional) — Target: TBD
- 🐍 Python bindings (optional)
- 🦀 Rust rewrite (optional)
- ☁️ Cloud-native features (optional)

---

## 🤝 Contributing

Interested in implementing any of these features? See [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines.

**Priority Tags:**
- **P1:** Critical improvements (security, performance)
- **P2:** Important enhancements (usability, observability)
- **P3:** Nice-to-have features (advanced use cases)

**Issue Labels:**
- `enhancement` — New features
- `performance` — Speed/efficiency improvements
- `security` — Security hardening
- `documentation` — Docs improvements

---

## 📞 Feedback

Questions or suggestions about this roadmap?
- Open an issue: https://github.com/AlexGromer/jwt-parser/issues
- Start a discussion: https://github.com/AlexGromer/jwt-parser/discussions

---

**Last Updated:** 2026-01-25
**Next Review:** 2026-02-15 (after v1.1.0 release)
