# External Secrets Operator

## Usage

This will deploy the [External Secrets Operator](https://github.com/openshift/external-secrets-operator) into an OpenShift 4.19 or later cluster. This operator allows you create git-safe `ExternalSecret` CRDs that reference secrets held in an external secrets manager such as AWS SecretManager, Azure Key Vault, Hashicorp Vault, etc... This is one way to safely manage secrets in a GitOps workflow.

After installing the operator and instance, you will need to create a `SecretStore` to configure the details of how External Secrets can connect to your chosen secret manager.  When that is in place, you can create `ExternalSecret` CRDs to create a normal Kubernetes Secret from the values it references in the secret store.

## Install Operator

Reference one of the `operator/overlay` directories.  For example:

```
oc apply -k external-secrets-operator/operator/overlays/tech-preview-v0.1
```

