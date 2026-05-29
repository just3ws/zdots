#!/usr/bin/env bats
# tests/phi_scrubber_fuzz.bats — Adversarial, near-miss, and edge-case tests for lib/phi_scrubber.bash.
#
# These complement the known-good coverage in phi_boundary.bats with property-style
# probes: format variants that MUST be caught, near-misses that MUST NOT be caught,
# adversarial embeddings, and edge cases (empty, very long, multiline).

setup() {
  load "setup.bash"
  setup_environment
}

# ---------------------------------------------------------------------------
# SSN — format variants that MUST be redacted
# ---------------------------------------------------------------------------

@test "fuzz/ssn: all-zeros SSN is caught" {
  run bash -c "ZDOTDIR='$ZDOTDIR' source '$ZDOTDIR/lib/phi_scrubber.bash' && printf '000-00-0000' | phi_scrub"
  [ "$status" -eq 0 ]
  [[ "$output" == *"[REDACTED-SSN]"* ]]
  [[ "$output" != *"000-00-0000"* ]]
}

@test "fuzz/ssn: SSN embedded mid-sentence is caught" {
  run bash -c "ZDOTDIR='$ZDOTDIR' source '$ZDOTDIR/lib/phi_scrubber.bash' && printf 'Patient SSN is 123-45-6789 per record.' | phi_scrub"
  [ "$status" -eq 0 ]
  [[ "$output" == *"[REDACTED-SSN]"* ]]
  [[ "$output" != *"123-45-6789"* ]]
}

@test "fuzz/ssn: multiple SSNs on one line are all caught" {
  run bash -c "ZDOTDIR='$ZDOTDIR' source '$ZDOTDIR/lib/phi_scrubber.bash' && printf 'primary: 111-22-3333 spouse: 444-55-6666' | phi_scrub"
  [ "$status" -eq 0 ]
  [[ "$output" != *"111-22-3333"* ]]
  [[ "$output" != *"444-55-6666"* ]]
}

@test "fuzz/ssn: SSN at start of line is caught" {
  run bash -c "ZDOTDIR='$ZDOTDIR' source '$ZDOTDIR/lib/phi_scrubber.bash' && printf '123-45-6789 is the SSN' | phi_scrub"
  [ "$status" -eq 0 ]
  [[ "$output" != *"123-45-6789"* ]]
}

@test "fuzz/ssn: SSN at end of line is caught" {
  run bash -c "ZDOTDIR='$ZDOTDIR' source '$ZDOTDIR/lib/phi_scrubber.bash' && printf 'SSN: 123-45-6789' | phi_scrub"
  [ "$status" -eq 0 ]
  [[ "$output" != *"123-45-6789"* ]]
}

# ---------------------------------------------------------------------------
# SSN — near-misses that MUST NOT be redacted
# ---------------------------------------------------------------------------

@test "fuzz/ssn/near-miss: wrong format NNN-NNNN-NN is not caught" {
  run bash -c "ZDOTDIR='$ZDOTDIR' source '$ZDOTDIR/lib/phi_scrubber.bash' && printf '123-4567-89' | phi_scrub"
  [ "$status" -eq 0 ]
  [[ "$output" == "123-4567-89" ]]
}

@test "fuzz/ssn/near-miss: phone-like NNN-NNN-NNNN is not caught" {
  run bash -c "ZDOTDIR='$ZDOTDIR' source '$ZDOTDIR/lib/phi_scrubber.bash' && printf 'call 555-867-5309' | phi_scrub"
  [ "$status" -eq 0 ]
  [[ "$output" == "call 555-867-5309" ]]
}

@test "fuzz/ssn/near-miss: nine digits no dashes is not caught" {
  run bash -c "ZDOTDIR='$ZDOTDIR' source '$ZDOTDIR/lib/phi_scrubber.bash' && printf '123456789' | phi_scrub"
  [ "$status" -eq 0 ]
  [[ "$output" == "123456789" ]]
}

@test "fuzz/ssn/near-miss: dots instead of dashes is not caught" {
  run bash -c "ZDOTDIR='$ZDOTDIR' source '$ZDOTDIR/lib/phi_scrubber.bash' && printf '123.45.6789' | phi_scrub"
  [ "$status" -eq 0 ]
  [[ "$output" == "123.45.6789" ]]
}

@test "fuzz/ssn/near-miss: suffix too short NNN-NN-NNN is not caught" {
  run bash -c "ZDOTDIR='$ZDOTDIR' source '$ZDOTDIR/lib/phi_scrubber.bash' && printf '123-45-678' | phi_scrub"
  [ "$status" -eq 0 ]
  [[ "$output" == "123-45-678" ]]
}

