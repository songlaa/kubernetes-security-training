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
echo "Creating a new kind cluster..."
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
sleep 30

# Step 3: Define the SSH Pod and Service configuration
echo "Creating your reverse shell pod..."
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
      "apt-get update && apt-get install -y openssh-server masscan iproute2 dnsutils libpcap-dev curl netcat-traditional iputils-ping && \
      echo 'root:${ROOT_PASSWORD}' | chpasswd && \
      echo 'PermitRootLogin yes' >> /etc/ssh/sshd_config && \
      service ssh start && tail -f /dev/null"
    ]
    ports:
    - containerPort: 22
EOF

# Step 4: Create a NodePort Service to expose SSH outside of `kind`
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
echo "Waiting for pod to be ready..."
kubectl wait --for=condition=ready pod/${POD_NAME} -n ${NAMESPACE} --timeout=120s

# Step 6: Get the kind control-plane IP
KIND_NODE_IP=$(docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' ${CLUSTER_NAME}-control-plane)
if [ -z "$KIND_NODE_IP" ]; then
  echo "Could not determine kind node IP. Make sure kind is running. Rerun the script."
  exit 1
fi

# Install Kubernetes Dashboard with unsecure skip login and extended roles
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Namespace
metadata:
  name: kubernetes-dashboard

---

apiVersion: v1
kind: ServiceAccount
metadata:
  labels:
    k8s-app: kubernetes-dashboard
  name: kubernetes-dashboard
  namespace: kubernetes-dashboard

---

kind: Service
apiVersion: v1
metadata:
  labels:
    k8s-app: kubernetes-dashboard
  name: kubernetes-dashboard
  namespace: kubernetes-dashboard
spec:
  clusterIP: 10.96.0.99 
  ports:
    - name: https
      port: 443
      targetPort: 8443
    - name: http
      port: 80
      targetPort: 9090
  selector:
    k8s-app: kubernetes-dashboard

---

apiVersion: v1
kind: Secret
metadata:
  labels:
    k8s-app: kubernetes-dashboard
  name: kubernetes-dashboard-certs
  namespace: kubernetes-dashboard
type: Opaque

---

apiVersion: v1
kind: Secret
metadata:
  labels:
    k8s-app: kubernetes-dashboard
  name: kubernetes-dashboard-csrf
  namespace: kubernetes-dashboard
type: Opaque
data:
  csrf: ""

---

apiVersion: v1
kind: Secret
metadata:
  labels:
    k8s-app: kubernetes-dashboard
  name: kubernetes-dashboard-key-holder
  namespace: kubernetes-dashboard
type: Opaque

---

kind: ConfigMap
apiVersion: v1
metadata:
  labels:
    k8s-app: kubernetes-dashboard
  name: kubernetes-dashboard-settings
  namespace: kubernetes-dashboard

---

kind: Role
apiVersion: rbac.authorization.k8s.io/v1
metadata:
  labels:
    k8s-app: kubernetes-dashboard
  name: kubernetes-dashboard
  namespace: kubernetes-dashboard
rules:
  # Allow Dashboard to get, update and delete Dashboard exclusive secrets.
  - apiGroups: [""]
    resources: ["secrets"]
    resourceNames: ["kubernetes-dashboard-key-holder", "kubernetes-dashboard-certs", "kubernetes-dashboard-csrf"]
    verbs: ["get", "update", "delete"]
    # Allow Dashboard to get and update 'kubernetes-dashboard-settings' config map.
  - apiGroups: [""]
    resources: ["configmaps"]
    resourceNames: ["kubernetes-dashboard-settings"]
    verbs: ["get", "update"]
    # Allow Dashboard to get metrics.
  - apiGroups: [""]
    resources: ["services"]
    resourceNames: ["heapster", "dashboard-metrics-scraper"]
    verbs: ["proxy"]
  - apiGroups: [""]
    resources: ["services/proxy"]
    resourceNames: ["heapster", "http:heapster:", "https:heapster:", "dashboard-metrics-scraper", "http:dashboard-metrics-scraper"]
    verbs: ["get"]

---

kind: ClusterRole
apiVersion: rbac.authorization.k8s.io/v1
metadata:
  labels:
    k8s-app: kubernetes-dashboard
  name: kubernetes-dashboard
rules:
  # Allow Metrics Scraper to get metrics from the Metrics server
  - apiGroups: ["metrics.k8s.io"]
    resources: ["pods", "nodes"]
    verbs: ["get", "list", "watch"]

---

apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  labels:
    k8s-app: kubernetes-dashboard
  name: kubernetes-dashboard
  namespace: kubernetes-dashboard
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: Role
  name: kubernetes-dashboard
subjects:
  - kind: ServiceAccount
    name: kubernetes-dashboard
    namespace: kubernetes-dashboard

---

apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: kubernetes-dashboard
  namespace: kubernetes-dashboard
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: kubernetes-dashboard
subjects:
  - kind: ServiceAccount
    name: kubernetes-dashboard
    namespace: kubernetes-dashboard

---

kind: Deployment
apiVersion: apps/v1
metadata:
  labels:
    k8s-app: kubernetes-dashboard
  name: kubernetes-dashboard
  namespace: kubernetes-dashboard
spec:
  replicas: 1
  revisionHistoryLimit: 10
  selector:
    matchLabels:
      k8s-app: kubernetes-dashboard
  template:
    metadata:
      labels:
        k8s-app: kubernetes-dashboard
    spec:
      containers:
        - name: kubernetes-dashboard
          image: kubernetesui/dashboard:v2.2.0
          imagePullPolicy: Always
          ports:
            - containerPort: 8443
              protocol: TCP
            - containerPort: 9090
              protocol: TCP  
          args:
            #- --auto-generate-certificates
            - --namespace=kubernetes-dashboard
            - --enable-skip-login
            - --disable-settings-authorizer
            - --enable-insecure-login
            - --insecure-bind-address=0.0.0.0
            # Uncomment the following line to manually specify Kubernetes API server Host
            # If not specified, Dashboard will attempt to auto discover the API server and connect
            # to it. Uncomment only if the default does not work.
            # - --apiserver-host=http://my-address:port
          volumeMounts:
            - name: kubernetes-dashboard-certs
              mountPath: /certs
              # Create on-disk volume to store exec logs
            - mountPath: /tmp
              name: tmp-volume
          livenessProbe:
            httpGet:
              scheme: HTTP
              path: /
              port: 9090
            initialDelaySeconds: 30
            timeoutSeconds: 30
          securityContext:
            allowPrivilegeEscalation: false
            readOnlyRootFilesystem: true
            runAsUser: 1001
            runAsGroup: 2001
      volumes:
        - name: kubernetes-dashboard-certs
          secret:
            secretName: kubernetes-dashboard-certs
        - name: tmp-volume
          emptyDir: {}
      serviceAccountName: kubernetes-dashboard
      nodeSelector:
        "kubernetes.io/os": linux
      # Comment the following tolerations if Dashboard must not be deployed on master
      tolerations:
        - key: node-role.kubernetes.io/master
          effect: NoSchedule

---

kind: Service
apiVersion: v1
metadata:
  labels:
    k8s-app: dashboard-metrics-scraper
  name: dashboard-metrics-scraper
  namespace: kubernetes-dashboard
spec:
  ports:
    - port: 8000
      targetPort: 8000
  selector:
    k8s-app: dashboard-metrics-scraper

---

kind: Deployment
apiVersion: apps/v1
metadata:
  labels:
    k8s-app: dashboard-metrics-scraper
  name: dashboard-metrics-scraper
  namespace: kubernetes-dashboard
spec:
  replicas: 1
  revisionHistoryLimit: 10
  selector:
    matchLabels:
      k8s-app: dashboard-metrics-scraper
  template:
    metadata:
      labels:
        k8s-app: dashboard-metrics-scraper
      annotations:
        seccomp.security.alpha.kubernetes.io/pod: 'runtime/default'
    spec:
      containers:
        - name: dashboard-metrics-scraper
          image: kubernetesui/metrics-scraper:v1.0.6
          ports:
            - containerPort: 8000
              protocol: TCP
          livenessProbe:
            httpGet:
              scheme: HTTP
              path: /
              port: 8000
            initialDelaySeconds: 30
            timeoutSeconds: 30
          volumeMounts:
          - mountPath: /tmp
            name: tmp-volume
          securityContext:
            allowPrivilegeEscalation: false
            readOnlyRootFilesystem: true
            runAsUser: 1001
            runAsGroup: 2001
      serviceAccountName: kubernetes-dashboard
      nodeSelector:
        "kubernetes.io/os": linux
      # Comment the following tolerations if Dashboard must not be deployed on master
      tolerations:
        - key: node-role.kubernetes.io/master
          effect: NoSchedule
      volumes:
        - name: tmp-volume
          emptyDir: {}

---

apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  namespace: kubernetes-dashboard
  name: pod-manager
rules:
- apiGroups: [""]
  resources: ["pods"]
  verbs: ["list", "create", "get"]
- apiGroups: [""]
  resources: ["pods/exec"]
  verbs: ["create"]
- apiGroups:
  - rbac.authorization.k8s.io
  resources:
  - rolebindings
  - roles
  verbs:
  - get
  - list

---

apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: pod-manager-binding
  namespace: kubernetes-dashboard
subjects:
- kind: ServiceAccount
  name: kubernetes-dashboard
  namespace: kubernetes-dashboard
roleRef:
  kind: Role
  name: pod-manager
  apiGroup: rbac.authorization.k8s.io
EOF



#create  ctf flags
kubectl run pod songlaa-advanced --image=alpine --restart=Never --namespace=kubernetes-dashboard -- /bin/sh -c "echo 'songlaa{1n53cur3_k1nd_1n5t4ll}' > /flag1.txt"

kubectl create ns songlaa-expert
docker build -t index:stable -<<EOF
  FROM nginx
  RUN echo TmV2ZXIgdXNlIHVuYXV0aGVudGljYXRlZCBzZXJ2aWNlcyBzb25nbGFhe3ZlcnkgZ29vZH0K | base64 -d > /usr/share/nginx/html/index.html
EOF
  kind load docker-image index:stable
# create deployment and service for index
cat <<EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: index-deployment
spec:
  replicas: 1
  selector:
    matchLabels:
      app: index-server
  template:
    metadata:
      labels:
        app: index-server
    spec:
      containers:
        - name: index-server
          image: index:stable
          ports:
            - name: http-port
              containerPort: 80
---
apiVersion: v1
kind: Service
metadata:
  name: index-service
spec:
  clusterIP: 10.96.0.66
  ports:
    - name: http
      port: 80
      targetPort: http-port
      protocol: TCP
  selector:
    app: index-server
---
EOF



# Final instructions for SSH connection
echo "The SSH server is available at ${KIND_NODE_IP}:${NODE_PORT}"
echo "Connect using the following command:"
echo "ssh root@${KIND_NODE_IP} -p ${NODE_PORT}"
echo "Password: ${ROOT_PASSWORD}"


