---
title: "Custom Policies"
weight: 4
sectionnumber: 3.4
---

Until now we learned best practices on how to secure our workload in Kubernetes, but as a cluster admin. How can we enforce certain regulations for resources in our cluster? Sometimes we need to be more specific than the 3 PSP this is where policy engines like [Open Policy Agent (OPA)](https://www.openpolicyagent.org/) or [Kyverno](https://kyverno.io/) come into play.

## Kyverno

Kyverno is an open-source policy engine designed specifically for Kubernetes. It allows you to manage and enforce security and compliance policies for your Kubernetes resources using custom resource definitions (CRDs). We use it to write our own Policies as Code.

Remember when we did patch a namespace in a previous lab. Patching and allowing the users to change labels can have real security consequences because it allows users to change the behavior of algorithms like network policies which use labels to filter out resources. This is why a Policy was set in place that you could only change certain labels of a namespace.

### {{% task %}} Install Kyverno on our kind cluster

We will install a standalone version of Kyverno on our `kind` cluster using helm to test out its functionality:

```bash
helm repo add kyverno https://kyverno.github.io/kyverno/
helm repo update
helm install kyverno kyverno/kyverno -n kyverno --create-namespace
 ```

We see that a new Webhook was created which calls Kyverno on CREATE and UPDATE operations:

```bash
kubectl get validatingwebhookconfigurations.admissionregistration.k8s.io kyverno-policy-validating-webhook-cfg -oyaml
```

Kyverno itself runs in the `kyverno` namespace:

```bash
kubectl get deployments.apps -n kyverno
```

### {{% task %}} Apply a policy

Let us create a namespace called `test-kyverno` and apply our own policy for this namespace, we want to start soft and warn users if they did not add the requirement that a container must drop `ALL` capabilities.

Create the namespace first:

```bash
kubectl create ns test-kyverno
```

Now let us create a pod which passes the PSS Level `baseline`:

```bash
cat <<EOF >> alpine-pod.yaml
apiVersion: v1
kind: Pod
metadata:
  name: alpine-pod
  namespace: test-kyverno
  labels:
    app: alpine
spec:
  securityContext:
    runAsNonRoot: true
    runAsUser: 1000
  containers:
    - name: alpine
      image: alpine
      command: ["sleep", "infinity"]
      securityContext:
        allowPrivilegeEscalation: false
        readOnlyRootFilesystem: true
      resources:
        limits:
          cpu: "100m"
          memory: "128Mi"
EOF
kubectl apply -f alpine-pod.yaml
```

We see this works.

The baseline does not monitor if file systems are mounted `read-only` but the `restricted` profile is not flexibel enough. Let us apply a Kyverno policy for that.

Kyvernos has a so called Custom Resourced called policy for that, create a file named `read-only.yaml` with this content:

```yaml
cat <<\EOF >> read-only.yaml
apiVersion: kyverno.io/v1
kind: Policy
metadata:
  name: enforce-readonly-filesystem
  namespace: test-kyverno
  annotations:
    policies.kyverno.io/title: Enforce read-only fs
    policies.kyverno.io/category: Best Practices
    policies.kyverno.io/severity: medium
    policies.kyverno.io/minversion: 1.6.0
    policies.kyverno.io/subject: Pod
spec:
  validationFailureAction: Audit
  background: true
  rules:
    - name: check-readonly-root-filesystem
      match:
        resources:
          kinds:
            - Pod
      validate:
        message: "The root filesystem must be mounted as read-only for all containers."
        pattern:
          spec:
            containers:
              - securityContext:
                  readOnlyRootFilesystem: true
EOF
```

Apply the policy now

```bash
kubectl apply -f read-only.yaml
```

Now let us delete, edit and rerun the pod

```bash
kubectl delete -f alpine-pod.yaml
```

Switch `readOnlyRootFilesystem` to false.

```bash
nano alpine-pod.yaml
```

And then apply the pod again:

```bash
kubectl apply -f alpine-pod.yaml
```

Because the Action is only set to `Audit` noncompliant resources are only logged, check here:

```bash
kubectl -n test-kyverno describe policies.kyverno.io enforce-readonly-filesystem
```

Let us now enforce our policy, switch the `Audit` to `Enforce` in `drop-policy.yaml` and apply it again:

```bash
nano read-only.yaml
kubectl apply -f read-only.yaml
```

Now test the same pod again:

```bash
kubectl delete -f alpine-pod.yaml
kubectl apply -f alpine-pod.yaml
```

We were successful in implementing and enforcing our policy for newly started pods. We still need this pod running so change it back to a working mode:

Let us now enforce our policy, switch the `Audit` to `Enforce` in `drop-policy.yaml` and apply it again:

```bash
nano alpine-pod.yaml
kubectl apply -f alpine-pod.yaml
```

## {{% task %}} (Advanced) Private Container Registries

To improve security many companies run private container registries nowadays. The goal is to enforce that you can only run images from your certain registries.

Create a Kyverno Policy with "Audit" Level which checks if your images (i.e. [quay.io/jitesoft/alpine](quay.io/jitesoft/alpine)) are pulled from quay.io and warns about that.
