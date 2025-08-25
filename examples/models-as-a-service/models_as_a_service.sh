#!/usr/bin/env bash
set -euo pipefail

# Color helpers for console output (pink and reset)
if [ -t 1 ]; then
    COLOR_PINK="$(printf '\033[95m')"
    COLOR_RESET="$(printf '\033[0m')"
else
    COLOR_PINK=""
    COLOR_RESET=""
fi

# This script contains prerequisite and post-install steps for the
# Models as a Service example.

# Function to check for required command-line tools
check_commands() {
    for cmd in "$@"; do
        if ! command -v "$cmd" &> /dev/null; then
            echo "Error: ${cmd} is not installed. Please install it to continue."
            exit 1
        fi
    done
}

prerequisite() {
    echo "--- Running prerequisite steps for Models as a Service ---"

    check_commands jq yq oc git

    # Patch ArgoCD instance to avoid 3scale operator race conditions
    oc patch argocd/openshift-gitops -n openshift-gitops \
         --type=json -p='[{"op": "add", "path": "/spec/controller/env", "value": [{ "name": "ARGOCD_SYNC_WAVE_DELAY", "value": "10" }]}]'

    # Force restart of ArgoCD application controllerinstance
    echo "ArgoCD instance patched. Waiting 5 seconds for the change to take effect..."
    sleep 5
    oc rollout restart statefulset/openshift-gitops-application-controller -n openshift-gitops

    # Discover cluster's wildcard domain
    echo "Discovering cluster wildcard domain..."
    WILDCARD_DOMAIN=$(oc get ingresscontroller -n openshift-ingress-operator default -o jsonpath='{.status.domain}')
    if [ -z "$WILDCARD_DOMAIN" ]; then
        echo "Could not automatically determine wildcard domain."
        exit 1
    else
        echo "Found wildcard domain: ${WILDCARD_DOMAIN}"
    fi

    # TODO: this secret is required by 3scale; here, for testing purposes, I'm copying one from the cluster

    # Create the 3scale namespace if it doesn't exist
    if ! oc get namespace 3scale &>/dev/null; then
        echo "Creating namespace 3scale..."
        oc create namespace 3scale && \
            oc label namespace 3scale argocd.argoproj.io/managed-by=openshift-gitops
    fi

    # Create secret only if it doesn't exist
    if ! oc get secret threescale-registry-auth -n 3scale &>/dev/null; then
        echo "Creating threescale-registry-auth secret..."
        oc extract secret/pull-secret -n openshift-config --keys=.dockerconfigjson --to=- \
            | grep -v .dockerconfigjson \
            | oc create secret generic threescale-registry-auth -n 3scale --type=kubernetes.io/dockerconfigjson --from-file=.dockerconfigjson=/dev/stdin

        oc annotate secret/threescale-registry-auth -n 3scale \
            argocd.argoproj.io/sync-options="Prune=false" \
            argocd.argoproj.io/compare-options="IgnoreExtraneous"
    else
        echo "Secret threescale-registry-auth already exists in 3scale namespace."
    fi

    # Extract the default ingress certificate
    local DEFAULT_INGRESS_CERTIFICATE
    DEFAULT_INGRESS_CERTIFICATE=$(oc get ingresscontroller/default -n openshift-ingress-operator -o jsonpath='{.spec.defaultCertificate.name}')

    # Create the redhat-sso namespace if it doesn't exist
    if ! oc get namespace redhat-sso &>/dev/null; then
        echo "Creating namespace redhat-sso..."
        oc create namespace redhat-sso && \
            oc label namespace redhat-sso argocd.argoproj.io/managed-by=openshift-gitops
    fi

    # Create the secret to serve the Keycloak TLS certificate
    oc create secret generic keycloak-tls-cert \
        --from-file=tls.crt=<(oc get secret $DEFAULT_INGRESS_CERTIFICATE -n openshift-ingress -o jsonpath='{.data.tls\.crt}' | base64 -d) \
        --from-file=tls.key=<(oc get secret $DEFAULT_INGRESS_CERTIFICATE -n openshift-ingress -o jsonpath='{.data.tls\.key}' | base64 -d) \
        --namespace=redhat-sso \
        --type="kubernetes.io/tls"

    oc annotate secret/keycloak-tls-cert \
        -n redhat-sso \
        argocd.argoproj.io/sync-options="Prune=false" \
        argocd.argoproj.io/compare-options="IgnoreExtraneous"

    # Save the wildcard domain as a helm parameter for later usage
    # TODO: keep this list updated with the new parameters
    helm_params+=(
        ["wildcardDomain"]="${WILDCARD_DOMAIN}"
        ["apimanager.wildcardDomain"]="${WILDCARD_DOMAIN}"
        ["deployer.domain"]="${WILDCARD_DOMAIN}"
    )

    # Prepare repository parameters
    GIT_REPO="${helm_params["GIT_REPO"]}"
    GIT_BRANCH="${helm_params["GIT_BRANCH"]}"

    # TODO: keep this list updated with the new parameters
    helm_params+=(
        ["threeScale.repoURL"]="${GIT_REPO}"
        ["cmsUpload.repoURL"]="${GIT_REPO}"
        ["minio.repoURL"]="${GIT_REPO}"
        ["llmaas.repoURL"]="${GIT_REPO}"
        ["rhssoInstance.repoURL"]="${GIT_REPO}"
        ["rhssoOperator.repoURL"]="${GIT_REPO}"
        ["threeScale.targetRevision"]="${GIT_BRANCH}"
        ["cmsUpload.targetRevision"]="${GIT_BRANCH}"
        ["minio.targetRevision"]="${GIT_BRANCH}"
        ["llmaas.targetRevision"]="${GIT_BRANCH}"
        ["rhssoOperator.targetRevision"]="${GIT_BRANCH}"
        ["rhssoInstance.targetRevision"]="${GIT_BRANCH}"
    )

    echo "--- Prerequisite steps completed. ---"
}

