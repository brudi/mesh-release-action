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

COMMIT_MSG=`git log -1 --pretty=%B`

is_fallback_app_name=false
# default
if [ -z "$APP" ]
then
  is_fallback_app_name=true
  APP=${PWD##*/}
  echo "app param not defined. using current folder name ${APP}"
fi

# clone and configure the catalog Git repository
git clone "https://brudicloud:${TOKEN}@${REPO}" catalog
cd catalog
git checkout ${REF}
git config --local user.email cloud@brudi.com
git config --local user.name Mesh


# configure path to app configuration
if [ -z "$REPO_PATH" ]
then
  # mesh convention: expect apps in 'apps' folder
  REPO_PATH="apps/${APP}"
  
  if [[ ! -d "$REPO_PATH" ]] && [ "$is_fallback_app_name" = true ] ; then    # when using fallback app name but the 'apps' folder 
    # does not exist, we fallback to the 'base' directory. 
    #
    # The app is now only used in the commit message. 
    REPO_PATH='base';
  fi
fi

echo "release Mesh app '$APP' ($VERSION) in $REPO"
echo "-> $COMMIT_MSG"

# create app config directory if it doesn't exist yet
if [[ ! -d "$REPO_PATH" ]]; then
  mkdir -p $REPO_PATH
fi

# sync base config
if [[ ! -d "$GITHUB_WORKSPACE/install" ]]; then
  echo "syncing from apps install folder"
  rsync -a $GITHUB_WORKSPACE/install/base $REPO_PATH/
  rsync -a $GITHUB_WORKSPACE/install/overlays $REPO_PATH/ 2>/dev/null
fi

# change to desired app config directory
cd $REPO_PATH

# use overlay
if [ ! -z "$OVERLAY" ]; then
  echo "editing overlay kustomization at overlays/'$OVERLAY'"
  cd overlays/$OVERLAY
else
  echo "editing base kustomization"
  cd base
fi

# edit image tags
if [ ! -z "$IMAGES" ]; then
  if [ -z "$IMAGE_BASE" ]; then
    echo "ERROR: define the 'imageBase' when using 'images'!"
    exit 1;
  fi
  echo "editing $IMAGES with base $IMAGE_BASE"
  edit_all_images $IMAGE_BASE $IMAGES $VERSION
elif [ ! -z "$IMAGE" ]; then
  edit_image_tag $IMAGE $VERSION
else
  echo "ERROR: one of 'image' or 'images' must be defined"
fi


test $? -eq 0 || exit 1

# commit and push
git add $REPO_PATH
git commit -m "chore($APP): release $REF $VERSION" -m $COMMIT_MSG
git push origin ${REF}
