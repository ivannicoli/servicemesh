#!/bin/bash

# Exit on error
set -e

# Default values
PROJECT_ID=""
CLUSTER_NAME="servicemesh-demo"
CLUSTER_ZONE="us-central1-a"
CLUSTER_VERSION="latest"
MACHINE_TYPE="e2-standard-2"
NODE_COUNT=3
REGISTRY="gcr.io"

# Print usage
usage() {
  echo "Usage: $0 -p PROJECT_ID [-n CLUSTER_NAME] [-z CLUSTER_ZONE] [-v CLUSTER_VERSION] [-m MACHINE_TYPE] [-c NODE_COUNT] [-r REGISTRY]"
  echo ""
  echo "Options:"
  echo "  -p PROJECT_ID     : GCP Project ID (required)"
  echo "  -n CLUSTER_NAME   : GKE cluster name (default: servicemesh-demo)"
  echo "  -z CLUSTER_ZONE   : GKE cluster zone (default: us-central1-a)"
  echo "  -v CLUSTER_VERSION: GKE cluster version (default: latest)"
  echo "  -m MACHINE_TYPE   : GKE node machine type (default: e2-standard-2)"
  echo "  -c NODE_COUNT     : Number of nodes in the cluster (default: 3)"
  echo "  -r REGISTRY       : Container registry to use (default: gcr.io)"
  echo ""
  echo "Example:"
  echo "  $0 -p my-gcp-project -n my-cluster -z us-west1-a"
  exit 1
}

# Parse command line arguments
while getopts "p:n:z:v:m:c:r:h" opt; do
  case $opt in
    p) PROJECT_ID=$OPTARG ;;
    n) CLUSTER_NAME=$OPTARG ;;
    z) CLUSTER_ZONE=$OPTARG ;;
    v) CLUSTER_VERSION=$OPTARG ;;
    m) MACHINE_TYPE=$OPTARG ;;
    c) NODE_COUNT=$OPTARG ;;
    r) REGISTRY=$OPTARG ;;
    h) usage ;;
    \?) echo "Invalid option: -$OPTARG" >&2; usage ;;
  esac
done

# Check if PROJECT_ID is provided
if [ -z "$PROJECT_ID" ]; then
  echo "Error: PROJECT_ID is required"
  usage
fi

echo "===== GKE Service Mesh Demo Setup ====="
echo "This script will set up a GKE cluster with Istio and deploy the service mesh demo applications."
echo ""
echo "Configuration:"
echo "  Project ID     : $PROJECT_ID"
echo "  Cluster Name   : $CLUSTER_NAME"
echo "  Cluster Zone   : $CLUSTER_ZONE"
echo "  Cluster Version: $CLUSTER_VERSION"
echo "  Machine Type   : $MACHINE_TYPE"
echo "  Node Count     : $NODE_COUNT"
echo "  Registry       : $REGISTRY"
echo ""
echo "Press Enter to continue or Ctrl+C to cancel..."
read

# Set the GCP project
echo "Setting GCP project to $PROJECT_ID..."
gcloud config set project $PROJECT_ID

# Create GKE cluster
echo "Creating GKE cluster $CLUSTER_NAME in zone $CLUSTER_ZONE..."
gcloud container clusters create $CLUSTER_NAME \
  --zone $CLUSTER_ZONE \
  --machine-type $MACHINE_TYPE \
  --num-nodes $NODE_COUNT \
  --enable-network-policy \
  --release-channel regular

# Get credentials for the cluster
echo "Getting credentials for the cluster..."
gcloud container clusters get-credentials $CLUSTER_NAME --zone $CLUSTER_ZONE --project $PROJECT_ID

# Install Istio
echo "Installing Istio..."
istioctl install --set profile=default -y

# Create and label namespace
echo "Creating and labeling namespace..."
kubectl create namespace servicemesh-demo
kubectl label namespace servicemesh-demo istio-injection=enabled

# Build and push Docker images
echo "Building and pushing Docker images..."

# App1
echo "Building and pushing app1 image..."
cd "$(dirname "$0")/app1"
docker build -t $REGISTRY/$PROJECT_ID/app1:latest .
docker push $REGISTRY/$PROJECT_ID/app1:latest

