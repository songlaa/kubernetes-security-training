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

Falco is an open-source Kubernetes threat detection engine. It detects unexpected application behavior and alerts on threats at runtime.  At the core of Falco is its driver responsible for monitoring (container) syscalls and forwarding them to userspace for analysis.

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

And check that the Falco pods are running.

```bash
kubectl get pods -n falco
```

If they fail you might have hit [this issue](https://github.com/falcosecurity/falco/issues/3119), change the falco deamonset and add the env var FALCOCTL_ARTIFACT_NOVERIFY to the `falcoctl-artifact-install` container.

Falco pod(s) might need a bit to start. Wait until they are ready:

```bash
kubectl wait pods --for=condition=Ready --all -n falco
```

Falco comes with a [pre-installed set of rules](https://github.com/falcosecurity/rules/blob/main/rules/falco_rules.yaml) that alert you upon suspicious behavior. We can check this by triggering such a rule.

One of these default rules is a log entry every time a shell is opened in a pod, let us do that:

```bash
kubectl exec -it -n test-kyverno alpine-pod -- sh 
```

Now let's take a look at the Falco logs:

```bash
kubectl logs -l app.kubernetes.io/name=falco -n falco -c falco | grep "shell was spawned"
```

You will see logs for all the Falco pods deployed on the system. The Falco pod corresponding to the node in which our `alpine-pod` is running has detected the event, and you'll be able to read a line like:

```
09:13:33.058953225: Notice A shell was spawned in a container with an attached terminal (evt_type=execve user=root user_uid=1000 user_loginuid=-1 process=sh proc_exepath=/bin/busybox parent=containerd-shim command=sh terminal=34816 exe_flags=EXE_LOWER_LAYER container_id=198e59c8bb67 container_image=docker.io/library/alpine container_image_tag=latest container_name=alpine k8s_ns=test-kyverno k8s_pod_name=alpine-pod)
```

We could forward the logs of the Falco daemonset to a central instance and alert on certain events there.

In a previous chapter we mentioned, that it is possible to read secrets by executing a pod and mounting the secret. This is exactly a situation where we can use a runtime security tool like Falco. Let us demonstrate that:

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
  securityContext:
    seccompProfile:
      type: RuntimeDefault
  containers:
    - name: nginx
      image: bitnami/nginx
      ports:
        - containerPort: 8443
      securityContext:
        allowPrivilegeEscalation: false
        readOnlyRootFilesystem: false
        runAsNonRoot: true
        runAsUser: 101
        capabilities:
          drop: ["ALL"]
        seccompProfile:
          type: RuntimeDefault
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

You created a webserver which uses a certificate from a secret to encrypt its communication. Now, let’s create a Falco rule that triggers an alert if any process other than nginx accesses the mounted secret files (the certificate and private key).

Create a yaml named `falco_custom_rules_cm.yaml` with your custom rule:

```yaml
cat << \EOF >> falco_custom_rules_cm.yaml
customRules:
  custom-rules.yaml: |-
    - rule: Unauthorized Access to Nginx TLS Secrets
      desc: Detects when a process other than nginx accesses the mounted TLS secrets
      condition: open_read and container and (fd.name startswith "/etc/nginx/tls") and (proc.name != "nginx")
      output: "Unauthorized access to TLS secret by process other than nginx (user=%user.name command=%proc.cmdline file=%fd.name container=%container.name)"
      priority: WARNING
      tags: [kubernetes, secrets, tls, nginx]
EOF
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

We saw that we can create alerts for different use cases. The Falco default ruleset is just a start you need to create rules according to your own needs and requirements in your cluster.
