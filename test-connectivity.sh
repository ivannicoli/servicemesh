#!/bin/bash

# Exit on error
set -e

echo "===== Service Mesh Demo Connectivity Test ====="
echo "This script tests connectivity to the deployed services"
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

# Get the Istio ingress gateway URL
INGRESS_HOST=$(minikube ip)
INGRESS_PORT=$(kubectl -n istio-system get service istio-ingressgateway -o jsonpath='{.spec.ports[?(@.name=="http2")].nodePort}')
GATEWAY_URL=$INGRESS_HOST:$INGRESS_PORT

echo "Testing connectivity to services..."
echo ""
echo "1. Testing direct pod connectivity:"
echo "-----------------------------------"

# Get pod IPs
APP1_POD=$(kubectl get pod -l app=app1 -n servicemesh-demo -o jsonpath='{.items[0].metadata.name}')
APP2_POD=$(kubectl get pod -l app=app2 -n servicemesh-demo -o jsonpath='{.items[0].metadata.name}')

echo "App1 pod: $APP1_POD"
echo "App2 pod: $APP2_POD"
echo ""

# Test pod-to-pod connectivity
echo "Testing app2 -> app1 connectivity (service discovery):"
kubectl exec -n servicemesh-demo $APP2_POD -c app2 -- curl -s http://app1:8080/ | grep -q "Hello from App1" && 
  echo "✅ Success: App2 can reach App1 via service discovery" || 
  echo "❌ Error: App2 cannot reach App1 via service discovery"

echo ""
echo "2. Testing Istio Ingress Gateway connectivity:"
echo "---------------------------------------------"
echo "Istio Ingress Gateway URL: http://$GATEWAY_URL"
echo ""

# Test direct cluster IP connectivity
echo "Testing direct cluster IP connectivity:"
echo "curl http://$GATEWAY_URL/app1"
curl -s --connect-timeout 5 http://$GATEWAY_URL/app1 > /dev/null && 
  echo "✅ Success: Direct cluster IP connectivity works" || 
  echo "❌ Error: Direct cluster IP connectivity failed"

echo ""
echo "3. Testing localhost port-forwarding:"
echo "-----------------------------------"
echo "Setting up temporary port-forwarding to test localhost connectivity..."

# Start port-forwarding in the background
kubectl port-forward -n istio-system svc/istio-ingressgateway 8888:80 &> /dev/null &
PORT_FORWARD_PID=$!

# Give it a moment to establish
sleep 2

# Test localhost connectivity
echo "Testing localhost connectivity:"
echo "curl http://localhost:8888/app1"
curl -s --connect-timeout 5 http://localhost:8888/app1 > /dev/null && 
  echo "✅ Success: Localhost connectivity works" || 
  echo "❌ Error: Localhost connectivity failed"

# Clean up port-forwarding
kill $PORT_FORWARD_PID &> /dev/null

echo ""
echo "===== Connectivity Test Results ====="
echo ""
echo "If direct cluster IP connectivity failed but localhost connectivity works,"
echo "you should use the port-forward.sh script to access the services:"
echo ""
echo "  ./port-forward.sh"
echo ""
echo "This will make the services accessible at:"
echo "  - http://localhost:8080/app1"
echo "  - http://localhost:8080/app2"
echo ""