# App2
echo "Building and pushing app2 image..."
cd "$(dirname "$0")/app2"
docker build -t $REGISTRY/$PROJECT_ID/app2:latest .
docker push $REGISTRY/$PROJECT_ID/app2:latest

# Return to the main directory
cd "$(dirname "$0")"

# Create temporary directory for GKE manifests
echo "Creating GKE-specific Kubernetes manifests..."
mkdir -p gke-manifests

# Create app1 deployment for GKE
cat > gke-manifests/app1-deployment.yaml << EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: app1
  namespace: servicemesh-demo
  labels:
    app: app1
    version: v1
spec:
  replicas: 2
  selector:
    matchLabels:
      app: app1
      version: v1
  template:
    metadata:
      labels:
        app: app1
        version: v1
    spec:
      containers:
      - name: app1
        image: $REGISTRY/$PROJECT_ID/app1:latest
        imagePullPolicy: Always
        env:
        - name: SERVICE_NAME
          value: "app1"
        - name: SERVICE_VERSION
          value: "v1"
        ports:
        - containerPort: 8080
        resources:
          requests:
            cpu: 100m
            memory: 128Mi
          limits:
            cpu: 200m
            memory: 256Mi
        readinessProbe:
          httpGet:
            path: /health
            port: 8080
          initialDelaySeconds: 5
          periodSeconds: 10
        livenessProbe:
          httpGet:
            path: /health
            port: 8080
          initialDelaySeconds: 15
          periodSeconds: 20
---
apiVersion: v1
kind: Service
metadata:
  name: app1
  namespace: servicemesh-demo
  labels:
    app: app1
    service: app1
spec:
  ports:
  - port: 8080
    name: http
    targetPort: 8080
  selector:
    app: app1
EOF

# Create app2 deployment for GKE
cat > gke-manifests/app2-deployment.yaml << EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: app2
  namespace: servicemesh-demo
  labels:
    app: app2
    version: v1
spec:
  replicas: 2
  selector:
    matchLabels:
      app: app2
      version: v1
  template:
    metadata:
      labels:
        app: app2
        version: v1
    spec:
      containers:
      - name: app2
        image: $REGISTRY/$PROJECT_ID/app2:latest
        imagePullPolicy: Always
        env:
        - name: SERVICE_NAME
          value: "app2"
        - name: SERVICE_VERSION
          value: "v1"
        - name: APP1_SERVICE
          value: "app1.servicemesh-demo.svc.cluster.local"
        - name: APP1_PORT
          value: "8080"
        ports:
        - containerPort: 8080
        resources:
          requests:
            cpu: 100m
            memory: 128Mi
          limits:
            cpu: 200m
            memory: 256Mi
        readinessProbe:
          httpGet:
            path: /health
            port: 8080
          initialDelaySeconds: 5
          periodSeconds: 10
        livenessProbe:
          httpGet:
            path: /health
            port: 8080
          initialDelaySeconds: 15
          periodSeconds: 20
---
apiVersion: v1
kind: Service
metadata:
  name: app2
  namespace: servicemesh-demo
  labels:
    app: app2
    service: app2
spec:
  ports:
  - port: 8080
    name: http
    targetPort: 8080
  selector:
    app: app2
EOF

# Copy Istio gateway configuration
cp istio/gateway.yaml gke-manifests/

# Apply Kubernetes manifests
echo "Applying Kubernetes manifests..."
kubectl apply -f gke-manifests/app1-deployment.yaml
kubectl apply -f gke-manifests/app2-deployment.yaml
kubectl apply -f gke-manifests/gateway.yaml

# Wait for deployments to be ready
echo "Waiting for deployments to be ready..."
kubectl wait --for=condition=available --timeout=300s deployment/app1 -n servicemesh-demo
kubectl wait --for=condition=available --timeout=300s deployment/app2 -n servicemesh-demo

# Get the Istio ingress gateway external IP
echo "Getting Istio ingress gateway external IP..."
INGRESS_HOST=$(kubectl -n istio-system get service istio-ingressgateway -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
INGRESS_PORT=$(kubectl -n istio-system get service istio-ingressgateway -o jsonpath='{.spec.ports[?(@.name=="http2")].port}')
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
echo "To clean up the resources:"
echo "gcloud container clusters delete $CLUSTER_NAME --zone $CLUSTER_ZONE --quiet"
echo ""
