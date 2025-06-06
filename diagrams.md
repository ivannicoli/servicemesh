# Service Mesh Architecture Diagrams

This document contains diagrams explaining the structure and architecture of the service mesh demo.

## Overall Architecture

```mermaid
graph TD
    subgraph "Kubernetes Cluster"
        subgraph "Istio Service Mesh"
            subgraph "servicemesh-demo Namespace"
                A[App1 Pod] --> |sidecar| A1[Istio Proxy]
                B[App2 Pod] --> |sidecar| B1[Istio Proxy]
                
                A1 <--> B1
                
                A1 <--> IG
                B1 <--> IG
            end
            
            IG[Istio Ingress Gateway]
        end
        
        CP[Istio Control Plane]
    end
    
    User[External User] --> IG
    
    style A fill:#6495ED,stroke:#333,stroke-width:2px
    style B fill:#6495ED,stroke:#333,stroke-width:2px
    style A1 fill:#FF7F50,stroke:#333,stroke-width:2px
    style B1 fill:#FF7F50,stroke:#333,stroke-width:2px
    style IG fill:#FF7F50,stroke:#333,stroke-width:2px
    style CP fill:#9370DB,stroke:#333,stroke-width:2px
```

## Service Communication Flow

```mermaid
sequenceDiagram
    participant User as External User
    participant Gateway as Istio Ingress Gateway
    participant App2 as App2 Service
    participant App1 as App1 Service
    
    User->>Gateway: HTTP Request to /app2
    Gateway->>App2: Forward request
    App2->>App1: Service discovery call
    App1-->>App2: Response with data
    App2-->>Gateway: Combined response
    Gateway-->>User: Final response
```

## Istio Components

```mermaid
graph LR
    subgraph "Istio Control Plane"
        Istiod[Istiod]
        Istiod --> Pilot[Pilot]
        Istiod --> Citadel[Citadel]
        Istiod --> Galley[Galley]
    end
    
    subgraph "Istio Data Plane"
        Envoy1[Envoy Proxy]
        Envoy2[Envoy Proxy]
        Gateway[Ingress Gateway]
    end
    
    subgraph "Observability"
        Kiali[Kiali]
        Jaeger[Jaeger]
        Grafana[Grafana]
        Prometheus[Prometheus]
    end
    
    Pilot --> Envoy1
    Pilot --> Envoy2
    Pilot --> Gateway
    
    Prometheus --> Envoy1
    Prometheus --> Envoy2
    Prometheus --> Gateway
    
    Kiali --> Prometheus
    Grafana --> Prometheus
    Jaeger --> Envoy1
    Jaeger --> Envoy2
    
    style Istiod fill:#9370DB,stroke:#333,stroke-width:2px
    style Pilot fill:#9370DB,stroke:#333,stroke-width:2px
    style Citadel fill:#9370DB,stroke:#333,stroke-width:2px
    style Galley fill:#9370DB,stroke:#333,stroke-width:2px
    style Envoy1 fill:#FF7F50,stroke:#333,stroke-width:2px
    style Envoy2 fill:#FF7F50,stroke:#333,stroke-width:2px
    style Gateway fill:#FF7F50,stroke:#333,stroke-width:2px
    style Kiali fill:#20B2AA,stroke:#333,stroke-width:2px
    style Jaeger fill:#20B2AA,stroke:#333,stroke-width:2px
    style Grafana fill:#20B2AA,stroke:#333,stroke-width:2px
    style Prometheus fill:#20B2AA,stroke:#333,stroke-width:2px
```

## Project Structure

```mermaid
graph TD
    Root[servicemesh-demo] --> App1[app1/]
    Root --> App2[app2/]
    Root --> K8s[kubernetes/]
    Root --> Istio[istio/]
    Root --> Scripts[Scripts]
    
    App1 --> A1[Dockerfile]
    App1 --> A2[package.json]
    App1 --> A3[server.js]
    
    App2 --> B1[Dockerfile]
    App2 --> B2[package.json]
    App2 --> B3[server.js]
    
    K8s --> K1[app1-deployment.yaml]
    K8s --> K2[app2-deployment.yaml]
    
    Istio --> I1[gateway.yaml]
    
    Scripts --> S1[deploy.sh]
    Scripts --> S2[cleanup.sh]
    Scripts --> S3[gke-setup.sh]
    Scripts --> S4[update-version.sh]
    Scripts --> S5[monitor.sh]
    Scripts --> S6[fault-injection.sh]
    Scripts --> S7[circuit-breaker.sh]
    Scripts --> S8[help.sh]
    
    style Root fill:#f9f9f9,stroke:#333,stroke-width:2px
    style App1 fill:#e6f3ff,stroke:#333,stroke-width:2px
    style App2 fill:#e6f3ff,stroke:#333,stroke-width:2px
    style K8s fill:#fff2e6,stroke:#333,stroke-width:2px
    style Istio fill:#ffe6e6,stroke:#333,stroke-width:2px
    style Scripts fill:#e6ffe6,stroke:#333,stroke-width:2px
```

## Traffic Management with Istio

