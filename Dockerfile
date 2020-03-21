FROM alpine:3.10

RUN apk --no-cache add rsync git

COPY entrypoint.sh /entrypoint.sh
COPY edit.sh /edit.sh

ENTRYPOINT ["/entrypoint.sh"]
