# Cloudflare R2 Backup Script

Automatic backup script for synchronizing local directories to Cloudflare R2 with retention management and restore functionality.

## Features

- ✅ Upload backups to Cloudflare R2
- ✅ Automatic retention management (delete old backups)
- ✅ Restore from R2 with auto-detection of latest backup
- ✅ Interactive menu
- ✅ Self-update from Git repository

## Installation

### 1. Install Rclone

```bash
curl https://rclone.org/install.sh | sudo bash
```

### 2. Configure Rclone for Cloudflare R2

```bash
rclone config
```

- Storage: `s3`
- Provider: `Cloudflare`
- Enter your R2 Access Key ID and Secret Access Key
- Endpoint: `https://<account-id>.r2.cloudflarestorage.com`

Name the remote `cloudflare-backup` (or customize in `backup.env`).

### 3. Install Script

```bash
git clone <repository-url>
cd cloudflare_r2
chmod +x install.sh
sudo ./install.sh
```

## Configuration

Edit configuration:

```bash
nano /opt/cloudflare_r2_backup/backup.env
```

Example:

```bash
export SOURCE="/backups/"
export RETENTION_DAYS=7
export RCLONE_DEST="cloudflare-backup:backups/mail.example.com"
export BACKUP_PATTERN='^mailcow-[0-9]{4}-[0-9]{2}-[0-9]{2}/$'
export LOGFILE="/var/log/backup_sync.log"
```

## Usage

### Interactive Mode

```bash
cloudflare-r2
```

### Commands

**Backup:**
```bash
cloudflare-r2 backup
```

**Restore (latest):**
```bash
cloudflare-r2 restore
```

**Restore specific backup:**
```bash
cloudflare-r2 restore mailcow-2025-12-23-01-00-31
```

**Update script:**
```bash
cloudflare-r2 update
```

## Automation

Daily backup at 4:00 AM:

```bash
sudo crontab -e
```

Add:
```bash
0 4 * * * cloudflare-r2 backup
```

## Logs

```bash
tail -f /var/log/backup_sync.log
```

## Configuration Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `SOURCE` | Source directory for backups | `/backup_source` |
| `RETENTION_DAYS` | Days to keep backups | `5` |
| `RCLONE_DEST` | R2 destination `remote:bucket/path` | `cloudflare-backup:my-backups/` |
| `BACKUP_PATTERN` | Regex for backup folder detection | `^backup-[0-9]{4}-[0-9]{2}-[0-9]{2}-[0-9]{2}-[0-9]{2}-[0-9]{2}/$` |
| `LOGFILE` | Log file path | `/var/log/backup_sync.log` |
| `LOCKFILE` | Lock file path | `/var/log/backup_sync.lock` |
| `RCLONE` | Rclone executable path | `/usr/bin/rclone` |

## License

MIT License
