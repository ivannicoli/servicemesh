#!/bin/bash

# Exit on error
set -e

# Default values
APP=""
VERSION=""
WEIGHT=0
DEPLOY=false

# Print usage
usage() {
  echo "Usage: $0 -a APP -v VERSION [-w WEIGHT] [-d]"
  echo ""
  echo "Options:"
  echo "  -a APP     : Application to update (app1 or app2) (required)"
  echo "  -v VERSION : New version (e.g., v2, v3) (required)"
  echo "  -w WEIGHT  : Traffic weight for the new version (0-100, default: 0)"
  echo "  -d         : Deploy the new version (default: false, just creates the files)"
  echo ""
  echo "Example:"
  echo "  $0 -a app1 -v v2 -w 20 -d"
  exit 1
}

# Parse command line arguments
while getopts "a:v:w:dh" opt; do
  case $opt in
    a) APP=$OPTARG ;;
    v) VERSION=$OPTARG ;;
    w) WEIGHT=$OPTARG ;;
    d) DEPLOY=true ;;
    h) usage ;;
    \?) echo "Invalid option: -$OPTARG" >&2; usage ;;
  esac
done

# Check if required parameters are provided
if [ -z "$APP" ] || [ -z "$VERSION" ]; then
  echo "Error: APP and VERSION are required"
  usage
fi

# Validate APP
if [ "$APP" != "app1" ] && [ "$APP" != "app2" ]; then
  echo "Error: APP must be either app1 or app2"
  usage
fi

# Validate VERSION
if [[ ! "$VERSION" =~ ^v[0-9]+$ ]]; then
  echo "Error: VERSION must be in the format 'vN' where N is a number (e.g., v2, v3)"
  usage
fi

# Validate WEIGHT
if [ "$WEIGHT" -lt 0 ] || [ "$WEIGHT" -gt 100 ]; then
  echo "Error: WEIGHT must be between 0 and 100"
  usage
fi

echo "===== Service Mesh Version Update ====="
echo "This script will create a new version of an application and update the traffic routing."
echo ""
echo "Configuration:"
echo "  Application : $APP"
echo "  New Version : $VERSION"
echo "  Traffic Weight: $WEIGHT%"
echo "  Deploy      : $DEPLOY"
echo ""
echo "Press Enter to continue or Ctrl+C to cancel..."
read

# Create a new deployment file for the new version
echo "Creating deployment file for $APP $VERSION..."

# Define the deployment file path
DEPLOYMENT_FILE="servicemesh-demo/kubernetes/${APP}-${VERSION}-deployment.yaml"

# Create the deployment file
cat > $DEPLOYMENT_FILE << EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: $APP-$VERSION
  namespace: servicemesh-demo
  labels:
    app: $APP
    version: $VERSION
spec:
  replicas: 1
  selector:
    matchLabels:
      app: $APP
      version: $VERSION
  template:
    metadata:
      labels:
        app: $APP
        version: $VERSION
    spec:
      containers:
      - name: $APP
        image: $APP:latest
        imagePullPolicy: IfNotPresent
        env:
        - name: SERVICE_NAME
          value: "$APP"
        - name: SERVICE_VERSION
          value: "$VERSION"
EOF

# Add app-specific environment variables
if [ "$APP" == "app2" ]; then
  cat >> $DEPLOYMENT_FILE << EOF
        - name: APP1_SERVICE
          value: "app1.servicemesh-demo.svc.cluster.local"
        - name: APP1_PORT
          value: "8080"
EOF
fi

# Complete the deployment file
cat >> $DEPLOYMENT_FILE << EOF
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
EOF

echo "Deployment file created: $DEPLOYMENT_FILE"

# Create a destination rule for the application if it doesn't exist
DESTINATION_RULE_FILE="servicemesh-demo/istio/${APP}-destination-rule.yaml"

if [ ! -f "$DESTINATION_RULE_FILE" ]; then
  echo "Creating destination rule for $APP..."
  
  cat > $DESTINATION_RULE_FILE << EOF
apiVersion: networking.istio.io/v1alpha3
kind: DestinationRule
metadata:
  name: $APP
  namespace: servicemesh-demo
spec:
  host: $APP
  subsets:
  - name: v1
    labels:
      version: v1
EOF
fi

# Add the new version to the destination rule
echo "Updating destination rule to include $VERSION..."
if ! grep -q "name: $VERSION" "$DESTINATION_RULE_FILE"; then
  sed -i '' "/subsets:/a\\
  - name: $VERSION\\
    labels:\\
      version: $VERSION" "$DESTINATION_RULE_FILE"
fi

# Update the virtual service for traffic splitting
VIRTUAL_SERVICE_FILE="servicemesh-demo/istio/${APP}-virtual-service.yaml"

# Create or update the virtual service
echo "Creating/updating virtual service for $APP with traffic splitting..."

if [ "$WEIGHT" -eq 0 ]; then
  # If weight is 0, don't include the new version in traffic routing
  cat > $VIRTUAL_SERVICE_FILE << EOF
apiVersion: networking.istio.io/v1alpha3
kind: VirtualService
metadata:
  name: $APP-virtualservice
  namespace: servicemesh-demo
spec:
  hosts:
  - "*"
  gateways:
  - servicemesh-gateway
  http:
  - match:
    - uri:
        prefix: /$APP
    rewrite:
      uri: /
    route:
    - destination:
        host: $APP
        subset: v1
        port:
          number: 8080
      weight: 100
EOF
else
  # Calculate the weight for v1
  V1_WEIGHT=$((100 - $WEIGHT))
  
  cat > $VIRTUAL_SERVICE_FILE << EOF
apiVersion: networking.istio.io/v1alpha3
kind: VirtualService
metadata:
  name: $APP-virtualservice
  namespace: servicemesh-demo
spec:
  hosts:
  - "*"
  gateways:
  - servicemesh-gateway
  http:
  - match:
    - uri:
        prefix: /$APP
    rewrite:
      uri: /
    route:
    - destination:
        host: $APP
        subset: v1
        port:
          number: 8080
      weight: $V1_WEIGHT
    - destination:
        host: $APP
        subset: $VERSION
        port:
          number: 8080
      weight: $WEIGHT
EOF
fi

echo "Virtual service file created/updated: $VIRTUAL_SERVICE_FILE"

# Deploy the new version if requested
if [ "$DEPLOY" = true ]; then
  echo "Deploying the new version..."
  
  # Apply the deployment
  kubectl apply -f $DEPLOYMENT_FILE
  
  # Apply the destination rule
  kubectl apply -f $DESTINATION_RULE_FILE
  
  # Apply the virtual service
  kubectl apply -f $VIRTUAL_SERVICE_FILE
  
  # Wait for the deployment to be ready
  echo "Waiting for deployment to be ready..."
  kubectl wait --for=condition=available --timeout=300s deployment/$APP-$VERSION -n servicemesh-demo
  
  echo "Deployment complete!"
else
  echo "Files created but not deployed. To deploy, run:"
  echo "kubectl apply -f $DEPLOYMENT_FILE"
  echo "kubectl apply -f $DESTINATION_RULE_FILE"
  echo "kubectl apply -f $VIRTUAL_SERVICE_FILE"
fi

echo ""
echo "===== Version Update Complete ====="
echo "The new version has been set up and traffic routing has been configured."
echo ""
echo "To test the traffic routing, access the application multiple times:"
echo "http://<MINIKUBE_IP>:<INGRESS_PORT>/$APP"
echo ""
echo "You should see approximately $WEIGHT% of requests going to $VERSION and $((100 - $WEIGHT))% going to v1."
echo ""
