---
title: "Securing the frontend"
weight: 5
sectionnumber: 1.5
---

Right now we have a fully functioning application, but we wan't to run it a secure as possible. In docker we would make sure to run as an unprivileged user, drop unnecessary capabilites and use a Mandatory Access Control System like AppArmor. Let us apply that to Kubernetes!

In Kubernetes, the SecurityContext defines security-related settings for both Pods and individual Containers. It allows you to control various security aspects of your workloads, such as user permissions, capabilities, and Linux security features (like SELinux, AppArmor, and seccomp).

## {{% task %}} Security Context

Before we secure our secure our frontend we have a general example of a security context in a pod:

Create a new file `security-context-demo.yaml` and paste the following content:

```bash
apiVersion: v1
kind: Pod
metadata:
  name: security-context-demo
spec:
  securityContext:
    runAsUser: 1000
    runAsGroup: 3000
    fsGroup: 2000
  volumes:
  - name: sec-ctx-vol
    emptyDir: {}
  containers:
  - name: sec-ctx-demo
    image: busybox:1.28
    command: [ "sh", "-c", "sleep 1h" ]
    volumeMounts:
    - name: sec-ctx-vol
      mountPath: /data/demo
    securityContext:
      allowPrivilegeEscalation: false
```

Then apply it:

```bash
kubectl apply -f security-context-demo.yaml --namespace <namespace>
```

You can see the different value entries in the 'securityContext' sections (on pod and container level), let's figure how what do they do. So create the pod and connect into the shell:

```bash
kubectl exec -it security-context-demo --namespace <namespace> -- sh
```

In the container run 'ps' to get a list of all running processes. The output shows, that the processes are running with the user 1000, which is the value from 'runAsUser':

```
PID   USER     TIME  COMMAND
    1 1000      0:00 sleep 1h
    6 1000      0:00 sh
```

Now navigate to the directory '/data' and list the content. As you can see the 'emptyDir' has been mounted with the group ID of 2000, which is the value of the 'fsGroup' field.

```
drwxrwsrwx 2 root 2000 4096 Oct  20 20:10 demo
```

Go into the dir 'demo' and create a file:

```bash
cd demo
echo hello > demofile
```

List the content with 'ls' again and see, that 'demofile' has the group ID 2000, which is the value 'fsGroup' as well.

Run the last command 'id' here and check the output:

```
uid=1000 gid=3000 groups=2000
```

The shown group ID of the user is 3000, from the field 'runAsGroup'. If the field would be empty the user would have 0 (root) and every process would be able to go with files which are owned by the root (0) group.

```
exit
```

You can delete the pod now:

```bash
kubectl delete pod security-context-demo --namespace <namespace>
```

We are ready to apply some of this new knowledge to our frontend deployment now:

## {{% task %}} A more secure frontend

First let us check if the current frontend runs as the root user, an easy way it to execute `whoami` in the running container:

```bash
kubectl -n <namespace> exec deployments/example-frontend -- whoami
```

We see that the process is running with the user `web`. We could also have checked the Dockerfile or run `docker inspect` to get the user.

Now let us make sure we don't run this pod as root, even if the image would change. We can set the `runAsNonRoot` field to `true` in the securityContext. This ensures that the container will not run with root privileges. If the image being used has no specific user set, this will result in an error. For this example we don't need `runAsUser` or `runAsGroup` because the image already runs with an unprivileged user/group.

We could also use `fsGroup` like in the example above. But since we don't use shated storage there is a better option: we add `readOnlyRootFilesystem` to the security context, this makes the filesystems in our container readonly.

Finally we drop all capabilities of the container, since we run on a port which is >1024 we even don't capabilities to open lower ports.

Change your file `deployment_example-frontend.yaml` to incorporate this securityContext:

```bash
apiVersion: apps/v1
kind: Deployment
metadata:
  labels:
    app: example-frontend
  name: example-frontend
spec:
  replicas: 2
  selector:
    matchLabels:
      app: example-frontend
  strategy:
    rollingUpdate:
      maxSurge: 25%
      maxUnavailable: 0
    type: RollingUpdate
  template:
    metadata:
      labels:
        app: example-frontend
    spec:
      securityContext:
        runAsNonRoot: true 
      containers:
        - image: quay.io/acend/example-web-python:latest
          name: example-frontend
          securityContext:
            readOnlyRootFilesystem: true
            allowPrivilegeEscalation: false
            capabilities:
              drop:
              - ALL
          readinessProbe:
            httpGet:
              path: /health
              port: 5000
              scheme: HTTP
            initialDelaySeconds: 10
            timeoutSeconds: 1
          resources:
            limits:
              cpu: 100m
              memory: 128Mi
            requests:
              cpu: 50m
              memory: 128Mi
```

and apply it using:

```bash
kubectl apply -f deployment_example-frontend.yaml --namespace <namespace>
```

Like this we can make sure that we don't run any container in our deployment as root, have minimum capabilites a readonly file-system.

{{% alert title="Note" color="info" %}}

If you need to run as root but want the added security of user-namespaces, kubernetes has them introduced recently as beta feature. More information under <https://kubernetes.io/docs/concepts/workloads/pods/user-namespaces/>

{{% /alert %}}

If you looked closely at the example you might have spotted `allowPrivilegeEscalation` set to `false` for the container. This controls whether a process can gain additional privileges (e.g., by using setuid binaries). By default, this is true unless overridden, but it's recommended to set it to false to prevent privilege escalation, so we did that too.

## {{% task %}} Seccomp profile

The default seccomp profiles for containers in Kubernetes depend on the underlying container runtime (Docker, containerd, CRI-O) and the Kubernetes distribution itself. Most distributions use the RuntimeDefault profile provided by the container runtime, but the actual system call restrictions may differ slightly based on the runtime’s configuration. Most container runtimes provide a sane set of default syscalls that are allowed or not.

You could adopt these defaults for your workload by setting the seccomp type in the security context of a pod or container to RuntimeDefault:

```
spec:
  securityContext:
    seccompProfile:
      type: RuntimeDefault
```

If you have the seccompDefault configuration [enabled](https://kubernetes.io/docs/tutorials/security/seccomp/#enable-the-use-of-runtimedefault-as-the-default-seccomp-profile-for-all-workloads), then Pods use the RuntimeDefault seccomp profile whenever no other seccomp profile is specified. Otherwise, the default is Unconfined.

You could also create you own seccomp profile store it on the nodes and and add it to security context of a pod like this:

```
        securityContext:
            seccompProfile:
              type: Localhost
              localhostProfile: "/path/to/custom-seccomp.json"
```

We could use stricter seccomp profiles for certain pods or log the usage of certain syscalls in our environment like this.
