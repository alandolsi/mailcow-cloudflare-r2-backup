# Project Overview

This project provides a comprehensive shell script (`syncbackup_cloudflare.sh`) for automating backups of local directories to Cloudflare R2 storage. It includes features for automatic retention management, easy restoration of backups (including the latest), a lock mechanism to prevent concurrent execution, and detailed logging. The script is designed to be configurable for various backup types using patterns.

**Key Technologies:**
*   **Bash:** The primary scripting language.
*   **Rclone:** Used for syncing files to Cloudflare R2.
*   **Cloudflare R2:** The target object storage for backups.

**Architecture:**
The project consists of a single Bash script that orchestrates `rclone` commands to perform backup, restore, and retention tasks. It relies on a pre-configured `rclone` remote for Cloudflare R2.

# Building and Running

This project does not require a traditional "build" step as it is a shell script.

## Prerequisites:
*   **Rclone:** Version 1.60 or higher.
*   **Bash** Shell.
*   **Cloudflare R2** Account with an `rclone` remote configured (e.g., `cloudflare-backup`).

## Installation:
1.  **Install Rclone:** `curl https://rclone.org/install.sh | sudo bash`
2.  **Configure Rclone for Cloudflare R2:** `rclone config` (refer to `README.md` for detailed steps).
3.  **Download Script:** Clone the repository and make the script executable: `chmod +x syncbackup_cloudflare.sh`

## Configuration:
Edit the variables at the beginning of `syncbackup_cloudflare.sh` to configure:
*   `SOURCE`: Source directory for backups.
*   `RETENTION_DAYS`: Retention period for backups in days.
*   `RCLONE_DEST`: Rclone destination (e.g., `remote-name:bucket/path`).
*   `BACKUP_PATTERN`: Regex pattern for automatic folder detection during restore.
*   `LOGFILE`: Path to the log file.

## Usage:

### Create a Backup:
```bash
./syncbackup_cloudflare.sh
# or explicitly:
./syncbackup_cloudflare.sh backup
```

### Restore a Backup:
*   **Restore latest backup:** `./syncbackup_cloudflare.sh restore`
*   **Restore a specific backup folder:** `./syncbackup_cloudflare.sh restore backup-2025-12-17-01-00-45`
*   **Restore to a different destination:** `./syncbackup_cloudflare.sh restore backup-2025-12-17-01-00-45 /tmp/restore`

## Automation with Cron:
Add a Cron job for regular backups (e.g., daily at 2:00 AM):
```bash
0 2 * * * /path/to/syncbackup_cloudflare.sh backup
```

# Development Conventions

*   **Scripting Language:** Bash.
*   **Logging:** All actions are logged to the configured `LOGFILE` (default: `/var/log/backup_sync.log`).
*   **Error Handling:** Includes a lock mechanism to prevent parallel execution and basic checks for Rclone availability.
*   **Security:** Emphasizes protecting Rclone configuration, using minimal permissions for R2 Access Keys, and regular testing of restores.
*   **Contributing:** Pull requests are welcome; open an issue for larger changes.
*   **License:** MIT License.

# Troubleshooting

Refer to the `README.md` for detailed troubleshooting steps, including issues with lock files, Rclone not found, and log file permissions.
