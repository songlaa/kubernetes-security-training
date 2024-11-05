
1. **Create a secret**:

   ```bash
   kubectl create secret generic my-secret --from-literal=username=myuser --from-literal=password=mypassword
   ```

2. **Run a pod with the secret mounted**:

   ```bash
   kubectl exec -it kubectl-pod -- sh
   ```

   inside this pod

   ```bash
   kubectl run secret-mount-pod --image=alpine --overrides='
   {
     "apiVersion": "v1",
     "spec": {
       "volumes": [
         {
           "name": "secret-volume",
           "secret": {
             "secretName": "my-secret"
           }
         }
       ],
       "containers": [
         {
           "name": "alpine",
           "command": ["cat", "/etc/secret-volume/username", "/etc/secret-volume/password"],
           "image": "alpine",
           "volumeMounts": [
             {
               "mountPath": "/etc/secret-volume",
               "name": "secret-volume",
               "readOnly": true
             }
           ]
         }
       ]
     }
   }'
   ```

These commands create a secret and then run a pod that mounts the secret at `/etc/secret-volume`.

```bash
kubectl logs secret-mount-pod
```
