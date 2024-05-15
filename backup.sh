#!/bin/bash

# Version 0.0.2
# Configuration Parameters
MAIN_DIR="/home"
DISCORD_USER_ID=123
DISCORD_CHANNEL_ID=456
DISCORD_TOKEN=private_discord_token


# Move to initial directory
cd $MAIN_DIR || exit

# Function to log messages with timestamps
log_message() {
  echo "$(date +'%Y-%m-%d %H:%M:%S') - $1"
}

# Check if the configuration file is provided as an argument
if [ $# -ne 1 ]; then
  log_message "Usage: $0 <config_file>"
  exit 1
fi

# Check if the configuration file exists
config_file="$1"
if [ ! -f "$config_file" ]; then
  log_message "Configuration file not found: $config_file"
  exit 1
fi

# Redirect echo output to the log file
log_file="$config_file.log"
exec > >(while read -r line; do log_message "$line"; done > "$log_file") 2>&1

# Remove carriage return characters (\r) to convert the file to Unix format
tr -d '\r' < "$config_file" > "$config_file.tmp"
mv "$config_file.tmp" "$config_file"

# Keep track of the overall item count
current_entry=0
max_entries=$(grep -c --invert-match '^#' "$config_file")

# Read the configuration file line by line (IFS = internal field separator)
while IFS=: read -r name versions source target exclusions || [ -n "$name" ]; do
  # Skip lines starting with #
  if [[ $name == \#* ]]; then
      continue
  fi

  # Remove outer double quotes from folder paths using eval
  source=$(eval echo "$source")
  target=$(eval echo "$target")
  exclusions=$(eval echo "$exclusions")

  # Print each output to the console instead of the log file
  ((current_entry++))
  echo "$current_entry/$max_entries started: $name"

  # Check if the source exists
  if [ -e "$source" ]; then
    # Create a temporary directory and copy the source to it
    temp_dir=$(mktemp -d)

    # Split exclusions by comma while preserving quoted values
    IFS=',' read -ra exclusion_dirs <<< "$exclusions"

    # Construct the --exclude parameters dynamically
    excluded=()
    for dir in "${exclusion_dirs[@]}"; do
      # Trim leading/trailing whitespace
      dir=$(echo "$dir" | sed -e 's/^ *//' -e 's/ *$//')
      
      # Check if the directory is not empty after trimming
      if [ -n "$dir" ]; then
        excluded+=("--exclude=$dir")
      fi
    done

    echo "Excluded directories:"
    for excl_dir in "${excluded[@]}"; do
      echo "$excl_dir"
    done

    # Use rsync with the constructed --exclude parameters
    rsync -a "${excluded[@]}" "$source/" "$temp_dir/"

    # Create a zip file of the temporary directory
    cd "$temp_dir" || exit
    zip_file="$name.zip"
    zip -r -q "$zip_file" .
    cd - || exit

    # Upload the new zip file to Google Drive using gdrive
    /usr/local/bin/gdrive files upload "$temp_dir/$zip_file" --parent "$target"

    # Get the list of files in the destination folder
    file_list=$(/usr/local/bin/gdrive files list --parent "$target" | grep -w "$name")

    # Check if there are more older versions than allowed
    if [ "$(echo "$file_list" | wc -l)" -gt "$versions" ]; then
      # Sort by created date and keep the oldest ones
      delete_files=$(echo "$file_list" | tail -n +2 | sort -k 6 | head -n "-$versions" | awk '{print $1}')

      # Delete the older versions
      for file_delete in $delete_files; do
        echo "Deleting older version: $file_delete"
        /usr/local/bin/gdrive files delete --recursive "$file_delete"
      done
    fi

    # Clean up the temporary directory and zip file
    rm -rf "$temp_dir" "$zip_file"
    
    echo "$current_entry/$max_entries finished: $name";
    echo "###";
  else
    echo "$current_entry/$max_entries failed: $name, '$source' not found.";
    echo "###";
    # Error Discord Ping
    echo "Sending Discord Error";
    curl -H "Content-Type: application/json" -X POST -d '{
            "content": "***[Backup] Warning @'"$(hostname)"'*** - <@'$DISCORD_USER_ID'>",
            "embeds": [{
                "title": "**'$current_entry'**/**'"$max_entries"'** failed",
                "description": "**'"$name"'**: __**'"$source"'**__ not found.",
                "color": "16732439"
                }]
            }' https://discord.com/api/webhooks/$DISCORD_CHANNEL_ID/$DISCORD_TOKEN
  fi
done < "$config_file"

#Finished Discord Msg
echo "Sending Discord Info";
curl -H "Content-Type: application/json" -X POST -d '{
          "content": "***[Backup] Info @'"$(hostname)"'***: __'"$config_file"'__ backup finished, **'"$max_entries"'** entries in total processed."
          }' https://discord.com/api/webhooks/$DISCORD_CHANNEL_ID/$DISCORD_TOKEN
          
