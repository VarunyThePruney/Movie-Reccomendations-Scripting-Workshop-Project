#!/bin/bash

SECONDS=0
API_KEY="5dc013077b983b1636f79036dd6ba8b1"
OUTPUT="movies.csv"
SEEN_IDS="seen_ids.tmp"

echo "ID,Title,Genre,Rating,Year,Director" > "$OUTPUT"
> "$SEEN_IDS"  

fetch_movies() {
    local url=$1
    local pages=$2
    local label=$3

    for page in $(seq 1 $pages); do
        echo "Fetching $label page $page of $pages..."
        curl -s "$url&page=$page" -o temp.json

        for id in $(jq -r '.results[].id' temp.json); do
            if ! grep -q "^$id$" "$SEEN_IDS"; then
                echo "$id" >> "$SEEN_IDS"

                curl -s "https://api.themoviedb.org/3/movie/$id?api_key=$API_KEY&append_to_response=credits" \
                | jq -r '[.id, .title, (.genres | map(.name) | join("/")), .vote_average, (.release_date|split("-")[0]), (.credits.crew | map(select(.job=="Director") | .name) | join("/"))] | @csv' \
                >> "$OUTPUT"
            fi
        done
    done
}

fetch_movies "https://api.themoviedb.org/3/movie/popular?api_key=$API_KEY" 100 "Popular"
fetch_movies "https://api.themoviedb.org/3/discover/movie?api_key=$API_KEY&with_original_language=hi" 50 "Hindi"
fetch_movies "https://api.themoviedb.org/3/discover/movie?api_key=$API_KEY&with_original_language=te" 50 "Telugu"

rm "$SEEN_IDS"
echo "All unique movies saved to $OUTPUT"
echo "Time taken: $SECONDS seconds"
