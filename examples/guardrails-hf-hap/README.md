# Guardrails Hugging Face HAP Example

This example demonstrates how to deploy and serve a chat model with guardrails using Hugging Face's Harm and Abuse Prevention (HAP) detector model for content moderation on OpenShift AI.

This example uses the following Helm charts:
https://github.com/redhat-ai-services/helm-charts/tree/main/charts/vllm-kserve
https://github.com/redhat-ai-services/helm-charts/tree/main/charts/guardrails-hf-detector-kserve

This example also uses modelcars from the Red Hat Services ModelCar Catalog:
https://github.com/redhat-ai-services/modelcar-catalog/

## Dependencies

This example requires a cluster with the following components:
* OpenShift AI
  * KServe (RawDeployment)
  * TrustyAI
* NVIDIA GPU Operator
* Node Feature Discovery

This example also requires that two GPUs such as an A10G be available in the cluster.

## Overview

This example contains the following components:

* `namespaces`: Used to configure the namespaces required for the example
* `vllm-chat-model`: Used to deploy the main chat model instance
* `hf-detector-guardian-model`: Used to deploy the Hugging Face HAP detector model for content moderation
* `guardrails`: Used to configure the guardrails policies and routing
* `tests`: Example notebooks that can be used to test the guardrails functionality

## Quick Start

### 1. Deploy Using Bootstrap Script

From the repository root:
```bash
./scripts/bootstrap.sh
```
1. Select `guardrails-hf-hap` from the examples list
2. Choose your desired overlay (default will be automatically selected if that is the only option)

## Troubleshooting


## Cleanup

To remove the deployment:

```bash
# Remove ArgoCD application
helm uninstall guardrails-hf-hap -n openshift-gitops
```

