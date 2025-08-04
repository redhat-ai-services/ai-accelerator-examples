#!/bin/bash
set -euo pipefail

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

    check_commands jq yq oc git podman

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

    VALUES_YAML_3SCALE_PATH="examples/models-as-a-service/components/3scale/values.yaml"

    # Update wildcard domain
    echo "Discovering cluster wildcard domain..."
    WILDCARD_DOMAIN_APPS=$(oc get ingresscontroller -n openshift-ingress-operator default -o jsonpath='{.status.domain}')
    if [ -z "$WILDCARD_DOMAIN_APPS" ]; then
        echo "Could not automatically determine wildcard domain. Please update ${VALUES_YAML_3SCALE_PATH} manually."
    else
        echo "Found wildcard domain: ${WILDCARD_DOMAIN_APPS}"
        echo "Updating 3scale instance with wildcard domain..."
        yq e -i '.wildcardDomain = "'"${WILDCARD_DOMAIN_APPS}"'"' "$VALUES_YAML_3SCALE_PATH"
        echo "File ${VALUES_YAML_3SCALE_PATH} updated."
    fi

    echo "Updating 3scale instance with storage class: ${rwx_storage_class}"
    yq e -i '.storageClassName = "'"${rwx_storage_class}"'"' "$VALUES_YAML_3SCALE_PATH"
    echo "File ${VALUES_YAML_3SCALE_PATH} updated."

    # Update ApplicationSet with current Git repo and branch
    echo "--- Updating ApplicationSet configuration ---"
    APPLICATIONSET_YAML_PATH="examples/models-as-a-service/argocd/base/applicationset.yaml"
    
    CURRENT_REPO_URL=$(git config --get remote.origin.url)
    CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD)

    if [ -z "$CURRENT_REPO_URL" ] || [ -z "$CURRENT_BRANCH" ]; then
        echo "Error: Could not determine current Git repository URL or branch."
        echo "Please ensure you are in a valid Git repository."
        return 1
    fi

    echo "Updating ApplicationSet to use your repository:"
    echo "  Repo URL: ${CURRENT_REPO_URL}"
    echo "  Branch: ${CURRENT_BRANCH}"

    yq e -i '.spec.generators[0].git.repoURL = "'"${CURRENT_REPO_URL}"'"' "${APPLICATIONSET_YAML_PATH}"
    yq e -i '.spec.generators[0].git.revision = "'"${CURRENT_BRANCH}"'"' "${APPLICATIONSET_YAML_PATH}"
    yq e -i '.spec.template.spec.source.repoURL = "'"${CURRENT_REPO_URL}"'"' "${APPLICATIONSET_YAML_PATH}"
    yq e -i '.spec.template.spec.source.targetRevision = "'"${CURRENT_BRANCH}"'"' "${APPLICATIONSET_YAML_PATH}"

    echo "ApplicationSet updated successfully."

    # Commit and push changes
    echo "--- Pushing configuration changes to Git ---"
    read -p "Do you want to commit and push the configuration changes to your repository? (y/n) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        git config --global credential.helper 'cache --timeout=3600'

        git add "${VALUES_YAML_3SCALE_PATH}" "${APPLICATIONSET_YAML_PATH}"
        
        # Check if there are changes to commit
        if git diff --staged --quiet; then
            echo "No configuration changes to commit."
        else
            git commit -m "Update MaaS configuration for deployment"
            echo "Pushing changes to branch '${CURRENT_BRANCH}'..."
            if git push origin "HEAD:${CURRENT_BRANCH}"; then
                echo "Configuration pushed to repository successfully."
            else
                echo "Error: Failed to push configuration to repository."
                echo "Please check your credentials and ensure you have push permissions."
                return 1
            fi
        fi
    else
        echo "Skipping Git push. Please commit and push the changes manually for the deployment to work correctly."
    fi

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
    echo "3scale Admin URL: https://${THREESCALE_ADMIN_URL}"
    echo "3scale Admin Password: ${THREESCALE_ADMIN_PASS}"


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
    echo "REDHAT-SSO Admin URL: https://${REDHATSSO_URL}/auth/admin/maas/console/"
    echo "REDHAT-SSO Admin User: ${REDHATSSO_ADMIN_USER}"
    echo "REDHAT-SSO Admin Password: ${REDHATSSO_ADMIN_PASS}"
    echo
    echo "Press enter to continue REDHAT-SSO configuration steps..."
    read

    configure_keycloak_client
    if [ $? -ne 0 ]; then
        echo "Keycloak configuration failed. Aborting post-install steps."
        return 1
    fi

    echo "Retrieving 3scale admin access token and host..."
    ACCESS_TOKEN=$(oc get secret system-seed -n 3scale -o jsonpath='{.data.ADMIN_ACCESS_TOKEN}' | base64 -d)
    if [ -z "$ACCESS_TOKEN" ]; then
        echo "Failed to retrieve 3scale access token. Please ensure the 'system-seed' secret exists in the '3scale' namespace and is populated."
        return 1
    fi

    ADMIN_HOST=$(oc get route -n 3scale | grep 'maas-admin' | awk '{print $2}')
    if [ -z "$ADMIN_HOST" ]; then
        echo "Failed to retrieve 3scale admin host. Please ensure the route exists in the '3scale' namespace."
        return 1
    fi
    echo "Found 3scale admin host: ${ADMIN_HOST}"

    read -p "Update 3scale developer portal with the latest content? (y/n) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        update_developer_portal
    fi

    configure_sso_developer_portal



    echo "--- Post-install steps completed! ---"
    
    handle_model_registration_loop

    # Clean up the temp file if it exists
    rm -f -- "${RESPONSE_FILE-}"
}

