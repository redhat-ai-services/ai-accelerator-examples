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


prerequisite() {
    echo "--- Running prerequisite steps for Models as a Service ---"

    check_commands jq yq oc git

    # Patch ArgoCD instance to avoid 3scale operator race conditions
    # See https://access.redhat.com/solutions/6989746 for more details
    patch_argocd_instance_if_needed

    # Create 3scale secret only if it doesn't exist
    create_threescale_registry_auth_secret

    # Create the Keycloak default TLS secret, based on the cluster's default router certificate
    create_keycloak_default_tls_secret

    # Create the secret to serve the Keycloak database credentials
    create_keycloak_database_secret

    echo "--- Prerequisite steps completed. ---" 
}


post-install-steps() {
    echo "--- Running post-install steps for Models as a Service ---"

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

    # Wait for redhat-sso namespace to be created
    echo "Waiting for the redhat-sso namespace to be created..."
    until oc get namespace redhat-sso &> /dev/null; do
        echo "Namespace 'redhat-sso' not found. Waiting..."
        sleep 10
    done
    echo "Namespace 'redhat-sso' found."

    # Wait for REDHAT-SSO Keycloak to be created
    echo "Waiting for statefulset Keycloak to be created..."
    until oc get statefulset/redhat-sso -n redhat-sso &> /dev/null; do
        echo "statefulset 'redhat-sso' in namespace 'redhat-sso' not found. Waiting..."
        sleep 30
    done
    echo "statefulset 'redhat-sso' in namespace 'redhat-sso' found."

    # Get REDHAT-SSO credentials
    echo "Waiting for statefulset 'redhat-sso' to be ready..."
    oc wait --for=jsonpath='{.status.readyReplicas}'=1 statefulset/redhat-sso -n redhat-sso --timeout=15m

    echo "Waiting for Red Hat SSO route to be created..."
    until oc get ingress redhat-sso-ingress -n redhat-sso &> /dev/null; do
        echo "Route 'redhat-sso' in namespace 'redhat-sso' not found. Waiting..."
        sleep 30
    done
    echo "Route 'redhat-sso' in namespace 'redhat-sso' found."

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

    # Get 3scale admin password
    THREESCALE_ADMIN_PASS=$(oc get secret system-seed -n 3scale -o jsonpath='{.data.ADMIN_PASSWORD}' | base64 -d)
    THREESCALE_ADMIN_URL=$(oc get route -l zync.3scale.net/route-to=system-provider -n 3scale -o jsonpath='{.items[0].spec.host}')

    # Get REDHAT-SSO admin password
    REDHATSSO_ADMIN_USER=$(oc get secret redhat-sso-initial-admin -n redhat-sso -o jsonpath='{.data.username}' | base64 -d)
    REDHATSSO_ADMIN_PASS=$(oc get secret redhat-sso-initial-admin -n redhat-sso -o jsonpath='{.data.password}' | base64 -d)
    REDHATSSO_URL=$(oc get route  -n redhat-sso -o jsonpath='{.items[0].spec.host}')

    echo
    echo "--- Admin credentials ---"
    echo

    echo "3scale Admin URL: ${COLOR_PINK}https://${THREESCALE_ADMIN_URL}${COLOR_RESET}"
    echo "3scale Admin Password: ${COLOR_PINK}${THREESCALE_ADMIN_PASS}${COLOR_RESET}"

    echo "REDHAT-SSO Admin URL: ${COLOR_PINK}https://${REDHATSSO_URL}${COLOR_RESET}"
    echo "REDHAT-SSO Admin User: ${COLOR_PINK}${REDHATSSO_ADMIN_USER}${COLOR_RESET}"
    echo "REDHAT-SSO Admin Password: ${COLOR_PINK}${REDHATSSO_ADMIN_PASS}${COLOR_RESET}"
}


