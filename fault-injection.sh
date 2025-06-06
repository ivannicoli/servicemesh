#!/bin/bash

# Exit on error
set -e

# Default values
APP="app1"
FAULT_TYPE="delay"
PERCENTAGE=50
DELAY_SECONDS=5
ERROR_CODE=500
REMOVE=false

# Print usage
usage() {
  echo "Usage: $0 [-a APP] [-t FAULT_TYPE] [-p PERCENTAGE] [-d DELAY_SECONDS] [-e ERROR_CODE] [-r]"
  echo ""
  echo "Options:"
  echo "  -a APP           : Application to inject faults into (app1 or app2) (default: app1)"
  echo "  -t FAULT_TYPE    : Type of fault to inject (delay or abort) (default: delay)"
  echo "  -p PERCENTAGE    : Percentage of requests to affect (0-100) (default: 50)"
  echo "  -d DELAY_SECONDS : Seconds to delay (for delay fault type) (default: 5)"
  echo "  -e ERROR_CODE    : HTTP error code to return (for abort fault type) (default: 500)"
  echo "  -r               : Remove fault injection (default: false)"
  echo ""
  echo "Example:"
  echo "  $0 -a app1 -t delay -p 75 -d 3"
  echo "  $0 -a app2 -t abort -p 30 -e 503"
  echo "  $0 -a app1 -r"
  exit 1
}

# Parse command line arguments
while getopts "a:t:p:d:e:rh" opt; do
  case $opt in
    a) APP=$OPTARG ;;
    t) FAULT_TYPE=$OPTARG ;;
    p) PERCENTAGE=$OPTARG ;;
    d) DELAY_SECONDS=$OPTARG ;;
    e) ERROR_CODE=$OPTARG ;;
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

# Validate FAULT_TYPE
if [ "$FAULT_TYPE" != "delay" ] && [ "$FAULT_TYPE" != "abort" ]; then
  echo "Error: FAULT_TYPE must be either delay or abort"
  usage
fi

# Validate PERCENTAGE
if [ "$PERCENTAGE" -lt 0 ] || [ "$PERCENTAGE" -gt 100 ]; then
  echo "Error: PERCENTAGE must be between 0 and 100"
  usage
fi

echo "===== Service Mesh Fault Injection ====="
if [ "$REMOVE" = true ]; then
  echo "Removing fault injection for $APP..."
else
  echo "Injecting $FAULT_TYPE fault into $APP..."
  echo ""
  echo "Configuration:"
  echo "  Application    : $APP"
  echo "  Fault Type     : $FAULT_TYPE"
  echo "  Percentage     : $PERCENTAGE%"
  if [ "$FAULT_TYPE" = "delay" ]; then
    echo "  Delay Seconds  : $DELAY_SECONDS"
  else
    echo "  Error Code     : $ERROR_CODE"
  fi
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

# Create or update the virtual service with fault injection
VIRTUAL_SERVICE_FILE="servicemesh-demo/istio/${APP}-fault-injection.yaml"

if [ "$REMOVE" = true ]; then
  # Remove the fault injection virtual service if it exists
  if kubectl get virtualservice ${APP}-fault -n servicemesh-demo &> /dev/null; then
    kubectl delete virtualservice ${APP}-fault -n servicemesh-demo
    echo "Fault injection removed for $APP."
  else
    echo "No fault injection found for $APP."
  fi
else
  # Create the virtual service with fault injection
  echo "Creating virtual service with fault injection..."
  
  # Start of the virtual service definition
  cat > $VIRTUAL_SERVICE_FILE << EOF
apiVersion: networking.istio.io/v1alpha3
kind: VirtualService
metadata:
  name: ${APP}-fault
  namespace: servicemesh-demo
spec:
  hosts:
  - $APP
  http:
  - fault:
EOF

  # Add the specific fault type
  if [ "$FAULT_TYPE" = "delay" ]; then
    cat >> $VIRTUAL_SERVICE_FILE << EOF
      delay:
        percentage:
          value: $PERCENTAGE
        fixedDelay: ${DELAY_SECONDS}s
EOF
  else
    cat >> $VIRTUAL_SERVICE_FILE << EOF
      abort:
        percentage:
          value: $PERCENTAGE
        httpStatus: $ERROR_CODE
EOF
  fi

  # Complete the virtual service definition
  cat >> $VIRTUAL_SERVICE_FILE << EOF
    route:
    - destination:
        host: $APP
EOF

  # Apply the virtual service
  kubectl apply -f $VIRTUAL_SERVICE_FILE
  
  echo "Fault injection applied to $APP."
  echo "Virtual service file created: $VIRTUAL_SERVICE_FILE"
fi

# Get the Istio ingress gateway URL
INGRESS_HOST=$(minikube ip)
INGRESS_PORT=$(kubectl -n istio-system get service istio-ingressgateway -o jsonpath='{.spec.ports[?(@.name=="http2")].nodePort}')
GATEWAY_URL=$INGRESS_HOST:$INGRESS_PORT

echo ""
echo "===== Fault Injection Complete ====="
if [ "$REMOVE" = true ]; then
  echo "Fault injection has been removed from $APP."
else
  echo "Fault injection has been applied to $APP."
  echo ""
  echo "To test the fault injection, access the application:"
  echo "http://$GATEWAY_URL/$APP"
  echo ""
  if [ "$FAULT_TYPE" = "delay" ]; then
    echo "Approximately $PERCENTAGE% of requests will be delayed by $DELAY_SECONDS seconds."
  else
    echo "Approximately $PERCENTAGE% of requests will fail with HTTP $ERROR_CODE error."
  fi
  echo ""
  echo "To remove the fault injection, run:"
  echo "$0 -a $APP -r"
fi
echo ""
