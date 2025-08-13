# Models as a Service Example

This example deploys a "Models as a Service" (MaaS) environment using Red Hat OpenShift. It provides a complete setup for serving and managing machine learning models as scalable, secure, and monetizable APIs.

## Included Components

This example automates the deployment and configuration of the following components:

*   **3scale API Management**: For API gateway functionality, including access control, rate limiting, and analytics.
*   **Red Hat SSO (Keycloak)**: For centralized authentication and authorization, integrated with the 3scale developer portal.
*   **OpenShift Data Foundation (ODF)**: As a recommended provider for the required ReadWriteMany (RWX) storage, used by 3scale.

## Prerequisites

Before you begin, ensure you have the following:

*   An OpenShift cluster with cluster-admin privileges.
*   The OpenShift GitOps operator installed.
*   The following command-line tools installed locally:
    *   `oc`
    *   `git`
    *   `jq`
    *   `yq`
    *   `podman`

## Deployment

To deploy this example, clone this repository and run the bootstrap script from the root directory:

```bash
./bootstrap.sh
```

Then select the `models-as-a-service` example from the menu.

The script will guide you through the following pre-deployment configuration steps:

1.  **Storage Configuration**: You will be prompted to provide the name of a ReadWriteMany (RWX) capable storage class available on your cluster. Red Hat OpenShift Data Foundation (ODF) is the recommended solution for providing this.
2.  **Git Repository Configuration**: The script will automatically detect your current Git repository URL and branch to configure the ArgoCD ApplicationSet.
3.  **Commit and Push**: You will be prompted to commit and push these configuration changes to your repository. This step is required for the GitOps-based deployment to work correctly. The script uses a Git credential helper to cache your credentials temporarily.

The bootstrap script then deploys the components using OpenShift GitOps.

## Post-Installation

After the initial deployment is complete, the script performs several post-installation tasks automatically:

*   Waits for all components (3scale, Red Hat SSO) to become ready.
*   Retrieves and displays the admin credentials for 3scale and Red Hat SSO.
*   Configures a Keycloak client for 3scale integration.
*   Creates a sample `developer` user in Keycloak for testing purposes.
*   Configures the 3scale developer portal with Single Sign-On (SSO) via Keycloak.
*   Updates the 3scale developer portal with custom content.

### Registering a Model

After the post-installation steps, you will be prompted to register a new model with 3scale. This interactive process will ask for:

*   **Model Name**: A unique name for your model.
*   **Model URL**: The internal service URL where your model is deployed.

The script then automatically creates the necessary backend, product, and application plan in 3scale to expose your model through the API gateway. You can register multiple models. 