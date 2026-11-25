# Lecture login page: sign in to meet.geniusesksa.com with the Abaqera account

**For:** the Abaqera Academy project (`E:\production\full-time\zeroone\velrix-mobile`: API + web app + web-admin)
**From:** the `jitsi-meet` repository (`E:\production\full-time\zeroone\jitsi-meet`), https://meet.geniusesksa.com/
**Builds on:** `docs/jitsi/server-jwt-auth.md` (token contract) and `docs/jitsi/lockdown-answers.md` (token rules, already implemented in the API)

## 1. The problem

Jitsi does not know Abaqera accounts (`AUTH_TYPE=jwt`, no passwords in Jitsi). A person who opens
`https://meet.geniusesksa.com/<room>` in a browser without a token is refused (`token required` in the prosody log), and Jitsi's own
login box (user + password) can never work (`no-auth-mech`). Today people only get in from the mobile app, which passes the token to the SDK.

Goal: **anyone with an Abaqera account (student, instructor, admin) opens the lecture link in a browser, signs in once with the same
email and password they use at Abaqera, and lands in the room.** No Jitsi account, no guests.

## 2. The flow

```
Browser                     Jitsi (meet.geniusesksa.com)        Abaqera login page / API
  | open /<room>  (no token)         |                                  |
  |--------------------------------->| refuses: token required          |
  |<---------------------------------| redirects to tokenAuthUrl        |
  | GET <login-page>?room=<room>&state=<json>                           |
  |-------------------------------------------------------------------->|
  |                                  |      sign in (email + password)  |
  |                                  |      API checks the person may   |
  |                                  |      enter THIS room, issues JWT |
  |<--------------------------------------------------------------------|
  | 302  https://meet.geniusesksa.com/<room>?jwt=<token>                |
  |--------------------------------->| verifies token, joins the room   |
```

If the person already has an Abaqera web session, the page skips the form and goes straight to the token step.

## 3. What the Jitsi side sends to the login page

Jitsi replaces placeholders in the configured `tokenAuthUrl`. We will configure:

```
https://<LOGIN_PAGE_HOST>/lecture-login?room={room}
```

| Parameter | Meaning |
|---|---|
| `room` | Room name from the address bar, e.g. `lecture-k3p9x2m7qa4d`. Treat it as **untrusted input**. |
| `state` (optional, add `&state={state}` if wanted) | URL-encoded JSON: `room`, `roomSafe` (lower-case room used by the server), `tenant`, config overrides. Not needed for our rules: ignore it. |

## 4. What the Abaqera project must build

### 4.1 The page `/lecture-login`

* Arabic first, RTL, Abaqera branding, with an English switch if the app already has one.
* Reads `room`. Validate it with `^lecture-[a-z2-9]{12}$` (the API makes room names from the alphabet `abcdefghijkmnpqrstuvwxyz23456789`). If it does not match: show "invalid lecture link", no form.
* Signed out: email + password form using the **existing** Abaqera sign-in endpoint (same rules, rate limit and lockout as the apps). Signed in: no form.
* After sign-in, call the new endpoint below, then redirect (4.3).
* Error screens, with a clear message and a button back to the platform (never redirect to Jitsi on error):
  * wrong email/password (generic message, no hint which one is wrong);
  * the lecture does not exist or is cancelled;
  * the person is not enrolled in that course / not the instructor of it;
  * outside the time window (opens 30 minutes before the start; show the start time);
  * lecture sign-in not configured (the API `Jitsi:AppSecret` is missing): show a support message.
* Mobile-friendly (people open links from WhatsApp on phones). If the user is on Android with the app installed, the page may offer "Open in the app" (optional).

### 4.2 The API endpoint (token by room)

The existing endpoints are keyed by session id (`/me/sessions/{sessionId}/lecture-token`, instructor and admin variants). A browser only knows the **room name**, so add one endpoint keyed by room:

`POST /api/v1/me/lecture-token` with body `{ "room": "lecture-k3p9x2m7qa4d" }`, bearer access token (any of `student`, `instructor`, `admin`).

Rules (reuse the logic already in `LearningService`, `InstructorService`, `AdminService`):

