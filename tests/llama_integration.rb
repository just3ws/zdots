#!/usr/bin/env ruby
# tests/llama_integration.rb — RubyLLM × llama.cpp integration test and demo
#
# Exercises every capability that llama.cpp exposes through the OpenAI-compatible
# API and validates that RubyLLM can reach each one. Use this to confirm the
# server is wired correctly before building any app on top of it.
#
# ─────────────────────────────────────────────────────────────────────────────
# INTEGRATION GUIDE — what every client connecting to llama.cpp MUST know
# ─────────────────────────────────────────────────────────────────────────────
#
# 1. ENDPOINT
#      http://127.0.0.1:8080   (read ZDOTS_AI_ENDPOINT; see etc/ai-models.yaml)
#
# 2. MODEL — use the SERVER ALIAS, not the GGUF filename
#      alias: "local"  is set in etc/ai-models.yaml → server.alias
#      The alias is what llama-server advertises in GET /v1/models.
#      Using the GGUF filename will cause:
#        • 404 from the server if the model field doesn't match
#        • "Unknown model" from RubyLLM's internal model registry
#      Always read the alias, never ZDOTS_AI_MODEL (which is the filename).
#
# 3. AUTH
#      llama.cpp ignores the Authorization header.
#      Set openai_api_key to any non-empty string so RubyLLM doesn't error.
#
# 4. RUBYLLM MODEL REGISTRY BYPASS
#      RubyLLM validates model IDs against its built-in registry of cloud
#      models. The local alias ("local") is not in that list, so every
#      chat/embed call must pass:
#        assume_model_exists: true, provider: "openai"
#      Without these two kwargs, RubyLLM raises ModelNotFoundError.
#
# 5. SYSTEM ROLE
#      Qwen2.5 supports the "system" role natively.
#      Set openai_use_system_role: true in RubyLLM.configure.
#      Use chat.with_instructions("...") to set a system prompt.
#
# 6. EMBEDDINGS — separate server (port 8090)
#      Embeddings run on a dedicated Nomic embed-v2 MoE server (port 8090).
#      The chat server (port 8080) has embeddings DISABLED: combining
#      --embeddings with --spec-draft-model causes a llama.cpp crash loop.
#      Use ZDOTS_AI_EMBED_ENDPOINT (default http://127.0.0.1:8090).
#      Model alias: "embed" (768-dim output; set in etc/ai-models.yaml).
#      ubatch_size in embed_server: section must be >= longest input tokens.
#      Manage with: llama-ctl install-embed / start-embed / stop-embed
#
# 7. STREAMING
#      Supported via SSE. Pass a block to chat.ask { |chunk| ... }.
#      Chunks arrive as RubyLLM::Chunk objects; chunk.content is the token.
#
# 8. TOOL USE / FUNCTION CALLING
#      Supported for Qwen2.5 (jinja chat template enabled by default).
#      Define a subclass of RubyLLM::Tool and attach with chat.with_tool(…).
#      The model will emit a tool_calls JSON block; RubyLLM dispatches it
#      to your tool's #execute method and resumes the conversation.
#      Complex nested schemas or strict: true may not parse cleanly—keep
#      tool definitions simple and verify with --debug if calls go missing.
#
# 9. NOT SUPPORTED by the current setup
#      • Image generation    — llama-server has no /v1/images/generations
#      • Audio transcription — no Whisper model loaded
#      • Moderation          — OpenAI-specific endpoint, not in llama-server
#
# 10. PLIST STALENESS
#      etc/ai-models.yaml is the single source of truth for server flags.
#      After every edit, run `llama-ctl install` to regenerate the plist.
#      The running server will NOT pick up YAML changes until reinstalled.
#
# ─────────────────────────────────────────────────────────────────────────────
# Usage
# ─────────────────────────────────────────────────────────────────────────────
#   ruby tests/llama_integration.rb           # full suite
#   ruby tests/llama_integration.rb --quick   # health-check mode (fast subset)
#   ZDOTS_AI_ENDPOINT=http://…:8080 ruby tests/llama_integration.rb

require "ruby_llm"
require "net/http"
require "uri"
require "json"

