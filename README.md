# AI Accelerator Examples

A collection of ready-to-deploy AI/ML examples for OpenShift AI using GitOps and modern cloud-native technologies. These examples demonstrate best practices for deploying and serving AI models on OpenShift using KServe, vLLM, and other AI acceleration tools.

## 🚀 Quick Start

Deploy any example with a single command:

```bash
./bootstrap.sh
```

This interactive script will:
1. Check your OpenShift login status
2. Show available examples
3. Guide you through deployment options
4. Deploy the selected example using ArgoCD

## 📋 Prerequisites

### Required Tools
- **OpenShift CLI** (`oc`) - For cluster interaction
- **Git** - For cloning this repository
- **Kustomize** - Integrated with `oc` for manifest management

### Required OpenShift Components
Your OpenShift cluster must have:
- **OpenShift AI (RHOAI)** with KServe
- **OpenShift Serverless** (Knative)
- **OpenShift Service Mesh** (Istio)
- **ArgoCD Operator** (OpenShift GitOps)
- **NVIDIA GPU Operator** (for GPU-accelerated examples)
- **Node Feature Discovery** (for hardware detection)

### Hardware Requirements
- **GPU nodes** with NVIDIA A10G or equivalent (for model serving examples)
- Sufficient cluster resources for model deployment

### Access Requirements
- OpenShift cluster admin privileges
- Logged into OpenShift: `oc login --server=<cluster-url> --token=<token>`

## 📁 Available Examples

### vLLM ModelCar Serverless
**Path**: `examples/vllm-modelcar-serverless/`

Deploy and serve the Granite 3.3 2B Instruct model using vLLM in a serverless configuration.

**Features**:
- **Model**: Granite 3.3 2B Instruct from Red Hat AI Services ModelCar Catalog
- **Serving**: vLLM for high-performance inference
- **Architecture**: KServe serverless deployment
- **API**: OpenAI-compatible REST endpoints
- **Testing**: Jupyter notebook included

**Quick Deploy**:
```bash
./bootstrap.sh
# Select: vllm-modelcar-serverless
```

[📖 Full Documentation](examples/vllm-modelcar-serverless/README.md)

## 🏗️ Project Structure

```
ai-accelerator-examples/
├── bootstrap.sh              # Quick deployment entry point
├── scripts/
│   ├── bootstrap.sh          # Main deployment script
│   ├── functions.sh          # Utility functions
│   └── validate_manifests.sh # Manifest validation
├── examples/
│   └── vllm-modelcar-serverless/
│       ├── argocd/           # GitOps configurations
│       ├── namespaces/       # Kubernetes namespaces
│       ├── vllm/             # vLLM serving configurations
│       ├── tests/            # Testing notebooks and scripts
│       └── README.md         # Example-specific documentation
├── requirements.txt          # Python linting dependencies
└── README.md                # This file
```

## 🛠️ Manual Deployment

If you prefer manual deployment over the bootstrap script:

### 1. Choose an Example
```bash
cd examples/<example-name>
```

### 2. Deploy Namespace
```bash
oc apply -k namespaces/overlays/default
```

### 3. Deploy with ArgoCD
```bash
oc apply -k argocd/overlays/default -n openshift-gitops
```

### 4. Monitor Deployment
```bash
# Check ArgoCD applications
oc get applications -n openshift-gitops

# Check example resources
oc get all -n <example-namespace>
```

## 🔧 Development

### Validation
Run linting and validation before submitting changes:

```bash
# Install Python dependencies
pip install -r requirements.txt

# Validate YAML files
./scripts/validate_manifests.sh

# Run yamllint
yamllint .

# Run spell checking
pyspelling
```

### Adding New Examples

1. **Create Example Directory**:
   ```bash
   mkdir -p examples/my-new-example/{argocd,namespaces,vllm,tests}
   ```

2. **Follow the Structure**:
   - `argocd/`: ArgoCD application configurations
   - `namespaces/`: Kubernetes namespace definitions  
   - `vllm/` (or appropriate service): Model serving configurations
   - `tests/`: Testing scripts and notebooks
   - `README.md`: Example documentation

3. **Use Kustomize**:
   - Organize with `base/` and `overlays/` structure
   - Support multiple deployment environments

4. **Test with Bootstrap**:
   ```bash
   ./bootstrap.sh
   # Verify your example appears in the selection
   ```

## 🔍 Troubleshooting

### Common Issues

**Bootstrap Script Fails**
```bash
# Check OpenShift login
oc whoami

# Verify cluster access
oc cluster-info
```

**ArgoCD Application Not Syncing**
```bash
# Check application status
oc get applications -n openshift-gitops

# View application details
oc describe application <app-name> -n openshift-gitops
```

**Model Serving Issues**
```bash
# Check pods in example namespace
oc get pods -n <example-namespace>

# View pod logs
oc logs <pod-name> -n <example-namespace>

# Check events
oc get events -n <example-namespace> --sort-by='.lastTimestamp'
```

### Debug Commands
```bash
# Test cluster capabilities
oc get nodes -l node.kubernetes.io/instance-type
oc get nodes -l nvidia.com/gpu.present=true

# Check operators
oc get csv -n openshift-operators | grep -E "(gpu|serverless|servicemesh|gitops)"

# Validate prerequisites
oc get knativeserving -n knative-serving
oc get servicemeshcontrolplane -n istio-system
```

## 🧹 Cleanup

### Remove Specific Example
```bash
# Remove ArgoCD application
oc delete -k examples/<example-name>/argocd/overlays/default -n openshift-gitops

# Remove namespace (cleans up all resources)
oc delete namespace <example-namespace>
```

### Remove All Examples
```bash
# List all example applications
oc get applications -n openshift-gitops -l example

# Remove all example applications
oc delete applications -n openshift-gitops -l example
```

## 🤝 Contributing

We welcome contributions! To contribute:

1. **Fork the repository**
2. **Create a feature branch**: `git checkout -b feature/my-new-example`
3. **Follow the project structure** for new examples
4. **Test your changes** with the bootstrap script
5. **Run validation**: `./scripts/validate_manifests.sh`
6. **Submit a pull request**

### Contribution Guidelines
- Follow existing directory and naming conventions
- Include comprehensive README for new examples
- Test on a real OpenShift AI cluster
- Use Kustomize for configuration management
- Support multiple deployment environments via overlays

## 📚 Additional Resources

### Documentation
- [OpenShift AI Documentation](https://docs.redhat.com/en/documentation/red_hat_openshift_ai_self-managed)
- [KServe Documentation](https://kserve.github.io/website/)
- [vLLM Documentation](https://docs.vllm.ai/)
- [ArgoCD Documentation](https://argo-cd.readthedocs.io/)

### Model Catalogs
- [Red Hat AI Services ModelCar Catalog](https://github.com/redhat-ai-services/modelcar-catalog/)
- [Red Hat AI Services Helm Charts](https://github.com/redhat-ai-services/helm-charts/)

### Community
- [Red Hat AI Services on GitHub](https://github.com/redhat-ai-services)
- [OpenShift AI Community](https://www.redhat.com/en/technologies/cloud-computing/openshift/openshift-ai)

## 📄 License

This project is licensed under the [Apache License 2.0](LICENSE).

---

**Ready to accelerate your AI deployments on OpenShift?** Start with `./bootstrap.sh` and explore the examples! 🚀
