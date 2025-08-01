# Models as a Service Example

This example deploys a "Models as a Service" environment using Red Hat OpenShift.

It includes the following components:

*   3scale API Management
*   OpenShift Data Foundation (ODF)
*   RedHat SSO

## Prerequisites

- An OpenShift cluster
- The OpenShift GitOps operator installed

## Deployment

To deploy this example, run the bootstrap script from the root of the repository:

```bash
./bootstrap.sh
```

Then select the `models-as-a-service` example from the menu. 