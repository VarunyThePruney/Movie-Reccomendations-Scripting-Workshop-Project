#!/bin/bash
# A smooth minimal terminal UI for movie recommendation with advanced filtering

# --- Configuration ---
MOVIES_FILE="movies.csv"
RATINGS_FILE="user_ratings.csv"

# --- Pre-flight Check ---
if [ ! -f "$MOVIES_FILE" ]; then
    gum style --bold --foreground 9 "Error: '$MOVIES_FILE' not found."
    gum style "Please make sure the movie data file is in the same directory."
    exit 1
fi

# --- Helper Function: Advanced Filtering Logic ---
# This function applies all filters (genre, rating, year, director) to the data.
filter_movies() {
    local genre="$1"
    local min_rating="$2"
    local year_range="$3"
    local director="$4"
    
    # 1. Start with the data file
    cat "$MOVIES_FILE" |
    
    # 2. Genre filter (Case-insensitive search in the Genre column)
    # The pattern targets the Genre column specifically, handling quotes if they exist.
    { 
        if [ -n "$genre" ]; then 
            grep -i ",[^\",]*\"*$genre\"*,"
        else 
            cat
        fi 
    } |
    
    # 3. Director filter (Case-insensitive search in the Director column)
    { 
        if [ -n "$director" ]; then 
            grep -i ",.*,.*,.*,.*,$director"
        else 
            cat
        fi 
    } |
    
    # 4. Year range filter (Uses awk to check the fifth column)
    { 
        if [ -n "$year_range" ]; then
            IFS='-' read start_year end_year <<< "$year_range"
            # Ensure years are valid numbers before passing to awk
            if [[ "$start_year" =~ ^[0-9]+$ ]] && [[ "$end_year" =~ ^[0-9]+$ ]]; then
                awk -F, -v start="$start_year" -v end="$end_year" '
                    NR==1 {print; next}
                    { y=$5; gsub(/"/,"",y); if (y >= start && y <= end) print }
                '
            else
                gum style --foreground 210 "Invalid year range format. Skipping year filter." >&2
                cat # Pass all data through if format is wrong
            fi
        else 
            cat
        fi
    } |
    
    # 5. Min rating filter (Uses awk to check the fourth column)
    {
        if [ -n "$min_rating" ] && [[ "$min_rating" =~ ^[0-9]+(\.[0-9]+)?$ ]]; then
            # NR==1 is for the header, $4 >= min is for data rows
            awk -F, -v min="$min_rating" 'NR==1 || $4 >= min'
        else 
            # If no rating or invalid rating, pass all data
            cat
        fi
    }
}


# --- Main Menu Loop ---
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
        "Exit")

    case $choice in
        "Show Top 10 Rated Movies")
            gum style --bold "🏆 Top 10 Rated Movies"
            gum spin --title "Fetching top movies..." -- sleep 1

            # Extract fields, sort by Rating (column 4), print top 10
            movie_list=$(awk -F, 'NR > 1 {gsub(/"/,"",$2); gsub(/"/,"",$3); gsub(/"/,"",$5); gsub(/"/,"",$6); printf "%s|%s|%s|%s|%s\n", $4, $2, $5, $3, $6}' "$MOVIES_FILE" | sort -t'|' -k1 -nr | head -n 10 | awk -F'|' '{printf "%d. %s (%s)\n   Rating: %s | Genre: %s | Director: %s\n\n", NR, $2, $3, $1, $4, $5}')
            
            echo "$movie_list"
            ;;

        "Advanced Movie Search")
            # --- Advanced Search Logic ---
            while true; do
                clear
                gum style --bold "🔍 Advanced Movie Search"

                # Use gum input for all search criteria
                CURRENT_GENRE=$(gum input --placeholder "Genre (e.g., Action|Comedy)" --header "Current Filter: Genre")
                CURRENT_MIN_RATING=$(gum input --placeholder "Minimum Rating (e.g., 7.5)" --header "Current Filter: Min Rating")
                CURRENT_YEAR_RANGE=$(gum input --placeholder "Year Range (e.g., 2000-2010)" --header "Current Filter: Year Range")
                CURRENT_DIRECTOR=$(gum input --placeholder "Director Name (e.g., Nolan)" --header "Current Filter: Director")
                
                # Run the filter function and capture results
                gum spin --title "Applying filters..." -- sleep 1
                
                # Run filter and remove the header line (NR>1) before formatting
                results=$(filter_movies "$CURRENT_GENRE" "$CURRENT_MIN_RATING" "$CURRENT_YEAR_RANGE" "$CURRENT_DIRECTOR" | awk -F, 'NR>1 {gsub(/"/,"",$2); gsub(/"/,"",$3); gsub(/"/,"",$5); gsub(/"/,"",$6); printf "%s|%s|%s|%s|%s\n", $2, $4, $5, $3, $6}' | awk -F'|' 'BEGIN{c=1} {printf "%d. %s (%s)\n   Rating: %s | Genre: %s | Director: %s\n\n", c++, $1, $3, $2, $4, $5}')
                
                if [ -n "$results" ]; then
                    gum style --bold --foreground 12 "✅ Found $(echo "$results" | grep -c -e '^[0-9]\.') matching movies:"
                    echo "$results"
                else
                    gum style --foreground 210 "No movies found matching all criteria."
                fi

                # Ask user if they want to search again
                if ! gum confirm "Perform another search?"; then
                    break # Exit the search loop
                fi
            done
            ;;

        "Rate a Movie")
            gum style --bold "✍️ Rate a Movie"
            
            # Use filter on movie titles for selection
            movie_to_rate=$(awk -F, 'NR > 1 {gsub(/"/,"",$2); print $1 ". " $2}' "$MOVIES_FILE" | gum filter --placeholder "Type to find a movie to rate...")

            if [ -n "$movie_to_rate" ]; then
                movie_id=$(echo "$movie_to_rate" | cut -d'.' -f1)
                movie_title=$(echo "$movie_to_rate" | cut -d'.' -f2- | sed 's/^ //')
                
                echo
                # Use gum choose for a cleaner rating input (1-10)
                rating=$(gum choose 10 9 8 7 6 5 4 3 2 1 --header "Your rating (1-10) for '$movie_title':")

                if [ -n "$rating" ]; then
                    if gum confirm "Save rating of $rating ⭐ for '$movie_title'?"; then
                        # Simple append logic: always adds a new rating.
                        # For a production system, this would require logic to UPDATE an existing rating.
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

                # Join user_ratings.csv (key=column 2, MovieID) with movies.csv (key=column 1, ID)
                my_ratings=$(sort -t, -k2,2 "$RATINGS_FILE" | join -t, -1 2 -2 1 - <(sort -t, -k1,1 "$MOVIES_FILE") | awk -F, '
                    BEGIN{c=1} 
                    {
                        # Columns are now: MovieID, User, UserRating, Timestamp, Title, Genre, WorldRating, Year, Director
                        gsub(/"/,"",$5); # Title
                        gsub(/"/,"",$6); # Genre
                        gsub(/"/,"",$9); # Director
                        printf "%d. %s (%s)\n   My Rating: %s | World Rating: %s | Genre: %s | Director: %s\n\n", c++, $5, $8, $3, $7, $6, $9
                    }
                ')
                
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

        "Exit")
            gum style --foreground 245 "👋 Goodbye!"
            exit 0
            ;;
    esac

    # Pause and wait for user to press Enter before clearing and showing the main menu again.
    echo
    gum style --foreground 240 "Press Enter to return to the main menu..."
    read -r < /dev/tty
done