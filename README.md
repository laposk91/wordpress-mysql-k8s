# 🖥️ 3-Tier WordPress Deployment on Kubernetes

This project demonstrates a complete 3-tier architecture for deploying a WordPress application on Kubernetes. The deployment includes:

- **Frontend (Web Layer)**: WordPress container.
- **Backend (Application Layer)**: PHP and Apache via WordPress image.
- **Database Layer**: MySQL database running in a separate Pod.

---

## 🗂️ Project Structure

├── wordpress-deployment.yaml # WordPress Deployment with environment variables from ConfigMap and Secret

├── mysql-deployment.yaml # MySQL Deployment

├── wordpress-service.yaml # LoadBalancer/NodePort service for WordPress

├── mysql-service.yaml # ClusterIP service for MySQL

├── wp-configmap.yaml # ConfigMap for database credentials (except password)

├── mysql-secret.yaml # Secret for MySQL password

├── wordpress-pvc.yaml # Persistent Volume Claim for WordPress

├── mysql-pvc.yaml # Persistent Volume Claim for MySQL



## 📦 Components

### 🔧 ConfigMap

Stores non-sensitive configuration data like:
```yaml
WORDPRESS_DB_HOST: mysql-service
WORDPRESS_DB_NAME: wordpress
WORDPRESS_DB_USER: myuser
🔐 Secret
Stores sensitive information like:

yaml
Copy
Edit
MYSQL_PASSWORD: mypasswd
🐳 WordPress Deployment
Uses the wordpress:latest Docker image.

Environment variables sourced from ConfigMap and Secret.

Mounts a PersistentVolume at /var/www/html.

🐬 MySQL Deployment
Uses the mysql:5.7 Docker image.

Reads environment variables from Secret.

Mounts a PersistentVolume at /var/lib/mysql.

🌐 Services
wordpress-service: Exposes WordPress to external traffic via LoadBalancer or NodePort.

mysql-service: ClusterIP service accessible only within the cluster.

🚀 Deployment Steps
Create ConfigMap & Secret

kubectl apply -f wp-configmap.yaml
kubectl apply -f mysql-secret.yaml
Deploy Persistent Volume Claims

kubectl apply -f mysql-pvc.yaml
kubectl apply -f wordpress-pvc.yaml
Deploy MySQL

kubectl apply -f mysql-deployment.yaml
kubectl apply -f mysql-service.yaml
Deploy WordPress

kubectl apply -f wordpress-deployment.yaml
kubectl apply -f wordpress-service.yaml
Check Pods and Services

kubectl get pods
kubectl get svc
Access WordPress

If using NodePort, visit:

php-template
Copy
Edit
http://<NodeIP>:<NodePort>
If using LoadBalancer, visit the external IP once it's available:

cpp
Copy
Edit
http://<LoadBalancer-IP>
🛠️ Troubleshooting
"Error establishing a database connection"

Check WORDPRESS_DB_HOST value in ConfigMap.

Ensure MySQL Pod is running and the user has correct privileges.

Verify MySQL password in Secret matches the MySQL Deployment.

Access Denied for User

Exec into MySQL Pod and run:

bash
Copy
Edit
mysql -u root -p
SHOW GRANTS FOR 'myuser'@'%';
📄 Requirements
Kubernetes cluster (minikube, kind, or cloud-managed)

kubectl installed

Docker (for local image builds if needed)

📌 Notes
This setup is for educational/demo purposes.

For production, consider using:

TLS/SSL with Ingress

Helm Charts

StatefulSets for MySQL

External storage provisioners

👨‍💻 Author
Created by Alabi
