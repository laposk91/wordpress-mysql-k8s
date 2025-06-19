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

kubectl configured and connected to your cluster

NFS server with network access to the cluster

Minimum 4GB RAM, 2 CPU cores available in the cluster

1. Prepare Your Environment
   
First, ensure your NFS server is set up and accessible:

Test NFS server connectivity

showmount -e <YOUR_NFS_SERVER_IP>

# Create NFS export directories

sudo mkdir -p /nfs/mysql /nfs/wordpress

sudo chown nobody:nogroup /nfs/mysql /nfs/wordpress

sudo chmod 755 /nfs/mysql /nfs/wordpress

2. Configure NFS Server IP

Update the deployment file with your NFS server IP:

Replace <NFS_SERVER_IP> with your actual NFS server IP

export NFS_SERVER_IP="192.168.1.100"  # Replace with your IP

sed -i "s/<NFS_SERVER_IP>/$NFS_SERVER_IP/g" wordpress-k8s-deployment.yaml

3. Deploy the Application

Make the scripts executable and run the deployment:

chmod +x scripts/*.sh

🔧 Installation

Clone and Navigate

cd wordpress-mysql-k8s

Configure NFS Server

bash# Update NFS_SERVER_IP in storage-volumes.yaml

sed -i 's/<NFS_SERVER_IP>/YOUR_NFS_IP/g' storage-volumes.yaml

Deploy Infrastructure

./deploy.sh

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
