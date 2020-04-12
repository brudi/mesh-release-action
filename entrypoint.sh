#!/bin/bash

. $(dirname "$0")/edit.sh

APP=${1}
VERSION=${2}
TOKEN=${3}
REPO=${4}
REF=${5}
REPO_PATH=${6-$APP}
IMAGE=${7}
IMAGE_BASE=${8}
IMAGES=${9}
OVERLAY=${10}
PUSH=${11-false}
AMEND=${12-false}
MERGE=${13}

commit_msg=$(git log -1 --pretty=%B)
action_root=$(pwd)
install_folder=$GITHUB_WORKSPACE/install
kustom_folder=""

is_fallback_app_name=false

# default app name
if [ -z "$APP" ]; then
  is_fallback_app_name=true
  APP=${PWD##*/}
  echo "app param not defined. using current folder name ${APP}"
fi

# set desired app kustomization directory
if [ ! -z "$OVERLAY" ]; then
  echo "editing overlay kustomization at overlays/$OVERLAY"
  kustom_folder=$install_folder/overlays/$OVERLAY
else
  echo "editing base kustomization"
  kustom_folder=$install_folder/base
fi

# edit image tags
pushd $kustom_folder
  if [ ! -z "$IMAGES" ]; then
    if [ -z "$IMAGE_BASE" ]; then
      echo "ERROR: define the 'imageBase' when using 'images'!"
      exit 1
    fi
    echo "editing $IMAGES with base $IMAGE_BASE"
    edit_all_images $IMAGE_BASE $IMAGES $VERSION
  elif [ ! -z "$IMAGE" ]; then
    edit_image_tag $IMAGE $VERSION
  else
    echo "ERROR: one of 'image' or 'images' must be defined"
    exit 1
  fi
  test $? -eq 0 || exit 1
popd

# clone and configure the catalog Git repository
pushd $action_root/catalog
  git clone "https://brudicloud:${TOKEN}@${REPO}" catalog
  git checkout ${REF}
  git config --local user.email cloud@brudi.com
  git config --local user.name Mesh

  # configure path to app configuration
  if [ -z "$REPO_PATH" ]; then
    # mesh convention: expect apps in 'apps' folder
    REPO_PATH="apps/${APP}"

    if [[ ! -d "$REPO_PATH" ]] && [ "$is_fallback_app_name" = true ]; then # when using fallback app name but the 'apps' folder
      # does not exist, we fallback to the 'base' directory.
      #
      # The app is now only used in the commit message.
      REPO_PATH='base'
    fi
  fi

  echo "release Mesh app '$APP' ($VERSION) in $REPO"
  echo "-> $commit_msg"
  # create app config directory if it doesn't exist yet
  if [[ ! -d "$REPO_PATH" ]]; then
    mkdir -p $REPO_PATH
  fi


  # sync all overlays to catalog app
  if [[ -d "$GITHUB_WORKSPACE/install" ]]; then
    echo "syncing from apps install folder"
    rsync -av $GITHUB_WORKSPACE/install/base $REPO_PATH/
    rsync -av $GITHUB_WORKSPACE/install/overlays/$OVERLAY $REPO_PATH/overlays/ 2>/dev/null
  fi

  # commit changes to catalog app
  git add $REPO_PATH
  git commit -F- <<EOF
release($APP): upgrade to $VERSION on $REF

$commit_msg
EOF

  # push catalog
  git push origin ${REF}
popd

# commit and push workspace changes
if [ "$PUSH" = true ]; then
  
  pushd $install_folder
    git config --local user.email cloud@brudi.com
    git config --local user.name Mesh

    git add .
    
    if [ "$AMEND" = true ]; then
      git commit --amend --no-edit --no-verify
    else
      git commit -F- <<EOF
chore($APP): release $VERSION

$commit_msg
EOF
    fi
  
    # push the workspace repo itself
    git push origin HEAD

  popd

  if [ ! -z "$MERGE" ]; then
    pushd $GITHUB_WORKSPACE
      git checkout $MERGE
      git merge next
      git push origin $MERGE
    popd
  fi
fi
