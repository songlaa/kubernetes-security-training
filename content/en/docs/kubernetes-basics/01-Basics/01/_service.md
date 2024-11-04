---
title: "Exposing a Service"
weight: 3
sectionnumber: 1.3
---

In this lab, we are going to make the frontend from the last lab accessible externally.

## {{% task %}} Create a ClusterIP Service

The command `kubectl apply -f deployment_example-frontend.yaml` from the last lab creates a Deployment but no Service.

A Kubernetes Service is an abstract way to expose an application running on a set of Pods as a network service. For some parts of your application (like frontends), you may want to expose a Service to an external IP address outside your cluster.

Kubernetes `ServiceTypes` allow you to specify the type of Service you want. The default is `ClusterIP`.

`Type` values and their behaviors are:

* `ClusterIP`: Exposes the Service on a cluster-internal IP. Only reachable from within the cluster. This is the default ServiceType.

* `NodePort`: Exposes the Service on each Node's IP at a static port (the NodePort). A ClusterIP Service, to which the NodePort Service routes, is automatically created. Access the NodePort Service from outside the cluster by requesting `<NodeIP>:<NodePort>`.

* `LoadBalancer`: Exposes the Service externally using a cloud provider's load balancer. NodePort and ClusterIP Services, which the external load balancer routes to, are automatically created.

* `ExternalName`: Maps the Service to the contents of the externalName field (e.g., foo.bar.example.com), by returning a CNAME record with its value. No proxying is set up.

Ingress can also be used to expose your Service.

