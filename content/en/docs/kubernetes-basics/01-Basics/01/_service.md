---
title: "Exposing a service"
weight: 3
sectionnumber: 1.3
---

In this lab, we are going to make the freshly deployed application from the last lab available online.

## {{% task %}} Create a ClusterIP Service

The command `kubectl apply -f deployment_example-web-go.yaml` from the last lab creates a Deployment but no Service. A kubernetes Service is an abstract way to expose an application running on a set of Pods as a network service. For some parts of your application (for example, frontends) you may want to expose a Service to an external IP address which is outside your cluster.

kubernetes `ServiceTypes` allow you to specify what kind of Service you want. The default is `ClusterIP`.

`Type` values and their behaviors are:

* `ClusterIP`: Exposes the Service on a cluster-internal IP. Choosing this value only makes the Service reachable from within the cluster. This is the default ServiceType.

* `NodePort`: Exposes the Service on each Node's IP at a static port (the NodePort). A ClusterIP Service, to which the NodePort Service routes, is automatically created. You'll be able to contact the NodePort Service from outside the cluster, by requesting \<NodeIP\>:\<NodePort\>.

* `LoadBalancer`: Exposes the Service externally using a cloud provider's load balancer. NodePort and ClusterIP Services, to which the external load balancer routes, are automatically created.

* `ExternalName`: Maps the Service to the contents of the externalName field (e.g. foo.bar.example.com), by returning a CNAME record with its value. No proxying of any kind is set up.

