#!/bin/bash

# Exit on error
set -e

echo "===== Service Mesh Demo Cleanup ====="
echo "This script will clean up all resources created for the service mesh demo."
echo ""
echo "Press Enter to continue or Ctrl+C to cancel..."
read

# Delete the namespace (this will delete all resources in the namespace)
echo "Deleting servicemesh-demo namespace..."
kubectl delete namespace servicemesh-demo

# Optional: Uninstall Istio
echo ""
echo "Do you want to uninstall Istio? (y/n)"
read uninstall_istio

if [[ "$uninstall_istio" == "y" || "$uninstall_istio" == "Y" ]]; then
  echo "Uninstalling Istio..."
  istioctl uninstall --purge -y
  kubectl delete namespace istio-system
  echo "Istio uninstalled."
else
  echo "Keeping Istio installation."
fi

# Optional: Stop Minikube
echo ""
echo "Do you want to stop Minikube? (y/n)"
read stop_minikube

if [[ "$stop_minikube" == "y" || "$stop_minikube" == "Y" ]]; then
  echo "Stopping Minikube..."
  minikube stop
  echo "Minikube stopped."
else
  echo "Keeping Minikube running."
fi

echo ""
echo "===== Cleanup Complete ====="
echo "The service mesh demo resources have been cleaned up."
echo ""
