#!/bin/bash

API_KEY="5dc013077b983b1636f79036dd6ba8b1"

# Create (or overwrite) CSV file with headers
echo "ID,Title,Genre,Rating,Year,Director" > movies.csv

MAX_PAGES=50   # 50 pages × 20 = 1000 movies
PC=1
for page in $(seq 1 $MAX_PAGES); do
    curl -s "https://api.themoviedb.org/3/movie/popular?api_key=$API_KEY&page=$page" -o movies.json
    echo "Page $PC of $MAX_PAGES"
    PC=$((PC+1))
    for id in $(jq -r '.results[].id' movies.json); do
        curl -s "https://api.themoviedb.org/3/movie/$id?api_key=$API_KEY&append_to_response=credits" \
        | jq -r '[.id, .title, (.genres | map(.name) | join("/")), .vote_average, (.release_date|split("-")[0]), (.credits.crew | map(select(.job=="Director") | .name) | join("/"))] | @csv' \
        >> movies.csv
    done
done

echo "✅ Movies saved to movies.csv"
./rmmvduplicates.sh