update_developer_portal() {
    echo "--- Updating 3scale Developer Portal ---"

    PORTAL_DIR="examples/models-as-a-service/components/3scale/portal"
    if [ ! -d "$PORTAL_DIR" ]; then
        echo "Portal content directory not found at ${PORTAL_DIR}"
        echo "Please ensure the portal files are located there. You may need to copy them from the original models-aas-demo/3scale/portal directory."
        read -p "Press enter to continue or Ctrl+C to abort."
        return
    fi
    echo "Clean up developer portal content... This may take a moment."
    podman run --userns=keep-id:uid=185 -it --rm -v "$(pwd)/${PORTAL_DIR}":/cms:Z ghcr.io/fwmotion/3scale-cms:latest \
        -k --access-token="${ACCESS_TOKEN}" ${ACCESS_TOKEN} "https://${ADMIN_HOST}" delete --yes-i-really-want-to-delete-the-entire-developer-portal

    echo "Updating developer portal content... This may take a moment."
    podman run --userns=keep-id:uid=185 -it --rm -v "$(pwd)/${PORTAL_DIR}":/cms:Z ghcr.io/fwmotion/3scale-cms:latest \
        -k --access-token="${ACCESS_TOKEN}" ${ACCESS_TOKEN} "https://${ADMIN_HOST}" upload --delete-missing --layout=/l_main_layout.html.liquid

    echo "Developer portal update command executed."
    echo "Note: There is also a 'download' option if you want to make changes manually on the 3scale CMS portal first."
    echo "--- Finished updating 3scale Developer Portal ---"
}

