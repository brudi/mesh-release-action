#!/bin/bash

# shellcheck source=edit.sh
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
COMMIT=${11:-true}
AMEND=${12-:false}
PUSH=${13:-false}
MERGE=${13}

commit_msg=$(git log -1 --pretty=%B)
action_root=$(pwd)
catalog_dir=$action_root/tmp_catalog
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
  if [ "$OVERLAY" != "prod" ]; then
    kustomize_folder=$install_folder/overlays/$OVERLAY
  fi
fi

printf "\n------------ Configuration -------------\n"
echo "App: $APP"
echo "Version: $VERSION"
echo "Repository: $REPO on $REF in $REPO_PATH"
echo "Overlay: $OVERLAY"
echo "Commit app changes?: $COMMIT"
echo "Amend commit: $AMMEND"
echo "Push app changes: $PUSH"
echo "Merge release commit to: $MERGE"
printf "----------------------------------------\n\n"

printf "------------ Kustomization -------------\n"
echo "Kustomize image versions in $kustomize_folder"
cd "$kustomize_folder" || exit 1
if [ ! -z "$IMAGES" ]; then
  if [ -z "$IMAGE_BASE" ]; then
    echo "ERROR: missing 'imageBase' when using 'images'!"
    exit 1
  fi
  echo "Set image tage to $VERSION for $IMAGES with base $IMAGE_BASE"
  edit_all_images "$IMAGE_BASE" "$IMAGES" "$VERSION"
elif [ ! -z "$IMAGE" ]; then
  edit_image_tag "$IMAGE" "$VERSION"
else
  echo "ERROR: one of 'image' or 'images' must be defined"
  exit 1
fi
test $? -eq 0 || exit 1
printf "----------------------------------------\n\n"

printf "----------- Synchronization ------------\n"
echo "Synchronize to $REPO on $REF"

# clone and configure the catalog Git repository
git clone "https://brudicloud:${TOKEN}@${REPO}" "$catalog_dir"
cd "$catalog_dir" || exit 1

# configure git user
git config --local user.email cloud@brudi.io
git config --local user.name Mesh

# checkout release branch of catalog
git checkout "$REF"

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

# create app config directory if it doesn't exist yet
if [[ ! -d "$REPO_PATH" ]]; then
  mkdir -p $REPO_PATH
fi

printf "\nUpdate app config for '%s' (%s) in %s at %s:\n---\n%s\n---\n" "$APP" "$VERSION" "$REPO" "$REPO_PATH" "$commit_msg"

# sync all overlays to catalog app
if [[ -d "$install_folder" ]]; then
  echo "Sync from install folder at $install_folder to $catalog_dir/$REPO_PATH"
  rsync -a "$install_folder/base" "$REPO_PATH/"
  rsync -a "$install_folder/overlays/$OVERLAY" "$REPO_PATH/overlays/"
  test $? -eq 0 || exit 1
fi
printf "----------------------------------------\n\n"

printf "------------- Release App --------------\n"
# commit changes to catalog app
echo "commit catalog changes in $REPO_PATH on $REF"
git add $REPO_PATH
git commit -F- <<EOF
release($APP): upgrade to $VERSION on $REF

$commit_msg
EOF

# push catalog
echo "push catalog changes to $REF"
git push origin "$REF"
test $? -eq 0 || exit 1

# remove catalog
rm -r "$action_root/tmp_catalog"
printf "----------------------------------------\n\n"

printf "------- Commit Release Changes ---------\n"
if [ "$COMMIT" = true ] || [ "$AMEND" = true ] || [ "$PUSH" = true ]; then
  # commit and push workspace changes
  cd "$install_folder" || exit 1
  ws_branch=$(git symbolic-ref --short HEAD)

  git config --local user.email cloud@brudi.com
  git config --local user.name Mesh

  echo "commit app changes in $install_folder on $ws_branch"
  git add .

  num_ahead=$(git rev-list --count "$ws_branch...origin/$ws_branch")
  if [ "$AMEND" = true ] && [ "$num_ahead" -gt 0 ]; then
    echo "amend release commit as requested"
    git commit --amend --no-edit --no-verify
  else
    echo "create a new commit for this release"
    git commit -F- <<EOF
chore($APP): release $VERSION

$commit_msg
EOF
  fi
  # push the workspace repo itself
  if [ "$PUSH" = true ]; then
    echo "push app changes to $ws_branch"
    git push origin "$ws_branch"
  fi
else
  echo "Commit & push of release changes is disabled"
fi
printf "----------------------------------------\n\n"

# merge workspace branch
printf "------------ Merge Release -------------\n"
if [ -n "$MERGE" ]; then
  echo "Merge $ws_branch into $MERGE in $action_root"
  cd "$action_root" || exit 1
  git checkout "$MERGE"
  git merge "$ws_branch"
  git push origin "$MERGE"
  git checkout "$ws_branch"
else
  echo "Merge of release changes is disabled"
fi
printf "----------------------------------------"
