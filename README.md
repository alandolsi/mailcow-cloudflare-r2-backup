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

You can configure the script using a `.env` file (recommended) or environment variables.

### Method 1: Using `.env` file (Recommended)

1. Copy the example configuration:
   ```bash
   cp backup.env.example .env
   ```
2. Edit `.env` with your settings:
   ```bash
   nano .env
   ```

### Method 2: Environment Variables

You can also export variables before running the script:

```bash
export SOURCE="/var/www/html/my_app"
export RETENTION_DAYS=7
export RCLONE_DEST="my-r2-remote:my-bucket/daily-backups"
./syncbackup_cloudflare.sh
```

| Variable         | Description                                                                | Default Value                         |
| :--------------- | :------------------------------------------------------------------------- | :------------------------------------ |
| `SOURCE`         | Source directory for backups.                                              | `/backup_source`                      |
| `RETENTION_DAYS` | Retention time for backups in days.                                        | `5`                                   |
| `RCLONE_DEST`    | Rclone destination in `remote-name:bucket/path` format.                    | `cloudflare-backup:my-backups/`       |
| `BACKUP_PATTERN` | Regex pattern for automatic folder detection during restore.               | `^backup-[0-9]{4}-[0-9]{2}-[0-9]{2}...` |
| `LOGFILE`        | Path to the log file.                                                      | `/var/log/backup_sync.log`            |
...
## Logging

The script writes all actions to the configured log file (default: `/var/log/backup_sync.log`).

## Monitoring with Filebeat & Kibana (Modular Setup)

We use a modular Filebeat configuration to support multiple servers easily.

### 1. Prepare Local Configuration

On your local machine, organize your Filebeat configuration:

```text
filebeat/
├── .env                  # Your credentials (host, user, password, tags)
├── filebeat.yml          # Global config (loads inputs.d/*.yml)
└── inputs.d/             # Specific log inputs
    ├── backup.yml        # Config for this backup script
    ├── mailcow.yml       # Config for Mailcow
    └── ...
```

Edit `filebeat/.env` and insert your Elasticsearch credentials and server name.

### 2. Upload to Server

Copy the configuration to your server:

```bash
# Copy all files
scp -r filebeat/* root@your-server:/etc/filebeat/
```

### 3. Configure Systemd (Load .env)

By default, Filebeat does not read `.env` files. We need to tell Systemd to load it.

Run this on the server:

```bash
# 1. Create override directory
mkdir -p /etc/systemd/system/filebeat.service.d/

# 2. Create override file
echo "[Service]
EnvironmentFile=/etc/filebeat/.env" > /etc/systemd/system/filebeat.service.d/override.conf

# 3. Secure the .env file (Contains passwords!)
chmod 600 /etc/filebeat/.env
chown root:root /etc/filebeat/.env

# 4. Apply changes and restart
systemctl daemon-reload
systemctl restart filebeat
```

### 4. Verify

Check if Filebeat is running and connected:

```bash
systemctl status filebeat
filebeat test output
```


