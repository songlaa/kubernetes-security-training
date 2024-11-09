# Kubernetes Security Training

## Content Sections

The training content resides within the [content](content) directory.

The main part are the labs, which can be found at [content/en/docs](content/en/docs).

## Hugo

This site is built using the static page generator [Hugo](https://gohugo.io/).

The page uses the [docsy theme](https://github.com/google/docsy) which is included as a Hugo Module.

### Docsy theme usage

* [Official docsy documentation](https://www.docsy.dev/docs/)
* [Docsy Plus](https://github.com/acend/docsy-plus/)

### Update hugo modules for theme updates

Run the following command to update all modules with their newest upstream version:

```bash
hugo mod get -u
```

Command without hugo installation:

```bash
export HUGO_VERSION=$(grep -oP "(?<=hugo-version: ')[^']*(?=')" .github/workflows/hugo.yaml)
docker run --rm --interactive -v $(pwd):/src docker.io/floryn90/hugo:${HUGO_VERSION} mod get -u
```

### Plain Docker

To develop locally we don't want to rebuild the entire container image every time something changed, and it is also important to use the same hugo versions like in production.
We simply mount the working directory into a running container, where hugo is started in the server mode.

```bash
export HUGO_VERSION=$(grep -oP "(?<=hugo-version: ')[^']*(?=')" .github/workflows/hugo.yaml)
docker run --rm --publish 8080:8080 --volume $(pwd):/src floryn90/hugo:$HUGO_VERSION-ext-ubuntu server --port 8080
```

### TODO - next Training

* check if <https://stackoverflow.com/questions/53053888/where-is-the-complete-list-of-kubernetes-objects> works in webshell and add to rbac training
* create a graphic showing the request flow internet --> ingress --> svc --> pod for the lab
* explore the possibilty to expose a kubernetes dashboard with a student link (gui for beginners)
