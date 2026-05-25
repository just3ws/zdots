# AI Pipeline Seams

Every point where two components touch in the AI pipeline. Invariants, verification, and test coverage for each seam.

## Architecture Overview

```
User Prompt
    │
    ▼
zdots-ask / zdots-ctx / ai-query (callers)
    │
    ▼
lib/ai-invoke.bash          ← AI Invocation Interface seam
    ├── zdots_ai_gate        ← PHI boundary: mode gate
    ├── zdots_message_hygiene← PHI boundary: normalize + scrub
    └── ai-query (subprocess)
            │
            ▼
        lib/ai-query-lib.bash
            ├── aiq_normalize       ← strip nulls/CRLF/ANSI
            ├── aiq_risk_scan       ← injection risk scoring
            ├── aiq_build_prompt    ← trust-boundary wrapping
            ├── aiq_submit          ← HTTP POST to llama-server
            └── aiq_sanitize_output ← strip <think> + escape sequences
                    │
                    ▼
            llama-server (127.0.0.1:8080)
```

---

## Seam 1: AI Invocation Interface (`lib/ai-invoke.bash`)

**What it is**: The single call site through which all lib/script code invokes local AI inference. Callers never call `ai-query` or `llama-server` directly.

**Functions**:
- `zdots_ai_infer_raw PROMPT [SYSTEM_PROMPT]` — raw text response
- `zdots_ai_distill PROMPT` — structured JSON response with validation

**Invariants**:
1. `zdots_ai_gate` is always called before any inference — exits 2 if `ZDOTS_AI_MODE=none`
2. `zdots_assert_local_endpoint` enforces loopback/RFC-1918 in local mode — exits 1 on violation
3. `zdots_message_hygiene` runs on every prompt before submission — PHI scrubbed, ANSI stripped
4. `ai-query` binary is resolved via `ZDOTS_AI_QUERY` env var (test injection) or `${ZDOTDIR}/bin/ai-query` (production)
5. `zdots_ai_distill` validates JSON via `jq empty` before returning — exits 2 on invalid JSON

**Exit codes**:
- 0: success
- 1: inference failed or binary not found
- 2: gate blocked (ZDOTS_AI_MODE=none), empty prompt, or invalid JSON from distill

**Test coverage**: `tests/ai_invoke.bats` (11 tests)
- Gate blocks when mode=none
- Empty prompt rejected
- ai-query not found → exit 1
- PHI (SSN) stripped before delegation
- System prompt forwarded / omitted correctly
- distill validates JSON, propagates inference errors, extracts from prose

**Verification**:
```bash
# Gate check
ZDOTS_AI_MODE=none bash -c 'source lib/ai-invoke.bash && zdots_ai_infer_raw "hi"'
# → exits 2

# PHI scrub check
ZDOTS_AI_QUERY=/dev/null ZDOTS_AI_MODE=local bash -c '
  source lib/ai-invoke.bash
  zdots_ai_infer_raw "patient SSN 123-45-6789" 2>&1
' | grep REDACTED
```

---

## Seam 2: Message Hygiene Pipeline (`lib/message_hygiene.bash`)

**What it is**: Two-stage pipeline run on every prompt before AI submission: `zdots_normalize_text` → `phi_scrub`.

**Function**: `zdots_message_hygiene` — reads stdin, writes cleaned text to stdout

**Invariants**:
1. Normalize always runs before phi_scrub (order is not configurable)
2. phi_scrub reads patterns from `etc/phi-patterns.yaml` via `yq` — fails hard if `yq` absent or file missing
3. PHI patterns are compiled once per process (lazy cache in `_PHI_SED_ARGS` array); pipeline subshells get a warm copy via export

**Exit codes**:
- 0: success
- 1: normalize or scrub step failed

**Test coverage**: `tests/phi_boundary.bats` (phi_scrubber section + phi_registry section, 14 tests)

**Verification**:
```bash
printf 'SSN 123-45-6789\nDOB: 01/01/2000\n' | bash -c 'source lib/message_hygiene.bash && zdots_message_hygiene'
# Output must contain [REDACTED-SSN] and [REDACTED-DOB], not raw values
```

