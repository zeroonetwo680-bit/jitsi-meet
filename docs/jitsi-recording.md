# Server-side lecture recording (Jibri) and browser sign-in

## 1. Recording on the VPS

`docker-compose.yml` now has a `jibri` service. Jibri opens the meeting in a headless Chrome and records it, so the host needs
a virtual sound card and enough CPU. VPS planned: 1 TB disk, 24 GB RAM, 8 cores (confirm with `nproc`).

### Prepare the host (once, as root, over SSH)

```bash
nproc && free -h && df -h /                 # confirm cores, RAM, disk
uname -r                                    # must be a real KVM kernel, not OpenVZ/LXC
sudo apt-get install -y linux-modules-extra-$(uname -r)
sudo modprobe snd-aloop && lsmod | grep snd_aloop
echo snd-aloop | sudo tee /etc/modules-load.d/snd-aloop.conf   # survives reboot
ls /dev/snd                                 # must list the loopback card (e.g. controlC*)
```

If `modprobe snd-aloop` fails the provider's kernel does not support it: recording cannot run on that VPS, ask the provider
for a KVM plan or a different kernel.

### Capacity

One Jibri records **one** lecture at a time (about 1 core and 2 to 3 GB RAM). For N lectures at the same hour, run N Jibri
containers (scale the `jibri` service, each needs its own `JIBRI_INSTANCE_ID`). Roughly 1 GB of disk per recorded hour at the default quality, so 1 TB
holds around 900 hours: plan a clean-up or upload job. **Needed from the owner: how many lectures run at the same time at peak?**

### Coolify

* Compose now reads `SERVICE_PASSWORD_JIBRI` and `SERVICE_PASSWORD_RECORDER`: Coolify generates them like the existing ones.
* Redeploy the whole stack. Recordings land in the `jibri-recordings` volume (`/config/recordings` in the container).

### Start recording

The frontend of this repo has no "auto-record" option, so the moderator (trainer) starts it with the **Record** button
(now in the toolbar). Truly automatic recording of every lecture needs a server-side trigger (a small Prosody module or a service that
asks Jicofo to start Jibri when a room is created): separate task, tell me if wanted.

### Not done yet

* Serving the finished files and giving them to the Abaqera API (the session's `recording_url`): needs a finalize script that
  copies the file to storage and calls the API.
* Verify on the server: start a lecture as a trainer, press Record, stop, find the `.mp4` in the volume and play it.

## 2. Sign in from the browser with the Abaqera account

Chosen design: Jitsi's `tokenAuthUrl`. A visitor who opens `https://meet.geniusesksa.com/<room>` without a token is redirected to
an Abaqera login page; after sign-in the page sends the browser back with `?jwt=...` for that room. Needs in the Abaqera project:

1. A web login page that accepts the room and a return URL, and after a successful sign-in calls the token service for the
   session that owns that room (same rules as the app: enrolled, time window, role).
2. The page redirects back to `https://meet.geniusesksa.com/<room>?jwt=<token>`.

Then here: `config.tokenAuthUrl = 'https://<abaqera-login-page>?room={room}&state={state}'` in `docker/custom-config.js`.
**Needed: the real login-page URL and whether it can carry a return URL.** Do this only together with `ENABLE_GUESTS=0`
(see `docs/abaqera-guest-lockdown-checklist.md`).