configure_keycloak_client() {
    echo "--- Configuring Keycloak client for 3scale ---"

    echo "Getting Keycloak admin token..."
    KEYCLOAK_TOKEN=$(curl "${CURL_OPTS[@]}" -X POST "https://${REDHATSSO_URL}/auth/realms/master/protocol/openid-connect/token" \
        -H "Content-Type: application/x-www-form-urlencoded" \
        -d "username=${REDHATSSO_ADMIN_USER}" \
        -d "password=${REDHATSSO_ADMIN_PASS}" \
        -d "grant_type=password" \
        -d "client_id=admin-cli" | jq -r .access_token)

    if [ -z "$KEYCLOAK_TOKEN" ] || [ "$KEYCLOAK_TOKEN" == "null" ]; then
        echo "Failed to get Keycloak admin token. Exiting."
        return 1
    fi
    echo "Successfully got Keycloak admin token."

    REALM="maas"

    echo "Checking if client '3scale' exists in realm '${REALM}'..."
    CLIENT_ID_3SCALE=$(curl "${CURL_OPTS[@]}" -X GET "https://${REDHATSSO_URL}/auth/admin/realms/${REALM}/clients?clientId=3scale" \
        -H "Authorization: Bearer ${KEYCLOAK_TOKEN}" | jq -r '.[0].id')

    if [ -n "$CLIENT_ID_3SCALE" ] && [ "$CLIENT_ID_3SCALE" != "null" ]; then
        echo "Client '3scale' already exists with ID: ${CLIENT_ID_3SCALE}. Skipping creation."
    else
        echo "Client '3scale' does not exist. Creating it..."
        CREATE_CLIENT_PAYLOAD=$(cat <<EOF
{
    "clientId": "3scale",
    "protocol": "openid-connect",
    "publicClient": false,
    "standardFlowEnabled": true,
    "implicitFlowEnabled": false,
    "directAccessGrantsEnabled": false,
    "serviceAccountsEnabled": false,
    "redirectUris": ["*"],
    "bearerOnly": false,
    "consentRequired": false
}
EOF
)
        
        curl "${CURL_OPTS[@]}" -X POST "https://${REDHATSSO_URL}/auth/admin/realms/${REALM}/clients" \
            -H "Authorization: Bearer ${KEYCLOAK_TOKEN}" \
            -H "Content-Type: application/json" \
            -d "${CREATE_CLIENT_PAYLOAD}"

        CLIENT_ID_3SCALE=$(curl "${CURL_OPTS[@]}" -X GET "https://${REDHATSSO_URL}/auth/admin/realms/${REALM}/clients?clientId=3scale" \
            -H "Authorization: Bearer ${KEYCLOAK_TOKEN}" | jq -r '.[0].id')
        
        if [ -z "$CLIENT_ID_3SCALE" ] || [ "$CLIENT_ID_3SCALE" == "null" ]; then
            echo "Failed to create client '3scale' or retrieve its ID. Exiting."
            return 1
        fi
        echo "Client '3scale' created with ID: ${CLIENT_ID_3SCALE}."
    fi

    echo "Adding protocol mappers..."

    # Check for 'email verified' mapper
    MAPPER_EXISTS=$(curl "${CURL_OPTS[@]}" -X GET "https://${REDHATSSO_URL}/auth/admin/realms/${REALM}/clients/${CLIENT_ID_3SCALE}/protocol-mappers/models" \
        -H "Authorization: Bearer ${KEYCLOAK_TOKEN}" | jq -r '.[] | select(.name=="email verified") | .name')

    if [ -n "$MAPPER_EXISTS" ]; then
        echo "'email verified' mapper already exists. Skipping."
    else
        EMAIL_VERIFIED_MAPPER_PAYLOAD=$(cat <<EOF
{
    "name": "email verified",
    "protocol": "openid-connect",
    "protocolMapper": "oidc-usermodel-property-mapper",
    "consentRequired": false,
    "config": {
        "userinfo.token.claim": "true",
        "user.attribute": "emailVerified",
        "id.token.claim": "true",
        "access.token.claim": "true",
        "claim.name": "email_verified",
        "jsonType.label": "boolean"
    }
}
EOF
)
        curl "${CURL_OPTS[@]}" -X POST "https://${REDHATSSO_URL}/auth/admin/realms/${REALM}/clients/${CLIENT_ID_3SCALE}/protocol-mappers/models" \
            -H "Authorization: Bearer ${KEYCLOAK_TOKEN}" \
            -H "Content-Type: application/json" \
            -d "${EMAIL_VERIFIED_MAPPER_PAYLOAD}"
        echo "Added 'email verified' mapper."
    fi

    # Check for 'org_type' mapper
    MAPPER_EXISTS=$(curl "${CURL_OPTS[@]}" -X GET "https://${REDHATSSO_URL}/auth/admin/realms/${REALM}/clients/${CLIENT_ID_3SCALE}/protocol-mappers/models" \
        -H "Authorization: Bearer ${KEYCLOAK_TOKEN}" | jq -r '.[] | select(.name=="org_type") | .name')

    if [ -n "$MAPPER_EXISTS" ]; then
        echo "'org_type' mapper already exists. Skipping."
    else
        ORG_TYPE_MAPPER_PAYLOAD=$(cat <<EOF
{
    "name": "org_type",
    "protocol": "openid-connect",
    "protocolMapper": "oidc-usermodel-attribute-mapper",
    "consentRequired": false,
    "config": {
        "user.attribute": "email",
        "claim.name": "org_name",
        "jsonType.label": "String",
        "id.token.claim": "true",
        "access.token.claim": "true",
        "userinfo.token.claim": "true",
        "aggregate.attributes": "false"
    }
}
EOF
)
        curl "${CURL_OPTS[@]}" -X POST "https://${REDHATSSO_URL}/auth/admin/realms/${REALM}/clients/${CLIENT_ID_3SCALE}/protocol-mappers/models" \
            -H "Authorization: Bearer ${KEYCLOAK_TOKEN}" \
            -H "Content-Type: application/json" \
            -d "${ORG_TYPE_MAPPER_PAYLOAD}"
        echo "Added 'org_type' mapper."
    fi

    echo "--- Creating developer user ---"
    USER_ID=$(curl "${CURL_OPTS[@]}" -X GET "https://${REDHATSSO_URL}/auth/admin/realms/${REALM}/users?username=developer&exact=true" \
        -H "Authorization: Bearer ${KEYCLOAK_TOKEN}" | jq -r '.[0].id')

    if [ -n "$USER_ID" ] && [ "$USER_ID" != "null" ]; then
        echo "User 'developer' already exists. Skipping creation."
    else
        echo "User 'developer' does not exist. Creating..."
        CREATE_USER_PAYLOAD=$(cat <<EOF
{
    "username": "developer",
    "enabled": true,
    "firstName": "John",
    "lastName": "Doe",
    "email": "user@example.com",
    "emailVerified": true
}
EOF
)
        curl "${CURL_OPTS[@]}" -X POST "https://${REDHATSSO_URL}/auth/admin/realms/${REALM}/users" \
            -H "Authorization: Bearer ${KEYCLOAK_TOKEN}" \
            -H "Content-Type: application/json" \
            -d "${CREATE_USER_PAYLOAD}"

        USER_ID=$(curl "${CURL_OPTS[@]}" -X GET "https://${REDHATSSO_URL}/auth/admin/realms/${REALM}/users?username=developer&exact=true" \
            -H "Authorization: Bearer ${KEYCLOAK_TOKEN}" | jq -r '.[0].id')
        
        if [ -z "$USER_ID" ] || [ "$USER_ID" == "null" ]; then
            echo "Failed to create user 'developer' or retrieve its ID."
            return 1
        fi
        echo "User 'developer' created with ID: ${USER_ID}."

        DEVELOPER_PASSWORD=$(uuidgen)
        SET_PASSWORD_PAYLOAD=$(cat <<EOF
{
    "type": "password",
    "value": "${DEVELOPER_PASSWORD}",
    "temporary": false
}
EOF
)
        curl "${CURL_OPTS[@]}" -X PUT "https://${REDHATSSO_URL}/auth/admin/realms/${REALM}/users/${USER_ID}/reset-password" \
            -H "Authorization: Bearer ${KEYCLOAK_TOKEN}" \
            -H "Content-Type: application/json" \
            -d "${SET_PASSWORD_PAYLOAD}"
        
        echo "Password for 'developer' user has been set."
        echo "Username: developer"
        echo "Password: ${DEVELOPER_PASSWORD}"
    fi

    echo "--- Keycloak client configuration completed. ---"
}

