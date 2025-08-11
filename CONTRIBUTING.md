# Contributing to AI Accelerator Examples

We welcome contributions! This guide will help you contribute effectively to the AI Accelerator Examples project.

## 🎯 Types of Contributions

- **New AI/ML Examples**: Add new deployment examples for different models or frameworks
- **Documentation**: Improve README files, add tutorials, or enhance existing docs
- **Bug Fixes**: Fix issues in existing examples or scripts
- **Improvements**: Enhance bootstrap scripts, validation tools, or deployment processes

## 🚀 Getting Started

### Prerequisites

Before contributing, ensure you have:
- Access to an OpenShift cluster with OpenShift AI installed
- Required tools: `oc`, `git`, `helm`
- Familiarity with Kubernetes, Kustomize, Hel, and GitOps concepts

### Development Setup

1. **Fork the repository**
   ```bash
   # Fork on GitHub, then clone your fork
   git clone https://github.com/YOUR-USERNAME/ai-accelerator-examples.git
   cd ai-accelerator-examples
   ```

2. **Create a feature branch**
   ```bash
   git checkout -b feature/my-new-example
   # or
   git checkout -b fix/bootstrap-script-issue
   ```

3. **Test your environment**
   ```bash
   # Verify OpenShift login
   oc whoami
   
   # Test the bootstrap script
   ./bootstrap.sh
   ```

## 📁 Adding New Examples

Each example should be fully self contained and not rely on other examples.  

### Standard Structure

#### Required Components:
- **`namespaces/`**: Kubernetes namespace definitions
- **`<component>/`**: Main application configurations (e.g., vllm/, dspa/, model-serving/)
- **`tests/`**: Testing scripts and notebooks
- **`README.md`**: Comprehensive example documentation

#### Example Structure:

Examples are required to adhere to the following structure.  Each example should contain a logical grouping of components that contain `base` and `overlays` folders.  The `overlays` folder should contain a folder called `default` if the example only has a single configuration.  If the examples required different configuration options for different versions of RHOAI or other components, it can contain multiple overlays.

```
examples/my-new-example/
├── namespaces/
│   ├── base/
│   │   ├── kustomization.yaml
│   │   └── namespace.yaml
│   └── overlays/
│       └── default/
│           └── kustomization.yaml
├── my-component/
│   ├── base/
│   │   ├── kustomization.yaml
│   │   └── deployment.yaml
│   └── overlays/
│       └── default/
│           └── kustomization.yaml
├── tests/
│   └── test-notebook.ipynb
└── README.md
```

Each component overlays folder will be deployed using ArgoCD from the bootstrap script.

### Use Kustomize Best Practices

- **Organize with `base/` and `overlays/`**: Separate base configurations from environment-specific customizations or configurations for specific RHOAI/OCP versions
- **Follow naming conventions**: Use consistent resource naming
- **Include proper labels**: Add standard Kubernetes labels

#### Example base/kustomization.yaml:
```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

namespace: my-example

resources:
  - deployment.yaml
  - service.yaml
```

### Create Comprehensive Documentation

Your `README.md` should include:

```markdown
# My New Example

Brief description of what this example demonstrates.

## Overview
- What technology/model/framework is used
- Key features and capabilities
- Prerequisites specific to this example

Prerequisites should include a list of what expected items should be configured before deploying the example.  These items should include enough details that if a user attempts to deploy the example without the [AI Accelerator](https://github.com/redhat-ai-services/ai-accelerator) they understand what will need to be configured for the example to function.

## Quick Start
- Bootstrap script usage
- Manual deployment steps

## Configuration
- Key configuration options
- Customization guidelines

## Testing
- How to test the deployment
- Example commands or notebooks

## Troubleshooting
- Common issues and solutions

## Cleanup
- How to remove the deployment
```

### Add Testing

Include appropriate testing for your example:

#### Jupyter Notebooks:
```python
# Example test cell
import requests

# Test model endpoint
response = requests.get(f"{endpoint}/v1/models")
assert response.status_code == 200
print("Model serving endpoint is accessible!")
```

### Test with Bootstrap Script

Ensure your example works with the bootstrap script:

```bash
./bootstrap.sh
# Verify your example appears in the selection
# Test deployment and cleanup
```

## 🧪 Testing and Validation

### Run All Validations

Before submitting your contribution:

```bash
# Validate Kustomize manifests
./scripts/validate_manifests.sh

# Install Python dependencies for linting
pip install -r requirements.txt

# Run YAML linting
yamllint .

# Run spell checking
pyspelling
```

### Test on Real Cluster

- Deploy your example on an actual OpenShift AI cluster
- Verify all components start successfully
- Test the functionality end-to-end
- Ensure cleanup works properly

## 📋 Contribution Guidelines

### Code Standards
- **Follow existing conventions**: Maintain consistency with existing examples
- **Use meaningful names**: Resources, files, and directories should be clearly named
- **Include proper metadata**: Add labels, annotations, and documentation
- **Support GitOps**: Ensure examples work with ArgoCD deployment

### Documentation Standards
- **Write clear README files**: Include all necessary information for users
- **Use consistent formatting**: Follow markdown best practices
- **Include examples**: Provide command examples and expected outputs
- **Add troubleshooting**: Document common issues and solutions

### Testing Standards
- **Test on real clusters**: Validate on actual OpenShift AI environments
- **Include test artifacts**: Add notebooks, scripts, or commands for testing
- **Document test procedures**: Explain how to verify the example works
- **Test cleanup procedures**: Ensure removal instructions work correctly

### Git Standards
- **Write descriptive commit messages**: Explain what and why, not just what
- **Keep commits focused**: One logical change per commit
- **Update documentation**: Include doc updates in the same PR as code changes
- **Test before committing**: Ensure validation passes before pushing

## 🛠️ Development Tools

### Useful Commands

```bash
# Quick validation of specific example
./scripts/validate_manifests.sh -d examples/my-example

# Test Kustomize build
kustomize examples/my-example/component/overlays/default --enable-helm

# Validate YAML syntax
yamllint examples/my-example/

# Check for common issues
helm lint charts/argocd-appgenerator/
```

## 📞 Getting Help

### Resources
- **GitHub Issues**: Report bugs or request features
- **Discussions**: Ask questions or discuss ideas
- **Documentation**: Check existing docs and examples

### Community
- Follow existing examples as templates
- Ask questions in GitHub Discussions
- Join community Slack channels (if available)
- Participate in community meetings

## 📝 License

By contributing to this project, you agree that your contributions will be licensed under the [Apache License 2.0](LICENSE).

---

Thank you for contributing to AI Accelerator Examples! Your contributions help make AI deployment on OpenShift easier for everyone. 🚀
