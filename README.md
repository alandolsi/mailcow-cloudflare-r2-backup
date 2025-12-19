# Cloudflare R2 Backup Script

Automatic backup script for synchronizing local directories to Cloudflare R2 with automatic retention management and restore functionality.

## Features

- ✅ Automatic uploading of backups to Cloudflare R2
- ✅ Automatic retention management (old backups are deleted)
- ✅ Restore function with automatic detection of the latest backup
- ✅ Lock mechanism against parallel execution
- ✅ Detailed logging
- ✅ Configurable backup patterns for different backup types

## Prerequisites

- **Rclone** (version 1.60 or higher)
- **Bash** Shell
- **Cloudflare R2** Account and configured Rclone Remote

## Installation

### 1. Install Rclone

```bash
curl https://rclone.org/install.sh | sudo bash
```

### 2. Configure Rclone for Cloudflare R2

```bash
rclone config
```

Follow the instructions and choose:
- Storage: `s3`
- Provider: `Cloudflare`
- Enter your R2 Access Key ID and Secret Access Key
- Endpoint: `https://<account-id>.r2.cloudflarestorage.com`

Name the remote, e.g., `cloudflare-backup`. This is the default value for `RCLONE_DEST`.

### 3. Download Script

```bash
git clone <repository-url>
cd cloudflare_r2
chmod +x syncbackup_cloudflare.sh
```

## Configuration

The script can be configured via environment variables. Set these variables before executing the script, or export them in your shell session.

| Variable         | Description                                                                | Default Value                         |
| :--------------- | :------------------------------------------------------------------------- | :------------------------------------ |
| `SOURCE`         | Source directory for backups.                                              | `/backup_source`                      |
| `RETENTION_DAYS` | Retention time for backups in days.                                        | `5`                                   |
| `RCLONE_DEST`    | Rclone destination in `remote-name:bucket/path` format.                    | `cloudflare-backup:my-backups/`       |
| `BACKUP_PATTERN` | Regex pattern for automatic folder detection during restore.               | `^backup-[0-9]{4}-[0-9]{2}-[0-9]{2}-[0-9]{2}-[0-9]{2}-[0-9]{2}/$` |
| `LOGFILE`        | Path to the log file.                                                      | `/var/log/backup_sync.log`            |
| `LOCKFILE`       | Path to the lock file (prevents parallel execution).                       | `/var/log/backup_sync.lock`           |
| `RCLONE`         | Path to the Rclone executable.                                             | `/usr/bin/rclone`                     |

### Using Environment File

Create a `backup.env` file (copy from `backup.env.example`) to store your configuration:

```bash
cp backup.env.example backup.env
```

Edit `backup.env` with your settings:

```bash
export SOURCE="/backups/"
export RETENTION_DAYS=7
export RCLONE_DEST="remote:backups/your-backup-destination"
export BACKUP_PATTERN='^mailcow-[0-9]{4}-[0-9]{2}-[0-9]{2}/$'
export LOGFILE="/var/log/backup_sync.log"
```

⚠️ **Important:** The `backup.env` file is excluded from Git to protect sensitive data. Never commit credentials to the repository.

**Example Configuration (export before execution):**

```bash
export SOURCE="/home/user/my_data_to_backup"
export RETENTION_DAYS=7
export RCLONE_DEST="my-r2-remote:my-bucket/daily-backups"
export BACKUP_PATTERN='^mydata-[0-9]{4}-[0-9]{2}-[0-9]{2}/$'
export LOGFILE="/var/log/backup_sync.log"
./syncbackup_cloudflare.sh
```

## Usage

### Create a Backup

```bash
./syncbackup_cloudflare.sh
# or explicitly:
./syncbackup_cloudflare.sh backup
```

### Perform a Restore (Import)

**Automatically restore the latest backup:**
```bash
./syncbackup_cloudflare.sh restore
```

**Restore a specific backup folder:**
```bash
./syncbackup_cloudflare.sh restore backup-2025-12-17-01-00-45
```

**Restore to a different destination directory:**
```bash
./syncbackup_cloudflare.sh restore backup-2025-12-17-01-00-45 /tmp/restore
```

## Automation with Cron

Add a Cron job for regular backups:

```bash
sudo crontab -e
```

Examples:

```bash
# Daily at 4:00 AM with environment file
0 4 * * * . /root/cloudflare_r2/backup.env; /bin/bash /root/cloudflare_r2/syncbackup_cloudflare.sh

# Daily at 2:00 AM (using inline environment variables)
0 2 * * * /path/to/syncbackup_cloudflare.sh backup

# Every 6 hours
0 */6 * * * /path/to/syncbackup_cloudflare.sh backup

# Every Sunday at 3:00 AM
0 3 * * 0 /path/to/syncbackup_cloudflare.sh backup
```

**Note:** When using the environment file approach, make sure to source the file (`. /path/to/backup.env`) before running the script in the same command.

## Logging

The script writes all actions to the configured log file (default: `./backup_sync.log`).

**View Log:**
```bash
tail -f /var/log/backup_sync.log
```

**Check last backup activity:**
```bash
grep "Backup End" /var/log/backup_sync.log | tail -1
```

## Retention Management

The script automatically deletes backups older than `RETENTION_DAYS` days. The retention time can be adjusted via the `RETENTION_DAYS` environment variable.

## Troubleshooting

### Script is already running (Lock file exists)

```bash
# Manually remove the lock file (only if no backup is running!)
rm -f /var/log/backup_sync.lock
```

### Rclone not found

```bash
# Check Rclone path
which rclone

# Adjust path in the script or via the RCLONE environment variable if necessary
```

### No permissions for log file

```bash
# Ensure the user executing the script has write permissions for the LOGFILE path.
```

## Security Notes

⚠️ **Important:**
- Protect your Rclone configuration (`~/.config/rclone/rclone.conf`)
- Use separate R2 Access Keys with minimal permissions for production systems
- Regularly test restores in a test environment
- Use encrypted connections (Rclone uses HTTPS by default)

## License

MIT License - see LICENSE file (if present)

## Contributing

Pull requests are welcome! For larger changes, please open an issue first.
