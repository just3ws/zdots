#!/bin/bash
# Zdots Inference Benchmark
# Usage: ./run_benchmark.sh [label]

LABEL=${1:-baseline}
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
OUT_FILE="${LABEL}_${TIMESTAMP}.json"
MODEL="local"
ENDPOINT="http://127.0.0.1:11500/v1/chat/completions"
METRICS="http://127.0.0.1:11500/metrics"

echo "Running benchmark: $LABEL at $TIMESTAMP"

# Helper for synthetic context
generate_context() {
    python3 -c "print(' '.join(['word'] * $1))"
}

# Array to store results
RESULTS=()

# Run sequence
for t in 512 1024 2048; do
    echo "Testing $t tokens..."
    CONTEXT=$(generate_context $t)
    
    START=$(python3 -c "import time; print(time.time())")
    curl -s -X POST $ENDPOINT \
        -H "Content-Type: application/json" \
        -d "{\"model\":\"$MODEL\",\"messages\":[{\"role\":\"user\",\"content\":\"$CONTEXT\\n\\nSummarize.\"}],\"stream\":false}" > /dev/null
    END=$(python3 -c "import time; print(time.time())")
    
    LATENCY=$(python3 -c "print(int(($END - $START) * 1000))")
    
    RESULTS+=("{\"tokens\": $t, \"latency_ms\": $LATENCY}")
done

# Build JSON
cat <<EOF > $OUT_FILE
{
  "timestamp": "$TIMESTAMP",
  "label": "$LABEL",
  "results": [$(IFS=,; echo "${RESULTS[*]}")]
}
EOF

echo "Benchmark complete: $OUT_FILE"
cat $OUT_FILE
