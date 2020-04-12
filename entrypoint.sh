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
install_folder=$action_root/install
kustomize_folder=$install_folder/base

is_fallback_app_name=false

# default app name
if [ -z "$APP" ]; then
  is_fallback_app_name=true
  APP=${PWD##*/}
  echo "app param not defined. using current folder name ${APP}"
fi

# set desired app kustomization directory
if [ ! -z "$OVERLAY" ]; then
  if [ "$OVERLAY" = "prod" ]; then
    echo "overwrite base images for production overlay upgrade"
  else
    echo "editing images in kustomization at overlays/$OVERLAY"
    kustomize_folder=$install_folder/overlays/$OVERLAY
  fi
else
  echo "editing images in base kustomization"
fi

# edit image tags
cd $kustomize_folder
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

# clone and configure the catalog Git repository
git clone "https://brudicloud:${TOKEN}@${REPO}" $install_folder/tmp_catalog
cd $install_folder/tmp_catalog
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
if [[ -d "$install_folder" ]]; then
  echo "syncing from apps install folder"
  rsync -av $install_folder/base $REPO_PATH/
  rsync -av $install_folder/overlays/$OVERLAY $REPO_PATH/overlays/ 2>/dev/null
fi

# commit changes to catalog app
git add $REPO_PATH
git commit -F- <<EOF
release($APP): upgrade to $VERSION on $REF

$commit_msg
EOF

# push catalog
git push origin ${REF}

# remove catalog
rm -r $install_folder/tmp_catalog

# commit and push workspace changes
cd $install_folder
git pull origin next
git config --local user.email cloud@brudi.com
git config --local user.name Mesh

git add .

num_ahead=$(git rev-list --count next...origin/next)
if [ "$AMEND" = true ] && [ $num_ahead -gt 0 ]; then 
  git commit --amend --no-edit --no-verify
else
  git commit -F- <<EOF
chore($APP): release $VERSION

$commit_msg
EOF
fi
  
# push the workspace repo itself
if [ "$PUSH" = true ]; then
  git log --oneline -3
  git push origin next
fi

# merge workspace branch
if [ ! -z "$MERGE" ]; then
  cd $GITHUB_WORKSPACE
    git checkout $MERGE
    git merge next
    git push origin $MERGE
  cd
fi
