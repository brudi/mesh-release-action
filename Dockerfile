FROM alpine:3.10

RUN apk --no-cache add rsync git curl bash

RUN curl -s "https://raw.githubusercontent.com/\
kubernetes-sigs/kustomize/master/hack/install_kustomize.sh" | bash

COPY entrypoint.sh /entrypoint.sh
COPY edit.sh /edit.sh

ENTRYPOINT ["/entrypoint.sh"]
