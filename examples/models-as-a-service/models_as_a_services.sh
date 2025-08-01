#!/bin/bash

# This script contains prerequisite and post-install steps for the
# Models as a Service example.

prerequisite() {
    echo "--- Running prerequisite steps for Models as a Service ---"

    # 3scale RWX Storage check
    echo "The 3scale operator requires a storage class with ReadWriteMany (RWX) access mode."
    echo "Red Hat OpenShift Data Foundation (ODF) is the recommended way to provide this."
    read -p "Do you have an RWX-capable storage class available in your cluster? (y/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "An RWX storage class is required. Please install OpenShift Data Foundation (ODF) or another RWX-capable storage solution and then re-run the script."
        exit 1
    fi

    read -p "Please enter the name of the RWX storage class: " rwx_storage_class
    while [ -z "$rwx_storage_class" ]; do
        echo "Storage class name cannot be empty."
        read -p "Please enter the name of the RWX storage class: " rwx_storage_class
    done

    INSTANCE_YAML_PATH="examples/models-as-a-service/components/3scale/cluster/instance.yaml"

    # Update wildcard domain
    echo "Discovering cluster wildcard domain..."
    CONSOLE_URL=$(oc whoami --show-console)
    WILDCARD_DOMAIN=$(echo "${CONSOLE_URL}" | sed -n 's/.*\.//p' | cut -d'/' -f1)
    if [ -z "$WILDCARD_DOMAIN" ]; then
        echo "Could not automatically determine wildcard domain. Please update ${INSTANCE_YAML_PATH} manually."
    else
        WILDCARD_DOMAIN_APPS=$(echo $CONSOLE_URL | sed 's/https.*console-openshift-console\.//' | sed 's/\/$//')
        echo "Found wildcard domain: ${WILDCARD_DOMAIN_APPS}"
        if grep -q "<wildcard-domain>" "$INSTANCE_YAML_PATH"; then
            echo "Updating 3scale instance with wildcard domain..."
            sed -i.bak "s|<wildcard-domain>|${WILDCARD_DOMAIN_APPS}|" "$INSTANCE_YAML_PATH"
            rm "${INSTANCE_YAML_PATH}.bak"
            echo "File ${INSTANCE_YAML_PATH} updated."
        else
            echo "Wildcard domain seems to be already set in ${INSTANCE_YAML_PATH}."
        fi
    fi

    if grep -q "<storage-class>" "$INSTANCE_YAML_PATH"; then
        echo "Updating 3scale instance with storage class: ${rwx_storage_class}"
        sed -i.bak "s|<storage-class>|${rwx_storage_class}|" "$INSTANCE_YAML_PATH"
        rm "${INSTANCE_YAML_PATH}.bak"
        echo "File ${INSTANCE_YAML_PATH} updated."
    else
        echo "Storage class seems to be already set in ${INSTANCE_YAML_PATH}."
    fi



    echo "--- Prerequisite steps completed. ---"
}

