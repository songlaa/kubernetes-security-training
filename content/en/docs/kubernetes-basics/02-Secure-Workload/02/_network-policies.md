---
title: "Network Policies"
weight: 2
sectionnumber: 2.2
---


## Kubernetes Networking

Kubernetes networking is designed to allow communication between various components like pods, services, and external resources. It ensures that containers can interact with each other.

Container Network Interface (CNI) is a specification for network plugins in Kubernetes. It enables the network layer to be abstracted and customized based on the specific requirements of the cluster. CNIs are responsible for configuring networking when a pod is started or terminated. CNI plugins allow Kubernetes clusters to use different networking models or overlay networks, making it possible to scale across diverse environments.

## Network Policies

One CNI function is the ability to enforce network policies and implement an in-cluster zero-trust container strategy. Network policies are a default Kubernetes object for controlling network traffic, but a CNI such as [Cilium](https://cilium.io/) or [Calico](https://www.tigera.io/project-calico/) is required to enforce them. We will demonstrate traffic blocking with our simple app.

### {{% task %}} Deploy a second frontend/backend application

First, we need a simple application to show the effects on Kubernetes network policies. Create a file named `simple-app.yaml` with this content:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: frontend
  labels:
    app: frontend
spec:
  replicas: 1
  selector:
    matchLabels:
      app: frontend
  template:
    metadata:
      labels:
        app: frontend
    spec:
      containers:
      - name: frontend-container
        image: docker.io/byrnedo/alpine-curl:0.1.8
        imagePullPolicy: IfNotPresent
        command: [ "/bin/ash", "-c", "sleep 1000000000" ]
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: not-frontend
  labels:
    app: not-frontend
spec:
  replicas: 1
  selector:
    matchLabels:
      app: not-frontend
  template:
    metadata:
      labels:
        app: not-frontend
    spec:
      containers:
      - name: not-frontend-container
        image: docker.io/byrnedo/alpine-curl:0.1.8
        imagePullPolicy: IfNotPresent
        command: [ "/bin/ash", "-c", "sleep 1000000000" ]
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: backend
  labels:
    app: backend
spec:
  replicas: 1
  selector:
    matchLabels:
      app: backend
  template:
    metadata:
      labels:
        app: backend
    spec:
      containers:
      - name: backend-container
        env:
        - name: PORT
          value: "8080"
        ports:
        - containerPort: 8080
        image: docker.io/cilium/json-mock:1.2
        imagePullPolicy: IfNotPresent
---
apiVersion: v1
kind: Service
metadata:
  name: backend
  labels:
    app: backend
spec:
  type: ClusterIP
  selector:
    app: backend
  ports:
  - name: http
    port: 8080
```

The application consists of two client deployments (`frontend` and `not-frontend`) and one backend deployment (`backend`). We are going to send requests from the frontend and not-frontend pods to the backend pod.


Deploy the app:

```bash
kubectl apply -f simple-app.yaml
```

this gives you the following output:

```
deployment.apps/frontend created
deployment.apps/not-frontend created
deployment.apps/backend created
service/backend created
```

Verify with the following command that everything is up and running:

```bash
kubectl get deployment,svc
```

Let us make life a bit easier by storing the pod name into an environment variable so we can reuse it later again:

```bash
export FRONTEND=$(kubectl get pods -l app=frontend -o jsonpath='{.items[0].metadata.name}')
echo ${FRONTEND}
export NOT_FRONTEND=$(kubectl get pods -l app=not-frontend -o jsonpath='{.items[0].metadata.name}')
echo ${NOT_FRONTEND}
```

## {{% task %}} Verify connectivity

Now we generate some traffic as a baseline test.

```bash
kubectl exec -ti ${FRONTEND} -- curl -I --connect-timeout 5 backend:8080
```

and

```bash
kubectl exec -ti ${NOT_FRONTEND} -- curl -I --connect-timeout 5 backend:8080
```

This will execute a simple `curl` call from the `frontend` and `not-frontend` application to the `backend` application:

```
# Frontend
HTTP/1.1 200 OK
X-Powered-By: Express
Vary: Origin, Accept-Encoding
Access-Control-Allow-Credentials: true
Accept-Ranges: bytes
Cache-Control: public, max-age=0
Last-Modified: Sat, 26 Oct 1985 08:15:00 GMT
ETag: W/"83d-7438674ba0"
Content-Type: text/html; charset=UTF-8
Content-Length: 2109
Date: Tue, 23 Nov 2021 12:50:44 GMT
Connection: keep-alive

# Not Frontend
HTTP/1.1 200 OK
X-Powered-By: Express
Vary: Origin, Accept-Encoding
Access-Control-Allow-Credentials: true
Accept-Ranges: bytes
Cache-Control: public, max-age=0
Last-Modified: Sat, 26 Oct 1985 08:15:00 GMT
ETag: W/"83d-7438674ba0"
Content-Type: text/html; charset=UTF-8
Content-Length: 2109
Date: Tue, 23 Nov 2021 12:50:44 GMT
Connection: keep-alive
```

We see that both applications can connect to the `backend` application.

Until now ingress and egress policy enforcement are still disabled on all of our pods because no network policy has been imported yet selecting any of the pods. Let us change this.

## {{% task %}} Deny traffic with a Network Policy

We block traffic by applying a network policy. Create a file `backend-ingress-deny.yaml` with the following content:

```yaml
kind: NetworkPolicy
apiVersion: networking.k8s.io/v1
metadata:
  name: backend-ingress-deny
spec:
  podSelector:
    matchLabels:
      app: backend
  policyTypes:
  - Ingress
```

The policy will deny all ingress traffic as it is of type Ingress but specifies no allow rule, and will be applied to all pods with the `app=backend` label thanks to the podSelector.

Ok, then let's create the policy with:

```bash
kubectl apply -f backend-ingress-deny.yaml
```

and you can verify the created `NetworkPolicy` with:

```bash
kubectl get netpol
```

Which gives you an output similar to this:

```
                                                    
NAME                   POD-SELECTOR   AGE
backend-ingress-deny   app=backend    2s

```

## {{% task %}} Verify connectivity again

We can now execute the connectivity check again:

```bash
kubectl exec -ti ${FRONTEND} -- curl -I --connect-timeout 5 backend:8080
```

and

```bash
kubectl exec -ti ${NOT_FRONTEND} -- curl -I --connect-timeout 5 backend:8080
```

But this time you see that the `frontend` and `not-frontend` applications cannot connect anymore to the `backend`:

```
# Frontend
curl: (28) Connection timed out after 5001 milliseconds
command terminated with exit code 28
# Not Frontend
curl: (28) Connection timed out after 5001 milliseconds
command terminated with exit code 28
```

The network policy correctly switched the default ingress behavior from default allow to default deny.

Let's now selectively re-allow traffic again, but only from the frontend to the backend.

## {{% task %}} Allow traffic from frontend to backend

We can do it by crafting a new network policy manually, but we can also use the Network Policy Editor made by Cilium to help us out:

![Cilium editor with backend-ingress-deny Policy](../cilium_editor_1.png)

Above you see our original policy, we create a new one with the editor now.

* Go to <https://editor.cilium.io/>
* Name the network policy to backend-allow-ingress-frontend (using the Edit button in the center).
* add `app=backend` as Pod Selector
* Set Ingress to default deny

![Cilium editor edit name](../cilium_editor_edit_name.png)

* On the ingress side, add `app=frontend` as podSelector for pods in the same Namespace.

![Cilium editor add rule](../cilium_editor_add.png)

* Inspect the ingress flow colors: the policy will deny all ingress traffic to pods labeled `app=backend`, except for traffic coming from pods labeled `app=frontend`.

![Cilium editor backend allow rule](../cilium_editor_backend-allow-ingress.png)

* Copy the policy YAML into a file named `backend-allow-ingress-frontend.yaml`. Make sure to use the `Networkpolicy` and not the `CiliumNetworkPolicy`!

The file should look like this:

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: "backend-allow-ingress-frontend"
spec:
  podSelector:
    matchLabels:
      app: backend
  policyTypes:
    - Ingress
  ingress:
    - from:
        - podSelector:
            matchLabels:
              app: frontend

```

Apply the new policy:

```bash
kubectl apply -f backend-allow-ingress-frontend.yaml
```

and then execute the connectivity test again:

```bash
kubectl exec -ti ${FRONTEND} -- curl -I --connect-timeout 5 backend:8080
```

and

```bash
kubectl exec -ti ${NOT_FRONTEND} -- curl -I --connect-timeout 5 backend:8080
```

This time, the `frontend` application is able to connect to the `backend` but the `not-frontend` application still cannot connect to the `backend`:

```
# Frontend
HTTP/1.1 200 OK
X-Powered-By: Express
Vary: Origin, Accept-Encoding
Access-Control-Allow-Credentials: true
Accept-Ranges: bytes
Cache-Control: public, max-age=0
Last-Modified: Sat, 26 Oct 1985 08:15:00 GMT
ETag: W/"83d-7438674ba0"
Content-Type: text/html; charset=UTF-8
Content-Length: 2109
Date: Tue, 23 Nov 2021 13:08:27 GMT
Connection: keep-alive

# Not Frontend
curl: (28) Connection timed out after 5001 milliseconds
command terminated with exit code 28

```

Note that this is working despite the fact we did not delete the previous `backend-ingress-deny` policy:

```bash
kubectl get netpol
```

```
NAME                             POD-SELECTOR   AGE
backend-allow-ingress-frontend   app=backend    2m7s
backend-ingress-deny             app=backend    12m

```

Network policies are additive. Just like with firewalls, it is thus a good idea to have default DENY policies and then add more specific ALLOW policies as needed.

Let us apply our new knowledge again to our original example frontend/backend application. But first delete this example:

```bash
kubectl delete netpol backend-allow-ingress-frontend, backend-ingress-deny 
kubectl delete -f simple-app.yaml

```

## {{% task %}} Network Isolation for our example frontend/backend

As previously mentioned it is a good practice to start with a default DENY rule and only add the traffic we want to allow.

These two policies will allow in-cluster DNS and deny all inbound and outbound traffic in the namespace by default, furthermore, we still allow traffic to our own webshell. Create a file named `deny-netpol.yaml`.

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-webshellkube
spec:
  podSelector:
    matchLabels:
     "app.kubernetes.io/name": webshell
  policyTypes:
    - Ingress
    - Egress
  egress:
  - {}
  ingress:
  - from:
    - namespaceSelector:
        matchLabels:
          app: ingress-haproxy
---
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-dns
spec:
  podSelector: {}
  policyTypes:
    - Egress
  egress:
    - to:
        - namespaceSelector:
            matchLabels:
              kubernetes.io/metadata.name: kube-system
          podSelector:
            matchLabels:
              k8s-app: kube-dns
      ports:
        - protocol: UDP
          port: 53
        - protocol: TCP
          port: 53
```

And apply it

```bash
kubectl apply -f deny-netpol.yaml
```

Now we have broken the communication from our front- to the backend. Check your frontend it should give you an error now.

Finally, create the network policies necessary for the communication from front- to backend and to reach the frontend. Create a file named `frontend-netpol.yaml`:

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: backend-allow-frontend
spec:
  podSelector:
    matchLabels:
      app: mariadb
  ingress:
    - from:
        - podSelector:
            matchLabels:
              app: example-frontend
          namespaceSelector:
            matchLabels:
              kubernetes.io/metadata.name: <namespace>
      ports:
        - protocol: TCP
          port: 3306
---
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: frontend-to-backend
spec:
  podSelector:
    matchLabels:
      app: example-frontend
  egress:
    - to:
        - namespaceSelector:
            matchLabels:
              kubernetes.io/metadata.name: <namespace>
          podSelector:
            matchLabels:
              app: mariadb
  ingress:
  - {}
```

And apply it:

```bash
kubectl apply -f frontend-netpol.yaml
```

Try out if your app is still working, refresh the frontend in your browser then check if it is working again.

## {{% task %}} (Advanced) Cilium Network Policies on Layer 7

Cilium extends the capabilities of Kubernetes network policies to support not only Layer 3/4 (IP addresses and ports) but also Layer 7 (application-level protocols like HTTP). This allows you to create more granular policies, such as restricting paths, methods, or domain names as shown in this lab. This helps enforce security policies that align with application logic and business requirements.

Create a new deployment named curl-deployment using the curlimages/curl image and set the command to sleep indefinitely:

```bash
kubectl apply -f - <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: curl-deployment
spec:
  replicas: 1
  selector:
    matchLabels:
      app: curl-deployment
  template:
    metadata:
      labels:
        app: curl-deployment
    spec:
      containers:
      - name: curl-container
        image: curlimages/curl
        command: ["sleep", "infinity"]
      dnsConfig:
        options:
        - name: ndots
          value: "1" #this option is here because it avoids adding .svc.cluster.local. to dns queries
EOF
```

Use kubectl exec to test connectivity to `www.zhaw.ch` and `songlaa.com`.

Note the results of these commands. By default, if no network policies are applied, the pod should be able to reach both sites.

Write a Cilium NetworkPolicy named songlaa that only allows HTTP/S traffic to `songlaa.com`. [Here](https://docs.cilium.io/en/stable/security/policy/language/#dns-based) is a link to the documentation.

Now try it again, it should only allow requests to `songlaa.com`

At this point, you may believe you've successfully blocked all egress traffic—until you learn about [DNS tunneling](https://brightsec.com/blog/dns-tunneling/). To address this potential vulnerability, you need to enhance your Cilium Network Policy further. Specifically, you should block all DNS queries except those directed to `songlaa.com`. For detailed guidance on configuring DNS policies, refer to the [Cilium DNS documentation](https://docs.cilium.io/en/stable/security/dns/).

If you did succeed you can cleanup the deplyoment and the Cilium NetworkPolicy:

```bash
kubectl delete deployment curl-deployment
kubectl delete CiliumNetworkPolicy songlaa
```
