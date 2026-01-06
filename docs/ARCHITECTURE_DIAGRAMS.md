# IDP Architecture Diagrams

## Production-Ready IDP Architecture

### High-Level View
```
┌─────────────────────────────────────────────────┐
│              Application Developers              │
│  (Use Backstage for everything)                 │
└────────────────────┬────────────────────────────┘
                     │
                     │ https://backstage.yourcompany.com
                     ↓
┌─────────────────────────────────────────────────┐
│         NGINX Ingress Controller                │
│  • SSL/TLS Termination                          │
│  • Domain routing                               │
│  • Load balancing                               │
└────────┬────────────────────────────────┬───────┘
         │                                │
         │                                │
         ↓                                ↓
┌────────────────────┐          ┌─────────────────┐
│    Backstage       │          │     ArgoCD      │
│  (Port 7007)       │◄─────────│   (Port 80)     │
│                    │   APIs   │                 │
│ ┌────────────────┐ │          │ ┌─────────────┐ │
│ │Service Catalog │ │          │ │App Sync     │ │
│ │Templates       │ │          │ │Health Check │ │
│ │TechDocs        │ │          │ │Rollback     │ │
│ │ArgoCD Plugin   │─┼──────────┼→│             │ │
│ │K8s Plugin      │ │          │ └─────────────┘ │
│ └────────────────┘ │          └─────────────────┘
│                    │                    │
│ ┌────────────────┐ │                    │
│ │  PostgreSQL    │ │                    │
│ │  (Database)    │ │                    │
│ └────────────────┘ │                    │
└────────────────────┘                    │
         │                                │
         └────────────┬───────────────────┘
                      │
                      ↓
         ┌─────────────────────────┐
         │   Kubernetes Cluster    │
         │  • Deployments          │
         │  • Services             │
         │  • ConfigMaps           │
         │  • Secrets              │
         └─────────────────────────┘
```

## Component Responsibilities

### Backstage (Developer Portal)
```
┌──────────────────────────────────────┐
│           Backstage UI               │
├──────────────────────────────────────┤
│                                      │
│  ┌──────────┐  ┌─────────────────┐  │
│  │ Catalog  │  │   Templates     │  │
│  │          │  │   (Scaffolder)  │  │
│  │ • APIs   │  │                 │  │
│  │ • Services│  │ • Node.js API  │  │
│  │ • Systems│  │ • Python App    │  │
│  │ • Docs   │  │ • Database      │  │
│  └──────────┘  └─────────────────┘  │
│                                      │
│  ┌──────────────────────────────┐   │
│  │      TechDocs                │   │
│  │  • Markdown documentation    │   │
│  │  • Searchable                │   │
│  │  • Auto-generated            │   │
│  └──────────────────────────────┘   │
│                                      │
│  ┌──────────────────────────────┐   │
│  │      Plugins                 │   │
│  │  • ArgoCD (deployments)      │   │
│  │  • Kubernetes (resources)    │   │
│  │  • GitHub (repos)            │   │
│  └──────────────────────────────┘   │
└──────────────────────────────────────┘
```

### ArgoCD (GitOps Engine)
```
┌──────────────────────────────────────┐
│           ArgoCD Server              │
├──────────────────────────────────────┤
│                                      │
│  Git Repository                      │
│       ↓                              │
│  ┌────────────────────┐              │
│  │  Sync Controller   │              │
│  │  • Watches Git     │              │
│  │  • Compares state  │              │
│  │  • Applies changes │              │
│  └────────────────────┘              │
│       ↓                              │
│  ┌────────────────────┐              │
│  │  Health Monitor    │              │
│  │  • Checks status   │              │
│  │  • Reports issues  │              │
│  └────────────────────┘              │
│       ↓                              │
│  Kubernetes Cluster                  │
└──────────────────────────────────────┘
```

## Data Flow Diagrams

### 1. Developer Creates New Service
```
Developer
    ↓
[Opens Backstage]
    ↓
[Selects Template]
    ↓
[Fills Parameters]
    │
    └→ Backstage Scaffolder
              ↓
       [Creates Git Repo]
              ↓
       [Commits Code]
              ↓
       [Creates catalog-info.yaml]
              │
              ├→ Backstage Catalog (registers service)
              │
              └→ ArgoCD (detects new app)
                      ↓
               [Syncs to Kubernetes]
                      ↓
               [Service Running]
```

### 2. Developer Views Deployment Status
```
Developer
    ↓
[Opens Backstage]
    ↓
[Views Service Page]
    ↓
[ArgoCD Plugin Tab]
    ↓
Backstage → ArgoCD API
    ↓
[Shows Sync Status]
[Shows Health Status]
[Shows Last Sync Time]
[Shows Git Revision]
```

### 3. Code Change Deployment
```
Developer
    ↓
[Commits Code to Git]
    ↓
[Pushes to GitHub]
    ↓
Git Repository
    ↓
ArgoCD (watches repo)
    ↓
[Detects Change]
    ↓
[Auto-Sync Enabled]
    ↓
[Applies to Kubernetes]
    ↓
[Updates Running Pods]
    ↓
Backstage Shows New Status
```

## Network Flow

### Local Development
```
Browser
    │
    │ http://backstage.localhost
    ↓
127.0.0.1 (Docker Desktop)
    │
    ↓
NGINX Ingress Pod
    │
    ├─→ backstage.localhost → backstage.backstage:7007
    │                              ↓
    │                         [Backstage Pod]
    │                              ↓
    │                         [PostgreSQL Pod]
    │
    └─→ argocd.localhost → argocd-server.argocd:80
                                ↓
                           [ArgoCD Pod]
```