configure_sso_developer_portal() {
    echo "--- Configuring 3scale Developer Portal SSO ---"

    RESPONSE_FILE=$(mktemp)
    trap 'rm -f -- "$RESPONSE_FILE"' EXIT

    local HTTP_CODE
    HTTP_CODE=$(curl "${CURL_OPTS[@]}" -w "%{http_code}" -o "${RESPONSE_FILE}" "https://${ADMIN_HOST}/admin/api/authentication_providers.xml?access_token=${ACCESS_TOKEN}")

    if [[ "$HTTP_CODE" -ge 400 ]]; then
        echo "Error: Failed to get Authentication Providers. Received HTTP status ${HTTP_CODE}."
        echo "Response from server:"
        cat "${RESPONSE_FILE}"
        return 1
    fi

    local SSO_INTEGRATION_EXISTS
    SSO_INTEGRATION_EXISTS=$(cat "${RESPONSE_FILE}" | yq -p xml -o json | jq -r '[.authentication_providers.authentication_provider?] | flatten | .[] | select(.kind? == "keycloak") | .id')

    if [ -n "$SSO_INTEGRATION_EXISTS" ]; then
        echo "RH-SSO integration already exists. Skipping creation."
    else
        echo "Creating RH-SSO integration..."
        local CLIENT_SECRET
        CLIENT_SECRET=$(curl "${CURL_OPTS[@]}" -X GET "https://${REDHATSSO_URL}/auth/admin/realms/maas/clients/$(curl "${CURL_OPTS[@]}" -X GET "https://${REDHATSSO_URL}/auth/admin/realms/maas/clients?clientId=3scale" -H "Authorization: Bearer ${KEYCLOAK_TOKEN}" | jq -r '.[0].id')/client-secret" -H "Authorization: Bearer ${KEYCLOAK_TOKEN}" | jq -r '.value')
        if [ -z "$CLIENT_SECRET" ] || [ "$CLIENT_SECRET" == "null" ]; then
            echo "Error: CLIENT_SECRET is not set. Cannot create SSO integration."
            return 1
        fi
        HTTP_CODE=$(curl "${CURL_OPTS[@]}" -w "%{http_code}" -o "${RESPONSE_FILE}" \
            -X POST "https://${ADMIN_HOST}/admin/api/authentication_providers.xml?access_token=${ACCESS_TOKEN}" \
            -H "Content-Type: application/x-www-form-urlencoded" \
            -d "kind=keycloak" \
            -d "name=Red Hat Single Sign-On" \
            -d "client_id=3scale" \
            -d "client_secret=${CLIENT_SECRET}" \
            -d "site=https://${REDHATSSO_URL}/auth/realms/maas" \
            -d "published=true")
        
        if [[ "$HTTP_CODE" -ge 400 ]]; then
            echo "Error: Failed to create RH-SSO integration. Received HTTP status ${HTTP_CODE}."
            echo "Response from server:"
            cat "${RESPONSE_FILE}"
            return 1
        fi
        echo "RH-SSO integration created."
    fi

    local AUTH_PROVIDER_ID
    AUTH_PROVIDER_ID=$(curl "${CURL_OPTS[@]}" -X GET "https://${ADMIN_HOST}/admin/api/authentication_providers.xml?access_token=${ACCESS_TOKEN}" | yq -p xml -o json | jq -r '[.authentication_providers.authentication_provider?] | flatten | .[] | select(.kind? == "keycloak") | .id')
    
    if [ -z "$AUTH_PROVIDER_ID" ]; then
        echo "Failed to retrieve Authentication Provider ID. Cannot update 'Always approve accounts'."
        return 1
    fi

    echo "Updating RH-SSO integration to always approve accounts..."
    HTTP_CODE=$(curl "${CURL_OPTS[@]}" -w "%{http_code}" -o "${RESPONSE_FILE}" \
        -X PUT "https://${ADMIN_HOST}/admin/api/authentication_providers/${AUTH_PROVIDER_ID}.xml?access_token=${ACCESS_TOKEN}" \
        -H "Content-Type: application/x-www-form-urlencoded" \
        -d "automatically_approve_accounts=true")

    if [[ "$HTTP_CODE" -ge 400 ]]; then
        echo "Error: Failed to update RH-SSO integration. Received HTTP status ${HTTP_CODE}."
        echo "Response from server:"
        cat "${RESPONSE_FILE}"
        return 1
    fi
    echo "RH-SSO integration updated."

    echo "--- 3scale Developer Portal SSO configuration completed. ---"
}

handle_model_registration_loop() {
    read -p "Do you want to register a model with 3scale? (y/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        return
    fi

    while true; do
        register_model_3scale_core
        if [ $? -ne 0 ]; then
            echo "Model registration failed. Aborting."
            break
        fi
        
        read -p "Do you want to register another model? (y/n) " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            break
        fi
    done
}

register_model_3scale_core() {
    echo "--- Register a new model with 3scale ---"

    if [ -z "$ADMIN_HOST" ] || [ -z "$ACCESS_TOKEN" ]; then
        echo "Error: ADMIN_HOST or ACCESS_TOKEN not set. Cannot configure 3scale."
        return 1
    fi

    read -p "Enter the model name: " model_name
    while [ -z "$model_name" ]; do
        echo "Model name cannot be empty."
        read -p "Enter the model name: " model_name
    done

    read -p "Enter the model internal service URL (e.g., https://granite-33-2b-instruct.vllm-granite.svc.cluster.local): " model_url
    while [ -z "$model_url" ]; do
        echo "Model URL cannot be empty."
        read -p "Enter the model internal service URL: " model_url
    done

    # 1. Create or get Backend
    echo "Checking for existing backend '${model_name}'..."
    BACKEND_ID=$(curl "${CURL_OPTS[@]}" "https://${ADMIN_HOST}/admin/api/backend_apis.json?access_token=${ACCESS_TOKEN}" | jq -r --arg name "${model_name}" '.backend_apis[] | .backend_api | select(.name == $name) | .id')

    if [ -n "$BACKEND_ID" ] && [ "$BACKEND_ID" != "null" ]; then
        echo "Backend '${model_name}' already exists with ID: ${BACKEND_ID}."
    else
        echo "Creating backend '${model_name}'..."
        BACKEND_RESPONSE=$(curl "${CURL_OPTS[@]}" -w "\n%{http_code}" -X POST "https://${ADMIN_HOST}/admin/api/backend_apis.json" \
            -d "access_token=${ACCESS_TOKEN}" \
            -d "name=${model_name}" \
            -d "private_endpoint=${model_url}")
        
        HTTP_CODE=$(echo "${BACKEND_RESPONSE}" | tail -n1)
        BACKEND_BODY=$(echo "${BACKEND_RESPONSE}" | sed '$d')
        BACKEND_ID=$(echo "${BACKEND_BODY}" | jq -r '.backend_api.id')

        if [ "$HTTP_CODE" -ne 201 ]; then
            echo "Failed to create backend. HTTP Status: ${HTTP_CODE}. Response:"
            echo "${BACKEND_BODY}"
            return 1
        fi
        echo "Backend created with ID: ${BACKEND_ID}"
    fi

    # 2. Create or get Product
    echo "Checking for existing product '${model_name}'..."
    PRODUCT_ID=$(curl "${CURL_OPTS[@]}" "https://${ADMIN_HOST}/admin/api/services.json?access_token=${ACCESS_TOKEN}" | jq -r --arg name "${model_name}" '.services[] | .service | select(.name == $name) | .id')

    if [ -n "$PRODUCT_ID" ] && [ "$PRODUCT_ID" != "null" ]; then
        echo "Product '${model_name}' already exists with ID: ${PRODUCT_ID}."
    else
        echo "Creating product '${model_name}'..."
        PRODUCT_RESPONSE=$(curl "${CURL_OPTS[@]}" -w "\n%{http_code}" -X POST "https://${ADMIN_HOST}/admin/api/services.json" \
            -d "access_token=${ACCESS_TOKEN}" \
            -d "name=${model_name}")
            
        HTTP_CODE=$(echo "${PRODUCT_RESPONSE}" | tail -n1)
        PRODUCT_BODY=$(echo "${PRODUCT_RESPONSE}" | sed '$d')
        PRODUCT_ID=$(echo "${PRODUCT_BODY}" | jq -r '.service.id')

        if [ "$HTTP_CODE" -ne 201 ]; then
            echo "Failed to create product. HTTP Status: ${HTTP_CODE}. Response:"
            echo "${PRODUCT_BODY}"
            return 1
        fi
        echo "Product created with ID: ${PRODUCT_ID}"
    fi

    # 3. Configure Product
    echo "Configuring product..."
    # 3.1 Update proxy settings
    curl "${CURL_OPTS[@]}" -X PATCH "https://${ADMIN_HOST}/admin/api/services/${PRODUCT_ID}/proxy.json" \
        -d "access_token=${ACCESS_TOKEN}" \
        -d "credentials_location=headers" \
        -d "auth_user_key=Authorization" > /dev/null

    # 3.2 Link backend to product
    echo "Linking backend to product..."
    LINK_RESPONSE=$(curl "${CURL_OPTS[@]}" -w "\n%{http_code}" -X POST "https://${ADMIN_HOST}/admin/api/services/${PRODUCT_ID}/backend_usages.json" \
        -d "access_token=${ACCESS_TOKEN}" \
        -d "backend_api_id=${BACKEND_ID}" \
        -d "path=/")
    
    HTTP_CODE=$(echo "${LINK_RESPONSE}" | tail -n1)
    LINK_BODY=$(echo "${LINK_RESPONSE}" | sed '$d')

    if [ "$HTTP_CODE" -eq 201 ]; then
        echo "Backend linked successfully."
    elif [ "$HTTP_CODE" -eq 422 ] && echo "${LINK_BODY}" | jq -e 'tostring | contains("already taken")' > /dev/null; then
        echo "Backend is already linked to the product."
    else
        echo "Failed to link backend to product. HTTP Status: ${HTTP_CODE}. Response:"
        echo "${LINK_BODY}"
        return 1
    fi

    # 3.3 Add Policies
    echo "Adding policies..."
    POLICIES_CONFIG='[{"name":"cors", "version":"1.0.0", "configuration":{"allow_methods":["GET","POST","DELETE","PUT","PATCH","HEAD","OPTIONS"],"allow_credentials":true,"allow_origin":"*","allow_headers":["Authorization","Content-type","Accept"]}, "enabled":true}, {"name":"apicast", "version":"builtin", "configuration":{}, "enabled":true}]'
    curl "${CURL_OPTS[@]}" -X PUT "https://${ADMIN_HOST}/admin/api/services/${PRODUCT_ID}/proxy/policies.json" \
        -d "access_token=${ACCESS_TOKEN}" \
        -d "policies_config=${POLICIES_CONFIG}" > /dev/null

    # 3.4 Add Methods and Mapping Rules
    echo "Adding methods and mapping rules..."
    HITS_METRIC_ID=$(curl "${CURL_OPTS[@]}" "https://${ADMIN_HOST}/admin/api/services/${PRODUCT_ID}/metrics.json?access_token=${ACCESS_TOKEN}" | jq -r '.metrics[] | .metric | select(.system_name=="hits") | .id')
    if [ -z "$HITS_METRIC_ID" ] || [ "$HITS_METRIC_ID" == "null" ]; then
        echo "Error: Could not find 'hits' metric for product."
        return 1
    fi

    METHOD_SYSTEM_NAME="v1_chat_completions_${PRODUCT_ID}"
    FRIENDLY_NAME="v1/chat/completions_${PRODUCT_ID}"
    echo "Creating method '${FRIENDLY_NAME}' (system name: ${METHOD_SYSTEM_NAME})..."
    METHOD_RESPONSE=$(curl "${CURL_OPTS[@]}" -w "\n%{http_code}" -X POST "https://${ADMIN_HOST}/admin/api/services/${PRODUCT_ID}/metrics/${HITS_METRIC_ID}/methods.json" \
        -d "access_token=${ACCESS_TOKEN}" \
        -d "friendly_name=${FRIENDLY_NAME}" \
        -d "system_name=${METHOD_SYSTEM_NAME}")
    
    HTTP_CODE=$(echo "${METHOD_RESPONSE}" | tail -n1)
    METHOD_BODY=$(echo "${METHOD_RESPONSE}" | sed '$d')
    METHOD_ID=$(echo "${METHOD_BODY}" | jq -r '.method.id')

    if [ "$HTTP_CODE" -eq 201 ]; then
        echo "Method '${FRIENDLY_NAME}' created successfully."
    elif [ "$HTTP_CODE" -eq 422 ] && echo "${METHOD_BODY}" | jq -e 'tostring | contains("already taken")' > /dev/null; then
        echo "Method '${FRIENDLY_NAME}' already exists. Getting its ID..."
        METHOD_ID=$(curl "${CURL_OPTS[@]}" "https://${ADMIN_HOST}/admin/api/services/${PRODUCT_ID}/metrics/${HITS_METRIC_ID}/methods.json?access_token=${ACCESS_TOKEN}" | jq -r --arg name "${METHOD_SYSTEM_NAME}" '.methods[] | .method | select(.system_name == $name) | .id')
    else
        echo "Failed to create method. HTTP Status: ${HTTP_CODE}. Response:"
        echo "${METHOD_BODY}"
        return 1
    fi
    if [ -z "$METHOD_ID" ] || [ "$METHOD_ID" == "null" ]; then
        echo "Error: Failed to get method ID for '${FRIENDLY_NAME}'."
        return 1
    fi
    
    PATTERN="/v1/chat/completions"
    echo "Creating mapping rule for pattern '${PATTERN}'..."
    MAPPING_RULE_RESPONSE=$(curl "${CURL_OPTS[@]}" -w "\n%{http_code}" -X POST "https://${ADMIN_HOST}/admin/api/services/${PRODUCT_ID}/proxy/mapping_rules.json" \
        -d "access_token=${ACCESS_TOKEN}" \
        -d "http_method=POST" \
        -d "pattern=${PATTERN}" \
        -d "metric_id=${METHOD_ID}" \
        -d "delta=1")
        
    HTTP_CODE=$(echo "${MAPPING_RULE_RESPONSE}" | tail -n1)
    MAPPING_RULE_BODY=$(echo "${MAPPING_RULE_RESPONSE}" | sed '$d')

    if [ "$HTTP_CODE" -eq 201 ]; then
        echo "Mapping rule created successfully."
    elif [ "$HTTP_CODE" -eq 422 ] && echo "${MAPPING_RULE_BODY}" | jq -e 'tostring | contains("already taken")' > /dev/null; then
        echo "Mapping rule for pattern '${PATTERN}' already exists."
    else
        echo "Failed to create mapping rule. HTTP Status: ${HTTP_CODE}. Response:"
        echo "${MAPPING_RULE_BODY}"
        return 1
    fi

    # 4. Promote Configuration
    echo "Promoting configuration to staging..."
    STAGING_DEPLOY_RESPONSE=$(curl "${CURL_OPTS[@]}" -w "\n%{http_code}" -X POST "https://${ADMIN_HOST}/admin/api/services/${PRODUCT_ID}/proxy/deploy.json" -d "access_token=${ACCESS_TOKEN}")

    HTTP_CODE=$(echo "${STAGING_DEPLOY_RESPONSE}" | tail -n1)
    STAGING_DEPLOY_BODY=$(echo "${STAGING_DEPLOY_RESPONSE}" | sed '$d')

    if [ "$HTTP_CODE" -ne 200 ] && [ "$HTTP_CODE" -ne 201 ]; then
        echo "Failed to deploy to staging. HTTP Status: ${HTTP_CODE}. Response:"
        echo "${STAGING_DEPLOY_BODY}"
        return 1
    fi

    LATEST_STAGING_VERSION=$(curl "${CURL_OPTS[@]}" "https://${ADMIN_HOST}/admin/api/services/${PRODUCT_ID}/proxy/configs/sandbox/latest.json?access_token=${ACCESS_TOKEN}" | jq -r '.proxy_config.version')
    if [ -z "$LATEST_STAGING_VERSION" ] || [ "$LATEST_STAGING_VERSION" == "null" ]; then
        echo "Error: Failed to get latest staging version after deployment."
        return 1
    fi
    echo "Successfully deployed staging version ${LATEST_STAGING_VERSION}."

    echo "Promoting staging version ${LATEST_STAGING_VERSION} to production..."
    PROMOTE_PROD_RESPONSE=$(curl "${CURL_OPTS[@]}" -w "\n%{http_code}" -X POST "https://${ADMIN_HOST}/admin/api/services/${PRODUCT_ID}/proxy/configs/sandbox/${LATEST_STAGING_VERSION}/promote.json" \
        -d "access_token=${ACCESS_TOKEN}" \
        -d "to=production")

    HTTP_CODE=$(echo "${PROMOTE_PROD_RESPONSE}" | tail -n1)
    PROMOTE_PROD_BODY=$(echo "${PROMOTE_PROD_RESPONSE}" | sed '$d')

    if [ "$HTTP_CODE" -ne 201 ]; then
        echo "Failed to promote to production. HTTP Status: ${HTTP_CODE}. Response:"
        echo "${PROMOTE_PROD_BODY}"
        return 1
    fi
    echo "Successfully promoted to production."

    # 5. Application Plans Configuration
    APP_PLAN_NAME="Basic"
    echo "Creating application plan '${APP_PLAN_NAME}'..."
    APP_PLAN_RESPONSE=$(curl "${CURL_OPTS[@]}" -w "\n%{http_code}" -X POST "https://${ADMIN_HOST}/admin/api/services/${PRODUCT_ID}/application_plans.json" \
        -d "access_token=${ACCESS_TOKEN}" \
        -d "name=${APP_PLAN_NAME}" \
        -d "state_event=publish")

    HTTP_CODE=$(echo "${APP_PLAN_RESPONSE}" | tail -n1)
    APP_PLAN_BODY=$(echo "${APP_PLAN_RESPONSE}" | sed '$d')

    if [ "$HTTP_CODE" -eq 201 ]; then
        echo "Application plan '${APP_PLAN_NAME}' created successfully."
    elif [ "$HTTP_CODE" -eq 422 ] && echo "${APP_PLAN_BODY}" | jq -e 'tostring | contains("already taken")' > /dev/null; then
        echo "Application plan '${APP_PLAN_NAME}' already exists."
    else
        echo "Failed to create application plan. HTTP Status: ${HTTP_CODE}. Response:"
        echo "${APP_PLAN_BODY}"
        return 1
    fi

    echo "Model '${model_name}' registered successfully."

    read -p "Do you want to activate this new service for all existing accounts? (y/n) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        activate_service_for_all_accounts "${PRODUCT_ID}"
    fi
}

activate_service_for_all_accounts() {
    local product_id=$1
    echo "--- Activating service for all accounts ---"

    # Get Plan ID for the service
    echo "Getting application plan ID for service ${product_id}..."
    local plan_id
    plan_id=$(curl "${CURL_OPTS[@]}" "https://${ADMIN_HOST}/admin/api/services/${product_id}/application_plans.json?access_token=${ACCESS_TOKEN}" | jq -r '.plans[] | .application_plan | select(.name == "Basic") | .id')

    if [ -z "$plan_id" ] || [ "$plan_id" == "null" ]; then
        echo "Error: Could not find 'Basic' application plan for service ${product_id}."
        return 1
    fi
    echo "Found plan ID: ${plan_id}"

    # Get all accounts
    echo "Fetching all accounts..."
    local page=1
    local total_pages=1
    local account_ids=()
    while [ "$page" -le "$total_pages" ]; do
        local accounts_response
        accounts_response=$(curl "${CURL_OPTS[@]}" "https://${ADMIN_HOST}/admin/api/accounts.json?access_token=${ACCESS_TOKEN}&page=${page}")
        
        if [ "$page" -eq 1 ]; then
            total_pages=$(echo "${accounts_response}" | jq -r '.metadata.total_pages')
            if [ -z "$total_pages" ] || [ "$total_pages" == "null" ]; then
                total_pages=1
            fi
        fi
        
        local ids
        ids=$(echo "${accounts_response}" | jq -r '.accounts[].account.id')
        account_ids+=($ids)
        
        ((page++))
    done

    echo "Found ${#account_ids[@]} accounts to process."

    # Activate service for each account
    local success_count=0
    local fail_count=0
    for account_id in "${account_ids[@]}"; do
        echo "Processing account ID: ${account_id}"
        
        # Check if the account is already subscribed
        local subscribed_plans
        subscribed_plans=$(curl "${CURL_OPTS[@]}" "https://${ADMIN_HOST}/admin/api/accounts/${account_id}/applications.json?access_token=${ACCESS_TOKEN}" | jq -r '.applications[].application.plan_id')

        if echo "${subscribed_plans}" | grep -q "${plan_id}"; then
            echo "  Account already subscribed to this plan. Skipping."
            ((success_count++))
            continue
        fi

        # Create dummy application to subscribe
        local app_response
        app_response=$(curl "${CURL_OPTS[@]}" -w "\n%{http_code}" -X POST "https://${ADMIN_HOST}/admin/api/accounts/${account_id}/applications.json" \
            -d "access_token=${ACCESS_TOKEN}" \
            -d "plan_id=${plan_id}" \
            -d "name=dummy-activation-app-$(date +%s)")
        
        local http_code
        http_code=$(echo "${app_response}" | tail -n1)
        local app_body
        app_body=$(echo "${app_response}" | sed '$d')

        if [ "$http_code" -ne 201 ]; then
            echo "  Failed to create dummy application for account ${account_id}. HTTP Status: ${http_code}. Response:"
            echo "  ${app_body}"
            ((fail_count++))
            continue
        fi

        local app_id
        app_id=$(echo "${app_body}" | jq -r '.application.id')
        echo "  Created dummy application with ID: ${app_id}"

        # Delete dummy application
        local delete_response
        delete_response=$(curl "${CURL_OPTS[@]}" -w "\n%{http_code}" -X DELETE "https://${ADMIN_HOST}/admin/api/accounts/${account_id}/applications/${app_id}.json?access_token=${ACCESS_TOKEN}")
        
        http_code=$(echo "${delete_response}" | tail -n1)

        if [ "$http_code" -ne 200 ]; then
            echo "  Warning: Failed to delete dummy application ${app_id} for account ${account_id}. You may need to delete it manually. HTTP Status: ${http_code}."
        else
            echo "  Successfully activated service and deleted dummy application."
        fi
        
        ((success_count++))
    done

    echo "--- Service activation summary ---"
    echo "Successful activations: ${success_count}"
    echo "Failed activations: ${fail_count}"
    echo "--------------------------------"
} 