#!/bin/bash
set -euo pipefail

# Create namespace
kubectl create ns mysql

# Create a directory for MySQL data on the node
mkdir -p /mnt/mysql-data

# Create a PersistentVolume with Retain policy (simulating existing data)
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: PersistentVolume
metadata:
  name: mysql-pv-retain
  labels:
    type: local
spec:
  storageClassName: manual
  capacity:
    storage: 500Mi
  accessModes:
    - ReadWriteOnce
  persistentVolumeReclaimPolicy: Retain
  hostPath:
    path: "/mnt/mysql-data"
EOF

# Create some dummy data to simulate existing database files
cat <<EOF > /mnt/mysql-data/IMPORTANT_DATA.txt
===========================================
CRITICAL CUSTOMER DATABASE DATA
===========================================
This file represents existing MySQL data
that must NOT be lost during recovery.

Customer Records: 50,000+
Transaction History: 2 years
Last Backup: 3 days ago

DO NOT DELETE - PRODUCTION DATA
===========================================
EOF

echo "Existing database data preserved" > /mnt/mysql-data/.data_exists

# Wait for PV to be available
sleep 3

# Create the MySQL Deployment manifest WITHOUT volume mount (student needs to add it)
cat <<'EOF' > ~/mysql-deploy.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: mysql
  namespace: mysql
  labels:
    app: mysql
    tier: database
spec:
  replicas: 1
  selector:
    matchLabels:
      app: mysql
  template:
    metadata:
      labels:
        app: mysql
        tier: database
    spec:
      containers:
        - name: mysql
          image: mysql:5.7
          env:
            - name: MYSQL_ROOT_PASSWORD
              value: "rootpassword123"
            - name: MYSQL_DATABASE
              value: "customerdb"
          ports:
            - containerPort: 3306
              name: mysql
EOF


k apply -f ~/mysql-deploy.yaml

echo "✅ Setup complete!"
echo ""
echo "📊 Current Status:"
echo "  ✅ PersistentVolume 'mysql-pv-retain' is available with existing data"
echo "  ✅ MySQL Deployment manifest is ready at ~/mysql-deploy.yaml"
echo "  ⚠️  MySQL Deployment has been deleted (simulating the incident)"
echo "  ⚠️  You need to create a PVC and update the Deployment to use it"
echo ""
echo "🎯 Your Mission: Restore MySQL without losing data!"
