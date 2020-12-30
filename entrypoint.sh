#!/bin/bash

# shellcheck source=utils.sh
. $(dirname "$0")/utils.sh
# shellcheck source=edit.sh
. $(dirname "$0")/edit.sh

APP=${1}
APP_FOLDER=${2:-install}
VERSION=${3}
TOKEN=${4}
REPO=${5}
REF=${6}
REPO_PATH=${7-$APP}
IMAGE=${8}
IMAGE_BASE=${9}
IMAGES=${10}
OVERLAY=${11}
COMMIT=${12:-true}
AMEND=${13:-false}
PUSH=${14:-false}
MERGE=${15:false}

commit_msg=$(git log -1 --pretty=%B)
action_root=$(pwd)
catalog_dir=$action_root/tmp_catalog
install_folder=$action_root/$APP_FOLDER
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

startsection "Configuration"
printprop "App" "$APP"
printprop "Version" "$VERSION"
printprop "Repository" "$REPO on $REF"
printprop "Path" "$REPO_PATH"
printprop "Overlay" "$OVERLAY"
printprop "Commit" "$COMMIT"
printprop "Amend" "$AMEND"
printprop "Push" "$PUSH"
printprop "Merge" "$MERGE"
endsection

startsection "Kustomization"
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
endsection

startsection "Synchronization"
echo "Synchronize to $REPO on $REF"

# clone and configure the catalog Git repository
git clone "https://brudicloud:${TOKEN}@${REPO}" "$catalog_dir"
cd "$catalog_dir" || exit 1

# configure git user
git config --local user.email brudi@brudi.com
git config --local user.name brudi

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

catalog_app="$catalog_dir/$REPO_PATH"
# sync all overlays to catalog app
if [[ -d "$install_folder" ]]; then
  echo "Sync base from install folder at $install_folder to $catalog_app/"
  rsync -Iav "$install_folder/base" "$REPO_PATH/"
  if [ -n "$OVERLAY" ]; then
    echo "Sync overlay from install folder at $install_folder/overlays/$OVERLAY to $catalog_app/overlays/"
    rsync -Iav "$install_folder/overlays/$OVERLAY" "$catalog_app/overlays/"
  fi

  # exit on sync errors
  test $? -eq 0 || exit 1

  # list changed files
  git status -s $catalog_app
fi
endsection

startsection "Release App"
# commit changes to catalog app
echo "Commit catalog changes in $REPO_PATH on $REF"
cd "$catalog_app" || exit 1
git add .
git commit -F- <<EOF
release($APP): upgrade to $VERSION on $REF

$commit_msg
EOF

# push catalog
echo "Push catalog changes to $REF"
git push origin "$REF"
test $? -eq 0 || exit 1

# remove catalog
cd "$action_root"
rm -rf "$catalog_dir"
endsection

startsection "Commit Release Changes"
if [ "$COMMIT" = true ] || [ "$AMEND" = true ] || [ "$PUSH" = true ]; then
  # commit and push workspace changes
  cd "$install_folder" || exit 1
  ws_branch=$(git symbolic-ref --short HEAD)

  git config --local user.email brudi@brudi.com
  git config --local user.name brudi

  echo "Commit app changes in $install_folder on $ws_branch"
  git add .

  # FIXME: To prevent unintended overwritees, re-enable rev-list test to check,
  #        whether or not an actual release commit is available already.
  # num_ahead=$(git rev-list --count "$ws_branch...origin/$ws_branch")
  # if [ "$AMEND" = true ] && [ "$num_ahead" -gt 0 ]; then
  if [ "$AMEND" = true ]; then
    echo "Amend release commit as requested"
    git commit --amend --no-edit --no-verify
  else
    echo "Create a new commit for this release"
    git commit -F- <<EOF
chore($APP): release $VERSION

$commit_msg
EOF
  fi
  # push the workspace repo itself
  if [ "$PUSH" = true ]; then
    echo "push app changes to $ws_branch"
    git push origin "$ws_branch"
    test $? -eq 0 || exit 1
  else
    echo "Push app changes is disabled"
  fi
else
  echo "Push release changes is disabled"
fi
endsection

# merge workspace branch
startsection "Merge Release"
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
endsection
