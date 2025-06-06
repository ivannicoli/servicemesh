#!/bin/bash

# Exit on error
set -e

echo "===== Service Mesh Demo Deployment ====="
echo "Building and deploying applications to Minikube with Istio"

# Ensure we're using the Minikube Docker daemon
echo "Configuring Docker to use Minikube daemon..."
eval $(minikube docker-env)

# Build app1
echo "Building app1 Docker image..."
cd "$(dirname "$0")/app1"
docker build -t app1:latest .

# Build app2
echo "Building app2 Docker image..."
cd "$(dirname "$0")/app2"
docker build -t app2:latest .

# Return to the main directory
cd "$(dirname "$0")"

# Apply Kubernetes manifests
echo "Applying Kubernetes manifests..."
kubectl apply -f kubernetes/app1-deployment.yaml
kubectl apply -f kubernetes/app2-deployment.yaml

# Apply Istio configurations
echo "Applying Istio configurations..."
kubectl apply -f istio/gateway.yaml

# Wait for deployments to be ready
echo "Waiting for deployments to be ready..."
kubectl wait --for=condition=available --timeout=300s deployment/app1 -n servicemesh-demo
kubectl wait --for=condition=available --timeout=300s deployment/app2 -n servicemesh-demo

# Get the Istio ingress gateway URL
INGRESS_HOST=$(minikube ip)
INGRESS_PORT=$(kubectl -n istio-system get service istio-ingressgateway -o jsonpath='{.spec.ports[?(@.name=="http2")].nodePort}')
GATEWAY_URL=$INGRESS_HOST:$INGRESS_PORT

echo ""
echo "===== Deployment Complete ====="
echo "Your applications are now deployed and accessible via the Istio Ingress Gateway"
echo ""
echo "Access app1 at: http://$GATEWAY_URL/app1"
echo "Access app2 at: http://$GATEWAY_URL/app2"
echo ""
echo "App2 will call app1 using Kubernetes service discovery"
echo ""
echo "To view the Kiali dashboard (Istio service mesh visualization):"
echo "istioctl dashboard kiali"
echo ""
echo "To view the Jaeger dashboard (distributed tracing):"
echo "istioctl dashboard jaeger"
echo ""
echo "To view the Grafana dashboard (metrics visualization):"
echo "istioctl dashboard grafana"
echo ""
