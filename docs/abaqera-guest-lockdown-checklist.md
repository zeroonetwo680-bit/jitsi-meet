# Guest lockdown: switch-over checklist and rollback

Switching `ENABLE_GUESTS` from `1` to `0` on https://meet.geniusesksa.com/ so nobody can join without an Abaqera JWT.
**Do not start until every box in "Before" is ticked.** With guests off, a student without a working token is refused.

## Before (all must be true)

- [ ] Abaqera API with the student and admin `lecture-token` endpoints is deployed on the server.
- [ ] `JITSI_APP_SECRET` in the API equals `JWT_APP_SECRET` in Coolify (compare through a private channel, never in git or chat).
- [ ] App 1.1.0 or later (Jitsi SDK, token sign-in) is built and installed by instructors and students.
- [ ] With guests still **on**, a test student and a test instructor each joined a real session through the new app using a token (instructor as moderator, student not).
- [ ] The owner agreed on the switch-over date and told instructors and students.
- [ ] No lecture is running at the moment of the switch (redeploy drops live calls).
- [ ] Rollback steps below are read and someone with Coolify access is available.

## Switch

1. Coolify, Jitsi resource, environment variables: set `ENABLE_GUESTS=0`. Leave `ENABLE_AUTH=1` and `AUTH_TYPE=jwt`.
2. Redeploy the **whole stack** (web, prosody, jicofo, jvb) so every service picks up the change.
3. Watch the prosody logs for startup errors.

## Verify after the switch

1. **Instructor** opens a session in the app: joins as moderator, display name correct, no camera button.
2. **Student** (enrolled, inside the time window) opens the same session: joins, no moderator rights.
3. **No token:** open `https://meet.geniusesksa.com/<any-room>` in a private window. Expect: refused, no guest join.
4. **Student token, other room:** use a student token on a room different from its `room` claim. Expect: refused.
5. **Not enrolled / outside the window:** the API must refuse to issue a token (no token, no entry).
6. **Student cannot create a room:** a student has no way to pick a room name; the API only issues tokens for rooms stored in the database. Try a hand-pasted `meet.geniusesksa.com` link as an instructor: the API must reject it.
7. `docker logs` of prosody: no unexpected `invalid issuer`, `invalid audience`, `bad signature` or `room` mismatch errors for legitimate users.

## Rollback

Use when students cannot join and it is not fixed within a few minutes.

1. Coolify: set `ENABLE_GUESTS=1` again (or delete the variable: the compose default is `1`).
2. Redeploy the whole stack (web, prosody, jicofo, jvb).
3. Confirm a student can join (with or without a token) and a visitor with no token joins as a guest again.
4. Tell the Abaqera project what failed (log lines, which user, which session) before trying again.

The trainer JWT sign-in from `docs/jitsi/server-jwt-auth.md` stays on during this rollback. Only if JWT itself is the problem: set `AUTH_TYPE=internal` and redeploy, then create trainer users with `prosodyctl register`.

## Common failures

| Symptom | Likely cause |
|---|---|
| Everyone refused after the switch | Secret mismatch between the API and Coolify, or the app is older than 1.1.0 |
| Only students refused | Student token endpoint, enrolment rule or time window (30 min before to 30 min after) |
| Token works on one session, fails on another sharing a virtual room | `room` claim does not match the room in the link |
| Instructor joins but is not moderator | Missing `moderator: true` / `affiliation: "owner"` in the token |
| Joins fail near the end of a lecture | Token `exp` reached (session end + 30 min, minimum 30 min) |
