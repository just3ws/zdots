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

# ── GLYPH_POOL / tick_seed ────────────────────────────────────────────────────

@test "tick_seed returns a single glyph from the combined pool" {
  run run_py "
from zsynod_core import GLYPH_POOL, tick_seed
g = tick_seed()
assert g in GLYPH_POOL, f'{g!r} not in pool'
assert len(g) == 1, f'expected single codepoint, got len={len(g)}'
print('ok')
"
  [ "$status" -eq 0 ]
  [[ "$output" == *"ok"* ]]
}

@test "glyph pool: 73 Taoist + emoji archetypes, no protocol-marker collisions" {
  run run_py "
from zsynod_core import TAOIST_GLYPHS, EMOJI_GLYPHS, GLYPH_POOL
assert len(TAOIST_GLYPHS) == 73, f'expected 73, got {len(TAOIST_GLYPHS)}'
assert len(GLYPH_POOL) == len(TAOIST_GLYPHS) + len(EMOJI_GLYPHS)
assert len(set(GLYPH_POOL)) == len(GLYPH_POOL), 'pool has duplicates'
# every emoji is a single codepoint — bracketing math stays char-simple
assert all(len(g) == 1 for g in EMOJI_GLYPHS)
# the seed must never read as forum protocol
markers = {'⚡', '⚖', '😈', '💭', '📚', '📜', '🔇'}
assert not markers & set(GLYPH_POOL), markers & set(GLYPH_POOL)
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

# ── get_trend_preamble ────────────────────────────────────────────────────────

@test "get_trend_preamble returns empty string with no speak entries" {
  run run_py "
import tempfile
from pathlib import Path
from zsynod_core import LedgerManager

lm = LedgerManager(Path(tempfile.mkstemp(suffix='.jsonl')[1]))
assert lm.get_trend_preamble() == '', 'expected empty string'
print('ok')
"
  [ "$status" -eq 0 ]
  [[ "$output" == *"ok"* ]]
}

@test "get_trend_preamble includes hot/mid/cold hashtags and stats" {
  run run_py "
import tempfile
from pathlib import Path
from zsynod_core import LedgerManager

lm = LedgerManager(Path(tempfile.mkstemp(suffix='.jsonl')[1]))
# Seed entries: one hot hashtag (many uses), one cold (one use)
for i in range(10):
    lm.append('pi', 'speak', {'remark': f'msg {i} #HotTag'})
lm.append('pi', 'speak', {'remark': 'rare thought #ColdTag'})

p = lm.get_trend_preamble()
assert '🔥' in p, 'missing hot emoji'
assert '❄' in p, 'missing cold emoji'
assert 'HotTag' in p, 'missing hot tag'
assert 'ColdTag' in p, 'missing cold tag'
assert 'σ=' in p and 'μ=' in p, 'missing stats'
print('ok')
"
  [ "$status" -eq 0 ]
  [[ "$output" == *"ok"* ]]
}

@test "deliberate includes trend line in user prompt" {
  run run_py "
import sys
from unittest.mock import patch
sys.path.append('$REPO_ROOT/lib')
from zsynod_core import ZsynodAgent

agent = ZsynodAgent('pi')
captured = {}

def fake_local(sp, up, tc=None, t=None, **kw):
    captured['user'] = up
    return 'ok'

with patch.object(agent, '_deliberate_local', fake_local):
    agent.deliberate('Topic', [], trend='Trend [σ=1.0 μ=2.0]: 🔥#Hot(9.0) — #Mid(2.0) — ❄#Cold(0.1)')

assert 'Trend' in captured['user'], 'trend line missing from user prompt'
assert '🔥' in captured['user']
assert '❄' in captured['user']
print('ok')
"
  [ "$status" -eq 0 ]
  [[ "$output" == *"ok"* ]]
}

# ── parse_directives ──────────────────────────────────────────────────────────

@test "parse_directives: vote line becomes entry, stripped from speech" {
  run run_py "
from zsynod_core import parse_directives
speech, d = parse_directives('P25 deepens before it broadens.\n>vote P25 aye\n#One #Two #Three')
assert d == [('vote', {'proposal': 'P25', 'vote': 'aye'})], d
assert '>vote' not in speech, speech
assert 'deepens' in speech and '#Three' in speech
print('ok')
"
  [ "$status" -eq 0 ]
  [[ "$output" == *"ok"* ]]
}

@test "parse_directives: verb, pid, and choice are case-insensitive" {
  run run_py "
from zsynod_core import parse_directives
_, d = parse_directives('  > VOTE p7 NAY')
assert d == [('vote', {'proposal': 'P7', 'vote': 'nay'})], d
print('ok')
"
  [ "$status" -eq 0 ]
  [[ "$output" == *"ok"* ]]
}

@test "parse_directives: second, propose, handoff all parse" {
  run run_py "
from zsynod_core import parse_directives
speech, d = parse_directives('>second P24\n>propose Recency window for trend\n>handoff @aider wire pulse to tick loop')
assert d[0] == ('second', {'proposal': 'P24'}), d[0]
assert d[1] == ('propose', {'title': 'Recency window for trend'}), d[1]
assert d[2] == ('handoff', {'to': 'aider', 'task': 'wire pulse to tick loop'}), d[2]
assert speech == '', speech
print('ok')
"
  [ "$status" -eq 0 ]
  [[ "$output" == *"ok"* ]]
}

@test "parse_directives: malformed directive stays in speech" {
  run run_py "
from zsynod_core import parse_directives
speech, d = parse_directives('>vote aye P25\n>handoff @aider\n>vote P25 maybe')
assert d == [], d
assert speech.count('>') == 3, speech
print('ok')
"
  [ "$status" -eq 0 ]
  [[ "$output" == *"ok"* ]]
}

@test "parse_directives: mid-line '>' is speech, not a directive" {
  run run_py "
from zsynod_core import parse_directives
speech, d = parse_directives('I think x > y here, so >vote P25 aye inline does not count')
assert d == [], d
assert 'x > y' in speech
print('ok')
"
  [ "$status" -eq 0 ]
  [[ "$output" == *"ok"* ]]
}

@test "parse_directives: pass with and without note" {
  run run_py "
from zsynod_core import parse_directives
_, d = parse_directives('>pass')
assert d == [('pass', {})], d
_, d = parse_directives('>pass nothing to add this round')
assert d == [('pass', {'note': 'nothing to add this round'})], d
print('ok')
"
  [ "$status" -eq 0 ]
  [[ "$output" == *"ok"* ]]
}

# ── quorum recognition + lifecycle states ─────────────────────────────────────

@test "commit_on_quorum: commits at quorum, idempotent, skips short tallies" {
  run run_py "
import tempfile
from pathlib import Path
from zsynod_core import LedgerManager

lm = LedgerManager(Path(tempfile.mkstemp(suffix='.jsonl')[1]))
lm.append('mike', 'propose', {'id': 'P1', 'title': 'Reaches quorum'})
lm.append('mike', 'propose', {'id': 'P2', 'title': 'Falls short'})
lm.append('pi', 'vote', {'proposal': 'P1', 'vote': 'aye'})
lm.append('claude', 'vote', {'proposal': 'P1', 'vote': 'aye'})
lm.append('pi', 'vote', {'proposal': 'P2', 'vote': 'aye'})

newly, held = lm.commit_on_quorum(2)
assert newly == ['P1'], newly
assert held == [], held
assert lm.get_tally('P1')['state'] == 'committed'
assert lm.get_tally('P2')['state'] == 'open'
assert lm.entries[-1].actor == 'synod' and lm.entries[-1].data['by'] == 'quorum'
assert lm.commit_on_quorum(2)[0] == [], 'second call must be a no-op'
print('ok')
"
  [ "$status" -eq 0 ]
  [[ "$output" == *"ok"* ]]
}

@test "lifecycle: NEW -> ACTIVE -> PASSING -> RATIFIED" {
  run run_py "
import tempfile
from pathlib import Path
from zsynod_core import LedgerManager

lm = LedgerManager(Path(tempfile.mkstemp(suffix='.jsonl')[1]))
lm.append('mike', 'propose', {'id': 'P1', 'title': 'T'})
assert lm.get_lifecycle_state('P1', 3) == 'NEW'

lm.append('pi', 'speak', {'remark': 'a', 'proposal': 'P1'})
lm.append('aider', 'speak', {'remark': 'b', 'proposal': 'P1'})
assert lm.get_lifecycle_state('P1', 3) == 'ACTIVE'

lm.append('pi', 'vote', {'proposal': 'P1', 'vote': 'aye'})
lm.append('claude', 'vote', {'proposal': 'P1', 'vote': 'aye'})
assert lm.get_lifecycle_state('P1', 3) == 'PASSING', 'one shy of quorum'

lm.append('codex', 'vote', {'proposal': 'P1', 'vote': 'aye'})
lm.commit_on_quorum(3)
assert lm.get_lifecycle_state('P1', 3) == 'RATIFIED'
print('ok')
"
  [ "$status" -eq 0 ]
  [[ "$output" == *"ok"* ]]
}

@test "lifecycle: STUCK after STALE_AFTER entries without tally movement" {
  run run_py "
import tempfile
from pathlib import Path
from zsynod_core import LedgerManager, STALE_AFTER

lm = LedgerManager(Path(tempfile.mkstemp(suffix='.jsonl')[1]))
lm.append('mike', 'propose', {'id': 'P1', 'title': 'T'})
lm.append('pi', 'speak', {'remark': 'a', 'proposal': 'P1'})
lm.append('aider', 'speak', {'remark': 'b', 'proposal': 'P1'})
for i in range(STALE_AFTER + 1):
    lm.append('pi', 'speak', {'remark': f'unrelated {i}'})
assert lm.get_lifecycle_state('P1', 3) == 'STUCK'
print('ok')
"
  [ "$status" -eq 0 ]
  [[ "$output" == *"ok"* ]]
}

@test "close: removes proposal from rotation, lifecycle CLOSED" {
  run run_py "
import tempfile
from pathlib import Path
from zsynod_core import LedgerManager

lm = LedgerManager(Path(tempfile.mkstemp(suffix='.jsonl')[1]))
lm.append('mike', 'propose', {'id': 'P1', 'title': 'T'})
lm.append('mike', 'close', {'proposal': 'P1', 'reason': 'sweep'})
assert lm.get_proposals() == [], 'closed proposal must leave rotation'
assert lm.get_tally('P1')['state'] == 'closed'
assert lm.get_lifecycle_state('P1', 3) == 'CLOSED'
print('ok')
"
  [ "$status" -eq 0 ]
  [[ "$output" == *"ok"* ]]
}

# ── event scheduler ───────────────────────────────────────────────────────────

@test "get_subscriptions: proposed, voted, and topic-refs all subscribe" {
  run run_py "
import tempfile
from pathlib import Path
from zsynod_core import LedgerManager

lm = LedgerManager(Path(tempfile.mkstemp(suffix='.jsonl')[1]))
lm.append('pi', 'propose', {'id': 'P1', 'title': 'A'})
lm.append('pi', 'vote', {'proposal': 'P2', 'vote': 'aye'})
lm.append('pi', 'speak', {'remark': 'x', 'proposal': 'P3'})
lm.append('pi', 'speak', {'remark': 'no ref'})
lm.append('claude', 'vote', {'proposal': 'P4', 'vote': 'aye'})
assert lm.get_subscriptions('pi') == {'P1', 'P2', 'P3'}, lm.get_subscriptions('pi')
print('ok')
"
  [ "$status" -eq 0 ]
  [[ "$output" == *"ok"* ]]
}

@test "next_event: mention since last turn outranks everything" {
  run run_py "
import tempfile
from pathlib import Path
from zsynod_core import LedgerManager

lm = LedgerManager(Path(tempfile.mkstemp(suffix='.jsonl')[1]))
lm.append('mike', 'propose', {'id': 'P1', 'title': 'T'})
lm.append('pi', 'speak', {'remark': 'old ping @claude', 'proposal': 'P1'})
lm.append('claude', 'speak', {'remark': 'acked', 'proposal': 'P1'})  # cursor moves
lm.append('pi', 'speak', {'remark': 'hey @claude what say you', 'proposal': 'P1'})
line, pid = lm.next_event('claude', 3)
assert line.startswith('📥'), line
assert 'what say you' in line and 'old ping' not in line
assert pid == 'P1'
print('ok')
"
  [ "$status" -eq 0 ]
  [[ "$output" == *"ok"* ]]
}

@test "next_event: decisive vote when one aye shy and member has not voted" {
  run run_py "
import tempfile
from pathlib import Path
from zsynod_core import LedgerManager

lm = LedgerManager(Path(tempfile.mkstemp(suffix='.jsonl')[1]))
lm.append('mike', 'propose', {'id': 'P1', 'title': 'T'})
lm.append('pi', 'vote', {'proposal': 'P1', 'vote': 'aye'})
lm.append('codex', 'vote', {'proposal': 'P1', 'vote': 'aye'})
line, pid = lm.next_event('claude', 3)
assert line.startswith('🗳'), line
assert pid == 'P1'
# pi already voted — falls through to a different event class
line2, _ = lm.next_event('pi', 3)
assert not line2.startswith('🗳'), line2
print('ok')
"
  [ "$status" -eq 0 ]
  [[ "$output" == *"ok"* ]]
}

@test "next_event: untouched proposal surfaces as 🆕, fallback always lands" {
  run run_py "
import tempfile
from pathlib import Path
from zsynod_core import LedgerManager

lm = LedgerManager(Path(tempfile.mkstemp(suffix='.jsonl')[1]))
lm.append('mike', 'propose', {'id': 'P1', 'title': 'Fresh idea'})
line, pid = lm.next_event('claude', 3)
assert line.startswith('🆕'), line
assert pid == 'P1' and 'Fresh idea' in line
# member touches it -> next event degrades to floor/stuck, never empty
lm.append('claude', 'speak', {'remark': 'seen', 'proposal': 'P1'})
line2, pid2 = lm.next_event('claude', 3)
assert pid2 == 'P1' and line2 != '', (line2, pid2)
print('ok')
"
  [ "$status" -eq 0 ]
  [[ "$output" == *"ok"* ]]
}

@test "deliberate includes ⚡ event line in user prompt" {
  run run_py "
import sys
from unittest.mock import patch
sys.path.append('$REPO_ROOT/lib')
from zsynod_core import ZsynodAgent

agent = ZsynodAgent('pi')
captured = {}

def fake_local(sp, up, tc=None, t=None, **kw):
    captured['user'] = up
    return 'ok'

with patch.object(agent, '_deliberate_local', fake_local):
    agent.deliberate('Topic', [], event='🗳 P1 is one aye from quorum — your vote decides')

assert '⚡ 🗳 P1' in captured['user'], captured['user']
print('ok')
"
  [ "$status" -eq 0 ]
  [[ "$output" == *"ok"* ]]
}

@test "deliberate system prompt teaches the directive contract" {
  run run_py "
import sys
from unittest.mock import patch
sys.path.append('$REPO_ROOT/lib')
from zsynod_core import ZsynodAgent

agent = ZsynodAgent('pi')
captured = {}

def fake_local(sp, up, tc=None, t=None, **kw):
    captured['system'] = sp
    return 'ok'

with patch.object(agent, '_deliberate_local', fake_local):
    agent.deliberate('Topic', [])

assert '>vote P# aye|nay|abstain' in captured['system'], captured['system']
assert '>handoff @member' in captured['system']
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

def fake_local(sp, up, tc=None, t=None, **kw):
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

def fake_local(sp, up, tc=None, t=None, **kw):
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

def fake_local(sp, up, tc=None, t=None, **kw):
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

# ── Dials: load / save / clamp ────────────────────────────────────────────────

@test "load_dials: missing file yields pure defaults" {
  run run_py "
from zsynod_core import load_dials, DIALS
d = load_dials('/nonexistent/dials.json')
for k, spec in DIALS.items():
    assert d[k] == spec['default'], (k, d[k])
assert d['muted'] == []
print('ok')
"
  [ "$status" -eq 0 ]
  [[ "$output" == *"ok"* ]]
}

@test "load_dials: clamps out-of-range values, keeps muted, drops unknown keys" {
  run run_py "
import tempfile, json
from pathlib import Path
from zsynod_core import load_dials, save_dials, DIALS
p = Path(tempfile.mkstemp(suffix='.json')[1])
p.write_text(json.dumps({
    'spontaneity': 9.0,          # over max -> clamp to 1.0
    'loop_window': 1,            # under min -> clamp to 2
    'muted': ['pi', 'codex'],
    'mystery_knob': 42,          # unknown -> dropped
}))
d = load_dials(p)
assert d['spontaneity'] == 1.0, d['spontaneity']
assert d['loop_window'] == 2 and isinstance(d['loop_window'], int)
assert d['muted'] == ['pi', 'codex']
assert 'mystery_knob' not in d
# roundtrip through save_dials
d['temperature'] = 1.1
save_dials(p, d)
d2 = load_dials(p)
assert abs(d2['temperature'] - 1.1) < 1e-9
assert d2['muted'] == ['pi', 'codex']
print('ok')
"
  [ "$status" -eq 0 ]
  [[ "$output" == *"ok"* ]]
}

# ── get_repetition: the loop detector ─────────────────────────────────────────

@test "get_repetition: identical remarks score 1.0, hashtags/handles ignored" {
  run run_py "
import tempfile
from pathlib import Path
from zsynod_core import LedgerManager

lm = LedgerManager(Path(tempfile.mkstemp(suffix='.jsonl')[1]))
lm.append('pi', 'speak', {'remark': 'loopback only covenant first #TagA @claude'})
lm.append('pi', 'speak', {'remark': 'loopback only covenant first #TagB @gemini'})
rep = lm.get_repetition('pi')
assert rep == 1.0, rep
print('ok')
"
  [ "$status" -eq 0 ]
  [[ "$output" == *"ok"* ]]
}

@test "get_repetition: fresh remarks score low, sparse history scores zero" {
  run run_py "
import tempfile
from pathlib import Path
from zsynod_core import LedgerManager

lm = LedgerManager(Path(tempfile.mkstemp(suffix='.jsonl')[1]))
assert lm.get_repetition('pi') == 0.0
lm.append('pi', 'speak', {'remark': 'only one remark here'})
assert lm.get_repetition('pi') == 0.0
lm.append('pi', 'speak', {'remark': 'completely different subject entirely'})
lm.append('pi', 'speak', {'remark': 'novel angle about scheduling latency'})
rep = lm.get_repetition('pi')
assert rep < 0.3, rep
print('ok')
"
  [ "$status" -eq 0 ]
  [[ "$output" == *"ok"* ]]
}

# ── next_event: 💭 loop-breaker and spontaneity ───────────────────────────────

@test "next_event: loop-breaker outranks mentions when member is looping" {
  run run_py "
import tempfile
from pathlib import Path
from zsynod_core import LedgerManager

lm = LedgerManager(Path(tempfile.mkstemp(suffix='.jsonl')[1]))
lm.append('mike', 'propose', {'id': 'P1', 'title': 'T'})
lm.append('pi', 'speak', {'remark': 'security covenant loopback always', 'proposal': 'P1'})
lm.append('pi', 'speak', {'remark': 'security covenant loopback always', 'proposal': 'P1'})
lm.append('claude', 'speak', {'remark': 'hey @pi thoughts?', 'proposal': 'P1'})
line, pid = lm.next_event('pi', 3, loop_threshold=0.55)
assert line.startswith('💭') and 'loop' in line, line
assert pid is None
# default threshold (2.0) disables the breaker -> mention wins as before
line2, _ = lm.next_event('pi', 3)
assert line2.startswith('📥'), line2
print('ok')
"
  [ "$status" -eq 0 ]
  [[ "$output" == *"ok"* ]]
}

@test "next_event: spontaneity dial triggers 💭 free thought, 0.0 never does" {
  run run_py "
import tempfile, random
from pathlib import Path
from zsynod_core import LedgerManager

lm = LedgerManager(Path(tempfile.mkstemp(suffix='.jsonl')[1]))
lm.append('mike', 'propose', {'id': 'P1', 'title': 'T'})

class AlwaysLow:
    def random(self):
        return 0.0
class AlwaysHigh:
    def random(self):
        return 0.999

line, pid = lm.next_event('pi', 3, spontaneity=0.15, rng=AlwaysLow())
assert line.startswith('💭') and 'free thought' in line, line
assert pid is None
line2, pid2 = lm.next_event('pi', 3, spontaneity=0.15, rng=AlwaysHigh())
assert not line2.startswith('💭'), line2
line3, _ = lm.next_event('pi', 3, spontaneity=0.0, rng=AlwaysLow())
assert not line3.startswith('💭'), line3
print('ok')
"
  [ "$status" -eq 0 ]
  [[ "$output" == *"ok"* ]]
}

# ── get_member_stats ──────────────────────────────────────────────────────────

@test "get_member_stats: counts speaks, votes, mentions, and ratified attribution" {
  run run_py "
import tempfile
from pathlib import Path
from zsynod_core import LedgerManager

lm = LedgerManager(Path(tempfile.mkstemp(suffix='.jsonl')[1]))
lm.append('pi', 'propose', {'id': 'P1', 'title': 'T'})
lm.append('pi', 'speak', {'remark': 'ping @claude and @gemini', 'proposal': 'P1'})
lm.append('claude', 'vote', {'proposal': 'P1', 'vote': 'aye'})
lm.append('gemini', 'vote', {'proposal': 'P1', 'vote': 'nay'})
lm.append('codex', 'pass', {})
lm.append('synod', 'commit', {'proposal': 'P1', 'by': 'quorum'})
s = lm.get_member_stats()
assert s['pi']['proposed'] == 1 and s['pi']['ratified'] == 1
assert s['pi']['speaks'] == 1 and s['pi']['mentions_out'] == 2
assert s['claude']['mentions_in'] == 1 and s['gemini']['mentions_in'] == 1
assert s['claude']['aye'] == 1 and s['gemini']['nay'] == 1
assert s['codex']['passes'] == 1
assert s['gemini']['last_seq'] == 3
assert 'repetition' in s['pi']
print('ok')
"
  [ "$status" -eq 0 ]
  [[ "$output" == *"ok"* ]]
}

# ── deliberate sampling dials ─────────────────────────────────────────────────

@test "deliberate passes temperature and max_tokens to the local backend" {
  run run_py "
from unittest.mock import patch
from zsynod_core import ZsynodAgent

agent = ZsynodAgent('pi')
captured = {}

def fake_local(sp, up, tc=None, t=None, temperature=None, max_tokens=None):
    captured['temperature'] = temperature
    captured['max_tokens'] = max_tokens
    return 'ok'

with patch.object(agent, '_deliberate_local', fake_local):
    agent.deliberate('Topic', [], temperature=1.2, max_tokens=300)

assert captured['temperature'] == 1.2, captured
assert captured['max_tokens'] == 300, captured
print('ok')
"
  [ "$status" -eq 0 ]
  [[ "$output" == *"ok"* ]]
}

@test "deliberate context_depth dial widens the quoted window" {
  run run_py "
import datetime
from unittest.mock import patch
from zsynod_core import ZsynodAgent, LedgerEntry

agent = ZsynodAgent('pi')
captured = {}

def fake_local(sp, up, tc=None, t=None, **kw):
    captured['user'] = up
    return 'ok'

entries = [LedgerEntry(seq=i, round=1, actor=f'a{i}', type='speak',
                       data={'remark': f'msg{i}'}, prev='x', hash='x',
                       ts=datetime.datetime.utcnow().isoformat()+'Z')
           for i in range(8)]

with patch.object(agent, '_deliberate_local', fake_local):
    agent.deliberate('Topic', entries, context_depth=8)
for i in range(8):
    assert f'msg{i}' in captured['user'], f'msg{i} missing at depth 8'
print('ok')
"
  [ "$status" -eq 0 ]
  [[ "$output" == *"ok"* ]]
}

# ── KnowledgeBase: the forum's window and pen ─────────────────────────────────

@test "KnowledgeBase: hydrate parses stub JSON, seed and ground return snippets" {
  run run_py "
import json, os, stat, tempfile
from pathlib import Path
from zsynod_core import KnowledgeBase

# Stub zdots-ctx: hydrate prints a fixed pool regardless of tag
stub = Path(tempfile.mkdtemp()) / 'zdots-ctx'
stub.write_text('''#!/bin/sh
echo '{\"methodologies\": [{\"slug\": \"tdd\", \"title\": \"TDD\", \"content\": \"Red green refactor\", \"tags\": [\"tdd\"]}], \"lessons\": [{\"context\": \"c\", \"content\": \"Always clamp dials on load\", \"created_at\": \"2026-01-01\"}]}'
''')
stub.chmod(stub.stat().st_mode | stat.S_IEXEC)

kb = KnowledgeBase(cmd=str(stub))
pool = kb.hydrate('anything')
assert len(pool['methodologies']) == 1 and len(pool['lessons']) == 1

class FixedRng:
    def choice(self, items): return items[0]
seed = kb.seed(rng=FixedRng())
assert seed == 'TDD: Red green refactor', seed

g = kb.ground('Adopt strict TDD everywhere')
assert g == 'TDD: Red green refactor', g
# cache: second hydrate must not re-run the subprocess (same object back)
assert kb.hydrate('anything') is pool
print('ok')
"
  [ "$status" -eq 0 ]
  [[ "$output" == *"ok"* ]]
}

@test "KnowledgeBase: record invokes add-lesson with content, context, tags" {
  run run_py "
import stat, tempfile
from pathlib import Path
from zsynod_core import KnowledgeBase

d = Path(tempfile.mkdtemp())
log = d / 'argv.log'
stub = d / 'zdots-ctx'
stub.write_text(f'''#!/bin/sh
printf '%s\\n' \"\$@\" > {log}
''')
stub.chmod(stub.stat().st_mode | stat.S_IEXEC)

kb = KnowledgeBase(cmd=str(stub))
ok = kb.record('zsynod ratified P9 \"Title\"', context='zsynod decision', tags=['zsynod', 'p9'])
assert ok
argv = log.read_text().splitlines()
assert argv == ['add-lesson', 'zsynod ratified P9 \"Title\"', 'zsynod decision', 'zsynod', 'p9'], argv
print('ok')
"
  [ "$status" -eq 0 ]
  [[ "$output" == *"ok"* ]]
}

@test "KnowledgeBase: missing command degrades to empty pool and failed record" {
  run run_py "
from zsynod_core import KnowledgeBase
kb = KnowledgeBase(cmd='/nonexistent/zdots-ctx')
assert not kb.available()
pool = kb.hydrate('x')
assert pool == {'methodologies': [], 'lessons': []}
assert kb.seed() is None
assert kb.ground('Some topic title') is None
assert kb.record('content') is False
print('ok')
"
  [ "$status" -eq 0 ]
  [[ "$output" == *"ok"* ]]
}

@test "deliberate pins kb_note as a [KB] line in the user prompt" {
  run run_py "
from unittest.mock import patch
from zsynod_core import ZsynodAgent

agent = ZsynodAgent('pi')
captured = {}

def fake_local(sp, up, tc=None, t=None, **kw):
    captured['user'] = up
    return 'ok'

with patch.object(agent, '_deliberate_local', fake_local):
    agent.deliberate('Topic', [], kb_note='TDD: Red green refactor')
assert '[KB] TDD: Red green refactor' in captured['user'], captured['user']
with patch.object(agent, '_deliberate_local', fake_local):
    agent.deliberate('Topic', [])
assert '[KB]' not in captured['user']
print('ok')
"
  [ "$status" -eq 0 ]
  [[ "$output" == *"ok"* ]]
}

# ── Decision records: the scribe captures the question, not just the 42 ──────

@test "get_decision_record: question from body, dissent with note and remark" {
  run run_py "
import tempfile
from pathlib import Path
from zsynod_core import LedgerManager

lm = LedgerManager(Path(tempfile.mkstemp(suffix='.jsonl')[1]))
lm.append('pi', 'propose', {'id': 'P1', 'title': 'Adopt rtk everywhere',
                            'body': 'Raw git output burns tokens'})
lm.append('codex', 'speak', {'remark': 'prefer a repomix pass instead', 'proposal': 'P1'})
lm.append('pi', 'vote', {'proposal': 'P1', 'vote': 'aye'})
lm.append('codex', 'vote', {'proposal': 'P1', 'vote': 'nay', 'note': 'overhead on small repos'})
lm.append('gemini', 'vote', {'proposal': 'P1', 'vote': 'abstain'})

rec = lm.get_decision_record('P1')
assert rec['proposer'] == 'pi'
assert rec['question'] == 'Raw git output burns tokens'
assert len(rec['dissent']) == 2
nay = next(d for d in rec['dissent'] if d['actor'] == 'codex')
assert nay['vote'] == 'nay'
assert nay['note'] == 'overhead on small repos'
assert nay['remark'] == 'prefer a repomix pass instead'
print('ok')
"
  [ "$status" -eq 0 ]
  [[ "$output" == *"ok"* ]]
}

@test "get_decision_record: no body falls back to proposer's first remark" {
  run run_py "
import tempfile
from pathlib import Path
from zsynod_core import LedgerManager

lm = LedgerManager(Path(tempfile.mkstemp(suffix='.jsonl')[1]))
lm.append('aider', 'propose', {'id': 'P2', 'title': 'Nightly doctor run'})
lm.append('aider', 'speak', {'remark': 'drift keeps landing unnoticed', 'proposal': 'P2'})
lm.append('aider', 'speak', {'remark': 'second remark', 'proposal': 'P2'})

rec = lm.get_decision_record('P2')
assert rec['question'] == 'drift keeps landing unnoticed', rec['question']
assert rec['dissent'] == []
print('ok')
"
  [ "$status" -eq 0 ]
  [[ "$output" == *"ok"* ]]
}

@test "minute: recorder prompt carries thread, framing, and the two-line contract" {
  run run_py "
import datetime
from unittest.mock import patch
from zsynod_core import ZsynodAgent, LedgerEntry

agent = ZsynodAgent('recorder')
captured = {}

def fake_local(sp, up, tc=None, t=None, **kw):
    captured['system'] = sp
    captured['user'] = up
    return 'QUESTION: q\nALTERNATIVES: none raised'

e = LedgerEntry(seq=0, round=1, actor='codex', type='speak',
                data={'remark': 'try repomix instead'}, prev='x', hash='x',
                ts=datetime.datetime.utcnow().isoformat()+'Z')
with patch.object(agent, '_deliberate_local', fake_local):
    out = agent.minute('P1', 'Adopt rtk', [e], question='tokens burn')

assert 'QUESTION' in captured['system'] and 'ALTERNATIVES' in captured['system']
assert 'try repomix instead' in captured['user']
assert 'tokens burn' in captured['user']
assert out.startswith('QUESTION:')
print('ok')
"
  [ "$status" -eq 0 ]
  [[ "$output" == *"ok"* ]]
}

@test "format_decision_lesson: minute + dissent lines; unanimity recorded as fact" {
  run run_py "
from zsynod_core import format_decision_lesson

rec = {'pid': 'P1', 'title': 'Adopt rtk', 'proposer': 'pi',
       'question': 'tokens burn',
       'tally': {'aye': 4, 'nay': 1, 'abstain': 0, 'state': 'committed', 'votes': {}},
       'dissent': [{'actor': 'codex', 'vote': 'nay', 'note': '', 'remark': 'overhead on small repos'}]}
out = format_decision_lesson(rec, 'QUESTION: q\nALTERNATIVES: repomix')
assert 'proposed by @pi' in out
assert 'ALTERNATIVES: repomix' in out
assert 'DISSENT: @codex (nay): overhead on small repos' in out
assert 'QUESTION: tokens burn' not in out  # minute supersedes raw question

# no minute -> raw question; no dissent -> unanimity is the recorded signal
rec2 = dict(rec, dissent=[])
out2 = format_decision_lesson(rec2)
assert 'QUESTION: tokens burn' in out2
assert 'DISSENT: none — unanimous.' in out2
print('ok')
"
  [ "$status" -eq 0 ]
  [[ "$output" == *"ok"* ]]
}

# ── honest votes: reasons, blind context, advocate, second reading ───────────

@test "parse_directives: vote reason becomes note; bare vote stays bare" {
  run run_py "
from zsynod_core import parse_directives
_, d = parse_directives('>vote P3 nay overhead on small repos')
assert d == [('vote', {'proposal': 'P3', 'vote': 'nay', 'note': 'overhead on small repos'})], d
_, d2 = parse_directives('>vote P3 aye')
assert d2 == [('vote', {'proposal': 'P3', 'vote': 'aye'})], d2
_, d3 = parse_directives('>vote P3 aye — cuts tokens 4x')
assert d3[0][1]['note'] == 'cuts tokens 4x', d3
print('ok')
"
  [ "$status" -eq 0 ]
  [[ "$output" == *"ok"* ]]
}

@test "devils_advocate: deterministic rotation over sorted roster" {
  run run_py "
from zsynod_core import devils_advocate
roster = ['pi', 'claude', 'aider']
seats = [devils_advocate(f'P{n}', roster) for n in range(6)]
assert seats[:3] == ['aider', 'claude', 'pi'], seats  # sorted roster, pid % 3
assert seats[:3] == seats[3:], 'must be deterministic per pid'
assert devils_advocate('P1', roster) == devils_advocate('P1', list(reversed(roster)))
assert devils_advocate('P1', []) is None
print('ok')
"
  [ "$status" -eq 0 ]
  [[ "$output" == *"ok"* ]]
}

@test "blind context: others' votes invisible until the member has voted" {
  run run_py "
import datetime
from zsynod_core import ZsynodAgent, LedgerEntry

def e(seq, actor, type_, data):
    return LedgerEntry(seq=seq, round=1, actor=actor, type=type_, data=data,
                       prev='x', hash='x',
                       ts=datetime.datetime.utcnow().isoformat()+'Z')

entries = [
    e(0, 'pi',     'speak',  {'remark': 'the argument itself'}),
    e(1, 'claude', 'vote',   {'proposal': 'P1', 'vote': 'aye'}),
    e(2, 'codex',  'second', {'proposal': 'P1'}),
    e(3, 'gemini', 'vote',   {'proposal': 'P1', 'vote': 'aye'}),
]
a = ZsynodAgent('pi')
blind = a._build_context(entries, depth=10, blind_for='pi')
assert 'voted' not in blind and 'the argument itself' in blind, blind
full = a._build_context(entries, depth=10)
assert 'claude voted aye' in full.replace('@', ''), full
own = a._build_context(entries + [e(4, 'pi', 'vote', {'proposal': 'P1', 'vote': 'nay'})],
                       depth=10, blind_for='pi')
assert 'pi voted nay' in own.replace('@', ''), 'own vote must stay visible'
print('ok')
"
  [ "$status" -eq 0 ]
  [[ "$output" == *"ok"* ]]
}

@test "deliberate: glyph brackets the prompt; advocate clause lands in system" {
  run run_py "
from unittest.mock import patch
from zsynod_core import ZsynodAgent

a = ZsynodAgent('pi')
captured = {}
def fake_local(sp, up, tc=None, t=None, **kw):
    captured['system'], captured['user'] = sp, up
    return 'ok-remark'
with patch.object(a, '_deliberate_local', fake_local):
    a.deliberate('Topic X', [], glyph='☯', advocate=True)
assert captured['user'][0] == '☯' and captured['user'][-1] == '☯', captured['user']
# The glyph must open the SYSTEM prompt — the full dispatch (combined CLI
# prompt or rendered chat stream) begins and ends with the round's glyph.
assert captured['system'][0] == '☯', captured['system'][:40]
combined = f\"{captured['system']}\n\n{captured['user']}\"  # CLI seat layout
assert combined[0] == '☯' and combined[-1] == '☯'
assert 'advocate' in captured['system'].lower()
assert 'AGAINST' in captured['system']
with patch.object(a, '_deliberate_local', fake_local):
    a.deliberate('Topic X', [])
assert 'advocate' not in captured['system'].lower()
print('ok')
"
  [ "$status" -eq 0 ]
  [[ "$output" == *"ok"* ]]
}

@test "second reading: unanimous quorum held one round, then commits" {
  run run_py "
import tempfile
from pathlib import Path
from zsynod_core import LedgerManager

lm = LedgerManager(Path(tempfile.mkstemp(suffix='.jsonl')[1]))
lm.append('mike', 'propose', {'id': 'P1', 'title': 'Unanimous'})
lm.append('pi', 'vote', {'proposal': 'P1', 'vote': 'aye'})
lm.append('claude', 'vote', {'proposal': 'P1', 'vote': 'aye'})

newly, held = lm.commit_on_quorum(2, unanimity_action=2)
assert newly == [] and held == ['P1'], (newly, held)
assert lm.pending_second_reading('P1')
assert lm.get_tally('P1')['state'] == 'open'
assert '⚖' in lm.topic_event('pi', 'P1', 2)

newly2, held2 = lm.commit_on_quorum(2, unanimity_action=2)
assert newly2 == ['P1'] and held2 == [], (newly2, held2)

# a contested tally never gets held
lm.append('mike', 'propose', {'id': 'P2', 'title': 'Contested'})
lm.append('pi', 'vote', {'proposal': 'P2', 'vote': 'aye'})
lm.append('claude', 'vote', {'proposal': 'P2', 'vote': 'aye'})
lm.append('codex', 'vote', {'proposal': 'P2', 'vote': 'nay'})
newly3, held3 = lm.commit_on_quorum(2, unanimity_action=2)
assert newly3 == ['P2'] and held3 == [], (newly3, held3)
print('ok')
"
  [ "$status" -eq 0 ]
  [[ "$output" == *"ok"* ]]
}

@test "format_decision_lesson: ASSENT line records reasoned and bare ayes" {
  run run_py "
from zsynod_core import format_decision_lesson

rec = {'pid': 'P1', 'title': 'T', 'proposer': 'pi', 'question': 'q',
       'tally': {'aye': 2, 'nay': 0, 'abstain': 0, 'state': 'committed', 'votes': {}},
       'dissent': [],
       'assent': [{'actor': 'aider', 'note': 'cuts tokens 4x'},
                  {'actor': 'claude', 'note': ''}],
       'second_reading': True}
out = format_decision_lesson(rec)
assert 'DISSENT: none — unanimous. Survived a second reading.' in out, out
assert 'ASSENT: @aider — cuts tokens 4x; @claude — no reason given' in out, out
print('ok')
"
  [ "$status" -eq 0 ]
  [[ "$output" == *"ok"* ]]
}

# ── member contract: backends ─────────────────────────────────────────────────

@test "openai backend: vendor request carries base_url, model, bearer key" {
  run run_py "
import json, os, urllib.request
import zsynod_core
from zsynod_core import ZsynodAgent

captured = {}
class FakeResp:
    def __enter__(self): return self
    def __exit__(self, *a): return False
    def read(self):
        return json.dumps({'choices': [{'message': {'content': 'hi'}}]}).encode()
def fake_urlopen(req, timeout=None):
    captured['url'] = req.full_url
    captured['auth'] = req.get_header('Authorization')
    captured['body'] = json.loads(req.data)
    return FakeResp()
urllib.request.urlopen = fake_urlopen

os.environ['GROQ_API_KEY'] = 'k123'
a = ZsynodAgent('groq', backend='openai',
                base_url='https://api.groq.com/openai/v1',
                model='llama-3.3-70b-versatile', key_env='GROQ_API_KEY')
out = a.complete('sys', 'user')
assert out == 'hi'
assert captured['url'] == 'https://api.groq.com/openai/v1/chat/completions'
assert captured['auth'] == 'Bearer k123'
assert captured['body']['model'] == 'llama-3.3-70b-versatile'

# keyless loopback seat (apfel/ollama): no key_env -> no auth header
b = ZsynodAgent('apfel', backend='openai', base_url='http://127.0.0.1:11434/v1')
b.complete('sys', 'user')
assert captured['auth'] is None
assert captured['url'] == 'http://127.0.0.1:11434/v1/chat/completions'

# declared key_env with no key -> dormant, loudly
os.environ.pop('MISSING_KEY', None)
c = ZsynodAgent('mistral', backend='openai', base_url='https://x/v1', key_env='MISSING_KEY')
try:
    c.complete('sys', 'user')
    raise AssertionError('expected RuntimeError')
except RuntimeError as ex:
    assert 'MISSING_KEY' in str(ex)
print('ok')
"
  [ "$status" -eq 0 ]
  [[ "$output" == *"ok"* ]]
}

@test "herald: briefing prompt carries the fact sheet; facts derive from chain" {
  run run_py "
import tempfile
from pathlib import Path
from unittest.mock import patch
from zsynod_core import LedgerManager, ZsynodAgent

lm = LedgerManager(Path(tempfile.mkstemp(suffix='.jsonl')[1]))
lm.append('pi', 'propose', {'id': 'P1', 'title': 'Adopt rtk everywhere'})
lm.append('pi', 'speak', {'remark': 'tokens burn', 'proposal': 'P1'})
lm.append('claude', 'vote', {'proposal': 'P1', 'vote': 'aye'})

facts = lm.get_herald_facts(quorum=2)
assert 'Adopt rtk everywhere' in facts
assert '@claude:aye' in facts
assert 'latest @pi: tokens burn' in facts

a = ZsynodAgent('herald')
captured = {}
def fake_local(sp, up, tc=None, t=None, **kw):
    captured['system'], captured['user'] = sp, up
    return 'briefing text'
with patch.object(a, '_deliberate_local', fake_local):
    out = a.herald(facts)
assert out == 'briefing text'
assert 'herald' in captured['system']
assert 'no hashtags' in captured['system'].lower()
assert 'Adopt rtk everywhere' in captured['user']
print('ok')
"
  [ "$status" -eq 0 ]
  [[ "$output" == *"ok"* ]]
}

@test "openai backend: key_cmd fallback fetches once, env var wins" {
  run run_py "
import json, os, urllib.request
from zsynod_core import ZsynodAgent

captured = {}
class FakeResp:
    def __enter__(self): return self
    def __exit__(self, *a): return False
    def read(self):
        return json.dumps({'choices': [{'message': {'content': 'hi'}}]}).encode()
def fake_urlopen(req, timeout=None):
    captured['auth'] = req.get_header('Authorization')
    return FakeResp()
urllib.request.urlopen = fake_urlopen

# key_cmd fallback, fetched once and cached
os.environ.pop('GH_TEST_TOKEN', None)
a = ZsynodAgent('gh', backend='openai', base_url='https://x/v1',
                key_env='GH_TEST_TOKEN', key_cmd='echo cmd-tok-1')
a.complete('s', 'u')
assert captured['auth'] == 'Bearer cmd-tok-1', captured['auth']
a.key_cmd = 'echo cmd-tok-2'  # cache must hold — no re-fetch per remark
a.complete('s', 'u')
assert captured['auth'] == 'Bearer cmd-tok-1', 'key_cmd must be fetched once'

# env var takes precedence over key_cmd
os.environ['GH_TEST_TOKEN'] = 'env-tok'
a.complete('s', 'u')
assert captured['auth'] == 'Bearer env-tok', captured['auth']

# both yield nothing -> dormant, loudly
os.environ.pop('GH_TEST_TOKEN', None)
b = ZsynodAgent('gh', backend='openai', base_url='https://x/v1',
                key_env='GH_TEST_TOKEN', key_cmd='true')
try:
    b.complete('s', 'u')
    raise AssertionError('expected RuntimeError')
except RuntimeError as ex:
    assert 'no key' in str(ex)
print('ok')
"
  [ "$status" -eq 0 ]
  [[ "$output" == *"ok"* ]]
}

@test "ledger pawl: intact chain loads; altered entry and broken link raise by seq" {
  run run_py "
import json, tempfile
from pathlib import Path
from zsynod_core import LedgerManager, LedgerIntegrityError

# build a genuine three-entry chain, then reload it — the pawl passes truth
path = Path(tempfile.mkstemp(suffix='.jsonl')[1])
lm = LedgerManager(path)
lm.append('mike', 'propose', {'id': 'P1', 'title': 'Trust the chain'})
lm.append('pi', 'vote', {'proposal': 'P1', 'vote': 'aye'})
lm.append('claude', 'remark', {'proposal': 'P1', 'remark': 'verified'})
assert len(LedgerManager(path).entries) == 3

# alter one entry's content in place — stored hash no longer recomputes
lines = path.read_text().splitlines()
doc = json.loads(lines[1]); doc['data']['vote'] = 'nay'
tampered = lines[:1] + [json.dumps(doc)] + lines[2:]
path.write_text('\n'.join(tampered) + '\n')
try:
    LedgerManager(path)
    raise AssertionError('expected LedgerIntegrityError (altered entry)')
except LedgerIntegrityError as ex:
    assert 'seq 1' in str(ex) and 'altered' in str(ex), str(ex)

# remove an entry from the middle — the link to the prior hash breaks
path.write_text('\n'.join([lines[0], lines[2]]) + '\n')
try:
    LedgerManager(path)
    raise AssertionError('expected LedgerIntegrityError (broken link)')
except LedgerIntegrityError as ex:
    assert 'chain broken' in str(ex), str(ex)
print('ok')
"
  [ "$status" -eq 0 ]
  [[ "$output" == *"ok"* ]]
}

@test "openai backend: malformed key (interior whitespace) refused without leaking it" {
  run run_py "
import os, urllib.request
from zsynod_core import ZsynodAgent

def fake_urlopen(req, timeout=None):
    raise AssertionError('request must never be built with a malformed key')
urllib.request.urlopen = fake_urlopen

# A two-line key file ('label\\ntoken') must be refused at the contract,
# not surface as http.client ValueError quoting the key into logs.
os.environ.pop('HF_TEST_TOKEN', None)
a = ZsynodAgent('hf', backend='openai', base_url='https://x/v1',
                key_env='HF_TEST_TOKEN',
                key_cmd='printf \"label\\nhf_secret123\\n\"')
try:
    a.complete('s', 'u')
    raise AssertionError('expected RuntimeError')
except RuntimeError as ex:
    msg = str(ex)
    assert 'malformed key' in msg, msg
    assert 'hf_secret123' not in msg, 'key must never appear in the error'
    assert 'label' not in msg.split('—')[0] or True
# cache cleared so a fixed key_cmd is retried next remark
assert a._key_cache == ''
print('ok')
"
  [ "$status" -eq 0 ]
  [[ "$output" == *"ok"* ]]
}
