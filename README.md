# DriveBackup
Basic backup shell script with logging &amp; config file that uses GDrive CLI<br>
Supports Discord Notifications for convenience.

## Configuration
The Discord Webhook and User ID can be defined at the top of the shell script.

For the configuration file, separate the entries by using ```:``` inbetween.<br>

| Part | Example |
| ------ | ------ |
| File/Folder Name | my_target_file_or_folder |
| Amount of old versions to keep | 5 |
| File/Folder Path | "/absolute/path/to/file/or/folder.tar" |
| Target Directory ID | 123GDRIVE456ID789 |
| Excluded files/folders (optional) | "/exclude/this/sub/dir/or/folder" |

Excluding files and folders is optional and can be concatenated using ```,``` like so:<br>
```"/excluded/folder/,/exclude_partially/exclude_me.doc"```

## Usage
- Place the backup.sh script in a folder of your choice
- Create a *.conf file with your to be secured file & folders along with their destination folder IDs (GDrive)<br>
- Execute the shell script using the *.conf file as parameter

Sample start command:
```sh
./backup.sh backup.conf
```

This will generate a log file of the same name of your *.conf file e.g. "backup.log".

## Automation
Open crontab using ```crontab -e```<br>
Then add a new entry with your preferred time schedule ```0 0 * * * /path/to/backup.sh backup.conf```<br>
Tip: Use <a href="https://crontab.guru/once-a-day" target="_blank" rel="noreferrer">crontab.guru</a> to generate your cron schedule expression.
