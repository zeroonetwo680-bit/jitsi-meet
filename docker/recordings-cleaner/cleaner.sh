#!/bin/sh
# Every few minutes: ask the API which recordings were deleted in the dashboard, remove their directories, confirm each one.
ROOT="${RECORDINGS_ROOT:-/recordings}"
API="${RECORDER_API_URL:-}"
SECRET="${RECORDER_SECRET:-}"
EVERY="${CLEAN_EVERY_SECONDS:-300}"

# Jibri writes here as an unprivileged user.
mkdir -p "$ROOT" && chmod 1777 "$ROOT"

log() { echo "$(date -u +%FT%TZ) cleaner: $*"; }

if [ -z "$API" ] || [ -z "$SECRET" ]; then
  log "RECORDER_API_URL or RECORDER_SECRET is not set: deletions are not processed"
  exec sleep 2147483647
fi

while true; do
  LIST=$(curl -fsS -m 30 -H "X-Recorder-Secret: $SECRET" "$API/api/v1/internal/recordings/pending-deletion" 2>/dev/null) || LIST=""
  # [{"id":"...","directory":"..."},...] -> one object per line
  printf '%s' "$LIST" | sed 's/},{/}\n{/g; s/^\[//; s/\]$//' | while IFS= read -r ITEM; do
    [ -n "$ITEM" ] || continue
    ID=$(printf '%s' "$ITEM" | sed -n 's/.*"id":"\([^"]*\)".*/\1/p')
    DIRECTORY=$(printf '%s' "$ITEM" | sed -n 's/.*"directory":"\([^"]*\)".*/\1/p')
    printf '%s' "$ID" | grep -Eq '^[0-9a-f-]{36}$' || continue
    case "$DIRECTORY" in *..*) continue ;; esac
    printf '%s' "$DIRECTORY" | grep -Eq '^(courses|unassigned)/[A-Za-z0-9._/-]+$' || continue
    rm -rf "${ROOT:?}/$DIRECTORY"
    # Remove folders that became empty (cohort, then course), never the root.
    PARENT=$(dirname "$DIRECTORY")
    while [ "$PARENT" != "." ] && [ "$PARENT" != "/" ] && rmdir "$ROOT/$PARENT" 2>/dev/null; do PARENT=$(dirname "$PARENT"); done
    if curl -fsS -m 30 -X POST -H "X-Recorder-Secret: $SECRET" "$API/api/v1/internal/recordings/$ID/deleted" >/dev/null; then
      log "removed $DIRECTORY"
    else
      log "removed $DIRECTORY but could not confirm $ID (will retry)"
    fi
  done
  sleep "$EVERY"
done
