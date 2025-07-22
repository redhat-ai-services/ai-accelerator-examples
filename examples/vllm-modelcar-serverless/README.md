# vLLM ModelCar Serverless Example

This example demonstrates how to deploy and serve the Granite 3.3 2B Instruct model using vLLM in a serverless configuration on OpenShift AI using KServe.

This example uses the following Helm chart:
https://github.com/redhat-ai-services/helm-charts/tree/main/charts/vllm-kserve

This example also uses a modelcar from the Red Hat Services ModelCar Catalog:
https://github.com/redhat-ai-services/modelcar-catalog/

## Dependencies

This example requires a cluster with the following components:
* OpenShift AI
  * KServe
* Serverless
* ServiceMesh
* NVIDIA GPU Operator
* Node Feature Discovery

This example also requires that a GPU such as an A10G be available in the cluster.

## Overview

This example contains the following components:

* `argocd`: Used to configure the components using ArgoCD
* `namespaces`: Used to configure the namespaces required for the example
* `vllm`: Used to deploy the vLLM instance with the Granite model
* `tests`: An example notebook that can be used to connect to the vLLM instance

## Quick Start

### 1. Deploy Using Bootstrap Script

From the repository root:
```bash
./scripts/bootstrap.sh
```
1. Select `vllm-modelcar-serverless` from the examples list
2. Choose your desired overlay (default will be automatically selected if that is the only option)

## Troubleshooting


## Cleanup

To remove the deployment:

```bash
# Remove ArgoCD application
oc delete -k examples/vllm-modelcar-serverless/argocd/overlays/default -n openshift-gitops
```

