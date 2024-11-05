kind delete cluster || true
kind create cluster
echo "wait 1 minute for kind to be ready"
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