```mermaid
graph LR
    Client[Client] --> Gateway[Istio Gateway]
    
    Gateway --> VS1[VirtualService app1]
    Gateway --> VS2[VirtualService app2]
    
    VS1 --> |100%| DR1[DestinationRule app1]
    VS2 --> |100%| DR2[DestinationRule app2]
    
    DR1 --> |subset v1| App1v1[App1 v1]
    DR1 --> |subset v2| App1v2[App1 v2]
    
    DR2 --> |subset v1| App2v1[App2 v1]
    DR2 --> |subset v2| App2v2[App2 v2]
    
    style Gateway fill:#FF7F50,stroke:#333,stroke-width:2px
    style VS1 fill:#FF7F50,stroke:#333,stroke-width:2px
    style VS2 fill:#FF7F50,stroke:#333,stroke-width:2px
    style DR1 fill:#FF7F50,stroke:#333,stroke-width:2px
    style DR2 fill:#FF7F50,stroke:#333,stroke-width:2px
    style App1v1 fill:#6495ED,stroke:#333,stroke-width:2px
    style App1v2 fill:#6495ED,stroke:#333,stroke-width:2px
    style App2v1 fill:#6495ED,stroke:#333,stroke-width:2px
    style App2v2 fill:#6495ED,stroke:#333,stroke-width:2px
```

## Canary Deployment with Traffic Splitting

```mermaid
graph LR
    Client[Client] --> Gateway[Istio Gateway]
    
    Gateway --> VS1[VirtualService app1]
    
    VS1 --> |80%| DR1v1[DestinationRule app1 v1]
    VS1 --> |20%| DR1v2[DestinationRule app1 v2]
    
    DR1v1 --> App1v1[App1 v1]
    DR1v2 --> App1v2[App1 v2]
    
    style Gateway fill:#FF7F50,stroke:#333,stroke-width:2px
    style VS1 fill:#FF7F50,stroke:#333,stroke-width:2px
    style DR1v1 fill:#FF7F50,stroke:#333,stroke-width:2px
    style DR1v2 fill:#FF7F50,stroke:#333,stroke-width:2px
    style App1v1 fill:#6495ED,stroke:#333,stroke-width:2px
    style App1v2 fill:#6495ED,stroke:#333,stroke-width:2px
```

## Fault Injection

```mermaid
graph LR
    Client[Client] --> Gateway[Istio Gateway]
    
    Gateway --> VS1[VirtualService app1]
    
    VS1 --> |Fault Injection| FI[Delay or Abort]
    FI --> DR1[DestinationRule app1]
    
    DR1 --> App1[App1]
    
    style Gateway fill:#FF7F50,stroke:#333,stroke-width:2px
    style VS1 fill:#FF7F50,stroke:#333,stroke-width:2px
    style FI fill:#FF0000,stroke:#333,stroke-width:2px
    style DR1 fill:#FF7F50,stroke:#333,stroke-width:2px
    style App1 fill:#6495ED,stroke:#333,stroke-width:2px
```

## Circuit Breaking

```mermaid
graph LR
    Client[Client] --> Gateway[Istio Gateway]
    
    Gateway --> VS1[VirtualService app1]
    
    VS1 --> DR1[DestinationRule app1]
    
    DR1 --> |Circuit Breaker| CB[Connection Limits & Outlier Detection]
    CB --> App1[App1]
    
    style Gateway fill:#FF7F50,stroke:#333,stroke-width:2px
    style VS1 fill:#FF7F50,stroke:#333,stroke-width:2px
    style DR1 fill:#FF7F50,stroke:#333,stroke-width:2px
    style CB fill:#FF0000,stroke:#333,stroke-width:2px
    style App1 fill:#6495ED,stroke:#333,stroke-width:2px
```

## Minikube vs GKE Deployment

```mermaid
graph TB
    subgraph "Local Development"
        Minikube[Minikube]
        LocalDocker[Local Docker]
        DeployScript[deploy.sh]
        
        DeployScript --> Minikube
        LocalDocker --> Minikube
    end
    
    subgraph "Cloud Deployment"
        GKE[Google Kubernetes Engine]
        GCR[Google Container Registry]
        GKEScript[gke-setup.sh]
        
        GKEScript --> GKE
        GCR --> GKE
    end
    
    Code[Application Code] --> LocalDocker
    Code --> GCR
    
    style Minikube fill:#f9f9f9,stroke:#333,stroke-width:2px
    style GKE fill:#4285F4,stroke:#333,stroke-width:2px
    style LocalDocker fill:#0db7ed,stroke:#333,stroke-width:2px
    style GCR fill:#4285F4,stroke:#333,stroke-width:2px
    style DeployScript fill:#e6ffe6,stroke:#333,stroke-width:2px
    style GKEScript fill:#e6ffe6,stroke:#333,stroke-width:2px
```

## Observability Stack

```mermaid
graph TB
    subgraph "Istio Service Mesh"
        App1[App1 + Sidecar]
        App2[App2 + Sidecar]
        Gateway[Istio Gateway]
    end
    
    subgraph "Monitoring & Visualization"
        Prometheus[Prometheus]
        Grafana[Grafana]
        Kiali[Kiali]
        Jaeger[Jaeger]
    end
    
    App1 --> Prometheus
    App2 --> Prometheus
    Gateway --> Prometheus
    
    Prometheus --> Grafana
    Prometheus --> Kiali
    
    App1 --> Jaeger
    App2 --> Jaeger
    Gateway --> Jaeger
    
    MonitorScript[monitor.sh] --> Kiali
    MonitorScript --> Grafana
    MonitorScript --> Jaeger
    MonitorScript --> Prometheus
    
    style App1 fill:#6495ED,stroke:#333,stroke-width:2px
    style App2 fill:#6495ED,stroke:#333,stroke-width:2px
    style Gateway fill:#FF7F50,stroke:#333,stroke-width:2px
    style Prometheus fill:#e6194B,stroke:#333,stroke-width:2px
    style Grafana fill:#3cb44b,stroke:#333,stroke-width:2px
    style Kiali fill:#4363d8,stroke:#333,stroke-width:2px
    style Jaeger fill:#f58231,stroke:#333,stroke-width:2px
    style MonitorScript fill:#e6ffe6,stroke:#333,stroke-width:2px
