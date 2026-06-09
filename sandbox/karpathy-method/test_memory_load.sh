#!/bin/bash
# Test: Memory/Latency Load Test for llama-server

MODEL="local"
ENDPOINT="http://127.0.0.1:11500/v1/chat/completions"
METRICS="http://127.0.0.1:11500/metrics"

# Generate synthetic context of N tokens (roughly 4 chars per token)
generate_context() {
    local tokens=$1
    python3 -c "print(' '.join(['word'] * $tokens))"
}

run_test() {
    local tokens=$1
    echo "--- Testing with $tokens tokens ---"
    
    # 1. Capture baseline metrics
    local start_metrics=$(curl -s $METRICS | grep -E "prompt|gen|tokens")
    
    # 2. Fire request and measure time
    local context=$(generate_context $tokens)
    
    start_time=$(python3 -c "import time; print(time.time())")
    curl -s -X POST $ENDPOINT \
        -H "Content-Type: application/json" \
        -d "{\"model\":\"$MODEL\",\"messages\":[{\"role\":\"user\",\"content\":\"$context\\n\\nSummarize this text in 5 words.\"}],\"stream\":false}" > /dev/null
    end_time=$(python3 -c "import time; print(time.time())")
    
    duration=$(python3 -c "print(int(($end_time - $start_time) * 1000))")
    echo "Latency: ${duration}ms"
    
    # 3. Capture post-request metrics
    local end_metrics=$(curl -s $METRICS | grep -E "prompt|gen|tokens")
    echo "Metrics Delta:"
    # (Simplified diff for MVP)
    echo "$end_metrics" | diff - <(echo "$start_metrics")
    echo ""
}

# Run sequence
for t in 512 1024 2048 4096; do
    run_test $t
done
