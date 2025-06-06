# Service Mesh Demo with Istio and Kubernetes

This project demonstrates a simple service mesh setup using Istio on Kubernetes (Minikube). It includes two microservices that communicate with each other using Kubernetes service discovery.

## Architecture

The demo consists of:

1. **App1**: A simple Node.js service that returns information about itself
2. **App2**: A Node.js service that calls App1 and combines the responses

Both services are deployed in Kubernetes with Istio sidecar injection enabled, allowing for advanced traffic management, observability, and security features.

## Prerequisites

- [Minikube](https://minikube.sigs.k8s.io/docs/start/)
- [kubectl](https://kubernetes.io/docs/tasks/tools/)
- [Istio](https://istio.io/latest/docs/setup/getting-started/)
- [Docker](https://docs.docker.com/get-docker/)

## Project Structure

```
servicemesh-demo/
├── app1/                  # First microservice
│   ├── Dockerfile
│   ├── package.json
│   └── server.js
├── app2/                  # Second microservice
│   ├── Dockerfile
│   ├── package.json
│   └── server.js
├── kubernetes/            # Kubernetes manifests
│   ├── app1-deployment.yaml
│   └── app2-deployment.yaml
├── istio/                 # Istio configurations
│   └── gateway.yaml
├── deploy.sh              # Deployment script
├── cleanup.sh             # Cleanup script
├── gke-setup.sh           # GKE deployment script
├── update-version.sh      # Version update and traffic splitting script
├── monitor.sh             # Monitoring dashboards script
├── fault-injection.sh     # Fault injection script
├── circuit-breaker.sh     # Circuit breaker script
├── help.sh                # Help script with usage information
├── diagrams.md            # Architecture diagrams (Mermaid)
└── README.md              # This file
```

## Setup and Deployment

1. Start Minikube:
   ```
   minikube start
   ```

2. Install Istio:
   ```
   istioctl install --set profile=default -y
   ```

3. Create and label the namespace:
   ```
   kubectl create namespace servicemesh-demo
   kubectl label namespace servicemesh-demo istio-injection=enabled
   ```

4. Deploy the applications:
   ```
   ./deploy.sh
   ```

## Utility Scripts

This project includes several utility scripts to help you explore Istio's features:

### Monitoring

Use the monitoring script to open Istio's observability dashboards:

```
./monitor.sh -d kiali      # Service mesh visualization
./monitor.sh -d jaeger     # Distributed tracing
./monitor.sh -d grafana    # Metrics visualization
./monitor.sh -d prometheus # Raw metrics
```

### Traffic Management

Update service versions and implement traffic splitting:

```
./update-version.sh -a app1 -v v2 -w 20 -d  # Deploy app1 v2 with 20% traffic weight
```

### Fault Injection

Inject faults to test service resilience:

```
./fault-injection.sh -a app1 -t delay -p 50 -d 5  # Add 5s delay to 50% of app1 requests
./fault-injection.sh -a app2 -t abort -p 20 -e 500  # Return 500 error for 20% of app2 requests
./fault-injection.sh -a app1 -r  # Remove fault injection
```

### Circuit Breaking

Implement circuit breaking to prevent cascading failures:

```
./circuit-breaker.sh -a app1 -c 1 -p 1 -e 1  # Set up circuit breaker for app1
./circuit-breaker.sh -a app1 -r  # Remove circuit breaker
```

### Cleanup

Clean up the demo resources:

```
./cleanup.sh
```

### GKE Deployment

Deploy the demo to Google Kubernetes Engine:

```
./gke-setup.sh -p YOUR_GCP_PROJECT_ID
```

### Help

For a quick reference of all available scripts and their options:

```
./help.sh
```

## Accessing the Applications

After deployment, you can access the applications through the Istio Ingress Gateway:

- App1: `http://<MINIKUBE_IP>:<INGRESS_PORT>/app1`
- App2: `http://<MINIKUBE_IP>:<INGRESS_PORT>/app2`

The deployment script will output the exact URLs.

## Service Discovery

App2 communicates with App1 using Kubernetes DNS-based service discovery. The service URL format is:

```
http://app1.servicemesh-demo.svc.cluster.local:8080
```

This demonstrates how microservices can discover and communicate with each other in a Kubernetes environment.

## Istio Features

This demo showcases several Istio features:

1. **Traffic Management**: Using VirtualServices and Gateway for routing
2. **Observability**: Automatic metrics, logs, and traces
3. **Security**: Automatic mTLS between services

## Monitoring and Visualization

Istio provides several dashboards for monitoring and visualizing your service mesh:

- **Kiali**: Service mesh visualization
  ```
  istioctl dashboard kiali
  ```

- **Jaeger**: Distributed tracing
  ```
  istioctl dashboard jaeger
  ```

- **Grafana**: Metrics visualization
  ```
  istioctl dashboard grafana
  ```

## Adapting for GKE

This project includes a script to deploy the demo to Google Kubernetes Engine:

```
./gke-setup.sh -p YOUR_GCP_PROJECT_ID
```

The script handles:

1. Creating a GKE cluster with Istio enabled
2. Building and pushing the Docker images to Google Container Registry (GCR)
3. Generating GKE-specific Kubernetes manifests
4. Deploying the applications to GKE

## Cleanup

To clean up the resources:

```
kubectl delete namespace servicemesh-demo
```

## Architecture Diagrams

This project includes detailed architecture diagrams created with Mermaid. View them in the `diagrams.md` file or any Markdown viewer that supports Mermaid syntax.

The diagrams include:
- Overall architecture of the service mesh
- Service communication flow
- Istio components
- Project structure
- Traffic management with Istio
- Canary deployment with traffic splitting
- Fault injection
- Circuit breaking
- Minikube vs GKE deployment
- Observability stack

## Additional Resources

- [Istio Documentation](https://istio.io/latest/docs/)
- [Kubernetes Documentation](https://kubernetes.io/docs/home/)
- [Minikube Documentation](https://minikube.sigs.k8s.io/docs/)
# servicemesh
