#!/bin/sh
# An empty or short secret would make every link guessable: refuse to start instead.
if [ "${#RECORDER_SECRET}" -lt 32 ]; then
  echo "RECORDER_SECRET must be set to 32 characters or more (the same value as Jitsi__RecorderSecret in the Abaqera API)." >&2
  exit 1
fi
