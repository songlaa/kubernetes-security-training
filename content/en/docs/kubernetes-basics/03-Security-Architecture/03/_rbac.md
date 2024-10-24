---
title: "RBAC"
weight: 1
sectionnumber: 3.1
---


## Role Based Access Control

Until now we just assumed that we have the necessary right to do our tasks in kubernetes. But how are users [Authenticated](https://kubernetes.io/docs/reference/access-authn-authz/authentication/) and [Authorized](https://kubernetes.io/docs/reference/access-authn-authz/rbac/) in Kubernetes/the Kubernetes API?

### Users in Kubernetes

All Kubernetes clusters have two categories of users: service accounts managed by Kubernetes, and normal users.

It is assumed that a cluster-independent service manages normal users in the following ways:

* an administrator distributing private keys
* a user store like Keystore or Google Accounts
* a file with a list of usernames and passwords

In this regard, Kubernetes does not have objects which represent normal user accounts. Normal users cannot be added to a cluster through an API call.

Even though a normal user cannot be added via an API call, any user that presents a valid certificate signed by the cluster's certificate authority (CA) is considered authenticated. In this configuration, Kubernetes determines the username from the common name field in the 'subject' of the cert (e.g., "/CN=bob").
In contrast, service accounts are users managed by the Kubernetes API. They are bound to specific namespaces, and created automatically by the API server or manually through API calls.

#### Authentication strategies

Kubernetes uses client certificates, bearer tokens, or an authenticating proxy to authenticate API requests through authentication plugins.
As HTTP requests are made to the API server, plugins attempt to associate the following attributes with the request:

* Username: a string which identifies the end user. Common values might be kube-admin or <jane@example.com>.
* UID: a string which identifies the end user and attempts to be more consistent and unique than username.
* Groups: a set of strings, each of which indicates the user's membership in a named logical collection of users. Common values might be system:masters or devops-team.
* Extra fields: a map of strings to list of strings which holds additional information authorizers may find useful.

The following authentication method are common:

* X509 client certificates
* bearer token
* Service account tokens
* OpenID Connect Tokens (Microsoft Entra ID, Salesforce,Google...)

### RBAC Authorisation

The RBAC API declares four kinds of Kubernetes object: Role, ClusterRole, RoleBinding and ClusterRoleBinding. You can describe or amend the RBAC objects using tools such as kubectl, just like any other Kubernetes object.

#### Role and ClusterRole

An RBAC Role or ClusterRole contains rules that represent a set of permissions. Permissions are purely additive (there are no "deny" rules).

A Role always sets permissions within a particular namespace; when you create a Role, you have to specify the namespace it belongs in.

ClusterRole, by contrast, is a non-namespaced resource. The resources have different names (Role and ClusterRole) because a Kubernetes object always has to be either namespaced or not namespaced; it can't be both.

#### RoleBinding and ClusterRoleBinding

A role binding grants the permissions defined in a role to a user or set of users. It holds a list of subjects (users, groups, or service accounts), and a reference to the role being granted. A RoleBinding grants permissions within a specific namespace whereas a ClusterRoleBinding grants that access cluster-wide.

A RoleBinding may reference any Role in the same namespace. Alternatively, a RoleBinding can reference a ClusterRole and bind that ClusterRole to the namespace of the RoleBinding. If you want to bind a ClusterRole to all the namespaces in your cluster, you use a ClusterRoleBinding.

### {{% task %}} Create a New Service Account

In this lab, we will explore how to test Kubernetes RBAC (Role-Based Access Control) using an **explicitly created service account**. Unlike the default service account, which is automatically created in each namespace, we will create our own service account and bind it to a Role that grants permissions to list and create pods.

Instead of using the default service account, we will create a new service account named `<namespace>-sa`:

```bash
kubectl create serviceaccount <namespace>-sa
kubectl get serviceaccount
```

Next, we will create a pod that uses the newly created <namespace>-sa service account.

```bash
kubectl run kubectl-pod --image=bitnami/kubectl --restart=Never --overrides='{ "spec": { "serviceAccount": "<namespace>-sa" }}' -- sleep infinity
```

We are ready to use kubectl from within our pod to list all pods in the namespace using the `<namespace>-sa` service account:

```bash
kubectl exec -it kubectl-pod -- kubectl get pods
```

You will likely see a permission denied error because `<namespace>-sa` does not have the required permissions to list pods.

To allow the `<namespace>-sa` service account to list and create pods, we need to create a Role that grants these permissions.

Create a file called `role.yaml` to define a Role that allows listing and creating pods:

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  namespace: <namespace>
  name: pod-manager
rules:
- apiGroups: [""]
  resources: ["pods"]
  verbs: ["list", "create"]
```

apply the Role:

```bash
kubectl apply -f role.yaml
```

This Role grants the ability to list and create pods in the `<namespace>` namespace. Kubernetes grants you rights to create roles and rolebindings which do not exceed your own rights.

Now that we have a Role, we need to bind the `<namespace>-sa` service account to this Role so that it can use the permissions.

Create a file called `rolebinding.yaml` to bind the `<namespace>-sa` service account to the `pod-manager` Role:

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: pod-manager-binding
  namespace: default
subjects:
- kind: ServiceAccount
  name: <namespace>-sa
  namespace: default
roleRef:
  kind: Role
  name: pod-manager
  apiGroup: rbac.authorization.k8s.io
```

Apply the RoleBinding:

```bash
kubectl apply -f rolebinding.yaml
```

The `<namespace>-sa` service account is now bound to the `pod-manager` Role, and can list and create pods in the `<namespace>` namespace.

Kubernetes provides the `kubectl auth can-i` command to check if a specific action is allowed for a user or service account.

```bash
kubectl auth can-i list pods --as=system:serviceaccount:<namespace>:<namespace>-sa -n <namespace>
kubectl auth can-i create pods --as=system:serviceaccount:<namespace>:<namespace>-sa -n <namespace>
```

Both commands should return `yes` now that the Role and RoleBinding are in place.

Now use the Service Account to create a new Pod

```bash
kubectl exec -it kubectl-pod -- kubectl run new-pod --image=nginx --restart=Never
```

Check if the new pod was created:

```bash
kubectl get pods
```

You should now see both `kubectl-pod` and `new-pod` in the output.

Feel free to experiment by modifying the Role's permissions or testing different service accounts to better understand Kubernetes RBAC!

{{% details title="🤔 Can I list secrets whith this service account?" %}}
You did not include secrets in your role, so you cannot list secrets directly.

However you have the right to start a pod in this namespace, if you happen to know the name of the secret (or guess it) you can mount any secret in this namespace to the pod an read it inside the pod!
{{% /details %}}

You can delete both pods and the service account after you have finished the lab:

```bash
kubectl delete pods kubectl-pod, new-pod
kubectl delete -f role.yaml
kubectl delete -f rolebinding.yaml
kubectl delete sa <namespace>-sa
```