### Production
```
Internet
    │
    │ https://backstage.yourcompany.com
    ↓
Load Balancer (Azure/AWS)
    │
    ↓
NGINX Ingress Controller
    │ (SSL Termination)
    │
    ├─→ backstage.yourcompany.com → backstage:7007
    │                                    ↓
    │                              [Backstage Pods]
    │                                (Replicas: 3)
    │                                    ↓
    │                              [PostgreSQL]
    │                                (HA Setup)
    │
    └─→ argocd.yourcompany.com → argocd-server:80
                                      ↓
                                 [ArgoCD Pods]
                                  (Replicas: 3)
```

## GitOps App-of-Apps Pattern

### Bootstrap Flow
```
Step 1: Manual Bootstrap
    kubectl apply -f bootstrap.yaml
         ↓
    Creates "root-app" in ArgoCD
         ↓
    root-app watches gitops/app-of-apps/

Step 2: Root App Deploys
    root-app
         ↓
    ┌────┴────┬─────────────┐
    ↓         ↓             ↓
appprojects  platform-apps  [future apps]
    ↓
Creates Projects

Step 3: Platform Apps Deploy
    platform-apps.yaml
         ↓
    ┌────┴────┬──────────┬─────────┐
    ↓         ↓          ↓         ↓
  argocd  ingress-nginx namespaces backstage
  (self)
    ↓         ↓          ↓         ↓
  [Running] [Running] [Running] [Running]

Step 4: Applications Deploy
    gitops/applications/*.yaml
         ↓
    ┌────┴────┬──────────┐
    ↓         ↓          ↓
sample-app  app-2     app-3
    ↓         ↓          ↓
[Running] [Running] [Running]
```

### Git Repository Structure
```
idp/ (Git Repository)
│
├── gitops/
│   ├── app-of-apps/          ← ArgoCD watches this
│   │   ├── bootstrap.yaml    ← Apply manually ONCE
│   │   ├── appprojects.yaml  ← Auto-deployed by root-app
│   │   └── platform-apps.yaml← Auto-deployed by root-app
│   │
│   ├── applications/         ← App definitions
│   │   ├── sample-app.yaml
│   │   └── my-app.yaml
│   │
│   └── overlays/             ← Environment configs
│       ├── dev/
│       ├── staging/
│       └── prod/
│
└── infrastructure/
    └── kubernetes/           ← Actual manifests
        ├── argocd/
        ├── backstage/
        ├── ingress/
        └── namespaces/
```

## Deployment States

### Initial State (Empty Cluster)
```
┌─────────────────────┐
│   Empty Cluster     │
│                     │
│  (Just Kubernetes)  │
└─────────────────────┘
```

### After ArgoCD Installation
```
┌─────────────────────┐
│   Cluster           │
│                     │
│  ┌───────────────┐  │
│  │    ArgoCD     │  │
│  │   (Manual)    │  │
│  └───────────────┘  │
└─────────────────────┘
```

### After Bootstrap
```
┌─────────────────────┐
│   Cluster           │
│                     │
│  ┌───────────────┐  │
│  │    ArgoCD     │  │
│  └───────────────┘  │
│         ↓           │
│  ┌───────────────┐  │
│  │   Root App    │  │
│  │  (Watches     │  │
│  │   app-of-apps)│  │
│  └───────────────┘  │
└─────────────────────┘
```

### Final State (Full IDP)
```
┌──────────────────────────────────┐
│   Full IDP Cluster               │
│                                  │
│  ┌────────────┐  ┌────────────┐ │
│  │  ArgoCD    │←─│  Root App  │ │
│  │ (self-mgmt)│  │            │ │
│  └────────────┘  └────────────┘ │
│                                  │
│  ┌────────────┐  ┌────────────┐ │
│  │ Backstage  │  │   Ingress  │ │
│  │            │  │            │ │
│  └────────────┘  └────────────┘ │
│                                  │
│  ┌────────────┐  ┌────────────┐ │
│  │Sample App  │  │  App 2     │ │
│  │            │  │            │ │
│  └────────────┘  └────────────┘ │
└──────────────────────────────────┘
```

## Security Boundaries

### ArgoCD Projects
```
┌─────────────────────────────────────────┐
│         ArgoCD RBAC Structure           │
├─────────────────────────────────────────┤
│                                         │
│  ┌─────────────────────────────────┐   │
│  │   Platform Project              │   │
│  │   (Full cluster access)         │   │
│  │                                 │   │
│  │   • ArgoCD                      │   │
│  │   • Backstage                   │   │
│  │   • Ingress                     │   │
│  │   • Namespaces                  │   │
│  └─────────────────────────────────┘   │
│                                         │
│  ┌─────────────────────────────────┐   │
│  │   Applications Project          │   │
│  │   (Limited to app namespaces)   │   │
│  │                                 │   │
│  │   • sample-app                  │   │
│  │   • my-app                      │   │
│  │   • team-apps                   │   │
│  └─────────────────────────────────┘   │
└─────────────────────────────────────────┘
```

## Summary

### What You Have Now
✅ Simple, clean architecture  
✅ Industry-standard IDP  
✅ Backstage as single portal  
✅ ArgoCD for GitOps  
✅ NGINX for routing  

### What You Don't Have
❌ Confusing multiple portals  
❌ Redundant abstraction layers  
❌ Hardcoded data  
❌ Unnecessary complexity  

### The Core Principle
```
Developer → Backstage → Everything Else

Backstage is the interface.
ArgoCD is the engine.
Kubernetes is the platform.
```

**Simple. Powerful. Production-Ready.**
