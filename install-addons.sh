#!/bin/bash

# Exit on error
set -e

echo "===== Installing Istio Addons ====="
echo "This script installs all Istio addons for observability:"
echo "- Grafana (metrics visualization)"
echo "- Kiali (service mesh visualization)"
echo "- Jaeger (distributed tracing)"
echo "- Prometheus (metrics collection)"
echo ""
echo "Note: For a fresh installation with all addons and optimized configuration,"
echo "you can also use: istioctl install -f istio-full.yaml"
echo ""

# Check if Istio is installed
if ! kubectl get namespace istio-system &> /dev/null; then
  echo "Error: Istio is not installed."
  echo "Please install Istio first using 'istioctl install --set profile=default -y'"
  exit 1
fi

echo "Installing Grafana addon..."
kubectl apply -f https://raw.githubusercontent.com/istio/istio/release-1.24/samples/addons/grafana.yaml

echo "Installing Kiali addon..."
kubectl apply -f https://raw.githubusercontent.com/istio/istio/release-1.24/samples/addons/kiali.yaml

echo "Installing Jaeger addon..."
kubectl apply -f https://raw.githubusercontent.com/istio/istio/release-1.24/samples/addons/jaeger.yaml

echo "Installing Prometheus addon..."
kubectl apply -f https://raw.githubusercontent.com/istio/istio/release-1.24/samples/addons/prometheus.yaml

echo ""
echo "===== Addon Installation Complete ====="
echo "All Istio addons have been installed."
echo ""
echo "To access the dashboards, use the following commands:"
echo ""
echo "Grafana (metrics visualization):"
echo "  istioctl dashboard grafana"
echo ""
echo "Kiali (service mesh visualization):"
echo "  istioctl dashboard kiali"
echo ""
echo "Jaeger (distributed tracing):"
echo "  istioctl dashboard jaeger"
echo ""
echo "Prometheus (metrics collection):"
echo "  istioctl dashboard prometheus"
echo ""
echo "You can also use the monitor.sh script to access these dashboards:"
echo "  ./monitor.sh -d [dashboard_name]"
echo ""
