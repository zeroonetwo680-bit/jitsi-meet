# Removes the files of recordings an administrator deleted in the dashboard (the API only records the request; the files
# live on this volume). Also makes the volume writable for Jibri's finalize script.
FROM alpine:3.20

RUN apk add --no-cache curl
COPY cleaner.sh /cleaner.sh
RUN chmod 0755 /cleaner.sh
CMD ["/cleaner.sh"]
