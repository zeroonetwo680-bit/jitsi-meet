#!/bin/bash
# Called by Jibri when a recording has ended, with the recording directory as its only argument:
#   /config/recordings/<id>/<room>_<timestamp>.mp4 and metadata.json
# 1. asks the Abaqera API which course / cohort / session the room belongs to (it answers with the target directory),
# 2. copies the files to $RECORDINGS_ROOT/<that directory> and checks the copy, 3. tells the API the recording is ready.
# Nothing is removed before the copy was verified; on any failure the files are kept (see "_unregistered").
set -u

DIR="${1:-}"
API="${RECORDER_API_URL:-}"
SECRET="${RECORDER_SECRET:-}"
ROOT="${RECORDINGS_ROOT:-/recordings}"

log() { echo "$(date -u +%FT%TZ) finalize: $*" | tee -a "${FINALIZE_LOG:-/tmp/finalize.log}" >&2; }

[ -d "$DIR" ] || { log "not a directory: '$DIR'"; exit 1; }
MP4=$(find "$DIR" -maxdepth 1 -name '*.mp4' | head -n 1)
[ -n "$MP4" ] || { log "no mp4 in $DIR"; exit 1; }
FILE=$(basename "$MP4")

# The room: the last path segment of the meeting URL in metadata.json, else the file name without its timestamp.
ROOM=""
if [ -f "$DIR/metadata.json" ]; then
  URL=$(grep -o '"meeting_url"[[:space:]]*:[[:space:]]*"[^"]*"' "$DIR/metadata.json" | head -n 1 | sed 's/.*:[[:space:]]*"\(.*\)"/\1/')
  ROOM=$(printf '%s' "$URL" | sed 's/[?#].*//; s#/*$##; s#.*/##')
fi
[ -n "$ROOM" ] || ROOM=$(printf '%s' "$FILE" | sed -E 's/_[0-9]{4}(-[0-9]{2}){5}\.mp4$//; s/\.mp4$//')
ROOM=$(printf '%s' "$ROOM" | tr -cd 'A-Za-z0-9._-')

# Start of the recording: the file's last change minus its length (when ffprobe is there).
END=$(stat -c %Y "$MP4")
DURATION=""
if command -v ffprobe >/dev/null 2>&1; then
  DURATION=$(ffprobe -v error -show_entries format=duration -of csv=p=0 "$MP4" 2>/dev/null | sed 's/\..*//')
fi
case "$DURATION" in ''|*[!0-9]*) DURATION="" ;; esac
START=$((END - ${DURATION:-0}))
RECORDED_AT=$(date -u -d "@$START" +%Y-%m-%dT%H:%M:%SZ)
DURATION_JSON=""
[ -n "$DURATION" ] && DURATION_JSON=",\"durationSeconds\":$DURATION"

keep_aside() {
  # The API could not be reached or refused: keep the files where an administrator can find them, and exit non-zero.
  local aside
  aside="$ROOT/_unregistered/$(basename "$DIR")"
  if mkdir -p "$aside" 2>/dev/null && cp -a "$DIR"/. "$aside"/ 2>/dev/null; then
    log "$1; kept a copy in $aside"
  else
    log "$1; files stay in $DIR"
  fi
  exit 1
}

[ -n "$API" ] && [ -n "$SECRET" ] || keep_aside "RECORDER_API_URL or RECORDER_SECRET is not set"
[ -n "$ROOM" ] || keep_aside "could not work out the room name"

BODY="{\"room\":\"$ROOM\",\"recordedAt\":\"$RECORDED_AT\",\"fileName\":\"$FILE\"$DURATION_JSON}"
RESP=$(curl -fsS -m 30 --retry 5 --retry-delay 5 --retry-all-errors \
  -H "X-Recorder-Secret: $SECRET" -H 'Content-Type: application/json' -d "$BODY" "$API/api/v1/internal/recordings") \
  || keep_aside "registering with the API failed"

ID=$(printf '%s' "$RESP" | sed -n 's/.*"id":"\([^"]*\)".*/\1/p')
DEST=$(printf '%s' "$RESP" | sed -n 's/.*"directory":"\([^"]*\)".*/\1/p')
case "$DEST" in *..*) DEST="" ;; esac
printf '%s' "$DEST" | grep -Eq '^(courses|unassigned)/[A-Za-z0-9._/-]+$' || keep_aside "the API returned an unusable directory"
printf '%s' "$ID" | grep -Eq '^[0-9a-f-]{36}$' || keep_aside "the API returned an unusable id"

TARGET="$ROOT/$DEST"
if ! mkdir -p "$TARGET" || ! cp -a "$DIR"/. "$TARGET"/; then
  keep_aside "could not write to $TARGET"
fi
# Only after the copy was verified is the source removed.
[ "$(stat -c %s "$MP4")" = "$(stat -c %s "$TARGET/$FILE")" ] || keep_aside "the copy in $TARGET is incomplete"
SIZE=$(stat -c %s "$TARGET/$FILE")
rm -rf "$DIR"

COMPLETE="{\"sizeBytes\":$SIZE,\"fileName\":\"$FILE\"$DURATION_JSON}"
curl -fsS -m 30 --retry 5 --retry-delay 5 --retry-all-errors \
  -H "X-Recorder-Secret: $SECRET" -H 'Content-Type: application/json' -d "$COMPLETE" \
  "$API/api/v1/internal/recordings/$ID/complete" >/dev/null \
  || log "recording $ID is stored in $TARGET but could not be marked ready"
log "recording $ID stored in $TARGET ($SIZE bytes)"
