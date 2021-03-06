#!/bin/bash

edit_image_tag() {
  echo "kustomize image tag $1 ($2)"
  kustomize edit set image $1=:$2
  test $? -eq 0 || exit 1
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
    test $? -eq 0 || exit 1
}
