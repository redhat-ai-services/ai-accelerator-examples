# 3scale Helm Chart for ArgoCD

This repository contains a Helm chart designed for deploying 3scale with ArgoCD.

## Overview

When used with an ArgoCD Application, this Helm chart provides the following functionalities:

1. **Installs the 3scale Operator**: Deploys the Red Hat Integration - 3scale Operator to your OpenShift cluster.
2. **Creates the ApiManager Instance**: Creates the ApiManager instance.
3. **Creates a custom policy**: Creates a custom policy for the 3scale.

## Usage

To use this Helm chart with ArgoCD, you can refer to the [application-3scale.yaml](application-3scale.yaml) file provided in this repository.

## Prerequisites

- **ArgoCD**: Make sure you have ArgoCD installed and configured in your OpenShift cluster.