# ─────────────────────────────────────────────────────────────────────────────
# Config
# ─────────────────────────────────────────────────────────────────────────────
ENDPOINT       = ENV.fetch("ZDOTS_AI_ENDPOINT",       "http://127.0.0.1:8080")
EMBED_ENDPOINT = ENV.fetch("ZDOTS_AI_EMBED_ENDPOINT",  "http://127.0.0.1:8090")
MODEL          = ENV.fetch("ZDOTS_AI_MODEL_ALIAS",     "local")   # alias, never GGUF filename
EMBED_MODEL    = ENV.fetch("ZDOTS_AI_EMBED_MODEL",     "embed")   # Nomic embed-v2 alias
PROVIDER       = "openai"                                          # llama.cpp speaks OpenAI API
QUICK          = ARGV.include?("--quick")                         # fast subset for health checks

# ─────────────────────────────────────────────────────────────────────────────
# Minimal test runner
# ─────────────────────────────────────────────────────────────────────────────
PASS = "\e[32mPASS\e[0m"
FAIL = "\e[31mFAIL\e[0m"
SKIP = "\e[33mSKIP\e[0m"

$results = { pass: 0, fail: 0, skip: 0 }

def test(name, slow: false)
  if slow && QUICK
    print "  #{name.ljust(56)} "
    puts "#{SKIP}  quick mode"
    $results[:skip] += 1
    return
  end
  print "  #{name.ljust(56)} "
  begin
    yield
    puts PASS
    $results[:pass] += 1
  rescue SkipTest => e
    puts "#{SKIP}  #{e.message}"
    $results[:skip] += 1
  rescue => e
    puts "#{FAIL}  #{e.message}"
    $results[:fail] += 1
  end
end

class SkipTest < StandardError; end
def skip!(msg) = raise SkipTest, msg
def assert(cond, msg = "assertion failed")
  raise msg unless cond
end

def http_get(path, timeout: 5)
  uri = URI("#{ENDPOINT}#{path}")
  Net::HTTP.start(uri.host, uri.port, open_timeout: timeout, read_timeout: timeout) do |h|
    h.get(uri.path)
  end
end

# ─────────────────────────────────────────────────────────────────────────────
# RubyLLM configuration
# ─────────────────────────────────────────────────────────────────────────────
RubyLLM.configure do |c|
  c.openai_api_key          = "local"           # auth is ignored by llama.cpp
  c.openai_api_base         = "#{ENDPOINT}/v1"
  c.openai_use_system_role  = true              # Qwen supports system role
  c.default_model           = MODEL
  c.request_timeout         = 90
  c.max_retries             = 0                 # fail fast in tests
end

# Direct HTTP helper for the embed server (port 8090, Nomic embed-v2 MoE).
# Embeddings are on a separate server because --embeddings + --spec-draft-model
# causes a llama.cpp crash loop. Do not use RubyLLM for embeddings.
def http_post_embed(input)
  uri  = URI("#{EMBED_ENDPOINT}/v1/embeddings")
  body = JSON.generate({ model: EMBED_MODEL, input: input })
  res  = Net::HTTP.start(uri.host, uri.port, open_timeout: 5, read_timeout: 60) do |h|
    h.post(uri.path, body, "Content-Type" => "application/json")
  end
  raise "embed HTTP #{res.code}: #{res.body[0, 200]}" unless res.code.to_i == 200
  JSON.parse(res.body)
end

# Shared chat options — every chat/embed call needs these two
CHAT_OPTS = { model: MODEL, provider: PROVIDER, assume_model_exists: true }.freeze

# ─────────────────────────────────────────────────────────────────────────────
# Tool definition for tool-use test
# ─────────────────────────────────────────────────────────────────────────────
class UnitConverter < RubyLLM::Tool
  description "Converts a value from one unit to another. " \
              "Supports: km/miles, celsius/fahrenheit, kg/pounds."

  param :value,     type: "number", desc: "The numeric value to convert", required: true
  param :from_unit, type: "string", desc: "Source unit (km, miles, celsius, fahrenheit, kg, pounds)", required: true
  param :to_unit,   type: "string", desc: "Target unit", required: true

  def execute(value:, from_unit:, to_unit:)
    result = case [from_unit.downcase, to_unit.downcase]
             in ["km",         "miles"]       then (value * 0.621371).round(4)
             in ["miles",      "km"]          then (value * 1.60934).round(4)
             in ["celsius",    "fahrenheit"]  then ((value * 9.0 / 5) + 32).round(4)
             in ["fahrenheit", "celsius"]     then (((value - 32) * 5.0) / 9).round(4)
             in ["kg",         "pounds"]      then (value * 2.20462).round(4)
             in ["pounds",     "kg"]          then (value * 0.453592).round(4)
             else return { error: "unsupported conversion: #{from_unit} → #{to_unit}" }
             end
    { result: result, from: "#{value} #{from_unit}", to: "#{result} #{to_unit}" }
  end
