# Lecture recordings (Jibri -> organised library -> dashboard)

## Flow

1. The dashboard setting **Record every lecture automatically** (Meeting settings, default on) puts the `auto-record` feature in an
   instructor's lecture token. Our Jitsi web build then starts a Jibri recording when that moderator joins.
2. Jibri writes `<room>_<timestamp>.mp4` + `metadata.json` to `/config/recordings`, then runs `docker/jibri/finalize.sh`.
3. The script registers the file with the API (`POST /api/v1/internal/recordings`, header `X-Recorder-Secret`). The API matches the room to a
   course session and answers with the target directory.
4. The file is copied to the `lecture-recordings` volume, size-verified, the source removed, and the API told it is complete (status `ready`).
5. The dashboard page **Recordings** lists them: play or copy a temporary link (30 minutes, signed), or delete.
6. A delete marks the row `deletion-requested`; `recordings-cleaner` removes the directory within 5 minutes and confirms.

## Folder layout (volume `lecture-recordings`)

```
courses/<course8>/<cohort8>/<yyyy-MM-dd>_session-<NN>_<HHmm>_<room>/<room>_<timestamp>.mp4
unassigned/<yyyy-MM>/<yyyy-MM-dd>_<HHmm>_<room>/...      (room matched no session)
```
Times are UTC+3. Ids are shortened to 8 characters.

## Settings

| Where | Name | Value |
|---|---|---|
| Jitsi stack (Coolify) | `RECORDER_SECRET` | 32+ random chars (`openssl rand -base64 48`) |
| Jitsi stack | `RECORDER_API_URL` | public API address, no trailing slash |
| Abaqera API | `JITSI_RECORDER_SECRET` (`Jitsi__RecorderSecret`) | same value as `RECORDER_SECRET` |
| Abaqera API | `JITSI_RECORDINGS_URL` (`Jitsi__RecordingsUrl`) | public address of the `recordings` service |

Give the `recordings` service its own domain in Coolify (for example `recordings.geniusesksa.com`). Never commit the secret.
Apply the API migration `20261126100000_LectureRecordings`. The VPS needs the `snd-aloop` kernel module for Jibri (see jitsi-recording.md).

## Verify on the server (not tested yet: no Docker on the dev machine)

1. Join a lecture as an instructor in a browser; recording should start by itself (red dot).
2. End it; within a minute a `ready` row appears in Dashboard > Recordings.
3. Press Play: the signed link opens the video. Edit the `md5` in the URL: expect 403.
4. Delete the row; within 5 minutes the directory disappears from the volume.
5. If finalize fails, the files are kept in `_unregistered/` on the volume and Jibri's logs say why. Check the exact arguments and
   `metadata.json` format of your Jibri image version.

## Limits

* Auto-start needs the instructor in a browser; the mobile SDK instructor starts it manually.
* Students cannot see recordings yet (admin page only). No retention policy yet.
* Changes in settings apply to people who join after saving.
