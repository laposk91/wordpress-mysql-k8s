
#!/bin/bash
# scripts/deploy.sh - Complete WordPress-MySQL Kubernetes Deployment Script

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
NFS_SERVER_IP=${NFS_SERVER_IP:-"192.168.1.100"}
MYSQL_ROOT_PASSWORD=${MYSQL_ROOT_PASSWORD:-"StrongRootP@ss123!"}
MYSQL_DATABASE=${MYSQL_DATABASE:-"wordpress_db"}
MYSQL_USER=${MYSQL_USER:-"wp_user"}
MYSQL_PASSWORD=${MYSQL_PASSWORD:-"SecureWP@ss456!"}

print_header() {
    echo -e "${BLUE}================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}================================${NC}"
}

print_status() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

check_prerequisites() {
    print_header "Checking Prerequisites"
    
    # Check kubectl
    if ! command -v kubectl &> /dev/null; then
        print_error "kubectl is not installed or not in PATH"
        exit 1
    fi
    print_status "kubectl is installed"
    
    # Check cluster connectivity
    if ! kubectl cluster-info &> /dev/null; then
        print_error "Cannot connect to Kubernetes cluster"
        exit 1
    fi
    print_status "Kubernetes cluster is accessible"
    
    # Check NFS server connectivity
    if command -v showmount &> /dev/null; then
        if showmount -e "$NFS_SERVER_IP" &> /dev/null; then
            print_status "NFS server $NFS_SERVER_IP is accessible"
        else
            print_warning "Cannot verify NFS server connectivity"
        fi
    else
        print_warning "showmount not available, skipping NFS check"
    fi
}

deploy_kubernetes_dashboard() {
    print_header "Deploying Kubernetes Dashboard"
    
    # Check if dashboard already exists
    if kubectl get namespace kubernetes-dashboard &> /dev/null; then
        print_status "Kubernetes dashboard already exists"
    else
        kubectl apply -f https://raw.githubusercontent.com/kubernetes/dashboard/v2.7.0/aio/deploy/recommended.yaml
        print_status "Kubernetes dashboard deployed"
    fi
    
    # Wait for dashboard to be ready
    kubectl wait --for=condition=available --timeout=300s deployment/kubernetes-dashboard -n kubernetes-dashboard
    print_status "Kubernetes dashboard is ready"
}

prepare_storage_config() {
    print_header "Preparing Storage Configuration"
    
    # Create temporary file with NFS server IP replaced
    sed "s/<NFS_SERVER_IP>/$NFS_SERVER_IP/g" wordpress-k8s-deployment.yaml > /tmp/wordpress-deployment.yaml
    print_status "Storage configuration prepared with NFS server: $NFS_SERVER_IP"
}

create_secrets() {
    print_header "Creating Secrets"
    
    # Delete existing secret if it exists
    kubectl delete secret mysql-secret -n wordpress-mysql --ignore-not-found=true
    
    # Create MySQL secret
    kubectl create secret generic mysql-secret \
        --from-literal=root-password="$MYSQL_ROOT_PASSWORD" \
        --from-literal=database="$MYSQL_DATABASE" \
        --from-literal=username="$MYSQL_USER" \
        --from-literal=password="$MYSQL_PASSWORD" \
        --namespace=wordpress-mysql
    
    print_status "MySQL secrets created"
}

deploy_infrastructure() {
    print_header "Deploying Infrastructure"
    
    # Apply the main deployment file
    kubectl apply -f /tmp/wordpress-deployment.yaml
    print_status "Infrastructure components deployed"
    
    # Wait for namespace to be ready
    sleep 5
    
    # Create secrets after namespace is created
    create_secrets
}

wait_for_deployment() {
    print_header "Waiting for Deployments"
    
    # Wait for MySQL deployment
    echo "Waiting for MySQL deployment..."
    kubectl wait --for=condition=available --timeout=600s deployment/mysql -n wordpress-mysql
    print_status "MySQL deployment is ready"
    
    # Wait for WordPress deployment
    echo "Waiting for WordPress deployment..."
    kubectl wait --for=condition=available --timeout=600s deployment/wordpress -n wordpress-mysql
    print_status "WordPress deployment is ready"
}

display_access_info() {
    print_header "Access Information"
    
    # Get WordPress service info
    echo "WordPress Service:"
    kubectl get svc wordpress-service -n wordpress-mysql
    
    # Get LoadBalancer IP if available
    EXTERNAL_IP=$(kubectl get svc wordpress-service -n wordpress-mysql -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || echo "")
    
    if [ -n "$EXTERNAL_IP" ]; then
        echo -e "${GREEN}WordPress URL: http://$EXTERNAL_IP${NC}"
    else
        echo -e "${YELLOW}LoadBalancer IP not yet assigned. Use port-forward:${NC}"
        echo "kubectl port-forward svc/wordpress-service 8080:80 -n wordpress-mysql"
        echo "Then access: http://localhost:8080"
    fi
    
    echo ""
    echo "Kubernetes Dashboard:"
    echo "1. Get admin token:"
    echo "   kubectl -n kubernetes-dashboard create token admin-user"
    echo "2. Start proxy:"
    echo "   kubectl proxy --address='0.0.0.0' --accept-hosts='^*$'"
    echo "3. Access: http://localhost:8001/api/v1/namespaces/kubernetes-dashboard/services/https:kubernetes-dashboard:/proxy/"
}

main() {
    print_header "WordPress-MySQL Kubernetes Deployment"
    
    check_prerequisites
    deploy_kubernetes_dashboard
    prepare_storage_config
    deploy_infrastructure
    wait_for_deployment
    display_access_info
    
    print_header "Deployment Complete!"
    print_status "WordPress with MySQL is now running on Kubernetes"
    echo ""
    echo "Next steps:"
    echo "1. Access WordPress and complete the installation"
    echo "2. Configure your WordPress site"
    echo "3. Monitor the deployment using Kubernetes Dashboard"
    echo ""
    echo "Use './scripts/verify.sh' to check deployment health"
    echo "Use './scripts/cleanup.sh' to remove the deployment"
}
