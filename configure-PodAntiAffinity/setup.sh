#!/bin/bash
set -euo pipefail

# Label nodes with zone topology
kubectl label node controlplane topology.kubernetes.io/zone=zone-a
kubectl label node node01 topology.kubernetes.io/zone=zone-b

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
EOF

kubectl apply -f /mongodb/mongodb-stateful.yaml

sleep 5

# Create the Service manifest separately
cat <<'EOF' > /mongodb/mongodb-service.yaml
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

# Apply the service first
kubectl apply -f /mongodb/mongodb-service.yaml



# Wait for StatefulSet to be created
sleep 15





echo "✅ Setup complete! MongoDB StatefulSet manifest is ready at /mongodb/mongodb-stateful.yaml"
echo "✅ MongoDB Service is already created at /mongodb/mongodb-service.yaml"
echo "⚠️  Current configuration does NOT enforce pod anti-affinity - your task is to add it!"
