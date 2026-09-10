#!/bin/bash

# Restore Uptime Kuma's data directory from one of the archives the `backups`
# container has taken.
#
# Everything this service knows is in that directory: the monitors somebody
# clicked in by hand, the notification channels, the status pages, the 2FA
# secrets, and the uptime history. It is one SQLite file and a few upload
# directories.
#
#     chmod +x uptime-kuma-restore-data.sh
#     ./uptime-kuma-restore-data.sh
#
# The application is stopped for the restore. SQLite is written on every
# heartbeat, and replacing the file under a running process is how a database
# ends up half old and half new.
set -euo pipefail
cd "$(dirname "$0")"

COMPOSE_FILE="${DOCKER_COMPOSE_FILE:-uptime-kuma-traefik-letsencrypt-docker-compose.yml}"
PROJECT="${COMPOSE_PROJECT_NAME:-uptime-kuma}"
BACKUP_PATH="${DATA_BACKUPS_PATH:-/srv/uptime-kuma-data/backups}"
RESTORE_PATH="${DATA_PATH:-/app/data}"

dc() { docker compose -f "$COMPOSE_FILE" -p "$PROJECT" "$@"; }

APP_CONTAINER="$(dc ps -aq uptime-kuma | head -n 1)"
BACKUPS_CONTAINER="$(dc ps -aq backups | head -n 1)"
[ -n "$APP_CONTAINER" ] || { echo "the uptime-kuma container was not found — is the stack up?" >&2; exit 1; }
[ -n "$BACKUPS_CONTAINER" ] || { echo "the backups container was not found — is the stack up?" >&2; exit 1; }

echo "--> All available data backups:"
docker exec "$BACKUPS_CONTAINER" sh -c "ls -1 $BACKUP_PATH" || true

echo "--> Copy and paste the backup name from the list above and press [ENTER]
--> Example: uptime-kuma-data-backup-YYYY-MM-DD_hh-mm.tar.gz"
echo -n "--> "
read -r SELECTED
[ -n "$SELECTED" ] || { echo "nothing selected, nothing restored" >&2; exit 1; }

if ! docker exec "$BACKUPS_CONTAINER" sh -c "tar -tzf '${BACKUP_PATH}/${SELECTED}' > /dev/null"; then
  echo "that file is not a readable tar archive — nothing has been stopped or deleted" >&2
  exit 1
fi
echo "--> $SELECTED was selected and reads as a valid archive"

echo "--> Stopping Uptime Kuma..."
docker stop "$APP_CONTAINER" > /dev/null

echo "--> Restoring the data directory..."
# The archive stores paths relative to /, so it extracts there. The directory
# is emptied first: a restore that merges leaves rows in the old database that
# the archive's database never had.
docker exec "$BACKUPS_CONTAINER" sh -c "rm -rf '${RESTORE_PATH:?}'/* && tar -zxpf '${BACKUP_PATH}/${SELECTED}' -C /"
echo "--> Data recovery completed."

echo "--> Starting Uptime Kuma..."
docker start "$APP_CONTAINER" > /dev/null
echo "--> The dashboard answers once it has opened the restored database."