# ---------------------------------------------------------------------------
# SSN — adversarial embeddings
# ---------------------------------------------------------------------------

@test "fuzz/ssn/adversarial: SSN adjacent to surrounding digits — inner pattern caught" {
  # 0123-45-67890 contains the sub-sequence 123-45-6789; the pattern must still fire
  run bash -c "ZDOTDIR='$ZDOTDIR' source '$ZDOTDIR/lib/phi_scrubber.bash' && printf '0123-45-67890' | phi_scrub"
  [ "$status" -eq 0 ]
  [[ "$output" != *"123-45-6789"* ]] || [[ "$output" == *"[REDACTED-SSN]"* ]]
}

@test "fuzz/ssn/adversarial: replacement token is not re-matched as an SSN" {
  run bash -c "ZDOTDIR='$ZDOTDIR' source '$ZDOTDIR/lib/phi_scrubber.bash' && printf '123-45-6789' | phi_scrub"
  [ "$status" -eq 0 ]
  [[ "$output" == "[REDACTED-SSN]" ]]
}

# ---------------------------------------------------------------------------
# MRN — format variants that MUST be redacted
# ---------------------------------------------------------------------------

@test "fuzz/mrn: MRN with no space before digits (MRN:12345)" {
  run bash -c "ZDOTDIR='$ZDOTDIR' source '$ZDOTDIR/lib/phi_scrubber.bash' && printf 'MRN:12345' | phi_scrub"
  [ "$status" -eq 0 ]
  [[ "$output" == *"[REDACTED-MRN]"* ]]
  [[ "$output" != *"12345"* ]]
}

@test "fuzz/mrn: MRN with multiple spaces before digits" {
  run bash -c "ZDOTDIR='$ZDOTDIR' source '$ZDOTDIR/lib/phi_scrubber.bash' && printf 'MRN:  99887766' | phi_scrub"
  [ "$status" -eq 0 ]
  [[ "$output" == *"[REDACTED-MRN]"* ]]
  [[ "$output" != *"99887766"* ]]
}

@test "fuzz/mrn: MRN embedded in longer string" {
  run bash -c "ZDOTDIR='$ZDOTDIR' source '$ZDOTDIR/lib/phi_scrubber.bash' && printf 'chart lookup MRN: 12345 admitted' | phi_scrub"
  [ "$status" -eq 0 ]
  [[ "$output" == *"[REDACTED-MRN]"* ]]
  [[ "$output" != *"12345"* ]]
}

# ---------------------------------------------------------------------------
# MRN — near-misses that MUST NOT be redacted
# ---------------------------------------------------------------------------

@test "fuzz/mrn/near-miss: lowercase mrn is not caught (pattern is case-sensitive)" {
  run bash -c "ZDOTDIR='$ZDOTDIR' source '$ZDOTDIR/lib/phi_scrubber.bash' && printf 'mrn: 12345' | phi_scrub"
  [ "$status" -eq 0 ]
  [[ "$output" == "mrn: 12345" ]]
}

@test "fuzz/mrn/near-miss: MRNX prefix is not caught" {
  run bash -c "ZDOTDIR='$ZDOTDIR' source '$ZDOTDIR/lib/phi_scrubber.bash' && printf 'MRNX: 12345' | phi_scrub"
  [ "$status" -eq 0 ]
  [[ "$output" == "MRNX: 12345" ]]
}

@test "fuzz/mrn/near-miss: MRN with no digits following is not caught" {
  run bash -c "ZDOTDIR='$ZDOTDIR' source '$ZDOTDIR/lib/phi_scrubber.bash' && printf 'MRN: abc' | phi_scrub"
  [ "$status" -eq 0 ]
  [[ "$output" == "MRN: abc" ]]
}

# ---------------------------------------------------------------------------
# DOB — format variants that MUST be redacted
# ---------------------------------------------------------------------------

@test "fuzz/dob: Date of Birth label (mixed case) is caught" {
  run bash -c "ZDOTDIR='$ZDOTDIR' source '$ZDOTDIR/lib/phi_scrubber.bash' && printf 'date of Birth: 3/7/85' | phi_scrub"
  [ "$status" -eq 0 ]
  [[ "$output" == *"[REDACTED-DOB]"* ]]
  [[ "$output" != *"3/7/85"* ]]
}