post-install-steps() {
    echo "--- Running post-install steps for Models as a Service ---"

    # Define common curl options.
    # WARNING: Using -k to disable certificate validation is a security risk.
    # This should only be used in trusted, controlled development environments.
    # In production, you should ensure proper certificates are configured.
    CURL_OPTS=("-s" "-k")

    # Wait for 3scale namespace to be created
    echo "Waiting for the 3scale namespace to be created..."
    until oc get namespace 3scale &> /dev/null; do
        echo "Namespace '3scale' not found. Waiting..."
        sleep 10
    done
    echo "Namespace '3scale' found."
    
    # Wait for 3scale APIManager to be created
    echo "Waiting for 3scale APIManager to be created..."
    until oc get apimanager/apimanager -n 3scale &> /dev/null; do
        echo "APIManager 'apimanager' in namespace '3scale' not found. Waiting..."
        sleep 30
    done
    echo "APIManager 'apimanager' in namespace '3scale' found."

    # Wait for 3scale to be ready
    echo "Waiting for 3scale APIManager to be ready..."
    oc wait --for=condition=Available --timeout=15m apimanager/apimanager -n 3scale

    # Get 3scale admin password
    THREESCALE_ADMIN_PASS=$(oc get secret system-seed -n 3scale -o jsonpath='{.data.ADMIN_PASSWORD}' | base64 -d)
    THREESCALE_ADMIN_URL=$(oc get route -l zync.3scale.net/route-to=system-provider -n 3scale -o jsonpath='{.items[0].spec.host}')
    echo "3scale Admin URL: ${COLOR_PINK}https://${THREESCALE_ADMIN_URL}${COLOR_RESET}"
    echo "3scale Admin Password: ${COLOR_PINK}${THREESCALE_ADMIN_PASS}${COLOR_RESET}"


    # Wait for redhat-sso namespace to be created
    echo "Waiting for the redhat-sso namespace to be created..."
    until oc get namespace redhat-sso &> /dev/null; do
        echo "Namespace 'redhat-sso' not found. Waiting..."
        sleep 10
    done
    echo "Namespace 'redhat-sso' found."

    # Wait for REDHAT-SSO Keycloak to be created
    echo "Waiting for statefulset Keycloak to be created..."
    until oc get statefulset/keycloak -n redhat-sso &> /dev/null; do
        echo "statefulset 'keycloak' in namespace 'redhat-sso' not found. Waiting..."
        sleep 30
    done
    echo "statefulset 'keycloak' in namespace 'redhat-sso' found."

    # Get REDHAT-SSO credentials
    echo "Waiting for statefulset 'keycloak' to be ready..."
    oc wait --for=jsonpath='{.status.readyReplicas}'=1 statefulset/keycloak -n redhat-sso --timeout=15m
    
    REDHATSSO_ADMIN_USER=$(oc get secret credential-redhat-sso -n redhat-sso -o jsonpath='{.data.ADMIN_USERNAME}' | base64 -d)
    REDHATSSO_ADMIN_PASS=$(oc get secret credential-redhat-sso -n redhat-sso -o jsonpath='{.data.ADMIN_PASSWORD}' | base64 -d)
    REDHATSSO_URL=$(oc get route keycloak -n redhat-sso -o jsonpath='{.spec.host}')
    echo "REDHAT-SSO Admin URL: ${COLOR_PINK}https://${REDHATSSO_URL}${COLOR_RESET}"
    echo "REDHAT-SSO Admin User: ${COLOR_PINK}${REDHATSSO_ADMIN_USER}${COLOR_RESET}"
    echo "REDHAT-SSO Admin Password: ${COLOR_PINK}${REDHATSSO_ADMIN_PASS}${COLOR_RESET}"

    echo "Retrieving 3scale admin access token and host..."
    ACCESS_TOKEN=$(oc get secret system-seed -n 3scale -o jsonpath='{.data.ADMIN_ACCESS_TOKEN}' | base64 -d)
    if [ -z "$ACCESS_TOKEN" ]; then
        echo "Failed to retrieve 3scale access token. Please ensure the 'system-seed' secret exists in the '3scale' namespace and is populated."
        exit 1
    fi

    ADMIN_HOST=$(oc get route -n 3scale | grep 'maas-admin' | awk '{print $2}')
    if [ -z "$ADMIN_HOST" ]; then
        echo "Failed to retrieve 3scale admin host. Please ensure the route exists in the '3scale' namespace."
        exit 1
    fi
    echo "Found 3scale admin host: ${ADMIN_HOST}"
}

refresh_keycloak_token() {
    KEYCLOAK_TOKEN=$(curl "${CURL_OPTS[@]}" -X POST "https://${REDHATSSO_URL}/auth/realms/master/protocol/openid-connect/token" \
        -H "Content-Type: application/x-www-form-urlencoded" \
        -d "username=${REDHATSSO_ADMIN_USER}" \
        -d "password=${REDHATSSO_ADMIN_PASS}" \
        -d "grant_type=password" \
        -d "client_id=admin-cli" | jq -r .access_token)
    if [ -z "$KEYCLOAK_TOKEN" ] || [ "$KEYCLOAK_TOKEN" == "null" ]; then
        echo "Failed to refresh Keycloak admin token."
        exit 1
    fi
}