post-install-steps() {
    echo "--- Running post-install steps for Models as a Service ---"
    
    # Wait for 3scale to be ready
    echo "Waiting for 3scale APIManager to be ready..."
    oc wait --for=condition=Available --timeout=15m apimanager/apimanager -n 3scale

    # Get 3scale admin password
    THREESCALE_ADMIN_PASS=$(oc get secret system-seed -n 3scale -o jsonpath='{.data.ADMIN_PASSWORD}' | base64 -d)
    THREESCALE_ADMIN_URL=$(oc get route -l zync.3scale.net/route-to=system-provider -n 3scale -o jsonpath='{.items[0].spec.host}')
    echo "3scale Admin URL: https://${THREESCALE_ADMIN_URL}"
    echo "3scale Admin Password: ${THREESCALE_ADMIN_PASS}"
    echo
    echo "Please follow the 3scale configuration steps from the README to set up backends, products, and application plans."
    echo "Press enter to continue after you have configured 3scale..."
    read

    # Get RH-SSO credentials
    echo "Waiting for RH-SSO Keycloak to be ready..."
    oc wait --for=condition=Ready --timeout=15m keycloak/rh-sso -n rh-sso
    
    RHSSO_ADMIN_USER=$(oc get secret credential-rh-sso -n rh-sso -o jsonpath='{.data.ADMIN_USERNAME}' | base64 -d)
    RHSSO_ADMIN_PASS=$(oc get secret credential-rh-sso -n rh-sso -o jsonpath='{.data.ADMIN_PASSWORD}' | base64 -d)
    RHSSO_URL=$(oc get route keycloak -n rh-sso -o jsonpath='{.spec.host}')
    echo "RH-SSO Admin URL: https://${RHSSO_URL}/auth/admin/maas/console/"
    echo "RH-SSO Admin User: ${RHSSO_ADMIN_USER}"
    echo "RH-SSO Admin Password: ${RHSSO_ADMIN_PASS}"
    echo
    echo "Please follow the RH-SSO configuration steps from the README to create a client for 3scale and configure the identity provider."
    echo "Press enter to continue after you have configured RH-SSO and linked it in 3scale..."
    read

    # Display test commands
    PROD_API_URL=$(oc get route -l apimanager.apps.3scale.net/route-to=apicast-production -n 3scale -o jsonpath='{.items[0].spec.host}')
    echo "--- Post-install steps completed! ---"
    echo "You can now test the API. Get an API key from the 3scale developer portal."
    echo
    echo "Example test command:"
    echo "curl -X 'POST' \\"
    echo "    'https://${PROD_API_URL}/v1/completions' \\"
    echo "    -H 'accept: application/json' \\"
    echo "    -H 'Content-Type: application/json' \\"
    echo "    -H 'Authorization: Bearer <YOUR_3SCALE_API_KEY>' \\"
    echo "    -d '{"
    echo "    \"model\": \"<your-model-name>\","
    echo "    \"prompt\": \"San Francisco is a\","
    echo "    \"max_tokens\": 15,"
    echo "    \"temperature\": 0"
    echo "}'"

    update_developer_portal
}

update_developer_portal() {
    echo "--- Updating 3scale Developer Portal ---"

    echo "Retrieving 3scale admin access token..."
    ACCESS_TOKEN=$(oc get secret system-seed -n 3scale -o jsonpath='{.data.ADMIN_ACCESS_TOKEN}' | base64 -d)
    if [ -z "$ACCESS_TOKEN" ]; then
        echo "Failed to retrieve 3scale access token. Please ensure the 'system-seed' secret exists in the '3scale' namespace and is populated."
        read -p "Press enter to continue or Ctrl+C to abort."
        return
    fi

    echo "Retrieving 3scale admin host..."
    ADMIN_HOST=$(oc get route -n 3scale | grep 'maas-admin' | awk '{print $2}')
    if [ -z "$ADMIN_HOST" ]; then
        echo "Failed to retrieve 3scale admin host. Please ensure the route exists in the '3scale' namespace."
        read -p "Press enter to continue or Ctrl+C to abort."
        return
    fi
    echo "Found 3scale admin host: ${ADMIN_HOST}"

    PORTAL_DIR="examples/models-as-a-service/components/3scale/portal"
    if [ ! -d "$PORTAL_DIR" ]; then
        echo "Portal content directory not found at ${PORTAL_DIR}"
        echo "Please ensure the portal files are located there. You may need to copy them from the original models-aas-demo/3scale/portal directory."
        read -p "Press enter to continue or Ctrl+C to abort."
        return
    fi

    echo "Updating developer portal content... This may take a moment."
    podman run --userns=keep-id:uid=185 -it --rm -v "${PORTAL_DIR}":/cms:Z ghcr.io/fwmotion/3scale-cms:latest \
        -k --access-token="${ACCESS_TOKEN}" "https://${ADMIN_HOST}" upload --delete-missing --layout=/l_main_layout.html.liquid

    echo "Developer portal update command executed."
    echo "Note: There is also a 'download' option if you want to make changes manually on the 3scale CMS portal first."
    echo "--- Finished updating 3scale Developer Portal ---"
} 