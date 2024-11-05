#! /bin/bash

# !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!! #
#  ____  ____   ___ ___ _     _____ ____        _    _     _____ ____ _____  #
# / ___||  _ \ / _ \_ _| |   | ____|  _ \      / \  | |   | ____|  _ \_   _| #
# \___ \| |_) | | | | || |   |  _| | |_) |    / _ \ | |   |  _| | |_) || |   #
#  ___) |  __/| |_| | || |___| |___|  _ <    / ___ \| |___| |___|  _ < | |   #
# |____/|_|    \___/___|_____|_____|_| \_\  /_/   \_\_____|_____|_| \_\|_|   #
#                                                                            #
# !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!! #
kind delete cluster || true
kind create cluster
echo "Waiting for kind cluster to be ready..."
sleep 60 # give kind some time
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: reverse-shell
  labels:
    app: reverse-shell
spec:
  containers:
  - name: ubuntu
    image: ubuntu:22.04
    command: ["sleep", "infinity"]
    securityContext:
      privileged: true
  restartPolicy: Never
EOF
docker run -d --name my-ubuntu-container ubuntu bash -c "echo c29uZ2xhYS1iZWdpbm5lcgo= | base64 -d > /tmp/secure && tail -f /dev/null"
sleep 10 # give pods some time
echo"here is your shell:"
kubectl exec -it reverse-shell -- sh 