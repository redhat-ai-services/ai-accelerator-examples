# vLLM ModelCar Multinode Example

This example demonstrates how to deploy and serve the Qwen2.5 7B Instruct model using vLLM in a multinode configuration on OpenShift AI using KServe.

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

This example requires multiple GPU nodes to support the multinode topology. The configuration uses:
* Pipeline Parallel Size: 2
* Tensor Parallel Size: 1

## Overview

This example contains the following components:

* `namespaces`: Used to configure the namespaces required for the example
* `vllm`: Used to deploy the vLLM instance with the Qwen2.5 7B model in multinode configuration
* `tests`: An example notebook that can be used to connect to the vLLM instance

## Configuration

### Model Configuration
- **Model**: Qwen2.5 7B Instruct from Red Hat AI Services ModelCar Catalog
- **Deployment Mode**: RawDeployment (non-serverless)
- **Serving Topology**: Multinode with pipeline parallelism
- **Pipeline Parallel Size**: 2
- **Tensor Parallel Size**: 1

### Namespace
The deployment creates a dedicated namespace `vllm-multinode-modelcar`.

## Quick Start

### 1. Deploy Using Bootstrap Script

From the repository root:
```bash
./scripts/bootstrap.sh
```
1. Select `vllm-multinode-modelcar` from the examples list
2. Choose your desired overlay (default will be automatically selected if that is the only option)

## Troubleshooting


## Cleanup

To remove the deployment:

```bash
# Remove ArgoCD application
helm uninstall vllm-multinode-modelcar -n openshift-gitops
```

## Additional Resources

- [vLLM Multinode Documentation](https://docs.vllm.ai/en/latest/serving/distributed_serving.html)
- [KServe Documentation](https://kserve.github.io/website/)
- [Qwen2.5 Model Information](https://huggingface.co/Qwen/Qwen2.5-7B)
