#!/bin/bash

# --- Configuration ---
API_KEY="${TMDB_API_KEY}"
OUTPUT="movies.csv"
SEEN_IDS_FILE="seen_ids.txt"

# How many pages to fetch each cycle
PAGES_TO_FETCH=20

# Keep only this many pages worth of movies
MAX_PAGES_IN_CSV=50
MOVIES_PER_PAGE=20
MAX_MOVIES_IN_CSV=$((MAX_PAGES_IN_CSV * MOVIES_PER_PAGE))

# Wait time between runs (in seconds)
RUN_INTERVAL_SECONDS=60

# Retry configuration
MAX_RETRIES=5
RETRY_DELAY=5

# Exit on errors, unset vars, or pipefail
set -euo pipefail

# --- Pre-run Checks ---
if [[ -z "$API_KEY" ]]; then
    echo "❌ Error: TMDB_API_KEY environment variable not set."
    echo "Usage: export TMDB_API_KEY=\"your_key_here\" && ./makemoviescsv.sh"
    exit 1
fi

# --- Setup Files ---
touch "$OUTPUT" "$SEEN_IDS_FILE"
if [[ ! -s "$OUTPUT" ]]; then
    echo "ID,Title,Genre,Rating,Year,Director" > "$OUTPUT"
fi

# --- Graceful Exit ---
trap "echo '🛑 Exiting gracefully...'; exit 0" SIGINT SIGTERM

# --- Helper: Safe Fetch with JSON Validation + Retry ---
fetch_with_retry() {
    local url="$1"
    local response=""
    local attempt=1

    while (( attempt <= MAX_RETRIES )); do
        response=$(curl -s --fail "$url" || true)

        # Validate JSON before using it
        if [[ -n "$response" ]] && echo "$response" | jq empty >/dev/null 2>&1; then
            echo "$response"
            return 0
        fi

        echo "⚠️  Attempt $attempt failed or invalid JSON for $url"
        ((attempt++))
        sleep "$RETRY_DELAY"
    done

    echo "❌ Failed after $MAX_RETRIES attempts: $url" >&2
    return 1
}

# --- Main Loop ---
while true; do
    echo "---------------------------------"
    echo "🔄 Fetching $PAGES_TO_FETCH pages of movie data from TMDB..."

    for page in $(seq 1 "$PAGES_TO_FETCH"); do
        echo "📄 Fetching page $page..."

        # Fetch page with retry logic
        page_json=$(fetch_with_retry "https://api.themoviedb.org/3/movie/popular?api_key=$API_KEY&page=$page") || continue

        # Validate again before parsing
        if ! echo "$page_json" | jq empty >/dev/null 2>&1; then
            echo "❌ Invalid JSON for page $page — skipping this page."
            echo "$page_json" | head -c 200
            continue
        fi

        # Extract movie IDs safely
        echo "$page_json" | jq -r '.results[].id' | while read -r id; do
            [[ -z "$id" || "$id" == "null" ]] && continue

            # Skip already seen movies
            if grep -qx "$id" "$SEEN_IDS_FILE"; then
                continue
            fi

            echo "🎬 New movie found (ID: $id). Fetching details..."

            details_url="https://api.themoviedb.org/3/movie/$id?api_key=$API_KEY&append_to_response=credits"
            movie_details=$(fetch_with_retry "$details_url") || continue

            # Ensure movie_details is valid JSON before using jq
            if ! echo "$movie_details" | jq empty >/dev/null 2>&1; then
                echo "❌ Invalid JSON for movie ID $id — skipping."
                continue
            fi

            # Extract and append to CSV
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
            sleep 0.3  # helps avoid TMDB rate limits
        done
    done

    echo "✅ Finished fetching all pages."

    # --- Trim CSV ---
    echo "🧹 Trimming CSV to last $MAX_MOVIES_IN_CSV movies..."
    TMP_OUTPUT="$OUTPUT.tmp"
    (head -n 1 "$OUTPUT" && tail -n "$MAX_MOVIES_IN_CSV" "$OUTPUT") > "$TMP_OUTPUT"
    mv "$TMP_OUTPUT" "$OUTPUT"

    # --- Update Seen IDs ---
    echo "🔁 Syncing seen IDs..."
    cut -d ',' -f 1 "$OUTPUT" | tail -n +2 > "$SEEN_IDS_FILE"

    echo "✨ Updated: $OUTPUT now contains $MAX_MOVIES_IN_CSV latest movies."
    echo "😴 Sleeping for $RUN_INTERVAL_SECONDS seconds..."
    sleep "$RUN_INTERVAL_SECONDS"
done
