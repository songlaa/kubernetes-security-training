#!/bin/bash

# Set variables
CLUSTER_NAME="kind"
POD_NAME="ssh-pod"
SERVICE_NAME="ssh-service"
NAMESPACE="default"
ROOT_PASSWORD="songlaa"
NODE_PORT=30022
HOST_PORT=30022

# Step 1: Delete any existing kind cluster
echo "Deleting existing kind cluster..."
kind delete cluster --name ${CLUSTER_NAME}

# Step 2: Create a new kind cluster with NodePort binding to host port
echo "Creating a new kind cluster with NodePort binding..."
cat <<EOF | kind create cluster --name ${CLUSTER_NAME} --config=-
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
nodes:
  - role: control-plane
    extraPortMappings:
      - containerPort: ${NODE_PORT}
        hostPort: ${HOST_PORT}
        protocol: TCP
EOF

# Wait for kind cluster to be fully ready
echo "Waiting for kind cluster to be ready..."
sleep 5

# Step 3: Define the SSH Pod and Service configuration
echo "Creating SSH Pod..."
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: ${POD_NAME}
  namespace: ${NAMESPACE}
  labels:
    app: ssh
spec:
  containers:
  - name: ssh-container
    image: ubuntu:latest
    command: ["/bin/bash", "-c", "--"]
    args: [
      "apt-get update && apt-get install -y openssh-server masscan dnsutils libpcap-dev curl netcat-traditional iputils-ping && \
      echo 'root:${ROOT_PASSWORD}' | chpasswd && \
      echo 'PermitRootLogin yes' >> /etc/ssh/sshd_config && \
      service ssh start && tail -f /dev/null"
    ]
    ports:
    - containerPort: 22
EOF

# Step 4: Create a NodePort Service to expose SSH outside of `kind`
echo "Creating NodePort service..."
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Service
metadata:
  name: ${SERVICE_NAME}
  namespace: ${NAMESPACE}
spec:
  selector:
    app: ssh
  ports:
    - protocol: TCP
      port: 22
      targetPort: 22
      nodePort: ${NODE_PORT}
  type: NodePort
EOF

# Step 5: Wait for the Pod to be Ready
echo "Waiting for the SSH pod to be ready..."
kubectl wait --for=condition=ready pod/${POD_NAME} -n ${NAMESPACE} --timeout=120s

# Step 6: Get the kind control-plane IP
KIND_NODE_IP=$(docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' ${CLUSTER_NAME}-control-plane)
if [ -z "$KIND_NODE_IP" ]; then
  echo "Could not determine kind node IP. Make sure kind is running."
  exit 1
fi

# Final instructions for SSH connection
echo "The SSH server is available at ${KIND_NODE_IP}:${NODE_PORT}"
echo "Connect using the following command:"
echo "ssh root@${KIND_NODE_IP} -p ${NODE_PORT}"
echo "Password: ${ROOT_PASSWORD}"


