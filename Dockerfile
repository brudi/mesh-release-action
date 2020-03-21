FROM alpine:3.10

RUN apk --no-cache add curl git

RUN curl -sL https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64 -o /usr/local/bin/yq && chmod +x /usr/local/bin/yq

COPY entrypoint.sh /entrypoint.sh
COPY edit.sh /edit.sh

ENTRYPOINT ["/entrypoint.sh"]
