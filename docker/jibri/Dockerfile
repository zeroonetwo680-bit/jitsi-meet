# Jibri with the academy's finalize script: when a recording ends it asks the Abaqera API where the lecture belongs
# and moves the files into the organised recordings volume. Keep the tag in sync with JITSI_TAG (not an ARG on purpose:
# Coolify's Dockerfile mode breaks ARG-before-FROM, see the main Dockerfile).
FROM jitsi/jibri:stable

COPY finalize.sh /opt/abaqera/finalize.sh
USER root
RUN chmod 0755 /opt/abaqera/finalize.sh
