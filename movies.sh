#!/bin/bash

API_KEY="5dc013077b983b1636f79036dd6ba8b1"
OUTPUT="movies.csv"
SEEN_IDS="seen_ids.tmp"

# Create CSV with headers
echo "ID,Title,Genre,Rating,Year,Director" > "$OUTPUT"
> "$SEEN_IDS"  # Empty the seen IDs file

MAX_PAGES=50

for page in $(seq 1 $MAX_PAGES); do
    echo "Fetching page $page of $MAX_PAGES..."
    curl -s "https://api.themoviedb.org/3/movie/popular?api_key=$API_KEY&page=$page" -o movies.json

    for id in $(jq -r '.results[].id' movies.json); do
        if ! grep -q "^$id$" "$SEEN_IDS"; then
            echo "$id" >> "$SEEN_IDS"

            curl -s "https://api.themoviedb.org/3/movie/$id?api_key=$API_KEY&append_to_response=credits" \
            | jq -r '[.id, .title, (.genres | map(.name) | join("/")), .vote_average, (.release_date|split("-")[0]), (.credits.crew | map(select(.job=="Director") | .name) | join("/"))] | @csv' \
            >> "$OUTPUT"
        fi
    done
done

rm "$SEEN_IDS"
echo "✅ Unique movies saved to $OUTPUT"

