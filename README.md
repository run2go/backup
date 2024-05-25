# Backup
Basic backup bash script with logging &amp; config file that uses rclone CLI<br>
Supports webhook notifications & auto updates.

## Configuration
The main config is available inside the shell script in the `# Configuration Parameters` section.

| Parameter | Example | Explanation |
| ------ | ------ | ------ |
| UPDATE_AUTO | `false` | Should the script auto update if a newer version is available? |
| UPDATE_NOTIFY | `true` | Should a notification be sent when an update is available? |
| WEBHOOK_REPORT | `true` | Should webhook reports be sent? |
| WEBHOOK_URL| `https://web.hook/` | URL that is being curled with POST |
| PING_TARGET | `@here` (optional) | Target that is being notified |


## Usage
- Place the backup.sh script in a folder of your choice
- Make it executable using `chmod +x backup.sh`
- Create a *.json file with your to be secured file & folders along with their rclone compliant destinations<br>
- Execute the shell script using the *.json file as parameter

Sample start command:
```bash
./backup.sh backup_sample.json
```

This will generate a log file of the same name of your *.conf file e.g. "backup_sample.json.log".

## Automation
Open crontab using ```crontab -e```<br>
Then add a new entry with your preferred time schedule ```0 0 * * * /path/to/backup.sh backup_sample.json```<br>
Tip: Use <a href="https://crontab.guru/once-a-day" target="_blank" rel="noreferrer">crontab.guru</a> to generate your cron schedule expression.
