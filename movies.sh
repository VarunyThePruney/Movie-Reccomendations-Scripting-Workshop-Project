#!/bin/bash

MOVIES_FILE="movies.csv"
input="$MOVIES_FILE"

genre=""
min_rating=""
year_range=""
director=""

# Parse all args
while [[ $# -gt 0 ]]; do
  key="$1"
  case $key in
    --genre)
      genre="$2"
      shift 2
      ;;
    --min-rating)
      min_rating="$2"
      shift 2
      ;;
    --year)
      year_range="$2"
      shift 2
      ;;
    --director)
      director="$2"
      shift 2
      ;;
    --help|*)
      echo "Usage: ./movies.sh [--genre GENRE] [--min-rating RATING] [--year START-END] [--director NAME]"
      exit 0
      ;;
  esac
done

filter() {
  cat "$input" |
  # Genre filter
  { if [ -n "$genre" ]; then grep -i -- "$genre"; else cat; fi; } |
  # Director filter
  { if [ -n "$director" ]; then grep -i -- "$director"; else cat; fi; } |
  # Year filter
  { 
    if [ -n "$year_range" ]; then
      IFS='-' read start_year end_year <<< "$year_range"
      awk -F, -v start="$start_year" -v end="$end_year" '
        NR==1 {print; next}
        { y=$5; gsub(/"/,"",y); if (y >= start && y <= end) print }
      '
    else cat
    fi
  } |
  # Min rating filter
  {
    if [ -n "$min_rating" ]; then
      awk -F, -v min="$min_rating" 'NR==1 || $4 >= min'
    else cat
    fi
  } |
  column -t -s,
}

filter

