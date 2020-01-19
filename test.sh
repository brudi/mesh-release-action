#!/bin/sh -l

is_fallback_app_name=true
REPO_PATH=
  if ([ -z "$REPO_PATH" ] && [[ ! -d "$REPO_PATH" ]]) && [ "$is_fallback_app_name" = true ] ; then
    # when using fallback app name but the 'apps' folder 
    # does not exist, we fallback to the 'base' directory. 
    #
    # The app is now only used in the commit message. 
    REPO_PATH='base';
	fi



echo "updating  $REPO_PATH"
