# ArgoCD Application Generator

A Helm chart for generating ArgoCD ApplicationSets and Projects for AI accelerator examples on OpenShift.

## Description

This chart creates ArgoCD ApplicationSet and Project resources that automatically discover and deploy AI/ML examples from a Git repository. It's specifically designed for managing multiple AI accelerator examples in a GitOps workflow.

## Prerequisites

- Kubernetes 1.24+
- ArgoCD operator installed
- Helm 3.8+

## Installing the Chart

To install the chart with the release name `ai-examples`:

```bash
helm install ai-examples ./charts/argocd-appgenerator
```

To install with custom values:

```bash
helm install ai-examples ./charts/argocd-appgenerator -f my-values.yaml
```

## Uninstalling the Chart

To uninstall/delete the `ai-examples` deployment:

```bash
helm uninstall ai-examples
```

## Configuration

The following table lists the configurable parameters and their default values.

### Git Configuration

| Parameter | Description | Default |
|-----------|-------------|---------|
| `git.repoURL` | Git repository URL containing examples | `"https://github.com/redhat-ai-services/ai-accelerator-examples.git"` |
| `git.revision` | Git revision/branch to track | `main` |
| `git.directories` | List of directory paths to scan | See values.yaml |

### ApplicationSet Configuration

| Parameter | Description | Default |
|-----------|-------------|---------|
| `applicationSet.annotations` | Additional annotations for ApplicationSet | `{}` |
| `applicationSet.labels` | Additional labels for generated applications | `{}` |
| `applicationSet.syncPolicy.automated.prune` | Enable automated pruning | `false` |
| `applicationSet.syncPolicy.automated.selfHeal` | Enable self-healing | `true` |
| `applicationSet.syncPolicy.retry.limit` | Maximum retry attempts | `5` |
| `applicationSet.syncPolicy.retry.backoff.duration` | Initial retry delay | `30s` |
| `applicationSet.syncPolicy.retry.backoff.factor` | Backoff factor | `2` |
| `applicationSet.syncPolicy.retry.backoff.maxDuration` | Maximum retry delay | `20m` |

### Project Configuration

| Parameter | Description | Default |
|-----------|-------------|---------|
| `project.annotations` | Additional annotations for Project | `{}` |
| `project.clusterResourceWhitelist` | Allowed cluster resources | `[{group: '*', kind: '*'}]` |
| `project.destinations` | Allowed destinations | `[{namespace: '*', server: '*'}]` |
| `project.sourceRepos` | Additional source repositories | `[]` |

### Destination Configuration

| Parameter | Description | Default |
|-----------|-------------|---------|
| `destination.server` | Target cluster server URL | `https://kubernetes.default.svc` |
| `destination.namespace` | Target namespace | `""` |

### Template Configuration

| Parameter | Description | Default |
|-----------|-------------|---------|
| `template.annotations` | Additional annotations for generated apps | See values.yaml |
| `template.labels` | Additional labels for generated apps | `{}` |

## Examples

### Basic Installation

```bash
helm install ai-examples ./charts/argocd-appgenerator
```

### Custom Git Repository

```yaml
# values.yaml
git:
  repoURL: "https://github.com/my-org/my-ai-examples.git"
  revision: "main"
  directories:
    - path: examples/*/overlays/production
```

```bash
helm install ai-examples ./charts/argocd-appgenerator -f values.yaml
```

### Multiple Environments

```yaml
# values.yaml
git:
  directories:
    - path: examples/*/overlays/staging
    - path: examples/*/overlays/production

applicationSet:
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
```

### Restricted Permissions

```yaml
# values.yaml
project:
  clusterResourceWhitelist:
    - group: ''
      kind: 'ConfigMap'
    - group: ''
      kind: 'Secret'
    - group: 'apps'
      kind: 'Deployment'
  
  destinations:
    - namespace: 'ai-*'
      server: 'https://kubernetes.default.svc'
  
  roles:
    - name: developer
      description: Developer access to AI examples
      policies:
        - "p, proj:ai-examples:developer, applications, *, ai-examples/*, allow"
      groups:
        - "ai-developers"
```

## Testing

Run the chart tests:

```bash
helm test ai-examples
```

## Troubleshooting

### Common Issues

1. **ApplicationSet not generating applications**
   - Check if the directory paths in `git.directories` exist
   - Verify the Git repository is accessible
   - Check ArgoCD logs: `kubectl logs -n openshift-gitops deployment/openshift-gitops-applicationset-controller`

2. **Applications failing to sync**
   - Verify the target cluster has sufficient permissions
   - Check if the destination namespace exists
   - Review application sync status: `kubectl get applications -n openshift-gitops`

3. **Project permissions denied**
   - Review the `project.clusterResourceWhitelist` and `project.destinations`
   - Ensure the ArgoCD service account has necessary cluster permissions

### Debug Commands

```bash
# Check ApplicationSet status
kubectl get applicationset -n openshift-gitops

# Check generated applications
kubectl get applications -l example=<release-name> -n openshift-gitops

# View ApplicationSet details
kubectl describe applicationset <release-name> -n openshift-gitops

# Check Project permissions
kubectl describe appproject <release-name> -n openshift-gitops
```

## Development

### Testing Locally

```bash
# Lint the chart
helm lint ./charts/argocd-appgenerator

# Generate templates for review
helm template ai-examples ./charts/argocd-appgenerator

# Test with specific values
helm template ai-examples ./charts/argocd-appgenerator -f test-values.yaml
```

### Contributing

1. Follow [Helm best practices](https://helm.sh/docs/chart_best_practices/)
2. Update this README when adding new configuration options
3. Add tests for new functionality
4. Use semantic versioning for chart releases
