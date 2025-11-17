#!/bin/bash

CSV_UPDATER="./realtimecsv_update.sh"

if ! pgrep -f "$CSV_UPDATER" > /dev/null; then
    bash "$CSV_UPDATER" &
    CSV_PID=$!
fi

cleanup() {
    if [[ -n "${CSV_PID:-}" ]]; then
        kill "$CSV_PID" 2>/dev/null
    fi
}
trap cleanup EXIT

MOVIES_FILE="movies.csv"
RATINGS_FILE="user_ratings.csv"

if [ ! -f "$MOVIES_FILE" ]; then
    gum style --bold --foreground 9 "Error: '$MOVIES_FILE' not found."
    gum style "Please make sure the movie data file is in the same directory."
    exit 1
fi

filter_movies() {
    local genre="$1"
    local min_rating="$2"
    local year_range="$3"
    local director="$4"
    
    cat "$MOVIES_FILE" |
    { 
        if [ -n "$genre" ]; then 
            grep -i ",[^\",]*\"*$genre\"*,"
        else 
            cat
        fi 
    } |
    { 
        if [ -n "$director" ]; then 
            grep -i ",.*,.*,.*,.*,$director"
        else 
            cat
        fi 
    } |
    { 
        if [ -n "$year_range" ]; then
            IFS='-' read start_year end_year <<< "$year_range"
            if [[ "$start_year" =~ ^[0-9]+$ ]] && [[ "$end_year" =~ ^[0-9]+$ ]]; then
                awk -F, -v start="$start_year" -v end="$end_year" '
                    NR==1 {print; next}
                    { y=$5; gsub(/"/,"",y); if (y >= start && y <= end) print }
                '
            else
                gum style --foreground 210 "Invalid year range format. Skipping year filter." >&2
                cat
            fi
        else 
            cat
        fi
    } |
    {
        if [ -n "$min_rating" ] && [[ "$min_rating" =~ ^[0-9]+(\.[0-9]+)?$ ]]; then
            awk -F, -v min="$min_rating" 'NR==1 || $4 >= min'
        else 
            cat
        fi
    }
}

while true; do
    clear
    gum style --border normal --margin "1 2" --padding "1 2" --border-foreground 240 \
    "🎬 Movie Recommendation Engine" \
    "───────────────────────────────" \
    "Choose an action below:"

    choice=$(gum choose \
        "Show Top 10 Rated Movies" \
        "Advanced Movie Search" \
        "Rate a Movie" \
        "View My Ratings" \
        "Refresh Movie Database" \
        "Exit")

    case $choice in
        "Show Top 10 Rated Movies")
            gum style --bold "🏆 Top 10 Rated Movies"
            gum spin --title "Fetching top movies..." -- sleep 1

            movie_list=$(awk -F, 'NR > 1 {
                gsub(/"/,"",$2); gsub(/"/,"",$3); gsub(/"/,"",$5); gsub(/"/,"",$6);
                printf "%s|%s|%s|%s|%s\n", $4, $2, $5, $3, $6
            }' "$MOVIES_FILE" |
            sort -t'|' -k1 -nr |
            head -n 10 |
            awk -F'|' '{printf "%d. %s (%s)\n   Rating: %s | Genre: %s | Director: %s\n\n", NR, $2, $3, $1, $4, $5}')

            echo "$movie_list"
            ;;

        "Advanced Movie Search")
            while true; do
                clear
                gum style --bold "🔍 Advanced Movie Search"

                CURRENT_GENRE=$(gum input --placeholder "Genre (e.g., Action|Comedy)" --header "Current Filter: Genre")
                CURRENT_MIN_RATING=$(gum input --placeholder "Minimum Rating (e.g., 7.5)" --header "Current Filter: Min Rating")
                CURRENT_YEAR_RANGE=$(gum input --placeholder "Year Range (e.g., 2000-2010)" --header "Current Filter: Year Range")
                CURRENT_DIRECTOR=$(gum input --placeholder "Director Name (e.g., Nolan)" --header "Current Filter: Director")

                gum spin --title "Applying filters..." -- sleep 1

                results=$(filter_movies "$CURRENT_GENRE" "$CURRENT_MIN_RATING" "$CURRENT_YEAR_RANGE" "$CURRENT_DIRECTOR" |
                    awk -F, 'NR>1 {
                        gsub(/"/,"",$2); gsub(/"/,"",$3); gsub(/"/,"",$5); gsub(/"/,"",$6);
                        printf "%s|%s|%s|%s|%s\n", $2, $4, $5, $3, $6
                    }' |
                    awk -F'|' 'BEGIN{c=1} {
                        printf "%d. %s (%s)\n   Rating: %s | Genre: %s | Director: %s\n\n", c++, $1, $3, $2, $4, $5
                    }')

                if [ -n "$results" ]; then
                    gum style --bold --foreground 12 "✅ Found $(echo "$results" | grep -c -e '^[0-9]\.') matching movies:"
                    echo "$results"
                else
                    gum style --foreground 210 "No movies found matching all criteria."
                fi

                if ! gum confirm "Perform another search?"; then
                    break
                fi
            done
            ;;

        "Rate a Movie")
            gum style --bold "✍️ Rate a Movie"

            movie_to_rate=$(awk -F, 'NR > 1 {gsub(/"/,"",$2); print $1 ". " $2}' "$MOVIES_FILE" |
                gum filter --placeholder "Type to find a movie to rate...")

            if [ -n "$movie_to_rate" ]; then
                movie_id=$(echo "$movie_to_rate" | cut -d'.' -f1)
                movie_title=$(echo "$movie_to_rate" | cut -d'.' -f2- | sed 's/^ //')

                echo
                rating=$(gum choose 10 9 8 7 6 5 4 3 2 1 --header "Your rating (1-10) for '$movie_title':")

                if [ -n "$rating" ]; then
                    if gum confirm "Save rating of $rating ⭐ for '$movie_title'?"; then
                        echo "user,$movie_id,$rating,$(date +%s)" >> "$RATINGS_FILE"
                        gum style --foreground 2 "✅ Rating saved!"
                        sleep 1
                    fi
                else
                    gum style --foreground 9 "Rating cancelled or invalid selection."
                    sleep 2
                fi
            fi
            ;;

        "View My Ratings")
            gum style --bold "📜 My Movie Ratings"
            if [ -s "$RATINGS_FILE" ]; then
                gum spin --title "Loading your ratings..." -- sleep 1

                my_ratings=$(sort -t, -k2,2 "$RATINGS_FILE" |
                    join -t, -1 2 -2 1 - <(sort -t, -k1,1 "$MOVIES_FILE") |
                    awk -F, '
                        BEGIN{c=1}
                        {
                            gsub(/"/,"",$5)
                            gsub(/"/,"",$6)
                            gsub(/"/,"",$9)
                            printf "%d. %s (%s)\n   My Rating: %s | World Rating: %s | Genre: %s | Director: %s\n\n",
                                   c++, $5, $8, $3, $7, $6, $9
                        }')

                if [ -n "$my_ratings" ]; then
                    echo "$my_ratings"
                else
                    gum style --foreground 210 "Could not match your ratings to the movie list."
                    sleep 2
                fi
            else
                gum style --foreground 210 "You haven't rated any movies yet."
                sleep 2
            fi
            ;;

        "Refresh Movie Database")
            gum style --bold "🔄 Refresh Movie Database"
            gum style --foreground 214 "⚠️ This process may take 10+ minutes..."
            sleep 2

            gum spin --title "Running makemoviescsv.sh..." -- ./makemoviescsv.sh

            if [ -f "$MOVIES_FILE" ]; then
                entry_count=$(($(wc -l < "$MOVIES_FILE") - 1))
                gum style --foreground 10 "✅ Movie database refreshed!"
                gum style --bold "Total entries: $entry_count"
            else
                gum style --foreground 9 "❌ Failed to refresh."
            fi
            ;;

        "Exit")
            gum style --foreground 245 "👋 Goodbye!"
            exit 0
            ;;
    esac

    echo
    gum style --foreground 240 "Press Enter to return to the main menu..."
    read -r < /dev/tty
done

