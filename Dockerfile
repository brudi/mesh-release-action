FROM alpine:3.10

RUN apk --no-cache add rsync git curl

RUN curl -s "https://raw.githubusercontent.com/\
kubernetes-sigs/kustomize/master/hack/install_kustomize.sh"  | sh

COPY entrypoint.sh /usr/local/bin/entrypoint.sh
COPY edit.sh /usr/local/bin/edit.sh

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
