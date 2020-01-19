#!/bin/sh -l

APP=${1}
VERSION=${2}
TOKEN=${3}
REPO=${4}
REF=${5}
REPO_PATH=${6-$APP}
KUSTOMIZATION=${7}
TAG_PATH=${8:-$FILE.newTag}

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
git checkout ${BRANCH}
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
echo "updating $TAG_PATH in $KUSTOMIZATION at $REPO_PATH"

# create app config directory if it doesn't exist yet
if [[! -d "$REPO_PATH" ]]; then
  mkdir -p $REPO_PATH
fi

# change to desired app config directory
cd $REPO_PATH

# replace version in kustomization file
yq write --inplace -- $KUSTOMIZATION $TAG_PATH $VERSION

# commit and push
git add $KUSTOMIZATION
git commit -m "chore($APP): release $APP $VERSION"
git push origin ${BRANCH}