1. Validate the room format (same regex), then find the sessions whose `meeting_url` room (first path segment, same rule as `RoomOf`) equals it, status not `cancelled`.
2. Pick the session to authorise. **One room can serve several sessions** (virtual rooms with a fixed link), so choose the one the caller is allowed in and that is inside its time window (or the nearest upcoming one for the error message).
3. By role:
   * `student`: non-cancelled enrolment in the session's course; window = 30 min before start to 30 min after end; token `moderator: false`, no `affiliation`.
   * `instructor`: owns the session's course; `moderator: true`, `affiliation: "owner"`.
   * `admin`: any session; `moderator: true`, `affiliation: "owner"`.
4. Return `{ "token": "<jwt>", "room": "...", "serverUrl": "https://meet.geniusesksa.com", "expiresAt": "..." }` (same shape as today) or the existing error envelope (`NOT_FOUND`, `FORBIDDEN_SCOPE`, `BUSINESS_RULE` with the "opens at" time).
5. Token claims are exactly the contract already in use: `iss`/`aud` = `abaqera`, `sub` = `meet.jitsi`, `room`, `nbf` = now - 10 s, `exp` per the lockdown rules, `context.user` (`id`, `name`, `email`, `moderator`, plus `affiliation` for moderators).
6. Rate-limit the endpoint; audit-log instructor/admin issuance like the existing ones.

### 4.3 The redirect back to Jitsi

* Build the URL **only from configuration** (`Jitsi:Url`) plus the **validated** room: `https://meet.geniusesksa.com/<room>?jwt=<token>`. Never take a host or return URL from the query string or from `state` (open-redirect risk).
* Use a fragment-free query `jwt` (that is the parameter Jitsi reads).
* The token travels in the URL: it is short-lived and bound to one room, acceptable (see `lockdown-answers.md` answer 12). Never log it, never store it, send `Referrer-Policy: no-referrer` and `Cache-Control: no-store` on the redirect response.
* Do **not** pass the Abaqera access/refresh token to Jitsi, only the Jitsi JWT.

### 4.4 Security checklist

* HTTPS only; the login page on an Abaqera origin, not on the Jitsi origin.
* Same lockout/rate limit as normal sign-in; no user enumeration in error text.
* Strict validation of `room`; ignore `state` except possibly for display language.
* Do not embed the page in an iframe (`frame-ancestors 'none'`).
* A student must never be able to get a token for a room they are not enrolled in, even by guessing room names.

## 5. What the Jitsi side does (already prepared)

* `docker-compose.yml` now passes `TOKEN_AUTH_URL` to the `web` service (empty = off). Once the login page exists, set in Coolify:
  `TOKEN_AUTH_URL=https://<LOGIN_PAGE_HOST>/lecture-login?room={room}` and redeploy the stack.
* `ENABLE_GUESTS` stays `0` (everyone needs a token). Keep `ENABLE_AUTH=1`, `AUTH_TYPE=jwt`.
* Nothing changes for the mobile app: it keeps passing the token to the SDK.

## 6. Acceptance tests (run after both sides are deployed)

1. Signed out, open `https://meet.geniusesksa.com/<room-of-a-live-session>`: redirected to the login page with `room` filled in. *(If Jitsi shows its own login box instead of redirecting, report it: the redirect trigger may need `tokenAuthUrl` set through `custom-config.js` for this image tag.)*
2. Sign in as an **enrolled student** inside the window: lands in the room as a participant, no moderator rights.
3. Sign in as the **instructor** of that course: lands in the room as moderator.
4. Sign in as a student **not enrolled**: error screen, no redirect to Jitsi.
5. Sign in as an enrolled student **outside the window**: error screen showing when the room opens.
6. Open a made-up room name (valid format, no session): "lecture not found".
7. Open `/lecture-login?room=anything-invalid`: "invalid lecture link", no form.
8. Already signed in at Abaqera: no form, straight into the room.
9. Take the `jwt` of test 2 and put it on a **different** room: Jitsi refuses (room claim mismatch).

## 7. Report back when done

* The real login page URL (so we set `TOKEN_AUTH_URL`).
* The final endpoint path and its error codes.
* Results of tests 1 to 9, and whether test 1 redirected on its own.
