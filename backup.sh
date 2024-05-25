#!/bin/bash

Version=0.1.2
Repo="https://raw.githubusercontent.com/run2go/backup/main/backup.sh"

# Configuration Parameters
UPDATE_AUTO=false
UPDATE_NOTIFY=true
WEBHOOK_REPORT=true
WEBHOOK_URL="https://web.hook/"
PING_TARGET="@here"

# Initialize the variables to store the report messages
backup_message=""
backup_warn=""
backup_update=""
backup_num=0

# Function to log messages with timestamps
log_message() {
  echo "$(date +'%Y/%m/%d %H:%M:%S') $1" | tee -a $LOG_FILE
}

# Function to check for script updates
check_for_updates() {
  latest_script=$(curl -s $Repo)
  latest_version=$(echo "$latest_script" | grep -oP 'Version=\K[0-9.]+')
  
  if [ -z "$latest_version" ]; then
    log_message "Invalid remote version, check \"$(echo $Repo)\""
    backup_update+="Notification $PING_TARGET: Invalid remote version, check \"$(echo $Repo)\"\n\n"
  elif [[ $latest_version != $Version ]]; then
    if $UPDATE_AUTO; then
      log_message "Updating script to version $latest_version"
      mv $0 ${0}.bk
      echo "$latest_script" | sed "/# Configuration Parameters/aUPDATE_AUTO=$UPDATE_AUTO\nUPDATE_NOTIFY=$UPDATE_NOTIFY\nWEBHOOK_REPORT=$WEBHOOK_REPORT\nWEBHOOK_URL=\"$WEBHOOK_URL\"\nPING_TARGET=\"$PING_TARGET\"" > "$0"
      chmod +x "$0"
      exec $0 "$@"
    fi
    
    if $UPDATE_NOTIFY; then
      backup_update+="Notification $PING_TARGET: Backup Script updated to version **$latest_version**\n\n"
    fi
  fi
}

# Perform the update check if enabled
if $UPDATE_AUTO || $UPDATE_NOTIFY; then
  check_for_updates "$@"
fi

# Check if the configuration file is provided as an argument
if [ $# -ne 1 ]; then
  log_message "Usage: $0 <config_file>"
  exit 1
fi

# Check if the configuration file exists
CONFIG_FILE="$1"
if [ ! -f "$CONFIG_FILE" ]; then
  log_message "Configuration file not found: $CONFIG_FILE"
  exit 1
fi

# Redirect echo output to the log file
LOG_FILE="$CONFIG_FILE.log"

# Clear logfile
rm $LOG_FILE
touch $LOG_FILE

# Read and process the configuration file
while read -r item; do
  # Parse JSON fields
  title=$(echo "$item" | jq -r '.title // empty')

  # Skip entries without a title
  if [ -z "$title" ]; then
    continue
  fi

  # Keep track of valid json entries
  ((backup_num+=1))

  source=$(echo "$item" | jq -r '.source')
  target=$(echo "$item" | jq -r '.target')
  excludes=$(echo "$item" | jq -r '.exclude // empty | .[]')

  log_message "[$backup_num] Starting backup for $title"

  # Prepare exclude options
  exclude_options=""
  for exclude in $excludes; do
    exclude_options+="--exclude $exclude "
  done

  # Check if the source is a file or directory
  if [ -d "$source" ]; then
    source_type="directory"
  elif [ -f "$source" ]; then
    source_type="file"
  else
    log_message "[$backup_num] Warn: Source '$source' for $title not found or invalid"
    backup_warn+="- **[$backup_num]** $title (Source not found: '$source')\n"
    continue
  fi

  # Perform the backup
  if [ "$source_type" == "directory" ]; then
    if ! rclone copy "$source" "$target" --verbose --log-file="$LOG_FILE" $exclude_options; then
      log_message "[$backup_num] Backup for $title (directory) failed"
      backup_warn+="- **[$backup_num]** $title\n"
    else
      log_message "[$backup_num] Backup for $title (directory) completed"
      backup_message+="- **[$backup_num]** $title\n"
    fi
  elif [ "$source_type" == "file" ]; then
    # Handle single file backup
    if ! rclone copyto "$source" "$target$(basename "$source")" --verbose --log-file="$LOG_FILE"; then
      log_message "[$backup_num] Backup for $title (file) failed"
      backup_warn+="- **[$backup_num]** $title\n"
    else
      log_message "[$backup_num] Backup for $title (file) completed"
      backup_message+="- **[$backup_num]** $title\n"
    fi
  fi
done < <(jq -c '.[]' "$CONFIG_FILE")

# Perform webhook report if requested
if $WEBHOOK_REPORT; then
  if [ -n "$backup_warn" ]; then
    # Prep linebreak after backup_warn
    description="$(echo -e "$backup_warn\n**$backup_num** entries processed in total.")"
    
    json_payload=$(jq -n \
      --arg content "***[Backup] Warning @$(hostname)***: $PING_TARGET" \
      --arg text "***[Backup] Warning @$(hostname)***: $PING_TARGET - **Error**: $(echo -e "$backup_warn")" \
      --arg title "Failed Backups" \
      --arg description "$description" \
      '{content: $content, text: $text, embeds: [{title: $title, description: $description, color: 16732439}]}')
  else
    json_payload=$(jq -n \
      --arg content "***[Backup] Info @$(hostname)***: __${CONFIG_FILE}__ backup finished, **$(($(echo -e "$backup_message" | wc -l)-1))** entries processed." \
      '{content: $content, text: $content}')
  fi

  curl -H "Content-Type: application/json" -X POST -d "$json_payload" "$WEBHOOK_URL"
  
  # Workaround for Slacks "pretty print"
  #curl -H "Content-Type: application/json" -X POST -d "$(echo "$json_payload" | sed 's/\*\{2,\}/*/g' | sed 's/__//g')" "$WEBHOOK_URL"
fi
