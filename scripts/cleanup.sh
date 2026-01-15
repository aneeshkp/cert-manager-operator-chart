#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CHART_DIR="$(dirname "$SCRIPT_DIR")"

echo "=== Cleaning up cert-manager operator ==="

# Destroy helmfile release
cd "$CHART_DIR"
helmfile destroy

# Delete CRDs
echo "Deleting cert-manager CRDs..."
kubectl get crd | grep cert-manager | awk '{print $1}' | xargs -r kubectl delete crd

echo "Deleting infrastructure CRD stub..."
kubectl delete crd infrastructures.config.openshift.io --ignore-not-found

echo "=== Cleanup complete ==="