You can also use Ingress to expose your Service. Ingress is not a Service type, but it acts as the entry point for your cluster. [Ingress](https://kubernetes.io/docs/concepts/services-networking/ingress/) exposes HTTP and HTTPS routes from outside the cluster to services within the cluster.
Traffic routing is controlled by rules defined on the Ingress resource. An Ingress may be configured to give Services externally reachable URLs, load balance traffic, terminate SSL / TLS, and offer name-based virtual hosting. An Ingress controller is responsible for fulfilling the route, usually with a load balancer, though it may also configure your edge router or additional frontends to help handle the traffic.

In order to create an Ingress, we first need to create a Service of type [ClusterIP](https://kubernetes.io/docs/concepts/services-networking/service/#publishing-services-service-types).

To create the Service add a new file `svc-web-go.yaml` with the following content:

{{< readfile file="/content/en/docs/kubernetes-basics/01-Basics/01/svc-web-go.yaml" code="true" lang="yaml" >}}

And then apply the file with:

```bash
kubectl apply -f svc-web-go.yaml --namespace <namespace>
```

There is also am imperative command to create a service and expose your application which can be used instead of the yaml file with the `kubectl apply ...` command

```
kubectl expose deployment example-web-go --type=ClusterIP --name=example-web-go --port=5000 --target-port=5000 --namespace <namespace>
```

Let's have a more detailed look at our Service:

```bash
kubectl get services --namespace <namespace>
```

Which gives you an output similar to this:

```bash
NAME             TYPE       CLUSTER-IP    EXTERNAL-IP   PORT(S)        AGE
example-web-go   ClusterIP  10.43.91.62   <none>        5000/TCP
```

{{% alert title="Note" color="info" %}}
Service IP (CLUSTER-IP) addresses stay the same for the duration of the Service's lifespan.
{{% /alert %}}

By executing the following command:

```bash
kubectl get service example-web-go -o yaml --namespace <namespace>
```

You get additional information:

```
apiVersion: v1
kind: Service
metadata:
  ...
  labels:
    app: example-web-go
  managedFields:
    ...
  name: example-web-go
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
    app: example-web-go
  sessionAffinity: None
  type: ClusterIP
status:
  loadBalancer: {}
```

The Service's `selector` defines which Pods are being used as Endpoints. This happens based on labels. Look at the configuration of Service and Pod in order to find out what maps to what:

```bash
kubectl get service example-web-go -o yaml --namespace <namespace>
```

```
...
  selector:
    app: example-web-go
...
```

With the following command you get details from the Pod:

{{% alert title="Note" color="info" %}}
First, get all Pod names from your namespace with (`kubectl get pods --namespace <namespace>`) and then replace \<pod\> in the following command. If you have installed and configured the bash completion, you can also press the TAB key for autocompletion of the Pod's name.
{{% /alert %}}

```bash
kubectl get pod <pod> -o yaml --namespace <namespace>
```

Let's have a look at the label section of the Pod and verify that the Service selector matches the Pod's labels:

```
...
  labels:
    app: example-web-go
...
```

This link between Service and Pod can also be displayed in an easier fashion with the `kubectl describe` command:

```bash
kubectl describe service example-web-go --namespace <namespace>
```

```
Name:                     example-web-go
Namespace:                example-ns
Labels:                   app=example-web-go
Annotations:              <none>
Selector:                 app=example-web-go
Type:                     ClusterIP
IP:                       10.39.240.212
Port:                     <unset>  5000/TCP
TargetPort:               5000/TCP
Endpoints:                10.36.0.8:5000
Session Affinity:         None
External Traffic Policy:  Cluster
Events:
  Type    Reason                Age    From                Message
  ----    ------                ----   ----                -------
```

The `Endpoints` show the IP addresses of all currently matched Pods.

## {{% task %}} Expose the Service

With the ClusterIP Service ready, we can now create the Ingress resource.
In order to create the Ingress resource, we first need to create the file `ing-example-web-go.yaml` and change the `host` entry to match your environment:

{{% onlyWhenNot customer %}}
{{< readfile file="/content/en/docs/kubernetes-basics/01-Basics/01/ingress.template.yaml" code="true" lang="yaml" >}}
{{% /onlyWhenNot %}}

As you see in the resource definition at `spec.rules[0].http.paths[0].backend.service.name` we use the previously created `example-web-go` ClusterIP Service.

Let's create the Ingress resource with:

```bash
kubectl apply -f ing-example-web-go.yaml --namespace <namespace>
```

Afterwards, we are able to access our freshly created Ingress at `http://example-web-go-<namespace>.<appdomain>`

{{% onlyWhen openshift %}}
{{% onlyWhenNot baloise %}}

```bash
oc expose service example-web-go --namespace <namespace>
```

The output should be:

```
route.route.openshift.io/example-web-go exposed
```

We are now able to access our app via the freshly created route at `http://example-web-go-<namespace>.<appdomain>`

{{% /onlyWhenNot %}}
{{% onlyWhen baloise %}}

```bash
oc create route edge example-web-go --service example-web-go --namespace <namespace>
```

The output should be:

```
route.route.openshift.io/example-web-go created
```

We are now able to access our app via the freshly created route at `https://example-web-go-<namespace>.<appdomain>`

{{% /onlyWhen %}}

Find your actual app URL by looking at your route (HOST/PORT):

```bash
oc get route --namespace <namespace>
```

Browse to the URL and check the output of your app.
{{% alert title="Note" color="info" %}}
If the site doesn't load, check if you are using the http:// , not the https:// protocol, which might be the default in your browser.
{{% /alert %}}

{{% /onlyWhen %}}

{{% onlyWhenNot openshift %}}

## {{% task %}} Expose as NodePort

{{% alert title="Note" color="info" %}}
This is an advanced lab, so feel free to skip this. NodePorts are usually not used for http-based applications as we use the layer 7-based Ingress resource. Only for non-http based applications, a NodePort might be a suitable alternative.
{{% /alert %}}

There's a second option to make a Service accessible from outside: Use a [NodePort](https://kubernetes.io/docs/concepts/services-networking/service/#nodeport).

In order to switch the Service type, change the existing `ClusterIP` Service by updating our Service definition in file `svc-web-go.yaml`to:

```yaml
apiVersion: v1
kind: Service
metadata:
  labels:
    app: example-web-go
  name: example-web-go
spec:
  ports:
  - port: 5000
    protocol: TCP
    targetPort: 5000
  selector:
    app: example-web-go
  type: NodePort

```

And then apply again with:

```bash
kubectl apply -f svc-web-go.yaml --namespace <namespace>
```

Let's have a more detailed look at our new `NodePort` Service:

```bash
kubectl get services --namespace <namespace>
```

Which gives you an output similar to this:

```bash
NAME             TYPE       CLUSTER-IP    EXTERNAL-IP   PORT(S)        AGE
example-web-go   NodePort   10.43.91.62   <none>        5000:30692/TCP
```

The `NodePort` number is assigned by Kubernetes and stays the same as long as the Service is not deleted. A NodePort Service is more suitable for infrastructure tools than for public URLs.

Open `http://<node-ip>:<node-port>` in your browser or use `curl http://<node-ip>:<node-port>` when the public ip is not available in your browser.
You can use any node IP as the Service is exposed on all nodes using the same `NodePort`. Use `kubectl get nodes -o wide` to display the IPs (`INTERNAL-IP` or `EXTERNAL-IP`) of the available nodes. Depending on your environment, use the internal or external (public) ip address.

```bash
kubectl get node -o wide
```

The output may vary depending on your setup:

```
NAME         STATUS   ROLES                      AGE    VERSION   INTERNAL-IP     EXTERNAL-IP   OS-IMAGE             KERNEL-VERSION      CONTAINER-RUNTIME
lab-1   Ready    controlplane,etcd,worker   150m   v1.17.4   5.102.145.142   <none>        Ubuntu 18.04.3 LTS   4.15.0-66-generic   docker://19.3.8
lab-2   Ready    controlplane,etcd,worker   150m   v1.17.4   5.102.145.77    <none>        Ubuntu 18.04.3 LTS   4.15.0-66-generic   docker://19.3.8
lab-3   Ready    controlplane,etcd,worker   150m   v1.17.4   5.102.145.148   <none>        Ubuntu 18.04.3 LTS   4.15.0-66-generic   docker://19.3.8
```

{{% /onlyWhenNot %}}

## {{% task %}} For fast learners

Have a closer look at the resources created in your namespace `<namespace>` with the following commands and try to understand them:

```bash
kubectl describe namespace <namespace>
```

```bash
kubectl get all --namespace <namespace>
```

```bash
kubectl describe <resource> <name> --namespace <namespace>
```

```bash
kubectl get <resource> <name> -o yaml --namespace <namespace>
```
