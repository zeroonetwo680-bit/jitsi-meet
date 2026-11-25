# Serves recorded lectures to the dashboard with expiring signed links (nginx secure_link). The Abaqera API signs the
# links with RECORDER_SECRET; nobody without a valid, unexpired link can read a file.
FROM nginx:1.27-alpine

COPY default.conf.template /etc/nginx/templates/default.conf.template
COPY 10-check-secret.sh /docker-entrypoint.d/10-check-secret.sh
RUN chmod 0755 /docker-entrypoint.d/10-check-secret.sh
