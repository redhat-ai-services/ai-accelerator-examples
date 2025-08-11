# AI Accelerator Examples

A comprehensive collection of ready-to-deploy AI/ML examples for OpenShift AI using GitOps and modern cloud-native technologies. These examples demonstrate best practices for deploying and serving AI models on OpenShift using KServe, vLLM, Kubeflow Pipelines, and other AI acceleration tools.

These examples are designed to work directly with the Red Hat AI Services [AI Accelerator](https://github.com/redhat-ai-services/ai-accelerator) repo for configuring an OpenShift AI cluster.

## 🚀 Quick Start

Deploy any example with a single command:

```bash
./bootstrap.sh
```

This interactive script will:
1. ✅ Check your OpenShift login status
2. 📋 Show available examples
3. 🎯 Guide you through deployment options
4. 🚀 Deploy the selected example using ArgoCD

## 🎯 Available Examples

- **vLLM ModelCar Serverless** (`examples/vllm-modelcar-serverless/`) - Deploy Granite 3.3 2B Instruct model using vLLM in serverless configuration
- **vLLM ModelCar Multinode** (`examples/vllm-multinode-modelcar/`) - Deploy Qwen2.5 7B Instruct model using vLLM with multinode pipeline parallelism
- **Kubeflow Pipelines with Tekton** (`examples/kfp-pipeline-example/`) - End-to-end ML pipeline with data ingestion, training, and deployment

## 🏗️ Project Structure

```
ai-accelerator-examples/
├── bootstrap.sh              # Quick deployment entry point
├── scripts/
│   ├── bootstrap.sh          # Main deployment script
│   ├── functions.sh          # Utility functions
│   └── validate_manifests.sh # Manifest validation
├── charts/
│   └── argocd-appgenerator/  # Helm chart for ArgoCD ApplicationSet generation
│       ├── Chart.yaml        # Chart metadata
│       ├── values.yaml       # Default configuration
│       ├── templates/        # Kubernetes resource templates
│       └── README.md         # Chart-specific documentation
├── examples/
│   └── <examples>
└── README.md                # This file
```

## 📋 Prerequisites

Each example contains a list of specific prerequisites for that component that will help to define what features of RHOAI or other Operators are required to utilize that example.

Most of the prerequisites should be fulfilled by the Red Hat AI Services [AI Accelerator](https://github.com/redhat-ai-services/ai-accelerator) repo for configuring an OpenShift AI cluster.

### Access Requirements
- OpenShift cluster admin privileges
- Logged into OpenShift: `oc login --server=<cluster-url> --token=<token>`

## 🛠️ Deployment Methods

### 1. Interactive Bootstrap (Recommended)
```bash
./bootstrap.sh
```
- Automatically detects your environment
- Prompts for repository URL configuration
- Lists available examples
- Handles deployment complexity

### 2. Manual Kustomize Deployment
```bash
# Navigate to desired example
cd examples/<example-name>

# Deploy namespace
oc apply -k namespaces/overlays/default

# Deploy application components
oc apply -k <component>/overlays/default
```

### 3. ArgoCD GitOps Deployment
```bash
# Using the ArgoCD app generator Helm chart
helm install ai-examples ./charts/argocd-appgenerator -n openshift-gitops \
  --set git.repoURL=https://github.com/your-org/your-fork.git \
  --set git.revision=main \
  --set git.directories[0].path=examples/*/overlays/default
```

## 🧪 Testing and Validation

### Run All Validations
```bash
# Validate Kustomize manifests and Helm charts
./scripts/validate_manifests.sh

# Install Python dependencies for linting
pip install -r requirements.txt

# Run YAML linting
yamllint .

# Run spell checking
pyspelling
```

## 🤝 Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for detailed guidelines on adding new examples, testing, and submitting contributions.

## 📚 Additional Resources

### Documentation
- [OpenShift AI Documentation](https://docs.redhat.com/en/documentation/red_hat_openshift_ai_self-managed)
- [KServe Documentation](https://kserve.github.io/website/)
- [vLLM Documentation](https://docs.vllm.ai/)
- [Kubeflow Pipelines Documentation](https://www.kubeflow.org/docs/components/pipelines/)
- [ArgoCD Documentation](https://argo-cd.readthedocs.io/)

### Additional Repos
- [Red Hat AI Services on GitHub](https://github.com/redhat-ai-services)
- [Red Hat AI Services ModelCar Catalog](https://github.com/redhat-ai-services/modelcar-catalog/)
- [Red Hat AI Services Helm Charts](https://github.com/redhat-ai-services/helm-charts/)
- [Red hat AI Services AI Accelerator](https://github.com/redhat-ai-services/ai-accelerator)

## 🏷️ Tags

`#OpenShift` `#AI` `#MachineLearning` `#KServe` `#vLLM` `#Kubeflow` `#GitOps` `#ArgoCD` `#Tekton` `#ModelServing` `#MLOps`
