#!/bin/bash
# A smooth minimal terminal UI for movie recommendation

# --- Pre-flight Check ---
# Check if the movies.csv file exists before starting.
if [ ! -f movies.csv ]; then
    gum style --bold --foreground 9 "Error: 'movies.csv' not found."
    gum style "Please make sure the movie data file is in the same directory."
    exit 1
fi

# --- Main Menu Loop ---
while true; do
    clear
    gum style --border normal --margin "1 2" --padding "1 2" --border-foreground 240 \
    "🎬 Movie Recommendation Engine" \
    "───────────────────────────────" \
    "Choose an action below:"

    choice=$(gum choose \
        "Show Top 10 Rated Movies" \
        "Search Movie by Genre" \
        "Rate a Movie" \
        "View My Ratings" \
        "Exit")

    case $choice in
        "Show Top 10 Rated Movies")
            gum style --bold "🏆 Top 10 Rated Movies"
            gum spin --title "Fetching top movies..." -- sleep 1

            movie_list=$(awk -F, 'NR > 1 {gsub(/"/,"",$2); gsub(/"/,"",$3); gsub(/"/,"",$5); gsub(/"/,"",$6); printf "%s|%s|%s|%s|%s\n", $4, $2, $5, $3, $6}' movies.csv | sort -t'|' -k1 -nr | head -n 10 | awk -F'|' '{printf "%d. %s (%s)\n   Rating: %s | Genre: %s | Director: %s\n\n", NR, $2, $3, $1, $4, $5}')
            
            echo "$movie_list"
            ;;

        "Search Movie by Genre")
            # Loop for continuous searching
            while true; do
                clear
                gum style --bold "🔍 Search by Genre"
                
                echo
                gum style --foreground 240 -- "Enter a genre (or leave blank to return to menu):"
                read -r genre

                # If the user enters nothing, break the loop
                if [ -z "$genre" ]; then
                    break
                fi

                gum spin --title "Searching for '$genre' movies..." -- sleep 1
                
                movie_list=$(grep -i ",.*,\"[^\"]*$genre[^\"]*\"," movies.csv | awk -F, 'BEGIN{c=1} {gsub(/"/,"",$2); gsub(/"/,"",$3); gsub(/"/,"",$5); gsub(/"/,"",$6); printf "%d. %s (%s)\n   Rating: %s | Genre: %s | Director: %s\n\n", c++, $2, $5, $4, $3, $6}')
                
                if [ -n "$movie_list" ]; then
                    # Display the full list directly
                    echo "$movie_list"
                else
                    gum style --foreground 210 "No movies found for '$genre'."
                fi

                # Ask user if they want to search again
                if ! gum confirm "Search for another genre?"; then
                    break # Exit the search loop
                fi
            done
            continue # Go to the next iteration of the main menu loop
            ;;

        "Rate a Movie")
            gum style --bold "✍️ Rate a Movie"
            
            movie_to_rate=$(awk -F, 'NR > 1 {gsub(/"/,"",$2); print $1 ". " $2}' movies.csv | gum filter --placeholder "Type to find a movie to rate...")

            if [ -n "$movie_to_rate" ]; then
                movie_id=$(echo "$movie_to_rate" | cut -d'.' -f1)
                movie_title=$(echo "$movie_to_rate" | cut -d'.' -f2- | sed 's/^ //')
                
                echo
                gum style --foreground 240 -- "Your rating (1-10) for '$movie_title':"
                read -r rating

                if [[ "$rating" =~ ^[0-9]+$ ]] && [ "$rating" -ge 1 ] && [ "$rating" -le 10 ]; then
                    if gum confirm "Save rating of $rating ⭐ for '$movie_title'?"; then
                        echo "user,$movie_id,$rating,$(date +%s)" >> user_ratings.csv
                        gum style --foreground 2 "✅ Rating saved!"
                        sleep 1
                    fi
                else
                    gum style --foreground 9 "Invalid rating. Please enter a number from 1 to 10."
                    sleep 2
                fi
            fi
            ;;

        "View My Ratings")
            gum style --bold "📜 My Movie Ratings"
            if [ -s user_ratings.csv ]; then
                gum spin --title "Loading your ratings..." -- sleep 1

                my_ratings=$(sort -t, -k2,2 user_ratings.csv | join -t, -1 2 -2 1 - <(sort -t, -k1,1 movies.csv) | awk -F, 'BEGIN{c=1} {gsub(/"/,"",$5); gsub(/"/,"",$6); gsub(/"/,"",$8); gsub(/"/,"",$9); printf "%d. %s (%s)\n   My Rating: %s | World Rating: %s | Genre: %s | Director: %s\n\n", c++, $5, $8, $3, $7, $6, $9}')
                
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
    read < /dev/tty
done