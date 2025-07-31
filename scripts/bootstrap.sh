#!/bin/bash
set -e

EXAMPLES_DIR="examples"
ARGOCD_NS="openshift-gitops"

source "$(dirname "$0")/functions.sh"

choose_example(){
    examples_dir=${EXAMPLES_DIR}

    echo
    echo "Choose an example you wish to deploy?"
    PS3="Please enter a number to select an example folder: "

    select chosen_example in $(basename -a ${examples_dir}/*/); 
    do
    test -n "${chosen_example}" && break;
    echo ">>> Invalid Selection";
    done

    echo "You selected ${chosen_example}"

    CHOSEN_EXAMPLE_PATH=${examples_dir}/${chosen_example}
}

choose_example_option(){
    if [ -z "$1" ]; then
        echo "Error: No option provided to choose_example_option()"
        echo "Usage: choose_example_option <chose_example_path>"
        exit 1
    fi
    chosen_example_path=$1

    echo

    # Check if argocd/overlays directory exists and count subdirectories
    overlays_dir="${chosen_example_path}/argocd/overlays"
    if [ -d "$overlays_dir" ]; then
        overlay_count=$(find "$overlays_dir" -mindepth 1 -maxdepth 1 -type d | wc -l)
        if [ "$overlay_count" -gt 1 ]; then
            # multiple overlay options found
            # let the user choose which one to deploy
            echo "Multiple overlay options found in ${overlays_dir}:"
            PS3="Choose an option you wish to deploy?"
            select chosen_option in $(basename -a ${overlays_dir}/*/);
            do
                test -n "${chosen_option}" && break;
                echo ">>> Invalid Selection";
            done
            echo "You selected ${chosen_option}"
        elif [ "$overlay_count" -eq 1 ]; then
            # one overlay option found
            # use the default one
            chosen_option=$(basename $(find "$overlays_dir" -mindepth 1 -maxdepth 1 -type d))
            echo "One overlay option found in ${overlays_dir}: ${chosen_option}"
        else
            echo "No overlay options found in ${overlays_dir}"
            exit 2
        fi

        CHOSEN_EXAMPLE_OPTION_PATH=${overlays_dir}/${chosen_option}
    else
        echo "Argocd folder was not found: ${overlays_dir}"
        exit 2
    fi
}

deploy_example(){
    if [ -z "$1" ]; then
        echo "Error: No option provided to deploy_example()"
        echo "Usage: deploy_example <chose_example_overlay_path>"
        exit 1
    fi
    chose_example_overlay_path=$1

    echo
    echo "Deploying example: ${chose_example_overlay_path}"
    kustomize build ${chose_example_overlay_path} | oc apply -n ${ARGOCD_NS} -f -
}

deploy_example_with_helm(){
    if [ -z "$1" ]; then
        echo "Error: No option provided to deploy_example()"
        echo "Usage: deploy_example <chose_example_overlay_path>"
        exit 1
    fi
    chose_example_overlay_path=$1

    example_name="blah"

    helm install ${example_name} ./charts/argocd-appgenerator -n ${ARGOCD_NS} \
        --set repoURL=${GITHUB_URL} \
        --set revision=${GIT_BRANCH} \
        --set directories[0].path=${chose_example_overlay_path}
}


set_repo_url(){
    GIT_REPO=$(git config --get remote.origin.url)
    GIT_REPO_BASENAME=$(get_git_basename ${GIT_REPO})
    GITHUB_URL="https://github.com/${GIT_REPO_BASENAME}.git"
    
    echo
    echo "Current repository URL: ${GITHUB_URL}"
    echo
    read -p "Press Enter to use this URL, or enter a new repository URL: " user_input
    
    if [ -n "$user_input" ]; then
        GITHUB_URL="$user_input"
        echo "Updated repository URL to: ${GITHUB_URL}"
    else
        echo "Using repository URL: ${GITHUB_URL}"
    fi
}

set_repo_branch(){
    GIT_BRANCH=$(git rev-parse --abbrev-ref HEAD)

    echo
    echo "Current repository branch: ${GIT_BRANCH}"
    echo
    read -p "Press Enter to use this branch, or enter a new repository branch: " user_input
    
    if [ -n "$user_input" ]; then
        GIT_BRANCH="$user_input"
        echo "Updated repository branch to: ${GIT_BRANCH}"
    else
        echo "Using repository branch: ${GIT_BRANCH}"
    fi
}

main(){
    set_repo_url
    set_repo_branch
    choose_example
    choose_example_option ${CHOSEN_EXAMPLE_PATH}
    # deploy_example ${CHOSEN_EXAMPLE_OPTION_PATH}
}

# check_oc_login
main
