#!/usr/bin/env bats
# Unit tests for lib/zsynod_core.py — circuit breaker, summarizer, deliberate params.
# Does NOT hit external services; mocks are inline Python.

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  PYTHON="python3"
}

# ── helpers ──────────────────────────────────────────────────────────────────

run_py() {
  "$PYTHON" - <<EOF
import sys
sys.path.append("$REPO_ROOT/lib")
$1
EOF
}

# ── AgentCircuitBreaker ───────────────────────────────────────────────────────

@test "circuit breaker: starts ready with full timeout" {
  run run_py "
from zsynod_core import AgentCircuitBreaker
b = AgentCircuitBreaker(90)
assert b.is_ready(), 'should be ready on first use'
assert b.current_timeout() == 90, f'expected 90, got {b.current_timeout()}'
print('ok')
"
  [ "$status" -eq 0 ]
  [[ "$output" == *"ok"* ]]
}

@test "circuit breaker: first timeout skips 1 tick, halves budget" {
  run run_py "
from zsynod_core import AgentCircuitBreaker
b = AgentCircuitBreaker(90)
b.record_timeout()
assert b._skip_remaining == 1, f'expected skip=1, got {b._skip_remaining}'
assert b.current_timeout() == 45.0, f'expected 45.0, got {b.current_timeout()}'
print('ok')
"
  [ "$status" -eq 0 ]
  [[ "$output" == *"ok"* ]]
}

@test "circuit breaker: skip drains each tick, then ready again" {
  run run_py "
from zsynod_core import AgentCircuitBreaker
b = AgentCircuitBreaker(90)
b.record_timeout()          # skip_remaining=1
assert not b.is_ready()     # tick 0: skipped, skip_remaining→0
assert b.is_ready()         # tick 1: ready
print('ok')
"
  [ "$status" -eq 0 ]
  [[ "$output" == *"ok"* ]]
}

@test "circuit breaker: four timeouts hit floor and cap skip at 8" {
  run run_py "
from zsynod_core import AgentCircuitBreaker, _MIN_TIMEOUT
b = AgentCircuitBreaker(90)
for _ in range(4):
    b.record_timeout()
assert b._skip_remaining == 8, f'expected 8, got {b._skip_remaining}'
assert b.current_timeout() == _MIN_TIMEOUT, f'expected floor {_MIN_TIMEOUT}, got {b.current_timeout()}'
print('ok')
"
  [ "$status" -eq 0 ]
  [[ "$output" == *"ok"* ]]
}

@test "circuit breaker: success resets state" {
  run run_py "
from zsynod_core import AgentCircuitBreaker
b = AgentCircuitBreaker(90)
b.record_timeout(); b.record_timeout()
b.record_success()
assert b._consecutive == 0
assert b._skip_remaining == 0
assert b.current_timeout() == 90
print('ok')
"
  [ "$status" -eq 0 ]
  [[ "$output" == *"ok"* ]]
}

# ── TAOIST_GLYPHS / tick_seed ─────────────────────────────────────────────────

@test "tick_seed returns a single character from the pool" {
  run run_py "
from zsynod_core import TAOIST_GLYPHS, tick_seed
g = tick_seed()
assert g in TAOIST_GLYPHS, f'{g!r} not in pool'
assert len(g) == 1, f'expected single char, got len={len(g)}'
print('ok')
"
  [ "$status" -eq 0 ]
  [[ "$output" == *"ok"* ]]
}

@test "TAOIST_GLYPHS has exactly 73 entries" {
  run run_py "
from zsynod_core import TAOIST_GLYPHS
assert len(TAOIST_GLYPHS) == 73, f'expected 73, got {len(TAOIST_GLYPHS)}'
print('ok')
"
  [ "$status" -eq 0 ]
  [[ "$output" == *"ok"* ]]
}

# ── LedgerManager.get_latest_summary ─────────────────────────────────────────

