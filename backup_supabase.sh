#!/usr/bin/env bash
set -euo pipefail

BACKUP_DIR="$HOME/supabase_backups"
mkdir -p "$BACKUP_DIR"
DATE=$(date '+%Y-%m-%d_%H-%M-%S')
FILE="$BACKUP_DIR/femic_$DATE.dump"

pg_dump "${PG_URL:?Defina PG_URL ex: postgresql://postgres.uhpyinpugdvcsmghgimd:senha@aws-0-us-east-1.pooler.supabase.com:5432/postgres}" \
  -F c -f "$FILE"

echo "Backup salvo: $FILE"
echo "Tamanho: $(du -h "$FILE" | cut -f1)"
