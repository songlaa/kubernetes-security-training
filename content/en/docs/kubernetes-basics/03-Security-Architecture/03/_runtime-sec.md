---
title: "Runtime Security"
weight: 5
sectionnumber: 3.5
---

Kubernetes clusters are dynamic, with workloads constantly being scheduled, modified, and removed. While static security measures (e.g., image scanning, Pod Security Policies) focus on vulnerabilities before deployment, runtime security tools like Falco detect threats as they occur.

This includes:

* Detecting anomalous behavior (e.g., unexpected process executions in containers).
* Identifying suspicious network activity (e.g., unexpected connections or port scans).
* Tracking system calls for unauthorized actions (e.g., privilege escalation attempts).

Falco is an open source Kubernetes threat detection engines. It Falco detects unexpected application behavior and alerts on threats at runtime.  At the core of Falco is its driver responsible for monitoring (container) syscalls and forwarding them to userspace for analysis.

### {{% task %}} Install Falco on kind

First, install the helm repository (exit the kind docker container if you are still in it from the previous lab):

```bash
helm repo add falcosecurity https://falcosecurity.github.io/charts
helm repo update
```

Then install Falco:

```bash
helm install --replace falco --namespace falco --create-namespace --set tty=true falcosecurity/falco
```

And check that the Falco pods are running:

```bash
kubectl get pods -n falco
```

Falco pod(s) might need a bit to start. Wait until they are ready:

```bash
kubectl wait pods --for=condition=Ready --all -n falco
```

Falco comes with a [pre-installed set of rules](https://github.com/falcosecurity/rules/blob/main/rules/falco_rules.yaml) that alert you upon suspicious behavior. We can check this by triggering such a rule

Let's create a deployment:

```bash
kubectl create deployment nginx --image=nginx
```

And execute a command that would trigger a rule:

```bash
kubectl exec -it $(kubectl get pods --selector=app=nginx -o name) -- cat /etc/shadow
```

Now let's take a look at the Falco logs:

```bash
kubectl logs -l app.kubernetes.io/name=falco -n falco -c falco | grep Warning
```

You will see logs for all the Falco pods deployed on the system. The Falco pod corresponding to the node in which our nginx deployment is running has detected the event, and you'll be able to read a line like:

```
09:46:05.727801343: Warning Sensitive file opened for reading by non-trusted program (file=/etc/shadow gparent=systemd ggparent=<NA> gggparent=<NA> evt_type=openat user=root user_uid=0 user_loginuid=-1 process=cat proc_exepath=/usr/bin/cat parent=containerd-shim command=cat /etc/shadow terminal=34816 container_id=bf74f1749e23 container_image=docker.io/library/nginx container_image_tag=latest container_name=nginx k8s_ns=default k8s_pod_name=nginx-7854ff8877-h97p4)
```

We could forward the logs of the falco deamonset to a central instance and alert on certain events there.

In a previous chapter we mentioned, that is is possible to read secretes by executing a pod and mounting the secret. This is exactly a situation where we can use a runtime security tool like falco. Let us demonstrate that:

```bash
#create the cert
openssl req -new -newkey rsa:4096 -x509 -sha256 -days 365 -nodes -subj "/C=CH/O=songlaa/OU=Domain Control Validated/CN=*.songlaa.com" -out tls.crt -keyout tls.key
#create the secret from the cert
kubectl create secret tls nginx-tls --cert=tls.crt --key=tls.key
# create the pod mounting the secret
cat << EOF >> secret-mount-pod.yaml
apiVersion: v1
kind: Pod
metadata:
  name: nginx-tls-pod
spec:
  containers:
  - name: nginx
    image: nginx
    ports:
    - containerPort: 443
    volumeMounts:
    - name: tls-cert
      mountPath: "/etc/nginx/tls"
      readOnly: true
  volumes:
  - name: tls-cert
    secret:
      secretName: nginx-tls
EOF
kubectl apply -f secret-mount-pod.yaml
```

You created a webserver wich uses a certificate from a secret to encrypt its communication.Now, let’s create a Falco rule that triggers an alert if any process other than nginx accesses the mounted secret files (the certificate and private key).

Create a yaml named `falco_custom_rules_cm.yaml` with your custom rule:

```yaml
customRules:
  custom-rules.yaml: |-
    - rule: Unauthorized Access to Nginx TLS Secrets
      desc: Detects when a process other than nginx accesses the mounted TLS secrets
      condition: open_read and container and (fd.name startswith "/etc/nginx/tls") and (proc.name != "nginx")
      output: "Unauthorized access to TLS secret by process other than nginx (user=%user.name command=%proc.cmdline file=%fd.name container=%container.name)"
      priority: WARNING
      tags: [kubernetes, secrets, tls, nginx]
```

This rule triggers on any read access (open_read) to files under /etc/nginx/tls (where the TLS cert and key are mounted).
It excludes nginx processes by checking that proc.name != "nginx".
The output logs the offending process and the file accessed.

And load it into Falco:

```bash
helm upgrade --namespace falco falco falcosecurity/falco --set tty=true -f falco_custom_rules_cm.yaml
```

Falco pods need some time to restart. Wait until they are ready:

```bash
kubectl wait pods --for=condition=Ready --all -n falco
```

Then trigger our new rule:

```bash
kubectl exec -it nginx-tls-pod -- cat /etc/nginx/tls/tls.key
```

And again check the logs:

```bash
kubectl logs -l app.kubernetes.io/name=falco -n falco -c falco | grep nginx
```

We saw that we can create alerts for different use cases. The Falco default ruleset is just a start you need create rules according to your own needs and requirements in your cluster.
