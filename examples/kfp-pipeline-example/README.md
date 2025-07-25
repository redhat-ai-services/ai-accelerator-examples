# KFP Pipeline Example

Todo

## Dependencies

This example requires a cluster with the following components:
* OpenShift AI
  * DataSciencePipelines
* OpenShift Pipelines

## Overview

This example contains the following components:

* `argocd`: Used to configure the components using ArgoCD
* `namespaces`: Used to configure the namespaces required for the example
* `dspa`: Used to deploy the Data Science Pipeline Application instance
* todo

## Quick Start

### 1. Deploy Using Bootstrap Script

From the repository root:
```bash
./scripts/bootstrap.sh
```
1. Select `kfp-pipeline-example` from the examples list
2. Choose your desired overlay (default will be automatically selected if that is the only option)

## Troubleshooting


## Cleanup

To remove the deployment:

```bash
# Remove ArgoCD application
oc delete -k examples/kfp-pipeline-example/argocd/overlays/default -n openshift-gitops
```
