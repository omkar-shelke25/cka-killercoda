#!/bin/bash
set -euo pipefail

# Label nodes with zone topology
kubectl label node controlplane topology.kubernetes.io/zone=zone-a
kubectl label node node01 topology.kubernetes.io/zone=zone-b

# Remove taint from controlplane to allow scheduling
kubectl taint no controlplane node-role.kubernetes.io/control-plane:NoSchedule-

# Wait for cluster to stabilize
sleep 7

# Create namespace
kubectl create ns database-services

# Create directory structure
mkdir -p /mongodb

# Create the StatefulSet manifest WITHOUT PodAntiAffinity (student needs to add it)
cat <<'EOF' > /mongodb/mongodb-stateful.yaml
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: mongodb-users-db
  namespace: database-services
  labels:
    app: mongodb-users-db
    environment: production
    team: data-platform
  annotations:
    owner: "db-team"
spec:
  serviceName: "mongodb"
  replicas: 2
  selector:
    matchLabels:
      app: mongodb-users-db
  template:
    metadata:
      labels:
        app: mongodb-users-db
        environment: production
      annotations:
        description: "MongoDB users database"
    spec:
      containers:
        - name: mongodb
          image: mongo:5.0
          ports:
            - containerPort: 27017
              name: mongodb
          volumeMounts:
            - name: mongodb-data
              mountPath: /data/db
  volumeClaimTemplates:
    - metadata:
        name: mongodb-data
        labels:
          app: mongodb-users-db
      spec:
        storageClassName: local-path
        accessModes: ["ReadWriteOnce"]
        resources:
          requests:
            storage: 500Mi
---
apiVersion: v1
kind: Service
metadata:
  name: mongodb
  namespace: database-services
  labels:
    app: mongodb-users-db
spec:
  clusterIP: None
  ports:
    - port: 27017
      name: mongodb
  selector:
    app: mongodb-users-db
EOF

# Apply the initial manifest (without anti-affinity)
kubectl apply -f /mongodb/mongodb-stateful.yaml

# Wait for StatefulSet to be created
sleep 5

echo "✅ Setup complete! MongoDB StatefulSet manifest is ready at /mongodb/mongodb-stateful.yaml"
echo "⚠️  Current configuration does NOT enforce pod anti-affinity - your task is to add it!"
