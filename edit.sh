#!/bin/sh -l

edit_image_tag() {
  echo "kustomize image tag $1 ($2)"
  kustomize edit set image $1=:$2
}

edit_all_images() {
    local repo="$1"
    local images="$2"
    local version="$3"
    local delimiter=","
    if [ -n "$images" ]; then
        local image
        while read -d "$delimiter" image; do
          edit_image_tag "$repo$image" $version
        done <<< "$images"
        edit_image_tag "$repo$image" $version
    fi
}