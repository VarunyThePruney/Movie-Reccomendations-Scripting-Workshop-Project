#!/bin/bash

INPUT="movies.csv"
TMP="movies_tmp.csv"

# Keep header
head -n 1 "$INPUT" > "$TMP"

# Deduplicate by Movie ID (handles quotes safely)
tail -n +2 "$INPUT" | awk -v OFS=',' '
{
    gsub(/"/,"",$1);   # remove quotes around ID if any
    if (!seen[$1]++) print $0
}' >> "$TMP"

# Replace original file
mv "$TMP" "$INPUT"

echo "✅ Removed duplicates by Movie ID. Clean file saved as $INPUT"

