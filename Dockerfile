FROM alpine:3.10

RUN apk --no-cache add rsync git

COPY entrypoint.sh /usr/local/bin/entrypoint.sh
COPY edit.sh /usr/local/bin/edit.sh

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
