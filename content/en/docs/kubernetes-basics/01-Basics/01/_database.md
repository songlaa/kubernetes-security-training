---
title: "Backend"
weight: 4
sectionnumber: 1.4
---

Numerous applications are stateful in some way and want to save data persistently, be it in a database, as files on a filesystem or in an object store. In this lab, we are going to create a MariaDB database and configure our application to store its data in it.

## {{% task %}} Instantiate a MariaDB database

We are first going to create a so-called _Secret_ in which we store sensitive data. The secret will be used to access the database and also to create the initial database.

```bash
kubectl create secret generic mariadb \
  --from-literal=database-name=acend_exampledb \
  --from-literal=database-password=mysqlpassword \
  --from-literal=database-root-password=mysqlrootpassword \
  --from-literal=database-user=acend_user \
  --namespace <namespace>
```

The Secret contains the database name, user, password, and the root password. However, these values will neither be shown with `{{% param cliToolName %}} get` nor with `{{% param cliToolName %}} describe`:

```bash
{{% param cliToolName %}} get secret mariadb --output yaml --namespace <namespace>
```

```
apiVersion: v1
data:
  database-name: YWNlbmQtZXhhbXBsZS1kYg==
  database-password: bXlzcWxwYXNzd29yZA==
  database-root-password: bXlzcWxyb290cGFzc3dvcmQ=
  database-user: YWNlbmRfdXNlcg==
kind: Secret
metadata:
  ...
type: Opaque
```

The reason is that all the values in the `.data` section are base64 encoded. Even though we cannot see the true values, they can easily be decoded:

```bash
echo "YWNlbmQtZXhhbXBsZS1kYg==" | base64 -d
```

{{% alert title="Note" color="info" %}}
By default, Secrets are not encrypted!

