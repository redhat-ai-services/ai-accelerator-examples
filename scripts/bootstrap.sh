#!/usr/bin/env bash
set -euo pipefail

EXAMPLES_DIR="examples"
ARGOCD_NS="openshift-gitops"

SCRIPT_DIR=$(readlink -f "$0")
SCRIPT_DIR=$(dirname "$SCRIPT_DIR")

# Load helper functions
# shellcheck disable=SC1091
source "$SCRIPT_DIR/functions.sh"

# Print commands as they are executed, if debug is enabled
if is_debug_enabled; then
    set -x
fi

choose_example(){
    examples_dir=${EXAMPLES_DIR}

    echo
    echo "Choose an example you wish to deploy? "
    PS3="Please enter a number to select an example folder:"

    select chosen_example in $(basename -a ${examples_dir}/*/);
    do
    test -n "${chosen_example}" && break;
    echo ">>> Invalid Selection";
    done

    echo "You selected ${chosen_example}"

    CHOSEN_EXAMPLE_PATH=${examples_dir}/${chosen_example}
}

choose_example_kustomize_option(){
    if [ -z "$1" ]; then
        echo "Error: No option provided to choose_example_kustomize_option()"
        echo "Usage: choose_example_kustomize_option <chosen_example_path>"
        exit 1
    fi
    chosen_example_path=$1

    echo

    # Find the first directory matching the pattern ${chosen_example_path}/*/overlays
    overlays_parent_dir=$(find "${chosen_example_path}" -mindepth 2 -maxdepth 2 -type d -name "overlays" | head -n 1)

    if [ -n "$overlays_parent_dir" ]; then
        overlays_dir="$overlays_parent_dir"

        echo "Found overlays directory: ${overlays_dir}"

        overlay_count=$(find "$overlays_dir" -mindepth 1 -maxdepth 1 -type d | wc -l)
        if [ "$overlay_count" -gt 1 ]; then
            # multiple overlay options found
            # let the user choose which one to deploy
            echo "Multiple overlay options found in ${overlays_dir}:"
            PS3="Choose an option you wish to deploy? "
            select chosen_option in $(find "${overlays_dir}/" -mindepth 1 -maxdepth 1 -type d -exec basename {} \; | sort);
            do
                test -n "${chosen_option}" && break;
                echo ">>> Invalid Selection";
            done
            echo "You selected ${chosen_option}"
        elif [ "$overlay_count" -eq 1 ]; then
            # one overlay option found
            # use the default one
            chosen_option=$(basename "$(find "$overlays_dir" -mindepth 1 -maxdepth 1 -type d)")
            echo "One overlay option found in ${overlays_dir}: ${chosen_option}"
        else
            echo "No overlay options found in ${overlays_dir}"
            exit 2
        fi

        CHOSEN_EXAMPLE_OPTION_PATH="${chosen_example_path}/*/overlays/${chosen_option}"
    else
        if [ -n "${chosen_example_path}/helm-charts" ]; then
            echo "No overlays folder was found, but helm-charts folder was found"
            CHOSEN_EXAMPLE_OPTION_PATH=""
        else
            echo "No overlays folder was found matching pattern: ${chosen_example_path}/*/overlays"
            echo "No helm-charts folder was found matching pattern: ${chosen_example_path}/helm-charts"
            exit 2
        fi
    fi
}

deploy_example(){
    if [ -z "$1" ]; then
        echo "Error: No option provided to deploy_example()"
        echo "Usage: deploy_example <example_name>"
        exit 1
    fi
    chosen_example_path="${1}"
    chosen_example_overlay_path="${1:-""}"

    # Extract the example name from the path (second component after splitting by "/")
    example_name=$(echo "${chosen_example_path}" | cut -d'/' -f2)

    echo
    echo "Example name: ${example_name}"
    echo "GIT_REPO: ${GIT_REPO}"
    echo "GIT_BRANCH: ${GIT_BRANCH}"
    echo "chosen_example_overlay_path: ${chosen_example_overlay_path}"
    echo

    CLUSTER_DOMAIN_NAME=$(oc get ingresses.config.openshift.io cluster -o jsonpath='{.spec.domain}')


    helm upgrade -i ${example_name} ./charts/argocd-appgenerator -n ${ARGOCD_NS} \
        --set fullnameOverride=${example_name} \
        --set repoURL=${GIT_REPO} \
        --set targetRevision=${GIT_BRANCH} \
        --set clusterDomainUrl=${CLUSTER_DOMAIN_NAME} \
        --set kustomizeDirectories[0].path="${chosen_example_overlay_path}" \
        --set helmDirectories[0].path="${chosen_example_path}/helm-charts/**"
}

set_repo_url(){
    GIT_REPO=$(git config --get remote.origin.url)

    echo
    echo "Current repository URL: ${GIT_REPO}"
    echo
    read -r -p "Press Enter to use this URL, or enter a new repository URL: " user_input

    if [ -n "$user_input" ]; then
        GIT_REPO="$user_input"
        echo "Updated repository URL to: ${GIT_REPO}"
    else
        echo "Using repository URL: ${GIT_REPO}"
    fi

    # Save as a helm parameter for later usage
    helm_params+=(
        ["GIT_REPO"]="${GIT_REPO}"
        ["repoURL"]="${GIT_REPO}"
    )
}

set_repo_branch(){
    GIT_BRANCH=$(git rev-parse --abbrev-ref HEAD)

    echo
    echo "Current repository branch: ${GIT_BRANCH}"
    echo
    # shellcheck disable=SC2162
    read -p "Press Enter to use this branch, or enter a new repository branch: " user_input

    if [ -n "$user_input" ]; then
        GIT_BRANCH="$user_input"
        echo "Updated repository branch to: ${GIT_BRANCH}"
    else
        echo "Using repository branch: ${GIT_BRANCH}"
    fi

    # Save as a helm parameter for later usage
    helm_params+=(
        ["GIT_BRANCH"]="${GIT_BRANCH}"
        ["targetRevision"]="${GIT_BRANCH}"
    )
}

main(){
    # Initialize helm params array
    declare -A helm_params

    set_repo_url
    set_repo_branch

    choose_example
    choose_example_kustomize_option "${CHOSEN_EXAMPLE_PATH}"

    echo
    echo "Looking for custom example script: ${CHOSEN_EXAMPLE_PATH}/${chosen_example}.sh"

    if [ -e "${CHOSEN_EXAMPLE_PATH}/${chosen_example}.sh" ]; then
        echo "Found custom example script: ${CHOSEN_EXAMPLE_PATH}/${chosen_example}.sh. Importing..."
        # shellcheck disable=SC1090
        source "${CHOSEN_EXAMPLE_PATH}/${chosen_example}.sh"
    fi

    [[ $(type -t prerequisite) == function ]] && prerequisite

    deploy_example  "${CHOSEN_EXAMPLE_PATH}" "${CHOSEN_EXAMPLE_OPTION_PATH}"

    [[ $(type -t post-install-steps) == function ]] && post-install-steps
}

# check_oc_login
main