# TODO: this secret is required by 3scale; here, for testing purposes, I'm copying one from the cluster
create_threescale_registry_auth_secret() {

    # Create the 3scale namespace if it doesn't exist
    create_namespace_if_not_exists "3scale"

    if ! oc get secret threescale-registry-auth -n 3scale &>/dev/null; then
        echo "Creating threescale-registry-auth secret..."
        
        # Extract existing cluster pull secret
        PULL_SECRET=$(oc extract secret/pull-secret -n openshift-config --keys=.dockerconfigjson --to=- | base64 -w 0)
        
        # Create secret using HEREDOC
        oc apply -f - <<EOF
apiVersion: v1
kind: Secret
metadata:
  name: threescale-registry-auth
  namespace: 3scale
  annotations:
    argocd.argoproj.io/sync-options: "Prune=false"
    argocd.argoproj.io/compare-options: "IgnoreExtraneous"
  labels:
    rhoai-example: maas
    rhoai-example-component: 3scale
type: kubernetes.io/dockerconfigjson
data:
  .dockerconfigjson: ${PULL_SECRET}
EOF

    else
        echo "Secret threescale-registry-auth already exists in 3scale namespace."
    fi
}

# TODO: create this secret via Helm chart / refactor to the cert-manager operator.
create_keycloak_default_tls_secret() {

    # Create the redhat-sso namespace if it doesn't exist
    create_namespace_if_not_exists "redhat-sso"

    # Create the secret to serve the Keycloak TLS certificate, if not exists
    if ! oc get secret keycloak-tls-cert -n redhat-sso &>/dev/null; then
        echo "Creating keycloak-tls-cert secret..."

        # Extract the default ingress certificate
        local INGRESS_CERT_NAME
        INGRESS_CERT_NAME=$(oc get ingresscontroller/default -n openshift-ingress-operator -o jsonpath='{.spec.defaultCertificate.name}')

        local INGRESS_CERT_DATA
        INGRESS_CERT_DATA=$(oc get secret "$INGRESS_CERT_NAME" -n openshift-ingress -o jsonpath='{.data}')

        # Extract certificate and key data
        local TLS_CRT_DATA
        TLS_CRT_DATA=$(echo "$INGRESS_CERT_DATA" | jq -r '."tls.crt"')
        local TLS_KEY_DATA
        TLS_KEY_DATA=$(echo "$INGRESS_CERT_DATA" | jq -r '."tls.key"')
        
        # Create TLS secret using HEREDOC
        oc apply -f - <<EOF
apiVersion: v1
kind: Secret
metadata:
  name: keycloak-tls-cert
  namespace: redhat-sso
  annotations:
    argocd.argoproj.io/sync-options: "Prune=false"
    argocd.argoproj.io/compare-options: "IgnoreExtraneous"
  labels:
    rhoai-example: maas
    rhoai-example-component: redhat-sso-instance
type: kubernetes.io/tls
data:
  tls.crt: '${TLS_CRT_DATA}'
  tls.key: '${TLS_KEY_DATA}'
EOF
    fi
}

# TODO: Figure a way to create this secret via Helm chart
#       Helm currently create the secret, but since the secret is using random generated items,
#       Every time ArgoCD syncs, the secret is recreated, and Keycloak database is now inaccessible.
#       This is a workaround to create the secret manually.
create_keycloak_database_secret() {
    # Create the redhat-sso namespace if it doesn't exist
    create_namespace_if_not_exists "redhat-sso"

    # Create the secret to serve the Keycloak database, if not exists
    if ! oc get secret postgres-db -n redhat-sso &>/dev/null; then
        oc apply -f - <<EOF
apiVersion: v1
kind: Secret
metadata:
  name: postgres-db
  namespace: redhat-sso
  annotations:
    argocd.argoproj.io/sync-options: "Prune=false"
    argocd.argoproj.io/compare-options: "IgnoreExtraneous"
  labels:
    rhoai-example: maas
    rhoai-example-component: redhat-sso-instance
type: Opaque
data:
  POSTGRESQL_USER: '$(echo -n "redhat-sso" | base64)'
  POSTGRESQL_PASSWORD: '$(echo -n $RANDOM | md5sum | head -c 32 | base64)'
  POSTGRESQL_DATABASE: '$(echo -n "keycloak" | base64)'
EOF
    else
        echo "Secret postgres-db already exists in redhat-sso namespace."
    fi
}

