#!/bin/bash
# deploy-gateway-multicluster.sh
# Demo script for the k3d-multicluster-playground GitHub repository
# Deploys a two cluster pod-to-pod multi-cluster setup
# https://github.com/southsidedean/linkerd-demos/tree/main/k3d-multicluster-playground
# Automates multi-cluster deployment
# Tom Dean | Buoyant
# Last edit: 1/17/2025

# Let's set some variables!

# BEL: Stable
BEL_VERSION=enterprise-2.15.7
CLI_VERSION=install
MC_VERSION=enterprise

# BEL: Preview
#BEL_VERSION=preview-24.10.4
#CLI_VERSION=install-preview
#MC_VERSION=preview

# API Addresses
CLUSTER_WAREHOUSE_API=`echo "https://$(kubectl --context warehouse get node k3d-warehouse-server-0 -o jsonpath='{.status.addresses[?(.type=="InternalIP")].address}'):6443"`
CLUSTER_ORDERS_API=`echo "https://$(kubectl --context orders get node k3d-orders-server-0 -o jsonpath='{.status.addresses[?(.type=="InternalIP")].address}'):6443"`

# Step 1: Add a Hosts Entry to CoreDNS

kubectl get cm coredns -n kube-system -o yaml --context orders -o yaml | grep -Ev "creationTimestamp|resourceVersion|uid" > coredns.yaml
sed -i .orig 's/host.k3d.internal/host.k3d.internal\ kubernetes/g' coredns.yaml
cat coredns.yaml
kubectl apply -f coredns.yaml -n kube-system --context orders
kubectl rollout restart deploy coredns -n kube-system --context orders
kubectl get cm coredns -n kube-system -o yaml --context orders -o yaml

# Step 2: Install the Multi-Cluster Extension

source settings.sh

#helm repo add linkerd-buoyant https://helm.buoyant.cloud
#helm repo update

#helm install linkerd-multicluster \
#  --create-namespace \
#  --namespace linkerd-multicluster \
#  --kube-context orders \
#  --set linkerd-multicluster.gateway.enabled=true \
#  --set license=$BUOYANT_LICENSE \
#  linkerd-buoyant/linkerd-$MC_VERSION-multicluster

#helm install linkerd-multicluster \
#  --create-namespace \
#  --namespace linkerd-multicluster \
#  --kube-context warehouse \
#  --set linkerd-multicluster.gateway.enabled=true \
#  --set license=$BUOYANT_LICENSE \
#  linkerd-buoyant/linkerd-$MC_VERSION-multicluster

linkerd multicluster install --context orders | kubectl apply --context orders -f -
linkerd multicluster install --context warehouse | kubectl apply --context warehouse -f -

linkerd --context=orders multicluster check
linkerd --context=warehouse multicluster check

kubectl apply -f policy.yaml --context orders

# Step 3: Link the Clusters

sleep 30
rm multicluster-*.yaml

#linkerd --context=warehouse multicluster link --cluster-name warehouse --gateway=true --api-addr $CLUSTER_WAREHOUSE_API > multicluster-link.yaml

linkerd --context=warehouse multicluster link --cluster-name warehouse --gateway=true --api-addr $CLUSTER_WAREHOUSE_API > multicluster-link-orig.yaml
KC1=`linkerd --context=warehouse multicluster link --cluster-name warehouse --gateway=true --api-addr $CLUSTER_WAREHOUSE_API | grep kubeconfig: | uniq | awk {'print $2'}` ; KC2=`echo $KC1 | base64 -d | sed 's/0\.0\.0\.0/kubernetes/g' | base64` ; awk -f mc.awk "$KC1" "$KC2" multicluster-link-orig.yaml > multicluster-link.yaml

kubectl apply -f multicluster-link.yaml --context orders
kubectl get links -A --context=orders

# Step 4: Export the 'fulfillment' Service to the 'orders' Cluster

kubectl get svc -A --context=orders
kubectl get svc -A --context=warehouse
kubectl --context=warehouse label svc -n orders fulfillment mirror.linkerd.io/exported=true
sleep 30
kubectl get svc -A --context=orders

# Step 5: Add multi-cluster policy
# The Linkerd multi-cluster extension includes a policy configuration that prevents unauthorized access to pods running in the linkerd-multicluster namespace. This policy configuration only grants access to the core Linkerd control plane by default. If you’re using the Linkerd multi-cluster extension with Buoyant Cloud, you’ll need to add the following configuration to the linkerd-multicluster namespace.:w

cat <<EOF > multicluster-policy.yaml
---
apiVersion: policy.linkerd.io/v1beta1
kind: ServerAuthorization
metadata:
  namespace: linkerd-multicluster
  name: service-mirror-buoyant-cloud
  labels:
    app.kubernetes.io/part-of: linkerd-buoyant
spec:
  server:
    name: service-mirror
  client:
    meshTLS:
      serviceAccounts:
        - name: buoyant-cloud-agent
          namespace: linkerd-buoyant
EOF

kubectl apply -f multicluster-policy.yaml --context orders
kubectl apply -f multicluster-policy.yaml --context warehouse

exit 0
