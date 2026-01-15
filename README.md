# cert-manager Operator Helm Chart

Deploy Red Hat cert-manager Operator on any Kubernetes cluster without OLM.

## Overview

This chart uses **olm-extractor** to extract manifests directly from Red Hat's OLM bundle, enabling deployment on non-OLM Kubernetes clusters (AKS, CoreWeave) while:

- **Minimizing OCP team burden** - Uses exact manifests from Red Hat's OLM bundles
- **Easy upgrades** - Single command: `./scripts/update-bundle.sh <version>`
- **Incremental consolidation** - Helm templating can be added gradually
- **No breaking changes** - Only minimal patches for non-OLM environments

## Prerequisites

- `kubectl` configured for your cluster
- `helmfile` installed
- `podman login registry.redhat.io` (for Red Hat registry auth)

## Quick Start

```bash
cd cert-manager-operator-chart

# 1. Login to Red Hat registry
podman login registry.redhat.io

# 2. Deploy
helmfile apply
```

## Configuration

Edit `environments/default.yaml`. Choose ONE auth method:

### Option A: System Podman Auth (Recommended)

```yaml
# environments/default.yaml
useSystemPodmanAuth: true
```

### Option B: Pull Secret File

```yaml
# environments/default.yaml
pullSecretFile: ~/pull-secret.txt
```

## What Gets Deployed

**Presync hooks (before Helm install):**
1. cert-manager CRDs + Infrastructure CRD stub - applied with `--server-side`
2. Infrastructure CR (required for non-OpenShift clusters)
3. Operand namespace (`cert-manager`)
4. CertManager CR (`cluster`)

**Helm install:**
5. Operator namespace (`cert-manager-operator`)
6. Pull secrets (in both namespaces)
7. cert-manager ServiceAccounts with `imagePullSecrets` (cert-manager, cert-manager-cainjector, cert-manager-webhook)
8. cert-manager Operator deployment + RBAC

**Post-install (automatic):**
9. Operator deploys cert-manager components (controller, webhook, cainjector)
10. Operator reconciles ServiceAccounts (adds labels, preserves `imagePullSecrets`)

## Version Compatibility

| Component | Version |
|-----------|---------|
| cert-manager Operator | v1.15.2 |
| cert-manager | v1.15.x |

## Verify Installation

```bash
# Check operator
kubectl get pods -n cert-manager-operator

# Check cert-manager components
kubectl get pods -n cert-manager

# Check CertManager CR
kubectl get certmanager cluster -o yaml
```

## Create an Issuer

```bash
# Self-signed ClusterIssuer
kubectl apply -f - <<EOF
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: selfsigned-issuer
spec:
  selfSigned: {}
EOF
```

## Uninstall

```bash
./scripts/cleanup.sh
```

## Update to New Bundle Version

```bash
./scripts/update-bundle.sh v1.18.0
helmfile apply
```

The update-bundle.sh script:
- Extracts manifests from Red Hat's OLM bundle (deployment, RBAC, CRDs)
- Applies minimal fixes for non-OLM environments
- Preserves OpenShift API stub CRDs

## Update Pull Secret

Red Hat pull secrets expire (typically yearly). To update:

```bash
# Option A: Using system podman auth (after re-login)
podman login registry.redhat.io
./scripts/update-pull-secret.sh

# Option B: Using pull secret file
./scripts/update-pull-secret.sh ~/new-pull-secret.txt

# Restart pods to use new secret
kubectl rollout restart deployment -n cert-manager --all
```

## Non-OpenShift Compatibility

This chart includes workarounds for running the Red Hat operator outside OpenShift:

1. **Infrastructure CRD/CR stub** - The operator requires `infrastructures.config.openshift.io` API
2. **CertManager CR pre-creation** - Created in presync to avoid race conditions
3. **OLM pattern replacement** - `olm.targetNamespaces` handled via olm-extractor's `--watch-namespace=""` flag
4. **Pre-created ServiceAccounts with imagePullSecrets** - On non-OpenShift clusters (AKS, GKE, etc.), there's no global pull secret mechanism. The chart pre-creates cert-manager ServiceAccounts with `imagePullSecrets` configured. The operator preserves these when it reconciles.

## File Structure

```
cert-manager-operator-chart/
├── Chart.yaml
├── values.yaml                  # Default values
├── helmfile.yaml.gotmpl         # Deploy with: helmfile apply
├── .helmignore
├── environments/
│   └── default.yaml             # User config
├── manifests-crds/              # cert-manager CRDs + Infrastructure stub
├── templates/
│   ├── deployment-*.yaml                  # Operator deployment
│   ├── pull-secret.yaml                   # Registry pull secrets
│   ├── serviceaccounts-cert-manager.yaml  # Operand SAs with imagePullSecrets
│   └── *.yaml                             # RBAC, ServiceAccount, etc.
└── scripts/
    ├── cleanup.sh               # Uninstall and delete CRDs
    ├── update-bundle.sh         # Update to new bundle version
    ├── update-pull-secret.sh    # Update expired pull secret
    └── post-install-message.sh  # Post-install instructions
```
