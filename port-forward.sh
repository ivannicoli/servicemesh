#!/bin/bash

# Exit on error
set -e

echo "===== Service Mesh Demo Port Forwarding ====="
echo "This script sets up port-forwarding to make the services accessible via localhost"
echo "This is especially useful for macOS users who may have issues with direct cluster IP access"
echo ""

# Check if the namespace exists
if ! kubectl get namespace servicemesh-demo &> /dev/null; then
  echo "Error: The servicemesh-demo namespace does not exist."
  echo "Please deploy the service mesh demo first using ./deploy.sh"
  exit 1
fi

# Check if Istio is installed
if ! kubectl get namespace istio-system &> /dev/null; then
  echo "Error: Istio is not installed."
  echo "Please install Istio first using 'istioctl install --set profile=default -y'"
  exit 1
fi

# Check if the Istio ingress gateway is running
if ! kubectl get -n istio-system deployment/istio-ingressgateway &> /dev/null; then
  echo "Error: Istio ingress gateway is not running."
  echo "Please check your Istio installation."
  exit 1
fi

# Get the original Istio ingress gateway URL (for reference)
INGRESS_HOST=$(minikube ip)
INGRESS_PORT=$(kubectl -n istio-system get service istio-ingressgateway -o jsonpath='{.spec.ports[?(@.name=="http2")].nodePort}')
GATEWAY_URL=$INGRESS_HOST:$INGRESS_PORT

echo "Original Istio Ingress Gateway URL: http://$GATEWAY_URL"
echo ""
echo "Setting up port-forwarding to make services accessible via localhost..."
echo ""
echo "Services will be available at:"
echo "- App1: http://localhost:8080/app1"
echo "- App2: http://localhost:8080/app2"
echo ""
echo "Press Ctrl+C to stop port-forwarding when you're done"
echo ""

# Start port-forwarding
kubectl port-forward -n istio-system svc/istio-ingressgateway 8080:80 &
PORT_FORWARD_PID=$!

# Trap Ctrl+C to clean up the port-forwarding process
trap 'kill $PORT_FORWARD_PID; echo "Port-forwarding stopped."; exit' INT

# Keep the script running to maintain the port-forwarding
echo "Port-forwarding is active. Press Ctrl+C to stop."
while true; do
    sleep 1
done