@test "fuzz/dob: DOB with dashes instead of slashes is caught" {
  run bash -c "ZDOTDIR='$ZDOTDIR' source '$ZDOTDIR/lib/phi_scrubber.bash' && printf 'DOB: 01-15-1990' | phi_scrub"
  [ "$status" -eq 0 ]
  [[ "$output" == *"[REDACTED-DOB]"* ]]
  [[ "$output" != *"01-15-1990"* ]]
}

@test "fuzz/dob: DOB with two-digit year is caught" {
  run bash -c "ZDOTDIR='$ZDOTDIR' source '$ZDOTDIR/lib/phi_scrubber.bash' && printf 'DOB: 12/31/99' | phi_scrub"
  [ "$status" -eq 0 ]
  [[ "$output" == *"[REDACTED-DOB]"* ]]
  [[ "$output" != *"12/31/99"* ]]
}

# ---------------------------------------------------------------------------
# DOB — near-misses that MUST NOT be redacted
# ---------------------------------------------------------------------------

@test "fuzz/dob/near-miss: DOB with no date following is not caught" {
  run bash -c "ZDOTDIR='$ZDOTDIR' source '$ZDOTDIR/lib/phi_scrubber.bash' && printf 'DOB: unknown' | phi_scrub"
  [ "$status" -eq 0 ]
  [[ "$output" == "DOB: unknown" ]]
}

@test "fuzz/dob/near-miss: all-lowercase dob is not caught" {
  run bash -c "ZDOTDIR='$ZDOTDIR' source '$ZDOTDIR/lib/phi_scrubber.bash' && printf 'dob: 01/01/2000' | phi_scrub"
  [ "$status" -eq 0 ]
  [[ "$output" == "dob: 01/01/2000" ]]
}

# ---------------------------------------------------------------------------
# Connection strings — suppress-flagged variants
# ---------------------------------------------------------------------------

@test "fuzz/conn: conn string without credentials (no @) passes through" {
  run bash -c "ZDOTDIR='$ZDOTDIR' source '$ZDOTDIR/lib/phi_scrubber.bash' && printf 'postgresql://localhost/mydb' | phi_scrub"
  [ "$status" -eq 0 ]
  [[ "$output" == "postgresql://localhost/mydb" ]]
}

@test "fuzz/conn: mysql conn string is suppressed (exits non-zero)" {
  run bash -c "ZDOTDIR='$ZDOTDIR' source '$ZDOTDIR/lib/phi_scrubber.bash' && printf 'mysql://user:pass@host/db' | phi_scrub"
  [ "$status" -ne 0 ]
  [[ "$output" != *"pass"* ]]
}

@test "fuzz/conn: redis conn string with port is suppressed" {
  run bash -c "ZDOTDIR='$ZDOTDIR' source '$ZDOTDIR/lib/phi_scrubber.bash' && printf 'redis://admin:s3cret@127.0.0.1:6379/0' | phi_scrub"
  [ "$status" -ne 0 ]
  [[ "$output" != *"s3cret"* ]]
}

# ---------------------------------------------------------------------------
# Inline credentials — variants and near-misses
# ---------------------------------------------------------------------------

@test "fuzz/inline_creds: api_key= form is caught" {
  run bash -c "ZDOTDIR='$ZDOTDIR' source '$ZDOTDIR/lib/phi_scrubber.bash' && printf 'api_key=sk-secret123' | phi_scrub"
  [ "$status" -eq 0 ]
  [[ "$output" == *"[REDACTED]"* ]]
  [[ "$output" != *"sk-secret123"* ]]
}

@test "fuzz/inline_creds: access_token= form is caught" {
  run bash -c "ZDOTDIR='$ZDOTDIR' source '$ZDOTDIR/lib/phi_scrubber.bash' && printf 'access_token=ghp_abc123' | phi_scrub"
  [ "$status" -eq 0 ]
  [[ "$output" == *"[REDACTED]"* ]]
  [[ "$output" != *"ghp_abc123"* ]]
}

@test "fuzz/inline_creds: access-token= form (dash separator) is caught" {
  run bash -c "ZDOTDIR='$ZDOTDIR' source '$ZDOTDIR/lib/phi_scrubber.bash' && printf 'access-token=ghp_abc123' | phi_scrub"
  [ "$status" -eq 0 ]
  [[ "$output" == *"[REDACTED]"* ]]
  [[ "$output" != *"ghp_abc123"* ]]
}