---

## Seam 3: PHI Pattern Registry (`etc/phi-patterns.yaml`)

**What it is**: Single source of truth for all redaction patterns. Adding a pattern here is the only change needed to protect a new data type across all AI paths.

**Schema**:
```yaml
patterns:
  - name: <string>      # label for [REDACTED-<NAME>] token
    regex: <sed-regex>  # POSIX extended regex — no `;` (sed delimiter)
    replace: <string>   # replacement text — no `;` (sed delimiter)
    weight: <int>       # risk weight (0–100); not yet used in gate logic
```

**Invariants**:
1. `regex` and `replace` must not contain `;` (sed field separator)
2. `yq` ≥ 4 required to parse YAML — `phi_scrub` exits non-zero with clear error if absent
3. Patterns apply in declaration order (first match wins within a token)

**Active patterns**:
| Name | Pattern | Weight |
|------|---------|--------|
| SSN | `\d{3}-\d{2}-\d{4}` | 90 |
| MRN | `MRN\s*:?\s*\d+` | 75 |
| DOB | `(DOB|Date of Birth)\s*:?\s*\d{1,2}[/-]\d{1,2}[/-]\d{2,4}` | 60 |
| conn_string | `(postgresql\|mysql\|redis)://[^@\s]+@[^/\s]*` | 85 |

**Test coverage**: `tests/phi_boundary.bats` (phi_registry section, 7 tests)

---

## Seam 4: AI Boundary (`lib/ai_boundary.bash`)

**What it is**: Mode gate and locality assertion. Called inside `zdots_ai_invoke_raw` — callers don't need to call it directly.

**Functions**:
- `zdots_ai_gate CALLER` — exits 2 if `ZDOTS_AI_MODE=none`; audits the call
- `zdots_assert_local_endpoint ENDPOINT` — exits 1 if endpoint is non-RFC-1918 in local mode

**RFC-1918 ranges accepted in local mode**:
- `127.x.x.x` (loopback)
- `10.x.x.x`
- `172.16–31.x.x`
- `192.168.x.x`

**Test coverage**: `tests/phi_boundary.bats` (ai_boundary section, 9 tests)

---

## Seam 5: `ai-query` Output Sanitization (`lib/ai-query-lib.bash:aiq_sanitize_output`)

**What it is**: Final output filter — strips Qwen3 `<think>` blocks and all terminal escape sequences before bytes reach stdout.

**Why it exists**: Qwen3 emits `<think>...</think>` reasoning blocks when thinking mode is active. These blocks are useful for ai-query's reasoning paths but must not leak to callers expecting clean text. ANSI sequences from the model could corrupt terminal display.

**Invariants**:
1. `<think>...</think>` blocks are stripped universally — callers never see raw thinking output
2. Multi-line think blocks handled via `perl -0777` slurp mode (not line-by-line)
3. Falls back to `awk` filter if `perl` absent (handles blocks but only single-line variants)
4. Strip happens AFTER model response received, BEFORE stdout

**Suppression at source**: `zdots-ask` system prompts all end with `/no_think` to tell Qwen3 not to emit thinking mode for interactive queries. The `aiq_sanitize_output` layer is defense-in-depth for raw ai-query calls and any model that ignores the token.

**Test coverage**: `tests/ai_query.bats` H7–H10 (think-block stripping, 4 tests)

**Verification**:
```bash
printf '<think>\nstep 1\nstep 2\n</think>\nFinal answer\n' | bash -c 'source lib/ai-query-lib.bash && aiq_sanitize_output'
# Must output: Final answer
# Must NOT output: step 1, step 2, <think>
```

---

## Seam 6: `llama-server` (127.0.0.1:8080)

**What it is**: The inference endpoint. All AI requests POST to `/v1/chat/completions`.

**Current model**: Qwen3-8B Q4_K_M (`Qwen_Qwen3-8B-Q4_K_M.gguf`)
**Profile**: `qwen3-8b` in `etc/ai-models.yaml`
**Context**: 8192 tokens/slot × 2 parallel slots = 16384 total
**n_embd**: 4096 (vector dimension for embeddings)

