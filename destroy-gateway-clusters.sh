#!/bin/bash
# destroy-gateway-clusters.sh
# Demo script for the k3d-multicluster-playground GitHub repository
# https://github.com/southsidedean/linkerd-demos/tree/main/k3d-multicluster-playground
# Automates cluster deletion and cleans up the kubectl contexts
# Tom Dean | Buoyant
# Last edit: 1/17/2025

# Remove the k3d clusters

k3d cluster delete orders warehouse
k3d cluster list

# Remove the kubectl contexts: hazl

kubectx -d orders
kubectx -d warehouse
kubectx

exit 0
