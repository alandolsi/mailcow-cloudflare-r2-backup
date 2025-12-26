#!/bin/bash
#
# Automatic backup from local directories to Cloudflare R2
# Requires Rclone (v1.60+)
#

# Get the directory where this script is located (resolve symlinks)
SCRIPT_DIR="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)"

# Try to load backup.env from script directory if it exists and variables are not set
if [ -f "$SCRIPT_DIR/backup.env" ] && [ -z "$SOURCE" ]; then
    source "$SCRIPT_DIR/backup.env"
fi

# --- CONFIGURATION (via Environment Variables or Defaults) ---

# Source directory for backups.
# Default: /backup_source
SOURCE="${SOURCE:-/backup_source}"

# Retention count (number of backups to keep).
# Default: 5
RETENTION_DAYS="${RETENTION_DAYS:-5}"

# Rclone destination (format: remote-name:bucket/path).
# Default: cloudflare-backup:my-backups/
RCLONE_DEST="${RCLONE_DEST:-cloudflare-backup:my-backups/}"
# Normalize destination to avoid duplicate slashes
RCLONE_DEST_TRIMMED="${RCLONE_DEST%/}"

# Regex pattern for automatic folder detection during restore.
# Default: generic backup pattern
BACKUP_PATTERN="${BACKUP_PATTERN:-^mailcow-[0-9]{4}-[0-9]{2}-[0-9]{2}-[0-9]{2}-[0-9]{2}-[0-9]{2}/$}"

# Path to the log file.
# Default: /var/log/backup_sync.log
LOGFILE="${LOGFILE:-/var/log/backup_sync.log}"

# Path to the lock file (prevents parallel execution).
# Default: /var/log/backup_sync.lock
LOCKFILE="${LOCKFILE:-/var/log/backup_sync.lock}"

# Path to the rclone executable.
# Default: /usr/bin/rclone (adjust if rclone is installed elsewhere)
RCLONE="${RCLONE:-/usr/bin/rclone}"