end

# ─────────────────────────────────────────────────────────────────────────────
# Tests
# ─────────────────────────────────────────────────────────────────────────────
mode_label = QUICK ? "quick" : "full"
puts "\nllama.cpp × RubyLLM integration  [#{mode_label} mode]"
puts "  endpoint : #{ENDPOINT}"
puts "  model    : #{MODEL}  (server alias)"
puts "  provider : #{PROVIDER}"
puts

# ── Layer 1: Raw HTTP ─────────────────────────────────────────────────────────
puts "── 1. Server (raw HTTP) ─────────────────────────────────────────────────"

server_up = false

test "GET /health → {status: ok}" do
  r = http_get("/health")
  assert r.code == "200", "HTTP #{r.code}"
  body = JSON.parse(r.body)
  assert body["status"] == "ok", "status=#{body["status"].inspect}"
  server_up = true
end

test "GET /v1/models → alias '#{MODEL}' present" do
  skip! "server not reachable" unless server_up
  r = http_get("/v1/models")
  assert r.code == "200", "HTTP #{r.code}"
  ids = JSON.parse(r.body)["data"].map { |m| m["id"] }
  assert ids.include?(MODEL), "'#{MODEL}' not in #{ids.inspect}"
end

test "GET /metrics → Prometheus output present" do
  skip! "server not reachable" unless server_up
  r = http_get("/metrics", timeout: 3)
  assert r.code == "200", "HTTP #{r.code}"
  assert r.body.include?("llamacpp"), "missing llamacpp metrics"
end

# ── Layer 2: Chat ─────────────────────────────────────────────────────────────
puts
puts "── 2. Chat ──────────────────────────────────────────────────────────────"

chat = nil

test "RubyLLM.chat — instantiate with assume_model_exists" do
  skip! "server not reachable" unless server_up
  chat = RubyLLM.chat(**CHAT_OPTS)
  assert chat, "nil chat object"
end

test "chat.ask — basic user message → non-empty reply" do
  skip! "chat not initialized" unless chat
  r = chat.ask("/no_think Reply with exactly the word: PONG")
  assert r.content.is_a?(String) && !r.content.strip.empty?, "empty or nil content"
end

test "chat.ask — system role via with_instructions" do
  skip! "chat not initialized" unless chat
  c = RubyLLM.chat(**CHAT_OPTS)
  c.with_instructions("You are a concise assistant. Always respond in one sentence.")
  r = c.ask("/no_think What is 2+2?")
  assert r.content.include?("4"), "expected '4' in: #{r.content.inspect}"
end

test "chat.ask — multi-turn context retained", slow: true do
  skip! "chat not initialized" unless chat
  c = RubyLLM.chat(**CHAT_OPTS)
  c.ask("/no_think Remember this code word: ZEPHYR")
  r = c.ask("/no_think What code word did I ask you to remember?")
  assert r.content.upcase.include?("ZEPHYR"), "context lost; got: #{r.content.inspect}"
end

# ── Layer 3: Streaming ───────────────────────────────────────────────────────
puts
puts "── 3. Streaming (SSE) ───────────────────────────────────────────────────"

test "chat.ask with block → chunks stream before completion", slow: true do
  skip! "chat not initialized" unless chat
  chunks = []
  c = RubyLLM.chat(**CHAT_OPTS)
  c.ask("/no_think Count from 1 to 5, one number per line.") { |chunk| chunks << chunk.content if chunk.content }
  assert chunks.length > 1, "expected multiple chunks, got #{chunks.length}"
  full = chunks.join
  assert full.match?(/[1-5]/), "streamed content missing numbers: #{full.inspect}"
end

# ── Layer 4: Tool use ─────────────────────────────────────────────────────────
puts
puts "── 4. Tool use (function calling) ───────────────────────────────────────"

test "tool — model invokes UnitConverter for a conversion request", slow: true do
  skip! "server not reachable" unless server_up
  c = RubyLLM.chat(**CHAT_OPTS)
  c.with_tool(UnitConverter.new)
  r = c.ask("/no_think Convert 100 km to miles. Reply with just the numeric result.")
  # 100 km = 62.1371 miles; accept any response containing the right digits
  assert r.content.match?(/62\.1/), "expected ~62.1 in: #{r.content.inspect}"
