---
title: "Deployments"
weight: 2
sectionnumber: 1.2
---

We are finally ready to get started with Kubernetes. You should have been given the setup instructions by your teacher and be logged in your namespace.

In this lab, we deploy our first container image and look at the concepts of Pods, Services, and Deployments.

## {{% task %}} Start and stop a single Pod

We have a look at deploying a pre-built container image from Quay.io or any other public container registry.

First, we start a new Pod. For this we have to define our Kubernetes Pod resource definition. Create a new file `pod_awesome-app.yaml` with the content below.

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: awesome-app
spec:
  containers:
  - image: {{% param "containerImages.deployment-image-url" %}}
    imagePullPolicy: Always
    name: awesome-app
    resources:
      limits:
        cpu: 20m
        memory: 32Mi
      requests:
        cpu: 10m
        memory: 16Mi

```

Now we can apply this with:

```bash
kubectl apply -f pod_awesome-app.yaml --namespace <namespace>
```

The output should be:

```
pod/awesome-app created
```

Use kubectl get pods --namespace <namespace>` to show the running Pod:

```bash
kubectl get pod awesome-app --namespace <namespace>
```

Which gives you an output similar to this:

```
NAME          READY   STATUS    RESTARTS   AGE
awesome-app   1/1     Running   0          1m24s
```

Now delete the newly created Pod:

```bash
kubectl delete pod awesome-app --namespace <namespace>
```

## {{% task %}} Create a Deployment

In some use cases, it can make sense to start a single Pod. But this has its downsides and is not really a common practice. Let's look at another concept which is tightly coupled with the Pod: the so-called _Deployment_. A Deployment ensures that a Pod is monitored and checks that the number of running Pods corresponds to the number of requested Pods.

To create a new Deployment we first define our Deployment in a new file `deployment_example-frontend.yaml` with the content below.

```yaml
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
      containers:
        - image: quay.io/acend/example-web-python:latest
          name: example-frontend
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

With this, we create our Deployment inside our already created namespace:

```bash
kubectl apply -f deployment_example-frontend.yaml --namespace <namespace>
```

The output should be:

```
deployment.apps/example-frontend created
```

Kubernetes creates the defined and necessary resources, pulls the container image (in this case from Quay.io) and deploys the Pod.

Examine the deployment yaml more closely and discuss it with each other. Where do we configure our resource usage and how do we handle High Availabilty and our update strategy in our code?

Use the command `kubectl get` with the `-w` parameter to get the requested resources and afterward watch for changes.

{{% alert title="Note" color="info" %}}
The `kubectl get -w` command will never end unless you terminate it with `CTRL-c`.
{{% /alert %}}

```bash
kubectl get pods -w --namespace <namespace>
```

{{% alert title="Note" color="info" %}}
Instead of using the `-w` parameter you can also use the `watch` command which should be available on most Linux distributions:

```bash
watch kubectl get pods --namespace <namespace>
```

{{% /alert %}}

This process can last for some time depending on your internet connection and if the image is already available locally.

{{% alert title="Note" color="info" %}}
If you want to create your own container images and use them with Kubernetes, you definitely should have a look at [these best practices](https://docs.openshift.com/container-platform/latest/openshift_images/create-images.html) and apply them. This image creation guide may be for OpenShift, however it also applies to Kubernetes and other container platforms.
{{% /alert %}}

### Creating Kubernetes resources

There are two fundamentally different ways to create Kubernetes resources.
You've already seen one way: Writing the resource's definition in YAML (or JSON) and then applying it on the cluster using `kubectl apply`.

The other variant is to use helper commands. These are more straightforward: You don't have to copy a YAML definition from somewhere else and then adapt it.
However, the result is the same. The helper commands just simplify the process of creating the YAML definitions.

As an example, let's look at creating the above deployment, this time using a helper command instead. If you already created the Deployment using the above YAML definition, you don't have to execute this command:

```yaml
kubectl create deployment example-frontend --image={{% param "containerImages.deployment-image-url" %}} --namespace <namespace>
```

It's important to know that these helper commands exist.
However, in a world where GitOps concepts have an ever-increasing presence, the idea is not to constantly create these resources with helper commands.
Instead, we save the resources' YAML definitions in a Git repository and leave the creation and management of those resources to a tool.

## {{% task %}} Viewing the created resources

Display the created Deployment using the following command:

```bash
kubectl get deployments --namespace <namespace>
```

A [Deployment](https://kubernetes.io/docs/concepts/workloads/controllers/deployment/) defines the following facts:

* Update strategy: How application updates should be executed and how the Pods are exchanged
* Containers
  * Which image should be deployed
  * Environment configuration for Pods
  * ImagePullPolicy
* The number of Pods/Replicas that should be deployed

By using the `-o` (or `--output`) parameter we get a lot more information about the deployment itself. You can choose between YAML and JSON formatting by indicating `-o yaml` or `-o json`. In this training, we are going to use YAML, but please feel free to replace `yaml` with `json` if you prefer.

```bash
kubectl get deployment example-frontend -o yaml --namespace <namespace>
```

After the image has been pulled, Kubernetes deploys a Pod according to the Deployment:

```bash
kubectl get pods --namespace <namespace>
```

Which gives you an output similar to this:

```
NAME                              READY   STATUS    RESTARTS   AGE
example-frontend-69b658f647-xnm94   1/1     Running   0          39s
```

The Deployment defines that one replica should be deployed, we see that in the output. This Pod is not yet reachable from outside the cluster.

## {{% task %}} (Advanced) Create a pod with two containers

We learned that a pod can consist of more than one container. Create a Pod with 2 containers running. You can use the following images:

* [curl](https://hub.docker.com/r/curlimages/curl), use this image with the [command](https://kubernetes.io/docs/tasks/inject-data-application/define-command-argument-container/) `sleep 3600`
* [nginx](nginxinc/nginx-unprivileged), use this image to start a webserver

Then exec into the container with the `curl` image and call the `nginx` container to verify communication between them.
