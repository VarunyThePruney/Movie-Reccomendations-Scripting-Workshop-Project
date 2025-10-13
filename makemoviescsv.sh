#!/bin/bash

API_KEY="5dc013077b983b1636f79036dd6ba8b1"
OUTPUT="movies.csv"
SEEN_IDS="seen_ids.tmp"

echo "ID,Title,Genre,Rating,Year,Director" > "$OUTPUT"  #empies and init the csv file
> "$SEEN_IDS"  		#empties the seen id temp file.

MAX_PAGES=200 				#edit this fore more/less movies in csv

for page in $(seq 1 $MAX_PAGES); do 															
    echo "Fetching page $page of $MAX_PAGES..."
    curl -s "https://api.themoviedb.org/3/movie/popular?api_key=$API_KEY&page=$page" -o movies.json   #runs a loop from 1 - max pages where it fetches from the api and imports to a json file, -o means output to json

    for id in $(jq -r '.results[].id' movies.json); do		#runs another loop for every Id in a certain page, these id's are read by jq as and sent to an array results[] where the .id only pulls the ID part of the json file as raw text
        if ! grep -q "^$id$" "$SEEN_IDS"; then			#quietly checks seenids.tmp if an id is found for all id's in a page, if not found, it will be added to the seen list to prevent it being added again later
            echo "$id" >> "$SEEN_IDS"
	
		#for every id, it pulls the data if the id hasnt been seen bfefore, &append... adds details like director, crew, etc
            curl -s "https://api.themoviedb.org/3/movie/$id?api_key=$API_KEY&append_to_response=credits" | jq -r '[.id, .title, (.genres | map(.name) | join("/")), .vote_average, (.release_date|split("-")[0]), (.credits.crew | map(select(.job=="Director") | .name) | join("/"))] | @csv' >> "$OUTPUT"
		#pipes the information to the csv file using jq, Further explanation at line 31 
        fi
    done
done

rm "$SEEN_IDS" #removes tmp file
echo "Movies saved to $OUTPUT"

#.id is id of film, .title is the title of the film
#.genres is the generes, | map(.name) pipes the genres names, | join("/") joines the names with a slash in case of multiple genres.
#.vote average is the ratings for the film
#release date is formatted as (yyyy/mm/dd), split("-") turns it into an array["yyyy", "mm", "dd"]. [0] takes the first element of the array which is year
#.credits.crew pulls the crew that worked on the film, | mape(select(.job=="Director") | .name pulls the director name(s), lastly | join("/") joins the director(s) together with a "/"\
#finally | @csv formats it into a csv file and places it in output with >> s
