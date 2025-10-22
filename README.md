# Movie-Reccomendations-Scripting-Workshop-Project
Group project for Scripting Workshop related to making a movie recommendation application with shell


🎬 Movie Recommendation TUI
A simple, fast, and fun Terminal User Interface (TUI) for exploring a movie dataset, built with Bash and gum. This script allows you to browse, search, and rate movies directly from your command line.

✨ Features
Top 10 Movies: Instantly view the 10 highest-rated movies from the dataset.
Genre Search: Interactively search for movies by any genre. You can perform multiple searches without returning to the main menu.
Movie-Rating System: Rate any movie on a scale of 1-10. Your ratings are saved locally.
View Your Ratings: Check the list of movies you've rated and compare your score directly with the public "world" rating.
Polished UI: Built with gum for a smooth, modern terminal experience.

🔧 Dependencies
Before running the script, make sure you have the following installed:
bash: The script is written in Bash.
gum: A tool for creating glamorous shell scripts.
Standard UNIX tools: awk, grep, sort, join, and read.

You can install gum on your specific operating system:

macOS
brew install gum

Linux (Debian/Ubuntu)
sudo mkdir -p /etc/apt/keyrings
curl -fsSL [https://repo.charm.sh/apt/gpg.key](https://repo.charm.sh/apt/gpg.key) | sudo gpg --dearmor -o /etc/apt/keyrings/charm.gpg
echo "deb [signed-by=/etc/apt/keyrings/charm.gpg] [https://repo.charm.sh/apt/](https://repo.charm.sh/apt/) * *" | sudo tee /etc/apt/sources.list.d/charm.list
sudo apt update && sudo apt install gum


Windows
 Using Scoop:
  scoop install gum

 Or using Winget:
  winget install charmbracelet.gum

🚀 Setup & Usage
Clone the Repository: Get the project files onto your local machine.

Add the Data File: This script requires a movies.csv file in the same directory. The file must have the following header and format:
ID,Title,Genre,Rating,Year,Director

Make the Script Executable:
chmod +x movie_menu.sh

Run the Script:
./movie_menu.sh

📁 Data Files
The script relies on and creates the following files:
movies.csv: The main database of movies.
user_ratings.csv ( Auto-generated ): This file is created automatically when you rate your first movie.