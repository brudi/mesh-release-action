#!/bin/sh -l

APP=${1}
VERSION=${2}
TOKEN=${3}
REPO=${4}
REPO_PATH=${5}
VALUES=${6}

echo "Release Mesh app '$APP' ($VERSION) in $REPO"
echo "using values file $VALUES at $PATH"

# clone and configure Git
git clone "https://brudicloud:${TOKEN}@${REPO}" chart
cd chart
git checkout master
git config --local user.email cloud@brudi.com
git config --local user.name brudi Mesh

# change app to chart directory
if [ -z "$REPO_PATH" ]
then
  echo "Using chart at /"
else
  echo "Using chart at $REPO_PATH"
  cd $REPO_PATH
fi

# replace version in values file
yq write --inplace -- $VALUES $APP.tag $VERSION

# commit and push
git add $VALUES
git commit -m "chore(object-sites): release $APP $VERSION"
git push origin master