#!/bin/bash

# Exit on error
set -e

# Default values
DASHBOARD="kiali"

# Print usage
usage() {
  echo "Usage: $0 [-d DASHBOARD]"
  echo ""
  echo "Options:"
  echo "  -d DASHBOARD : Dashboard to open (kiali, jaeger, grafana, prometheus) (default: kiali)"
  echo ""
  echo "Example:"
  echo "  $0 -d grafana"
  exit 1
}

# Parse command line arguments
while getopts "d:h" opt; do
  case $opt in
    d) DASHBOARD=$OPTARG ;;
    h) usage ;;
    \?) echo "Invalid option: -$OPTARG" >&2; usage ;;
  esac
done

# Validate DASHBOARD
if [ "$DASHBOARD" != "kiali" ] && [ "$DASHBOARD" != "jaeger" ] && [ "$DASHBOARD" != "grafana" ] && [ "$DASHBOARD" != "prometheus" ]; then
  echo "Error: DASHBOARD must be one of: kiali, jaeger, grafana, prometheus"
  usage
fi

echo "===== Service Mesh Monitoring ====="
echo "Opening the $DASHBOARD dashboard..."

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

# Generate some traffic to the services
echo "Generating some traffic to the services..."
INGRESS_HOST=$(minikube ip)
INGRESS_PORT=$(kubectl -n istio-system get service istio-ingressgateway -o jsonpath='{.spec.ports[?(@.name=="http2")].nodePort}')
GATEWAY_URL=$INGRESS_HOST:$INGRESS_PORT

# Function to generate traffic
generate_traffic() {
  local app=$1
  local count=$2
  
  echo "Sending $count requests to $app..."
  for i in $(seq 1 $count); do
    curl -s -o /dev/null "http://$GATEWAY_URL/$app"
    echo -n "."
    sleep 0.5
  done
  echo ""
}

# Generate traffic to both apps
generate_traffic "app1" 10
generate_traffic "app2" 10

# Open the requested dashboard
case $DASHBOARD in
  kiali)
    echo "Opening Kiali dashboard..."
    echo "Kiali provides a service mesh visualization and monitoring tool."
    echo "You can see the service graph, traffic flow, and health of your services."
    istioctl dashboard kiali
    ;;
  jaeger)
    echo "Opening Jaeger dashboard..."
    echo "Jaeger provides distributed tracing to monitor and troubleshoot transactions in complex distributed systems."
    echo "You can see the request traces across your services."
    istioctl dashboard jaeger
    ;;
  grafana)
    echo "Opening Grafana dashboard..."
    echo "Grafana provides metrics visualization for your services."
    echo "You can see dashboards for service metrics, control plane metrics, and more."
    
    # Check if Grafana is enabled in the Istio installation
    if ! kubectl get deployment -n istio-system grafana &> /dev/null; then
      echo "Error: Grafana is not enabled in your Istio installation."
      echo "To enable Grafana, reinstall Istio with Grafana enabled:"
      echo "  istioctl install -f istio-grafana.yaml"
      echo ""
      echo "The istio-grafana.yaml file is provided in this project."
      exit 1
    fi
    
    istioctl dashboard grafana
    ;;
  prometheus)
    echo "Opening Prometheus dashboard..."
    echo "Prometheus collects metrics from your services and Istio components."
    echo "You can query and visualize these metrics."
    istioctl dashboard prometheus
    ;;
esac

echo ""
echo "===== Monitoring Complete ====="
echo "The $DASHBOARD dashboard has been opened."
echo ""
echo "To generate more traffic to the services, you can run:"
echo "curl http://$GATEWAY_URL/app1"
echo "curl http://$GATEWAY_URL/app2"
echo ""
