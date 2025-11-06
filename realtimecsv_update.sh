#!/bin/bash

API_KEY="5dc013077b983b1636f79036dd6ba8b1"
OUTPUT="movies.csv"
SEEN_IDS_FILE="seen_ids.txt"
PAGES_TO_FETCH=20
MAX_PAGES_IN_CSV=50
MOVIES_PER_PAGE=20
MAX_MOVIES_IN_CSV=$((MAX_PAGES_IN_CSV * MOVIES_PER_PAGE))
RUN_INTERVAL_SECONDS=60
MAX_RETRIES=5
RETRY_DELAY=5
set -euo pipefail

touch "$OUTPUT" "$SEEN_IDS_FILE"
if [[ ! -s "$OUTPUT" ]]; then
    echo "ID,Title,Genre,Rating,Year,Director" > "$OUTPUT"
fi

fetch_with_retry() {
    local url="$1"
    local response=""
    local attempt=1
    while (( attempt <= MAX_RETRIES )); do
        response=$(curl -s --fail "$url" || true)
        if [[ -n "$response" ]] && echo "$response" | jq empty >/dev/null 2>&1; then
            echo "$response"
            return 0
        fi
        ((attempt++))
        sleep "$RETRY_DELAY"
    done
