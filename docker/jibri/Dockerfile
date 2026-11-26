# Jibri with the academy's finalize script: when a recording ends it asks the Abaqera API where the lecture belongs
# and moves the files into the organised recordings volume. Keep the tag in sync with JITSI_TAG (not an ARG on purpose:
# Coolify's Dockerfile mode breaks ARG-before-FROM, see the main Dockerfile).
FROM jitsi/jibri:stable

COPY finalize.sh /opt/abaqera/finalize.sh
USER root
RUN chmod 0755 /opt/abaqera/finalize.sh

# Start-up diagnostics: "ABAQERA-CHECK OK|FAIL|WARN" lines in the jibri log say why recording would fail.
COPY abaqera-check.sh /etc/cont-init.d/99-abaqera-check
RUN sed -i 's/\r$//' /etc/cont-init.d/99-abaqera-check && chmod 0755 /etc/cont-init.d/99-abaqera-check
