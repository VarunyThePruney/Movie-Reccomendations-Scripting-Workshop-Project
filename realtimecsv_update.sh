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
    return 1
}

while true; do
    for page in $(seq 1 "$PAGES_TO_FETCH"); do
        page_json=$(fetch_with_retry "https://api.themoviedb.org/3/movie/popular?api_key=$API_KEY&page=$page") || continue
        if ! echo "$page_json" | jq empty >/dev/null 2>&1; then
            continue
        fi
        echo "$page_json" | jq -r '.results[].id' | while read -r id; do
            [[ -z "$id" || "$id" == "null" ]] && continue
            if grep -qx "$id" "$SEEN_IDS_FILE"; then
                continue
            fi
            details_url="https://api.themoviedb.org/3/movie/$id?api_key=$API_KEY&append_to_response=credits"
            movie_details=$(fetch_with_retry "$details_url") || continue
            if ! echo "$movie_details" | jq empty >/dev/null 2>&1; then
                continue
            fi
            echo "$movie_details" | jq -r '
                [
                    .id,
                    (.title // "N/A" | gsub("\""; "\"\"")),
                    ((.genres | map(.name) | join("/")) // "N/A"),
                    (.vote_average // 0),
                    ((.release_date | split("-")[0]) // "N/A"),
                    ((.credits.crew | map(select(.job=="Director") | .name) | join("/")) // "N/A")
                ] | @csv
            ' >> "$OUTPUT"
            echo "$id" >> "$SEEN_IDS_FILE"
            sleep 0.3
        done
    done

    TMP_OUTPUT="$OUTPUT.tmp"
    (head -n 1 "$OUTPUT" && tail -n "$MAX_MOVIES_IN_CSV" "$OUTPUT") > "$TMP_OUTPUT"
    mv "$TMP_OUTPUT" "$OUTPUT"

    cut -d ',' -f 1 "$OUTPUT" | tail -n +2 > "$SEEN_IDS_FILE"
    sleep "$RUN_INTERVAL_SECONDS"
done
