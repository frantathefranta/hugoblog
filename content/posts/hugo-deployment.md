+++
title = "Hugo Deployment"
author = ["Franta Bartik"]
date = 2024-03-21T16:50:00-04:00
draft = false
+++

## Introduction {#introduction}

I wanted to have a fully automated setup to deploy a Hugo blog on my K3s cluster. This guide isn't really about setting up Hugo, more about the underlying infrastructure.


## Procedure {#procedure}


### Hugo {#hugo}


#### Prerequisites {#prerequisites}

1.  [Create your Hugo site first](https://gohugo.io/getting-started/quick-start/) and set up the config to your liking.
2.  Set up an account on [DockerHub](https://hub.docker.com) (and [GitHub](https://github.com) if you don't have one)
3.  Have a running Kubernetes cluster


#### Set up the GitHub repo {#set-up-the-github-repo}

I've chosen GitHub because I already know how to use it but it should be possible to have a similar CI/CD setup on a different host.
You'll need these files at the root of the repo:

1.  `Dockerfile`
    ```dockerfile
    FROM hugomods/hugo:exts as builder

    # Base URL
    ARG HUGO_BASEURL=""
    ENV HUGO_BASEURL=${HUGO_BASEURL}
    # Build site
    COPY . /src
    RUN hugo --minify --gc
    # Set the fallback 404 page if defaultContentLanguageInSubdir is enabled, please replace the `en` with your default language code.
    # RUN cp ./public/en/404.html ./public/404.html

    #####################################################################
    #                            Final Stage                            #
    #####################################################################
    FROM hugomods/hugo:nginx
    # Copy the generated files to keep the image as small as possible.
    COPY --from=builder /src/public /site
    ```

2.  `.github/workflows/main.yaml`
    ```yaml
    name: ci

    on:
      push:
        branches:
    ​      - 'master'

    jobs:
      docker:
        env:
          IMAGE: <image_name>
        runs-on: ubuntu-latest
        steps:
    ​      - name: Checkout
            uses: actions/checkout@v4
            with:
              submodules: recursive # Necessary to download and apply themes
    ​      - name: Set up QEMU
            uses: docker/setup-qemu-action@v3
    ​      - name: Set up Docker Buildx
            uses: docker/setup-buildx-action@v3
    ​      - name: Login to Docker Hub
            uses: docker/login-action@v3
            with:
              username: ${{ secrets.DOCKERHUB_USERNAME }}
              password: ${{ secrets.DOCKERHUB_TOKEN }}
    ​      - name: Build and push
            uses: docker/build-push-action@v5
            with:
              context: .
              push: true
              tags: |
                ${{ env.IMAGE }}:${{ github.sha }}-${{ github.run_number }}
    ```

3.  `.gitignore`
    ```gitignore
    # Added automatically
    .DS_Store
    .idea
    *.log
    tmp/

    # Hugo specifc
    public/
    resources/
    .hugo_build.lock
    ```


### Kubernetes {#kubernetes}

My cluster is orchestrated using FluxCD, so I'm using their solution for Image Automation. When bootstrapping your cluster with Flux, you'll need to add the option `--components-extra=image-reflector-controller,image-automation-controller`, because it doesn't get installed default. Another necessity is to use `--read-write-key=true` for deploying a repo key that can write (default is read-only). `ImageUpdateAutomation` will not be able to run properly without it.


#### `HelmRelease` {#helmrelease}

I'm using the `bjw-template` Helm Chart because I'm familiar with it and it's already used for other releases in my cluster.

```yaml
---
# yaml-language-server: $schema=https://kubernetes-schemas.pages.dev/helm.toolkit.fluxcd.io/helmrelease_v2beta2.json
apiVersion: helm.toolkit.fluxcd.io/v2beta2
kind: HelmRelease
metadata:
  name: hugo
  namespace: apps
spec:
  chart:
    spec:
      chart: app-template
      version: 2.6.x # auto-update to semver bugfixes only
      sourceRef:
        kind: HelmRepository
        name: bjw
        namespace: flux-system
  interval: 15m
  timeout: 5m
  values: # paste contents of upstream values.yaml below, indented 4 spaces
    controllers:
      main:
        strategy: Recreate
        containers:
          main:
            image:
              repository: <image_name> # {"$imagepolicy": "flux-system:hugoblog-repo-policy:name"}
              tag: latest # {"$imagepolicy": "flux-system:hugoblog-repo-policy:tag"}
              # With tag: latest, the ImageUpdateAutomation will change this automatically
    service:
      main:
        ports:
          http:
            port: 80 # the hugo:nginx image runs the NGINX server on port 80
    ingress:
      main:
        enabled: true
        hosts:
          - host: <blog_domain>
            paths:
              - path: /
                pathType: Prefix
                service:
                  name: main
                  port: http
        tls:
          - secretName: <TLS_Secret_Name>
            hosts:
              - <blog_domain>
```


#### `ImageRepository` {#imagerepository}

```yaml
---
# yaml-language-server: $schema=https://raw.githubusercontent.com/fluxcd-community/flux2-schemas/main/imagerepository-image-v1beta2.json
apiVersion: image.toolkit.fluxcd.io/v1beta2
kind: ImageRepository
metadata:
  name: hugoblog
  namespace: flux-system
spec:
  image: <image_name>
  interval: 5m
```


#### `ImagePolicy` {#imagepolicy}

```yaml
---
# yaml-language-server: $schema=https://raw.githubusercontent.com/fluxcd-community/flux2-schemas/main/imagepolicy-image-v1beta2.json
apiVersion: image.toolkit.fluxcd.io/v1beta2
kind: ImagePolicy
metadata:
  name: hugoblog-repo-policy
  namespace: flux-system
spec:
  imageRepositoryRef:
    name: hugoblog
  filterTags:
    ## use "pattern: '[a-f0-9]+-(?P<ts>[0-9]+)'" if you copied the workflow example using github.run_number
    pattern: '[a-f0-9]+-(?P<ts>[0-9]+)'
    extract: '$ts'
  policy:
    numerical:
      order: asc
```


#### `ImageUpdateAutomation` {#imageupdateautomation}

```yaml
---
# yaml-language-server: $schema=https://raw.githubusercontent.com/fluxcd-community/flux2-schemas/main/imageupdateautomation-image-v1beta1.json
apiVersion: image.toolkit.fluxcd.io/v1beta1
kind: ImageUpdateAutomation
metadata:
  name: flux-system
  namespace: flux-system
spec:
  git:
    checkout:
      ref:
        branch: main
    commit:
      author:
        email: fluxcdbot@users.noreply.github.com
        name: fluxcdbot
      messageTemplate: '{{range .Updated.Images}}{{println .}}{{end}}'
    push:
      branch: main
  interval: 30m0s
  sourceRef:
    kind: GitRepository
    name: flux-system
  update:
    path: ./ # Set so it applies to the whole repo
    strategy: Setters
```


## Result {#result}

Now when you add a new update to your Hugo blog:

1.  A new docker image should get built.
2.  It will be pulled in by the `image-automation-controller` in your Kubernetes cluster.
3.  A new pod will be deployed with the updated blog.