end

# ── Layer 5: Embeddings (port 8090, Nomic embed-v2 MoE) ──────────────────────
# The embedding server is separate from the chat server. It cannot share a
# process with speculative decoding — use EMBED_ENDPOINT (127.0.0.1:8090).
puts
puts "── 5. Embeddings (embed server: #{EMBED_ENDPOINT}) ──────────────────────"

embed_up = false

test "GET #{EMBED_ENDPOINT}/health → {status: ok}" do
  r = http_get("/health").tap {} rescue (skip! "embed server unreachable"; nil)
  # embed server has its own endpoint
  uri = URI("#{EMBED_ENDPOINT}/health")
  res = Net::HTTP.start(uri.host, uri.port, open_timeout: 3, read_timeout: 5) { |h| h.get(uri.path) }
  assert res.code == "200", "HTTP #{res.code}"
  body = JSON.parse(res.body)
  assert body["status"] == "ok", "status=#{body["status"].inspect}"
  embed_up = true
end

test "embed — returns a 768-dim float vector (Nomic embed-v2)" do
  skip! "embed server not reachable" unless embed_up
  data = http_post_embed("hello world")
  vec  = data.dig("data", 0, "embedding")
  assert vec.is_a?(Array) && !vec.empty?, "bad vectors"
  assert vec.all? { |v| v.is_a?(Float) }, "non-float in vector"
  assert vec.length == 768, "expected 768 dims, got #{vec.length}"
end

test "embed — dimensionality consistent across different inputs" do
  skip! "embed server not reachable" unless embed_up
  a = http_post_embed("apple").dig("data", 0, "embedding")
  b = http_post_embed("orange").dig("data", 0, "embedding")
  assert a.length == b.length, "dim #{a.length} vs #{b.length}"
end

test "embed — similar texts closer than dissimilar (cosine)", slow: true do
  skip! "embed server not reachable" unless embed_up

  cosine = ->(a, b) do
    dot  = a.zip(b).sum { |x, y| x * y }
    norm = ->(v) { Math.sqrt(v.sum { |x| x**2 }) }
    dot / (norm[a] * norm[b])
  end

  v_cat1 = http_post_embed("The cat sat on the mat.").dig("data",   0, "embedding")
  v_cat2 = http_post_embed("A feline rested on a rug.").dig("data", 0, "embedding")
  v_diff = http_post_embed("Stock market futures rose.").dig("data", 0, "embedding")

  near = cosine[v_cat1, v_cat2]
  far  = cosine[v_cat1, v_diff]
  assert near > far, "near=#{near.round(3)} should exceed far=#{far.round(3)}"
end

# ── Layer 6: Capabilities not supported ───────────────────────────────────────
puts
puts "── 6. Unsupported capabilities (expected failures) ──────────────────────"

test "image generation → 404 (not implemented by llama-server)", slow: true do
  skip! "server not reachable" unless server_up
  uri  = URI("#{ENDPOINT}/v1/images/generations")
  body = JSON.generate({ model: MODEL, prompt: "a cat", n: 1, size: "256x256" })
  r    = Net::HTTP.start(uri.host, uri.port, open_timeout: 3, read_timeout: 5) do |h|
    h.post(uri.path, body, "Content-Type" => "application/json")
  end
  assert r.code != "200", "unexpectedly got 200 — llama-server may now support images"
end

# ─────────────────────────────────────────────────────────────────────────────
# Summary
# ─────────────────────────────────────────────────────────────────────────────
puts
total  = $results.values.sum
passed = $results[:pass]
failed = $results[:fail]
skip_n = $results[:skip]
label  = failed > 0 ? "\e[31mFAILED\e[0m" : "\e[32mPASSED\e[0m"
suffix = skip_n > 0 ? ", #{skip_n} skipped" : ""
puts "── #{label}  #{passed}/#{total - skip_n} passed#{suffix} ─────────────────────────────────────"

if failed > 0 && !QUICK
  puts
  puts "Troubleshooting:"
  puts "  llama-ctl status        — is the server running?"
  puts "  llama-ctl logs          — check for model load errors"
  puts "  llama-ctl install       — regenerate plist after yaml changes"
  puts "  RUBYLLM_DEBUG=true ...  — dump raw request/response JSON"
end
puts

exit(failed > 0 ? 1 : 0)