Ingress is not a Service type, but it acts as the entry point for your cluster. [Ingress](https://kubernetes.io/docs/concepts/services-networking/ingress/) exposes HTTP and HTTPS routes from outside the cluster to services within. Traffic routing is controlled by rules defined on the Ingress resource. An Ingress may be configured to provide Services with externally reachable URLs, load-balance traffic, terminate SSL/TLS, and offer name-based virtual hosting. An Ingress controller is responsible for fulfilling the route, typically with a load balancer or configuring your edge router or frontends to handle the traffic.

To create an Ingress, we first need a Service of type [ClusterIP](https://kubernetes.io/docs/concepts/services-networking/service/#publishing-services-service-types).

To create the Service, add a new file `svc-frontend.yaml` with the following content:

{{< readfile file="/content/en/docs/kubernetes-basics/01-Basics/01/svc-example-frontend.yaml" code="true" lang="yaml" >}}

Then, apply the file with:

```bash
kubectl apply -f svc-frontend.yaml --namespace <namespace>
```

Alternatively, an imperative command can create and expose the Service without a YAML file:

```bash
kubectl expose deployment example-frontend --type=ClusterIP --name=example-frontend --port=5000 --target-port=5000 --namespace <namespace>
```

Let's inspect the Service:

```bash
kubectl get services --namespace <namespace>
```

This should output something similar to:

```bash
NAME              TYPE       CLUSTER-IP    EXTERNAL-IP   PORT(S)    AGE
example-frontend  ClusterIP  10.43.91.62   <none>        5000/TCP
```

{{% alert title="Note" color="info" %}}
Service IP (CLUSTER-IP) addresses remain stable for the lifespan of the Service.
{{% /alert %}}

Get more information with:

```bash
kubectl get service example-frontend -o yaml --namespace <namespace>
```

Example output:

```yaml
apiVersion: v1
kind: Service
metadata:
  ...
  labels:
    app: example-frontend
  managedFields:
    ...
  name: example-frontend
  namespace: <namespace>
  ...
spec:
  clusterIP: 10.43.91.62
  externalTrafficPolicy: Cluster
  ports:
  - port: 5000
    protocol: TCP
    targetPort: 5000
  selector:
    app: example-frontend
  sessionAffinity: None
  type: ClusterIP
status:
  loadBalancer: {}
```

The Service's `selector` defines which Pods are being used as Endpoints. This happens based on labels. Look at the configuration of Service and Pod in order to find out what maps to what:

```
...
  selector:
    app: example-frontend
...
```

With the following command you get details from the Pod:

```bash
kubectl get pod <pod> -o yaml --namespace <namespace>
```

Ensure the Pod’s labels match the Service’s selector:

```
...
  labels:
    app: example-frontend
```

Alternatively, use:

```bash
kubectl describe service example-frontend --namespace <namespace>
```

The `Endpoints` section lists IPs of the matching Pods.

## {{% task %}} Expose the Service with Ingress

With the ClusterIP Service ready, create an Ingress resource. First, create `ing-example-frontend.yaml` and adjust the `host` entry as needed:

{{< readfile file="/content/en/docs/kubernetes-basics/01-Basics/01/ingress.template.yaml" code="true" lang="yaml" >}}

The Ingress resource at `spec.rules[0].http.paths[0].backend.service.name` uses the `example-frontend` ClusterIP Service.

Apply the Ingress with:

```bash
kubectl apply -f ing-example-frontend.yaml --namespace <namespace>
```

Access the Ingress at `http://example-frontend-<namespace>.<appdomain>`.

## {{% task %}} (Optional) Expose as NodePort

{{% alert title="Note" color="info" %}}
This advanced option is optional. NodePorts are typically not used for HTTP-based applications, as Ingress provides layer 7-based routing. NodePort is useful for non-HTTP applications.
{{% /alert %}}

To make a Service accessible from outside using [NodePort](https://kubernetes.io/docs/concepts/services-networking/service/#nodeport), create a new Service in `svc-frontend-nodeport.yaml`:

```yaml
apiVersion: v1
kind: Service
metadata:
  labels:
    app: example-frontend
  name: example-frontend-nodeport
spec:
  ports:
  - port: 5000
    protocol: TCP
    targetPort: 5000
  selector:
    app: example-frontend
  type: NodePort
```

Note the changes in `type: NodePort` and `ports` sections. Apply it with:

```bash
kubectl apply -f svc-frontend-nodeport.yaml --namespace <namespace>
```

Inspect the NodePort Service:

```bash
kubectl get services -l app=example-frontend --namespace <namespace>
```

The output will show:

```bash
NAME                        TYPE       CLUSTER-IP    EXTERNAL-IP   PORT(S)        AGE
example-frontend-nodeport   NodePort   10.43.91.62   <none>        5000:30692/TCP
```

Access `http://<node-ip>:<node-port>` in your browser or with `curl`. Use `kubectl get nodes -o wide` to list node IPs.

```bash
kubectl get node -o wide
```

Output example:

```
NAME    STATUS   ROLES                      AGE    VERSION   INTERNAL-IP     EXTERNAL-IP   OS-IMAGE             KERNEL-VERSION      CONTAINER-RUNTIME
lab-1   Ready    controlplane,etcd,worker   150m   v1.17.4   5.102.145.142   <none>        Ubuntu 18.04.3 LTS   4.15.0-66-generic   docker://19.3.8
lab-2   Ready    controlplane,etcd,worker   150m   v1.17.4   5.102.145.77    <none>        Ubuntu 18.04.3 LTS   4.15.0-66-generic   docker://19.3.8
lab-3   Ready    controlplane,etcd,worker   150m   v1.17.4   5.102.145.148   <none>        Ubuntu 18.04.3 LTS   4.15.0-66-generic   docker://19.3.8
```

## {{% task %}} (Advanced) Bring it all together

Now that we've covered how to create a Deployment, Service, and Ingress resource, it's your turn to try it on your own. Create a Deployment with two pods using the image [go-httpbin:2
.15.0](https://hub.docker.com/r/mccutchen/go-httpbin/tags). Expose this Deployment using a Service, and set up an Ingress that responds to:

* `http://example-frontend-><namespace>.<appdomain>/headers` and a second Ingress that responds to
* `http://example-httpbin-><namespace>.<appdomain>`

Tip: Use imperative commands with --dry-run=client -o yaml to preview the resource definitions before applying them.

## {{% task %}} For fast learners

Examine resources in your namespace with:

```bash
kubectl describe namespace <namespace>
kubectl get all --namespace <namespace>
kubectl describe <resource> <name> --namespace <namespace>
kubectl get <resource> <name> -o yaml --namespace <namespace>
```
