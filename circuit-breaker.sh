#!/bin/bash

# Exit on error
set -e

# Default values
APP="app1"
MAX_CONNECTIONS=1
HTTP_1_MAX_PENDING_REQUESTS=1
MAX_REQUESTS_PER_CONNECTION=1
CONSECUTIVE_ERRORS=1
INTERVAL=1s
BASE_EJECTION_TIME=3m
REMOVE=false

# Print usage
usage() {
  echo "Usage: $0 [-a APP] [-c MAX_CONNECTIONS] [-p HTTP_1_MAX_PENDING_REQUESTS] [-m MAX_REQUESTS_PER_CONNECTION] [-e CONSECUTIVE_ERRORS] [-i INTERVAL] [-t BASE_EJECTION_TIME] [-r]"
  echo ""
  echo "Options:"
  echo "  -a APP                        : Application to apply circuit breaker to (app1 or app2) (default: app1)"
  echo "  -c MAX_CONNECTIONS            : Maximum number of connections to the service (default: 1)"
  echo "  -p HTTP_1_MAX_PENDING_REQUESTS: Maximum number of pending HTTP requests (default: 1)"
  echo "  -m MAX_REQUESTS_PER_CONNECTION: Maximum number of requests per connection (default: 1)"
  echo "  -e CONSECUTIVE_ERRORS         : Number of consecutive errors before ejection (default: 1)"
  echo "  -i INTERVAL                   : Time interval for checking errors (default: 1s)"
  echo "  -t BASE_EJECTION_TIME         : Minimum time the host is ejected (default: 3m)"
  echo "  -r                            : Remove circuit breaker (default: false)"
  echo ""
  echo "Example:"
  echo "  $0 -a app1 -c 2 -p 2 -e 3"
  echo "  $0 -a app1 -r"
  exit 1
}

# Parse command line arguments
while getopts "a:c:p:m:e:i:t:rh" opt; do
  case $opt in
    a) APP=$OPTARG ;;
    c) MAX_CONNECTIONS=$OPTARG ;;
    p) HTTP_1_MAX_PENDING_REQUESTS=$OPTARG ;;
    m) MAX_REQUESTS_PER_CONNECTION=$OPTARG ;;
    e) CONSECUTIVE_ERRORS=$OPTARG ;;
    i) INTERVAL=$OPTARG ;;
    t) BASE_EJECTION_TIME=$OPTARG ;;
    r) REMOVE=true ;;
    h) usage ;;
    \?) echo "Invalid option: -$OPTARG" >&2; usage ;;
  esac
done

# Validate APP
if [ "$APP" != "app1" ] && [ "$APP" != "app2" ]; then
  echo "Error: APP must be either app1 or app2"
  usage
fi

echo "===== Service Mesh Circuit Breaker ====="
if [ "$REMOVE" = true ]; then
  echo "Removing circuit breaker for $APP..."
else
  echo "Applying circuit breaker to $APP..."
  echo ""
  echo "Configuration:"
  echo "  Application                  : $APP"
  echo "  Max Connections              : $MAX_CONNECTIONS"
  echo "  HTTP/1.1 Max Pending Requests: $HTTP_1_MAX_PENDING_REQUESTS"
  echo "  Max Requests Per Connection  : $MAX_REQUESTS_PER_CONNECTION"
  echo "  Consecutive Errors           : $CONSECUTIVE_ERRORS"
  echo "  Interval                     : $INTERVAL"
  echo "  Base Ejection Time           : $BASE_EJECTION_TIME"
fi

echo ""
echo "Press Enter to continue or Ctrl+C to cancel..."
read

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

# Create or update the destination rule with circuit breaker
DESTINATION_RULE_FILE="servicemesh-demo/istio/${APP}-circuit-breaker.yaml"

if [ "$REMOVE" = true ]; then
  # Remove the circuit breaker destination rule if it exists
  if kubectl get destinationrule ${APP}-circuit-breaker -n servicemesh-demo &> /dev/null; then
    kubectl delete destinationrule ${APP}-circuit-breaker -n servicemesh-demo
    echo "Circuit breaker removed for $APP."
  else
    echo "No circuit breaker found for $APP."
  fi
else
  # Create the destination rule with circuit breaker
  echo "Creating destination rule with circuit breaker..."
  
  cat > $DESTINATION_RULE_FILE << EOF
apiVersion: networking.istio.io/v1alpha3
kind: DestinationRule
metadata:
  name: ${APP}-circuit-breaker
  namespace: servicemesh-demo
spec:
  host: $APP
  trafficPolicy:
    connectionPool:
      tcp:
        maxConnections: $MAX_CONNECTIONS
      http:
        http1MaxPendingRequests: $HTTP_1_MAX_PENDING_REQUESTS
        maxRequestsPerConnection: $MAX_REQUESTS_PER_CONNECTION
    outlierDetection:
      consecutive5xxErrors: $CONSECUTIVE_ERRORS
      interval: $INTERVAL
      baseEjectionTime: $BASE_EJECTION_TIME
      maxEjectionPercent: 100
EOF

  # Apply the destination rule
  kubectl apply -f $DESTINATION_RULE_FILE
  
  echo "Circuit breaker applied to $APP."
  echo "Destination rule file created: $DESTINATION_RULE_FILE"
fi

# Get the Istio ingress gateway URL
INGRESS_HOST=$(minikube ip)
INGRESS_PORT=$(kubectl -n istio-system get service istio-ingressgateway -o jsonpath='{.spec.ports[?(@.name=="http2")].nodePort}')
GATEWAY_URL=$INGRESS_HOST:$INGRESS_PORT

echo ""
echo "===== Circuit Breaker Setup Complete ====="
if [ "$REMOVE" = true ]; then
  echo "Circuit breaker has been removed from $APP."
else
  echo "Circuit breaker has been applied to $APP."
  echo ""
  echo "To test the circuit breaker, you can use a load testing tool like fortio:"
  echo ""
  echo "# Install fortio if not already installed"
  echo "kubectl apply -f https://raw.githubusercontent.com/istio/istio/release-1.24/samples/httpbin/sample-client/fortio-deploy.yaml -n servicemesh-demo"
  echo ""
  echo "# Run a load test with multiple concurrent connections"
  echo "kubectl exec -it deploy/fortio -n servicemesh-demo -- fortio load -c 2 -qps 0 -n 20 -loglevel Warning http://$APP:8080/"
  echo ""
  echo "You should see some requests succeed and others fail with 503 errors when the circuit breaker trips."
  echo ""
  echo "To remove the circuit breaker, run:"
  echo "$0 -a $APP -r"
fi
echo ""
