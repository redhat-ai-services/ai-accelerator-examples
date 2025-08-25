#!/bin/bash
set -e

# check login
check_oc_login(){
  oc cluster-info | head -n1
  oc whoami || exit 1
  echo
}

get_git_basename(){
  if [ -z "$1" ]; then
    echo "No repo provided."
    exit 1
  else
    REPO_URL=$1
  fi

  QUERY='s#(git@|https://)github.com[:/]([a-zA-Z0-9_.-]+/[a-zA-Z0-9_.-]+)\.git#\2#'
  REPO_BASENAME=$(echo ${REPO_URL} | sed -E  ${QUERY})
  echo ${REPO_BASENAME}
}

# $1 is the name of the array (declared as, for example, `declare -A params=(["key1"]="value1" ["key2"]="value2")`)
# then call `$(expand_params_to_helm_params params)`
# to get the list of parameters for helm
expand_params_to_helm_params() {
    declare -n inhash=$1
    declare -a outlist

    for param in "${!inhash[@]}"; do
        outlist+=("--set" "${param}"="${inhash[$param]}")
    done

    echo "${outlist[@]}"
}