@test "get_latest_summary returns empty string when no summary exists" {
  run run_py "
import tempfile, json
from pathlib import Path
from zsynod_core import LedgerManager

with tempfile.NamedTemporaryFile(suffix='.jsonl', mode='w', delete=False) as f:
    name = f.name

lm = LedgerManager(Path(name))
assert lm.get_latest_summary('P1') == '', 'expected empty string'
print('ok')
"
  [ "$status" -eq 0 ]
  [[ "$output" == *"ok"* ]]
}

@test "get_latest_summary returns most recent text for a proposal" {
  run run_py "
import tempfile
from pathlib import Path
from zsynod_core import LedgerManager

with tempfile.NamedTemporaryFile(suffix='.jsonl', mode='w', delete=False) as f:
    name = f.name

lm = LedgerManager(Path(name))
lm.append('summarizer', 'summary', {'proposal': 'P1', 'text': 'first'})
lm.append('summarizer', 'summary', {'proposal': 'P1', 'text': 'second'})
lm.append('summarizer', 'summary', {'proposal': 'P2', 'text': 'other'})
assert lm.get_latest_summary('P1') == 'second', f'got {lm.get_latest_summary(\"P1\")!r}'
assert lm.get_latest_summary('P2') == 'other'
print('ok')
"
  [ "$status" -eq 0 ]
  [[ "$output" == *"ok"* ]]
}

# ── deliberate() prompt construction ─────────────────────────────────────────

@test "deliberate builds system prompt with actor handle and members" {
  run run_py "
import sys
from unittest.mock import patch
sys.path.append('$REPO_ROOT/lib')
from zsynod_core import ZsynodAgent, LedgerEntry
import datetime

agent = ZsynodAgent('pi')
captured = {}

def fake_local(sp, up, tc=None, t=None):
    captured['system'] = sp
    captured['user'] = up
    return 'ok'

with patch.object(agent, '_deliberate_local', fake_local):
    agent.deliberate('TestTopic', [], members=['mike','pi','claude'])

assert '@pi' in captured['system'], 'actor handle missing'
assert '@mike' in captured['system'], 'member @mike missing'
assert '160 tokens' in captured['system'], '160-token rule missing'
assert '3 hashtags' in captured['system'], 'hashtag rule missing'
print('ok')
"
  [ "$status" -eq 0 ]
  [[ "$output" == *"ok"* ]]
}

@test "deliberate prepends [STATE] summary when provided" {
  run run_py "
import sys
from unittest.mock import patch
sys.path.append('$REPO_ROOT/lib')
from zsynod_core import ZsynodAgent

agent = ZsynodAgent('aider')
captured = {}

def fake_local(sp, up, tc=None, t=None):
    captured['user'] = up
    return 'ok'

with patch.object(agent, '_deliberate_local', fake_local):
    agent.deliberate('Topic', [], summary='P1: aye=2 nay=1')

assert '[STATE]' in captured['user'], '[STATE] prefix missing'
assert 'P1: aye=2 nay=1' in captured['user']
print('ok')
"
  [ "$status" -eq 0 ]
  [[ "$output" == *"ok"* ]]
}

@test "deliberate context capped at last 5 entries" {
  run run_py "
import sys
from unittest.mock import patch
sys.path.append('$REPO_ROOT/lib')
from zsynod_core import ZsynodAgent, LedgerEntry
import datetime

agent = ZsynodAgent('opencode')
captured = {}

def fake_local(sp, up, tc=None, t=None):
    captured['user'] = up
    return 'ok'

entries = []
for i in range(8):
    e = LedgerEntry(seq=i, round=1, actor=f'a{i}', type='speak',
                    data={'remark': f'msg{i}'}, prev='x', hash='x',
                    ts=datetime.datetime.utcnow().isoformat()+'Z')
    entries.append(e)

with patch.object(agent, '_deliberate_local', fake_local):
    agent.deliberate('Topic', entries)

# Only last 5 actors should appear
for i in range(3):
    assert f'msg{i}' not in captured['user'], f'msg{i} should be pruned'
for i in range(3, 8):
    assert f'msg{i}' in captured['user'], f'msg{i} should be present'
print('ok')
"
  [ "$status" -eq 0 ]
  [[ "$output" == *"ok"* ]]
}