# --- INTERACTIVE MODE ---
# If no arguments provided, show interactive menu
if [ $# -eq 0 ]; then
    echo "========================================="
    echo "  Cloudflare R2 Backup & Restore Tool"
    echo "========================================="
    echo ""
    echo "What would you like to do?"
    echo ""
    echo "  1) Backup - Upload current data to Cloudflare R2"
    echo "  2) Restore - Download backup from Cloudflare R2"
    echo "  3) Update - Update this script from repository"
    echo "  4) Exit"
    echo ""
    read -p "Please select [1-4]: " choice
    
    case $choice in
        1)
            ACTION="backup"
            ;;
        2)
            ACTION="restore"
            # Check if rclone is available
            if [ ! -x "$RCLONE" ]; then
                echo "ERROR: rclone not found at $RCLONE"
                exit 1
            fi
            
            echo ""
            echo "Fetching available backups from R2..."
            echo ""
            
            # List all backup folders
            mapfile -t BACKUP_FOLDERS < <("$RCLONE" lsf "$RCLONE_DEST_TRIMMED" --dirs-only | grep -E "$BACKUP_PATTERN" | sed 's:/$::' | sort -r)
            
            if [ ${#BACKUP_FOLDERS[@]} -eq 0 ]; then
                echo "ERROR: No backup folders found on R2"
                exit 1
            fi
            
            echo "Available backups:"
            echo ""
            for i in "${!BACKUP_FOLDERS[@]}"; do
                printf "  %2d) %s\n" $((i+1)) "${BACKUP_FOLDERS[$i]}"
            done
            echo "   0) Cancel"
            echo ""
            
            read -p "Select backup to restore [0-${#BACKUP_FOLDERS[@]}]: " backup_choice
            
            if [ "$backup_choice" -eq 0 ] 2>/dev/null; then
                echo "Restore cancelled."
                exit 0
            fi
            
            if [ "$backup_choice" -ge 1 ] && [ "$backup_choice" -le ${#BACKUP_FOLDERS[@]} ] 2>/dev/null; then
                RESTORE_NAME="${BACKUP_FOLDERS[$((backup_choice-1))]}"
                echo ""
                echo "Selected: $RESTORE_NAME"
                echo ""
                read -p "Restore to directory [$SOURCE]: " custom_dest
                RESTORE_DEST="${custom_dest:-$SOURCE}"
                echo ""
                echo "Starting restore..."
            else
                echo "ERROR: Invalid selection"
                exit 1
            fi
            ;;
        3)
            ACTION="update"
            ;;
        4)
            echo "Goodbye!"
            exit 0
            ;;
        *)
            echo "ERROR: Invalid choice"
            exit 1
            ;;
    esac
else
    # --- MODE / PARAMETERS (non-interactive) ---
    ACTION=${1:-backup}               # backup, restore/import, or update
    RESTORE_NAME=${2:-}               # Name/folder/file on R2 (required for restore/import)
    RESTORE_DEST=${3:-$SOURCE}        # Local destination directory (default: $SOURCE)
fi

# --- UPDATE MODE ---
if [ "$ACTION" = "update" ]; then
    echo ""
    echo "========================================="
    echo "  Updating Script from Repository"
    echo "========================================="
    echo ""
    
    # Find repository directory (where this script is symlinked from)
    REAL_SCRIPT=$(readlink -f "${BASH_SOURCE[0]}")
    REPO_DIR=$(dirname "$REAL_SCRIPT")
    
    if [ ! -d "$REPO_DIR/.git" ]; then
        echo "ERROR: Git repository not found"
        echo "Script location: $REAL_SCRIPT"
        exit 1
    fi
    
    echo "Repository: $REPO_DIR"
    echo ""
    
    # Pull latest changes
    cd "$REPO_DIR" || exit 1
    echo "Running: git pull --ff-only"
    git pull --ff-only
    
    if [ $? -ne 0 ]; then
        echo ""
        echo "ERROR: git pull failed"
        exit 1
    fi
    
    echo ""
    echo "✓ Update complete!"
    echo ""
    exit 0
fi

# Check for lock file (prevents parallel execution)
if [ -f "$LOCKFILE" ]; then
    echo "$(date): Script is already running (lock file exists)" >> "$LOGFILE"
    exit 1
fi

# Create lock file
echo $$ > "$LOCKFILE"
trap "rm -f '$LOCKFILE'; exit" EXIT INT TERM

# Check if rclone is available
if [ ! -x "$RCLONE" ]; then
    echo "$(date): ERROR - rclone not found at $RCLONE" >> "$LOGFILE"
    exit 1
fi

# --- RESTORE / IMPORT ---
if [ "$ACTION" = "restore" ] || [ "$ACTION" = "import" ]; then
    # If no specific name was given, automatically detect the newest folder
    if [ -z "$RESTORE_NAME" ]; then
        echo "Searching for the newest backup folder..." >> "$LOGFILE"
        # List all folders, sort descending and take the first one (newest)
        RESTORE_NAME=$("$RCLONE" lsf "$RCLONE_DEST_TRIMMED" --dirs-only | grep -E "$BACKUP_PATTERN" | sort -r | head -n 1 | sed 's:/$::')
        
        if [ -z "$RESTORE_NAME" ]; then
            echo "$(date): ERROR - No backup folder found" >> "$LOGFILE"
            exit 1
        fi
        echo "Newest backup folder found: $RESTORE_NAME" >> "$LOGFILE"
    fi

    mkdir -p "$RESTORE_DEST"
    echo "--- Restore Start: $(date) ---" >> "$LOGFILE"
    echo "Starting restore from $RESTORE_NAME to $RESTORE_DEST ..." >> "$LOGFILE"
    
    # Show progress on terminal, log to file
    echo ""
    echo "========================================="
    echo "  Restoring: $RESTORE_NAME"
    echo "========================================="
    echo ""

    "$RCLONE" copy "${RCLONE_DEST_TRIMMED}/${RESTORE_NAME}" "$RESTORE_DEST" \
        --progress \
        --stats-one-line \
        --stats 1s \
        --transfers=4 \
        --checkers=8 \
        >> "$LOGFILE" 2>&1
    
    RCLONE_EXIT=$?

    if [ $RCLONE_EXIT -eq 0 ]; then
        echo ""
        echo "========================================="
        echo "  ✓ Restore Complete!"
        echo "========================================="
        
        # Show summary
        RESTORE_SIZE=$(du -sh "$RESTORE_DEST" 2>/dev/null | cut -f1)
        FILE_COUNT=$(find "$RESTORE_DEST" -type f 2>/dev/null | wc -l)
        
        echo ""
        echo "  Restored: $FILE_COUNT files"
        echo "  Total size: $RESTORE_SIZE"
        echo "  Location: $RESTORE_DEST"
        echo ""
        echo "--- Restore End: $(date) ---" >> "$LOGFILE"
        rm -f "$LOCKFILE"
        exit 0
    else
        echo ""
        echo "✗ Restore: ERROR (Check log: $LOGFILE)" | tee -a "$LOGFILE"
        rm -f "$LOCKFILE"
        exit 1
    fi
fi

echo "--- Backup Start: $(date) ---" >> "$LOGFILE"

# Check source directory
FILE_COUNT=$(find "$SOURCE" -type f 2>/dev/null | wc -l)
SOURCE_SIZE=$(du -sh "$SOURCE" 2>/dev/null | cut -f1)

# Mark log position for this backup run
LOG_MARKER="=== BACKUP RUN $(date +%s) ==="
echo "$LOG_MARKER" >> "$LOGFILE"

# 1. UPLOAD (COPY)
echo "Starting upload to Cloudflare..." >> "$LOGFILE"
echo ""
echo "========================================="
echo "  Uploading Backup to Cloudflare R2"
echo "========================================="
echo ""
echo "  Source: $SOURCE"
echo "  Files found: $FILE_COUNT ($SOURCE_SIZE)"
echo ""

"$RCLONE" copy "$SOURCE" "$RCLONE_DEST_TRIMMED" \
    --progress \
    --stats-one-line \
    --stats 1s \
    --transfers=4 \
    --checkers=8 \
    --verbose \
    >> "$LOGFILE" 2>&1

RCLONE_EXIT=$?

echo ""
if [ $RCLONE_EXIT -eq 0 ]; then
    echo "========================================="
    echo "  ✓ Upload Complete!"
    echo "========================================="
    
    # Count only files transferred in THIS run (after marker)
    NEW_FILES=$(sed -n "/$LOG_MARKER/,\$p" "$LOGFILE" | grep -c "Copied (new)" || echo "0")
    
    echo ""
    if [ "$NEW_FILES" -gt 0 ]; then
        echo "  New files uploaded: $NEW_FILES"
        echo "  Already synced: $((FILE_COUNT - NEW_FILES))"
    else
        echo "  All files already synced ($FILE_COUNT files, $SOURCE_SIZE)"
    fi
    echo "  Destination: $RCLONE_DEST_TRIMMED"
    echo ""
else
    echo "========================================="
    echo "  ✗ Upload Failed!"
    echo "========================================="
    echo ""
    echo "  Check log: $LOGFILE"
    echo ""
    exit 1
fi

# 2. CLEANUP (Keep only the latest RETENTION_DAYS backups)
echo "========================================="
echo "  Cleaning up old backups..."
echo "========================================="
echo ""
echo "Retention policy: Keep latest $RETENTION_DAYS backups" | tee -a "$LOGFILE"
echo "Backup pattern: $BACKUP_PATTERN" | tee -a "$LOGFILE"
echo ""

DELETED_COUNT=0
CURRENT_COUNT=0

echo "Checking existing backups on R2..."
# List all backup files with timestamp, sort by time descending (newest first)
while read -r DATE TIME DIR; do
    TIMESTAMP="$DATE $TIME"
    # Normalize directory name (remove trailing slash)
    DIR=${DIR%/}
    
    # Consider only directories matching BACKUP_PATTERN
    if ! echo "${DIR}/" | grep -Eq "$BACKUP_PATTERN"; then
        echo "  [SKIP] Pattern mismatch: ${DIR}/" | tee -a "$LOGFILE"
        continue
    fi

    ((CURRENT_COUNT++))

    if [ "$CURRENT_COUNT" -gt "$RETENTION_DAYS" ]; then
        echo "  [DELETE] Backup $CURRENT_COUNT ($TIMESTAMP) > Limit $RETENTION_DAYS: $DIR" | tee -a "$LOGFILE"
        "$RCLONE" purge "${RCLONE_DEST_TRIMMED}/${DIR}" >> "$LOGFILE" 2>&1
        if [ $? -eq 0 ]; then
            ((DELETED_COUNT++))
        fi
    else
        echo "  [KEEP]   Backup $CURRENT_COUNT ($TIMESTAMP): $DIR" | tee -a "$LOGFILE"
    fi
done < <("$RCLONE" lsf "$RCLONE_DEST_TRIMMED" --dirs-only --format "tp" | sort -r)

echo ""
if [ "$DELETED_COUNT" -gt 0 ]; then
    echo "  Deleted $DELETED_COUNT old backup folder(s)" | tee -a "$LOGFILE"
else
    echo "  No old backup folders to delete" | tee -a "$LOGFILE"
fi
echo ""
echo "--- Backup End: $(date) ---" >> "$LOGFILE"
echo ""
echo "========================================="
echo "  ✓ Backup Completed Successfully!"
echo "========================================="
echo ""

# Clean exit
rm -f "$LOCKFILE"
exit 0