**Server flags** (from `etc/ai-models.yaml::server`):
- `--embeddings --pooling mean`: enables `/v1/embeddings` for RAG
- `--flash-attn on`: ~2-4× KV cache reduction on M4
- `--cache-type-k/v q8_0`: halved KV cache memory
- `--cache-reuse 256`: KV prefix cache reuse (amortizes system prompt prefill)
- `--alias local`: stable model name for API callers

**Locality invariant**: `zdots_assert_local_endpoint` ensures this is always a loopback/RFC-1918 address when `ZDOTS_AI_MODE=local`. `ZDOTS_AI_MODE=cloud` bypasses the check (future cloud path).

**Health check**:
```bash
llama-ctl health          # exits 0 if up
llama-ctl status          # human-readable with active_model
curl -s http://127.0.0.1:8080/health | jq .status
```

**Model rollback** (if regression found):
```bash
# 1. Switch profile back to standard
export ZDOTS_AI_PROFILE=standard    # or update .zdots.env
# 2. Update plist model path
ZDOTS_AI_PROFILE=standard llama-ctl install
launchctl unload ~/Library/LaunchAgents/com.zdots.llama-server.plist
launchctl load ~/Library/LaunchAgents/com.zdots.llama-server.plist
# 3. Revert vector dimension in DB
zdots-ctx migrate  # down to vector(3584) requires manual Sequel down migration
```

---

## Seam 7: pgvector Embedding Storage

**Tables**: `methodologies.embedding`, `lessons.embedding`
**Type**: `vector(4096)` (Qwen3-8B n_embd; was `vector(3584)` for Qwen2.5-7B)
**Migration**: `db/migrations/20260525000000_update_embedding_dimension.rb`

**Invariant**: embedding dimension must match `n_embd` of the model used to generate them. Inserting a vector of wrong dimension raises a pgvector type error.

**Verification**:
```sql
-- Run as migration user:
SELECT relname, atttypmod FROM pg_attribute
JOIN pg_class ON pg_attribute.attrelid = pg_class.oid
WHERE relname IN ('methodologies','lessons') AND attname = 'embedding';
-- atttypmod must be 4096
```

---

## Thinking Mode Protocol

Qwen3-8B supports hybrid thinking mode: think-first reasoning (`<think>...</think>`) followed by the actual response.

| Path | Thinking | Mechanism |
|------|----------|-----------|
| `zdots-ask` (interactive) | Suppressed at source | `/no_think` token appended to all 4 system prompts in `etc/prompts/` |
| `ai-query` (general) | Allowed | Reasoning improves accuracy for complex tasks |
| All paths | Stripped at output | `aiq_sanitize_output` removes any `<think>` blocks universally |

This means callers always receive clean responses. Thinking tokens are never exposed outside `llama-server`.

---

## Full Regression Checklist

```bash
# 1. Unit tests
bats tests/ai_invoke.bats tests/phi_boundary.bats tests/ai_query.bats

# 2. Live inference — no think blocks
zdots-ask "what shell is zdots built on?"

# 3. PHI scrubbing — SSN must not reach model
zdots-ask "patient SSN 123-45-6789 needs help" 2>&1 | grep -v REDACTED | grep "123-45-6789" && echo FAIL || echo PASS

# 4. Domain routing
zdots-ask --dry-run "explain pgp_sym_encrypt"  # → domain=phi

# 5. Raw inference
AIQ_SUPPRESS_RAW_WARN=1 ai-query --mode raw "What is 2+2?"

# 6. Server health
llama-ctl health && llama-ctl status

# 7. Vector dimension
psql -q "${ZDOTS_MIGRATION_URL}" -c \
  "SELECT relname, atttypmod FROM pg_attribute JOIN pg_class ON pg_attribute.attrelid=pg_class.oid WHERE relname IN ('methodologies','lessons') AND attname='embedding';"
# atttypmod must = 4096
```
