#!/bin/bash
set -euo pipefail

cd /workspace

# Output file
OUTPUT_FILE="references/cdn-speed-survey.md"

# Write header
cat > "$OUTPUT_FILE" << EOF
# CDN Speed Survey

Generated at $(date -u +"%Y-%m-%dT%H:%M:%SZ")

## Results

| URL | Type | HTTP Status | Time (s) | Speed (B/s) | Content-Length | Category |
|-----|------|-------------|----------|-------------|----------------|----------|
EOF

# URLs to test
URLS=(
    "https://dl.google.com/android/repository/repository2-3.xml|Google CDN"
    "https://storage.googleapis.com|Google Cloud"
    "https://github.com|GitHub"
    "https://objects.githubusercontent.com|GitHub Storage"
    "https://registry.npmjs.org|npm"
    "https://npmmirror.com/mirrors/npm/index.json|npm mirror"
    "https://crates.io/api/v1/summary|Rust/Cargo"
    "https://rsproxy.cn/api/v1/crates|Rust mirror"
    "https://files.pythonhosted.org/packages/PyYAML-6.0.1.tar.gz|PyPI"
    "https://pypi.tuna.tsinghua.edu.cn/simple|PyPI mirror"
    "https://dl-cdn.alpinelinux.org/alpine/v3.19/main/x86_64/APKINDEX.tar.gz|Alpine"
    "https://httpbin.org/get|International baseline"
)

# Test each URL
for item in "${URLS[@]}"; do
    IFS='|' read -r URL TYPE <<< "$item"
    echo "Testing $URL..."

    # Use curl with proxy (GET request, not HEAD, to get actual speed)
    RESULT=$(curl -x http://127.0.0.1:18080 -L --max-time 30 -w '{"http_code": "%{http_code}", "time_total": %{time_total}, "speed_download": %{speed_download}, "content_length": "%{size_download}"}' -s -o /dev/null "$URL" 2>&1 || true)

    # Parse result
    HTTP_CODE=$(echo "$RESULT" | grep -oE '"http_code": "[^"]+"' | cut -d'"' -f4 || echo "000")
    TIME_TOTAL=$(echo "$RESULT" | grep -oE '"time_total": [0-9.]+' | cut -d: -f2 | tr -d ' ' || echo "0")
    SPEED=$(echo "$RESULT" | grep -oE '"speed_download": [0-9.]+' | cut -d: -f2 | tr -d ' ' || echo "0")
    CONTENT_LENGTH=$(echo "$RESULT" | grep -oE '"content_length": "[^"]+"' | cut -d'"' -f4 || echo "0")

    # Determine category
    CATEGORY=""
    if [ -z "$SPEED" ] || [ "$SPEED" = "0" ]; then
        if [ "$HTTP_CODE" = "000" ]; then
            CATEGORY="TIMEOUT"
        else
            CATEGORY="FAIL"
        fi
    else
        # Use awk for floating point comparison
        if awk -v s="$SPEED" 'BEGIN {if (s > 102400) print 1; else print 0}' | grep -q 1; then
            CATEGORY="高速 (>100KB/s)"
        elif awk -v s="$SPEED" 'BEGIN {if (s > 10240) print 1; else print 0}' | grep -q 1; then
            CATEGORY="中速 (10-100KB/s)"
        elif awk -v s="$SPEED" 'BEGIN {if (s > 0) print 1; else print 0}' | grep -q 1; then
            CATEGORY="低速 (<10KB/s)"
        else
            CATEGORY="FAIL"
        fi
    fi

    # Append to output file
    echo "| $URL | $TYPE | $HTTP_CODE | $TIME_TOTAL | $SPEED | $CONTENT_LENGTH | $CATEGORY |" >> "$OUTPUT_FILE"
done

echo "" >> "$OUTPUT_FILE"
echo "## Summary" >> "$OUTPUT_FILE"
echo "- Generated at $(date -u +"%Y-%m-%dT%H:%M:%SZ")" >> "$OUTPUT_FILE"

echo "Done! Results saved to $OUTPUT_FILE"
