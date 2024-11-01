---
title: "Architecture and encryption"
weight: 2
sectionnumber: 3.2
---

In order to secure Kubernetes we want to understand its different components. For that, we install a minimal Kubernetes Distribution ourselves:

### {{% task %}} Install a Kubernetes Cluster

For this task we need to switch to a VM, there we will install a Kubernetes Cluster using [kind](https://kind.sigs.k8s.io/)

SSH into your VM: You find the relevant command in the file `welcome`

```
ssh -i /home/project/id-ecdsa <namespace>@159.69.155.196
```

Now download `kind`:

```bash
curl -Lo ./kind https://kind.sigs.k8s.io/dl/v0.24.0/kind-linux-amd64
chmod +x ./kind
sudo mv ./kind /usr/local/bin/kind
```

Similar to Kubernetes `kind` can be configured using a yaml resource, execute the command below to create the file `cluster.yaml`:

```yaml
cat <<EOF >> cluster.yaml
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
nodes:
- role: control-plane
- role: worker
EOF
```

To create a two-node closter please execute:

```bash
kind create cluster --config cluster.yaml
```

After a while, you should have a cluster running. Please check it with:

```bash
kubectl get nodes
```

The goal now is to identify our minimal moving parts in Kubernetes and address some security-relevant features. By using `kubectl` you did use the standard config `~/.kube/config`. If you are curious you can check the used cert and see which user you are and the address of the API Server.

You find the main control plane parts in the `kube-system` namespace:

```bash
kubectl -n kube-system get pods
```

Which will give you an output like this:

```
NAME                                         READY   STATUS    RESTARTS        AGE
NAME                                         READY   STATUS    RESTARTS   AGE
coredns-7db6d8ff4d-gdqhg                     1/1     Running   0          43s
coredns-7db6d8ff4d-zkfq4                     1/1     Running   0          43s
etcd-kind-control-plane                      1/1     Running   0          59s
kindnet-5w4n8                                1/1     Running   0          41s
kindnet-fqnhp                                1/1     Running   0          43s
kube-apiserver-kind-control-plane            1/1     Running   0          59s
kube-controller-manager-kind-control-plane   1/1     Running   0          59s
kube-proxy-2fmst                             1/1     Running   0          41s
kube-proxy-s7g8c                             1/1     Running   0          43s
kube-scheduler-kind-control-plane            1/1     Running   0          59s
```

The core services for Kubernetes are all here:

* etcd-kind-control-plane: etcd is a key-value store used by Kubernetes to store all cluster data, including configuration, state, and other critical data
* kindnet: kindnet is a CNI (Container Network Interface) plugin that handles networking for the Kind cluster.
* kube-apiserver-kind-control-plane: kube-apiserver is the central component of the control plane, which exposes the Kubernetes API. It processes requests and interacts with other control plane components.
* kube-controller-manager-kind-control-plane: kube-controller-manager runs controller processes that handle routine tasks like managing node states, replicas, and deployments.
* kube-proxy: enabling routing and load-balancing for traffic between services and pods in the cluster.
* kube-scheduler-kind-control-plane: kube-scheduler assigns pods to nodes based on resource availability and constraints. This is the component taking care of pod (re)starts.

### Kubernetes CIS Benchmark

We want to check our local Kubernetes Cluster using the CIS Kubernetes Benchmark which is a set of best practices and security guidelines developed by the Center for Internet Security (CIS) to help organizations secure their Kubernetes clusters. For this we use a tool named [kube-bench](https://github.com/aquasecurity/kube-bench) which should also be part of every kubernetes lifecycle pipeline-test.

### {{% task %}} Check your clusters security

We will run `kube-bench` directly in our Kubernetes cluster using a Kubernetes job:

```bash
kubectl apply -f https://raw.githubusercontent.com/aquasecurity/kube-bench/refs/heads/main/job.yaml
```

Wait for a few seconds for the job to complete

```bash
kubectl get pods
```

The results are held in the pod's logs (adjust the name)

```bash
kubectl logs kube-bench-fpwnt
```

We see that our `kind` cluster fails in the RBAC Section because it binds the users `kubernetes` and the group `kubeadm:cluster-admins` to the cluster-admin role to give it full privileges.
Check also the different warnings for other sections, for a lot we already have the knowledge to remediation the issues. What we have not yet played around with is `etcd`. Let's do that:

### {{% task %}} Read data in etcd

We learned that the state of our cluster is stored in `etcd`, in `kind` `etcd` runs inside the cluster see `etcd-kind-control-plane`. Let us demonstrate that we can read secrets if we have access to the database.

Create the secret first:

```bash
kubectl create secret generic my-secret --from-literal=username=myuser --from-literal=password=mypassword
```

Login the control plane `node` (which is a docker container in this example)

```bash
docker exec -it kind-control-plane bash
```

To access `etcd` you can use a tool named `etcdctl`. If it’s not installed, you may need to manually download and install `etcdctl` inside the container:

```bash
ETCD_VER=v3.4.34

GITHUB_URL=https://github.com/etcd-io/etcd/releases/download
DOWNLOAD_URL=${GITHUB_URL}

rm -f /tmp/etcd-${ETCD_VER}-linux-amd64.tar.gz
rm -rf /tmp/etcd-download-test && mkdir -p /tmp/etcd-download-test

curl -L ${DOWNLOAD_URL}/${ETCD_VER}/etcd-${ETCD_VER}-linux-amd64.tar.gz -o /tmp/etcd-${ETCD_VER}-linux-amd64.tar.gz
tar xzvf /tmp/etcd-${ETCD_VER}-linux-amd64.tar.gz -C /tmp/etcd-download-test --strip-components=1
rm -f /tmp/etcd-${ETCD_VER}-linux-amd64.tar.gz

cp /tmp/etcd-download-test/etcdctl /usr/local/bin/
etcdctl version
```

Set up environment variables**: To interact with `etcd`, you need to configure environment variables for `etcdctl`:

```bash
export ETCDCTL_API=3
export ETCDCTL_CACERT="/etc/kubernetes/pki/etcd/ca.crt"
export ETCDCTL_CERT="/etc/kubernetes/pki/etcd/server.crt"
export ETCDCTL_KEY="/etc/kubernetes/pki/etcd/server.key"
export ETCDCTL_ENDPOINTS="https://127.0.0.1:2379"
```

You can see that `etcd` communication is encrypted using a pki. The ports used are 2379 (client to server), 2380 (replications) and 2381 for metrics.

Now list the keys in `etcd` to find where the secret is stored:

```bash
etcdctl get "" --prefix --keys-only | grep my-secret
```

Use `etcdctl` to retrieve the secret data:

```bash
etcdctl get /registry/secrets/default/my-secret --print-value-only
```

This will return the Kubernetes Secret resource in its raw format, which includes the `data` section where the username and password are stored (base64 encoded).

We see:

* Interacting with `etcd` directly bypasses Kubernetes RBAC and can expose sensitive information (such as secrets). Ensure you have proper access controls and audit policies in place.
* Be careful when modifying or reading directly from `etcd`, as it is the core data store for Kubernetes.

### {{% task %}} Encrypt etcd

Let us improve security by encrypting the etcd database:

Still inside the pod create a file named `/etc/kubernetes/pki/encryption-config.yaml`. Here is how you can do it in one go without a editor:

```bash
cat <<EOF >> /etc/kubernetes/pki/encryption-config.yaml
apiVersion: apiserver.config.k8s.io/v1
kind: EncryptionConfiguration
resources:
  - resources:
      - secrets
    providers:
      - aescbc:
          keys:
            - name: key1
              secret: 8jgVX8G2tl2c0J/+wYrfPejGhZG3gVTdfJHMM1Y6Kvc=
      - identity: {}

EOF
```

The secret field is a base64-encoded 256-bit key. To enable encryption at rest, modify the kube-apiserver manifest to include the encryption provider configuration.
We add the necessary flag using `sed` in place editing

```bash
#check the file
cat /etc/kubernetes/manifests/kube-apiserver.yaml
#edit it
sed -i '/- kube-apiserver/a\    - --encryption-provider-config=/etc/kubernetes/pki/encryption-config.yaml' /etc/kubernetes/manifests/kube-apiserver.yaml
#check the difference
cat /etc/kubernetes/manifests/kube-apiserver.yaml
```

Kubernetes will automatically restart the kube-apiserver since it's running as a static pod.

Recreate the secret to ensure it is encrypted (you need to open a new terminal and connect to the VM again). If you get errors wait a while until etcd recovers:

```bash
kubectl get secret my-secret -n default -o yaml | kubectl apply -f -
```

Now check if you can still read the secret:

```bash
etcdctl get /registry/secrets/default/my-secret --print-value-only
```

You should only see binary data now. Don't forget to exit the container.

```bash
exit
```

Encrypting secret data with a locally managed key protects against an etcd compromise, but it fails to protect against a host compromise.

To address this Kubernetes can use Managed (KMS) key storage: The KMS provider uses envelope encryption: Kubernetes encrypts resources using a data key, and then encrypts that data key using the managed encryption service. Kubernetes generates a unique data key for each resource. The API server stores an encrypted version of the data key in etcd alongside the ciphertext; when reading the resource, the API server calls the managed encryption service and provides both the ciphertext and the (encrypted) data key. Within the managed encryption service, the provider uses a key encryption key to decipher the data key, deciphers the data key, and finally recovers the plain text. Communication between the control plane and the KMS requires in-transit protection, such as TLS.

Kubernetes natively supports integration with external KMS providers like [HashiCorp Vault](https://github.com/hashicorp/vault), modern KMS tools have functions for data encryption, dynamic secrets, revocation and renewal of secrets.
