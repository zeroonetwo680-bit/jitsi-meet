#!/usr/bin/with-contenv bash
# Abaqera: say plainly at start-up why lecture recording would fail. Prints "ABAQERA-CHECK OK|FAIL|WARN ..." lines to
# the Jibri container log (Coolify, service "jibri"). Never stops the container.

ok()   { echo "ABAQERA-CHECK OK   $*"; }
fail() { echo "ABAQERA-CHECK FAIL $*"; }
warn() { echo "ABAQERA-CHECK WARN $*"; }

# 1. Virtual sound card (snd-aloop on the host). Without it Chrome has no audio device and every recording fails at once.
if grep -qi loopback /proc/asound/cards 2>/dev/null; then
    ok "sound: ALSA Loopback card present"
else
    fail "sound: no ALSA Loopback card. On the VPS run: sudo modprobe snd-aloop && echo snd-aloop | sudo tee /etc/modules-load.d/snd-aloop.conf, then redeploy"
fi

# 2. The address Jibri's Chrome opens.
if [ -z "${PUBLIC_URL}" ]; then
    fail "PUBLIC_URL is empty: Jibri would open https://${XMPP_DOMAIN}/<room>, which does not resolve"
elif ! command -v curl >/dev/null 2>&1; then
    ok "web: PUBLIC_URL=${PUBLIC_URL} (curl not in the image, reachability not checked)"
else
    code=$(curl -s -o /dev/null -m 15 -w '%{http_code}' "${PUBLIC_URL}/" 2>/dev/null || echo 000)
    if [ "${code}" -ge 200 ] 2>/dev/null && [ "${code}" -lt 400 ]; then
        ok "web: ${PUBLIC_URL} answers HTTP ${code}"
    else
        fail "web: ${PUBLIC_URL} answers HTTP ${code} from inside the container (DNS, proxy or Cloudflare blocking the server itself?)"
    fi
fi

# 3. XMPP accounts used to join and to record.
[ -n "${JIBRI_XMPP_PASSWORD}" ] && ok "xmpp: jibri password set" || fail "xmpp: JIBRI_XMPP_PASSWORD is empty (SERVICE_PASSWORD_JIBRI in Coolify)"
[ -n "${JIBRI_RECORDER_PASSWORD}" ] && ok "xmpp: recorder password set" || fail "xmpp: JIBRI_RECORDER_PASSWORD is empty (SERVICE_PASSWORD_RECORDER in Coolify)"

# 4. Where finished recordings go.
[ -n "${RECORDER_API_URL}" ] && ok "api: RECORDER_API_URL=${RECORDER_API_URL}" || warn "api: RECORDER_API_URL is empty: files are recorded but not registered in the dashboard"
[ -n "${RECORDER_SECRET}" ] && ok "api: RECORDER_SECRET set" || warn "api: RECORDER_SECRET is empty: files are recorded but not registered in the dashboard"
for dir in "${JIBRI_RECORDING_DIR:-/config/recordings}" "${RECORDINGS_ROOT:-/recordings}"; do
    if [ -d "${dir}" ]; then
        free=$(df -Pm "${dir}" 2>/dev/null | awk 'NR==2 {print $4}')
        ok "disk: ${dir} exists, ${free:-?} MB free"
    else
        warn "disk: ${dir} does not exist"
    fi
done

exit 0