@test "fuzz/inline_creds/near-miss: tokenizer= is not caught" {
  run bash -c "ZDOTDIR='$ZDOTDIR' source '$ZDOTDIR/lib/phi_scrubber.bash' && printf 'tokenizer=tiktoken' | phi_scrub"
  [ "$status" -eq 0 ]
  [[ "$output" == "tokenizer=tiktoken" ]]
}

@test "fuzz/inline_creds/near-miss: spaces around equals (token = secret) is not caught" {
  run bash -c "ZDOTDIR='$ZDOTDIR' source '$ZDOTDIR/lib/phi_scrubber.bash' && printf 'token = secret123' | phi_scrub"
  [ "$status" -eq 0 ]
  [[ "$output" == "token = secret123" ]]
}

# ---------------------------------------------------------------------------
# CLI credential flags — additional variants
# ---------------------------------------------------------------------------

@test "fuzz/cli_creds: --secret flag is caught" {
  run bash -c "ZDOTDIR='$ZDOTDIR' source '$ZDOTDIR/lib/phi_scrubber.bash' && printf 'myapp --secret topsecretval' | phi_scrub"
  [ "$status" -eq 0 ]
  [[ "$output" == *"[REDACTED]"* ]]
  [[ "$output" != *"topsecretval"* ]]
}

@test "fuzz/cli_creds: --auth flag is caught" {
  run bash -c "ZDOTDIR='$ZDOTDIR' source '$ZDOTDIR/lib/phi_scrubber.bash' && printf 'curl --auth bearer:token123' | phi_scrub"
  [ "$status" -eq 0 ]
  [[ "$output" == *"[REDACTED]"* ]]
  [[ "$output" != *"token123"* ]]
}

@test "fuzz/cli_creds: --authorization flag is caught" {
  run bash -c "ZDOTDIR='$ZDOTDIR' source '$ZDOTDIR/lib/phi_scrubber.bash' && printf 'curl --authorization Bearer:abc123' | phi_scrub"
  [ "$status" -eq 0 ]
  [[ "$output" == *"[REDACTED]"* ]]
  [[ "$output" != *"abc123"* ]]
}

# ---------------------------------------------------------------------------
# Edge cases
# ---------------------------------------------------------------------------

@test "fuzz/edge: empty input returns empty output" {
  run bash -c "ZDOTDIR='$ZDOTDIR' source '$ZDOTDIR/lib/phi_scrubber.bash' && printf '' | phi_scrub"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "fuzz/edge: whitespace-only input passes through unchanged" {
  run bash -c "ZDOTDIR='$ZDOTDIR' source '$ZDOTDIR/lib/phi_scrubber.bash' && printf '   \t  ' | phi_scrub"
  [ "$status" -eq 0 ]
  [[ "$output" == "   	  " ]]
}

@test "fuzz/edge: very long clean line (10 KB) passes through" {
  run bash -c "ZDOTDIR='$ZDOTDIR' source '$ZDOTDIR/lib/phi_scrubber.bash' && python3 -c \"print('x' * 10240, end='')\" | phi_scrub"
  [ "$status" -eq 0 ]
  [ "${#output}" -ge 10240 ]
  [[ "$output" != *"REDACTED"* ]]
}

@test "fuzz/edge: multiline input — PHI on line 2 is caught, clean lines preserved" {
  run bash -c "ZDOTDIR='$ZDOTDIR' source '$ZDOTDIR/lib/phi_scrubber.bash' && printf 'first line clean\nSSN: 123-45-6789\nthird line clean' | phi_scrub"
  [ "$status" -eq 0 ]
  [[ "$output" == *"[REDACTED-SSN]"* ]]
  [[ "$output" != *"123-45-6789"* ]]
  [[ "$output" == *"first line clean"* ]]
  [[ "$output" == *"third line clean"* ]]
}

@test "fuzz/edge: all four redact patterns in one blob" {
  run bash -c "ZDOTDIR='$ZDOTDIR' source '$ZDOTDIR/lib/phi_scrubber.bash' && printf 'SSN: 111-22-3333 MRN: 9876543 DOB: 06/15/1972 api_key=supersecret' | phi_scrub"
  [ "$status" -eq 0 ]
  [[ "$output" == *"[REDACTED-SSN]"* ]]
  [[ "$output" == *"[REDACTED-MRN]"* ]]
  [[ "$output" == *"[REDACTED-DOB]"* ]]
  [[ "$output" == *"[REDACTED]"* ]]
  [[ "$output" != *"111-22-3333"* ]]
  [[ "$output" != *"9876543"* ]]
  [[ "$output" != *"06/15/1972"* ]]
  [[ "$output" != *"supersecret"* ]]
}
