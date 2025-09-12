#!/usr/bin/env bash
set -e

# check login
check_oc_login() {
  oc cluster-info | head -n1
  oc whoami || exit 1
  echo
}

# Function to check for required command-line tools
check_commands() {
    for cmd in "$@"; do
        if ! command -v "$cmd" &> /dev/null; then
            echo "Error: ${cmd} is not installed. Please install it to continue."
            exit 1
        fi
    done
}

# $1 is the name of the array (declared as, for example, `declare -A params=(["key1"]="value1" ["key2"]="value2")`)
# then call `$(expand_params_to_helm_params params)`
# to get the list of parameters for helm
expand_params_to_helm_params() {
    declare -n inhash=$1
    declare -a outlist

    for param in "${!inhash[@]}"; do
        outlist+=("--set" "\"${param}\"=\"${inhash[$param]}\"")
    done

    echo "${outlist[@]}"
}

pause() {
  #read -t5 -n1 -r -p 'Press any key in the next five seconds...' key
  # shellcheck disable=SC2034
  read -n1 -r -p "Press any key to continue..." key
}

is_debug_enabled() {
    [ "${DEBUG:-}" = true ] || [ "${DEBUG:-}" = 1 ] || [ "${DEBUG:-}" = "true" ] || [ "${DEBUG:-}" = "1" ]
}

# Patch ArgoCD instance to avoid 3scale operator race conditions
# See https://access.redhat.com/solutions/6989746 for more details
patch_argocd_instance_if_needed() {
    local ARGOCD_SYNC_WAVE_DELAY
    ARGOCD_SYNC_WAVE_DELAY=$(oc get argocd/openshift-gitops -n openshift-gitops -o json | jq '.spec?.controller?.env[]? | select(.name == "ARGOCD_SYNC_WAVE_DELAY") | .value')

    if [ -z "$ARGOCD_SYNC_WAVE_DELAY" ]; then
        echo "ARGOCD_SYNC_WAVE_DELAY is not set. Setting it to 5 seconds."

        oc patch argocd/openshift-gitops -n openshift-gitops \
            --type=json -p='[{"op": "add", "path": "/spec/controller/env", "value": [{ "name": "ARGOCD_SYNC_WAVE_DELAY", "value": "5" }]}]'

        # ArgoCD instance will restart automatically.
        echo "ArgoCD instance patched."
    fi
}


create_namespace_if_not_exists() {
    local namespace=$1
    if ! oc get namespace "$namespace" &>/dev/null; then
        echo "Creating namespace $namespace..."
        oc apply -f - <<EOF
apiVersion: v1
kind: Namespace
metadata:
  name: "$namespace"
  labels:
    argocd.argoproj.io/managed-by: openshift-gitops
EOF
    fi
}
