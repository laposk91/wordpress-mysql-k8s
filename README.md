📋 Overview
Production-ready Kubernetes deployment of a multi-tier WordPress application with MySQL backend, featuring enterprise-grade security, 
persistent storage, and comprehensive monitoring through Kubernetes Dashboard.

📁 Project Structure

wordpress-mysql-k8s/

├── 01-infrastructure/

│   ├── namespace-config.yaml

│   └── storage-volumes.yaml

├── 02-security/

│   ├── dashboard-admin.yaml        

│   ├── application-config.yaml      

│   └── network-policies.yaml         

├── 03-database/

│   └── mysql-deployment.yaml        

├── 04-application/

│   └── wordpress-deployment.yaml      

├── scripts/

│   ├── deploy.sh                      

│   ├── cleanup.sh                     

│   └── verify.sh                     

└── README.md


🚀 Quick Start
Prerequisites

Kubernetes cluster (v1.25+)
kubectl configured
NFS server with network access
Minimum 4GB RAM, 2 CPU cores

🔧 Installation

Clone and Navigate
cd wordpress-mysql-k8s

Configure NFS Server
bash# Update NFS_SERVER_IP in storage-volumes.yaml
sed -i 's/<NFS_SERVER_IP>/YOUR_NFS_IP/g' storage-volumes.yaml

Deploy Infrastructure
bash./deploy.sh

Access Application
bash# Get WordPress URL
kubectl get svc wordpress-service -n wordpress-mysql

# Access Dashboard
kubectl proxy --address='0.0.0.0' --accept-hosts='^*$'
# Open: http://localhost:8001/api/v1/namespaces/kubernetes-dashboard/services/https:kubernetes-dashboard

🚀 Deployment Commands
Automated Deployment
bash# Complete deployment
./scripts/deploy.sh

# Verify deployment
./scripts/verify.sh

# Clean up resources
./scripts/cleanup.sh
Manual Deployment
bash# 1. Infrastructure
kubectl apply -f 01-infrastructure/

# 2. Security & Configuration
kubectl apply -f 02-security/
kubectl create secret generic mysql-secret \
  --from-literal=root-password='StrongRootP@ss123!' \
  --from-literal=database='wordpress_db' \
  --from-literal=username='wp_user' \
  --from-literal=password='SecureWP@ss456!' \
  --namespace=wordpress-mysql

# 3. Database
kubectl apply -f 03-database/

# 4. Application
kubectl apply -f 04-application/
🔍 Monitoring & Verification
Health Checks
bash# Overall status
kubectl get all -n wordpress-mysql

# Pod logs
kubectl logs -f deployment/mysql -n wordpress-mysql
kubectl logs -f deployment/wordpress -n wordpress-mysql

# Service connectivity
kubectl get endpoints -n wordpress-mysql

# Resource usage
kubectl top pods -n wordpress-mysql

# Scale WordPress replicas
kubectl scale deployment wordpress --replicas=5 -n wordpress-mysql

# Auto-scaling (HPA)
kubectl autoscale deployment wordpress --cpu-percent=70 --min=2 --max=10 -n wordpress-mysql