However, [Kubernetes (1.13 and later)](https://kubernetes.io/docs/tasks/administer-cluster/encrypt-data/) offers the capability to encrypt data in etcd.

Another option would be the use of a secrets management solution like [Vault by HashiCorp](https://www.vaultproject.io/) in conntection with the [External Secrets Operator](https://external-secrets.io/).

{{% /alert %}}

We are now going to create a Deployment and a Service. As a first example, we use a database without persistent storage. Only use an ephemeral database for testing purposes as a restart of the Pod leads to data loss. We are going to look at how to persist this data in a persistent volume later on.

As we had seen in the earlier labs, all resources like Deployments, Services, Secrets and so on can be displayed in YAML or JSON format. It doesn't end there, capabilities also include the creation and exportation of resources using YAML or JSON files.

In our case we want to create a Deployment and Service for our MariaDB database.
Save this snippet as `mariadb.yaml`:

{{< readfile file="/content/en/docs/kubernetes-basics/01-Basics/01/mariadb.yaml" code="true" lang="yaml" >}}

Apply it with:

```bash
kubectl apply -f mariadb.yaml --namespace <namespace>
```

As soon as the container image for `mariadb:10.5` has been pulled, you will see a new Pod using `kubectl get pods`.

The environment variables defined in the deployment configure the MariaDB Pod and how our frontend will be able to access it.

The interesting thing about Secrets is that they can be reused, e.g., in different Deployments. We could extract all the plaintext values from the Secret and put them as environment variables into the Deployments, but it's way easier to instead simply refer to its values inside the Deployment (as in this lab) like this:

```
...
spec:
  template:
    spec:
      containers:
      - name: mariadb
        env:
        - name: MYSQL_USER
          valueFrom:
            secretKeyRef:
              key: database-user
              name: mariadb
        - name: MYSQL_PASSWORD
          valueFrom:
            secretKeyRef:
              key: database-password
              name: mariadb
        - name: MYSQL_ROOT_PASSWORD
          valueFrom:
            secretKeyRef:
              key: database-root-password
              name: mariadb
        - name: MYSQL_DATABASE
          valueFrom:
            secretKeyRef:
              key: database-name
              name: mariadb
...
```

Above lines are an excerpt of the MariaDB Deployment. Most parts have been cut out to focus on the relevant lines: The references to the `mariadb` Secret. As you can see, instead of directly defining environment variables you can refer to a specific key inside a Secret. We are going to make further use of this concept for our Python application.

## {{% task %}} Attach the database to the application

By default, our `example-frontend` application uses an SQLite memory database.

However, this can be changed by defining the following environment variable to use the newly created MariaDB database:

```
#MYSQL_URI=mysql://<user>:<password>@<host>/<database>
MYSQL_URI=mysql://acend_user:mysqlpassword@mariadb/acend_exampledb
```


The connection string our `example-frontend` application uses to connect to our new MariaDB, is a concatenated string from the values of the `mariadb` Secret.

For the actual MariaDB host, you can either use the MariaDB Service's ClusterIP or DNS name as the address. All Services and Pods can be resolved by DNS using their name.

{{% onlyWhenNot sbb %}}
The following commands set the environment variables for the deployment configuration of the `example-frontend` application:

{{% alert title="Warning" color="warning" %}}
Depending on the shell you use, the following `set env` command works but inserts too many apostrophes! Check the deployment's environment variable afterwards or directly edit it as described further down below.
{{% /alert %}}

```bash
{{% param cliToolName %}} set env --from=secret/mariadb --prefix=MYSQL_ deploy/example-frontend --namespace <namespace>
```

and

```bash
{{% param cliToolName %}} set env deploy/example-frontend MYSQL_URI='mysql://$(MYSQL_DATABASE_USER):$(MYSQL_DATABASE_PASSWORD)@mariadb/$(MYSQL_DATABASE_NAME)' --namespace <namespace>
```

The first command inserts the values from the Secret, the second finally uses these values to put them in the environment variable `MYSQL_URI` which the application considers.

You can also do the changes by directly editing your local `deployment_example-frontend.yaml` file. Find the section which defines the containers. You should find it under:

```
...
spec:
...
 template:
 ...
  spec:
    containers:
    - image: ...
...
```

The dash before `image:` defines the beginning of a new container definition. The following specifications should be inserted into this container definition:

```yaml
        env:
          - name: MYSQL_DATABASE_NAME
            valueFrom:
              secretKeyRef:
                key: database-name
                name: mariadb
          - name: MYSQL_DATABASE_PASSWORD
            valueFrom:
              secretKeyRef:
                key: database-password
                name: mariadb
          - name: MYSQL_DATABASE_ROOT_PASSWORD
            valueFrom:
              secretKeyRef:
                key: database-root-password
                name: mariadb
          - name: MYSQL_DATABASE_USER
            valueFrom:
              secretKeyRef:
                key: database-user
                name: mariadb
          - name: MYSQL_URI
            value: mysql://$(MYSQL_DATABASE_USER):$(MYSQL_DATABASE_PASSWORD)@mariadb/$(MYSQL_DATABASE_NAME)
```

Your file should now look like this:

```
      ...
      containers:
      - image: {{% param "containerImages.training-image-url" %}}
        imagePullPolicy: Always
        name: example-frontend
        ...
        env:
        - name: MYSQL_DATABASE_NAME
          valueFrom:
            secretKeyRef:
              key: database-name
              name: mariadb
        - name: MYSQL_DATABASE_PASSWORD
          valueFrom:
            secretKeyRef:
              key: database-password
              name: mariadb
        - name: MYSQL_DATABASE_ROOT_PASSWORD
          valueFrom:
            secretKeyRef:
              key: database-root-password
              name: mariadb
        - name: MYSQL_DATABASE_USER
          valueFrom:
            secretKeyRef:
              key: database-user
              name: mariadb
        - name: MYSQL_URI
          value: mysql://$(MYSQL_DATABASE_USER):$(MYSQL_DATABASE_PASSWORD)@mariadb/$(MYSQL_DATABASE_NAME)
```

Then use:

```bash
{{% param cliToolName %}} apply -f deployment_example-frontend.yaml --namespace <namespace>
```

to apply the changes.

{{% /onlyWhenNot %}}
{{% onlyWhen sbb %}}
Add the environment variables by directly editing the Deployment:

```bash
{{% param cliToolName %}} edit deployment example-frontend --namespace <namespace>
```

```yaml
      ...
      containers:
      - image: {{% param "containerImages.training-image-url" %}}
        imagePullPolicy: Always
        name: example-frontend
        ...
        env:
        - name: SPRING_DATASOURCE_DATABASE_NAME
          valueFrom:
            secretKeyRef:
              key: database-name
              name: mariadb
        - name: SPRING_DATASOURCE_USERNAME
          valueFrom:
            secretKeyRef:
              key: database-user
              name: mariadb
        - name: SPRING_DATASOURCE_PASSWORD
          valueFrom:
            secretKeyRef:
              key: database-password
              name: mariadb
        - name: SPRING_DATASOURCE_DRIVER_CLASS_NAME
          value: com.mysql.cj.jdbc.Driver
        - name: SPRING_DATASOURCE_URL
          value: jdbc:mysql://mariadb/$(SPRING_DATASOURCE_DATABASE_NAME)?autoReconnect=true
        ...
```

{{% /onlyWhen %}}

The environment can also be checked with the `set env` command and the `--list` parameter:

```bash
{{% param cliToolName %}} set env deploy/example-frontend --list --namespace <namespace>
```

This will show the environment as follows:

```
# deployments/example-frontend, container example-frontend
# MYSQL_DATABASE_PASSWORD from secret mariadb, key database-password
# MYSQL_DATABASE_ROOT_PASSWORD from secret mariadb, key database-root-password
# MYSQL_DATABASE_USER from secret mariadb, key database-user
# MYSQL_DATABASE_NAME from secret mariadb, key database-name
MYSQL_URI=mysql://$(MYSQL_DATABASE_USER):$(MYSQL_DATABASE_PASSWORD)@mariadb/$(MYSQL_DATABASE_NAME)
```

{{% alert title="Warning" color="warning" %}}
Do not proceed with the lab before all example-frontend pods are restarted successfully.

The change of the deployment definition (environment change) triggers a new rollout and all example-frontend pods will be restarted. The application will not be connected to the database until all pods are restarted successfully.
{{% /alert %}}

In order to find out if the change worked we can either look at the container's logs (`{{% param cliToolName %}} logs <pod>`) or we could register some "Hellos" in the application, delete the Pod, wait for the new Pod to be started and check if they are still there.

{{% alert title="Note" color="info" %}}
This does not work if we delete the database Pod as its data is not yet persisted.
{{% /alert %}}

## {{% task %}} Manual database connection

As described in {{<link "troubleshooting">}} we can log into a Pod with {{% onlyWhenNot openshift %}}`kubectl exec -it <pod> -- /bin/bash`.{{% /onlyWhenNot %}}{{% onlyWhen openshift %}}`oc rsh <pod>`.{{% /onlyWhen %}}

Show all Pods:

```bash
{{% param cliToolName %}} get pods --namespace <namespace>
```

Which gives you an output similar to this:

```
NAME                                  READY   STATUS      RESTARTS   AGE
example-frontend-574544fd68-qfkcm      1/1     Running     0          2m20s
mariadb-f845ccdb7-hf2x5               1/1     Running     0          31m
mariadb-1-deploy                      0/1     Completed   0          11m
```

Log into the MariaDB Pod:

{{% alert title="Note" color="info" %}}
As mentioned in {{<link "troubleshooting">}}, remember to append the command with `winpty` if you're using Git Bash on Windows.
{{% /alert %}}

{{% onlyWhenNot openshift %}}

```bash
kubectl exec -it deployments/mariadb --namespace <namespace> -- /bin/bash
```

{{% /onlyWhenNot %}}
{{% onlyWhen openshift %}}

```bash
oc rsh --namespace <namespace> <mariadb-pod-name>
```

{{% /onlyWhen %}}

You are now able to connect to the database and display the data. Login with:

```bash
mysql -u$MYSQL_USER -p$MYSQL_PASSWORD -h$MARIADB_SERVICE_HOST $MYSQL_DATABASE

```

```
Welcome to the MariaDB monitor.  Commands end with ; or \g.
Your MariaDB connection id is 52810
Server version: 10.2.22-MariaDB MariaDB Server

Copyright (c) 2000, 2018, Oracle, MariaDB Corporation Ab and others.

Type 'help;' or '\h' for help. Type '\c' to clear the current input statement.

MariaDB [acend_exampledb]>
```

Show all tables with:

```bash
show tables;
```

Show any entered "Hellos" with:

```bash
select * from hello;
```

## {{% task %}} Optional Lab: Import a database dump

Our task is now to import this [dump.sql](https://raw.githubusercontent.com/acend/kubernetes-basics-training/main/content/en/docs/attaching-a-database/dump.sql) into the MariaDB database running as a Pod. Use the `mysql` command line utility to do this. Make sure the database is empty beforehand. You could also delete and recreate the database.

{{% alert title="Note" color="info" %}}
You can also copy local files into a Pod using `{{% param cliToolName %}} cp`. Be aware that the `tar` binary has to be present inside the container and on your operating system in order for this to work! Install `tar` on UNIX systems with e.g. your package manager, on Windows there's e.g. [cwRsync](https://www.itefix.net/cwrsync). If you cannot install `tar` on your host, there's also the possibility of logging into the Pod and using `curl -O <url>`.
{{% /alert %}}

### Solution

This is how you copy the database dump into the MariaDB Pod.

Download the [dump.sql](https://raw.githubusercontent.com/acend/kubernetes-basics-training/main/content/en/docs/attaching-a-database/dump.sql) or get it with curl:

```bash
curl -O https://raw.githubusercontent.com/acend/kubernetes-basics-training/main/content/en/docs/attaching-a-database/dump.sql
```

Copy the dump into the MariaDB Pod:

```bash
{{% param cliToolName %}} cp ./dump.sql <podname>:/tmp/ --namespace <namespace>
```

This is how you log into the MariaDB Pod:

{{% onlyWhenNot openshift %}}

```bash
kubectl exec -it <podname> --namespace <namespace> -- /bin/bash
```

{{% /onlyWhenNot %}}
{{% onlyWhen openshift %}}

```bash
oc rsh --namespace <namespace> <podname>
```

{{% /onlyWhen %}}

This command shows how to drop the whole database:

```bash
mariadb -u$MYSQL_USER -p$MYSQL_PASSWORD -h$MARIADB_SERVICE_HOST $MYSQL_DATABASE
```

```bash
drop database `acend_exampledb`;
create database `acend_exampledb`;
exit
```

Import a dump:

```bash
mariadb -u$MYSQL_USER -p$MYSQL_PASSWORD -h$MARIADB_SERVICE_HOST $MYSQL_DATABASE < /tmp/dump.sql
```

Check your app to see the imported "Hellos".

{{% onlyWhen openshift %}}

{{% alert title="Note" color="info" %}}
You can find your app URL by looking at your route:

```bash
{{% param cliToolName %}} get {{% onlyWhenNot openshift %}}ingress{{% /onlyWhen %}}{{% onlyWhen openshift %}}route{{% /onlyWhen %}} --namespace <namespace>
```

{{% /alert %}}
{{% /onlyWhen %}}

{{% onlyWhenNot openshift %}}

{{% alert title="Note" color="info" %}}
You can find your app URL by looking at your ingress:

```bash
kubectl get ingress --namespace <namespace>
```

{{% /alert %}}
{{% /onlyWhenNot %}}

{{% alert title="Note" color="info" %}}
A database dump can be created as follows:

{{% onlyWhenNot openshift %}}

```bash
kubectl exec -it <podname> --namespace <namespace> -- /bin/bash
```

{{% /onlyWhenNot %}}
{{% onlyWhen openshift %}}

```bash
oc rsh --namespace <namespace> <podname>
```

{{% /onlyWhen %}}

```bash
mysqldump --user=$MYSQL_USER --password=$MYSQL_PASSWORD -h$MARIADB_SERVICE_HOST $MYSQL_DATABASE > /tmp/dump.sql
```

```bash
{{% param cliToolName %}} cp <podname>:/tmp/dump.sql /tmp/dump.sql
```

{{% /alert %}}
