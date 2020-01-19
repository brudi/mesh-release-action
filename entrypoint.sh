#!/bin/sh -l

APP=${1}
VERSION=${2}
TOKEN=${3}
REPO=${4}
REF=${5:-"master"}
REPO_PATH=${6:-"."}
KUSTOMIZATION=${7:-"kustomization.yaml"}
TAG_PATH=${8:-$FILE.newTag}

echo "release Mesh app '$APP' ($VERSION) in $REPO"
echo "updating $TAG_PATH in $KUSTOMIZATION at $REPO_PATH"

# clone and configure Git
git clone "https://brudicloud:${TOKEN}@${REPO}" catalog
cd catalog

git checkout ${BRANCH}
git config --local user.email cloud@brudi.com
git config --local user.name Mesh

# change to desired app  directory
cd $REPO_PATH

# replace version in kustomization file
yq write --inplace -- $KUSTOMIZATION $TAG_PATH $VERSION

# commit and push
git add $KUSTOMIZATION
git commit -m "chore($APP): release $APP $VERSION"
git push origin ${BRANCH}
